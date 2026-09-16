---
name: worker-blocking-tui-prompt
description: "A spawned worker using a blocking TUI menu (AskUserQuestion/plan/permission) freezes its pane; Kevin can't interact — unstick via tmux send-keys"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 69d8b83c-f3ea-4100-88e0-384fe2bcfb76
  modified: 2026-08-20T17:16:04.861Z
---

When Kevin says a worker session is "stuck / I can't interact with the prompt," it's often NOT a crash or bridge-drop — the worker hit a **blocking interactive TUI menu** (AskUserQuestion-style choose-list, ExitPlanMode, or a permission prompt) inside its tmux pane. That menu swallows keystrokes until answered with ↑/↓ + Enter, so a normal `reply`/typed instruction can't reach the worker (the input loop is blocked), and Kevin can't easily drive it through the bridge.

**Diagnose:** `peek_session(name)` — you'll see the menu (options with a `❯` cursor, plus a footer like "Enter to select · ↑/↓ to navigate · n to add notes · Esc to cancel").

**Fix (I can drive the pane directly with Bash):**
- Confirm the session: `tmux has-session -t <name>`.
- Read which option is highlighted from the peek. To land deterministically on the top option, send `Up` a couple times (clamps at top), then `Enter`: `tmux send-keys -t <name> Up` then `tmux send-keys -t <name> Enter`. For a lower option, send the right number of `Down` then `Enter`.
- To cancel and return the worker to a normal `❯` prompt (so it takes typed instructions via the thread instead): `tmux send-keys -t <name> Escape`.
- **The choice may be consequential** (2026-08-20: comet's menu offered "take over stack now" which quits Kevin's live overmind). Get Kevin's explicit pick BEFORE sending the selecting keystroke — don't guess a consequential option. Re-peek right before sending to confirm the highlight hasn't moved.

**Prevention:** spawned/build-wt workers should ask via `reply` (non-blocking), NOT via blocking TUI prompts. Worth stating in spawn briefs if it recurs. See [[session-bridge-drop-recovery]], [[worker-posts-to-main-not-thread]].
