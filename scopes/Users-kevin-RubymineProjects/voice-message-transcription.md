---
name: voice-message-transcription
description: "How to transcribe Slack/Discord voice messages — local hydra sidecar, no external upload"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 0187402c-9918-4470-a8c3-1a93113b9830
---

Kevin sends voice memos (`.m4a`, audio/mp4). Transcribe them via the **local** hydra transcription sidecar — do NOT claim "no transcription available," and do NOT upload his audio to an external service.

- Sidecar: `http://127.0.0.1:8123/transcribe` (default; `HYDRA_TRANSCRIBE_URL` overrides). Parakeet-MLX on Apple Silicon, on-box. Managed by `~/RubymineProjects/hydra/start-transcribe.sh` (tmux session `hydra-transcribe`); client is `hydra/daemon/transcription.ts`.
- Download the attachment first (`download_attachment(chat_id, message_id)` → path in `~/.claude/channels/slack/inbox/`), then:
  `curl -s -m 120 -F "audio=@<path>;type=audio/mp4" http://127.0.0.1:8123/transcribe` → returns JSON `{"text": "..."}`.
- Multipart field name is `audio`; response `.text` is the transcript. `/` returns 404 (only `/transcribe` is a route) — that still means the server is up.
- If the sidecar isn't running, `start-transcribe.sh` (or `--auto`) brings it up; setup is `transcribe-server/setup.sh` (one-time, creates `.venv`).
