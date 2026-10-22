---
name: nova-read-console-has-no-nats-creds
description: The nova prod READ console cannot make Prophet/NATS calls (Authorization Violation); its config-readonly.yaml ships empty NATS_JWT/NKEYS_SEED. Anything that calls Treasury/Ipseity over Prophet needs the write console, even for a dry run.
metadata:
  type: project
---

Verified 2026-10-15 while trying to dry-run `EngBot.BackfillTransferCompletedAt.plan()` from
`al console create -a nova -p` (template console-read, namespace nova-ro). The first
`treasury_events.consume` request failed with `NATS connection failed: Authorization Violation`.

**Why:** the read console's secret is built from
`graph/config/configtool/prod-us-west-2-zeus/config-readonly.yaml`, which sets `NATS_JWT: ""` and
`NATS_NKEYS_SEED: ""` (lines 43-44) while keeping `NATS_URL: tls://connect.ngs.global`, so the client
connects anonymously and NGS rejects it. The write console (`just console -p -w`, template
console-write) uses the full app config minus DB creds (`graph/cdk8s/main.ts` ~458-461), so Prophet
works there. DB access via IAM works in both.

**How to apply:** a prod dry run of anything that calls Treasury or Ipseity over Prophet needs the
write console and a JIT `console-writers` grant; the read console is only good for DB reads. Don't
spend time pushing files into a read pod to "preview" a Prophet-backed engbot. Related:
[[feedback_gate_in_fresh_session]] for the backfill runbook details in the engbot docblock.
