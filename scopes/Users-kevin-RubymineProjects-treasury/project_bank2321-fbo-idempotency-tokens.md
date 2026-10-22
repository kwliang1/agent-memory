---
name: project_bank2321-fbo-idempotency-tokens
description: Live FBO create idempotency-token formats Venture sends to Treasury; permanent once stored, never rename
metadata:
  type: project
---

Since 2026-10-20 every GP-side FBO create from venture carries `customer_accounts.idempotency_token`:
`venture:geo_config:<id>:accredited`, `venture:geo_config:<id>:qp`, `venture:campaign_segment:<uuid>:accredited|qp`.
Treasury looks up by token only (no entity fallback), rejects a token whose row has another entity/purpose (400), and echoes it in REST `as_proto`; Venture's `create_fbo_account!` raises on a missing echo.

**Why:** one fund entity (one EIN, several classes) needs a set per class campaign.

**How to apply:** never rename a format: stored rows would stop matching and retries would open new sets. Segment tokens only label (each attempt mints a new uuid + entity). Kevin declined: data-fixing the few prod orphans from before tokens, the readers that pick an arbitrary set (loans, MMF), and `ensure_sub_account_request!` ("not our problem").
