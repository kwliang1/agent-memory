---
name: nova-9500-bulkupload-review
description: "nova PR #9500 (NOVA-3681, ctotheameron) bulk-upload email-copy refactor — 2-round adversarial review findings, ranked, with the F1 downgrade + 3-fix convergence."
metadata: 
  node_type: memory
  type: project
  originSessionId: a7686c8f-f7e6-4916-93f0-f72f9dcc6649
  modified: 2026-08-17T18:29:42.658Z
---

Reviewed nova **PR #9500** `fix(directory): respect bulk upload "name" on email copy` (branch `ctotheameron/oc/NOVA-3681/better-bulk-upload`, base main, author ctotheameron — NOT Kevin's). 2 adversarial rounds, all findings traced against branch code. Review lived in Discord thread, not the PR. Kevin fed concrete Qs (DD traces, const-vs-function, error-tag collapse) then "relaunch the critic" for R2.

**Confirmed issues (ranked, for the author):**
1. **Blank-email bug (medium).** Cleared subject/body field → `''` (EditContents writes raw input). Send resolver `graph/src/internal/schema/directory/entity/bulkEntityUpload/email.ts:41` stores `customSubject.trim()` with **no `|| null`**; activity `graph/src/lib/temporal/activities/emailSending/sendBulkEntityUploadEmails.ts` does `customEmailSubject ?? defaults.subject` — `??` doesn't catch `''` → ships literally blank subject/empty body via `sendBasicEmail`. Fix server-side in email.ts, not just frontend onChange.
2. **Temporal race (fragile).** email.ts:46 starts `SEND_BULK_ENTITY_UPLOAD_EMAILS` **inside** the Prisma `$transaction`, before commit, on load-bearing `startDelay:'3 seconds'`; activity **re-reads** subject/body (only `args:[id]` passed). Read-after-write race + rollback-orphan.
3. **`originalError` dropped (R1).** upsert resolver `upsert.ts:39` throws `new GraphQLError('Failed to update bulk entity upload.')` with NO `originalError` → breaks `maskedErrors.ts:42` unwrap + DD/Sentry root cause. Sibling `distribution/upsert.ts:80` does it right (`{ originalError }`). Service preserves the cause chain via `to()` `errors.ts:265`; resolver throws it away.
4. **Error-tag collapse (R1).** service `services/directory/entity/bulkUpload/update.ts` maps ALL data errors to `service:bulkEntityUpload:unknown` (builder has no `.add(...)`, so `.narrow('unknown')` is the only option). Data layer already emits rich tags (`data/prisma/error.ts` notFound/P2025, uniqueConstraintViolation, …). P2025 (bad id) indistinguishable from DB-down. Add `notFound` tag + branch.
5. **Zero tests** for update.ts / data bulkUpload.ts / email.ts / activity, and none fencing the `''` seam or error-tag path. `upsert.test.ts` exists but doesn't cover them.
6. **Unenforced `function` flip.** No `func-style`/`react/function-component-definition` rule in biome config; const→function applied to only 1 of 4 hooks in `BulkEntityUploadModal/hooks/index.ts`. Drop or commit repo-wide via codemod.

**The 3-fix convergence:** emit subject/body as **workflow args** + start workflow **after** commit → fixes #1 (empty re-read window), #2 (race + orphan), and retires the org-name fallback landmine in one change.

**Downgraded (critic overreach, corrected):** R2 critic claimed the PR's core feature is "defeated" — delivered email uses `organization.name` while preview uses `upload.name`. FALSE on the real path: email.ts:46 is the **sole** enqueuer and always overwrites `customEmailSubject` before the activity runs, so the activity's `?? defaultEmailProps(organization.name)` fallback is **dead** — delivery matches preview (both upload-name). Real residue = latent/dead inconsistent fallback, not an active bug.

**Clean:** auth/IDOR (`bulkEntityUpload/auth.ts:66` derives org from `upload.organizationId`, checks member gated by hasPortal&&canBulkCreateEntities, non-member→forbidden/notFound); Cursor's "defaults not cleared on update.ts" doesn't land (`ignoreDefaults` returns undefined→coerced null→Prisma clears).
