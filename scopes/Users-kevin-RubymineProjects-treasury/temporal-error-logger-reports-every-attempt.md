---
name: temporal-error-logger-reports-every-attempt
description: TemporalUtils ErrorLogger sends EVERY failed activity attempt to Sentry; ErrorTracker silently drops UntrackedError instances, so a "final-attempt alert" needs a String message
metadata:
  type: reference
---
`TemporalUtils::Interceptors::ErrorLogger` (`lib/temporal_utils/interceptors/error_logger.rb:23-27`) reports every failed activity attempt to Sentry unless the error is an `ErrorTracker::UntrackedError`. There is no final-attempt gate.

`ErrorTracker.error` (`lib/error_tracker.rb:51-57`) returns before Sentry when either the message or `args[0]` is an `UntrackedError`.

So for an expected-retry error (e.g. Frec deposit account still PENDING): subclass `UntrackedError`, and on the final attempt report a **String** message from the activity. Passing the exception itself is silently dropped, and a spec that stubs `ErrorTracker.error` won't catch it. Assert on `Sentry.capture_message` with `Rails.env.production?` stubbed.

Old code comments claiming "final-attempt Sentry is owned by the interceptor" were wrong (fixed in BANK-2234).

See [[mmf-frec-deposit-account-routing-collision]].
