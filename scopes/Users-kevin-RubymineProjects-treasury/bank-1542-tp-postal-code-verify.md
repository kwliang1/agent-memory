---
name: bank-1542-tp-postal-code-verify
description: BANK-1542 verify TP no longer requires postal_code on counterparty creation — prod-console test script staged
metadata: 
  node_type: memory
  type: project
  originSessionId: a0793ba3-2a2e-44d1-8613-d02f2b12e0c4
  modified: 2026-08-17T23:59:59.193Z
---

BANK-1542 (Kevin's, Todo, Nova Foundations): Bisher flagged that Treasury Prime shipped a change so **zip is no longer required when creating a counterparty**. Verify empirically.

**Scope (non-obvious):** only **wire** counterparties ever carried an address/`postal_code` — `TreasuryPrime::ExternalWireAccounts::SetupService`, whose `truncate_bank_address`/`apply_address_defaults!` inject `'00000'` placeholders *because* TP required a zip. ACH counterparty body (`ExternalAchAccounts::SetupService`) sends no address at all, so the ticket only concerns the wire path. Confirming the removal lets us drop the `'00000'` placeholder logic.

**TP has NO delete-counterparty endpoint** (verified via docs `llms.txt` + Kevin's screenshot): Counterparty = List/GET, Create/POST, Fetch/GET:id, Update/PATCH:id only. The generic `ApiService.delete` is used solely for *webhooks* (`webhook_config_service.rb:147`), never counterparties — first draft wrongly added a DELETE cleanup; Kevin caught it. So any counterparty created PERSISTS in prod (inert: fake acct#, nothing references its cp_ id, no money can move; also consistent with our normal duplicate-counterparty creation).

**Approach shipped (2026-08-17):** prod-console script at `scratchpad/bank_1542_zip_test.rb` (also pasted in Discord thread). Calls `TreasuryPrime::ApiService.post(endpoint: 'counterparty', ...)` on the MAIN instance. Runs omitted-zip TEST first; only POSTs a with-zip CONTROL if the test is REJECTED → **at most ONE** counterparty ever created (name `BANK-1542 ZIP TEST DO NOT USE`, ABA `<routing-1 redacted>`, both address_on_account + bank_address zips omitted). Verdict CONFIRMED/NOT CONFIRMED/INCONCLUSIVE; prints created cp_ id(s). No DB writes, no money movement. Sandbox alt would avoid the orphan but prod console lacks sandbox creds.

**Caveat flagged to Kevin:** a REJECTED TP call increments STATSD `treasury.treasury_prime.api_error` + feeds the "[Banking] TP API Error Spike" monitor. Only the "zip still required" outcome produces blips (≤3, under threshold); the hoped ACCEPTED path fires nothing.

**RAN 2026-08-17 (v1, both-zips-omitted) — INCONCLUSIVE but informative:**
- TEST (both zips omitted) → REJECTED `{"error":"Missing required parameter: postal_code"}`.
- CONTROL (with zip) → REJECTED `{"error":"Missing required parameter: bank_name"}` — MY BUG: dropped `bank_name`, a top-level `wire` field the real SetupService sends (setup_service.rb:61). Control correctly caught the malformed body → INCONCLUSIVE.
- **Ruled out Kevin's two hypotheses:** endpoint is correct (error URI `api.treasuryprime.com/counterparty`); NOT a version issue — TP is flat single-version (`api_version:"1"`, no per-request version header in TP's model or our client).
- **Key doc nuance** (post_counterparty): bank `postal_code`, if omitted, is **backfilled from the routing-number record**; rejected only if no record on file. But the BENEFICIARY's own `address_on_account.postal_code` is NOT derivable → hard-required. Both-omitted tripped the beneficiary requirement, which is NOT the field we placeholder.

**Ruled out on our side (all 3):** endpoint correct; version N/A (flat api_version:"1"); **request shape matches TP's CURRENT documented body exactly** (`{name_on_account, wire:{account_number, routing_number, bank_name, address_on_account, bank_address}}`), and TP docs mark `postal_code` OPTIONAL in both address objects. So docs + TP's claim (Kevin: "TP claims they removed the requirement") say optional, yet v1 hard-rejected on postal_code → **contradiction points to TP account-side config, not our code**.

**v3 script (current, in scratchpad) — isolates each of the 2 zip fields** (address_on_account = payee's own zip, not TP-derivable; bank_address = bank zip, TP backfills from routing record). Omits each independently (control only if both reject), prints OMITTABLE/REQUIRED matrix, routing `<routing-1 redacted>`. Both OMITTABLE → TP claim holds, drop placeholder. Beneficiary REQUIRED → claim not live for our account; hand failing field+payload back to TP. **NOT yet run.**

**RESULT — v3 ran 2026-08-17 (routing <routing-1 redacted> Chase):**
- `bank_address.postal_code` → **OMITTABLE** (TP backfills from routing record). ACCEPTED, created `cp_11n873baayn5pc4` (persists, inert).
- `address_on_account.postal_code` (beneficiary) → **REQUIRED** — REJECTED "Missing required parameter: postal_code" even with bank zip present. TP can't derive payee zip.

**CONCLUSION — TP's "removed the requirement" is HALF-TRUE. Three `'00000'` sites in SetupService split:**
1. Beneficiary `apply_address_defaults!` (setup_service.rb:168, non-US only) → **MUST KEEP** (TP hard-requires beneficiary zip; '00000' is the only way to satisfy TP for postal-code-less countries).
2. Bank `truncate_bank_address:223` + intermediary `build_intermediary_party_body:146` → technically removable (TP backfills) **BUT only for banks TP has on file**; docs "if no record on file, rejected" = the exact Increase-enriched edge case the placeholder guards. Chase test doesn't clear that case.

**Recommendation given to Kevin: DON'T remove the placeholder.** Bogus '00000' on a bank address is harmless (bank keyed by routing/SWIFT, not zip); removing it only adds a fail-closed path for obscure banks, no evidence '00000' harms wires today. Defensible narrower option: drop bank/intermediary '00000' + guard to omit only when ABA record lacks zip, accepting reject for unknown banks — needs product/ops nod. Ticket effectively answerable/closable with this finding.

**SHIPPED 2026-08-17 → treasury PR #8571 (OPEN, signed+verified, CI running, NOT merged).** Branch `kevinliang/bank-1542`. Single-site change in `truncate_bank_address` (setup_service.rb:220): omit `bank_address.postal_code` when ABA record has none (TP backfills) instead of `.presence || '00000'`. Comment reworded (dropped stale "Increase-enriched" claim; real source = Fed ABA import — wire file has no zip, JPMorgan named mismatch). Metric `placeholder_used{field:postal_code}` still emitted. EXCLUDED intermediary '00000' (build_intermediary_party_body:146 — wire-SUBMISSION endpoint, untested by 1542) + beneficiary '00000' (apply_address_defaults!:168 — TP requires). Spec: 4 assertions '00000'→`not_to have_key(:postal_code)`, 22/22 green (Docker), sorbet clean. Diff 2 files +16/−13.

**Review gate (2 Opus, 1 round): both cleared, no blocking concerns.** Ops rec (add placeholder_used monitor) DECLINED as redundant — reject is a 4xx already paged by `ops/datadog/monitors/treasury-prime-api-4xx-spike.json` (fires on `treasury.treasury_prime.api_error{status:4xx}`, incremented api_service.rb:176). Fail-open→fail-closed only bites banks TP's routing DB doesn't know (near-empty; Fed-registered wire banks). Half-created main/manco split N/A (deterministic on body, main fails first).

**DONE — PR #8571 MERGED 2026-08-17 (by Kevin, after @dcetlin bare APPROVE, CI green).** Screenshot loop CLOSED: Bisher's screenshot was a **TP release note** — "Adding wire counterparties just got simpler. Zip code is no longer required, and city and state now auto-populate from the Federal Reserve routing number table **when available**." Confirms all our findings: it's WIRE (not ACH); the relaxed zip is the bank_address one backfilled from the Fed routing table; "when available" = the exact fail-closed edge (no record → reject); beneficiary zip never in TP's claim. Fully vindicated.
