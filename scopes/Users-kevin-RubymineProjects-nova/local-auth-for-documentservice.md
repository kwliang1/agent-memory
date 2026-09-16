---
name: local-auth-for-documentservice
description: "Local DocumentService auth is `al auth login -p` (AngelList CLI), not a local container and not raw `aws sso login`."
metadata: 
  node_type: memory
  type: reference
  originSessionId: 735720e2-1046-4f41-a5f3-9c7683877ee2
  modified: 2026-09-10T17:23:29.095Z
---

To re-auth DocumentService locally: **`al auth login -p`** (AngelList CLI, opens a browser, prints `Authenticated as <you> (production)`). Kevin ran this 2026-09-10; it is the house command.

**Why it's needed, and why there's no container to start.** `graph/src/lib/documentService.ts` picks config from `DEPLOY_ENVIRONMENT`; local dev is neither `production` nor `staging`, so it falls to `DocumentServiceClientConfig.localConfig()`. That name is misleading — it returns the **gamma** DocumentService on AWS API Gateway (`*.execute-api.us-west-2.amazonaws.com`) with `fromNodeProviderChain()` credentials. So there is never a local document-service container; DS calls fail when the AWS/SSO session behind `AWS_PROFILE` expires.

`.devcontainer/.env` sets `AWS_PROFILE=angellist-venture-prod-engineer`, an SSO profile against `angellistventure.awsapps.com`. `aws sso login --profile <that>` is the underlying mechanism, but prefer the `al` wrapper.

**Order matters: log in, THEN restart graph.** `documentServiceClient` (`graph/src/lib/documentService.ts`) is a module-level singleton built at import with `fromNodeProviderChain()`, so a running graph keeps the credentials it resolved at boot. Observed 2026-09-10: `al auth login -p` at 17:19, yet graph still failed `AdminEntityMigrationReserveIngestFile` with "The SSO session associated with this profile has expired" at 17:31. Restart graph after authenticating: `curl -X POST http://localhost:$PROCESS_COMPOSE_PORT/process/restart/graph`.

Consequence worth remembering: because the DS upload goes to an API Gateway presigned URL rather than the staging S3 buckets, the worktree-host CORS trap in AGENTS.md (uploads only work from `portal.angellist.dev`) does **not** obviously apply to the matchmaking CSV ingest path.

See [[nova-local-e2e-matchmaking]] and [[document-service-at-rest-model]].
