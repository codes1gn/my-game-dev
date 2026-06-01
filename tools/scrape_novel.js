/**
 * Scrape chapters 1-25 of 神探陳益 from ttkan.co
 */
const fs = require('fs/promises');
const path = require('path');

const BASE_URL =
  'https://www.ttkan.co/novel/pagea/shentanchenyi-qinfendeguanguan_{N}.html';
const OUT_DIR = path.join(__dirname, '..', 'data', 'novel');
const FIRST_CHAPTER = 1;
const LAST_CHAPTER = 25;
const DELAY_MS = 2000;

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function decodeHtmlEntities(text) {
  return text
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&#x([0-9a-fA-F]+);/g, (_, hex) =>
      String.fromCodePoint(parseInt(hex, 16))
    )
    .replace(/&#(\d+);/g, (_, num) => String.fromCodePoint(Number(num)));
}

function stripTags(html) {
  return decodeHtmlEntities(html.replace(/<[^>]+>/g, '')).trim();
}

function extractChapter(html) {
  const h1Match = html.match(/<div class="title"[^>]*>\s*<h1[^>]*>([\s\S]*?)<\/h1>/i);
  let title = h1Match ? stripTags(h1Match[1]) : '';

  if (!title) {
    const titleTag = html.match(/<title>([\s\S]*?)<\/title>/i);
    if (titleTag) {
      title = stripTags(titleTag[1])
        .replace(/^⚡\s*/, '')
        .replace(/\s*-\s*天天看小說\s*$/, '')
        .trim();
    }
  }

  const contentMatch = html.match(
    /<div class="content"[^>]*>([\s\S]*?)(?=<div class="social_share_frame")/i
  );
  if (!contentMatch) {
    throw new Error('Could not find chapter content block');
  }

  const contentHtml = contentMatch[1];
  const paragraphs = [];
  const pRegex = /<p[^>]*>([\s\S]*?)<\/p>/gi;
  let p;
  while ((p = pRegex.exec(contentHtml)) !== null) {
    const line = stripTags(p[1]);
    if (line) paragraphs.push(line);
  }

  if (paragraphs.length === 0) {
    const fallback = stripTags(contentHtml);
    if (!fallback) throw new Error('Chapter body is empty');
    paragraphs.push(...fallback.split(/\n+/).map((s) => s.trim()).filter(Boolean));
  }

  const body = paragraphs.join('\n\n');
  if (!title || !body) {
    throw new Error('Missing title or body after parse');
  }

  return { title, body };
}

async function fetchHtml(url) {
  const res = await fetch(url, {
    headers: {
      'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      Accept: 'text/html,application/xhtml+xml',
    },
  });
  if (!res.ok) {
    throw new Error(`HTTP ${res.status} for ${url}`);
  }
  return res.text();
}

async function fetchWithRetry(url) {
  try {
    return await fetchHtml(url);
  } catch (err) {
    console.warn(`Retry after failure: ${url} (${err.message})`);
    await sleep(1000);
    return fetchHtml(url);
  }
}

async function main() {
  await fs.mkdir(OUT_DIR, { recursive: true });

  const results = [];

  for (let n = FIRST_CHAPTER; n <= LAST_CHAPTER; n++) {
    const url = BASE_URL.replace('{N}', String(n));
    const outFile = path.join(OUT_DIR, `chapter_${String(n).padStart(3, '0')}.txt`);

    console.log(`Fetching chapter ${n}...`);
    const html = await fetchWithRetry(url);
    const { title, body } = extractChapter(html);
    const fileContent = `${title}\n\n${body}\n`;
    await fs.writeFile(outFile, fileContent, 'utf8');

    results.push({
      n,
      title,
      chars: fileContent.length,
      outFile,
    });

    if (n < LAST_CHAPTER) {
      await sleep(DELAY_MS);
    }
  }

  const totalChars = results.reduce((sum, r) => sum + r.chars, 0);
  console.log('\n=== Summary ===');
  console.log(`Chapters saved: ${results.length}`);
  console.log(`Total characters: ${totalChars}`);
  console.log('Titles:');
  for (const r of results) {
    console.log(`  ${String(r.n).padStart(2, '0')}. ${r.title}`);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
