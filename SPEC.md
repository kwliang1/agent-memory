# Codebase memory graph — implementation spec

**For a fresh session to execute.** Design and measurement are done; this is the build.
Everything here was verified on 2026-09-15/16 against the live machine. Re-verify
anything you are about to depend on — commands are given — but do not re-derive the
design.

Companion: `DESIGN.md` holds the reasoning and the rejected alternatives.
Artifact: https://claude.ai/artifact/NVyzfPmaR3ufFQ6GzHrFC2

---

## 1. What you are building

A per-repo knowledge graph of the codebase that a session recalls from automatically,
seeded on demand rather than exhaustively.

- **Store** — one SQLite file, `node` / `edge` / `theme` / `coverage` + FTS5. Derived
  from source, gitignored, rebuildable.
- **Indexer** — Prism AST for Ruby, TypeScript compiler API for nova.
- **Ranker** — the component that makes retrieval affordable. Not optional.
- **Coverage ledger** — makes "is this theme known / fresh / stale" a lookup.
- **Hooks** — SessionStart, UserPromptSubmit, PostToolUse.
- **Telemetry** — tokens and accuracy per prompt and session.

Proving order: **treasury, then nova, then venture.**

---

## 2. Decisions already made — do not relitigate

| Question | Decision |
|---|---|
| Database | SQLite. Kuzu only if edges pass ~10^7. Neo4j/Postgres ruled out. |
| Ranking weight | `1/log(1+in_degree)`, K=10. Start here, iterate against the baseline. |
| Who writes concepts | Automatic generation; Kevin reviews the **initial seed list** by hand. |
| Concept key format | `[repo, concept_slug]` — e.g. `[treasury, ach_pull]`, `[nova, transfers]`. |
| Eager layer | General preferences **+ available tools** + theme names. Preferences stay. |
| The 428 existing notes | Become concept nodes with provenance. Never regenerated away. |
| Worktrees | Index main, overlay `git diff main...HEAD`. |
| Structural refresh | At session start (4.9 s). Nightly is for concepts + citation verification only. |

---

## 3. Verified facts, with re-verification commands

### treasury graph (the target shape)
```sh
cd ~/RubymineProjects/treasury
git ls-files app lib backend | grep -E '\.rb$' > /tmp/rf.txt
ruby ~/agent-memory/bin/build-graph.rb $(cat /tmp/rf.txt)
```
2,049 class/module nodes, 9,066 resolved edges, 4.9 s, 1.7 MB as SQLite.
Out-degree median 3 / p90 11 / max 106. In-degree median 1 / p90 9 / **max 359**.

### The ranker is load-bearing
2-hop **undirected** from `OutgoingWire` reaches **858 of 2,049 nodes** — 42% of the
repo, ~172,000 tokens for one injection. Undirected is the honest case because "related
concepts" means callers as well as callees. Ranked top-10 is ~2,000 tokens, and surfaces
`AchPushes::CreateService` and `OutgoingWires::CreateService` unprompted while `Types`
and `ApplicationRecord` never appear.

### Scope resolution — the exact command matters
```sh
git worktree list --porcelain | head -1   # -> /Users/kevin/RubymineProjects/treasury   CORRECT
git rev-parse --show-toplevel             # -> /.../.worktrees/treasury-1746            WRONG
```
`--show-toplevel` returns the worktree, not the repo. It is what claude-mem uses. No path
heuristic works: treasury's 47 worktrees live under **four** different parent directories.

Today: 47 live treasury worktrees, 13 with a scope directory, **0 memory files in any**.
treasury proper has 170. Across all scopes: 63 total, 12 with memory.

### Reading main from a worktree — no checkout
```sh
git show main:app/services/ach_pulls/create_service.rb   # works from inside a worktree
```
All worktrees share one object store. **Never `git checkout main`** in a worktree — it
destroys uncommitted work with no stash entry.

Worst `main...HEAD` delta across all 47 worktrees is 52 files; median is single digits;
39 files reparse in 0.015 s.

### Cross-repo relations cannot be name-matched
nova declares **no** `Transfer`, `OutgoingWire`, `AchPush`, `OutgoingPayment` in
TypeScript. `achPull` / `outgoingWire` appear nowhere in it. nova's own `TransferType`
(153 files) is unrelated. **Name matching returns zero.** Use, in order:

1. **GraphQL operations** — nova sends `query ALTreasury`, `query AchReturnPipelineState`,
   `mutation ConfirmRecipientDistributionPayment` into treasury's 402 `app/graphql` files.
2. **The existing notes** — 31 already assert cross-repo relations in prose
   (22 treasury→nova, 9 nova→treasury).
3. **Kevin naming the residual.**

### Tooling on this machine
- Ruby **3.4.8**, so **Prism 1.9.0 is stdlib**. No gem needed.
- `sqlite3` **3.51.0**.
- Sorbet RBI is **not** a domain symbol table — 2,058 of treasury's 2,394 are generated
  external-API clients (999 temporalio, 319 treasury_api, 243 entity_api). Ignore it.
