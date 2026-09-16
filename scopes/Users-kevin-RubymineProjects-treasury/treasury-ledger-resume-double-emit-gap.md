---
name: treasury-ledger-resume-double-emit-gap
description: "Resuming treasury's merged ledger from an entry is lossy: double-emitted rows share one keyset cursor, so the sibling leg is dropped."
metadata: 
  node_type: memory
  type: project
  originSessionId: 7e9b973a-8f9d-429a-9c75-2911fbd5fa1d
  modified: 2026-09-03T06:02:01.319Z
---

`LedgerEntries::PaginationService` emits one `LedgerEntry` row **twice** when it touches two
requested accounts (once attributed to the destination, once to the origin) — see the class
comment in `app/services/ledger_entries/pagination_service.rb`. Both response entries carry the
same ledger row, so both map to the identical `(created_at, id)` keyset cursor.

Consequence: any "resume after this entry" API is lossy at the pair boundary. Stop after
consuming the first leg, resume from it, and treasury's `(created_at, id) < (?, ?)` filter
(`LedgerEntries::FetchService`) skips the unconsumed sibling. Silently.

This hits **both** candidate API shapes:
- a per-entry `cursor` in the response, and
- PR #8755's `after_entry_id` input (resolves uuid → row → strictly-after). Its specs only use
  single-sided `external_incoming_funds` entries, so the case is uncovered.

Live for nova, not theoretical: `graph/src/services/entityFinancialAccount/ledger/index.ts` sends
**all VBAs on the EFA** as `ids`, so a VBA→VBA internal transfer double-emits.

Fixes to consider: carry the pair's `account_id` with the anchor and resume `<=` the anchor with
the consumed side filtered out, or stop double-emitting and give the entry an explicit two-sided
shape.

Related: the treasury cursor is `base64(JSON({key,type,value,id}))` holding the **internal integer
PK** and is order-column-specific (decode raises on a mismatched order column), which is why
handing one to every entry freezes both the encoding and the sort order into the wire format.
Per the gem CHANGELOG convention, additive *output* fields have no deploy-ordering constraint
while additive *input* fields are one-way (treasury deploys first).
