# agent-memory internals

The technical detail behind [README.md](README.md), moved here when the README was rewritten for newcomers. The install steps were updated to list all five; the rest is unchanged. `SPEC.md` is the implementation spec; `DESIGN.md` holds the reasoning and rejected alternatives.

## What install.sh does

Idempotent — safe to re-run, and it never overwrites a real directory with a symlink.

It does five things, in this order:

1. **Wires the PII guard.** `core.hooksPath` is *local* git config and is **not cloned**, so a fresh
   clone has `hooks/pre-commit` silently disabled. This runs first because it is the one step that
   must never be left to a manual README line — the guard is what stops SSN- and account-shaped
   digits reaching a remote, and it fails closed.
2. **Symlinks each scope whose project directory exists on this machine.**
3. **Links `config/CLAUDE.md`** to `~/.claude/CLAUDE.md`, unless a real file is already there.
4. **Wires the Claude Code hooks** into `~/.claude/settings.json`, adding only what is missing and
   backing the file up to `settings.json.bak` first. Skipped without `jq`, or from a linked worktree.
5. **Schedules `bin/reindex.sh`** with launchd every 15 minutes (macOS only; refused from a linked worktree).

## Portability: scopes are machine-specific

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

**The reindex job runs from this tree too.** `install.sh` schedules `bin/reindex.sh` with launchd
(`com.agent-memory.reindex`, every 15 minutes, log at `~/Library/Logs/agent-memory-reindex.log`). It
keeps one detached worktree per indexed repo under `~/.agent-memory-index/`, registered in that repo's
`git worktree list`. To remove it: `launchctl bootout gui/$(id -u)/com.agent-memory.reindex`, delete
the plist from `~/Library/LaunchAgents/`, then `git -C <repo> worktree remove ~/.agent-memory-index/<repo>`.

## MEMORY.md is the only retrieval path

A memory file that has no pointer in its scope's `MEMORY.md` is unreachable. Nothing loads it.

Measured against 2,050 session transcripts on 2026-09-15: the index is injected at session start in
454 of them; automatic recall of a memory *body* appears in **zero**. System-reminder injections are
persisted to the transcript — that is how the index is observable — so a recall would be equally
visible if it happened. Two sessions reached this independently, by different markers.

Practical consequence: **adding the file is half the job. Without the pointer it does not exist.**

The index injected is the cwd's, and hydra spawns at `~/RubymineProjects`, so a repo's own index
used to load only in a session started inside that repo. `hooks/memory-scope.sh` fills that: at
SessionStart a worktree gets its parent repo's index, and on UserPromptSubmit a session above the
repos gets a repo's index the first time a prompt names it, once per session. In a hydra
prompt only the `<request>` text counts; bot and session relays never do. Each injection stays
under Claude Code's 10,000-character hook limit, so a longer index is cut with a pointer to
the rest, and compaction lets a named repo's index load again.

Subagents get the same treatment on SubagentStart. One started in a worktree gets its parent
repo's index. One started above the repos gets the index of the repo its parent session is bound
to, which `hooks/memory-retrieve.sh` records the first time a prompt picks a repo. Explore and
Plan agents are skipped, and the hook prints nothing when neither case applies.

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

## How the pieces fit

Five things, each replaceable on its own. Run them in this order.

**1. `bin/build-graph.rb` — the indexer.** Parses Ruby with Prism (stdlib on 3.4) and
emits two TSVs: nodes (class/module, with `file:line`) and edges. Four edge kinds:

| kind | from | what it means |
|---|---|---|
| `references` | constant references in the AST | code coupling — X names Y |
| `assoc` | `belongs_to` / `has_many` / `has_one` | declared model relations |
| `fk` | annotation column `customer_account_id` | X points at CustomerAccount |
| `shares_column` | two models carrying the same non-resolving column | data coupling the AST cannot see |

The last one exists because a relation carried by a column has no constant anywhere:
`CustomerAccount` and five other models reach entity verification through
`owner_entity_api_id`, and nothing in the AST says so.

Ambiguous names are **dropped, never guessed**. An early version resolved a bare name
by first-match-in-file-order and manufactured a 190-in-degree hub that does not exist.
Output is byte-identical under a reversed input file list; that is a criterion, not a
nicety.

