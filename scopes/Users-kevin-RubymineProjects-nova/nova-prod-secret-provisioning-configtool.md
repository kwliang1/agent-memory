---
name: nova-prod-secret-provisioning-configtool
description: "How nova injects env/secrets in staging/prod: inline `encrypted|...` values in cdk8s configtool config.yaml → the graph-config k8s Secret read by both graph API and worker pods."
metadata: 
  node_type: memory
  type: reference
  originSessionId: 04a376b3-023d-4ac7-ac38-29fcb39af09a
  modified: 2026-08-24T22:29:43.701Z
---

Nova does **not** use AWS Secrets Manager entries or per-var KMS keys for app config. Env vars — secret and plaintext alike — live in `graph/config/configtool/<stack>/config.yaml` (stacks: `staging-us-west-2-hermes`, `prod-us-west-2-zeus`, `prod-us-west-2-staging-zeus`; app/capital-api/pdfops/hasura each have their own `config/configtool/`).

- Secrets are stored **inline** as `encrypted|<ciphertext>|<key-fingerprint>|<...>` (AngelList **configtool**, `@angellist/infra/configtool`, envelope-encrypted with a KMS-backed key). Plaintext values sit inline unencrypted. e.g. `ENCRYPTION_SECRET`, `TREASURY_API_SECRET`, `DB_PASSWORD`, `IPSEITY_API_KEY` are all `encrypted|...` there.
- `configtool.load(configPath)` (`graph/cdk8s/main.ts:61`) decrypts at synth into a single k8s Secret `graph-config` (`new Secret(this,'config',{ stringData: configData })`, `main.ts:88`).
- **Both** the graph API and the Temporal worker pods consume `graph-config` (`envFrom secretRef: graph-config`, and `secretKeyRef` for individual keys in `graph/cdk8s/tonic.ts`). One secret feeds both.
- To add a new env var: add it to **each stack's** `config.yaml` — `encrypted|...` for secrets (needs configtool encryption rights → infra/platform), plaintext otherwise — then ArgoCD syncs. `graph/src/lib/config.ts` reads it via `process.env` with a safe default.

Concrete use (BANK-1884, [[spawned-nova-worktree-is-bare]]): the Temporal payload-encryption vars (`TEMPORAL_PAYLOAD_ENCRYPTION_KEYS` encrypted, `..._ACTIVE_KEY_ID` / `..._ENABLED` plaintext) are provisioned this way — the only infra-gated step is the encrypted entry.
