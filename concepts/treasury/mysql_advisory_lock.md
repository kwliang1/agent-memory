<!-- machine-owned: regenerated every run, never hand-edit -->
---
concept: [treasury, mysql_advisory_lock]
related:
  - [treasury, customer_account]
  - [treasury, money_market_fund_account]
  - [treasury, ledger_entry]
---
symbols:  MysqlAdvisoryLock, MysqlAdvisoryLock::LockTimeout
files:    lib/mysql_advisory_lock.rb
indexed:  b9e45f71df9f1334507931a1f0b575bc976578a7
<!-- end machine-owned -->

## Judgment
MySQL caps lock names at 64 chars (error 4163). A prefix plus a 36-char UUID overflows past a
~28-char prefix, and specs with short fixture ids hide it; use a UUID-shaped fixture.
provenance: review gate, 2026-10-06
