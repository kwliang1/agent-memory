---
name: ipseity-no-goodjob-cron
description: ipseity doesn't enable GoodJob cron, so a recurring job needs a Temporal schedule; Temporal is preferred over GoodJob anyway
metadata:
  type: reference
---

`config/application.rb` sets the GoodJob adapter but no `enable_cron` or cron entries, so a GoodJob job has nothing that runs it on a schedule. Recurring work in ipseity runs on Temporal schedules; Persona's polling is the example (`Integrations::Persona::ScheduleService`, `lib/temporal/workflows/persona/poll_events_workflow.rb`). Nothing creates a schedule automatically: `ensure_schedule_exists!` is run once per environment by hand. Kevin prefers Temporal over GoodJob for new async work.

**How to apply:** build a recurring job as a Temporal workflow with a schedule, not a GoodJob class, and plan the step that creates the schedule.
