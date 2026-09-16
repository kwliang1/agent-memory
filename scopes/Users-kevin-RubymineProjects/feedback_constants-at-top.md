---
name: constants-at-top
description: "Constants must be defined at top of class, before method definitions — never inside class << self or after private"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 2550bd47-3ed3-45da-8f6e-f9cf91b74ecb
---

Constants at top of class, before method definitions — not after `private` or inside `class << self`.

**Why:** Team coding style — constants are class-level declarations and should be visually grouped together at the top for discoverability. Defining them inside `class << self` or after `private` buries them.

**How to apply:** When defining constants like `T.let({...}.freeze, ...)`, place them at the top of the class body, alongside other constants (e.g., `AUTO_MIGRATION_THRESHOLD_CENTS`, `EXCLUDED_PROGRAMS`). Related to [[services]] pattern where constants go before `class << self`.
