# Voice Acting Roadmap

## Phase 1: Edge TTS (Current -- Free Baseline)

Use Microsoft Edge TTS for initial voice-over. Free, no API key, unlimited usage.

### Speaker-to-Voice Map

| Speaker     | Voice ID               | Gender | Notes                    |
|-------------|------------------------|--------|--------------------------|
| narrator    | zh-CN-YunxiNeural      | Male   | Calm, steady narration   |
| 陈益        | zh-CN-YunyangNeural    | Male   | Protagonist, authoritative |
| 周业斌      | zh-CN-YunjianNeural    | Male   | Partner, gruff/serious   |
| 青年警员    | zh-CN-YunxiaNeural     | Male   | Young officer, energetic |
| 法医        | zh-CN-XiaoyiNeural     | Female | Forensic doctor, professional |
| 助手        | zh-CN-XiaoxiaoNeural   | Female | Assistant, polite        |

### Limitations
- Neutral tone only -- no emotion tags
- Characters may sound similar
- Microsoft preset voices only

---

## Phase 2: Fish Audio S2 Pro (Upgrade)

When ready for higher quality:
- Sign up at https://fish.audio (free tier: 7 min/month)
- Inline emotion: `[angry]`, `[whisper]`, `[excited]`, `[sigh]`
- Voice cloning from 5-second reference clips
- Cost: ~$0.18 per full case, or free tier for 1-2 cases/month
- Node.js SDK: `npm install fish-audio`

---

## Phase 3: GPT-SoVITS (Local, Unlimited)

For scaling to many cases without API costs:
- Clone voices from audiobook samples (1 min each)
- Run locally on NVIDIA GPU (6GB+ VRAM)
- Unlimited generation, fully offline
- Setup: Python + CUDA + ~5GB model downloads

---

## File Structure

```
assets/voice/
  case_001/
    opening_start.mp3        # node id = start
    opening_node2.mp3         # node id = node2
    ...
    investigation_inv_01.mp3
    conclusion_conc_01.mp3
```

Naming: `{dialogue_file_prefix}_{node_id}.mp3`

## Integration

- `AudioManager` handles voice playback on a separate channel from BGM
- `dialogue_box.gd` calls `AudioManager.play_voice(file_path)` when displaying each line
- Voice auto-stops when player advances to next line
- narrator lines use slower rate (-10%), character lines use normal rate
