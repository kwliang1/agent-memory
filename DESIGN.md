# Memory system — design notes

Working document. Conclusions and evidence as of 2026-09-16, from the session that
reorganised the corpus and investigated claude-mem.

---

## What we found

**There is no retrieval today.** Measured across 2,050 session transcripts: the
`MEMORY.md` index is injected at session start 454 times; automatic recall of a memory
*body* appears **zero** times. System-reminder injections do persist to transcripts —
that is how the index is observable — so a recall would be equally visible. Two sessions
reached this independently by different markers.

So the whole mechanism is: an index is pasted into context, and the model decides what
to open. A curated table of contents, not an index in the search sense.

Three consequences drove everything else:

- A file with no pointer is **unreachable**, not merely harder to find. 210 of 431 files
  were in that state, including 27 standing behavioural rules.
- Scope is keyed to cwd. Hydra-spawned sessions sit at the umbrella cwd, so they never
  auto-load treasury's or nova's index. Worktree sessions have no memory directory at all.
- Cost scales with the index, not the corpus. ~428 files ≈ 1.3 MB of bodies cost nothing
  until opened; the indexes are what every session pays for.

**The corpus is compensation, not the design.** These files exist *because* there was no
automatic system. Tonight's price for maintaining them by hand: eight review rounds,
~44 hooks that misstated their own file, 210 orphans, and a reconciler that silently
reverted 47 hand-written corrections while reporting success. That is the true cost of
manual persistence, and it is not worth paying again.

---

## Shape of the corpus

| | |
|---|---|
| memory files | 428 across 9 scopes |
| reachable by >=1 identifier | **349 (81.5%)** |
| distinct Linear IDs / PRs / CA numbers | 245 / 380 / 69 |
| code citations (`file.rb:123`) | 740 |
| wikilinks between memories | 605, 75% of files have ≥1 outbound |
| files nothing links to | 202 |
| assert a PR/issue state | 166 |
| carry a dated state stamp | 359 |
| pure durable rule, no state | **61** |

The last three rows are the important ones: **~85% of these files mix a durable
conclusion with a volatile state claim**, and every defect eight review rounds found was
in the volatile half. The conclusions held up.

---

## The retrieval model

**Eager layer: bare minimum.** Standard preferences plus the list of available tools.
Not a section index, not a scope directory. Everything else is pulled.

**Retrieval is identifier lookup, not search.** The queries this work generates are
identifier-shaped — a Linear ID, a PR number, a CA number, a file path.
Measured precision on a keyed lookup: 1–3 files per identifier.

```
BANK-1746   -> 3 files     #8574        -> 1 file
BANK-1707   -> 2 files     CA 465829    -> 1 file   (the $1.8M do-not-reorder)
NOVA-3740   -> 2 files
```

All five verify against the current index. Identifier lookup beats full-text on these
queries because the keys are literal strings in the text — but see the 18.5% gap below:
it does not cover everything, which is why the embedding layer is in scope.

An env-var key class was tried and dropped: an ALLCAPS sweep returns 1,825 tokens, too
noisy to use without an allow-list.

**Triggered by what the agent pulls, not only by the prompt.** The unlock is a second
hop: fetch a Linear issue → its ID keys the first memory → identifiers *inside the ticket
body* (an MMF Sell, a BookTransfer, a CA number) key the next. Bounded expansion, depth
1–2 so it terminates. Retrieval becomes a side-effect of doing the work rather than
something someone has to remember to invoke.

**Gap: 79 files (18.5%) carry no identifier**, measured — not the 38 (9%) an earlier
pass claimed. Many are general preferences, which load eagerly anyway, but 18.5% is a
real hole and it is the argument for the embedding layer rather than against it.



### Built and measured, not estimated

Reproduce with `bin/measure-index.sh` (add `--naive` for the right-hand column).
Every figure below is that script's output, not an estimate.

| | naive | excluding `MEMORY.md` |
|---|---|---|
| files indexed | 440 | **428** |
| distinct keys | 1,415 | **1,368** |
| postings (key, file) | 2,409 | **2,139** |
| index bytes (`wc -c`) | 205,854 (201 KiB) | **189,563 (185 KiB)** |
| files per key | median 1, mean 1.7, p90 3, max 21 | median 1, mean 1.6, p90 3, max 21 |
| keys resolving to <=3 files | 1,302 (92.0%) | **1,288 (94.2%)** |
| rebuild, 3 runs | — | 10.2 s / 9.5 s / 9.6 s |

