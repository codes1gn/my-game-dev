const https = require('https');
const http = require('http');
const fs = require('fs');
const path = require('path');

const OUTPUT_DIR = path.join(__dirname, '..', 'assets', 'music');

const TRACKS = [
  {
    name: 'bgm_menu',
    url: 'https://opengameart.org/sites/default/files/investigation.ogg',
    desc: 'Investigation by wipics (CC0) - detective loop for main menu'
  },
  {
    name: 'bgm_vn',
    url: 'https://opengameart.org/sites/default/files/Night%20of%20the%20Streets.mp3',
    desc: 'Night of the Streets (CC0) - horror/suspense for VN scenes'
  },
  {
    name: 'bgm_investigation',
    url: 'https://opengameart.org/sites/default/files/dark_cavern_ambient_002.ogg',
    desc: 'Dark Cavern Ambient 002 (CC0) - continuous loop for investigation'
  },
  {
    name: 'bgm_deduction',
    url: 'https://opengameart.org/sites/default/files/ancient_mysteries.ogg',
    desc: 'Ancient Mysteries (CC0) - mysterious melody for deduction board'
  }
];

function download(url, dest, maxRedirects = 5) {
  return new Promise((resolve, reject) => {
    if (maxRedirects <= 0) return reject(new Error('Too many redirects'));
    const mod = url.startsWith('https') ? https : http;
    const opts = {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': '*/*'
      }
    };
    mod.get(url, opts, (res) => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        let loc = res.headers.location;
        if (loc.startsWith('/')) {
          const u = new URL(url);
          loc = u.protocol + '//' + u.host + loc;
        }
        res.resume();
        return download(loc, dest, maxRedirects - 1).then(resolve).catch(reject);
      }
      if (res.statusCode !== 200) {
        res.resume();
        return reject(new Error(`HTTP ${res.statusCode} for ${url}`));
      }
      const file = fs.createWriteStream(dest);
      res.pipe(file);
      file.on('finish', () => { file.close(resolve); });
      file.on('error', reject);
    }).on('error', reject);
  });
}

async function main() {
  if (!fs.existsSync(OUTPUT_DIR)) fs.mkdirSync(OUTPUT_DIR, { recursive: true });

  for (const track of TRACKS) {
    const ext = track.url.match(/\.(ogg|mp3|wav)(\?|$)/i)?.[1] || 'mp3';
    const dest = path.join(OUTPUT_DIR, `${track.name}.${ext}`);
    if (fs.existsSync(dest) && fs.statSync(dest).size > 50000) {
      console.log(`[SKIP] ${track.name}.${ext} (${(fs.statSync(dest).size / 1024).toFixed(0)} KB)`);
      continue;
    }
    console.log(`[DL] ${track.name}.${ext} - ${track.desc}`);
    console.log(`     ${track.url}`);
    try {
      await download(track.url, dest);
      const size = fs.statSync(dest).size;
      if (size < 5000) {
        console.log(`  WARN: too small (${size} bytes), removing`);
        fs.unlinkSync(dest);
      } else {
        console.log(`  OK (${(size / 1024).toFixed(0)} KB)`);
      }
    } catch (e) {
      console.log(`  FAIL: ${e.message}`);
      if (fs.existsSync(dest)) fs.unlinkSync(dest);
    }
  }

  console.log('\n--- Results ---');
  const files = fs.readdirSync(OUTPUT_DIR).filter(f => /\.(mp3|ogg|wav)$/i.test(f));
  for (const f of files) {
    const full = path.join(OUTPUT_DIR, f);
    const stat = fs.statSync(full);
    console.log(`${stat.size > 5000 ? 'OK' : 'BAD'}  ${f} (${(stat.size / 1024).toFixed(0)} KB)`);
  }

  const ok = files.filter(f => fs.statSync(path.join(OUTPUT_DIR, f)).size > 5000).length;
  console.log(`\n${ok}/${TRACKS.length} tracks downloaded successfully`);
}

main().catch(console.error);
