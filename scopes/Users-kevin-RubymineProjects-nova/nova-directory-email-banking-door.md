---
name: nova-directory-email-banking-door
description: "A DirectoryPerson email is a SECOND, wider door to full banking permissions than the matchmaking port's owner ladder — auto-join grants all 3 banking perms on mere payment listing. It does NOT rescue an unseated owner; it produces a duplicate entity instead."
metadata:
  node_type: memory
  type: project
  originSessionId: 0d5b8057-25e5-4594-8e8e-fd60088856e4
  modified: 2026-09-14
---

Found 2026-09-14 answering Kevin's challenge: *"if an email is listed as a DirectoryPerson they should have access to accept the distribution on behalf of the owner, no? and that DP should be given full bank permissions"* — he was right, and it goes further than he said.

**Access to a distribution payment resolves on a directory email match, not on anything the port wrote.** `graph/src/data/distributions/distributionPayment.ts:1419` `hasPermissions`: an account whose email matches any DirectoryPerson linked to the recipient passes, and the `connectedEntityId` branch is explicitly optional. On an fsm-enrolled org an unrevoked `DistributionAccessGrant` is checked too (keyed to `directoryEntityId`, NOT to a nova Account or Organization); on every other org the email match alone suffices.

**Once the directory entity is connected to a nova entity, merely LISTING the payment grants full banking.** `autoJoinOrgIfEmailMatch` (`graph/src/services/distribution/payments/autoJoinOrgIfEmailMatch.ts:93-143`) creates the org membership and upserts all three — `canViewFinancialAccounts`, `canManageTransfers`, `canManageFinancialAccounts` — plus view/edit on the entity and every data-room category. It fires from `fetchAccessiblePayments/index.ts:149`, not only on accept. The code carries its own warning at `:27`: *"TODO: THIS IS BAD - SECURITY PROBLEM - NEEDS TO CHANGE"* — the sender controls LP org membership by controlling the directory email.

**The matchmaking port never touches DirectoryEntity or DirectoryPerson** — zero references in the whole service. So this is not a matchmaking defect; it predates it.

## The interaction that IS ours, and it runs opposite to intuition

I first wrote that this door *softens* the owner-access gaps (an email-only owner "isn't stranded"). **That was wrong and had to be retracted.** The door leads into the *distribution*, not to the *ported entity*. Connecting the two needs `canEdit` on that entity (`connectOrCreateForDirectoryEntity.ts:107-125`), and the UI only offers entities the LP already holds a seat on (`RecipientPayoutFlow/pages/StartPage/index.tsx:156-160`). Only the port's owner ladder grants that seat.

So for an owner the port failed to seat: they reach the distribution fine, the entity picker is **empty**, and `connectOrCreate` falls through to its last branch and **creates a new nova entity and a new organization** — leaving the ported entity and its wallet orphaned. That makes the owner-resolution gaps **worse**, not softer.

**Nothing GP-side ever sets `connectedEntityId`.** Publish creates directory entities unconnected (`services/distribution/publish/resolveDirectory.ts:99-196` writes name/type + vehicle/source links only) and resolves existing ones by id or short id — never by name, type or email. Name and type are compared purely to emit GP-facing warning strings (`draftPipeline/directoryMatch.ts:113-127`); the draft pipeline persists nothing. DirectoryPersons ARE resolved by email (`resolveDirectory.ts:29-95`, `findManyByEmails`) — that is the email match Kevin was thinking of, but it is person-level inside an already-resolved entity. So the ordering is: GP publishes → DE created unconnected with a contact list from a spreadsheet → **first LP acceptance connects it** → from then on every contact on that list picks up the org seat and all three banking permissions on their next page load.

**No cheap dedup is available at the connect step.** `DirectoryEntity` carries no TIN and no ipseity id — only name, type, and the sender's own external references. There is nothing to look a ported entity up by. (I proposed keying on `alIpseityEntityId` there and had to retract it.) The duplicate does surface eventually, though not kindly: `Entity.alIpseityEntityId` is `@unique` (`packages/prisma/models/entity.prisma:18`) and the new entity gets its id at final KYC save (`saveAngellistEntity.ts:233`), so if it resolves to the same ipseity entity the stamp collides and the LP is blocked partway through onboarding. If ipseity mints a different entity, the two quietly coexist.

See [[nova-matchmaking-owner-gate]], [[nova-matchmaking-retro-artifact]].
