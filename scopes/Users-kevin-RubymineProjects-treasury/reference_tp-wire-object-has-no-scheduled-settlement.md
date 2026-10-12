---
name: reference_tp-wire-object-has-no-scheduled-settlement
description: "Treasury Prime's wire object has NO scheduled_settlement field — it is ACH-only, and debit-scoped even there; this decides the CrossTransfer completion predicate"
metadata:
  node_type: memory
  type: reference
---

**Verified against Treasury Prime's own API docs, 2026-09-29** (docs.treasuryprime.com/reference/get_wire).

The TP **wire** object's fields are: `account_id, amount, bankdata, chips_ssn, counterparty_id,
error, fx_quote, id, imad, instructions, intermediary, omad, org_id, purpose, status,
target_currency_code, uetr, userdata`. **There is no `scheduled_settlement`.**

On the **ACH** object `scheduled_settlement` exists but is scoped to **debits** — it is the timestamp
at which a debit's credit hold is released. For an ACH **credit** TP returns the key *present with
value `null`, permanently*. Confirmed in prod 2026-09-21 by refetching a sent ACH 6 days later:
still `scheduled_settlement: nil, direction: credit`.

**Why this matters.** `treasury_prime/cross_transfers/state_service.rb` distinguishes
`response.keys.include?(:scheduled_settlement)` from `response[:scheduled_settlement].present?`.
Given the above:
- wire rail → key **absent** → the key-presence test yields "complete without a settlement time"
- ACH credit → key **present, null** → yields "wait", forever, with nothing else to set the column

That asymmetry is the whole of [[intl-settlement-short-adjust-ct-never-completes]].

**Two BANK-2149 reviewers asserted opposite things about this schema and neither had checked.** One
claimed the wire path was changing behaviour; the other claimed it could not. The docs settled it in
one fetch. Per [[verify-domain-premise-before-crediting]] — a vendor's payload shape is a domain
fact, not something to infer from a passthrough service method or from a spec fixture. Repo fixtures
here are synthetic: a spec asserting a wire response with `scheduled_settlement: nil` is testing a
payload TP cannot produce.