**1b. `bin/build-graph-ts.ts` — the TypeScript indexer.** Edges come from imports, which
is structurally safer than the Ruby side: an import states its source file, so there is
nothing to guess. A node is a *module*, named for its whole path (`Daemon::SessionLifecycle`),
because TypeScript has no global namespace and bare export names collide — 13 names in
hydra are carried by 32 declarations. Parsed with `Bun.Transpiler`, not a regex: a regex
cannot tell `import type` from a value import, and hydra has 128 type-only imports that
must not become runtime edges. The loader follows the extension, because neither of
bun's dialects parses both: in `tsx` a generic arrow is an unclosed JSX tag, in `ts` JSX
is a syntax error. Builtins, packages and unresolvable specifiers are dropped, never
guessed.

Test files are excluded, as `app lib backend` excludes `spec/` on the Ruby side. They
are 120 of hydra's 230 files, and because the ranker traverses undirected they act as
two-way bridges between modules that never reference each other — with them in,
`BridgeDispatch` answered `Config` instead of `BridgeServer`.

**Resolution.** `bin/ts-resolve.ts` resolves a relative specifier against the importer, a
bare one through the nearest `tsconfig.json` (`paths` by longest prefix, then `baseUrl`;
only a relative `extends` is followed), and then through a workspace `package.json` name,
mapping its `exports`/`main` build output (`dist/x.js`) back to source (`src/x.ts`).
Anything left is a dependency and is dropped. A barrel (`services/index.ts`:
`export * as transfer from './transfer'`) also gives its caller an edge to the member it
uses (`services.transfer.x`), since nova calls most services that way. The walk follows
the whole chain, through named and local (`import { x }; export { x }`) re-exports and
`export * from` (whose names come from `Bun.Transpiler.scan`, so values only), to the
module that defines or last re-exports
the name. It stops at an object that bundles imports (`export const libDataRoom = { authz }`),
which is a value, not a re-export. On nova: 8,734 relative and 14,822 aliased
imports (21 unresolvable) give 30,657 edges, 7,209 of them through barrels.
`*e2e/` trees are excluded with the tests. tsconfigs are parsed with a JSONC stripper of
our own, because index.sh runs the indexed repo's pinned bun and 1.2.x has no `Bun.JSONC`.

A second limit bites in a mixed repo: `.jsx` and `.js` files are outside the index, so
an edge whose target is one is dropped — flowdash loses 48 real edges that way.

Two more worth knowing. `foo/index.ts` names its module `Foo::Index`, so the name a
person would type (`Foo`) resolves to nothing — 0 of hydra's 126 files, but 1,350 of
nova's 7,093. And a path git has to quote (non-ASCII, or a tab or quote in the name) is
skipped; `bin/theme.sh` refuses to seed a concept over one and says why, so the two
layers agree for Ruby — widen one and you must widen the other. `theme.sh` is still
Ruby-only: it does not apply the TypeScript test exclusions, so it can stamp a `.test.ts`
the indexer never read.

**2. `bin/schema.sql` + `bin/index.sh` — the store.** One SQLite file. `index.sh` runs
parse → load → count end to end, dispatches on whether the repo holds Ruby or
TypeScript, and refuses a linked worktree, because
`worktree list --porcelain | head -1` answers with the *parent* and indexing a branch
under the parent's name would replace the main checkout's rows. With
`MEMORY_INDEX_CANONICAL=1` it, `seed-concepts.rb`, `load-concepts.sh` and `theme.sh` accept
a clean worktree sitting exactly at the main checkout's `origin/main`: that is the parent's
content, and it is how `reindex.sh` builds without touching the shared checkout.

Only half the store is derived. `node`, `edge` and `graph_health` rebuild from source in
under a second. `theme`, `theme_file` and `theme_node` are seeded and derivable from
nothing — deleting the file destroys them.

**3. `bin/rank.sql` + `bin/rank.sh` — retrieval.** Traverse to *rank*, not to collect.
A 2-hop undirected walk from `CustomerAccount` reaches 980 of 2,049 nodes — 48% of the
repo, ~196,000 tokens. Each hop divides by `1 + log(1 + undirected_degree(target))`, so
a generic node contributes little and a specific collaborator dominates. Top 10 is
~2,000 tokens.

**Undirected** degree, because the traversal is undirected. Weighting by in-degree gave
`Types::QueryType` (in 1, out 105) a leaf's penalty while it sat adjacent to every model
it references, and it ranked 2nd.

**4. `bin/derive-concepts.rb` — the concept layer.** Merges a model with its service
namespace by stem, so `AchPull` and `AchPulls::*` become one `ach_pull`. Emits
`seeds/<repo>-concepts.tsv` with each concept's top symbols and its related concepts,
for review by hand before anything is written. A TypeScript module has no such stem, so
its concept is the first directory below the layer directories in `bin/ts-layers.txt`
(`graph/src/services/dataRoom/` -> `data_room`); spelling variants merge. `match.sh` reads
the same file to drop layer words from a module name.

