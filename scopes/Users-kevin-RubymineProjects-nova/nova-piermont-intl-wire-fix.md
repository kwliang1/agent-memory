---
name: nova-piermont-intl-wire-fix
description: "INC-5462 nova fix — Piermont international wire instructions now show beneficiary + PCBB intermediary routing (not FFC collapse). PR #9436 draft, NOT merged."
metadata: 
  node_type: memory
  type: project
  originSessionId: 48ff2274-fa63-4105-abed-2c9f000f0d38
  modified: 2026-08-12T20:57:14.195Z
---

INC-5462 nova-side fix (branch `kevinliang/nova-piermont-intl-wire-routing`, worktree `.worktrees/piermont-wire`, HEAD `97ac2738`, signed). **PR #9436 APPROVED by Yewon (ywplee-al) — NOT merged; do not merge without Kevin.** SWIFT-dedup logic extracted to shared `beneficiarySwift.ts` (`beneficiarySwiftCodeToShow`) used by both copy-all + on-screen rows (per Yewon nit). Thomas (treasury lead) confirmed: keep intermediary ABA row + dedupe SWIFT to intermediary-only — both already implemented. Links INC-5462 (incident.io + Slack C0BQME6T6AU). NOTE: do NOT commit screenshots into the repo — Kevin rejected that (I'd committed the e2e PNG + embedded via blob URL; removed it). GitHub API can't upload PR-body images, so hand the screenshot to Kevin (Slack) and let him drag-drop into the desc; leave a `<!-- drag-drop -->` placeholder.

**What:** Piermont international ("From non U.S. bank") wire instructions were forced through Grasshopper's FFC `AlternativeNonUS` layout, collapsing onto PCBB (headlined PCBB's routing; copy-all labeled PCBB as primary "Bank", dropped Piermont's own ABA). Fix in `app/src/components/vulcan/elements/PaymentProvider/ALTreasury/ALWireInstructions/`:
- `index.tsx` — `showAlternativeNonUSWireInstructions` now Grasshopper-swift-missing only; Piermont uses standard `DefaultWireInstructions` correspondent layout.
- `DefaultWireInstructions/helpers.tsx` + `fullCopyBuilder.ts` — added "Intermediary bank ABA / Routing number" row (`intermediaryBank.routingNumber`); suppress top-level beneficiary SWIFT when `wireInfo.swiftCode === intermediaryBank.swiftCode` (Piermont has no own BIC → PCBBUS66 is correspondent's). GHB (own BIC differs) + SVB (no intermediary) unaffected.
Result matches Piermont's official sheet field-for-field. Memo unchanged (STANDARD). No backend/schema change.

**Validation:** 6 unit tests green, nova-e2e Playwright spec green (`nova-e2e/tests/specs/banking/wireInstructionsPiermont.spec.ts` — stubs `EntityFinancialAccountWireInstructions`, drives account-page Wire-instructions modal, screenshots), typecheck + biome clean. 3-round independent review gate passed (final: no concerns). Screenshot at `.worktrees/piermont-international-wire.png`.

**e2e how-to (reusable):** `cd nova-e2e && just e2e run --auto specs/banking/<spec>` (boots emulator+graph+app+proxy). Emulator has NO `customer_accounts.wire_instructions` prophet handler → stub the wireInfo GraphQL op via `page.route('**/api/graphql')`. `createSenderOrg(handle)` handle must be in `SENDER_ORG_DEFINITIONS` (e.g. `navigation-testing`). Fresh worktree: `pnpm turbo run build --filter=app^...` before vitest (unbuilt dist). See [[inc-5462-piermont-intl-wire-routing]] for the domain/RCA and [[nova-worktree-dev-gotchas]].

**Companion:** treasury PR #8515 adds the intermediary ABA to the treasury PDF. Nova/venture were the "collapse" surfaces flagged in the RCA; this fixes nova. Venture `wire_manual.rb` still collapses (separate follow-up if wanted).