Key classes, excluded variant — the partition reconstructs the total exactly
(245 + 380 + 69 + 674 = 1,368):

| class | count |
|---|---|
| Linear IDs | 245 |
| PR numbers | 380 |
| CA numbers | 69 |
| code paths | 674 |

Measurement traps found by review and fixed in the script:

- `\b[A-Z]{2,6}-[0-9]{2,5}\b` scooped up `SHA-256` and `AES-256` as Linear issues. Now an
  explicit team allow-list (BANK, NOVA, INC, USVC, SEC, WALLET, OP, TER, N). `N` is a
  real Linear prefix — `N-167` is a Nova issue with its own memory file — so it stays.
- `#[0-9]{3,6}` swallowed 8 `CA#`, 6 `DCR#` and 50 `Record#id` forms as PR numbers. A CA
  number checked against the GitHub PR API 404s and reads as a deleted PR. Now guarded by
  a negative lookbehind, and the CA class accepts `CA#` as well as `CA-` and `CA `.
  Residual limit: a few numbers appear both as `DCR#3003` and bare `#3003` in prose, which
  no regex can disambiguate.
- The code-path class keys on the bare path, so `wire_manual.rb:88` and
  `wire_manual.rb:203` collapse to one key: 674 distinct paths vs 740 distinct
  `path:line`. Keying on the path is correct for lookup — a note about a file is
  relevant regardless of line — but the line belongs in the payload for verification.

**One builder-side defect still open.** The highest-fan-out keys are bare basenames
(`state_service.rb` 21, `index.tsx` 18, `create_service.rb` 16). These are not
high-fan-out identifiers; the citation key is underspecified. A fan-out threshold
treats the symptom — the key needs a repo or directory qualifier.

### Database: SQLite

The store is one SQLite file per machine holding `node`, `edge`, `graph_health`, `theme`,
`theme_file` and `theme_node`, plus FTS5. It is gitignored, but **only half of it is
derived**: `node`, `edge` and `graph_health` rebuild from source in under a second, while
the `theme*` tables are seeded by a model pass and derivable from nothing. Deleting the
file restores the graph and destroys every theme — demonstrated, not assumed. Step 4 must
persist each theme as markdown in git so the disposability property comes back.

Scale, measured rather than extrapolated: treasury's real graph is **2,049 nodes and
6,759 edges, ~1.9 MB**. An earlier estimate of "110,000 symbol nodes across four repos"
was grep-derived and too high; grep counted `class << self` and matches inside strings
and comments. treasury by AST is 2,049 against 3,044 by grep. The other three repos need
the same AST treatment before any cross-repo total is quoted.

At this scale the database is not the constraint — the **ranker** is (see below). Ruled
out, with the condition that changes each:

- **Neo4j / Memgraph** — earn out at 10^8 edges or deep variable-length pattern matching.
  We are six orders of magnitude below that and they cost a daemon.
- **Kuzu** is the escalation path if edges pass ~10^7 or queries become genuine pattern
  matching: embedded, no daemon, Cypher. Young, so not first.
- **Vectors are in scope.** 79 of the 428 notes (18.5%) carry no identifier, and "how
  does treasury handle partial ACH returns" has none either. `sqlite-vec` keeps
  embeddings in the same file, so similarity is one more edge kind rather than a second
  system.
- **Postgres** only if this stops being single-machine. Nothing points that way.

One global database with a `repo` column, not one per repo — cross-repo edges are a
requirement and cannot span two files.

### Measured against treasury, not modelled

An earlier revision sized traversal on a synthetic graph with uniform edges and max
out-degree 26. That assumed away hubs — the one property that decides whether this
works. Kevin pushed back on the token numbers and was right.

Real treasury graph, built with Prism over `app`, `lib`, `backend` — 1,679 Ruby files
in under a second (`bin/build-graph.rb`):

| | |
|---|---|
| class/module nodes | 2,049 |
| resolved reference edges | 6,759 |
| as a SQLite file | ~1.9 MB |
| out-degree | median 3, mean 4.1, p90 9, p99 21, **max 105** |
| in-degree | median 1, mean 3.8, p90 6, p99 54, **max 298** |

