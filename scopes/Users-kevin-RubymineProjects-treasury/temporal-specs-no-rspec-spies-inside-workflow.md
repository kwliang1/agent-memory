---
name: temporal-specs-no-rspec-spies-inside-workflow
description: rspec stubs/spies on methods called inside workflow code can trip temporalio's illegal-call tracer (Mutex); a failed run then strands on a fixed task queue and fails later examples — use per-example task queues and assert via history
metadata:
  type: feedback
---

`allow(WorkflowClass).to receive(:m).and_call_original`, when `m` runs inside workflow code, goes through rspec-mocks' proxy Mutex. temporalio's illegal-call tracer rejects that as `Cannot access Thread::Mutex synchronize from inside a workflow`, and the task fails forever. It passed in BANK-2459 until a `wait_condition` yield was added, then broke.

Worse, the stuck run stayed on the fixed task queue `'test-tp-tin-fix'`, so later examples' workers picked it up and unrelated `.once` assertions failed. That looked like 8 random failures.

**Why:** cost an hour of misdiagnosis in round 33.
**How to apply:** in treasury Temporal workflow specs, use `let(:task_queue) { "…-#{SecureRandom.hex(4)}" }`. Assert workflow-internal behaviour from history instead (e.g. TIMER_STARTED `start_to_fire_timeout` on `workflow_handle(id, run_id: handle.first_execution_run_id)`) rather than spying on methods the workflow calls. Stubbing service methods that only activities call is fine.

Related: [[temporal-ruby-signal-handlers-run-after-main-fiber]]
