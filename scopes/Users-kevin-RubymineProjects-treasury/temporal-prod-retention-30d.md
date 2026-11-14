---
name: temporal-prod-retention-30d
description: Prod Temporal namespace retention is 30 days; reading it needs the write console (read console has no Temporal cert)
metadata:
  type: reference
---

Prod namespace `angellist-treasury-prod-us-west-2.l3ylo` has `workflow_execution_retention_ttl` = 2,592,000s (30 days), checked 2026-10-28 via `DescribeNamespace` through `Temporal::InternalClient.client.workflow_service`. Retention starts at workflow close, so a still-running workflow keeps its ID reserved indefinitely under `REJECT_DUPLICATE`.

The prod READ console fails with `KeyError: TEMPORAL_CLIENT_CERT`; use a dedicated write console (`-n 7`, delete after) for read-only Temporal calls. See [[treasury-prod-console-access]].

Prod workers run versioned with `default_versioning_behavior: PINNED` (`lib/temporal/internal_client.rb`), so long-sleeping workflows keep their starting build alive. Relevant to [[temporal-error-logger-reports-every-attempt]].
