---
name: nova-local-e2e-matchmaking
description: "How to drive the LP-migration admin UI end-to-end locally: seed script, treasury NATS collision, minted venture session (auth.angellist.dev is down), scoring flag."
metadata: 
  node_type: memory
  type: project
  originSessionId: af78388c-a659-4db4-ad5f-53c58488dced
  modified: 2026-09-02T22:06:24.742Z
---

Recipe proven 2026-09-01 (BANK-1941 screenshots) for exercising AdminTools → Matchmaking → "LP migration (CSV)" against a worktree stack:

1. **Seed**: `graph/scripts/seedMatchmakingLocalDemo.ts` (run with env sourced, `npx tsx`) seeds local ipseity entities (Grace Hopper et al., known TINs 210-55-500x / 82-055510x), links treasury INVESTMENT wallets via `docker exec treasury`, and writes a demo CSV incl. `owner_email`. Requires `MATCHMAKING_SCORING_ENABLED=true` in `.devcontainer/.env` + full stack restart (process-compose reads env once).
2. **⚠️ Treasury NATS collision**: worktree treasury containers (`treasury-flint`, `treasury-1360`, …) join the same Prophet/NATS queue group as main `treasury`. A worktree instance with a missing DB (flint) fails ~1/N of ALL treasury calls machine-wide (scoring dies with `We could not find your database: treasury_development_flint`); ones with live DBs answer from the wrong data. `docker stop` the others while testing, `docker start` after. A dead scoring workflow does NOT auto-recover — re-trigger with `temporal.scoreMatchmakingBatch({ uploadId, documentId: upload.ingestDocumentId, actor })` via tsx (needs `configure(new Router())` from `src/lib/prophet` + `NODE_ENV=development`).
3. **Login**: browser login is OIDC via auth.angellist.dev (nginx → localhost:3333/3334) which is often not running → 502. Venture monolith (port 3001) + redis sessions still work: mint a session via venture `bin/rails runner` — `Rack::Session::SessionId.new(SecureRandom.hex(32))`, write `{ session_id, "warden.user.user.key" => User.serialize_into_session(user) }` as JSON to redis db 9 under `sid.private_id`, set cookie `_angellist_v2=<public_id>` domain `.angellist.dev`. venture@angellist.com is id 16773456, is_admin.
4. **Playwright**: use `createRequire('<repo>/nova-e2e/tests/package.json')` to borrow `@playwright/test` from scratch scripts; dialog action buttons need `.last()` (two "Commit"-labeled nodes). ADAPT/React-Aria table quirks (2026-09-02): row checkboxes are off-viewport inputs — `focus()` + `keyboard.press(' ')` toggles them (dispatchEvent/'click' does NOT update React-Aria state); `getByRole('checkbox')` finds nothing (inputs read as hidden); the header select-all is only reachable via `getByRole('checkbox', {name:/select all/i}).click({force:true})` and still lands on row 1 sometimes — prefer per-row keyboard toggles; row blades open via DOUBLE-click on a cell (`onRowAction`); the batch ComboBox is `getByRole('combobox')` then `getByRole('option')`; ADAPT `Row` is a list-item component, NOT a layout flexbox (use `Stack direction='horizontal'`); Menu triggers need real `.click()`, not dispatchEvent.
5. Worktree dev DB can be behind migrations with a FAILED migration blocking deploy (P3009) — fix the data (backfill NULL `distribution.entity_financial_account_id` from `entity_financial_account.entity_id = sender_entity_id`), `prisma migrate resolve --rolled-back 20260806065302_require_entity_financial_account_id_on_distributions`, then `migrate deploy`. Symptom before the fix: "table public.entity_matchmaking_upload does not exist" and the UI's "Couldn't load the batch list".
6. Treasury NATS flake persists per-row even with other worktree treasuries stopped: one seed run scored grace+marie fine and flaked alan, wallets all verified-correct in treasury (check with `docker exec treasury bin/rails runner`). A "no investment wallet" NEEDS_REVIEW row with a real wallet still commits — gather re-checks live at commit. Re-staging a content-tweaked CSV (e.g. change email casing — resolution is case-insensitive) is faster than re-triggering scoring.

Related: [[spawned-nova-worktree-is-bare]], [[matchmaking-pii-scoring-architecture]].

