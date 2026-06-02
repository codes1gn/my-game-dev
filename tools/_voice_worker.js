const { Communicate } = require('edge-tts-universal');
const fs = require('fs');

const [,, text, voice, rate, pitch, outFile] = process.argv;

(async () => {
  const comm = new Communicate(text, { voice, rate, pitch, volume: '+0%' });
  const chunks = [];
  for await (const chunk of comm.stream()) {
    if (chunk.type === 'audio') {
      chunks.push(chunk.data);
    }
  }
  fs.writeFileSync(outFile, Buffer.concat(chunks));
})().catch(e => {
  process.stderr.write(e.message);
  process.exit(1);
});
