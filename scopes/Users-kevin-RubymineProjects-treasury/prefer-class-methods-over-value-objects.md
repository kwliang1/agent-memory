---
name: prefer-class-methods-over-value-objects
description: "Kevin's preference — stateless helper/extraction classes should be class methods, not instantiated value-object wrappers, unless the instance earns its keep"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 3ad9960c-76bc-41e1-bc5d-096317de4033
  modified: 2026-08-22T06:16:57.187Z
---

When extracting logic into a helper class (e.g. `BalanceCheck::Classification` from BANK-1859), Kevin prefers **stateless class methods** (`Classification.match_kind(record)`, `class << self`) over an instantiated value object (`Classification.new(record).match_kind`).

**Why:** the value-object wrapper only earns its keep if the instance carries real state — memoization, or state shared across a call sequence. If each public method just recomputes from the wrapped record (no memoization) and consumers memoize results in their own ivars anyway, the instance buys nothing but ceremony (`.new` + a `@record` ivar). Class methods that take `record` are the leaner, preferred shape. Mirrors the existing `Payments::Health::Transfers::EvaluationService` / `OutgoingPayment::InfoService` (`class << self`) pattern.

**How to apply:** default to class methods for a stateless extraction. Only reach for an instance/value object when you can name the real utility (memoized subset-search, shared state across N calls on one instance). "Saves re-typing `record`" is NOT sufficient. This also aligns with `.claude/rules/services.md` (InfoService = lookups/predicates as class methods under `class << self`). See [[op-balance-check-classification]].
