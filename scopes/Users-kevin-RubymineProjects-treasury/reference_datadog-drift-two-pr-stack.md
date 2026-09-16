---
name: datadog-drift-two-pr-stack
description: "Datadog drift-check structurally forces a 2-PR stack (pull, then change); repo banking.json dangling widget_ids = widgets missing from the repo; how to dd-pull without 1Password"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 6403d9eb-d7ee-4ec9-b2ae-f9e8da960500
  modified: 2026-09-15T06:35:44.356Z
---

`ops/datadog/sync.mjs --drift-check` forgives drift **only** when the branch's file equals the live dashboard *exactly* (`sync.mjs:398-406`: `mainNormalized !== remoteJson` → fall back to `localJson === remoteJson`). So when the repo file has fallen behind production, **a single PR that both pulls prod and makes a change cannot pass** — it matches neither `main == remote` nor `local == remote`. Two stacked PRs are forced, which is what the thrown error at `sync.mjs:405` prescribes:

1. **pull PR** — file := verbatim normalized production. `local == remote` → "drift from main, but this branch already contains the fix — skipping". Merge PUTs prod's own state back, a no-op.
2. **change PR** — stacked on 1. Once 1 is on main, `main == remote` → no drift.

**Dangling `widget_ids` in a dashboard JSON are not a harmless quirk** — they are widgets that exist in production and are *missing from the repo file*. Production is internally consistent (refs == widgets, 0 dangling); only the repo drifts. Verified on `banking.json` 2026-09-14: repo 119 widgets / 138 refs / 19 dangling vs prod 135 widgets / 135 refs / 0 dangling, and the 19 resolved to the CryptoDeposit + settlement-wire block in `Payments Health` plus `Temporal Schedules` in `Crons`. Merging the stale file would have **deleted 20 live widgets**, resurrected 4 dead ones, and reverted 27.

Drift accumulates silently because `.buildkite/pipeline.rb:16` (`skip_datadog_sync_reason`) skips **both** Datadog steps unless the build touches `ops/datadog/`. Nothing re-syncs between ops/datadog PRs, so UI edits pile up unnoticed.

## dd-pull without 1Password

`make dd-pull` needs `op`. To get the identical bytes from an authenticated browser session instead (Claude-in-Chrome), run in the page context on `app.datadoghq.com`:

```js
const STRIP = new Set(['id','url','created_at','modified_at','author_handle','author_name',
  'is_read_only','notify_list','reflow_type','template_variable_presets']); // = DASHBOARD_STRIP_KEYS
const raw = await (await fetch('/api/v1/dashboard/<slug>', {credentials:'same-origin'})).json();
const body = {}; for (const [k,v] of Object.entries(raw)) if (!STRIP.has(k)) body[k]=v;
const s = JSON.stringify(body, null, 2) + "\n";   // exactly what sync.mjs:347+355 writes
```

Session cookies authenticate `/api/v1/dashboard/<slug>` fine. Get the bytes out with a Blob + `<a download>` click (lands in `~/Downloads`) — tool results truncate around ~4KB, so never return the JSON itself; return only a SHA-256 and compare it against the downloaded file.

Caveat to state when using this: the pull came from session auth, not API-key auth. If the two return different shapes the pull PR's drift-check fails and CI says so.

Note the pulled file drops `restricted_roles` (the API omits it; absent ≡ `[]`) and writes non-ASCII as literal UTF-8, whereas a hand-maintained file may use `\uXXXX` escapes — so a pull reformats those characters file-wide. Related: [[worktree-precommit-hook-stale-main]], [[project_datadog-docs-ci-owns-sync]].
