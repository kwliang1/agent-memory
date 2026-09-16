---
name: One-off scripts: loadable .rb for rails console; PR optional, deploy skippable
description: For throwaway operational scripts in Ipseity, deliver a standalone .rb with a callable module for `load` in rails console. A PR for review is fine, but don't block execution on merge/deploy.
type: feedback
originSessionId: 3671a678-85e7-40db-a1f7-1a2a37316e45
---
For one-off operational / pre-req / validation scripts in this Ipseity codebase, deliver a **standalone `.rb` file that defines a callable module** (e.g. `MyJob.run(kwargs...)`). The user's execution venue is `rails console` on an Ipseity host: `load` the file, then invoke the method. Do NOT default to a rake task.

**Why:** User executes these interactively via `rails console`, often before a PR has merged/deployed. Opening a PR for review is welcome so others can scrutinize the logic, but the user does NOT wait for merge/deploy to actually run the script if the review looks good — they scp the file to a host (or check out the branch) and load it in console. Rake tasks force a deploy-before-run cycle that doesn't match this workflow.

**How to apply:** When the user says "one-off," "one-time pre-req," "script for this ticket," or mentions rails console:

1. Deliver a single `.rb` file structured as:
   ```ruby
   module MyJob
     def self.run(input:, output:, cache:, qps: 35, limit: nil, reset: false, overwrite: false)
       # ... implementation
     end
   end
   ```
2. Default placement: `script/` (standard Rails convention for one-offs). Open a PR so others can review.
3. No top-level side effects on `load` — explicit method invocation only. This lets the user re-run with tweaked kwargs in the same console session, and load/reload safely after edits.
4. Don't couple execution to the PR merging. The script should be runnable from the user's branch checkout on the host, not from the deployed code.

Rake is still correct for scripts that live in the codebase long-term (recurring maintenance, runbook procedures).