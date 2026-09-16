---
name: reference_temporal-sig-widen-inflight-drain
description: "Widening a Temporal activity arg type for in-flight drain? Widen the WORKFLOW execute sig too — config/sorbet.rb turns a strict-sig mismatch into Sentry noise on replay, and specs can't catch it."
metadata: 
  node_type: memory
  type: reference
  originSessionId: 23b68fa9-be75-423c-be38-7d8010b45530
  modified: 2026-07-27T21:46:18.457Z
---

When changing a Temporal workflow/activity argument type (e.g. int `application.id` → `application.uuid`) and adding a transitional lookup so **in-flight workflows drain** without breaking, widen the sig on BOTH the workflow `execute` AND the activity `execute` — e.g. `T.any(String, Integer)`.

Why: in-flight workflows replay with their ORIGINAL arg (the Integer) baked into Temporal history. `config/sorbet.rb:17-31` makes every `sig` runtime-validated (`class Module; include(T::Sig)`) with a *lenient* `call_validation_error_handler` — on a type mismatch it does NOT raise (a plain `sig` has `on_failure=nil`), it calls `ErrorTracker.error` → **Sentry**. So a strict `String` sig on the workflow, replayed with the legacy Integer, spews spurious "Expected String, got Integer" Sentry errors on every replay (potentially ×100 with retries). The activity alone being widened isn't enough — the workflow is replayed too.

Critically: `config/sorbet.rb:18` is `next if Rails.env.test?`, so this validation never fires under RSpec — **no spec can catch this class of bug**. It's caught only by reasoning + reviewing sig consistency across the whole replay path (workflow execute, activity execute, and anything called with the raw replayed arg before it's resolved to a record). Caught in BANK-1511 review round 3 after rounds 1-2 missed it. See [[project_bank1511-mmf-dry-refactor]].

Drop the widened sigs + the transitional lookup once in-flight workflows have drained.
