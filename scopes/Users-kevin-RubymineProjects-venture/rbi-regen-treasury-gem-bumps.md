---
name: rbi-regen-treasury-gem-bumps
description: "When bumping treasury (protobuf) gems, regenerate both gem AND DSL RBIs; exclude make-rbi drift"
metadata: 
  node_type: memory
  type: project
  originSessionId: 2fbca691-8ddc-4811-9d3e-104c63130845
---

When bumping `treasury_api` / `treasury_prophet_api` (protobuf-backed gems) in venture, the Sorbet RBIs come from **two** tapioca passes — regenerate both:
- `bin/tapioca gem treasury_api treasury_prophet_api` → `sorbet/rbi/gems/treasury_*@<ver>-<sha>.rbi` (gem RBIs; filename includes git revision)
- `tapioca dsl` (or `make rbi`) → `sorbet/rbi/dsl/treasury_api/messages/**` DSL RBIs, e.g. `outgoing_wire.rbi`, `standalone_banking/ledger_entry/category.rbi` (new protobuf fields like `imad`/`omad` and new enum constants land here)

**Easy to miss:** running only `tapioca gem` leaves the DSL RBIs stale.

**`make rbi` over-reaches — don't commit its full output to a scoped PR.** It also:
- rewrites stale model annotations across unrelated `app/models/**` (capital_call, deal_share, cptr, settings…) — drift from other people's merges, not your change. Drop these (or do a separate annotation-sync PR).
- **deletes `sorbet/rbi/gems/resolv@0.7.1.rbi`** — local tapioca treats `resolv` as a Ruby default gem and skips it, but `main` intentionally commits it (`Gemfile:278` pins `gem 'resolv', '>= 0.6.1'`, bundler resolves to 0.7.1 over the 3.4.8 default 0.6.2). Restore it: `git checkout HEAD -- 'sorbet/rbi/gems/resolv@0.7.1.rbi'`. Do NOT change the resolv dependency in a feature PR.

After regen, keep only the treasury-related gem + DSL RBIs; restore everything else to match main. See [[graphql-schema-regen]] for the parallel schema-export step.
