---
name: feedback_brief_review_agents_with_memory
description: "Hooks give subagents the CODE GRAPH but never the markdown scope memory — no hook reads scopes/ at all, so paste the relevant notes into reviewer prompts"
metadata:
  node_type: memory
  type: feedback
  originSessionId: b5e49ee1-6ed2-4ee7-8096-aa2221085908
  modified: 2026-09-29T22:58:10.339Z
---

Subagents run the same harness and **do** get the code-graph injection. What they never get — and
what nobody gets automatically — is the **markdown scope memory** under `~/agent-memory/scopes/`.

**Verified 2026-09-29, not assumed:**

- `PostToolUse` on `Read|Grep|Glob|WebFetch` runs `agent-memory/hooks/memory-retrieve.sh`, which
  fires for subagents too. Run by hand with a *worktree* cwd it resolves the repo correctly —
  `git worktree list --porcelain`'s first line is the main worktree, so `repo=treasury` — and emits
  the `Related code in treasury (ranked, 2 hops)` block. **Worktree cwd is not the problem.**
- But that hook only ever emits **graph symbols with file:line**. `grep -n 'scopes/|MEMORY.md|\.md'`
  over it returns nothing, and `grep -rln 'scopes/' hooks/` matches only `hooks/pre-commit`.
  **No hook injects the markdown notes, for anyone.**
- The umbrella `MEMORY.md` says so itself: *"Read the matching scope before starting work on any
  repo named below. Nothing loads it for you."* My own scope reads this session were manual `cat`s.

So a reviewer gets symbols and file:line, never the incident write-ups — the accumulated
"here is the trap" knowledge. That is exactly the part that would have saved a round.

**Why it matters:** on treasury BANK-2179 (Terran Robotics) two of three reviewers' headline
findings were wrong, and both errors were documented in
[[project_terran-robotics-wire-omnibus-shortfall]]:

- Its **"Query trap"** line says filtering `LedgerEntry` on `origin/destination = CustomerAccount`
  misses the outbound return legs, because the *wire* is the origin/destination. The domain
  reviewer made that exact query, missed LE 5757530/5757532, and asserted "no ledger skew — stop
  re-litigating it." Refuted by pulling every entry on both sub-account rows: both are $0.00.
- It names T199653/T199654 as the GHB→SVB **returns** three times. The ops reviewer conflated them
  with T200394/T200395, the SVB→GHB **forwards**, and concluded the repair ACH would stall forever
  in `sent_pending_arrival`. Refuted by 771 completed credit ACHs into SVB.

**How to apply:** `cat` the relevant scope files and paste their text inline into each reviewer
prompt, the same way CLAUDE.md's review-loop rule 2 already requires for the diff. Pick the
incident/project file plus any `reference_*` hazard file the diff touches. ~12KB per reviewer
against a ~200k budget. Do not rely on a hook for this; there isn't one.

**Token shape of a gate.** One session on 2026-09-29 measured reviewers at ~62% of spend. Across 132
gate sessions (2026-10-08, [[feedback_gate_in_fresh_session]]) it is **~46%**, with the main thread
inside the gate window ~47% and leftover context ~7%. Both halves are worth cutting.

**What else belongs in the brief** (from [[reference_gate_mining_2026_10]]):
- The diff inline, or a `git diff <base>...<sha>` command. On Opus 5.5 that ran in ~80s with
  11 tools; a `.diff` file path took ~120s with 19 tools. Only 2% of briefs put the diff inline.
- An inventory: callers of changed functions, writers of changed columns, and every surface that
  shows the field. ~13 late resets were sibling call sites already within the diff's reach.
- The declined findings with their evidence ([[feedback_gate_declines_need_evidence]]).
- The orchestrator's typecheck and test results, so reviewers do not re-run suites.

Related: [[feedback_verify_reviewer_negative_results]]. Both refutations above came from prod
queries, not argument — and this note's own first draft blamed worktree cwd until Kevin pushed back
and the hook was actually run.
