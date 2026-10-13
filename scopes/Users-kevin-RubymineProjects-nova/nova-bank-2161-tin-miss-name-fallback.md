---
name: nova-bank-2161-tin-miss-name-fallback
description: "BANK-2161 / PR #10676 — a TIN that ipseity no_matches now falls back to the name+type lookup; NO_MATCH only if that misses too"
metadata:
  node_type: memory
  type: project
  originSessionId: 1abd7eac-65e0-4b24-a893-ec4a7b79d9fe
  modified: 2026-10-01T23:00:56.591Z
---

As of 2026-10-01, PR #10676 (branch kevinliang/bank-2161) is pushed and open, not merged. It changes matchmaking scoring:
- When ipseity's blind-index TIN lookup returns `no_match` for a row that has a legal name, `resolveCandidates` runs that row through the name+type lookup and sets `nameFallback: true`.
- `classify` sends those rows through the name resolver. A hit can only reach NEEDS_REVIEW, never AUTO_MATCH. A miss is NO_MATCH. Fallback candidates are saved with `tinMatched=false`, which caps a reviewer's pick at NEEDS_REVIEW.
- A TIN miss on a row with no name is NO_MATCH. It used to be CONFLICT.

Kevin first decided on "TIN miss → NO_MATCH". A reviewer then showed that TIN rows never got a name search, so a mistyped TIN did worse than a blank one. Kevin's response: "this should have been how it worked in the first place".

There is no backfill. Old zero-candidate CONFLICT rows (e.g. batch dbfe0927) still need a manual reject.

**Why:** a row with no available action held its batch out of COMPLETED.

**How to apply:** when touching scoring tests, remember `resolveCandidates` always makes a second `lookupEntitiesByName` call, with `[]` when there is no fallback. A sticky `mockReturnValue` will answer that call and quietly turn a no-TIN row into a fallback row, so use `mockReturnValueOnce`. Related: [[nova-entity-matchmaking-scorer]].