- Packwerk: treasury **6** packages, venture 12. Coarse; a poor seeding unit.
- Hooks fire normally in hydra sessions — the daemon exports `CLAUDE_CONFIG_DIR` into
  every spawn.

---

## 4. Traps — each of these cost real time

- **Scope directory names begin with `-`.** `ls -1d */` and `find . -name X` read the
  leading dash as a flag and silently return wrong results. Keep paths `./`-prefixed.
- **`find` needs `-L`** under `~/.claude/projects/*/memory` — those are symlinks into this
  repo. Without it every scope reads as empty.
- **`cd ""` succeeds in zsh** and leaves you in `$PWD`. An unguarded empty path variable
  indexes whatever directory you happen to be in and exits 0.
- **`awk -v x="$f"` expands backslash escapes** in the value. Use `ENVIRON["x"]` with an
  exported variable — and note the export must apply to the process that *reads* it, not
  an earlier one in the pipeline.
- **`env -u GIT_DIR -u GIT_WORK_TREE`** before any `git -C` that must not inherit a
  hijacked environment.
- **`du -h` reports allocated blocks, not bytes.** Cite `wc -c`.
- **Bash `cd` persists across tool calls.** Use absolute paths.
- **`#[0-9]{3,6}` is not a PR number.** It swallows `CA#`, `DCR#` and `Record#id` forms.
  A CA number checked against the GitHub PR API 404s and reads as a deleted PR.
- **`N` IS a real Linear prefix** (Nova team; `N-167` has its own memory file). A reviewer
  will call it a false positive. It isn't.

---

## 5. Build steps

### Step 0 — baseline (do this first, it is destroyed by step 5)
Pull 30–50 real prompts from the 2,050 transcripts in
`~/.claude/projects/*/[0-9a-f-]*.jsonl`. They carry the answer Kevin actually accepted,
which is the grader. Record per prompt: tokens at session start, tokens injected, whether
the session cited the right file / PR / prior decision.

**Acceptance:** a committed baseline table. Without it the litmus test has no "before".

### Step 1 — schema + indexer
`node(name, repo, kind, path, line)`, `edge(src, dst, kind)`, `theme`, `coverage`.
WAL. Index `edge(src)`, `edge(dst)`, `node(name)`.

`bin/build-graph.rb` already emits nodes and edges; port it to write SQLite directly.

**Acceptance:** treasury reproduces 2,049 nodes / 9,066 edges, and the run is
deterministic across two invocations.

### Step 2 — the ranker
```sql
WITH RECURSIVE reach(id, depth, w) AS (
  SELECT :start, 0, 1.0
  UNION ALL
  SELECT u.o, r.depth+1, r.w / (1.0 + log(1 + COALESCE(i.d, 1)))
  FROM und u JOIN reach r ON u.i = r.id
  LEFT JOIN indeg i ON i.n = u.o
  WHERE r.depth < 2
)
SELECT id, sum(w) AS score FROM reach WHERE id <> :start
GROUP BY id ORDER BY score DESC LIMIT 10;
```
`und` is the undirected edge view; `indeg` is `SELECT dst, count(*) FROM edge GROUP BY dst`.

**Acceptance:** from `AchPulls::CreateService`, `AchPushes::CreateService` and
`OutgoingWires::CreateService` both appear in the top 10; `Types` and `ApplicationRecord`
do not. Payload stays under 2,000 tokens.

### Step 3 — coverage ledger
`theme(repo, slug, last_indexed_sha)` + `theme_file(theme_id, path)`.
Staleness = `git diff --name-only <last_indexed_sha>..HEAD` ∩ theme files ≠ ∅, computed
against **the worktree's own HEAD**, not main's.

**Acceptance:** a theme reports fresh, a file is touched, it reports stale, a reseed
returns it to fresh — and the reseed re-reads only the changed files.

### Step 4 — concept seeding
`seeds/treasury-concepts.tsv` holds 125 derived concepts awaiting Kevin's review.
**Do not seed before he has reviewed that list.**

Concept template:
```
---
concept: [treasury, ach_pull]
related:
  - [treasury, ach_push]         # derived
  - [nova, ach_return_pipeline]  # cross-repo, from the GraphQL op
---
<!-- machine-owned: regenerated every run, never hand-edit -->
symbols:  AchPull, AchPulls::CreateService, AchPulls::StateService
files:    app/models/ach_pull.rb, app/services/ach_pulls/create_service.rb
graphql:  AchPullType, AchPulls::StateEnum
indexed:  68983603f
<!-- end machine-owned -->

## Judgment            <- prose, never written by the job
BANK-1764 blocks submission when...
provenance: bank-1764-ach-pull-block-submission.md
```
The boundary is structural, not procedural: **the job must be incapable of writing below
the machine-owned block.** A reconciler that could rewrite prose silently reverted 47
hand-written corrections earlier in this work.

