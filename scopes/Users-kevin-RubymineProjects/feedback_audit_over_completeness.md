---
name: Audit traceability beats field-level Frankenstein merges
description: When designing logic that combines data from multiple input sources into a single persisted record, prefer wholesale (single-source-wins) writes over field-level merge — even if it means rare information loss
type: feedback
originSessionId: 5373b9a5-1979-4b34-ad89-cd2d64bd29d2
---
When designing logic that combines data from multiple input sources into one persisted record (e.g., dedup'd Ipseity entities written from multiple Nova role payloads), prefer **wholesale single-source-wins** writes over field-level merge.

**Why:** Field-level merge (e.g., `||=` per field across multiple payloads) produces records where you can't trace which input contributed which field. The user explicitly pushed back: "why field level instead of wholesale? seems difficult to audit afterwards." Auditability matters more than maximizing field completeness in a deduplicated record.

**How to apply:**
- When proposing how to handle "what if multiple inputs write to the same persisted record": default to "first writer wins, later writers skip the write entirely."
- Combine with deterministic ordering so the audit story is "this record's data came from input X" — not "some union of inputs."
- If information loss is a concern, surface it via Sentry warning ("a later input would have populated a currently-blank field") rather than silently merging.
- Reserve field-level merge for cases where audit traceability is genuinely not a concern (rare).
