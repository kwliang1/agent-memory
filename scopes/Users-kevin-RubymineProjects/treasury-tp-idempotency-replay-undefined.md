---
name: treasury-tp-idempotency-replay-undefined
description: Treasury Prime's idempotency key does not document what a replay RETURNS, and keys expire at 7 days — so "just re-POST it" is never a safe recovery plan.
metadata:
  type: reference
---

Treasury Prime's [idempotency reference](https://docs.treasuryprime.com/reference/idempotency.md) promises
only that a keyed request is "processed once". It never states what a **replay** returns — the original
resource, a cached response, or an error. Peer APIs split hard on this (fiskaly and Kobana replay the
original response with an `X-Idempotency-Replayed` header; Ripple 409s an in-flight duplicate and 422s a
body mismatch), so the favorable behaviour cannot be assumed.

**Keys are retained 7 days only.** Past that the same key is reusable, so a replay creates a second real
payment.

Why this matters: treasury passes the record's own `idempotency_token` to the bank on every payment POST
(`treasury_prime/api_service.rb:46` sets `X-Idempotency-Key`; `api_service.rb:42` raises if a payment
endpoint is called without one — so the key is structurally guaranteed, which makes "re-POST is safe" look
true from the code alone). It isn't. Any recovery design that needs to learn a payment id after a crash
must **ask the bank** (list/fetch), not re-POST. Confirming TP's actual replay behaviour needs a sandbox
probe, not a doc read.

Same shape on DIBS (`dibs/client.rb:84` passes `idempotency_key:`), with its own undocumented semantics.

Came up designing the wire submit claim state — see [[feedback_review_gate_count]] for the gate that ran
alongside it, and [[verify-domain-premise-before-crediting]]: a grep showed the token was passed and looked
like proof; only the vendor doc showed it wasn't.
