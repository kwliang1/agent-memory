---
name: hydra-restart-orphans-threads
description: "A hydra daemon restart can drop sessions from the registry, orphaning their threads — Kevin's messages there fall back to main with a bare chat_id, which mimics the stripped-suffix bug"
metadata:
  node_type: memory
  type: project
---

After a `hydra restart <platform>`, some sessions can fail to re-register. Their threads are left
**orphaned**: `threadToSession` has no key for them, so anything Kevin types in that thread falls
back to **main** and arrives tagged with a bare `chat_id` (no `:ts`).

That looks *identical* to the stripped-suffix failure in [[reply-chat-id-must-be-thread]] — and on
2026-09-27 I misdiagnosed it as exactly that, then compounded it by blaming a specific PR (#387,
DM-recipient caching). Both wrong. Don't infer the cause from top-level history alone.

**Diagnose from the daemon's own log, not by inference.** `daemon/router.ts` prints one line per
inbound thread message to `$HYDRA_LOG` (`/Users/kevin/hydra-slack-daemon.log`):

```
daemon: thread routing: channelId=… effectiveThreadId=… resolvedThreadId=… mappedSession=… threadToSession keys=[…]
```

- `effectiveThreadId` intact + `mappedSession=none` → **orphaned thread**, suffix is fine.
- `effectiveThreadId` missing the `:ts` → genuinely stripped; that's the other bug.

**`hydra health` lies about this.** It reported `30 sessions (30 connected)` while `hydra list` and
`list_sessions` both showed 28 — the two missing ones were exactly the orphaned threads. Trust the
session list and the `threadToSession` keys, not the health count.

**Fix is `respawn` in that thread, never `handoff`.** `handleHandoffIntercept`
(`daemon/commands/thread.ts:667-674`) resolves `registry.getByThread(threadId)` first and errors
`no live session in this thread` when there is none — its own message tells you to respawn.
`respawn` rebuilds a session from the thread history.

Also seen that night: three `daemon: listening on …` boots in the log tail when only one restart was
issued, so grep the boot markers before assuming your restart was the only one.

**Name reuse hides the loss (2026-09-28).** Hydra draws session names from a fixed pool, so a name
freed by a death gets reassigned to the next spawn — on a *different* thread. Kevin's
`pixel` ("treasury: BANK-2092") died at 38h of context, and 64s later a BANK-1897 respawn came up
as `pixel` too. The session list still showed a `pixel`, so nothing looked wrong; the treasury
thread was silently orphaned.

So **a name present in `hydra list` does not prove that session survived.** Match on `thread_id`,
never on name. To audit real losses, read the exit logs
(`~/.claude/channels/slack/spawn-logs/exit-<name>-<uuid>.log`) — `wall_clock` tells you how much
context died with it.

Standing unknown as of 2026-09-28: sessions die steadily with `exit_code=1` and the
`nonBlockingStdout: uninstalling (Error: EIO)` signature and **no logged reason** — 8 in 19h,
several 27-38h old. Not root-caused. The missing kill logging above is why.
