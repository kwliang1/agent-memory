---
name: bank-1469-mmf-submit-application-cutover
description: MMF v2 cross-repo cutover — Venture create_account → submit_application + event-driven CA resolution; issue chain BANK-1463/1509/1469/1505
metadata: 
  node_type: memory
  type: project
  originSessionId: 68d15e8c-d696-4429-a827-757196bc2402
---

MMF v2: Venture must stop calling `create_account` and call `submit_application`, then resolve the MMF CustomerAccount asynchronously (it no longer exists at submission time). Full reviewed plan lives in Linear **BANK-1469** description (written 2026-06-25, new-table solution). Branch `kevinliang/bank-1469`.

Key verified facts (don't re-derive):
- `submit_application` is a **REST** endpoint — `TreasuryAPI::MoneyMarketFund.submit_application` (`treasury_api` gem) → `Api::MoneyMarketFundsController#submit_application`, returns `application_uuid`. NOT the prophet RPC client. The `treasury_prophet_api` 0.6.x bump is irrelevant to the submit call (but the prophet gem DOES define the event message classes, so it matters for the observation half).
- Venture caller: `backend/banking/app/graphql/banking/mutations/create_mmf_account.rb:38` is the sole writer of `mmf_treasury_account_id`; ~7 read sites across 5 files depend on "present ⇒ ready CA".
- Async resolution is **event-driven** via existing `Treasury::EventConsumerService` (`app/services/treasury/event_consumer_service.rb`, `case payload` dispatch ~:277, DLQ `TreasuryEvent::DeadLetter`). No polling.
- The treasury event **already exists** — BANK-1509 / PR #7966 (open, mergeable, branch `kevinliang/bank-1509`, prophet gem 0.6.3). Class: `TreasuryProphetApi::Messages::TreasuryEvents::Applications::MoneyMarketFunds::ActivatedEvent::V1::Payload`, fields `application_uuid` + `account_type` ("CustomerAccount") + `account_id` (the CA uuid). NOT `CustomerAccounts::CreatedEvent`. Venture handler must match this. (#7966 has uncommitted working-tree tweaks — confirm final payload before consuming.)
- Solution: new `Banking::MoneyMarketFundApplication` model (tracks application_uuid/status/CA uuid); on the new treasury event, write resolved CA uuid back into `vehicle.mmf_treasury_account_id` so read sites stay untouched. `backend/banking` is slated for deprecation in a few months — keep blast radius minimal.

Issue chain & deploy order (strict):
1. BANK-1463 — treasury `submit_application` (merged, commit `2cb780739` on treasury main).
2. **BANK-1509** (filed 2026-06-25) — treasury emits new MMF-activated event (application_uuid + customer_account_uuid). **Gating prereq, blocks BANK-1469.** Without it, shipping the submit cutover alone bricks MMF account creation in prod.
3. **BANK-1469** — this Venture cutover (submit + model + event consumer).
4. **BANK-1505** — treasury removes `create_account`. Separate branch `kevinliang/bank-1505` for its own Linear sync; must deploy LAST.

Both gems are git gems from the treasury monorepo (`gem 'treasury_api', git: angellist/treasury, branch main`). Lock rev `b93022d4` predates submit_application — needs `bundle update treasury_api`. See [[rbi-regen-treasury-gem-bumps]] for RBI regen.