Top hubs: `CustomerAccount` 298, `ErrorTracker` 130, `SubAccount` 129,
`ApplicationRecord` 117. Heavy-tailed, which is normal for a call graph and fatal for
naive traversal. (An earlier pass reported `Types` 359 and `DIBS` 315 as the top two;
both were artifacts of a prefix-emission bug, and a rank-4 hub at 190 was fabricated
outright by a resolver that guessed at ambiguous bare names. Both fixed.)

**Retrieval is ranking, not reachability.**

| query from | 1 hop | 2 hops directed | 2 hops undirected | tokens naive |
|---|---|---|---|---|
| `AchPulls::CreateService` | 11 | 82 | **418** | ~83,600 |
| `OutgoingWire` | 110 | 61 | **631** | ~126,200 |
| `CustomerAccount` | 309 | 111 | **980** | ~196,000 |

Undirected is the honest case — "related concepts" means callers as well as callees —
and 980 of 2,049 nodes is 48% of the repo for one injection. So weight each hop down by
how generic its target is:

```
score(n) = sum over paths of  prod  1 / (1 + log(1 + in_degree(target)))
```

Top-10 from `AchPulls::CreateService` on the real graph:

```
2.115  Api::AchPullsController                 1-hop
1.663  AchPullsHandler                         1-hop
1.486  CustomerAccount                         1-hop
1.481  AchPulls::StateService                  2-hop
1.228  AchPushes::CreateService                2-hop   <- the AchPush sibling relation
1.211  OutgoingPayment::StateService           2-hop
1.148  Maintenance::ReinitiateErroredFundsMigrationTransfersTask
1.145  FraudPrevention::ComplianceRulesService 2-hop
1.136  Internal::Api::V1::ExternalAchAccountsController
1.136  Api::PlaidsController                   2-hop
```

`AchPushes::CreateService` — the sibling relation Kevin named — surfaces unprompted at
rank 5, and `Types` and `ApplicationRecord` do not appear at all. Honest caveat:
`OutgoingWires::CreateService` made rank 9 on the pre-fix graph and does not survive into
the corrected top 10, so only one of the two named examples is a live demonstration. **~196,000 tokens -> ~2,000.** The ranker is a
required component, not an optimisation.

### Concepts

A concept merges the model and its service namespace by stem — `AchPull` plus
`AchPulls::*` become one `ach_pull` — with structural namespaces dropped. 125 derived
for treasury by `bin/derive-concepts.rb`, listed in `seeds/treasury-concepts.tsv` for
review. Kevin's format: `[treasury, ach_pull]`, `[nova, transfers]`.

Generation is automatic; the **initial seed list is reviewed by hand** before anything
is written.

**Template** — the same ownership boundary as the maintenance design:

```
---
concept: [treasury, ach_pull]
related:
  - [treasury, ach_push]         # derived, sibling
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

File references sit in the machine block so they update continuously; judgment sits
below it where the job cannot reach.

### Cross-repo relations: camelCase modules, not PascalCase types

An earlier pass here claimed "name matching returns zero." That was wrong — the test was
aimed at a naming convention nova does not use for these.

PascalCase declarations do return zero: nova declares no `class|interface|type|enum`
named `Transfer`, `OutgoingWire`, `AchPush` or `OutgoingPayment`, and its own
`TransferType` (153 files) is unrelated to treasury's. But nova names treasury's concepts
as **camelCase modules**, in 25 files:

```
graph/src/clients/treasury/index.ts:2   export * from './operations/achPull';
graph/src/clients/treasury/index.ts:14  export * from './operations/outgoingWire';
graph/test/factories/treasury.ts:1     import type { CreateAchPullResponse } from
                                        'clients/treasury/operations/achPull';
