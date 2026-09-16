---
name: nova-buildkite-deploy-queue-block
description: "Why a stuck \"running and failing\" nova main build blocks ALL newer builds' staging deploys, and how to tell it's a flake safe to cancel."
metadata: 
  node_type: memory
  type: reference
  originSessionId: 9fc22eb0-2857-4b36-bd32-8c632e5f1133
  modified: 2026-08-19T23:06:18.884Z
---

nova Buildkite (pipeline `angellist-venture/nova`, main branch) staging/prod deploys run in **commit order** — a stuck build at the front of the queue blocks every newer build's staging deploy, even when the newer build is fully green.

**Symptom:** newest main build is green (all e2e ✓, all deps satisfied) but its `Nova Staging (Sandbox)` group sits at `0/5` (jobs never scheduled). Meanwhile older builds show "Running for Nh and failing" for hours.

**Mechanism (verified 2026-08-19 on builds #46834/#46842/#46869):**
- Staging deploy `depends_on` build+test steps (`.buildkite/pipeline.rb:589`) — a build whose e2e fails can NEVER deploy. But while it's still "running and failing" (an e2e shard still auto-retrying), its deploy job stays *waiting* (not skipped), holding its queue slot ahead of newer builds. `deploy_step_v4` (external gem, not readable in repo) serializes deploys in order.
- Proof the flow itself is healthy: an earlier green build deployed Staging 5/5 + Prod 5/5 in ~17m; the newer green build stalled only because 4 failing builds sat ahead of it.

**Flake vs. real break test:** git `merge-base --is-ancestor <failing-build-sha> <green-HEAD-sha>`. If the failing commits are ancestors of a newer GREEN build, the same (superset) code passes ⇒ flake, not those PRs. nova e2e flakes here manifest as **~45-min job timeouts/hangs** ("Timed Out, Ran in 45m42s", exhausted retries), not assertion failures.

**Resolution:** stuck builds won't self-heal promptly (retries take 45m each, can re-hang). Cancel them → queue advances → latest green build (which contains all their code) deploys to staging. Canceling loses no deploy (they can't deploy anyway). Read build logs via [[ci-failure-via-chrome skill]] — Buildkite log is behind SSO, no bk CLI installed.
