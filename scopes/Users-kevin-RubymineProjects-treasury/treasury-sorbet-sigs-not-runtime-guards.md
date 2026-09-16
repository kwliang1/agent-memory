---
name: treasury-sorbet-sigs-not-runtime-guards
description: In treasury, a non-nilable Sorbet sig does NOT raise at runtime in prod and is skipped entirely in test — never treat a clean typecheck as a nil guard
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
