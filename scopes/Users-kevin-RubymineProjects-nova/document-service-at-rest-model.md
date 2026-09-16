---
name: document-service-at-rest-model
description: "How AngelList DocumentService (separate Go service) protects docs at rest, and the nova access-scope gap for PII (BANK-1917)."
metadata: 
  node_type: memory
  type: reference
  originSessionId: a2a9b86a-6fc1-44a0-937a-3d578624cfdb
  modified: 2026-08-27T01:06:55.411Z
---

`@angellist/document-service-client` (nova `graph/src/lib/documentService.ts`) is a client to the **separate** `angellist/document-service` Go repo — nova NEVER touches its S3 buckets directly. nova only calls `postDocument` (→ presigned PUT + `document.id`) and `getDocument` (→ authz check → presigned GET). So bucket SSE / IAM / lifecycle live in document-service + AWS, not nova. Verified for BANK-1917 (2026-08-26).

- **Encryption (CONFIRMED via IaC):** app (`internal/clients/s3/client.go`) sets no SSE — it's bucket-default. Buckets are Pulumi-managed in `angellist/infra` → `pulumi/support-services-aws/index.ts` (`protect: true`), AWS acct `<acct-1 redacted>`. Both `prod-angellist-document-storage` (finalized) and `prod-angellist-draft-document-storage` (draft) have `serverSideEncryptionConfiguration → sseAlgorithm: 'AES256'` (**SSE-S3, not a CMK**), `versioning.enabled`, DenyNonHttps policy (TLS-only), and cross-account S3 access granted ONLY to `documentServiceRoleArn`. Finalized bucket also has Object Lock enabled + **no lifecycleRules** (permanent). KMS-for-TIN = one-field change (`sseAlgorithm: 'aws:kms'` + `kmsMasterKeyId`) in that Pulumi file, owned by infra/support-services.
- **Access scope (app-layer gap; raw bucket is locked):** at the S3 IAM layer the bucket policy grants access ONLY to the document-service role — no nova/venture role reads the bucket directly. The breadth is purely at the DocumentService *app* authz layer, which mints presigned URLs: reads gated by `internal/authz/helper.go` `CanAccessDocument` on `DocumentMetadata.GetOwnerService()` (`internal/clients/dynamodb/types.go`), which derives owner ONLY from a fixed uploader/caller set (`internal/utils/identity.go`): relay/stack/ipseity/treasury/usvc. **No `nova` caller/owner.** Owner `""` ⇒ **open to ALL onboarded callers** (fin, flowdash, venture, usvc, mcp + read-only sky/funds/portal). So KYC(Ipseity)/bank-stmt(Treasury) docs are owner-locked, but a nova-uploaded doc (human-email uploader) is ownerless ⇒ world-readable internally. Fix = document-service adds OwnerNova/CallerNova + `CLIENT_API_KEY_NOVA` + nova tags uploads.
- **Retention:** finalized docs = "No TTL — persist indefinitely" (`metadata.go`); only DRAFT has TTL. Route registry (`internal/service/document_service.go`) has **no `DELETE /documents/{id}`** (only `deindex` = search only). Pruning needs an owner-side delete endpoint / lifecycle rule.

Related: [[nova-prod-secret-provisioning-configtool]] (document-service uses same configtool HCL pattern in its own repo).
