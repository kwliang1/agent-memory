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
| distinct Linear IDs / PRs / CA numbers | 247 / 425 / 61 |
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
| distinct keys | 1,415 | 1,407 |
| postings (key, file) | 2,409 | **2,192** |
| index bytes (`wc -c`) | 205,854 (201 KiB) | **193,853 (189 KiB)** |
| files per key | median 1, mean 1.7, p90 3, max 21 | median 1, mean 1.6, p90 3, max 21 |
| keys resolving to <=3 files | 1,302 (92.0%) | **1,326 (94.2%)** |
| rebuild, 3 runs | — | 10.2 s / 9.5 s / 9.6 s |

Key classes, excluded variant — the partition reconstructs the total exactly
(247 + 425 + 61 + 674 = 1,407):

| class | count |
|---|---|
| Linear IDs | 247 |
| PR numbers | 425 |
| CA numbers | 61 |
| code paths | 674 |

Two measurement traps found by review and fixed in the script:

- `\b[A-Z]{2,6}-[0-9]{2,5}\b` scoops up `SHA-256` and `AES-256` as Linear issues.
  The builder now uses an explicit team allow-list.
- The code-path class keys on the bare path, so `wire_manual.rb:88` and
  `wire_manual.rb:203` collapse to one key: 674 distinct paths vs 740 distinct
  `path:line`. Keying on the path is correct for lookup — a note about a file is
  relevant regardless of line — but the line belongs in the payload for verification.

**One builder-side defect still open.** The highest-fan-out keys are bare basenames
(`state_service.rb` 21, `index.tsx` 18, `create_service.rb` 16). These are not
high-fan-out identifiers; the citation key is underspecified. A fan-out threshold
treats the symptom — the key needs a repo or directory qualifier.

### Database: yes — SQLite, and the sizing that got here

**Rev 1 of this section was wrong.** It sized the index against these 428 hand-written
notes, found 189 KiB, and concluded no database was needed. Kevin's correction: the notes
are a small subset. The target is a wiki of each codebase — every repo indexed, typed
relations between concepts (`AchPush` <-> `OutgoingWire`), eventually relations across
repos (nova <-> treasury). That is a different object, and it reverses the conclusion.

Measured from `git ls-files`, not estimated:

| repo | code files | LOC | class/module | ruby def | ts export |
|---|---|---|---|---|---|
| treasury | 3,656 | 350,817 | 3,044 | 7,232 | 1,118 |
| nova | 8,317 | 342,858 | 6 | 52 | 13,914 |
| ipseity | 1,048 | 74,727 | 1,416 | 1,877 | 15 |
| venture | 20,550 | 781,886 | 12,007 | 44,609 | 24,990 |
| **total** | **33,571** | **1,550,288** | **16,473** | **53,770** | **40,037** |

~110,000 symbol nodes before any concept layer, against the 428 notes rev 1 measured —
off by roughly 250x.

**SQLite, for the opposite reason rev 1 gave.** Not "too small to need a database" but
"110k nodes and ~1.1M edges is small *for SQLite*, and the traversal is shallow." Loaded
a synthetic graph at the measured shape and timed it:

| query | nodes reached | time |
|---|---|---|
| 1 hop from a symbol | 7 | <10 ms |
| 2 hops (`AchPush` -> `OutgoingWire` shape) | 75 | <10 ms |
| 3 hops | 717 | 10 ms |
| reverse: everything referencing a symbol | 7 | <10 ms |

110,000 nodes, 1,100,000 edges, 88 MB on disk, max out-degree 26, `WITH RECURSIVE` over
an indexed edge table. One global database with a `repo` column — cross-repo edges are a
requirement and cannot span two files.

Ruled out, with the condition that changes it:

- **Neo4j / Memgraph** — earn out at 10^8 edges or deep variable-length pattern matching.
  Depth 1-2 at a thousandth of that scale does not justify a daemon.
- **Kuzu** is the real escalation path, not Neo4j: embedded, no daemon, Cypher, built for
  this. Move if edges pass ~10^7 or queries become genuine pattern matching. Young, so
  not first.
- **Vectors are now in scope**, unlike rev 1. "How does treasury handle partial ACH
  returns" carries no identifier. `sqlite-vec` puts embeddings in the same file, so
  concept similarity is one more edge kind rather than a second system.
- **Postgres** only if this stops being single-machine. Nothing points that way.

### Build order: static analysis first

An LLM pass over raw source is ~16M tokens for one pass and yields edges nothing can
verify. Most of the skeleton is already on disk:

- **9,344 Sorbet RBI files** across treasury (2,394), ipseity (1,824) and venture (5,126)
  — a precomputed symbol table currently unused.
- **24 Packwerk packages** (treasury 12, venture 12) — author-declared concept
  boundaries, free and already correct.
- nova has neither, so it needs the TypeScript compiler API.

Static analysis gives symbol nodes and call edges exactly; the model's job narrows to
naming themes over that structure. Nightly runs re-index only what `git diff` changed.

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

There are 1,412 machine-checkable assertions to verify: 740 citations, 425 PRs, 247
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
