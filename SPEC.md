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

- **Store** — one SQLite file: `node`, `edge`, `graph_health` (derived from source,
  rebuildable in under a second) plus `theme`, `theme_file`, `theme_node` (seeded, NOT
  derivable — deleting the db destroys them). Gitignored.
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
| Ranking weight | `1/(1 + log(1+undirected_degree))`, K=10. Start here, iterate against the baseline. |
| Who writes concepts | Automatic generation; Kevin reviews the **initial seed list** by hand. |
| Concept key format | `[repo, concept_slug]` — e.g. `[treasury, ach_pull]`, `[nova, transfers]`. |
| Eager layer | General preferences **+ available tools** + theme names. Preferences stay. |
| The 428 existing notes | Become concept nodes with provenance. Never regenerated away. |
| Worktrees | Index main, overlay `git diff main...HEAD`. |
| Structural refresh | At session start (under a second). Nightly is for concepts + citation verification only. |

---

## 3. Verified facts, with re-verification commands

### treasury graph (the target shape)
```sh
cd ~/RubymineProjects/treasury
git ls-files app lib backend | grep -E '\.rb$' > /tmp/rf.txt
ruby ~/agent-memory/bin/build-graph.rb $(cat /tmp/rf.txt)
```
2,049 class/module nodes, 6,759 resolved edges. `bin/index.sh` end to end runs in under a second and
produces ~1.9 MB of SQLite. (Byte-exact figures flap by ~8 KiB on page allocation, so
they are not quoted here.)
Out-degree median 3 / p90 9 / max 105. In-degree median 1 / p90 6 / **max 298**.

### The ranker is load-bearing
2-hop **undirected** reach: 418 from `AchPulls::CreateService`, 631 from
`OutgoingWire`, and **980 from `CustomerAccount`** — 48% of the repo, ~196,000 tokens
for one injection. Undirected is the honest case because "related
concepts" means callers as well as callees. Ranked top-10 is ~2,000 tokens. From `AchPulls::CreateService` it surfaces
`AchPushes::CreateService` at rank 5 while `Types` and `ApplicationRecord` never
appear. Note this holds **from that seed only** — from `OutgoingWire`, neither named
example appears (the top 10 has `OutgoingWires::StateService`), so do not use it as a
general criterion.

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

### Cross-repo relations: match the stem, not the identifier
PascalCase declarations return zero — nova declares no `Transfer`, `OutgoingWire`,
`AchPush` or `OutgoingPayment`, and its own `TransferType` (153 files) is unrelated. But
nova names them as **camelCase modules** in 25 files, under a directory named for the
dependency: `graph/src/clients/treasury/operations/achPull.ts`, `outgoingWire.ts`. An
earlier pass reported "name matching returns zero"; that test was aimed at the wrong
convention. Sources, in order:

1. **camelCase module names** — `achPull`, `outgoingWire` under
   `graph/src/clients/treasury/`. Direct and derivable; match on the stem across
   naming conventions.
2. **GraphQL operations** — nova sends `query ALTreasury`, `query AchReturnPipelineState`,
   `mutation ConfirmRecipientDistributionPayment` into treasury's 402 `app/graphql` files.
3. **The existing notes** — 31 already assert cross-repo relations in prose
   (22 treasury→nova, 9 nova→treasury). Not reproduced by any committed script; a
   mention-grep gives 35/47, so treat 31 as approximate.
4. **Kevin naming the residual.**

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
  will call it a false positive. It is not.
- **The transcripts are a second, unscrubbed copy of the leaked PII.** Scrubbing `scopes/`
  did not touch `~/.claude/projects/*/*.jsonl`. Measured with the command below — **49 distinct** SSN-shaped values. The word
  boundaries are load bearing: dropping `\b` from the same scan returns 188, because it
  then matches inside longer digit runs. Narrowing to a TIN/SSN keyword returns fewer
  still, and the window matters — 17 at 24 chars, 20 at 40 — so quote the window with the
  number or not at all. The corpus is live: 157 files / 2,334 occurrences at last check
  (an earlier draft said 3,189, which came from the no-boundary variant, not from drift)

  ```sh
  grep -rhoE '\b[0-9]{3}-[0-9]{2}-[0-9]{4}\b' --include='*.jsonl' \
    ~/.claude/projects | sort -u | wc -l
  ```

  So "the repo is clean" and "the data is contained" are different claims and
  only the first is true. Anything that mines transcripts and writes into this repo —
  step 0's baseline, a telemetry job, a concept seeder reading session history — is a live
  path to reintroducing the leak from a source already certified clean.
  `hooks/pre-commit` is the boundary. It scans **every staged text file**, not a
  whitelist — v1 restricted to `scopes/` and v2 to `*.md`, and both were the same bug on
  a different axis: a `.tsv` carrying an SSN committed cleanly while identical `.md`
  content was blocked. Verified in a scratch clone that it now blocks `.md`, `.tsv` and
  `.py`, and passes ordinary content carrying PR numbers, Linear IDs and CA numbers.
  Raw transcript-derived corpora are also gitignored: a file that is never staged cannot
  be leaked by an amend, and `gt modify -a` behaves like `git add -A`. **Do not carry a raw transcript extract into a commit, and do
  not ship transcript-derived data in anything portable.**
