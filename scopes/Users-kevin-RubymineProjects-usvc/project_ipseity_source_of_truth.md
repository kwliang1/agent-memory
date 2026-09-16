---
name: Ipseity is the system of record for KYC state
description: Don't propose local KYC outcome tables; the upstream EntityAPI is canonical and queryable by ipseity_entity_id
type: project
originSessionId: 0a21371f-dca7-4d6c-9206-321285843803
---
KYC state for USVC investors lives in Ipseity (EntityAPI). The USVC Rails app
does not — and will not — replicate KYC outcomes into a local table.

**Why:** Ipseity is the canonical store for identity/KYC across AngelList
products. Building a local replica creates a divergence risk and adds nothing
an auditor can't already get by querying Ipseity with the
`ipseity_entity_id` that's already on the Commitment.

**How to apply:** When designing audit/compliance flows for KYC, treat
Ipseity as authoritative. App-side log events (`kyc_review.*` etc.) are
operational breadcrumbs that record *what this app decided to do* — they are
not a KYC ledger. Don't propose `kyc_review_outcomes` / `kyc_history` /
`alloy_outcomes` tables; if an auditor question comes up that the existing
log breadcrumbs don't answer, the answer almost certainly comes from
Ipseity by `ipseity_entity_id`.

Treasury (sibling app) consumes IpseityEvents/NATS for live updates; USVC
chose a polling-chain pattern for the same upstream data (USVC-580). Both
patterns confirm the same architectural posture: Ipseity is upstream truth,
the local apps are consumers.
