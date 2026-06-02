'use strict';

const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');

let AdmZip;
try { AdmZip = require('adm-zip'); } catch { AdmZip = null; }

let iconv;
try {
  iconv = require('iconv-lite');
} catch {
  iconv = null;
}

const OUTPUT_DIR = path.join(__dirname, '..', 'novel_data');
const USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';
const MIN_TXT_BYTES = 1024 * 1024;

const results = {
  sources: [],
  errors: [],
  primaryFile: null,
};

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function resolveUrl(base, loc) {
  if (!loc) return base;
  if (loc.startsWith('http://') || loc.startsWith('https://')) return loc;
  const u = new URL(base);
  if (loc.startsWith('//')) return u.protocol + loc;
  if (loc.startsWith('/')) return u.protocol + '//' + u.host + loc;
  return new URL(loc, base).href;
}

function fetchBuffer(url, redirectCount = 0) {
  return new Promise((resolve, reject) => {
    if (redirectCount > 5) return reject(new Error('Too many redirects: ' + url));
    let parsed;
    try {
      parsed = new URL(url);
    } catch (e) {
      return reject(e);
    }
    const mod = parsed.protocol === 'https:' ? https : http;
    const req = mod.get(
      url,
      {
        headers: {
          'User-Agent': USER_AGENT,
          Accept: 'text/html,application/xhtml+xml,application/octet-stream,text/plain,*/*',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        },
        timeout: 60000,
      },
      (res) => {
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
          res.resume();
          const next = resolveUrl(url, res.headers.location);
          return resolve(fetchBuffer(next, redirectCount + 1));
        }
        const chunks = [];
        res.on('data', (c) => chunks.push(c));
        res.on('end', () => {
          resolve({
            status: res.statusCode,
            headers: res.headers,
            body: Buffer.concat(chunks),
            finalUrl: url,
          });
        });
      }
    );
    req.on('error', reject);
    req.on('timeout', () => {
      req.destroy(new Error('Request timeout: ' + url));
    });
  });
}


async function fetchWithRetry(url, attempts = 3) {
  let lastErr;
  for (let i = 0; i < attempts; i++) {
    try {
      return await fetchBuffer(url);
    } catch (e) {
      lastErr = e;
      await sleep(800 * (i + 1));
    }
  }
  throw lastErr;
}

function extractZipToTxt(zipBuffer, txtPath) {
  if (!AdmZip) return null;
  const zip = new AdmZip(zipBuffer);
  const entries = zip.getEntries().filter((e) => !e.isDirectory);
  const txtEntry =
    entries.find((e) => /\.txt$/i.test(e.entryName)) ||
    entries.sort((a, b) => b.header.size - a.header.size)[0];
  if (!txtEntry) return null;
  const data = txtEntry.getData();
  fs.writeFileSync(txtPath, data);
  return { size: data.length, entry: txtEntry.entryName };
}

async function bypass438xsGate(bookPathUrl) {
  const gate = await fetchWithRetry(bookPathUrl);
  const gateHtml = gate.body.toString('utf8');
  const m = gateHtml.match(/redirect_link\s*=\s*['"]([^'"]+)['"]/);
  if (!m) {
    if (gateHtml.length > 5000 && !gateHtml.includes('FingerprintJS')) {
      return { html: decodeHtmlBuffer(gate.body, gate.headers['content-type']), finalUrl: bookPathUrl };
    }
    throw new Error('438xs anti-bot gate; no redirect_link');
  }
  const bypassUrl = m[1] + 'fp=-5';
  const page = await fetchWithRetry(bypassUrl);
  return {
    html: decodeHtmlBuffer(page.body, page.headers['content-type']),
    finalUrl: bypassUrl,
  };
}

function extractHjwzwChapterContent(html) {
  const titleMatch = html.match(/property="og:title"\s+content="([^"]+)"/i);
  const title = titleMatch ? titleMatch[1].trim() : '';
  const divRe = /<div[^>]*text-indent:\s*2em[^>]*>([\s\S]*?)<\/div>/gi;
  let best = '';
  let m;
  while ((m = divRe.exec(html)) !== null) {
    const chunk = m[1];
    if (/請記住本站域名|黃金屋/.test(chunk) && chunk.length < 800) continue;
    if (chunk.length > best.length) best = chunk;
  }
  let text = stripHtml(best.replace(/<p\s*\/?>/gi, '\n'));
  if (text.length < 200) {
    const og = html.match(/property="og:description"\s+content="([^"]+)"/i);
    if (og) text = og[1].trim();
  }
  return { title, text };
}

