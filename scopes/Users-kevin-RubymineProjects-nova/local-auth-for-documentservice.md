---
name: local-auth-for-documentservice
description: "Local DocumentService auth is `aws sso login --profile angellist-venture-prod-engineer`. NOT `al auth login` — that is a different auth system entirely."
metadata: 
  node_type: memory
  type: reference
  originSessionId: af366db7-dedb-49ab-a556-1a80afef428d
  modified: 2026-09-21T17:02:46.321Z
---

**Corrected 2026-09-21.** This note previously said the house command was `al auth login -p`,
with `aws sso login` as its "underlying mechanism". That is wrong and cost a round-trip.

`al auth login -p` is **OAuth2/PKCE against Dex** for internal-service CLI calls (`al auth
login --help`: "-p, --production  Shortcut for --env prod"). It writes AngelList CLI tokens
and never touches `~/.aws/sso/cache`. After running it, the newest AWS SSO token can still be
days old and `aws sts get-caller-identity --profile …` still fails.

**The command that actually works:**

```
aws sso login --profile angellist-venture-prod-engineer
```

Run it in a real terminal — via the `!` prefix it is backgrounded at 120s, which is exactly
the login's own timeout, so it fails with "timed out waiting for authentication (120s)".

**Why.** `graph/src/lib/documentService.ts` picks config from `DEPLOY_ENVIRONMENT`; local dev
is neither `production` nor `staging`, so it falls to `DocumentServiceClientConfig.localConfig()`
— a misleading name that returns the **gamma** DocumentService on AWS API Gateway with
`fromNodeProviderChain()` credentials. There is no local document-service container; DS calls
fail when the SSO session behind `AWS_PROFILE` (set in `.devcontainer/.env` to
`angellist-venture-prod-engineer`) expires.

**Order matters: log in, THEN restart graph.** `documentServiceClient` is a module-level
singleton built at import, so a running graph keeps the credentials it resolved at boot:
`curl -X POST http://localhost:$PROCESS_COMPOSE_PORT/process/restart/graph`.

**Symptom** — staging a matchmaking CSV fails at `AdminEntityMigrationReserveIngestFile`, UI
shows "Could not reserve", graph logs "The SSO session associated with this profile has
expired". **Verify with `aws sts get-caller-identity --profile "$AWS_PROFILE"`**, not by
trusting a login command's success message — `al` reports "Authenticated as … (production)"
while the AWS profile stays expired.

Because the DS upload goes to an API Gateway presigned URL rather than the staging S3 buckets,
the worktree-host CORS trap in AGENTS.md does **not** apply to the matchmaking CSV ingest path.

See [[nova-local-e2e-matchmaking]] and [[document-service-at-rest-model]].
