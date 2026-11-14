---
name: prod-readonly-console-has-no-temporal
description: treasury's read-only prod console (`al console -a treasury -p`) has SKIP_TEMPORAL and no Temporal cert; signalling or starting workflows needs the write console (-w)
metadata:
  type: reference
---

Operator hints that touch Temporal must name the write console, `al console -a treasury -p -w`. The read-only console config sets `SKIP_TEMPORAL: "true"` and blank `TEMPORAL_HOST`/`TEMPORAL_NAMESPACE` (config/configtool/prod-us-west-2-zeus/config-readonly.yaml:22,148-149), and only the write console gets the Temporal Cloud mTLS cert (cdk8s/main.ts:165-167). In the read-only console, `Temporal::InternalClient.client` raises `KeyError: TEMPORAL_CLIENT_CERT`.

The working one-liner is `Temporal::InternalClient.client.workflow_handle('<id>').signal(:name, args)`, which carries the namespace and mTLS. A handle with no run_id follows the latest run across ContinueAsNew. Write access needs GlobalConsoleWriters ([[al-console-access]]).
