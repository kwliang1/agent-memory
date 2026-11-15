---
name: temporal-ruby-nonretryable-bare-class-name
description: Temporal Ruby SDK reports a plain exception's failure type as the BARE class name, so fully-qualified non_retryable_error_types never match
metadata:
  type: reference
---
`temporalio-1.6.0 converters/failure_converter.rb:101` sets `type: error.class.name.split('::').last`. A `non_retryable_error_types: ['Foo::Bar::BazError']` entry never matches — use `'BazError'` or raise `Temporalio::Error::ApplicationError.new(msg, non_retryable: true)`. Live instance of the bug on main: `lib/temporal/workflows/sub_account_requests/process_workflow.rb:23` (as of 2026-10-23). Caught by the BANK-2398 gate.

Also: default `RetryPolicy` has no attempt ceiling (`max_attempts: 0` = unlimited).