- **"2,050 transcripts" overstates the grader pool.** The file count is live and grows as
  sessions run (2,050 -> 2,096 -> 2,107 across this work), so quote it with a date or not
  at all. More importantly, the majority are
  large majority are subagent transcripts with no answer Kevin accepted, so grading against
  one measures nothing. The real pool is roughly 240 real sessions and ~1,310
  Kevin-authored prompts.
- **Assistant turns are mostly `tool_use`.** In one transcript, 186 tool-use against 102
  text-bearing entries. A fixed lookahead of N entries after a prompt lands inside tool
  calls and misses the answer — it made one pass's citation numbers 4x too low. Window to
  the *next user prompt*, not to N entries.
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

**Acceptance:** treasury reproduces 2,049 nodes / 6,759 edges, and the edge set is
byte-identical when the input file list is reversed. Determinism is not incidental here —
the first version resolved ambiguous bare names by first-match-in-file-order and
manufactured a 190-in-degree hub that did not exist.

### Step 2 — the ranker
```sql
WITH RECURSIVE reach(id, depth, w) AS (
  SELECT :start, 0, 1.0
  UNION ALL
  SELECT u.o, r.depth+1, r.w / (1.0 + log(1 + COALESCE(g.d, 0)))
  FROM und u JOIN reach r ON u.i = r.id
  LEFT JOIN deg g ON g.n = u.o
  WHERE r.depth < 2
)
SELECT id, sum(w) AS score FROM reach WHERE id <> :start
GROUP BY id ORDER BY score DESC LIMIT 10;
```
`und` is the undirected edge view; `deg` is undirected degree — `count(*)` over src and dst unioned, NOT `GROUP BY dst`.

This is committed as `bin/rank.sql` with `bin/rank.sh` as the runner — use those rather
than retyping from here. Two traps the published formula had: `1/log(1+degree)` divides by zero on a degree-0 target, and `COALESCE(i.d, 1)` penalises a node with no in-edges
as if it had one (0.7686 instead of 1.0). The `1 +` in the denominator is load bearing.

**Acceptance:** from `AchPulls::CreateService`, the top 10 is dominated by its actual
data collaborators — `ExternalAchAccount`, `CustomerAccount`, `AchPull`,
`Plaid::MicrodepositVerification` — with `Api::AchPullsController`,
`AchPulls::StateService` and `AchPullsHandler` also present. No framework base class
(`ApplicationRecord`) and no `Types::*` appears.

Kevin confirmed this ordering on 2026-09-16. An earlier criterion required
`AchPushes::CreateService` in the top 10; schema edges moved it to rank 11, displaced by
the data this service actually touches. Do not tune the ranker back toward the sibling —
the corpus in `test/rank-regression.sh` asserts set membership in the top K, not order. Payload stays under 2,000
tokens against a naive 2-hop reach of 418 nodes from that seed, or 980 from
`CustomerAccount`.

Note `OutgoingWires::CreateService` made the top 10 on the pre-fix graph and does not on
the corrected one, so do not treat it as a criterion. `Types` and `ApplicationRecord`
staying out is still a valid check.

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
<!-- machine-owned: regenerated every run, never hand-edit -->
---
concept: [treasury, ach_pull]
related:
  - [treasury, ach_push]         # derived
  - [nova, ach_return_pipeline]  # cross-repo, from the GraphQL op
---
symbols:  AchPull, AchPulls::CreateService, AchPulls::StateService
files:    app/models/ach_pull.rb, app/services/ach_pulls/create_service.rb
graphql:  AchPullType, AchPulls::StateEnum
indexed:  68983603f
<!-- end machine-owned -->

