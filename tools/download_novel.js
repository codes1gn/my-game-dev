const https = require('https');
const http = require('http');
const fs = require('fs');
const path = require('path');

const OUTPUT_DIR = path.join(__dirname, '..', 'novel_data');
const OUTPUT_FILE = path.join(OUTPUT_DIR, 'shentanchenyi.txt');

function fetch(url, redirectCount = 0) {
  return new Promise((resolve, reject) => {
    if (redirectCount > 5) return reject(new Error('Too many redirects'));
    const mod = url.startsWith('https') ? https : http;
    mod.get(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'text/html,application/xhtml+xml,*/*',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      },
      timeout: 15000,
    }, res => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        let next = res.headers.location;
        if (next.startsWith('/')) {
          const u = new URL(url);
          next = u.protocol + '//' + u.host + next;
        }
        return resolve(fetch(next, redirectCount + 1));
      }
      let data = [];
      res.on('data', c => data.push(c));
      res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body: Buffer.concat(data) }));
    }).on('error', reject);
  });
}

async function tryCuoceng() {
  console.log('Trying cuoceng.com...');
  const bookId = '1f7d0c2f-5c82-4627-a2d6-623bacff9c5c';
  const txtUrl = `https://www.cuoceng.com/down/txt/${bookId}`;
  const epubUrl = `https://www.cuoceng.com/down/epub/${bookId}`;

  for (const url of [txtUrl, epubUrl]) {
    try {
      console.log('  Trying:', url);
      const res = await fetch(url);
      console.log('  Status:', res.status, 'Size:', res.body.length, 'Content-Type:', res.headers['content-type']);
      if (res.status === 200 && res.body.length > 100000) {
        const ext = url.includes('epub') ? '.epub' : '.txt';
        const outPath = path.join(OUTPUT_DIR, 'shentanchenyi' + ext);
        fs.writeFileSync(outPath, res.body);
        console.log('  Downloaded to:', outPath, `(${(res.body.length / 1024 / 1024).toFixed(1)} MB)`);
        return true;
      }
    } catch (e) {
      console.log('  Error:', e.message);
    }
  }
  return false;
}

async function tryTxl1() {
  console.log('Trying txl1.com...');
  const urls = [
    'https://www.txl1.com/d/476111.txt',
    'https://www.txl1.com/down/476111.txt',
    'https://www.txl1.com/download/476111.txt',
    'https://www.txl1.com/d/476111',
  ];
  for (const url of urls) {
    try {
      console.log('  Trying:', url);
      const res = await fetch(url);
      console.log('  Status:', res.status, 'Size:', res.body.length);
      if (res.status === 200 && res.body.length > 100000) {
        fs.writeFileSync(OUTPUT_FILE, res.body);
        console.log('  Downloaded!', `(${(res.body.length / 1024 / 1024).toFixed(1)} MB)`);
        return true;
      }
    } catch (e) {
      console.log('  Error:', e.message);
    }
  }
  return false;
}

async function tryYzzw() {
  console.log('Trying yzzw.org chapter-by-chapter...');
  const indexUrl = 'https://www.yzzw.org/info/1506225/';
  try {
    const res = await fetch(indexUrl);
    const html = res.body.toString('utf-8');
    const chapterPattern = /href="(\/read\/1506225\/\d+\.html)"/g;
    const chapters = [];
    let match;
    while ((match = chapterPattern.exec(html)) !== null) {
      chapters.push('https://www.yzzw.org' + match[1]);
    }
    console.log(`  Found ${chapters.length} chapter links`);
    if (chapters.length > 0) {
      console.log('  First few:', chapters.slice(0, 3));
      console.log('  (Chapter-by-chapter download needs separate implementation)');
      return { chapters };
    }
  } catch (e) {
    console.log('  Error:', e.message);
  }
  return false;
}

async function main() {
  if (!fs.existsSync(OUTPUT_DIR)) fs.mkdirSync(OUTPUT_DIR, { recursive: true });

  if (await tryCuoceng()) return;
  if (await tryTxl1()) return;
  const yzzw = await tryYzzw();
  if (yzzw && yzzw.chapters) {
    console.log('\nBulk TXT download not available. Found chapter URLs on yzzw.org.');
    console.log('Total chapters found:', yzzw.chapters.length);
    fs.writeFileSync(
      path.join(OUTPUT_DIR, 'chapter_urls.json'),
      JSON.stringify(yzzw.chapters, null, 2)
    );
    console.log('Saved chapter URLs to novel_data/chapter_urls.json');
  } else {
    console.log('\nAll download attempts failed.');
  }
}

main().catch(console.error);
