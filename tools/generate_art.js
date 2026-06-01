const https = require('https');
const fs = require('fs');
const path = require('path');

const API_KEY = process.env.POLLINATIONS_KEY || 'sk_Zl3JuVYxxnVpYPFMteqByDtGudF4RLZm';
const BASE_URL = 'https://gen.pollinations.ai';

const STYLE_PREFIX = 'anime visual novel style, high quality, detailed, dramatic lighting, dark moody atmosphere, chinese detective noir,';

const ASSETS = [
  {
    name: 'chen_yi_portrait',
    output: '../assets/portraits/chen_yi.png',
    prompt: `${STYLE_PREFIX} portrait of a young chinese male detective in his late 20s, short black hair, sharp intelligent eyes, wearing a dark blue police uniform shirt, serious determined expression, half body shot, dark background with subtle blue lighting, visual novel character portrait`,
    width: 512, height: 768,
  },
  {
    name: 'zhou_yebin_portrait',
    output: '../assets/portraits/zhou_yebin.png',
    prompt: `${STYLE_PREFIX} portrait of a middle-aged chinese male police captain, around 45 years old, stern authoritative face, slightly graying hair at temples, wearing formal police uniform with captain insignia, arms crossed, half body shot, dark background, visual novel character portrait`,
    width: 512, height: 768,
  },
  {
    name: 'young_officer_portrait',
    output: '../assets/portraits/young_officer.png',
    prompt: `${STYLE_PREFIX} portrait of a young chinese male police officer in his early 20s, energetic appearance, slightly messy hair, wearing standard police uniform, eager but nervous expression, half body shot, dark background, visual novel character portrait`,
    width: 512, height: 768,
  },
  {
    name: 'bg_main_menu',
    output: '../assets/scenes/bg_main_menu.png',
    prompt: `dark atmospheric chinese city night scene, neon signs, rain-slicked streets, fog, moody noir detective atmosphere, cinematic wide angle, no people, dark blue and amber tones, concept art style`,
    width: 1280, height: 720,
  },
  {
    name: 'bg_interrogation',
    output: '../assets/scenes/bg_interrogation.png',
    prompt: `dark interrogation room interior, single overhead lamp casting harsh light on metal table, two chairs facing each other, one-way mirror on wall, concrete walls, dim moody lighting, chinese police station, photorealistic concept art`,
    width: 1280, height: 720,
  },
  {
    name: 'bg_apartment',
    output: '../assets/scenes/bg_apartment.png',
    prompt: `chinese apartment interior crime scene, living room with couch and coffee table, scattered evidence markers, dim lighting, police tape, dark moody atmosphere, forensic investigation scene, overhead blueprint style mixed with photorealistic, concept art`,
    width: 1280, height: 720,
  },
  {
    name: 'bg_apartment_map',
    output: '../assets/scenes/bg_apartment_map.png',
    prompt: `top-down floor plan of a small chinese apartment, blueprint style, dark background with white and amber lines, rooms labeled: living room kitchen bedroom bathroom entrance, evidence markers shown as red dots, crime scene investigation map, clean vector style`,
    width: 880, height: 370,
  },
];

async function generateImage(asset) {
  const encodedPrompt = encodeURIComponent(asset.prompt);
  const url = `${BASE_URL}/image/${encodedPrompt}?model=flux&width=${asset.width}&height=${asset.height}&seed=42&enhance=true&key=${API_KEY}`;

  const outputPath = path.resolve(__dirname, asset.output);
  const dir = path.dirname(outputPath);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });

  return new Promise((resolve, reject) => {
    console.log(`[${asset.name}] Generating...`);
    const file = fs.createWriteStream(outputPath);
    
    const request = https.get(url, { timeout: 120000 }, (res) => {
      if (res.statusCode === 301 || res.statusCode === 302) {
        https.get(res.headers.location, { timeout: 120000 }, (res2) => {
          res2.pipe(file);
          file.on('finish', () => {
            file.close();
            const size = fs.statSync(outputPath).size;
            console.log(`[${asset.name}] Done! ${(size/1024).toFixed(1)} KB -> ${outputPath}`);
            resolve();
          });
        }).on('error', reject);
        return;
      }
      res.pipe(file);
      file.on('finish', () => {
        file.close();
        const size = fs.statSync(outputPath).size;
        console.log(`[${asset.name}] Done! ${(size/1024).toFixed(1)} KB -> ${outputPath}`);
        resolve();
      });
    });
    request.on('error', reject);
    request.on('timeout', () => { request.destroy(); reject(new Error('timeout')); });
  });
}

async function main() {
  console.log(`Generating ${ASSETS.length} assets via Pollinations.ai...`);
  for (const asset of ASSETS) {
    try {
      await generateImage(asset);
    } catch (err) {
      console.error(`[${asset.name}] FAILED: ${err.message}`);
    }
  }
  console.log('All done!');
}

main();