## Judgment            <- prose, never written by the job
BANK-1764 blocks submission when...
provenance: bank-1764-ach-pull-block-submission.md
```
The marker sits ABOVE the frontmatter, so `concept:` and `related:` are inside the
machine block — the job rewrites them every run, and a layout that implied otherwise
meant an edit to `related:` vanished silently. The boundary is structural, not
procedural: **the job must be incapable of writing below the machine-owned block.** A reconciler that could rewrite prose silently reverted 47
hand-written corrections earlier in this work.

### Step 5 — hooks
- `SessionStart` — resolve scope via `git worktree list --porcelain`, rebuild structure
  (under a second), inject preferences + tool list + theme **names**. Ceiling ~500 tokens.
- `UserPromptSubmit` — match prompt against theme names and identifiers, then RANK by
  undirected degree and cut at K. **Never select by name equality:** the token `wire` matches a
  2-symbol namespace exactly, while `outgoing_wire`, `incoming_wire` and
  `external_wire_account` are what the question means. See DESIGN.md.
  **And rank the union of a concept's top symbols, not one of them.** A prompt resolves
  to a concept; the concept's entry points give materially different answers. From
  `ach_pull`: `AchPull` surfaces model peers (AchPush, OutgoingWire, IncomingWire),
  `AchPulls::StateService` surfaces state-machine peers, `AchPulls::CreateService`
  surfaces data collaborators (ExternalAchAccount, Plaid::MicrodepositVerification).
  Picking one entry point silently picks one of those views.
- `PostToolUse` — extract identifiers from tool output → ranker → inject. Second hop
  through the fetched body, depth 2 then stop.

`hooks/memory-scope.sh` exists and is deliberately **not** wired into `settings.json`.

**Acceptance:** re-run the step 0 prompts and compare tokens and accuracy.

### Step 6 — the TypeScript indexer, starting with hydra

**Owner: the nova session.** Kevin's goal is to run this himself against hydra and
iterate without a session in the middle. Everything except the indexer already works on
a TS repo — store, ranker, regression harness, installer are language-agnostic. This is
the one missing piece.

**Start with hydra, not nova.** It is Kevin's daily tool, so the dogfooding is immediate,
and it is a tenth the size:

```
hydra     167 .ts    39,907 LOC    531 exports    756 imports
treasury  1,679 .rb  350,817 LOC
```

**The edge source is imports, and this is structurally safer than the Ruby version.**
Every expensive bug on the Ruby side came from a constant not saying where it lives:
suffix-guessing invented a 190-in-degree hub, and a synthesized `company_id` resolved to
a test mock. TypeScript states the source file. There is nothing to guess.

Of hydra's 756 imports, **268 are relative** (`from './foo'`) and become edges; the other
488 are node/bun builtins and packages — `fs` 47, `path` 40, `child_process` 24,
`bun:test` 71 — which are **external and must be dropped**, exactly as the Ruby indexer
drops its 11,917 unresolvable references rather than guessing at them. hydra's
`tsconfig.json` defines no `paths` aliases, so no alias resolution is needed; check this
again before pointing it at another repo.

**Parser:** `bun`, `node` and `tsc` are all on PATH. TypeScript is not installed inside
hydra. Use the compiler API or ts-morph; do not regex imports — a regex cannot tell a
type-only import from a value import, and `import type` should not create a runtime edge.

**What has no analogue and should not be forced:**
- `fk` / `assoc` / `shares_column` are ActiveRecord. hydra has no ORM. Emit `references`
  only. (nova the *repo* does have Prisma — 180 models, 467 `@relation`, 514 `*Id` — and
  `@relation` names its target explicitly, so nova's schema edges would need no camelize
  guess at all. That is step 7, not this one.)
- `bin/derive-concepts.rb` stem-merges a model with its service namespace, which is a
  Rails naming convention. hydra's boundaries are directories. Concept derivation for TS
  is a separate decision — do not port the Ruby heuristic.

**Acceptance:**
1. `bin/index.sh ~/RubymineProjects/hydra` produces nodes and edges, and `bin/index.sh`
   dispatches on repo language rather than assuming Ruby.
2. Edge set is byte-identical under a reversed input file list. This is the criterion
   that caught three separate order-dependence bugs on the Ruby side.
3. `import type` produces no edge; builtins and packages produce no edge.
4. At least five hydra cases added to `test/rank-cases.tsv`, each a query Kevin would
   actually make — and each verified to *fail* when the fix it guards is reverted. A
   `deny` case on a symbol that some other filter removes unconditionally proves nothing;
   six of the Ruby cases were tautological for exactly that reason.
5. Kevin can run the three-command loop himself:
   ```sh
   ./bin/index.sh ~/RubymineProjects/hydra
   ./bin/rank.sh index/graph.db 'SessionLifecycle'
   ./test/rank-regression.sh
   ```

**Then:** nova the repo (Prisma schema edges), then venture.

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
| `index/`, `*.db` | Gitignored. Graph tables rebuildable; `theme*` tables are not — see section 3. |

**The database is not committed — but it is only half derivable.** `node`, `edge` and
`graph_health` rebuild from source in under a second. `theme`, `theme_file` and
`theme_node` do **not**: they are seeded by a model pass and reviewed by hand, and
`index.sh` never touches them. Deleting the db destroys every seeded theme, and the path
lists exist nowhere else. Verified.

**So step 4 must persist each theme as markdown in git** — the concept template in
section 5 — with these tables as a cache derived from those files. Until that lands,
"delete it and rebuild" is only safe before any theme is seeded.

**Hazards specific to this repo:**

- Never `git clean -xfd`, `git checkout -- .`, or `git reset --hard` here. A `reset --hard`
  destroyed 47 uncommitted corrections once already. Commit first, probe in a scratch clone.
- Graphite's pre-push auto-commits staged files — leftover staging lands on the branch.
- Concurrent sessions share this checkout. Commit carefully.

**Definition of done per step:** the acceptance criterion in section 5 is met, the
pre-push gate has produced 2 consecutive clean rounds, the branch is pushed, and the PR
body states what was *measured* — not what was intended.
