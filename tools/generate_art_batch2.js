const https = require('https');
const fs = require('fs');
const path = require('path');

const API_KEY = process.env.POLLINATIONS_KEY || 'sk_Zl3JuVYxxnVpYPFMteqByDtGudF4RLZm';
const BASE_URL = 'https://gen.pollinations.ai';

const CHAR_STYLE = 'anime visual novel style, high quality, detailed, dramatic lighting, dark moody atmosphere, chinese detective noir,';
const SCENE_STYLE = 'high quality concept art, moody atmospheric lighting, cinematic,';

const ASSETS = [
  {
    name: 'forensic_doctor',
    output: '../assets/portraits/forensic_doctor.jpg',
    prompt: `${CHAR_STYLE} portrait of a chinese female forensic pathologist in her early 30s, long black hair tied in a ponytail, wearing white lab coat over dark clothes, calm analytical expression, half body shot, dark background with cold blue lighting, visual novel character portrait`,
    width: 512, height: 768,
  },
  {
    name: 'assistant_officer',
    output: '../assets/portraits/assistant_officer.jpg',
    prompt: `${CHAR_STYLE} portrait of a chinese male police detective in his mid 30s, medium build, neat short hair, wearing dark detective coat over shirt, friendly but sharp expression, slight smile, half body shot, dark background, visual novel character portrait`,
    width: 512, height: 768,
  },
  {
    name: 'suspect_npc',
    output: '../assets/portraits/suspect_npc.jpg',
    prompt: `${CHAR_STYLE} portrait of a nervous chinese middle-aged man in his 40s, slightly disheveled hair, wearing casual civilian clothes, anxious sweating expression, looking away from camera, half body shot, dark background, visual novel character portrait`,
    width: 512, height: 768,
  },
  {
    name: 'bg_police_office',
    output: '../assets/scenes/bg_police_office.jpg',
    prompt: `${SCENE_STYLE} interior of a modern chinese police detective office, cluttered desk with case files and monitors, dim desk lamp, fluorescent ceiling lights off, nighttime atmosphere, evidence boards on wall with photos and string connections, dark moody lighting`,
    width: 1280, height: 720,
  },
  {
    name: 'bg_city_day',
    output: '../assets/scenes/bg_city_day.jpg',
    prompt: `${SCENE_STYLE} chinese city street daytime scene, warm afternoon sunlight filtering through buildings, small shops and restaurants lining the street, a few people walking, urban slice of life atmosphere, mild overcast sky, photorealistic`,
    width: 1280, height: 720,
  },
  {
    name: 'bg_canteen',
    output: '../assets/scenes/bg_canteen.jpg',
    prompt: `${SCENE_STYLE} interior of a chinese police station canteen, simple tables and chairs, warm fluorescent lighting, food counter with metal trays, a few officers eating in background, lunchtime atmosphere, slice of life`,
    width: 1280, height: 720,
  },
  {
    name: 'bg_dormitory',
    output: '../assets/scenes/bg_dormitory.jpg',
    prompt: `${SCENE_STYLE} simple chinese police dormitory room at night, single bed with dark sheets, small desk with reading lamp on, stack of case files, window showing city lights outside, minimalist and moody, warm lamp glow contrasting cold moonlight`,
    width: 1280, height: 720,
  },
  {
    name: 'bg_lab',
    output: '../assets/scenes/bg_lab.jpg',
    prompt: `${SCENE_STYLE} forensic laboratory interior, sterile white and blue lighting, examination tables, microscopes, evidence bags on shelves, computer screens showing analysis data, clean and clinical atmosphere, subtle detective noir tone`,
    width: 1280, height: 720,
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
  console.log(`Generating ${ASSETS.length} assets (batch 2)...`);
  for (const asset of ASSETS) {
    try {
      await generateImage(asset);
    } catch (err) {
      console.error(`[${asset.name}] FAILED: ${err.message}`);
    }
  }
  console.log('Batch 2 complete!');
}

main();