```

So there *is* a derivable syntactic bridge, and `graph/src/clients/treasury/` is a
directory named for the dependency. Match on the camelCase/snake_case stem across
conventions, not on identifier equality.

The relation is real in the domain and has no syntactic trace in either codebase. Three
sources that do work, in descending reliability:

1. **GraphQL operations** — nova sends `query ALTreasury`, `query AchReturnPipelineState`,
   `mutation ConfirmRecipientDistributionPayment`, resolving into treasury's 402
   `app/graphql` files. Derivable and verifiable.
2. **The existing notes** — 31 already assert cross-repo relations in prose (22
   treasury->nova, 9 nova->treasury). Free and already correct.
3. **Kevin naming them.** There will be a residual.

### Worktrees

47 live treasury worktrees; 13 have a scope directory; **0 memory files in any of them**.
treasury proper has 170.

```
git worktree list --porcelain | head -1   ->  /.../treasury           correct
git rev-parse --show-toplevel             ->  /.../treasury-1746      wrong
```

`--show-toplevel` returns the worktree, not the repo, and it is what claude-mem uses. No
path heuristic works either: treasury's worktrees live under four different parents.

Index main, overlay the branch. `git show main:<path>` reads main from inside a worktree
without touching the working tree, and all worktrees share one object store. *Switching*
would be the dangerous version. Across all 47 the worst `main...HEAD` delta is 52 files;
the median is single digits, and 39 files reparse in 0.015 s.

### Nightly is nearly pointless for structure

A full structural rebuild is under a second. Rebuild at session start and structural staleness
stops existing as a concept. The nightly only needs to exist for the concept layer and
the citation verifier.

### Acceptance criteria

Kevin's litmus test: run a session under the new system and measure accuracy of output
plus token usage, per prompt and per session. Correct bar — but the baseline has to be
captured *before* anything is built, or "accuracy up, tokens down" is unfalsifiable.

- **Prompts** — 30-50 real ones pulled from the 2,050 transcripts already on disk, not
  invented. They carry the answer Kevin actually accepted, which is the grader.
- **Accuracy** — did the session cite the right file, PR and prior decision.
- **Tokens** — eager layer at session start, injected memory per tool call, and session
  total. All three, because the design trades the first against the second.
- **Regression** — cases where injected memory made the answer *worse* by asserting stale
  state. Five topics in the current corpus have files that disagree about one ticket, so
  this is a measured failure mode, not a hypothetical.

Proving ground order, per Kevin: **treasury first, then nova, then venture.**

---

## Maintenance

Auto-edit, not a report. A nightly report someone has to process is a report nobody
reads — demonstrated this session, where twelve rules were *labelled* misfiled and then
sat unmoved for two more rounds.

But auto-edit is exactly how the reconciler did its damage. The fix is a structural
ownership boundary, not more care:

- **Machine-owned block** — a fenced section the job rewrites wholesale: PR state, Linear
  status, file:line coordinates, last-verified date. Free to auto-edit; nothing
  hand-written lives there.
- **Prose body** — never written by the job. A citation that has vanished entirely
  (`alloys_controller.rb`, deleted by #8458) is a judgment call: flag, do not rewrite.

There are 1,365 machine-checkable assertions to verify: 740 citations, 380 PRs, 245
Linear IDs. A 25-path treasury sample already had **3 pointing at deleted files**. This
check would have caught a large share of what eight manual rounds found.

**TTL belongs on state claims, not on memories.** Age is not wrongness —
`treasury-op778` is from August and is still the thing standing between someone and
wrongly rejecting a live $1.8M payment. But five topics currently have two files each
(`bank-1586` has three) disagreeing about one ticket's state, and a newest-wins
supersession rule collapses those automatically.

**Operational controls**, first-class rather than discovered later: hard size cap with
oldest-first eviction, periodic checkpoints, and an *enforced* token ceiling on whatever
loads eagerly.

**The repo makes auto-edit safe.** Every nightly change is a signed commit and a
reviewable diff, so the weekly report is `git log --since=1.week` rather than a separate
artifact to maintain.

---

## claude-mem — read at source, not from docs

Repo: `thedotmack/claude-mem`. Docs do not answer the scoping question; the source does.

**Project identity is better than expected** (`src/utils/project-name.ts`):

- Prefers `CLAUDE_PROJECT_DIR` over raw cwd, so subagent temp cwds never become the
  project identity (their #3437).
- Derives the name from the **git repo root** via `rev-parse --show-toplevel`, so it is
  stable across subdirectories and worktrees (their #2663).
- `getProjectContext` returns a **compound key** for a worktree —
  `parent/worktree` — plus `allProjects: [parent, composite]`, and an `isWorktree` flag.

That natively solves the worktree-to-parent mapping this repo's `memory-scope.sh`
hand-rolls, and solves it better.

**So the earlier conclusion — "it would only create memory within the hydra dir" — is
wrong.** Storage is one global SQLite (`~/.claude-mem/claude-mem.db`) with an indexed
`project` column on `observations` and `sdk_sessions`, and FTS5 search with combined
filters. Not per-directory silos.

**The real consequence for hydra is different and smaller:**
`/Users/kevin/RubymineProjects` is not a git repo, so a plain hydra spawn falls back to
the cwd basename and every umbrella session shares one `RubymineProjects` bucket.
Worktree spawns resolve correctly to their parent repo. That is a filter/config problem,
not an architectural wall.

**Privacy is the blocking objection.** `PrivacyCheckValidator` operates on the *user
prompt*: content wrapped in `<private>` tags is stripped, and a wholly-private prompt
suppresses the observation. **There is no PII filtering on captured tool output.** The
`PostToolUse` hook fires 100+ times per session, capturing tool executions and
AI-compressing them.

This session leaked customer SSNs, a full bank account number, and a residential address
from **hand-written** notes. Auto-ingesting `al console` reads, Sentry payloads and DB
rows is strictly worse, and an opt-in tag is the same shape as the index pointer nobody
remembered 210 times.

**Capture is unfiltered, at source.** `src/cli/handlers/observation.ts` posts
`tool_name`, `tool_input`, `tool_response` and `cwd` to the worker. Raw tool input *and*
response, no filtering at the hook, then AI-compressed. For this work that means prod
console reads, Sentry payloads and DB rows.

**No retention policy exists.** Grepping for retention, eviction, pruning, vacuum, row
caps or age-based deletion across `src/` returns nothing for the local SQLite — the only
`DELETE FROM observations` statements are single-row by id, for server/team deletion. The
database grows without bound. That is a direct miss against the size-cap and checkpoint
requirements.

**Verdict — build, don't fork.** Three of its four relevant subsystems are wrong for this
use: retrieval is FTS5-over-prose where identifier lookup fits better; capture is an
unfiltered firehose that would have to be removed; and the operational controls are
absent rather than merely different. The one genuinely good part is project identity
(`getProjectContext`), which is 192 lines across two files (`project-name.ts` 125,
`worktree.ts` 67; five functions) and can be reimplemented or vendored. Forking
means carrying the whole repo's churn to keep one file. (An earlier draft cited
"291 MB and 223 releases" — unverifiable, the local clone at /tmp/cm-src is shallow and
tag-less, so that figure is withdrawn.)

---

## Hooks in hydra — verified

Hooks fire normally in hydra sessions. The daemon `.env` sets
`CLAUDE_CONFIG_DIR=/Users/kevin/.claude` and `session-lifecycle.ts:131` exports it into
every spawn; confirmed from inside a hydra-spawned session. No hydra-side work is needed
for a `PostToolUse` or `SessionStart` hook.

---

## Build order

1. **Identifier index** — Linear IDs, PRs, CA numbers, file paths, env vars → files.
   Cheap, trivially maintained, and the verifier already walks these exact tokens.
2. **Tool-use triggered lookup** — a `PostToolUse` hook that spots identifiers in what
   the agent just fetched and injects matching memory, including the second hop through
   the fetched content. This is what makes it ergonomic instead of another tool someone
   has to remember.
3. **`verify-memory`** — walk the ~1,500 assertions, auto-edit the machine-owned block,
   flag judgment cases. launchd nightly, plus a `Stop` hook scoped to touched files.
4. **Trim the eager layer** to preferences plus tool list.
5. **Migration** — add the machine-owned block to the 359 files carrying state.

Nothing writes a memory conclusion without a human in the loop.

---

## Open

- How much of the corpus should survive as durable memory at all? ~61 files are pure
  rule; much of the rest is state a database should own and expire.
- Whether the promotion path (observation → durable memory) is manual, suggested, or
  automatic with review.
- Two repos still hold leaked data in their history and need deleting:
  `kwliang1/claude-memory` (SSNs) and `kwliang1/claude-memory-v2` (account numbers).
