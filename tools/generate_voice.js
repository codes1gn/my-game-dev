const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const VOICE_MAP = {
  'narrator':   { voice: 'zh-CN-YunxiNeural',    rate: '-10%', pitch: '-5Hz' },
  '陈益':       { voice: 'zh-CN-YunyangNeural',   rate: '+0%',  pitch: '+0Hz' },
  'chen_yi':    { voice: 'zh-CN-YunyangNeural',   rate: '+0%',  pitch: '+0Hz' },
  '周业斌':     { voice: 'zh-CN-YunjianNeural',    rate: '-5%',  pitch: '-8Hz' },
  'zhou_yebin': { voice: 'zh-CN-YunjianNeural',    rate: '-5%',  pitch: '-8Hz' },
  '青年警员':   { voice: 'zh-CN-YunxiaNeural',      rate: '+5%',  pitch: '+3Hz' },
  '法医':       { voice: 'zh-CN-XiaoyiNeural',     rate: '-5%',  pitch: '+0Hz' },
  '助手':       { voice: 'zh-CN-XiaomoNeural',     rate: '+0%',  pitch: '+0Hz' },
};

const DEFAULT_VOICE = { voice: 'zh-CN-YunxiNeural', rate: '+0%', pitch: '+0Hz' };

const DIALOGUE_DIR = path.join(__dirname, '..', 'data', 'dialogue');
const OUTPUT_BASE = path.join(__dirname, '..', 'assets', 'voice', 'case_001');
const WORKER = path.join(__dirname, '_voice_worker.js');

function getPrefix(filename) {
  return filename.replace('.json', '').replace('case_001_', '');
}

function main() {
  if (!fs.existsSync(OUTPUT_BASE)) fs.mkdirSync(OUTPUT_BASE, { recursive: true });

  const files = fs.readdirSync(DIALOGUE_DIR)
    .filter(f => f.startsWith('case_001') && f.endsWith('.json'))
    .sort();

  console.log(`Found ${files.length} dialogue files for Case 1\n`);

  let totalGen = 0;
  let totalSkip = 0;
  let totalFail = 0;

  for (const file of files) {
    const filePath = path.join(DIALOGUE_DIR, file);
    const data = JSON.parse(fs.readFileSync(filePath, 'utf-8'));
    const nodes = data.nodes || [];
    const prefix = getPrefix(file);

    console.log(`--- ${file} (${nodes.filter(n => n.type === 'text').length} text nodes) ---`);

    for (const node of nodes) {
      if (node.type !== 'text' || !node.text) continue;

      const speaker = node.speaker || 'narrator';
      const nodeId = node.id || `node_${totalGen}`;
      const outFile = path.join(OUTPUT_BASE, `${prefix}_${nodeId}.mp3`);

      if (fs.existsSync(outFile) && fs.statSync(outFile).size > 1000) {
        totalSkip++;
        continue;
      }

      const voiceCfg = VOICE_MAP[speaker] || DEFAULT_VOICE;
      const text = node.text.replace(/[（）]/g, '');

      try {
        execFileSync('node', [WORKER, text, voiceCfg.voice, voiceCfg.rate, voiceCfg.pitch, outFile], {
          timeout: 30000,
          stdio: ['pipe', 'pipe', 'pipe'],
        });
        const size = fs.statSync(outFile).size;
        if (size < 500) {
          fs.unlinkSync(outFile);
          throw new Error('Audio too small');
        }
        totalGen++;
        console.log(`  [${totalGen}] ${prefix}_${nodeId}.mp3 (${(size / 1024).toFixed(0)} KB) [${speaker}]`);
      } catch (e) {
        totalFail++;
        console.log(`  FAIL: ${prefix}_${nodeId} - ${e.message.split('\n')[0]}`);
      }
    }
  }

  console.log(`\n=== Done: ${totalGen} generated, ${totalSkip} skipped, ${totalFail} failed ===`);
  const allFiles = fs.readdirSync(OUTPUT_BASE).filter(f => f.endsWith('.mp3'));
  console.log(`Total files in output: ${allFiles.length}`);
}

main();
