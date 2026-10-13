---
name: feedback_no_long_polling_al_console
description: "Never leave a polling loop running against `al console exec` — each invocation can trigger an auth prompt, and a dead console turns it into a prompt every cycle"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 5b1765d3-5f92-4ba1-837c-3b815ee329de
  modified: 2026-09-25T05:31:59.421Z
---

Do not run unattended polling loops that shell out to `al console exec` (or `kubectl exec`
into a console pod). On 2026-09-24 I left one watching for an ACH to settle at ~80s
intervals; it ran 341 times, the console pod died at 01:53Z, and every attempt after that
failed and retried — roughly 62 auth prompts at Kevin over 3.5 hours while he was away.
He asked "why do you keep prompting me for al console access".

**Why:** each `al console exec` can re-trigger SSO / 1Password auth. Fine for a few minutes
of active work, hostile when it runs overnight. A dead or lapsed console makes it worse, not
better — the loop retries forever instead of stopping. Related: [[onepassword-cli-prompts]],
[[treasury-console-pod-stdin-eof-workaround]] (the write console self-terminates, so a
long-lived loop *will* eventually hit a dead pod).

**How to apply:**
- For anything longer than ~10 minutes, don't poll. Ask Kevin to check, or check once when
  he next messages.
- If a short watch is genuinely needed, cap the iteration count, and **exit the loop on the
  first failure** rather than retrying — consecutive failures mean the console is gone and
  every further attempt is a prompt.
- Prefer a signal that costs nothing: a DB/webhook-backed check, or just waiting for the
  next inbound message.
- Before ending a session, kill any background watchers and confirm with
  `ps aux | grep -E '[a]l console|[k]ubectl exec'` — stray `al console exec` processes
  survived my first `pkill` and needed `kill -9`.
