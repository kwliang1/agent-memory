---
name: customer-accounts-create-incorporation-country-flake
description: "Api::CustomerAccountsController#create 'creates a customer account' fails ~half of seeds since BANK-2233 (#9065): mock company's incorporation_country is random US/GB/CA, US routes to DIBS so resolve_program! is never called"
metadata:
  node_type: memory
  type: project
  originSessionId: 0c12266a-b6ce-4835-b0ce-74ea8ae43c61
  modified: 2026-10-07T17:38:33.409Z
---

Seen 2026-10-07 on #9074 (BANK-2236), CI rspec-treasury-2 failed twice with `expected: 1 time ... received: 0 times` on `SubAccountRequests::InfoService.resolve_program!` (`spec/controllers/api/customer_accounts_controller_spec.rb:145`).

Cause: `lib/mocks/entity_api/identity_data/company.rb:63` samples `incorporation_country` from US/GB/CA. BANK-2233 (`customer_account/verification.rb` `should_open_dibs_sub_account?`) sends a domestic US-incorporated company to DIBS, skipping `resolve_program!`. Locally 5/9 seeds fail; seed-dependent, not order-dependent.

**Why:** unrelated PRs go red on it; a retry is a coin flip.
**How to apply:** if this example fails on a PR, it's this flake. Fix = pin the spec's mock to a non-US incorporation_country (separate PR; Harsohail's test). Check whether that fix has merged before retrying.
