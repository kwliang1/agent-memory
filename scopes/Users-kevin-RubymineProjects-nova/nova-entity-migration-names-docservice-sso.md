---
name: nova-entity-migration-names-docservice-sso
description: "Entity migration 'Entity name' column blank = expired AWS SSO for DocumentService, NOT missing/bad data; the legal name is never stored in nova's DB (CSV PII), only parsed from the DocumentService-archived CSV."
metadata:
  node_type: memory
  type: reference
  originSessionId: 18177271-aaa5-4d7c-b954-10e8e6db65a0
  modified: 2026-09-08T06:56:34.630Z
---

In the admin **Entity migration** tab, the **Entity name** column (and name search) is blank whenever graph can't fetch the archived CSV — and the usual local cause is an **expired AWS SSO session**, not the row data.

**Why the name isn't in the DB.** `entity_matchmaking_row` has NO name column (21 cols: id, upload_id, row_number, status, matched/ported ids, error, scored/completed/forced/rejected/selected fields, pre_select_status, pre_select_matched_ipseity_entity_id). The legal name is deliberately never persisted — CSV PII kept out of nova/Datadog (see `reserveIngestFile` comment: "The CSV must never traverse nova"). The UI name is parsed client-side from the archived CSV, fetched via the `adminEntityMatchmakingIngestFile` query → graph `getIngestFileBytes` → DocumentService. So deleting/cleaning rows never affects names, and a blank name column is a FETCH failure, not bad data.

**The fetch auths via AWS SSO.** `graph/src/lib/documentService.ts`: when `DEPLOY_ENVIRONMENT` is not prod/staging (worktrees are `development`), it uses `DocumentServiceClientConfig.localConfig()` → gamma DocumentService via AWS `fromNodeProviderChain()`. The package README: "To use localConfig(), you need to be logged into AWS via SSO." Worktree `.devcontainer/.env` sets `AWS_PROFILE=angellist-venture-prod-engineer`.

**Diagnose + fix.** `aws sts get-caller-identity` → "The SSO session associated with this profile has expired…". Fix (Kevin must run it — interactive, his creds): `aws sso login --profile angellist-venture-prod-engineer`, then reopen the tab. If still blank, restart graph (`just dev restart graph`) so the doc-service client re-resolves creds. Same auth surfaced earlier this session as a "reauth for doc service" prompt. Related: [[nova-worktree-portal-auth-2fa]] (a DIFFERENT auth — portal login, not AWS SSO).