A TypeScript module with at least 50 edges is a hub when it is in no concept
(`graph/src/lib/prisma.ts`, 1,029 edges) or its neighbours span 25 or more concepts
(`packages/core/src/result`, 56). One domain index crosses it too: `data/organization/index.ts`
spans 30, so the organization concept loses its top seed. Hubs are recorded in
`structural_node` and skipped by `rank.sql` the way `ApplicationRecord` is. nova has 56;
the floor keeps a small repo's `lib/` traversable.

**5. `bin/install.sh` — bootstrap.** Wires `core.hooksPath` first, because that is local
git config and is **not cloned**: a fresh clone has the PII guard silently disabled.
Then symlinks scopes by computing each local project directory's slug, since the slug
transform is lossy and cannot be reversed.

## Writing Judgment

Everything below `## Judgment` in a concept file is Kevin's, and `bin/match.sh` injects it
under the concept's code block, labelled as his recorded decisions that outrank the
model's own inference but get checked against the code before acting. Keep it to what
the code cannot tell a reader: a decision, a rejected option, a constraint from outside
the repo.

- One entry is a few lines of prose, then a `src:` line per source:
  `src: <jsonl path under ~/.claude/projects> <ISO ts of Kevin's message> "<verbatim quote>"`.
  Cite Kevin's own message, never assistant prose. `provenance:` is the older form.
- `src:` and `provenance:` lines are for the reviewer and never injected.
- Link a memory with `See [[name]]` instead of restating it.
- Injection stops at 1500 bytes (`MATCH_JUDGMENT_BYTES`), so put the most useful entry first.

## Iterating on it

**`test/rank-regression.sh` is the loop.** The corpus in `test/rank-cases.tsv` is a list
of real queries with expected and forbidden answers:

```sh
./bin/index.sh ~/RubymineProjects/treasury
./bin/index.sh ~/RubymineProjects/hydra
./bin/index.sh ~/RubymineProjects/nova     # the corpus covers all three repos
./test/rank-regression.sh                  # 32 passed, 0 failed
```

All three repos have to be indexed: a seed that resolves to nothing is counted as a failure,
because scoring it as a pass is how two `deny` cases stayed green with hydra absent.

This exists because the two worst ranker bugs on this branch — an in-degree weight
against undirected traversal, and GraphQL roots ranking 2nd — **survived six independent
review rounds and died to a single realistic query.** Reviews check the code. These check
the answers.

**When retrieval looks wrong, add the case before fixing it.** A `deny` line naming what
should not appear is usually more durable than a `want` line, because the wrong answers
are stable while the right ones re-order as the graph grows.

**Make sure the case can fail.** Three `deny Types::*` lines passed with the weighting
bug deliberately reintroduced, because a separate exclusion list was filtering those
symbols anyway — they tested the denylist, not the weighting. The cases that actually
discriminate name one-off incident-repair tasks (`Maintenance::Repair…Task`), which have
low in-degree and high out-degree and surface only under the broken weight. Revert the
fix, confirm the corpus goes red, restore.


## Tooling

| Script | Does |
|---|---|
| `bin/install.sh` | Bootstrap on a machine. Idempotent. `--dry-run` to preview. |
| `bin/build-graph.rb` | Prism AST indexer. Emits `node`/`edge` TSV. Deterministic — ambiguous references are dropped, never guessed. |
| `bin/build-graph-ts.ts`, `bin/ts-resolve.ts` | TypeScript indexer. One module node per file; edges from relative, tsconfig-alias and workspace-package imports. `import type` produces no edge. |
| `bin/structural.rb` | Lists a TypeScript repo's hub modules for `rank.sql` to skip. |
| `bin/derive-concepts.rb` | Merges a model with its service namespace by stem into one concept; a TypeScript module by its domain directory. |
| `bin/rank.sh`, `bin/rank.sql` | Ranked neighbours of a symbol. Traverses to rank, not to collect. |
| `test/rank-regression.sh` | The iteration loop — real queries with expected answers. |
| `test/ts-indexer-test.sh` | The TypeScript indexer against a fixture tree, plus the language dispatch. |
| `bin/measure-index.sh` | Note-index measurement. Reproduces the **note-index** figures in `DESIGN.md` — not the graph figures, which come from `build-graph.rb` and `rank.sql`. |

`SPEC.md` is the implementation spec and the canonical design document. `DESIGN.md` holds the
reasoning and the rejected alternatives.
