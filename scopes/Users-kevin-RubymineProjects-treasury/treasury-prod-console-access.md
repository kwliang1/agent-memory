---
name: treasury-prod-console-access
description: "How to run prod Rails console queries myself via the `al console` CLI (kubectl consoles) instead of handing Kevin scripts"
metadata:
  node_type: memory
  type: reference
  originSessionId: 55f5576b-3a6c-4309-9a8f-44b9a9471694
  modified: 2026-07-28T05:24:39.809Z
---

I have prod console access via the `al` CLI (`/Users/kevin/bin/al`, an AngelList unified CLI). Kevin confirmed 2026-07-09 — run queries myself rather than pasting scripts for him to run.

**Run a script (non-interactive):**
```
al console push -a treasury -p <local.rb> /tmp/x.rb
al console exec  -a treasury -p -- bundle exec rails runner /tmp/x.rb
```
- `-a/--app` = namespace (`treasury`, `venture`, `nova`, `ipseity`, `comptroller`, default `angellist`); `-p` = prod (`--env prod`); default is **staging**.
- Default console is **read-only**; add `-w` for the **write** console. Consoles are per-user k8s pods (e.g. `console-read-kevin.liang-0`); first exec spins one up (`Waiting for … to be ready`, ~10-30s). `al console list -a treasury -p` shows existing.
- Subcommands: `create/attach/exec/list/delete/push/pull` (alias `al cs` / `al k`).

**Gotcha — TP API needs the WRITE console:** the READ console lacks Treasury Prime API base-url/creds, so `TreasuryPrime::ApiService.get(...)` fails with `not an HTTP URI` (net-http, api_service.rb:78). DB-only queries (ActiveRecord over LedgerEntry/OutgoingWire/CustomerAccount) work fine on READ. For anything hitting `TreasuryPrime::ApiService` (e.g. `account/<acct_id>/transaction`), use `-w`.

**Gotcha — console pods go STALE (2026-07-11):** a console pod keeps the app image from when it was created — long-lived pods run OLD code (mine lacked changes merged 4h earlier; Kevin spotted it). Before making any "is X deployed?"/code-presence claim, recycle the pod: `al console delete -a treasury -p -w` then `al console create --no-attach -a treasury -p -w` (plain `exec` after delete does NOT recreate the konsole CR — it fails with `role "console" not found`; `create` is required). Also `al console list` can report "No consoles found" even when the -0 pod exists, and the read console's `treasury-ro` RBAC block recurs — write console is the reliable fallback.

**Gotcha — WRITE console role is TIME-BOXED (2026-07-27):** `al console -a treasury -p -w` can fail with `!! no access to role "GlobalConsoleWriters"` even after a successful `aws sso login` — the writer elevation is time-limited and lapses mid-session (worked at the start of a session, gone ~1h later). When BOTH read (`treasury-ro` Forbidden) and write (role lapsed) are down, I have no treasury prod access; hand Kevin the runner or ask him to re-grant the writer role. Not retryable by re-running SSO.

**Always keep console work READ-ONLY unless Kevin explicitly authorizes a write** (`find`, `.where`, API `GET` only — no `create!/update!/save`). Wrap exploratory writes Kevin asks for in a rolled-back transaction unless he says commit. Prefer pushing a file over inline `-e`/quoted ruby (quoting hell). Used to diagnose [[duplicate-wire-debit-mismatch]].

**RBAC flips between read and write.** Being granted `GlobalConsoleWriters` revoked my `treasury-ro` access — `al console exec -a treasury -p` then fails with `pods ... is forbidden ... in the namespace treasury-ro`. Both can also lapse mid-session. The write console runs read-only queries fine, so when write is granted just use `-w` for everything.
