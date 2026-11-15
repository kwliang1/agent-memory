---
name: dibs-bank-limit-hold-alerting
description: DIBS FboLimit holds retry forever silently; UI monitor 178876572 has no handles; the incident.io webhook creates alerts but never incidents
metadata:
  type: project
---
A DIBS payment over an FboLimit raises LimitExceededError before submission and SubmitActivity retries every 30 min with no max attempts, while the Treasury transfer reads submitted (INC-5822, $24.5M Piermont wire vs $10M cap, 2 days). UI-made monitor 178876572 alerted the whole time but has no @-handles. PR #9217 (BANK-2377) adds `ops/datadog/monitors/dibs-bank-limit-exceeded.json` paging incident.io.

**Why:** splitting a held payment without cancelling it can pay twice — the original submits once the limit is raised or the period resets. BNY cancel doesn't stop it (BANK-2378).
**How to apply:** `@webhook-incidentio_webhook` alerts reach route "Datadog Banking Alerts" (Team = Nova Foundations → escalate + create incident), but the Datadog source title-cases the team tag (`team:nova-foundations` → `Nova-foundations`), which misses the catalog alias `nova-foundations`. So as of 2026-10-22, 112 of 122 Datadog alerts had Team=None and none opened an incident or paged. Check alert_stats group_by team/has_incident before claiming a monitor "opens an incident". Renotify reuses the dedup key (one alert per episode). A new monitor's first eval alerts on any in-flight condition — time the merge. Datadog log search needs `::` values quoted. Related: [[reference_datadog-monitor-needs-unconditional-gauge]].
