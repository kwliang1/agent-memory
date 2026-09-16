---
name: hydra-parked-main-recovery
description: TODO/design idea — auto-detect + recover the parked main bot (slack-byte) and stop silently losing the message stuck in its input buffer on restart
metadata: 
  node_type: memory
  type: project
  originSessionId: b8de99f2-fc23-43eb-9091-530404697b77
---

Idea raised by Kevin 2026-07-02: add cleanup / auto-recovery for the "main bot parks" failure mode (documented in [[hydra-session-resurrection]]). Today when the main bridge `slack-byte` parks — idle at ~0% CPU with an inbound Slack message sitting unprocessed in its `❯` input (the bridge delivers messages as an mcp notification; a fully-idle session doesn't reliably start a new turn) — the only reliable fix is `./start-slack-byte.sh`, which **loses the pending message** because it lived only in the input buffer and never became a turn. Recovery is manual and lossy: on 2026-07-02 the bot sat parked ~30 min (👀 delivered, no reply), then needed a restart AND a manual re-send of the stuck "clear atlas and spark" command.

Approaches to explore when picked up:
- **Detect:** the daemon already applies the 👀 ack at delivery — flag a main-session message that got 👀 but produced no reply/turn within N seconds as "parked."
- **Preserve + replay:** persist delivered-but-unanswered inbound messages so a `slack-byte` restart re-injects them instead of dropping them (nothing persists the input-buffer message today).
- **Auto-restart:** a watchdog for the main bridge (analogous to `watchdog.sh` for the daemon) that restarts `slack-byte` on park and replays the pending message.

**Why:** the current recovery is manual, slow, and silently drops the user's message — bad UX for the primary bot, and the failure mode recurs after every daemon restart.
**How to apply:** re-confirm the current delivery/ack lifecycle (deliverToSession + the ackReaction) before wiring detection — the file:line refs in [[hydra-session-resurrection]] are pre-rebase and likely stale, so re-grep `bridge.ts`/`router.ts` on latest main.

See [[hydra-session-resurrection]] (the park gotcha + resurrection flow), [[hydra-rebase-followups]].
