---
name: prophet-error-category-is-class-name-fallback
description: Prophet sends any non-BaseError raised by a handler with the Ruby class name as its category; caller-facing CHANGELOG text must say so
metadata:
  type: reference
---

`Prophet::Response.error` (prophet gem `lib/prophet/response.rb`) sets `category: error.category.presence || error.class.name`. Only `TreasuryProphetApi::Errors::BaseError` subclasses, plus what `BaseHandler#process` maps (RecordNotFound, RecordInvalid, RecordNotUnique), reach the caller as `not_found`, `validation_error`, `conflict`. Anything else arrives as its class name, e.g. `Frec::Client::ApiError`, `Interchange::Error`, `Protip::Error` or `RuntimeError`. Timeouts and NATS failures never produce a response: the client raises `Prophet::TimeoutError` / `ConnectionError` itself.

**Why:** BANK-2785 gate round 7. The 0.10.4 CHANGELOG listed only the mapped categories. A caller branching on them would misread provider outages, and that counted as a functional finding that reset the gate.

**How to apply:** when writing a treasury_prophet_api CHANGELOG entry for a new route, list the mapped categories, then one sentence covering "anything else is the class name; treat it as a server fault" and the timeout case. Related: [[project_bank2341-client-error-contract]].
