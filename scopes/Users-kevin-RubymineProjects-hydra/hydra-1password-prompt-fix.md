---
name: hydra-1password-prompt-fix
description: "RESOLVED 2026-07-02: 1Password 'Allow tmux CLI access' prompt storm — root cause (treasury Makefile op reads), the ~/.zshenv DAEMON_SOCK-gated stub fix, and the gotchas"
metadata: 
  node_type: memory
  type: project
  originSessionId: b8de99f2-fc23-43eb-9091-530404697b77
---

The recurring "1Password Access Requested — Allow tmux to get CLI access" prompt storm (2026-07-01/02) was caused by `treasury/Makefile:363-364`: `export DD_API_KEY ?= $(shell op read "op://treasury/Treasury Datadog/credential")` (+ DD_APP_KEY). Every `make` run by a hydra bot evaluated them → 2 `op read`s → desktop-app auth prompt. It was NOT commit signing (op-ssh-sign signed silently — verified), NOT Datadog-specific (keys unused by sorbet/rspec), NOT fixable by any 1Password setting for tmux-parented processes.

**Fix (live since 2026-07-02 16:23, in `~/.zshenv`):** a block gated on `[[ -n "$DAEMON_SOCK" ]]` (all bot shells — workers + slack-byte — export it; user shells don't) that (a) sources `~/.op-service-token` and (b) stubs `export DD_API_KEY/DD_APP_KEY=hydra-noop`, so make's `?=` skips the op reads. Works instantly on running sessions because every Bash-tool command is a fresh zsh sourcing `.zshenv` — no restarts. Verified: bot shell gets stubs, user shell untouched, `?=` skip proven with a synthetic Makefile.

**Gotchas learned:**
- `~/.op-service-token` contains Russell's TEMPLATE with placeholder `ops_PASTE_TOKEN_HERE`, commented out. No real service account was ever created. If bots later need real `op read`: create SA at my.1password.com → Developer → Service Accounts with READ on `treasury` vault (SA cannot access built-in Employee vault), paste token AND uncomment. Don't uncomment the placeholder — a garbage token makes op fail with `DecodeSACredentials` instead of prompting.
- 1Password CLI auth is per-terminal-session (tty+start time, 10-min inactivity expiry, 12h cap, revoked on lock; see 1password.dev/cli/app-integration-security). Claude Code Bash subshells have NO controlling tty (`tt=??`) and bot ancestry is the self-signed tmux server — auth can never persist for bots. iTerm-hosted claude works because ancestry is signed iTerm.
- Verified separately (2026-07-02 doc-research workflow): NO 1Password-native fully-headless commit signing exists — vault-only key means desktop-agent prompts; ceiling is "Approve for all applications" + timed window + no auto-lock ≈ one Touch ID tap per unlock window. If a bot commit triggers an SSH-key prompt (dialog says "use the SSH key", NOT "CLI access"), tick "Approve for all applications" once — covers the fleet until 1Password quits.
- After changing env plumbing, in-flight shell commands keep pre-fix env for up to ~10 min (Bash tool cap) — expect straggler prompts briefly; don't restart sessions for them.

**Why:** avoids re-litigating a multi-hour investigation; the fix lives in a user dotfile (`~/.zshenv`), easy to miss when debugging hydra.
**How to apply:** if prompts recur, first read the dialog text (CLI vs SSH-key), then check `~/.zshenv` gate intact and `DAEMON_SOCK` present in the bot's claude env; the treasury Makefile lines may also have moved — re-grep `op read`.

See [[hydra-slack-setup]], [[hydra-session-resurrection]], [[hydra-rebase-followups]].
