---
name: treasury-sorbet-sigs-not-runtime-guards
description: In treasury, sigs and T::Struct props do NOT raise at runtime (T.let/T.must DO) — never treat a clean typecheck or a struct type as a nil guard
metadata:
  type: reference
---

`config/sorbet.rb` overrides `T::Configuration.call_validation_error_handler`:

```ruby
next if Rails.env.test?
raise error if signature&.on_failure && :raise.in?(signature.on_failure)
ErrorTracker.error(error)
```

So a sig violation **logs and execution continues into the method body** in production, unless that specific sig declares `on_failure: :raise`. In test it is a bare `next` — no check at all. The comment also notes this disables `T::Struct` prop-type enforcement.

Consequences:
- `sig { params(x: SubAccount) }` is documentation, not a guard. A nil reaches the body and blows up on the first deref.
- A green suite is **structurally incapable** of catching it, and `srb tc` won't either when the value launders through an untyped call (e.g. `transfer.destination` is untyped).
- Guard nilables explicitly at the call site.

**Why:** on 2026-08-31 this let a `nil.svb?` into `Transfers::InfoService.requires_svb_ach_split?` through a non-nilable sig, with 570 green examples and a clean typecheck. Caught only by review. It also converts a recoverable `Transfer::CreationError` (which drives `SubAccountRequests::RetryService`) into a bare `NoMethodError` that the catch-all re-wraps, destroying the recovery path.

**But `T.let` and `T.must` DO raise at runtime** (they use `inline_type_error_handler`, which config/sorbet.rb leaves at the default). So replacing `T.let(raw['id'], String)` / `T.must(x)` on provider data with a non-nilable `T::Struct` prop silently drops a fail-closed guard: the struct takes nil and the code keeps going. BANK-1804 (2026-11-03) lost two such guards in Frec `buy_movement` this way. It took gate rounds 12 and 13 to restore both with an explicit raise. When typing a provider payload into structs, list every `T.let`/`T.must` the old code ran on those fields and keep an explicit raise for each.
