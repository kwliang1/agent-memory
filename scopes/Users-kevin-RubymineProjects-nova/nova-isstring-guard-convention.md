---
name: nova-isstring-guard-convention
description: "Use isString from @angellist/std.ts/guard for string type-narrowing in nova, not a hand-rolled typeof check (PR #6898)"
metadata:
  type: reference
---


- Use `isString` from `@angellist/std.ts/guard` for string type checks — not `typeof === 'string'`, not `effect/String`, not `lib/string`. See PR #6898 discussion.

Relocated 2026-09-16 from the conductor nova-san-jose worktree scope, which no session loads.
