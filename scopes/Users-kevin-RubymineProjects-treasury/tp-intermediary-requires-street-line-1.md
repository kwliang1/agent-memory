---
name: tp-intermediary-requires-street-line-1
description: TP /wire rejects an intermediary block without street_line_1 ("Missing required parameter: street_line_1") even though counterparty bank_address may omit it; OW 137893 / SMBCJPJT 2026-10-14
metadata:
  type: project
---

Treasury Prime's `POST /wire` requires `intermediary.address.street_line_1`. It rejects with
`{"error":"Missing required parameter: street_line_1"}` when the block carries only
city/state/postal/country. The counterparty `bank_address` on `POST /counterparty` has omitted
street_line_1 since 2022 (#3180) with no rejections, so #7667's "TP accepts placeholders" was true
for counterparties only; the intermediary omission was never exercised in prod until OW 137893
(intermediary SMBCJPJT, Sumitomo Mitsui, 2026-10-13) — the placeholder_used metric for
consumer:intermediary/field:street_line_1 was zero for 90d before that.

**Why:** the banner text ("Missing required parameter: street_line_1") reads like a beneficiary
address problem; the beneficiary street was populated. The missing field is on the intermediary's
DIBS `SwiftRoutingRecord.street1`.

**How to apply:** fix the data with an Update SWIFT Routing Record DCR adding street1 for the
intermediary BIC, then retry the wire. Branch `kevinliang/tp-intermediary-street-required`
(2026-10-14) makes `build_intermediary_party_body` raise `MissingIntermediaryStreet` with that
instruction instead of omitting the field. Confirm the failing block from the Datadog log
`service:treasury-temporal "Treasury Prime API call failed"` → `custom.payload.data`, not from the
banner. Related: [[reference_tp-wire-object-has-no-scheduled-settlement]].