**Lighter path proven 2026-09-17 (PR #10240 copy screenshot) — you do NOT need the seed script, ipseity seeding, or treasury at all if you only need rows on screen.** Staging any well-formed CSV creates rows and they score to CONFLICT/NEEDS_REVIEW against whatever ipseity holds; the commit dialog opens regardless of row status. Whole path, ~20 min:
1. `just worktree-init` (infra-only, with the symlink from [[spawned-nova-worktree-is-bare]]), then `just dev up`.
2. **`worktree-init` does NOT migrate the dev DB.** It leaves the P3009 failed `20260806065302_require_entity_financial_account_id_on_distributions`. Symptom in the UI is "Couldn't load the batch list" — the matchmaking tables simply don't exist. Fix is step 5 of the recipe above (backfill, `migrate resolve --rolled-back`, `migrate deploy`), then restart graph + graph-worker via `curl -X POST localhost:$PC_PORT/process/restart/graph`.
3. Mint the session with a **script file**, not an inline `-e` string: `bin/rails runner /tmp/mint.rb` from the venture checkout. `User.find_by(email:'venture@angellist.com')` (id 16773456; the admin predicate is `is_admin?`, there is no `is_admin` attribute), `Rack::Session::SessionId.new(SecureRandom.hex(32))`, JSON `{session_id: sid.private_id, "warden.user.user.key" => User.serialize_into_session(u)}` into redis db 9 at `sid.private_id`, cookie = `sid.public_id`.
4. CSV header contract is `tin,legal_name,entity_type,owner_email,owner_user_id` (`app/.../EntityMigrationTab/csv.ts` `CSV_TEMPLATE`).
5. Right after staging the UI shows "The archived source file could not be read" and `0 rows` — that is DocumentService finalization lag, NOT an auth failure. The ingest retries and the graph-worker logs `Scored matchmaking chunk ... scored: 13`. Just reload.

**Playwright selectors that actually work (beyond the 2026-09-02 notes):**
- `getByRole('dialog')` is ambiguous — the whole Admin tools page is `role=dialog`. Always name it: `getByRole('dialog', { name: 'Stage a batch' })`.
- The `Actions` Menu.Button **auto-closes**: `await trigger.click()` then wait **~600ms max** before querying. A `waitForTimeout(1200)` finds zero `menuitem`s even though `aria-expanded` was true.
- Select-all-rows: iterate `input[type=checkbox]` from index 1, `focus()` + `keyboard.press(' ')` each.

**Screenshotting the review table's row ORDER (proven 2026-09-29, BANK-2121 / PR #10599).** The
committed `seedMatchmakingLocalDemo.ts` gives the right status mixture but writes the CSV in an order
that is *already* nearly triage order (1-3 AUTO, 4-9 NEEDS, 10-14 mostly CONFLICT), so the default view's
`#` column comes out almost sequential and demonstrates nothing. Build a **round-robin striped**,
**>25-row** CSV instead (`PAGE_SIZE = 25`, `RowsTable/index.tsx`).

**A random shuffle is not enough** — it leaves clumps, and Kevin rejected the first attempt because its
top seven rows happened to read AUTO, AUTO, NEEDS, NEEDS, NEEDS, NO_MATCH, NO_MATCH, so the file-order
screenshot still *looked* status-grouped even though it was correct. Cycle the statuses strictly instead
(`[AUTO, NEEDS, CONFLICT, NO_MATCH]`, dropping exhausted buckets) and assert **zero adjacent same-status
pairs** before staging. 10/10/10/5 over 35 rows renders file order as a clean green-yellow-red-grey
rainbow and triage order as four blocks, with page 1 ending *mid*-CONFLICT so load-more still crosses a
boundary. Repeating a CSV row verbatim scores identically —
no dedup and no "already claimed" interference; only the whole-file content hash is batch identity.

**Playwright, beyond the selector notes above:** drive `https://portal.angellist.dev` with
`ignoreHTTPSErrors: true` plus
`addCookies([{name:'_angellist_v2', domain:'.angellist.dev', secure:true, sameSite:'None'}])`.
Whole-row `textContent()` is unparseable — read order out of `page.locator('body').ariaSnapshot()`,
where each row is `- rowheader "N"` then `- gridcell "<entity>"` then `- gridcell "<status>"`. Sort state
lives on the `columnheader`'s `aria-sort` (`none`/`ascending`/`descending`) and is the cleanest assertion
for a sort toggle. Load-more is scroll-driven (`mouse.wheel`), not a button. The batch picker is the only
`combobox` on the page and its options read `"<name>In review · N rows"`. **`Delete batch…` opens a dialog
whose confirm button stays `disabled`** (an unidentified confirmation step) — rename a scratch batch in
SQL rather than trying to delete it.

A worktree that took the *default* nova ports (6682/4000/4020) is served by the bare
`portal.angellist.dev`; nginx's `map $nova_subdomain_suffix` only lists suffixed worktrees, so there is no
`portal-<name>` host for that one. Check `/etc/nginx/maps/nova-app-ports.map` in `deps-nginx-1` before
assuming a hostname.
