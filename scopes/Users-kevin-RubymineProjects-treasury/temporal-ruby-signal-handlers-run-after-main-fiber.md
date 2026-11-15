---
name: temporal-ruby-signal-handlers-run-after-main-fiber
description: temporalio Ruby 1.5.0 resumes the main fiber synchronously on timer fire / activity result while same-task signal handlers are only queued — yield before reading signal-fed state, or ContinueAsNew drops the signal
metadata:
  type: reference
---

In temporalio Ruby 1.5.0, `fire_timer` and `resolve_activity` resume the waiting main fiber inside `apply` (workflow_instance.rb:358-359,370), but `apply_signal` only schedules the handler fiber (:404-415). If a signal arrives in the same workflow task as a timer fire or an activity result, the main fiber runs first and doesn't see it. If it then raises ContinueAsNewError without yielding, the signal is lost silently.

Fix: put `Temporalio::Workflow.wait_condition { true }` before every read of signal-fed state. It always yields (scheduler.rb:68-82), sends no command, and is replay-safe. BANK-2459 needed it per drain iteration (`next_snooze_request`), not once before the loop; that took rounds 33 and 34 to find.

Spec technique: stop the worker across the timer fire (`env.sleep(seconds_until + 1)` with no worker running), wait for TIMER_FIRED in history, signal, then start a fresh worker with `max_cached_workflows: 0`. Don't `env.sleep` far past the timer: once it fires, the server stops skipping time while a workflow task is pending, and the RPC times out.

Related: [[temporal-specs-no-rspec-spies-inside-workflow]] · [[temporal-ruby-nonretryable-bare-class-name]]
