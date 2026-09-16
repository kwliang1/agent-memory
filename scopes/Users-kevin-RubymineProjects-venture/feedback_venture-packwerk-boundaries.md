---
name: venture-packwerk-boundaries
description: Venture uses strict packwerk — root package must access banking through BankingApp public API
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 021ac3c2-b0c1-4819-a048-9574a5a80dda
---

Venture enforces `enforce_dependencies: strict` via packwerk. The root package (`app/services/`, `app/controllers/`) cannot directly reference `Banking::*` models in `backend/banking/`.

**Why:** The event consumer (`app/services/treasury/event_consumer_service.rb`) referencing `Banking::MoneyMarketFundApplication` directly caused packwerk CI failure.

**How to apply:** When adding event handlers or root-package services that need banking models:
1. Create a public API service in `app/public_api/banking_app/` (e.g. `BankingApp::MoneyMarketFunds::ActivationService`)
2. Route through `Treasury::EffectsService` (root package) → `BankingApp::*` (public API) → `Banking::*` (banking package)
3. Follow the existing pattern: every event handler in `EventConsumerService` calls `Treasury::EffectsService`, never banking models directly.
