---
name: reference_hydra_transcribe_sidecar
description: "Transcribe Slack/Discord voice notes via hydra's local sidecar on 127.0.0.1:8123 — there is no whisper binary on this machine"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 7cfb79ad-23f4-49ce-95c2-df8be09f146d
  modified: 2026-09-18T05:42:08.779Z
---

Voice notes arrive as `.m4a` attachments the Read tool rejects as binary, and this machine has **no
STT binary** (`whisper`, `whisper-cpp`, `whisper-cli`, `insanely-fast-whisper` are all absent; only
`ffmpeg`, which converts but does not transcribe). Don't tell the user transcription is unavailable
— hydra runs a sidecar:

```
curl -s -X POST -F "audio=@/path/to/file.m4a" http://127.0.0.1:8123/transcribe | jq -r .text
curl -s http://127.0.0.1:8123/health     # reports the loaded backend
```

Backend is `mlx-community/parakeet-tdt-0.6b-v3` via `parakeet-mlx` — **parakeet, not whisper**. A few
seconds for a ~600KB clip. Fallback if the sidecar is down: `uvx mlx-whisper` (pulls ~150MB on first
run, so prefer the sidecar).

Attachments land in `~/.claude/channels/slack/inbox/` — the bridge pre-downloads them, but the
`<channel>` tag only carries `downloaded_files` sometimes; otherwise call
`download_attachment(chat_id, message_id)` to get the path.

Two addressing traps when asking a peer instead: `"main"` does not resolve from an interactive
session (you *are* main), and the tmux label is not the address — `slack-byte` fails,
`rubymineprojects-11` works. See [[feedback_claude_desktop]].
