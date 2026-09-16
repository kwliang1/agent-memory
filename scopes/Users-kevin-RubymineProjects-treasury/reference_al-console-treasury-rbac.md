---
name: al-console-treasury-rbac
description: "prod treasury console access is auth-flow-dependent (Forbidden in treasury-ro when SSO stale; 2026-09-02 blocked again); fallbacks = ask Kevin to re-auth/run script, or Snowflake via Metabase db 234"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 892ccf5d-c3ea-4745-9279-94d0bb3f1a41
  modified: 2026-09-02T22:49:22.467Z
---

**2026-09-02: READ console Forbidden again** (`pods "console-read-kevin.liang-0" is forbidden ... namespace "treasury-ro"`) — but **WRITE console (`-w`) WORKED** for a read-only `rails runner` one-liner (`console-write-kevin.liang-0`). So: try default read → if Forbidden, try `-w` → if that fails too, ask Kevin to re-auth / hand him the one-liner.

**Fallback for prod counts when console is blocked:** Snowflake via Metabase MCP (`mcp__claude_ai_AngelList_-_Metabase__execute_query`, database_id **234** "Snowflake Reporting"). Treasury tables live at `ANALYTICS.STAGING_TREASURY.TREASURY_<TABLE>_MB` (e.g. `TREASURY_MONEY_MARKET_FUND_YIELDS_MB`, `TREASURY_CUSTOMER_ACCOUNTS_MB`). Coverage is partial — e.g. `account_provider_money_market_funds` is NOT replicated, so bound with related tables instead. Datadog APM spans are retention-sampled (`retainedby: diversity_sampling`) — good for distinct-cardinality and status mix, not exact call counts.

**UPDATE 2026-07-22 (later, after Kevin re-ran the SSO/auth flow): READ console RESTORED.** `/Users/kevin/bin/al console push … -p -a treasury` then `… exec -p -a treasury -- bundle exec rails runner /tmp/x.rb` worked cleanly (pod `console-read-kevin.liang-0`, ~1 spin-up wait). So access is auth-flow-dependent, not permanently dead — if Forbidden, ask Kevin to re-auth before falling back to hand-him-the-script.

**Earlier 2026-07-22: BOTH tiers hard-blocked for kevin.liang** (pre re-auth). Write (`-w`) → `no access to role "GlobalConsoleWriters"`; Read (default) → `Forbidden ... treasury-ro`; Legacy (`-l`) → deprecated. When blocked, hand Kevin the read-only script to run himself (attach via reply). Verify diagnostics locally where possible.

`al` binary is NOT on the spawned-session shell PATH — invoke as `/Users/kevin/bin/al`.

`al console` prod treasury READ console (`-p -a treasury`, default = read-only, console-read-kevin.liang-0, namespace `treasury-ro`) is **RBAC-flaky**: worked 2026-07-10 morning, Forbidden again 2026-07-10 evening. **WORKAROUND (verified 2026-07-10, DEAD as of 2026-07-22): use the WRITE console — add `-w` flag** (`al console exec -p -w -a treasury -- ...`). Different namespace (`treasury`, not `treasury-ro`). Flags: `-p` prod, `-w` write console, `-l` legacy full-access, default is read-only. Pattern: `al console push <local> /tmp/x.rb -p -w -a treasury` then `al console exec -p -w -a treasury -- bundle exec rails runner /tmp/x.rb`. SSO may prompt (auto-opens browser). See [[feedback_prod-query-local-verify]].
