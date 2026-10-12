---
name: project_todo_dedup_port_recipient_org_artifact
description: "TODO (2026-10-02) — write an artifact on the dedup-port reachability gap (MAPA Trust / Thunderclap, batch 7de9f208), with org links and fix sites"
metadata:
  node_type: memory
  type: project
  originSessionId: e618e032-4eb6-45a1-a941-ba932778ccd2
  modified: 2026-10-02T20:20:30.504Z
---

TODO: memorialize in an artifact (Kevin asked 2026-10-02). Not yet written.

Finding: a matchmaking dedup port (entity already held, ipseity id match) is a wallet-ensure that grants nobody. The ported wallet is unreachable by the LP when the held entity has no RECIPIENT org, or when the LP's account lacks canEdit and banking in the holding org.

Cases (batch `7de9f208-ee40-49d6-a354-7aac22a97658`, ported 2026-10-02 ~14:03Z; Jack's RUM session `c129bd77-12d3-4bd5-a06a-56a283b4a280`):
- Row 67 Thunderclap, LLC (entity `92c2798d`, wallet `th-dWbwXr01b-bank-account`). Only org: `dillon-newman` (757cdbef, MERIDIAN). Dillon and cmca@smacpafirm.com are admins with full banking. david.tc.newman is a member with banking all false. No RECIPIENT org exists for any of them, so the distribution link and the portal invite would both create a duplicate entity.
- Row 45 Mapa Trust (entity `eaa31a10`, wallet `maZTnFTK8gIN-bank-account`). Org `ll1qyxuGl0O2` (8f85d877, RECIPIENT). Sole member lluispedragosa@yahoo.com (venture 1080826), superAdmin with view/edit/sign but NO bankingPermission row. The entity's email is lpedragosa@gmail.com: an id-less 2021 account in a different org, `lly0p2WeBeFD`.
- Distribution sender: iter-investments (740de281). No directory entities for either LP as of 2026-10-02.

Fix sites:
- `graph/src/services/entityMatchmaking/executePort.ts` (dedup path; comment above `createOrDedup`). Proposed rule: if no RECIPIENT org holds the entity, create one seeded with the holding org's members who already have banking, at the same permissions. Otherwise route the row to NEEDS_REVIEW.
- `RecipientPayoutFlow/index.tsx:358` and `lib/portal/getOrCreateOrgEntityAndOrgMember.ts:285` both filter to RECIPIENT orgs only.
- `data/directory/entity/hasPermissions.ts:34-37` matches the distribution email exactly, with no venture-secondary-email fallback.
- `data/entity/financialAccount.ts` hasPermissions has no superAdmin bypass; it needs a bankingPermission row.

Related: [[matchmaking-owner-gate-design]], [[nova-directory-email-banking-door]].
