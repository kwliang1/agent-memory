---
name: ts-best-practices-skill-and-reviewers
description: "The ts-best-practices review skill (user-level), how it's wired, and who actually reviews Kevin's nova PRs."
metadata: 
  node_type: memory
  type: project
  originSessionId: 7309fb0e-e965-47fe-a9eb-d09c1726b0aa
  modified: 2026-08-26T21:55:30.647Z
---

**`ts-best-practices` review skill** lives at `~/.claude/skills/ts-best-practices/SKILL.md` (user-level, deliberately NOT checked into nova). It's a nova-TypeScript code-review checklist mined from Cameron Austgen and Alec Deitloff's PRs + Alec's review nits on Kevin. Rules marked ⭐ = both engineers apply; 💬 = from Alec's review comments.

**CRITICAL config-dir fact:** hydra spawns its Claude Code sessions with `CLAUDE_CONFIG_DIR=~/.claude-byte` (`daemon/config.ts:24`, `session-lifecycle.ts:132`). So hydra/byte sessions (Russell, spawned builds, `/review` critics) load their global CLAUDE.md and user **skills from `~/.claude-byte/`**, NOT `~/.claude/`. Kevin's normal terminal Claude Code uses `~/.claude/`. Neither dir is git-tracked. This split governs where skills/instructions must live to reach each session type.

**Final wiring (all user-level, nothing git-tracked, checkout-proof):**
- Skill source of truth: `~/.claude/skills/ts-best-practices/` (Kevin's terminal). Symlinked into `~/.claude-byte/skills/ts-best-practices` → so hydra/byte sessions can discover it too.
- Pre-push gate: `~/.claude/CLAUDE.md` step 2 tells reviewer agents to load the skill on nova `.ts`/`.tsx` diffs (covers terminal sessions).
- Hydra auto-load: a `## Reviewing nova TypeScript` directive in `~/.claude-byte/CLAUDE.md` — loaded by every hydra/byte session in every directory → the critic auto-invokes the skill on nova TS. Replaced an earlier fragile uncommitted edit to tracked `daemon/prompts/review-critic.ts`, which was REVERTED (Kevin: "I don't want git checkout to overwrite it").
- Optional explicit trigger: `protocols/lenses/nova-ts.ts` lens (alias `nts`) kept as an untracked file registered via hydra's `.git/info/exclude` (git-ignored → survives `git checkout`; only `git clean -fdx` removes it). Gives `/review +nova-ts`. Lenses are hydra's first-class review-pass hook (`protocols/lenses/*.ts`, auto-discovered via `defineLens`; only `security` pre-existed). Loads clean; `bun test __tests__` = 950 pass / 0 fail.
- Daemon reload/restart needed for hydra to pick up the lens + byte-CLAUDE.md directive (was NOT restarted — live sessions).

**`design-doc-voice` skill** = Kevin's house writing voice for ALL external-facing text (PR titles/descriptions, Linear, artifact & doc prose, inline comments, PR-review + Slack/thread replies). Source at `~/.claude/skills/design-doc-voice/`; **now symlinked into `~/.claude-byte/skills/design-doc-voice`** (2026-08-26) so hydra/byte sessions load it too — same pattern as ts-best-practices. Core: conciseness-first (ship short the *first* draft; a maximalist draft gets sent back, a memo-length reply gets rewritten), plain/low-jargon, lead-with-the-point. Kevin's own voice markers (added from a real thread reply): first-person opinion-ownership ("I still feel", "I'd argue", "imo"), open concessions, quote-and-respond (`>` then terse answer, fragments ok), emphasize the one operative word, links ride a label. Load it before drafting any of those surfaces — artifacts included.

**GitHub handles:** Cameron Austgen = `ctotheameron` (NOT Cameron Napoli = `cameronnapoli`). Alec Deitloff = `ahlec`.

**Who reviews Kevin's nova PRs:** NOT Cameron Austgen (0 review comments all-time). Actual reviewers are `cameronnapoli`, `amahon`, `kevinmmarlow`, plus bots (cursor, devin). Alec left ~9 inline nits in 90d. Useful when deciding who to tag or whose conventions to weight.

**gh gotcha:** rapid bursts of `gh api` calls (100s) trip GitHub secondary rate limits and silently return empty. Throttle, or use GraphQL (separate budget). See [[spawned-nova-worktree-is-bare]] for the worktree provisioning context.