async function downloadHjwzwChapters(chapterPaths, outPath) {
  const base = 'https://tw.hjwzw.com';
  const chapterUrls = chapterPaths.map((p) => resolveUrl(base, p));
  const testCount = Math.min(5, chapterUrls.length);
  for (let i = 0; i < testCount; i++) {
    const res = await fetchWithRetry(chapterUrls[i]);
    const chHtml = decodeHtmlBuffer(res.body, res.headers['content-type']);
    const { title, text } = extractHjwzwChapterContent(chHtml);
    console.log('  Test chapter', i + 1, title || chapterUrls[i], 'chars:', text.length);
    if (text.length <= 1000) return null;
    await sleep(300);
  }
  fs.writeFileSync(outPath, '', 'utf8');
  for (let i = 0; i < chapterUrls.length; i++) {
    const res = await fetchWithRetry(chapterUrls[i]);
    const chHtml = decodeHtmlBuffer(res.body, res.headers['content-type']);
    const { title, text } = extractHjwzwChapterContent(chHtml);
    const block = (title || ('Chapter ' + (i + 1))) + '\n\n' + text + '\n\n';
    fs.appendFileSync(outPath, block, 'utf8');
    if ((i + 1) % 20 === 0) console.log('  Progress:', i + 1, '/', chapterUrls.length);
    await sleep(300);
  }
  return { path: outPath, size: fs.statSync(outPath).size, chapters: chapterUrls.length };
}

function looksLikeTextContentType(contentType) {
  if (!contentType) return true;
  const ct = contentType.toLowerCase();
  return (
    ct.includes('text/') ||
    ct.includes('application/octet-stream') ||
    ct.includes('application/download') ||
    ct.includes('application/force-download') ||
    ct.includes('application/x-download')
  );
}

