# agent-memory

Version control for Claude Code's auto-memory. Every change to a memory file becomes a reviewable diff.

## Why

Memory is written by many concurrent sessions with no history. Before this repo, a bad bulk edit was unrecoverable and a silent drop was invisible — one near-miss on the umbrella index and one duplicate-correction incident both traced to that.

## Install on a new machine

```sh
git clone git@github.com:kwliang1/agent-memory.git ~/agent-memory
~/agent-memory/bin/install.sh --dry-run   # see what it would do
~/agent-memory/bin/install.sh
```

Idempotent — safe to re-run, and it never overwrites a real directory with a symlink.

It does three things, in this order:

1. **Wires the PII guard.** `core.hooksPath` is *local* git config and is **not cloned**, so a fresh
   clone has `hooks/pre-commit` silently disabled. This runs first because it is the one step that
   must never be left to a manual README line — the guard is what stops SSN- and account-shaped
   digits reaching a remote, and it fails closed.
2. **Symlinks each scope whose project directory exists on this machine.**
3. **Links `config/CLAUDE.md`** to `~/.claude/CLAUDE.md`, unless a real file is already there.

### Portability: scopes are machine-specific

A slug is the absolute project path with `/`, `_` and `.` all replaced by `-`. **That transform is
lossy and cannot be reversed** — `Users-kevin-RubymineProjects-angellist-user-mapping` could be
`angellist-user-mapping`, `angellist_user_mapping`, or `angellist/user/mapping`. On this machine it is
the underscore form.

So the installer works the other way round: it enumerates local project directories, computes each
one's slug, and links only where that slug matches a committed scope. A scope with no matching local
directory is **skipped and reported**, never guessed at. Set `MEMORY_SEARCH_ROOTS` (colon-separated)
to add search roots beyond `$HOME`, `$HOME/RubymineProjects` and `$HOME/conductor/workspaces`.

Skipped scopes are usually dead workspaces rather than an error — three conductor scopes on this
machine point at workspaces that were deleted, and the installer names them so they can be pruned
deliberately.

## Layout

```
scopes/<slug>/          <- the real memory directory
  MEMORY.md             <- the index
  <name>.md             <- one fact per file
```

`<slug>` is Claude Code's project-directory name with the leading `-` stripped:

```
~/.claude/projects/-Users-kevin-RubymineProjects/memory
  -> ~/agent-memory/scopes/Users-kevin-RubymineProjects
```

Each `~/.claude/projects/<scope>/memory` is a symlink into `scopes/`. Session transcripts stay in
`~/.claude/projects/` and never enter this repo — they contain file contents and production data.

## Hazards this repo introduces

Putting a live directory under git buys history and costs two things that did not exist before.

**Never run `git clean -xfd`, `git checkout -- .`, or `git reset --hard` here.** A memory file is
untracked until someone commits it, and any of those deletes it with no object and no reflog entry.
Before this directory was a git tree, nothing swept it. This is the one way the repo is strictly worse
than no repo, and it lasts only for the uncommitted window — so commit after a curation pass.

**`config/` and `hooks/` must stay on the default branch.** `~/.claude/CLAUDE.md` is a symlink into
`config/`. Claude Code treats a missing CLAUDE.md as *"no rules found"*, not as an error — so a branch
that lacks `config/` silently removes every behavioural rule from every session started while it is
checked out, including the BLOCKING gates. Sessions already running keep their copy, so the fleet
splits into two rule regimes with no signal in either. Never park this repo on a branch without
`config/`.

The git index is per-repo, not per-session, and many sessions share this checkout. Anything you stage
is fair game for whichever session next runs `gt`, which auto-commits staged files. Stage nothing here
that you are not about to commit.

## MEMORY.md is the only retrieval path

A memory file that has no pointer in its scope's `MEMORY.md` is unreachable. Nothing loads it.

Measured against 2,050 session transcripts on 2026-09-15: the index is injected at session start in
454 of them; automatic recall of a memory *body* appears in **zero**. System-reminder injections are
persisted to the transcript — that is how the index is observable — so a recall would be equally
visible if it happened. Two sessions reached this independently, by different markers.

Practical consequence: **adding the file is half the job. Without the pointer it does not exist.**

## Workflow

Memory edits land as PRs so they can be reviewed. The initial import on `main` is the pre-existing
state, captured as-is.

Restore a scope. Stage it elsewhere and swap it in, so the live path is never missing:

```sh
cd ~/agent-memory
git worktree add -q /tmp/cm-restore <ref>
rm -rf scopes/<slug> && cp -a /tmp/cm-restore/scopes/<slug> scopes/<slug>
git worktree remove /tmp/cm-restore
git reset -q scopes/<slug>
```

The symlinks mean a restored file is live immediately — no copy back.

The plain `checkout <ref> -- <path>` is a merge, not a revert: it restores the old files but leaves
anything added since, so recovering from "a bad edit added junk" keeps the junk. It also leaves the
result **staged**, and Graphite's pre-push hook auto-commits staged files — a restore left staged can
ride into an unrelated commit. Hence the delete-first and `reset` steps.

Restoring by switching branches or checking out an old commit wholesale will delete scope directories
absent from the target and dangle their symlinks until you switch back. Use the path form.

## Scope inventory at import

| scope | files | indexed | orphans |
|---|---|---|---|
| Users-kevin-RubymineProjects | 224 | 112 | 112 |
| Users-kevin-RubymineProjects-treasury | 86 | 13 | 73 |
| Users-kevin-RubymineProjects-nova | 45 | 27 | 18 |
| Users-kevin-RubymineProjects-hydra | 16 | 14 | 2 |
| Users-kevin-RubymineProjects-ipseity | 15 | 15 | 0 |
| Users-kevin-RubymineProjects-usvc | 12 | 12 | 0 |
| Users-kevin-RubymineProjects-venture | 10 | 5 | 5 |
| Users-kevin | 10 | 10 | 0 |
| Users-kevin-RubymineProjects-angellist-user-mapping | 1 | 1 | 0 |
| 3 conductor workspaces | 1 each | — | — |

210 orphans at import, 27 of them behavioral rules. Treasury is the worst scope at 15% reachable.

## Tooling

| Script | Does |
|---|---|
| `bin/install.sh` | Bootstrap on a machine. Idempotent. `--dry-run` to preview. |
| `bin/build-graph.rb` | Prism AST indexer. Emits `node`/`edge` TSV. Deterministic — ambiguous references are dropped, never guessed. |
| `bin/derive-concepts.rb` | Merges a model with its service namespace by stem into one concept. |
| `bin/rank.sh`, `bin/rank.sql` | Ranked neighbours of a symbol. Traverses to rank, not to collect. |
| `bin/measure-index.sh` | Note-index measurement. Reproduces every figure in `DESIGN.md`. |

`SPEC.md` is the implementation spec and the canonical design document. `DESIGN.md` holds the
reasoning and the rejected alternatives.
