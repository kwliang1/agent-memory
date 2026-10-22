---
name: interchange-empty-account-limits-dont-block
description: Interchange docs say an unset per-transaction funding limit blocks that rail, but sandbox achPull succeeded with account controls limits {}; wire.canWithdraw must be true for wirePush sells
metadata:
  type: reference
---

Interchange's `ProgramControls_Funding_Limits_*` schemas say "If unset, the account cannot deposit/withdraw via X". In sandbox, account `034BpTJEIHbujd3eMOokAB` has `funding.limits: {}` and an `achPull` of $1000 still reached SUCCESS (2026-10-13). So empty account-level limits don't block; a reviewer citing that doc line is not evidence by itself.

Separately, `settings.wire.canWithdraw` must be `true`: every Treasury MMF sell is a `wirePush` ("Wire withdrawal"). The Treasury guide's example sets it false; onboarding copied that until 2026-10-14 (#9083).

**How to apply:** check a live sandbox account's controls and transfer history (`ix.sh GET`) before acting on a doc-only claim about Interchange controls. Related: [[treasury-tp-idempotency-replay-undefined]]
