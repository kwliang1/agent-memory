---
name: nova-configtool-staging-zeus-is-prod-cluster
description: "nova's prod-us-west-2-staging-zeus is a staging-LABELLED namespace inside the PRODUCTION cluster — its bare svc.cluster.local upstreams resolve to prod ipseity/treasury."
metadata:
  node_type: memory
  type: reference
---

Before enabling ANY feature flag or upstream-touching config in `nova/graph/config/configtool/`, check which cluster the stack runs in. There are three stacks and only ONE is a real staging environment:

| stack | reality |
|---|---|
| `prod-us-west-2-zeus` | production (`portal.angellist.com`) |
| `staging-us-west-2-hermes` | genuine staging cluster — own RDS, own Temporal, own venture (`angellist-staging.com`) |
| `prod-us-west-2-staging-zeus` | **staging-labelled namespace INSIDE the production cluster** |

**The trap:** all three carry byte-identical `IPSEITY_BASE_URL: "http://web.ipseity.svc.cluster.local"` and `TREASURY_API_BASE_URI: "http://web.treasury.svc.cluster.local"`. That's cluster-local DNS with no environment qualifier — the string tells you NOTHING; it resolves in whichever cluster the pod runs in. `prod-us-west-2-staging-zeus` shares `clusterDomain: ...prod-us-west-2-zeus...` and a byte-identical `roleArn` with prod, so its ipseity/treasury calls land on the PRODUCTION deployments.

**How to prove it in 30 seconds (no cluster access needed):** compare how a stack addresses its OWN sibling vs shared services. `prod-us-west-2-staging-zeus` knows to qualify its sibling as `capital-api.nova-staging.svc` but reaches `web.ipseity.svc` BARE — and its `VENTURE_BASE_URL` is production `venture.angellist.com` where real staging uses `venture.angellist-staging.com`. That venture URL alone settles it. No `ipseity-staging`/`treasury-staging` namespace is referenced anywhere in the repo.

**Do NOT assume a blanked NATS config makes a staging stack fail closed.** `prod-us-west-2-staging-zeus` sets `NATS_JWT: ""` ("staging doesn't use NATS RPC"), but the ipseity and treasury SDK clients are plain HTTP over the config base URLs (`graph/src/lib/sdk/{ipseity,treasury}.ts:11`) — the reach is live, and `IPSEITY_API_KEY` there is a real encrypted value that authenticates.

Caught 2026-09-01 on PR #9833: enabling matchmaking scoring there would have sent live LP tax IDs (`resolveCandidates` → `entities.lookup_by_tax_id`) from `portal-staging.angellist.com` to production ipseity. Stack was dropped from the PR. Also note `config-readonly.yaml` (the script-runner secret) is a SEPARATE file that does not inherit new keys. See [[nova-matchmaking-local-e2e]].
