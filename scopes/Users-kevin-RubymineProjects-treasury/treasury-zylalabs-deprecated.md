---
name: treasury-zylalabs-deprecated
description: ZylaLabs SWIFT/IBAN lookup is fully dead in treasury (code #7799, config #8880, vendor account canceled); plus the configtool 1-key-renders-to-3-Secrets gotcha.
metadata:
  type: project
---

**ZylaLabs is completely gone from treasury.** Three layers, all closed as of 2026-09-15:

1. **Code** — PR #7799 / commit `d19207ed8` ("completely deprecate DIBS::SwiftWireRecord + ZylaLabs + flag gating", BANK-1288), merged 2026-06-08. Deleted `app/services/swift_iban_routing_number/lookup_service.rb` (the sole reader; hardcoded base URL `zylalabs.com/api/1887/...`, bearer from `ENV['SWIFT_IBAN_ROUTING_NUMBER_LOOKUP_KEY']`), the `DIBS::SwiftWireRecord` model + table (migration `20260608110000_drop_swift_wire_records.rb`), and the whole GraphQL surface. `DIBS::SwiftRoutingRecord` (ISOBIC-seeded) is now the only source of SWIFT data and makes **no network calls at all**.
2. **Config** — that PR left the credential in configtool for 3 months. Removed by PR **#8880** (`chore(config): remove dead ZylaLabs SWIFT lookup API key`), branch `kevinliang/remove-zylalabs-lookup-key`.
3. **Vendor** — Kevin confirmed the ZylaLabs **account is canceled**, so the ciphertext still in git history is inert. Not derivable from the repo — don't re-raise it as a leaked secret.

**Why:** a future grep will hit the encrypted blob at `config/configtool/prod-us-west-2-zeus/config.yaml:119` on older commits and look like a live credential. It isn't.

**How to apply:** treat any remaining `zylalabs` / `SWIFT_IBAN` hit as history-only. If SWIFT bank data is needed, `DIBS::SwiftRoutingRecord` is the answer.

---

**Reusable configtool gotcha (cost me a wrong prediction):** one key in a stack's configtool files renders into **three** k8s Secrets, not one — `treasury-config` (from `config.yaml`), plus `config-ro` **and** `config-ro-console` (both from `config-readonly.yaml`; the console one is readonly ∪ `config-readonly-overrides.yaml`). So deleting a key that lives in both `config.yaml` and `config-readonly.yaml` shows **3 hunks per stack** in the CI deploy-diff comment. Don't tell anyone to expect one. Each stack dir has *three* files, not two.

Related: the deploy-wave hazard documented in PR #8762 — Secrets apply at ArgoCD wave 0 while workloads roll at 10-50, and there's no `checksum/config` annotation or Reloader, so removing a still-read key can strand an old-image pod. Only safe when the reader is long since rolled out. See [[treasury-local-dev-gotchas]].
