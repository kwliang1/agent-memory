---
name: nova-matchmaking-blank-names-finalization-lag
description: "Blank 'Entity name' column right after staging a matchmaking batch = DocumentService finalization lag, and the UI read has NO retry. Self-resolves in seconds; the callout wording is misleading."
metadata:
  node_type: reference
  type: reference
---

In the nova admin **Entity migration** tab, every row's `Entity name` rendering `—` **immediately after an upload** is DocumentService finalization lag, not bad data and not auth.

**Mechanism.** DS finalization is async: PUT → S3 event → finalize workflow. Until it lands a read returns `isProcessing`. The **ingest path retries** — `graph/src/services/entityMatchmaking/ingestDocument.ts:38` treats `isProcessing` as a retryable `documentRead` error and Temporal keeps retrying, which is why rows, Match statuses and matched entities all populate fine. The **UI read does not retry** — `getIngestFileBytes.ts:56` returns it as a plain error, so `useCsvRows` gets `errored: true`, `rows: []`, and `csvName: csvRow?.legalName ?? '—'` blanks every row. Wait and reload and it fills in.

**Diagnostic tell:** if scoring worked (row numbers + Match statuses + a matched entity are present) then the server read the file fine, so a blank name column can only be the *client-side* re-fetch. The names are never stored — `entity_matchmaking_row` has no name column; the browser re-parses the archived CSV purely for display, and the port takes name/type from ipseity anyway. **So blank names never block a port** — they only cost the display column and name search.

**The callout is misleading:** it says *"The archived source file could not be read — CSV columns and name search are unavailable, not empty. Reload to retry."* (`RowsTable/index.tsx:181`) for a transient state that fixes itself. Candidate fixes offered to Kevin 2026-09-11: have `useCsvRows` distinguish `isProcessing` from a real failure and poll briefly (same shape as the existing uploads/rows settle polling), or at minimum reword the callout to mention finalization.

**Do not confuse with** [[nova-entity-migration-names-docservice-sso]] — that one is expired AWS SSO on a *local worktree* (`DEPLOY_ENVIRONMENT=development` → `localConfig()` → `fromNodeProviderChain()`), which does not apply in prod. Ruled out for prod: both paths use the same `documentServiceClient` and reads are not owner-scoped (`ingestDocument.ts:14` — requestingUser is audit attribution only), so it is not a per-document permission difference, and a "Temporal worker vs graph API process has different DS access" theory I floated was **wrong**.

**This is the whole explanation — Kevin confirmed it covers both occurrences on 2026-09-11.** I had speculated the earlier batch was "days old" so finalization would have completed; I never actually established when it was staged, and that assumption was unfounded. One cause, not two. Corollary for next time: don't reason from an assumed staging age — `entity_matchmaking_upload.created_at` is right there.

See [[lp-porting-fund5-fund6-csv-defects]], [[nova-lp-porting-review-tab]].
