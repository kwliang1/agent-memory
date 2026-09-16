---
name: hydra-dictation-pr
description: "Voice dictation PR (kwliang1/hydra #1) finished 2026-07-03: rebased, daemon-integrated, Slack audio, review-hardened; fork-main fast-forward still pending"
metadata: 
  node_type: memory
  type: project
  originSessionId: 4800e7cc-db76-4332-a9d1-a3faa1ba3dfc
---

Voice dictation lives in **fork PR #1 (kwliang1/hydra, branch `feat/voice-dictation-canary-qwen`)** — NOT an sf8193/hydra PR. Finished + force-pushed 2026-07-03: rebased onto origin/main @c27b77b (12 commits, the off-topic `proj:` commit dropped — that's upstream PR #60), sidecar integrated into `hydra up`/`down`/`watchdog` + legacy scripts via `start-transcribe.sh --auto`, Slack audio verified (gateway only filters `bot_message`, so `file_share`/`slack_audio` clips flow through). 4 review rounds (eng/ops/security agents) until 2 clean.

Key design decisions (don't re-litigate): ONE shared tmux session `hydra-transcribe` for all platforms (per-platform sessions raced for port 8123); crashed server **parks** (session alive w/ error) instead of exiting so the watchdog can't model-load crash-loop every 120s — remediation is `tmux kill-session -t hydra-transcribe`; mock backend never auto-supervised (explicit AUTOSTART=1 only); `.env` keys allowlist-extracted (set -a sourcing leaked bot tokens into the sidecar env).

**Pending:** `git push fork origin/main:main` (fast-forward 880e2c4→c27b77b) was denied by the permission classifier (default-branch push) — until Kevin runs/approves it, PR #1's diff shows ~44 upstream commits as noise. Work worktree (removable): `/private/tmp/claude-501/-Users-kevin-RubymineProjects-hydra/4800e7cc-db76-4332-a9d1-a3faa1ba3dfc/scratchpad/hydra-dict`.

**Repo test convention (non-obvious):** `bun test` requires `DISCORD_BOT_TOKEN=dummy` (or slack tokens) + ideally an isolated `HYDRA_STATE_DIR` — daemon tests import `config.ts`, which `process.exit(1)`s without a platform token, killing the suite with no summary. Also: never stub `process.stderr.write` at test-file module level — bun runs all files in one process and it swallows every later file's output (this bug hid the crash in the original PR).

Kevin's live slack daemon (main checkout, [[hydra-rebase-followups]] branch) does NOT have dictation yet — it lands when the PR merges and his branch rebases. Related: [[hydra-slack-setup]].
