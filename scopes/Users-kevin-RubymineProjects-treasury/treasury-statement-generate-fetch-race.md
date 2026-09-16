---
name: treasury-statement-generate-fetch-race
description: "TP monthly-statement download errors the FIRST pull of a fresh month — generate-then-immediately-fetch race, no polling. \"Statement with date YYYY-MM not found\" = retry, not a bug."
metadata: 
  node_type: memory
  type: project
  originSessionId: a5c4a034-3c7a-4a78-8186-7f5e79b9962b
  modified: 2026-08-03T18:45:15.865Z
---

TP monthly statement download (`TreasuryPrime::Statements::InfoService.statement`, sub_account statement resolver) fails the **first** time a fresh month is pulled with `Treasury Prime API call failed: ...: {"error":"Statement with date YYYY-MM not found..."}`.

**Not an off-by-one:** July's statement key IS `2026-08` — TP dates a monthly statement the month AFTER the period (`calculate_date`, `info_service.rb:85` comment: "report for October generated in November"). So month `07` → date `2026-08` is correct.

**Root cause (CONFIRMED via prod console 2026-08-03) = create! discards the ready url, then does a racy re-GET:**
1. GET `.../statement?date=2026-08` → 404 (PDF not generated yet).
2. On 404, `CreateService.create!` POSTs to generate. **The POST returns the finished statement object WITH a ready `url`** (verified: POST returned `{date:"2026-08", type:"monthly", url:".../statement/file_...", ...}`). But `create!`'s sig is `.void` — it **throws that response away**.
3. `InfoService` then does a **separate immediate re-GET by date** (`info_service.rb:36`), which races TP's read-after-write consistency → 404 → `ApiService.handle_response` raises. That re-GET is the failure.

The `T::Private::Methods::CallValidation.validate_call_skip_block_type` in the message is a cosmetic mislabel (`caller_locations` grabbed the Sorbet sig-wrapper frame at `api_service.rb:159`), not the cause.

**Immediate unblock:** run the generate POST once (or `InfoService.statement` succeeds on 2nd try) — then the statement is cached at TP and the user can just re-download from the Treasury UI (hits the 200 path). No need to exfiltrate PDF bytes from prod console. TP account id for CA `9e1b7b09…` = `acct_11jy1bpy27xpqd6`.

**Real fix (unshipped as of 2026-08-03):** make `create!` **return** the POST response (which already has `:url`) and have `InfoService` use that `url` directly instead of the racy re-GET. No polling/sleep needed — the POST hands us the ready url. Behavior dates to PR #5307 "generate treasury prime statement on not found" — not a regression. Origin: Amy Saks pulling July ledger for John Gleeson, #banking thread 2026-08-03.

Note: TP's `/account/{id}/statement` LIST endpoint requires a `date` param — can't enumerate all statements (returns "Missing required parameter: date").