### Step 5 — hooks
- `SessionStart` — resolve scope via `git worktree list --porcelain`, rebuild structure
  (4.9 s), inject preferences + tool list + theme **names**. Ceiling ~500 tokens.
- `UserPromptSubmit` — match prompt against theme names and identifiers → ranker.
- `PostToolUse` — extract identifiers from tool output → ranker → inject. Second hop
  through the fetched body, depth 2 then stop.

`hooks/memory-scope.sh` exists and is deliberately **not** wired into `settings.json`.

**Acceptance:** re-run the step 0 prompts and compare tokens and accuracy.

### Step 6 — nova, then venture
nova needs the TypeScript compiler API; it has no Sorbet and no Packwerk.

---

## 6. Code already in this repo

| Path | State |
|---|---|
| `bin/build-graph.rb` | Prism indexer. Works. Emits TSV; needs a SQLite writer. |
| `bin/derive-concepts.rb` | Stem-merges model + service namespace. Works. |
| `bin/measure-index.sh` | Note-index measurement. Reproduces every figure in DESIGN.md. |
| `seeds/treasury-concepts.tsv` | 125 concepts, **awaiting Kevin's review**. |
| `hooks/memory-scope.sh` | Worktree scope resolution. Unwired by choice. |
| `hooks/pre-commit` | PII guard, wired via `core.hooksPath`. Fails closed. |
| `scopes/` | 428 notes across 9 scopes. Symlinked live into `~/.claude/projects/`. |

---

## 7. Rules that apply to this work

- **Never delete a memory file as cleanup without Kevin's explicit say-so.** An unindexed
  memory is unreachable, not worthless, and several are load-bearing.
- **Back up before any bulk edit.** `git reset --hard` in this repo destroyed 47
  uncommitted corrections once already. Commit first, probe in a scratch clone.
- **Never disable commit signing.**
- `config/` and `hooks/` must stay on the default branch — `~/.claude/CLAUDE.md` is
  symlinked from there, and a missing file reads as "no rules found", not as an error.
- The **pre-push review gate** in `~/.claude/CLAUDE.md` applies: 5 reviewers per round,
  2 consecutive clean rounds.
- Kevin reviews changes as PRs. Branch prefix `kevinliang/`, Graphite, never commit to
  `main`.

---

## 8. Open — needs Kevin, not a decision you can make

1. **Review of `seeds/treasury-concepts.tsv`** before any concept is written. The tail
   (`angellist`, `account_policy`, `state_machine_transition`) is probably prunable.
2. **Two repos still hold leaked data in git history and need deleting** —
   `kwliang1/claude-memory` (SSNs) and `kwliang1/claude-memory-v2` (account numbers).
   Requires `delete_repo` scope.
3. Whether concept promotion from a live session is automatic or suggested.

---

## 9. Where the work goes

**Repo:** `git@github.com:kwliang1/agent-memory.git` (private), cloned at `~/agent-memory`.
`scopes/` is **symlinked live** into `~/.claude/projects/*/memory`, so the working tree
*is* production. No deploy step, no staging copy.

**Branching:** Graphite, prefix `kevinliang/`, never commit to `main`. Kevin reviews as
PRs. Update a PR body with `gh api repos/{owner}/{repo}/pulls/<N> --method PATCH` where
`<N>` is a literal number; the `gh` subcommand for editing PRs is banned by
`~/.claude/CLAUDE.md` and a PreToolUse hook enforces it — it scans your command text, so
it fires even when you are only quoting the rule.

**Layout:**

| Path | Holds |
|---|---|
| `SPEC.md` | This spec. Canonical. |
| `DESIGN.md` | Reasoning, measurements, rejected alternatives. |
| `bin/` | Working scripts — graph builder, concept derivation, index measurement. |
| `seeds/` | Derived concept lists awaiting review. |
| `scopes/` | The 428 notes. **Symlinked live.** |
| `config/`, `hooks/` | Must stay on the **default branch** — `~/.claude/CLAUDE.md` is symlinked from `config/`, and a missing file reads as "no rules found" rather than erroring. |
| `index/`, `*.db` | Gitignored. Derived graph — rebuildable, never committed. |

**The database is not committed.** It rebuilds from source in ~5 s. If it is ever wrong,
delete it and rebuild.

**Hazards specific to this repo:**

- Never `git clean -xfd`, `git checkout -- .`, or `git reset --hard` here. A `reset --hard`
  destroyed 47 uncommitted corrections once already. Commit first, probe in a scratch clone.
- Graphite's pre-push auto-commits staged files — leftover staging lands on the branch.
- Concurrent sessions share this checkout. Commit carefully.

**Definition of done per step:** the acceptance criterion in section 5 is met, the
pre-push gate has produced 2 consecutive clean rounds, the branch is pushed, and the PR
body states what was *measured* — not what was intended.