function decodeHtmlBuffer(buf, hintCharset) {
  const tryDecode = (enc) => {
    if (enc === 'utf8' || enc === 'utf-8') return buf.toString('utf8');
    if (iconv) return iconv.decode(buf, enc);
    return null;
  };

  let charset = hintCharset;
  if (!charset) {
    const head = buf.slice(0, 4096).toString('latin1');
    const m = head.match(/charset\s*=\s*["']?([\w-]+)/i);
    if (m) charset = m[1].toLowerCase();
  }
  if (charset) {
    if (charset.includes('gb')) {
      const t = tryDecode('gbk');
      if (t) return t;
    }
    if (charset.includes('utf')) return tryDecode('utf8');
    if (iconv) {
      try {
        return iconv.decode(buf, charset);
      } catch {
        /* fall through */
      }
    }
  }

  const utf8 = tryDecode('utf8');
  if (utf8 && !utf8.includes('\uFFFD')) return utf8;
  const gbk = tryDecode('gbk');
  if (gbk) return gbk;
  return utf8 || buf.toString('binary');
}

function stripHtml(text) {
  return text
    .replace(/<script[\s\S]*?<\/script>/gi, '')
    .replace(/<style[\s\S]*?<\/style>/gi, '')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/p>/gi, '\n')
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#(\d+);/g, (_, n) => String.fromCharCode(Number(n)))
    .replace(/&#x([0-9a-fA-F]+);/g, (_, hex) => String.fromCharCode(parseInt(hex, 16)))
    .replace(/\s+\n/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function extractHrefLinks(html, baseUrl) {
  const links = new Set();
  const re = /href\s*=\s*["']([^"'#]+)["']/gi;
  let m;
  while ((m = re.exec(html)) !== null) {
    const href = m[1].trim();
    if (!href || href.startsWith('javascript:')) continue;
    links.add(resolveUrl(baseUrl, href));
  }
  return [...links];
}

function pickDownloadLinks(links) {
  return links.filter((u) => /down|download|\/d\/|\.txt|\/txt\/|\/dl\//i.test(u));
}

async function trySaveBulkDownload(url, outPath, minBytes = MIN_TXT_BYTES) {
  const res = await fetchWithRetry(url);
  const ct = res.headers['content-type'] || '';
  console.log('    GET', url, '->', res.status, res.body.length, 'bytes', ct);
  if (res.status !== 200) return null;
  const isZip = /\.zip/i.test(url) || /zip/i.test(ct);
  const min = isZip ? 50000 : minBytes;
  if (res.body.length < min) return null;
  if (!looksLikeTextContentType(ct) && !/\.txt/i.test(url) && !isZip) return null;
  if (isZip) {
    const zipPath = outPath.replace(/\.txt$/i, '.zip');
    fs.writeFileSync(zipPath, res.body);
    const extracted = extractZipToTxt(res.body, outPath);
    if (extracted) {
      console.log('    Extracted zip entry:', extracted.entry, extracted.size, 'bytes');
      return { path: outPath, size: extracted.size, url, zipPath };
    }
    return { path: zipPath, size: res.body.length, url };
  }
  fs.writeFileSync(outPath, res.body);
  return { path: outPath, size: res.body.length, url };
}

async function sourceIxdzs8() {
  const name = 'ixdzs8.com';
  console.log('\n=== Source 1:', name, '===');
  const bookUrl = 'https://ixdzs8.com/read/526203/';
  const outPath = path.join(OUTPUT_DIR, 'shentanchenyi_ixdzs.txt');
  const candidateUrls = [
    'https://ixdzs8.com/down/526203',
    'https://ixdzs8.com/d/526203',
    'https://ixdzs8.com/download/526203',
    'https://ixdzs8.com/txt/526203',
    'https://ixdzs8.com/down/526203.txt',
    'https://ixdzs8.com/dl/526203',
  ];
  let best = null;

  for (const url of candidateUrls) {
    try {
      const saved = await trySaveBulkDownload(url, outPath);
      if (saved && (!best || saved.size > best.size)) best = saved;
    } catch (e) {
      console.log('    Error:', url, e.message);
      results.errors.push({ source: name, url, error: e.message });
    }
  }

  try {
    console.log('  Fetching book page for download links...');
    const page = await fetchBuffer(bookUrl);
    const html = decodeHtmlBuffer(page.body, page.headers['content-type']);
    const allLinks = extractHrefLinks(html, bookUrl);
    const dlLinks = pickDownloadLinks(allLinks);
    console.log('  Parsed download-like links:', dlLinks.length);
    for (const url of dlLinks.slice(0, 15)) {
      try {
        const saved = await trySaveBulkDownload(url, outPath, 50000);
        if (saved && (!best || saved.size > best.size)) best = saved;
      } catch (e) {
        results.errors.push({ source: name, url, error: e.message });
      }
    }
  } catch (e) {
    console.log('  Book page error:', e.message);
    results.errors.push({ source: name, step: 'book_page', error: e.message });
  }

  if (best) {
    results.sources.push({
      name,
      success: true,
      file: best.path,
      size: best.size,
      url: best.url,
    });
    return best;
  }
  results.sources.push({ name, success: false });
  return null;
}

function extract438ChapterUrls(html, indexUrl) {
  const bookPrefix = '/book/0etlzw/';
  const urls = [];
  const seen = new Set();
  const re = /href\s*=\s*["']([^"']+)["']/gi;
  let m;
  while ((m = re.exec(html)) !== null) {
    let href = m[1];
    if (!href.includes('0etlzw')) continue;
    if (!/\/book\/0etlzw\/.+\.html/i.test(href) && !/\/book\/0etlzw\/\d+/i.test(href)) continue;
    if (/index|list|sort|comment|rss/i.test(href)) continue;
    const full = resolveUrl(indexUrl, href);
    if (seen.has(full)) continue;
    seen.add(full);
    urls.push(full);
  }
  return urls;
}

function extract438ChapterContent(html) {
  const titleMatch =
    html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i) ||
    html.match(/class=["'][^"']*title[^"']*["'][^>]*>([\s\S]*?)<\//i);
  const title = titleMatch ? stripHtml(titleMatch[1]) : '';

  const contentPatterns = [
    /<div[^>]+id=["']content["'][^>]*>([\s\S]*?)<\/div>/i,
    /<div[^>]+class=["'][^"']*content[^"']*["'][^>]*>([\s\S]*?)<\/div>/i,
    /<div[^>]+id=["']chaptercontent["'][^>]*>([\s\S]*?)<\/div>/i,
    /<div[^>]+class=["'][^"']*read-content[^"']*["'][^>]*>([\s\S]*?)<\/div>/i,
    /<article[^>]*>([\s\S]*?)<\/article>/i,
  ];

  let raw = '';
  for (const re of contentPatterns) {
    const m = html.match(re);
    if (m && m[1].length > raw.length) raw = m[1];
  }
  if (!raw) {
    const start = html.search(/id=["']content["']|class=["'][^"']*content/);
    if (start !== -1) raw = html.slice(start, start + 50000);
  }
  const text = stripHtml(raw);
  return { title, text };
}

async function source438xs() {
  const name = '438xs.com';
  console.log('\n=== Source 2:', name, '===');
  const indexUrl = 'https://www.438xs.com/book/0etlzw/';
  const chaptersDir = path.join(OUTPUT_DIR, 'chapters_438xs');
  const combinedPath = path.join(OUTPUT_DIR, 'shentanchenyi_438xs.txt');

  let html;
  let indexBase = indexUrl;
  try {
    const bypass = await bypass438xsGate(indexUrl);
    html = bypass.html;
    indexBase = bypass.finalUrl;
  } catch (e) {
    console.log('  Index fetch failed:', e.message);
    results.errors.push({ source: name, error: e.message });
    results.sources.push({ name, success: false });
    return null;
  }

  let chapterUrls = extract438ChapterUrls(html, indexBase);
  if (chapterUrls.length === 0) {
    const re = /href\s*=\s*["'](\/book\/0etlzw\/[^"']+\.html)["']/gi;
    const seen = new Set();
    let m;
    while ((m = re.exec(html)) !== null) {
      const full = resolveUrl(indexBase, m[1]);
      if (!seen.has(full)) {
        seen.add(full);
        chapterUrls.push(full);
      }
    }
  }

  console.log('  Chapter links found:', chapterUrls.length);
  if (chapterUrls.length === 0) {
    results.sources.push({ name, success: false, chapters: 0 });
    return null;
  }

  const testCount = Math.min(5, chapterUrls.length);
  const testTexts = [];
  for (let i = 0; i < testCount; i++) {
    try {
      const res = await fetchWithRetry(chapterUrls[i]);
      const chHtml = decodeHtmlBuffer(res.body, res.headers['content-type']);
      const { title, text } = extract438ChapterContent(chHtml);
      testTexts.push({ title, len: text.length, url: chapterUrls[i] });
      console.log('  Test chapter', i + 1, title || chapterUrls[i], 'chars:', text.length);
    } catch (e) {
      testTexts.push({ len: 0, error: e.message });
    }
    await sleep(300);
  }

  const ok = testTexts.filter((t) => t.len > 1000).length >= Math.min(3, testCount);
  if (!ok) {
    console.log('  First chapters look like previews or failed; skipping full download.');
    results.sources.push({
      name,
      success: false,
      chapters: testTexts.filter((t) => t.len > 0).length,
      testLengths: testTexts.map((t) => t.len),
    });
    return null;
  }

  fs.mkdirSync(chaptersDir, { recursive: true });
  const parts = [];
  let downloaded = 0;

  for (let i = 0; i < chapterUrls.length; i++) {
    const url = chapterUrls[i];
    const filePath = path.join(chaptersDir, `chapter_${String(i + 1).padStart(4, '0')}.txt`);
    let body;
    if (fs.existsSync(filePath)) {
      body = fs.readFileSync(filePath, 'utf8');
    } else {
      try {
        const res = await fetchWithRetry(url);
        const chHtml = decodeHtmlBuffer(res.body, res.headers['content-type']);
        const { title, text } = extract438ChapterContent(chHtml);
        body = `${title || 'Chapter ' + (i + 1)}\n\n${text}\n`;
        fs.writeFileSync(filePath, body, 'utf8');
        downloaded++;
      } catch (e) {
        results.errors.push({ source: name, chapter: i + 1, url, error: e.message });
        body = '';
      }
      await sleep(300);
    }
    if (body) parts.push(body.trimEnd());
    if ((i + 1) % 20 === 0) {
      console.log(`  Progress: ${i + 1}/${chapterUrls.length} chapters`);
    }
  }

  fs.writeFileSync(combinedPath, parts.join('\n\n') + '\n', 'utf8');
  const size = fs.statSync(combinedPath).size;
  console.log('  Combined file:', combinedPath, size, 'bytes');

  results.sources.push({
    name,
    success: true,
    file: combinedPath,
    size,
    chapters: chapterUrls.length,
    downloadedThisRun: downloaded,
  });
  return { path: combinedPath, size, chapters: chapterUrls.length };
}

function extractHjwzwChapterUrls(html, baseUrl) {
  const urls = [];
  const seen = new Set();
  const re = /href\s*=\s*["']([^"']+)["']/gi;
  let m;
  while ((m = re.exec(html)) !== null) {
    const href = m[1];
    if (!/Book\/49644|book\/49644/i.test(href)) continue;
    if (!/\/\d+\.html|\/read\/|chapter|\/c\d+/i.test(href) && !/\/Book\/49644\/\d+/i.test(href)) {
      if (!/\/Book\/49644\//i.test(href)) continue;
    }
    const full = resolveUrl(baseUrl, href);
    if (seen.has(full)) continue;
    seen.add(full);
    urls.push(full);
  }
  return urls;
}

async function sourceHjwzw() {
  const name = 'tw.hjwzw.com';
  console.log('\n=== Source 3:', name, '===');
  const bookUrl = 'https://tw.hjwzw.com/Book/49644';
  const catalogUrl = 'https://tw.hjwzw.com/Book/Chapter/49644';
  const outPath = path.join(OUTPUT_DIR, 'shentanchenyi_hjwzw.txt');
  let best = null;

  try {
    const page = await fetchWithRetry(bookUrl);
    const html = decodeHtmlBuffer(page.body, page.headers['content-type']);
    const links = extractHrefLinks(html, bookUrl);
    const dlLinks = pickDownloadLinks(links);
    console.log('  Download-like links:', dlLinks.length);
    for (const url of dlLinks.slice(0, 10)) {
      try {
        const saved = await trySaveBulkDownload(url, outPath, 50000);
        if (saved && (!best || saved.size > best.size)) best = saved;
      } catch (e) {
        results.errors.push({ source: name, url, error: e.message });
      }
    }

    if (!best) {
      console.log('  Fetching chapter catalog...');
      const cat = await fetchWithRetry(catalogUrl);
      const catHtml = decodeHtmlBuffer(cat.body, cat.headers['content-type']);
      const chapterPaths = [...catHtml.matchAll(/\/Book\/Read\/49644,\d+/g)].map((m) => m[0]);
      const uniq = [...new Set(chapterPaths)];
      console.log('  Chapters in catalog:', uniq.length);
      if (uniq.length > 0) {
        const dl = await downloadHjwzwChapters(uniq, outPath);
        if (dl) best = { path: dl.path, size: dl.size, chapters: dl.chapters };
      }
    }
  } catch (e) {
    console.log('  Error:', e.message);
    results.errors.push({ source: name, error: e.message });
  }

  if (best) {
    results.sources.push({
      name,
      success: true,
      file: best.path,
      size: best.size,
      chapters: best.chapters || null,
    });
    return best;
  }
  results.sources.push({ name, success: false });
  return null;
}

function choosePrimaryFile() {
  const successes = results.sources.filter((s) => s.success && s.file && s.size);
  if (successes.length === 0) return null;
  successes.sort((a, b) => b.size - a.size);
  const top = successes[0];
  const primaryPath = path.join(OUTPUT_DIR, 'shentanchenyi.txt');
  fs.copyFileSync(top.file, primaryPath);
  results.primaryFile = { from: top.name, path: primaryPath, size: top.size };
  return results.primaryFile;
}

async function main() {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  console.log('Output directory:', OUTPUT_DIR);
  console.log('iconv-lite:', iconv ? 'available' : 'missing');

  await sourceIxdzs8();
  await source438xs();
  await sourceHjwzw();

  const primary = choosePrimaryFile();

  console.log('\n========== SUMMARY ==========');
  for (const s of results.sources) {
    if (s.success) {
      console.log(`[OK] ${s.name}: ${s.file} (${s.size} bytes)` + (s.chapters ? `, chapters=${s.chapters}` : ''));
    } else {
      console.log(`[FAIL] ${s.name}` + (s.chapters != null ? ` (chapters=${s.chapters})` : ''));
    }
  }
  if (primary) {
    console.log(`Primary (largest): ${primary.path} from ${primary.from} (${primary.size} bytes)`);
  } else {
    console.log('No successful downloads; primary file not created.');
  }
  if (results.errors.length) {
    console.log('Errors logged:', results.errors.length);
    console.log(JSON.stringify(results.errors.slice(0, 20), null, 2));
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});