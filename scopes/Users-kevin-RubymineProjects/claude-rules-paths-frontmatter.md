---
name: claude-rules-paths-frontmatter
description: ".claude/rules scoping uses `paths:` (globs: ignored); nested AGENTS.md auto-loads; user-level ~/.claude/rules paths match relative to cwd, so use **/ prefix under hydra."
metadata:
  type: reference
---
Probed 2026-10-12 with canaries on a synthetic parent/repo tree via `claude -p`. Round 1 used the model's self-report; round 2 was confirmed by grepping the session jsonl for attachments when only one file had been Read.
- `paths:` (YAML list) in `.claude/rules/*.md` frontmatter scopes the rule: it attaches to a Read result only when the file matches.
- `globs:` is NOT honored, so the rule loads in every session. treasury's services.md, sorbet.md and frontend.md use `globs:` and are always-on.
- From a parent cwd (hydra sessions run at ~/RubymineProjects), nothing in the repo loads at start. The first Read under the repo pulls in its CLAUDE.md and unscoped rules, and path-scoped rules load only for matching files.
- From the repo cwd, CLAUDE.md and unscoped rules load at session start.
- A nested `AGENTS.md` loads natively when a file in its dir is Read, from either cwd. No CLAUDE.md shim is needed; a `@AGENTS.md` import in a nested CLAUDE.md also resolves.
- User-level `~/.claude/rules/*.md` with `paths:` works, but paths match relative to the session cwd: `app/x/**` fired from the repo cwd and NOT from the hydra parent cwd. `**/app/x/**` fired from the parent and stayed out for a non-matching file.
- `~/.claude/rules` as a symlink to another dir (e.g. a sibling wiki), and a symlinked single rule file, both load with `paths:` scoping intact (transcript-verified).

Related: [[claude-md-ancestor-loading-rules]]. Context: deciding whether to replace agent-memory graph injection with colocated rules.
