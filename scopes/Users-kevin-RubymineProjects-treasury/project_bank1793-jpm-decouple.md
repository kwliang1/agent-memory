---
name: project_bank1793-jpm-decouple
description: "BANK-1793 create_as_active decoupling — PR #8681 MERGED at aa690fea1; 4 post-merge commits on recreated branch need a follow-up PR; 2 documented gaps await Kevin"
metadata: 
  node_type: memory
  type: project
  originSessionId: f6815ccc-19b2-4577-b925-7da274ee1af8
  modified: 2026-09-04T20:31:09.844Z
---

**PR #8681 (`kevinliang/bank-1793`) MERGED 2026-09-04 20:26:29Z at `aa690fea1`** (CI-green, 23 checks). Migration column shipped separately in #8792 (merged `2271d4b67`).

**4 changes missed the merge by ~3 min.** Branch recreated at `9efd7f107` on origin so they survive. Need a small follow-up PR:
1. `migration_service.rb` — log at the `DeferredActivationConflict` raise site (was the only decision point in the feature with no record; every other branch logs).
2–4. Spec pins: that log; the controller deferral log; and `expect(SubAccounts::InfoService).not_to receive(:missing_active_sub_account?)` on the global-account case — the old spec passed for the wrong reason and its mutant was *flaky* (depended on GlobalAccount id colliding with a CustomerAccount id in an IVC row).

**Two gaps deliberately NOT fixed — await Kevin. Neither is a regression (main behaves the same):**
- **Orphaned TP application → deferral ignored → full-balance wire.** Application row commits (`account_applications/create_service.rb:680`) before the request→application link (`state_service.rb:405-408`). Crash between → orphan → retry mints a 2nd application → on approval `for_application` returns nil → `nil ||` at `treasury_primes_controller.rb:205` defaults to activate.
- **`for_application` unordered `find_by`.** Flagged by 3 agents; 2 independently confirmed it CANNOT move money today — a deferred 2nd request can't share an application because `migrate!` raises `DeferredActivationConflict` on exactly the precondition enabling reuse. Emergent invariant across 5 files, unpinned. Separate pre-existing bug: `complete_sub_account_request!` can pick the terminal row and strand the real request in `ApplicationSubmitted`.

**Key facts worth keeping:**
- `SubAccounts::CreateService#create!` **defaults `create_as_active: false`** → `opened_at: nil` is a NORMAL state on main. Never key a "dormant/deferred" query on the bare shape: it collects SVB/FRB (which `set_active_sub_account!` *refuses* to activate) and GHB-omnibus routing accounts (activating one would wire the balance INTO the routing account). Key on the request's flag instead — state-agnostic, since TP requests are already `completed` when the account exists.
- `treasury_primes_controller.rb:182` replay guard only skips `opened_at`/`closed_at` present, so a dormant account still reaches the activation decision.
- The DIBS rail has **no replay guard at all** (`create_from_dibs_webhook!` calls `create!` unconditionally) — pre-existing.
- `for_application` (any state) at controller:205 vs `in_flight_for_application` at TP create_service:34 is DELIBERATE and lifecycle-driven: by :205 `complete_sub_account_request!` already marked it Completed, so a state-scoped finder there would return nil and silently DROP the deferral.

See [[feedback_minimal-change-in-review-gate]], [[reference_worktree-precommit-hook-stale-main]].
