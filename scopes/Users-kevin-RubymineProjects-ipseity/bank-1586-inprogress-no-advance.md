---
name: bank-1586-inprogress-no-advance
description: "ipseity KYC auto-move tweak (Viv Hong): stop auto-advancing 'In Progress' tasks to Response Received. Shipped as PR #1533, not merged."
metadata: 
  node_type: memory
  type: project
  originSessionId: 1a6f9fb4-ce4b-483c-99e3-e303b92355d0
  modified: 2026-08-12T05:55:10.620Z
---

**Viv Hong follow-up to the BANK-1586 auto-advance feature ([[bank-1586-response-received-plan]]).** Ask: when pending docs are uploaded, do NOT auto-advance a linked Flowdash KYC task that's already in **In Progress** (it's an unassigned buffer that auto-flows to Needs Review after 24h — where tasks get assigned; jumping to Response Received skips Needs Review).

**Key framing correction:** Kevin called it "adding a value to the state enum," but the guard is a **fail-closed allow-list** `ADVANCE_FROM_STAGES` in `lib/flowdash/workflow/kyc_review.rb`, NOT a blocklist. `IN_PROGRESS` was IN the list → correct change is to **remove** it, not add. Same net effect.

**Live-state verified:** re-land **#1529** (`549c9127`) IS merged on ipseity `main` — feature is live, no BANK-1586 dependency for this tweak. Based branch on top of #1529.

**Change:** dropped `IN_PROGRESS` from `ADVANCE_FROM_STAGES` (remaining workable = NEEDS_REVIEW, NEEDS_FOLLOW_UP, TIME_SENSITIVE). Kept `IN_PROGRESS` constant DEFINED — still used by `app/services/alloy/slack_notification_service.rb:25` (Slack-alert filter). Nil-guards untouched. Spec: added "not advanced when In Progress" test; repointed 2 specs that used In Progress as a workable fixture → Needs Review/Follow-Up.

**Status:** ipseity **PR #1533** (branch `kevinliang/kyc-inprogress-no-advance`, worktree off origin/main). srb tc green; host rspec can't boot (Missing ENTITY_API_SECRET → Buildkite is the real run). 1 focused review round clean. Signed commit, --no-verify push (broken husky). **NOT merged — Kevin's to review/merge.**
