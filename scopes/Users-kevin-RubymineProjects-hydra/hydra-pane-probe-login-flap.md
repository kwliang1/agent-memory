---
name: hydra-pane-probe-login-flap
description: "PR #310 fix for pane-probe re-posting login-success/expiring notifications every cycle"
metadata: 
  node_type: memory
  type: project
  originSessionId: b4ce22bc-ebb4-495b-93f3-46a9f84eeacc
  modified: 2026-08-19T20:42:29.456Z
---

Hydra PR #310 (`kevinliang/hydra-pane-probe-login-flap` off main, opened 2026-08-19, NOT merged — needs Kevin's go-ahead + a `hydra restart slack` to deploy). Fixes the daemon `daemon/pane-probe.ts` re-posting `✅ login successful. Press Enter to continue` / `🔑 login expiring soon` to a session thread every probe cycle after the session finished /login and returned to a working `❯` prompt.

Root cause (two compounding): (1) `LOGIN_SUCCESS_RE = /Login successful/` matched the banner in stale scrollback ABOVE a live prompt; (2) login states register no intercept, so `clearState` deleted the probe entry on any active (idle<30s) cycle → next idle re-created it with notifyCount=0, defeating the per-entry cap. `expiring` co-renders with the working prompt so it flapped the same way.

Fixes: `hasLiveReplPrompt(tail)` (bare `❯` line OR `ctx: N%`) gates success/oauth/blocked/expired to null when a working prompt is present (`expiring` intentionally ungated); tightened `LOGIN_SUCCESS_RE` to require "Press Enter to continue"; `clearState(key, now, reason)` where reason='active' preserves a notified intercept-less entry (latch); success+expiring one-shot (effectiveMax=1).

**Why:** the flap is CC-UI-coupled — the 8-line tail captures a login banner sitting above a resumed live prompt. Any future login-detection change must preserve the "is this the live screen, not scrollback" discipline.

**How to apply:** genuine full-screen blocking screens (Select-login-method uses `›` not `❯`; success/oauth/expired have no `ctx:` footer) carry no live-prompt markers, so gating them is safe. Related: [[hydra-reboot-recovery-facts]], [[hydra-session-resurrection]].
