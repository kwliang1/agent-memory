---
name: audio-transcription-uvx-whisper
description: "How to transcribe an audio clip (Slack/Discord voice memo) locally — no STT tool installed by default, use uvx mlx-whisper."
metadata: 
  node_type: memory
  type: reference
  originSessionId: 2cc959b9-7b6d-4c0f-bc9c-486641c0ae8d
  modified: 2026-08-22T00:31:18.352Z
---

Kevin's env (arm64 Mac) has **no speech-to-text tool** by default — only `ffmpeg`; the Read tool can't ingest audio. To transcribe a voice memo:

1. Download the attachment (discord/slack plugin `download_attachment(chat_id, message_id)` → local path, or it's pre-downloaded).
2. `ffmpeg -y -i clip.m4a -ar 16000 -ac 1 -c:a pcm_s16le /tmp/clip.wav` (optional; whisper decodes m4a directly too).
3. `uvx --from mlx-whisper mlx_whisper /tmp/clip.wav --model mlx-community/whisper-base.en-mlx --output-dir /tmp --output-format txt` → reads `/tmp/clip.wav.txt`.

`uvx` is at `/Users/kevin/.local/bin/uvx` (ephemeral env, no install pollution). First run pulls the package + model (~150MB, HF cache) — run it `run_in_background`. mlx-whisper is Apple-Silicon-optimized (lighter than openai-whisper/torch). base.en is fast + accurate enough for a 1-min memo. **Ask Kevin before running** (it's a network install), but he's fine with it. Worked cleanly on a 60s clip for BANK-1858.
