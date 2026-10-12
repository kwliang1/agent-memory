---
name: hydra-console-billing
description: "RETIRED 2026-09-26: .claude-byte is dead, the whole fleet runs CLAUDE_CONFIG_DIR=~/.claude. Billing under the byte login was wrong."
metadata:
  node_type: memory
  type: project
  originSessionId: ee84b05e-77f7-49e3-9208-24e2481b8da9
  modified: 2026-09-26T21:19:48.513Z
---

**Current state (verified 2026-09-26).** The hydra fleet runs `CLAUDE_CONFIG_DIR=/Users/kevin/.claude`. Kevin: *"billing is incorrect, we should never be using claude-byte anymore."* `.claude-byte` is retired — do not restore it, do not "fix" a daemon back to it, do not pin it on a lifecycle command.

Verified, not assumed:
- `~/.claude/channels/slack/.env` → `CLAUDE_CONFIG_DIR=/Users/kevin/.claude`
- `grep -rn claude-byte --include=*.ts --include=*.sh` over the repo → **zero hits**
- `shared/constants.ts:110` → `claudeConfigDir()` returns `process.env.CLAUDE_CONFIG_DIR || ~/.claude`. The old `.claude-personal` default is gone, so an unset var now lands on `.claude` correctly.
- Spawned transcripts land in `~/.claude/projects/`. `~/.claude-byte/projects/` still holds 58 stale dirs — historical only, and invisible to `daemon/usage.ts`, which reads via `claudeConfigDir()`.

**What this invalidates.** The previous version of this memory said the fleet moved to `.claude-byte` on 2026-08-27 for Anthropic Console billing (`billingType: usage_based`, keychain `Claude Code-credentials-a21d4e95`), and told you to prefix lifecycle commands with `CLAUDE_CONFIG_DIR=/Users/kevin/.claude-byte`. **All of that is wrong now.** The `cli/helpers.ts` `resolveConfig` ordering bug it described is also moot — there is no second config dir to drift between.

Still true and worth keeping: running Claude sessions never re-read the keychain while healthy, so a restart is the only way to flip billing; and migrating a session between config dirs means copying `projects/<cwd-slug>/<claudeSessionId>.jsonl` to the target, `hydra kill <name>`, then `resume` in its Slack thread.

See [[claude-config-topology]], [[hydra-hardcoded-claude-config-paths]], [[daemon-restart-via-bash-not-cli]] — all three carry `.claude-byte` claims corrected on the same date.
