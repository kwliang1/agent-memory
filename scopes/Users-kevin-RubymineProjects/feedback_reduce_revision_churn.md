---
name: feedback_reduce_revision_churn
description: How to cut the number of revision rounds Kevin needs on proposed code/wording
metadata: 
  node_type: memory
  type: feedback
  originSessionId: b3595ab6-e83d-4c27-9b30-23fa6f1d5aae
  modified: 2026-08-21T15:45:29.811Z
---

Kevin runs an intensive, iterative review. To reduce rounds, lead with a draft he'll *extend*, not one he has to *pare down / redirect*.

**Do on the first pass, by default:**
- **Apply his already-stated preferences** instead of the "parity with existing code" default: AR over raw SQL (raw only with a benchmark to justify — on real data, e.g. `make setup` / Tonic dump, not synthetic); `# typed: strict` on new/refactored service files; terse one-line comments; plain house voice for prose (see [[feedback_external_writing_style]]).
- **Consolidate / reuse before creating.** Search for an existing home first: extend the sibling service rather than adding a new class; reuse canonical constants/maps (e.g. `Entity::IDENTITY_DATA_MODELS`); extract cross-cutting helpers to a `lib` util rather than a private method. He pushed back on a separate `NameLookupService`, a duplicative constant, and an inline `normalize_uuid`.
- **Outline-first for anything wordy or forky.** Before writing a full PR description or a non-trivial design, send a short outline (or the design shape + the 1–2 real forks with a recommendation) and get a yes. Revising an outline is cheap; revising finished prose + code isn't.
- **Back perf/design claims with evidence up front**, in the PR desc — don't assert from reasoning and wait to be asked to benchmark.

**Why:** on NOVA-3883, ~a dozen review rounds were spent redirecting first drafts on naming, consolidation, AR-vs-raw, strict typing, uuid-lib extraction, wire-key naming, and density — most of which trace to leading with a maximalist/parity draft rather than a preference-applied, consolidated, lean one.
