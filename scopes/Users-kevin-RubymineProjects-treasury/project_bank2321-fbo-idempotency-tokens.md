---
name: project_bank2321-fbo-idempotency-tokens
description: Live FBO create idempotency-token formats Venture sends to Treasury (BANK-2321) — permanent once stored, never rename
metadata:
  type: project
---

Since 2026-10-20 (treasury#9194, venture#37763) every GP-side FBO create carries `customer_accounts.idempotency_token`:
`venture:geo_config:<id>:accredited`, `venture:geo_config:<id>:qp`, `venture:campaign_segment:<uuid>:accredited|qp`.
Treasury looks up by token only (no entity fallback), rejects a token whose row has another entity/purpose (400), and echoes it in REST `as_proto`; Venture's `create_fbo_account!` raises on a missing echo.

**Why:** one fund entity (Unshackled, one EIN, 9 classes) needs a set per class campaign.
**How to apply:** never rename a format — stored rows would stop matching and retries would open new sets. Segment tokens only label (each attempt mints a new uuid + entity). Kevin declined: data-fixing the 1 accredited / 4 QP prod orphans (draft fc 62870; finalized 338/351/368/377), the arbitrary-set readers (loans/MMF; Unshackled takes neither), and `ensure_sub_account_request!` ("not our problem"). Follow-ups: [[BANK-2322]], BANK-2345.
