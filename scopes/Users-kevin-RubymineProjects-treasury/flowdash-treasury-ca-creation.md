---
name: flowdash-treasury-ca-creation
description: "What it takes to create treasury CustomerAccounts from Flowdash (scoping findings, 2026-06-27)"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 77f6b237-62fa-41a6-80e3-a258759c9022
---

Scoping for "create CustomerAccounts from Flowdash" (investigated 2026-06-27).

**Flowdash** (`/Users/kevin/RubymineProjects/flowdash`): standalone Rails 7.2 app, separate repo/deploy, React front-end. Backend actions run via the **Step framework** (Workflow→Stage→Task→Action→Step); user click → GraphQL `Mutations::Actions::PerformAsync` → Sidekiq `ActionExecution#execute!` runs ordered `StepExecution`s. **Only outbound transport is HTTP (Faraday)** — NO NATS/Prophet/gRPC client. Existing third-party integrations (incident.io at `app/models/step_execution/incident_io.rb`, Slack, Twilio) are the template: typed payload + Faraday POST + bearer token from `Settings`. Today treasury only *consumes* Flowdash's REST API (inbound, `User-Agent: Treasury`); zero outbound treasury calls exist.

**Treasury CA creation**: canonical logic = `CustomerAccounts::CreateService.create!` (`app/services/customer_accounts/create_service.rb:15`). Callable surfaces: Prophet RPC `CustomerAccount.create` (`app/handlers/customer_accounts_handler.rb:6`, modern/recommended) and legacy REST `POST /customer_accounts` (`app/controllers/api/customer_accounts_controller.rb:18`, deprecated but handles FBO/IVC). No generic GraphQL create. Inputs: `entity_id` (Ipseity) + `source` (closed enum: angellist/alto_ira/standalone_banking/nova) + optional `account_purpose`. **Creating a CA auto-provisions a REAL bank SubAccount via a Temporal workflow** (`SubAccountRequests::CreateService`) — major side effect. `create` has NO caller-identity authz (REST = shared secret `TREASURY_API_SECRET`; Prophet = NATS secrets).

**The gap & recommendation:** Flowdash is HTTP-only; treasury's modern create is Prophet/NATS. So either (1) fast: Flowdash Step → HTTP POST to the deprecated REST endpoint, or (2) cleaner: treasury adds a thin modern HTTP endpoint wrapping CreateService, Flowdash Step calls it. Don't give Flowdash NATS just for this. **Decisions that are the real work:** add a `flowdash`/`ops` source enum value (sync model + gem); intentionally handle the real-bank-subaccount side effect; add authz if Flowdash should be entity/purpose-restricted; FBO/fund (IVC) accounts only work via the REST path. Effort for standard entity-owned CAs: days, not weeks. See [[treasury-prophet-datadog]] for the prophet handler layer.
