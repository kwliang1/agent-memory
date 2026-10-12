---
name: nova-who-did-it-datadog-trail
description: "How to attribute a nova prod action (connect, confirm, link open) to a real person — GraphQL op logs carry trueUser+variables; RUM carries usr.true_id/is_impersonating"
metadata:
  node_type: memory
  type: reference
  originSessionId: 102d19ec-53e3-4d9d-842b-3d6d326eb8f2
  modified: 2026-10-01T18:30:30.282Z
---

Attributing "who did X" in nova prod (verified 2026-10-01 on the Maple distribution):

- **Server side:** nova-graph logs `GraphQL Op: <Name>` with `custom.user`, `custom.trueUser` (differs when an admin impersonates) and `custom.variables` (e.g. `distributionPaymentId`, `entityId`, `directoryEntityId`). Search with `storage_tier: flex_and_indexes`. Coverage looked incomplete (one confirm was missing), so absence is weak evidence.
- **Browser side:** RUM views carry `usr.id`, `usr.true_id`, `usr.is_impersonating`. The payout link is `/start/payment/distribution/<distributionPayment.id>`; `recipientStartedAt` is set on the first VIEW (`distributionPayment.ts:913`), by whoever opens it — an impersonating admin included. So "started" ≠ the LP engaged.
- **Console scripts:** `al console exec` stdout lands in Datadog under service nova-graph (console pod host), so console probes are timestamped there — but writes only show if the script printed them.
- `DirectoryEntity.updatedAt` has no `@updatedAt`, so a connect leaves no timestamp on the row.
- Kevin's AngelList id is 64594 (`kwliang`).

Related: [[reference_nova_graph_prod_console_query]], [[nova-entity-matchmaking-scorer]].
