---
name: osc-7501-program-status-spike
description: OSC 7501 needs a pty shim under tmux (pipe-pane loses the probe race); DROPPED 2026-11-05 — sessions/<pid>.json already gives status + waitingFor
metadata:
  type: project
---

Spike 2026-11-04 (CC 2.1.318, tmux 3.4). Scripts: session scratchpad `osc/shim.py`, `osc/relay.py`.

- CC sends `\e[>0q\e[?u\e]7501;?\a\e[c` in one write after first render. It enables programStatus only if an OSC 7501 `?` reply arrives before the DA1 (`\e[c`) reply. No env var forces it on (only CLAUDE_CODE_DISABLE_TERMINAL_TITLE / SESSION_KIND=bg force it off).
- `tmux pipe-pane -IO` relay: sees the probe and replies at the same timestamp, but tmux has already answered DA1 itself → `programStatus=no (probe: no reply to OSC 7501 ; ?)`. Dead end.
- A pty shim between tmux and claude (python `pty.fork`, reply before forwarding output) → `programStatus=yes`. Log: idle → working → working+msg → `blocked:kind=permission:msg=<b64 "approve Bash: touch hello.txt">` → working → done → `state=clear` ×3 on /exit. The trust dialog emitted nothing.
- Hydra's launch path doesn't disable it: this session's spawn log contains the `\e]7501;?` probe. Hydra already uses each pane's single pipe-pane slot for spawn logs (`daemon/engines/claude-engine.ts:326`), which is one more reason to use a shim over pipe-pane.

Untested: login/usage-limit/plan-mode records, `--resume` relaunch, resize under the shim.

**Decision 2026-11-05 (Kevin): dropped.** Bun 1.4.2's `Bun.spawn({ terminal })` gives a native pty, so a bun shim is feasible (no python needed). But CC's `<config>/sessions/<pid>.json` already carries `status` (busy/idle/waiting) + `waitingFor`, read by `daemon/engines/claude-status.ts` and shown on Home (#501). 7501 only adds done/error/progress/title, at the cost of a process in front of every session (shim crash = session dies). Revisit only for a signal the pid json lacks.
