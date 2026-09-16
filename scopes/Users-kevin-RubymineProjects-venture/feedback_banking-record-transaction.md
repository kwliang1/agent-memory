---
name: banking-record-transaction
description: Venture multi-DB — use BankingRecord.transaction not ActiveRecord::Base.transaction for banking models
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 021ac3c2-b0c1-4819-a048-9574a5a80dda
---

In venture's multi-database setup, banking models use `BankingRecord` which `connects_to database: { writing: :banking }`. Any transaction wrapping banking model operations MUST use `BankingRecord.transaction`, not `ActiveRecord::Base.transaction`.

**Why:** `ActiveRecord::Base.transaction` opens a transaction on the primary (non-banking) connection. Banking model operations (`lock`, `update!`, `find_by!`) execute on the banking connection — completely outside that transaction. The lock is released immediately and writes are non-atomic. Both Devin and Cursor AI reviewers caught this on BANK-1469 while 4 rounds of internal review agents missed it.

**How to apply:** Whenever writing code that wraps banking model operations in a transaction — whether in services, handlers, public API services, mutations, or anywhere else — use `BankingRecord.transaction do ... end`. Look at existing banking services for the pattern (e.g. `banking/onboarding_service.rb:31`, `banking/team_members/update_service.rb:10`). This applies to any model inheriting from `BankingRecord`. This is not just a review concern — get it right in the initial implementation.
