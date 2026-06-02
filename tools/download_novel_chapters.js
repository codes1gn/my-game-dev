'use strict';

const fs = require('fs');
const path = require('path');
const https = require('https');

const BOOK_ID = '1047937059';
const TOTAL_CHAPTERS = 821;
const BASE_URL = `https://mwenku.read.qq.com/read/${BOOK_ID}`;
const CHAPTERS_DIR = path.join(__dirname, '..', 'novel_data', 'chapters');
const COMBINED_FILE = path.join(__dirname, '..', 'novel_data', 'shentanchenyi_full.txt');
const USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';
const DELAY_MS = 500;

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function stripHtml(text) {
  return text
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#(\d+);/g, (_, n) => String.fromCharCode(Number(n)))
    .replace(/&#x([0-9a-fA-F]+);/g, (_, hex) => String.fromCharCode(parseInt(hex, 16)))
    .trim();
}

function fetchChapter(chapterNumber) {
  const url = `${BASE_URL}/${chapterNumber}`;
  return new Promise((resolve, reject) => {
    const req = https.get(
      url,
      {
        headers: {
          'User-Agent': USER_AGENT,
          Accept: 'text/html,application/xhtml+xml',
        },
      },
      (res) => {
        if (res.statusCode && res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
          res.resume();
          reject(new Error(`HTTP redirect ${res.statusCode} for chapter ${chapterNumber}`));
          return;
        }
        if (res.statusCode !== 200) {
          res.resume();
          reject(new Error(`HTTP ${res.statusCode} for chapter ${chapterNumber}`));
          return;
        }
        let data = '';
        res.setEncoding('utf8');
        res.on('data', (chunk) => {
          data += chunk;
        });
        res.on('end', () => resolve(data));
      }
    );
    req.on('error', reject);
    req.setTimeout(60000, () => {
      req.destroy(new Error(`Timeout for chapter ${chapterNumber}`));
    });
  });
}

function extractChapter(html) {
  const h1Match = html.match(/<h1 class="chapter-title"[^>]*>([\s\S]*?)<\/h1>/);
  if (!h1Match) {
    return { error: 'missing h1 title' };
  }
  const title = stripHtml(h1Match[1]);
  const contentStart = html.indexOf('<div class="isTxt chapter-content"');
  if (contentStart === -1) {
    return { title, paragraphs: [], error: 'missing chapter content' };
  }

  let contentEnd = html.indexOf('本周热推', contentStart);
  if (contentEnd === -1) contentEnd = html.indexOf('read-pagination', contentStart);
  if (contentEnd === -1) contentEnd = html.indexOf('class="comment"', contentStart);

  const section = html.slice(contentStart, contentEnd === -1 ? html.length : contentEnd);
  const paragraphs = [...section.matchAll(/<p[^>]*>([\s\S]*?)<\/p>/g)]
    .map((m) => stripHtml(m[1]))
    .filter((t) => t.length > 0);

  return { title, paragraphs };
}

function chapterFilePath(chapterNumber) {
  return path.join(CHAPTERS_DIR, `chapter_${String(chapterNumber).padStart(3, '0')}.txt`);
}

function formatChapterFile({ title, paragraphs }) {
  return `${title}\n\n${paragraphs.join('\n\n')}\n`;
}

async function downloadAll() {
  fs.mkdirSync(CHAPTERS_DIR, { recursive: true });

  const errors = [];
  let downloadedThisRun = 0;
  let skipped = 0;

  for (let n = 1; n <= TOTAL_CHAPTERS; n++) {
    const filePath = chapterFilePath(n);
    if (fs.existsSync(filePath)) {
      skipped++;
      if (n % 10 === 0) {
        console.log(`Progress: chapter ${n}/${TOTAL_CHAPTERS} (skipped existing)`);
      }
      continue;
    }

    try {
      const html = await fetchChapter(n);
      const extracted = extractChapter(html);
      if (extracted.error) {
        errors.push({ chapter: n, error: extracted.error, title: extracted.title || null });
      }
      const body = formatChapterFile({
        title: extracted.title || `Chapter ${n}`,
        paragraphs: extracted.paragraphs || [],
      });
      fs.writeFileSync(filePath, body, 'utf8');
      downloadedThisRun++;
      if (n % 10 === 0) {
        console.log(`Progress: chapter ${n}/${TOTAL_CHAPTERS} (downloaded ${downloadedThisRun}, skipped ${skipped})`);
      }
    } catch (err) {
      errors.push({ chapter: n, error: err.message });
      console.error(`Error chapter ${n}: ${err.message}`);
    }

    await sleep(DELAY_MS);
  }

  const parts = [];
  for (let n = 1; n <= TOTAL_CHAPTERS; n++) {
    const filePath = chapterFilePath(n);
    if (fs.existsSync(filePath)) {
      parts.push(fs.readFileSync(filePath, 'utf8').trimEnd());
    }
  }
  fs.writeFileSync(COMBINED_FILE, `${parts.join('\n\n')}\n`, 'utf8');

  let totalBytes = 0;
  let fileCount = 0;
  for (let n = 1; n <= TOTAL_CHAPTERS; n++) {
    const filePath = chapterFilePath(n);
    if (fs.existsSync(filePath)) {
      totalBytes += fs.statSync(filePath).size;
      fileCount++;
    }
  }

  const combinedBytes = fs.existsSync(COMBINED_FILE) ? fs.statSync(COMBINED_FILE).size : 0;

  console.log('\n=== Download complete ===');
  console.log(`Chapter files present: ${fileCount}/${TOTAL_CHAPTERS}`);
  console.log(`Downloaded this run: ${downloadedThisRun}`);
  console.log(`Skipped (already existed): ${skipped}`);
  console.log(`Total chapter files size: ${totalBytes} bytes (${(totalBytes / 1024 / 1024).toFixed(2)} MiB)`);
  console.log(`Combined file size: ${combinedBytes} bytes (${(combinedBytes / 1024 / 1024).toFixed(2)} MiB)`);
  console.log(`Errors: ${errors.length}`);
  if (errors.length) {
    console.log(JSON.stringify(errors, null, 2));
  }
}

downloadAll().catch((err) => {
  console.error(err);
  process.exit(1);
});