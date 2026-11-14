---
name: mmf-interchange-integration
description: "Everything Interchange (treasury MMF 2nd provider): the APEX→Interchange pivot and API map, code gaps vs George's answers, reversal + dividend-reversal semantics, BANK-2597 onboarding, BANK-1669 stack, BANK-1678 probe, Schedule A fees, sandbox controls. One file by Kevin's call, 2026-11-05."
metadata: 
  node_type: memory
  type: project
  originSessionId: d1f0fdbf-2f0c-455a-9a67-6f1dfaacbc16
  modified: 2026-08-14T19:26:27.522Z
---

Consolidated 2026-11-05 from 8 files at Kevin's request. All new Interchange context goes in this file as a section, not a new memory file. Section names stand in for the old file names.

## Pivot and API map (2026-08)

2026-08-14: Pivoted treasury's 2nd-MMF-provider Linear project from **APEX Direct → Interchange** (Kevin's call). Project `caa76b33a989`, now "Money Market Funds — Interchange Integration" (BANK team). **No APEX code was ever built** — pure planning pivot; APEX issues kept as the requirements *reference*, re-pointed at Interchange. Supersedes canceled [[bank-1665-apex-mmf-discovery]] (APEX) AND the earlier-canceled BANK-1489 (MoneyMarketFund::Interchange) — Interchange is back in. Seam = BANK-1487 (`MoneyMarketFund::Adapters`, merged to main).

**Interchange API** (portal.interchange.com/docs/api-reference): o5/j5 (pentops) protobuf-generated, no OpenAPI, but a **public machine-readable j5 registry**: `https://o5.interchange.com/registry/v1/interxfi/program-api/latest/api.json` (no auth; ~1MB; `api.packages[].schemas` has every object/enum with field types and enum numbers, plus `stateEntities` with endpoints). Found 2026-11-08 in the portal bundle (`portal`→`o5` host rewrite). Codegen the Sorbet structs from it directly; no need to ask Interchange or to go via the docs Markdown. CQRS `/c`(command)+`/q`(query), event-sourced state machines, id62 ids, decimal-string money. Base `sandbox.api.interchange.com`. Auth = `clientId`/`clientSecret`→JWT (`POST /ixm/auth/v1/api_auth/q/token`) — much simpler than APEX's JWS→JWT→x-api-key. Services: `ixc.{registration,orders,funding,portfolio,sweeps,assets,costbasis}`, `ixf.{documents,hours}`, `ixm.{auth,events}`.

**Two MMF execution models, BOTH route to JPMAM:**
- **Explicit orders** — `ixc.orders.v1` `POST /order/c` with `routeMoneyMarket` event (→ "money market fund provider, currently JPMAM"). Fills as Portfolio `TradeTransaction`s. Maps 1:1 onto treasury's order-shaped ledger (`MMF_BUY`/`MMF_SELL`).
- **Auto-sweep** — enroll at account create via `controls.sweeps.settings.{canSweepAccount, sweepPlanId}` (registration `POST /account/c`, `controls` Required, `marginType:CASH`). `ixc.sweeps.v1` is **READ-ONLY** (SweepTarget/Plan/cutoff) — plans are **Interchange-provisioned, we select not author**. Read results in `ixc.portfolio.v1` (`sweptBalance`, Sweep Balance, `Performance.portfolioValue`=NLV, `unrealizedDividends source=SWEEP`=yield). Yield rate = `assets money_market_stats.sevenDayYield`.

**DECISION (Kevin): persist BOTH tracks as Backlog, distinct milestones, sweep-first leaning.** Sweep is lighter (enroll is a field not a subsystem; no order lifecycle) but NOT "half" — closer than that. **FREC already proves the seam handles a deposit-driven / provider-invests / treasury-records-legs (=sweep) shape**, so sweep records purchase/redemption activities as the same `MMF_BUY`/`MMF_SELL` legs (existing derivation + zero-tolerance divergence check hold). Explicit orders ≈ **~3 issues** (execute_buy! is net-new — FREC buy is a wire; + $↔shares/NAV + fill→ledger recon), NOT the 1-2 I over-claimed nor the 5-6 APEX baggage.

**Adversarial review (3 agents, Kevin-mandated before persisting) findings folded in:**
- Seam is order-shaped by method names but FREC-precedent makes it sweep-capable (Kevin corrected my "not sweep-ready").
- **De-Frec 2 leaks** — `yield_service.rb:27` + `statements/fetch_service.rb:19` call `Frec::Client` directly, break for ANY 2nd provider → Foundations line.
- **Forced-liquidation** isn't a margin risk on a CASH account (Kevin right); real vector = negative cash via Instant-Deposit **advance reversal** / returned deposit / fees → P0 guard (disable `canUseAdvance`, buffer, fee-routing), not a blocker.

**6 open gates live on M1 spike (go/no-go before build):** (1) confirm JPMAM SweepPlan provisioned + its `sweepPlanId` (Kevin: likely done); (2) sweep emits discrete purchase/redemption activities to ledger as buy/sell legs; (3) negative-cash behavior; (4) event retention/replay/ordering (`ixm.events.v1`, not in reference); (5) JWT TTL/rate limits (auth silent); (6) order fill/settlement timing + NAV.

**Milestones (all Backlog):** M1 Sandbox Spike & Gate Resolution · M2 Foundations (auth/client/config + de-Frec + generalize seam) · Sweep Track (1 milestone) · Explicit-Order Track (2 milestones = the visual "more surface" tradeoff) · Productionization · **Post-launch checklist** (new).
**Issues:** 24 reframed APEX→Interchange (BANK-1669–1693 range, + BANK-1769 umbrella). 9 `[QA]` todos under Post-launch (BANK-1794–1802). **21 sub-issues (BANK-1803–1823)** break 7 bundled parents into per-shippable-PR children (Kevin: "size per shippable PR, not per bullet"): 1671 seam→5, 1670 config→3, 1675 pipeline→2, 1672 onboarding→2, 1681 provisioning→3, 1680 orders→3, 1674 funding→3. Left 1679 (client) + 1673/1687 (balances+yield) whole.
**Event story restructured:** BANK-1675 = the COMMON event pipeline (webhook Target + poll consumer, dedupe/DLQ/replay) in M2 Foundations; per-track recon on top = BANK-1689 (sweep) + BANK-1683 (orders), both blockedBy 1675.
**Case matrix in TWO places:** (1) canonical Linear DOC (markdown, AI-readable — Kevin wanted this for future AI sessions): https://linear.app/angellist/document/interchange-mmf-qa-case-matrix-ac16496b4522 — the 9 QA issues + Post-launch milestone link THIS, not the artifact; (2) interactive artifact (60 cases, filter by track/priority, house style): https://claude.ai/code/artifact/3e2dda5a-82a0-4453-9078-1a75ba475153.
Kevin trim prefs (applied this review pass): project desc = links to portal + specific API pages, not a dense endpoint dump; "seam merged" → one line "background already done, MMF re-architecture"; Out-of-scope = only Frontend/GraphQL + FREC decommission (Venture/Comptroller Prophet contract is provider-agnostic = ~1:1 w/ FREC, dropped). `frec_*` cols remaining = 4 leaf ids (frec_account_id, frec_deposit_id, frec_liquidation_id, frec_yield_event_id); generic provider_order_id/provider_reconciliation_id already exist unused → Interchange uses those, no rename.

Linear MCP quirk: save_project/save_milestone/save_issue responses sometimes echo STALE content or time out but the write lands — verify with get_*/list_*. save_project `summary` capped 255 chars.

**Interchange docs MCP (2026-08-14, set up by atlas):** installed 2 global skills at `~/.claude/skills/` — `interchange-auth` (mints JWT from creds via `mcp-headers.sh`, POST /ixm/auth/v1/api_auth/q/token; skill text says "1h" but **docs say TTL = 12h** — trust 12h) + `interchange-mcp-setup` (registers the server). MCP `interchange` registered at USER scope in `~/.claude/.claude.json`: url `https://sandbox.api.interchange.com/mcp/`, headersHelper `sh ~/.claude/skills/interchange-auth/mcp-headers.sh`. Tools: docs_overview/docs_search/docs_fetch (search/read Interchange dev docs). **CONNECTED 2026-08-14** — Kevin created the API key + `~/.interchange/credentials` (BASE=https://sandbox.api.interchange.com + INTERCHANGE_CLIENT_ID/SECRET, chmod 600); `claude mcp get interchange` = ✔ Connected. Tools appear in a FRESH session (`/mcp`). GOTCHA: zsh interactive doesn't strip `#` comments → don't paste the token-test command with a trailing `# comment` (it becomes the zone arg → "cannot reach #"). If it ever 403s "Dynamic Client Registration rejected" again, that's the no-creds/expired-creds fallback — check `~/.interchange/credentials` + re-run `sh ~/.claude/skills/interchange-auth/mcp-headers.sh`. Skills zip source = Google Drive file 17NOEpeapu7p7hJWFjeWOHMkVuM8Ho4u8 (private Drive file → download needs authed browser, not curl). Setup doc = gdoc 1oSFAYjcJn6QNuE6ASRrvI7Q7sJrSo2U4CVjbV4EuhiQ.

**DOCS-MCP VALIDATION PASS (qubit, 2026-08-14) — higher fidelity than the earlier browser verify. Every API claim held; gate corrections below. APPLIED to Linear 2026-08-14 (project description + M1 milestone `516baeb7` + 6 issues BANK-1669/1678/1679/1682/1688/1689, per Kevin's "add these"/"push the updates"). Only issues containing stale/correctable claims were touched (grep for canUseAdvance/undocumented/OpenAPI); BANK-1689 already had the YIELD leg + was enriched. Other issues left as-is.**
- **Golden doc = `guide:treasury`** ("Open org accounts with cash sweeps... auto-sweep settled cash into MMFs") — Interchange's own writeup of our sweep design. Browser pass missed it.
- CONFIRMED verbatim: `routeMoneyMarket` OrderEventType ("...money market fund provider (currently JPMAM)"); MMF fills = TradeTransaction counterparty=MONEY_MARKET; sweep enroll = `controls.sweeps.settings.canSweepAccount`(+optional sweepPlanId), marginType CASH, guide states "There is no enrollment API call"; performance→portfolioValue(NLV)+unrealizedDividends.byAsset source=SWEEP; yield rate = `MoneyMarketStatsData.sevenDayYield` (GET /ixc/assets/v1/money_market_stats/q/:assetId/:date); sweeps.v1 read-only (query svcs only, plans Interchange-provisioned). FundFamily enum = ONLY JPMAM.
- **Gate 3 RESOLVED + refined**: sweep emits discrete Transactions — TransactionDetail polymorph incl `ixc.sweeps.clearing.v1.SweepsTransaction`; legs derive from SweepBalance Transaction{Slated,Settled,Posted} signed `amount`. **GAP: dividends are a 3rd leg** (`DividendPaymentTransaction`, pay 1st biz day next month) — our mapping only names buy/sell, needs an income leg.
- **Gate 4 has a WRONG detail**: Instant-Deposit advance IS real (portfolio `deposit_advance` entity; CashBalance advanceGranted/Settled/**Reversed**→"availableToTrade decreases" = exact negative-cash vector). BUT **no `canUseAdvance` account control exists in docs** (FREC carryover). Real levers: `AccountConfig.skipCreditCheck=false` (blocks negative holds), handle Returned/advanceReversed, cash buffer. Ask Interchange if Instant Deposit is disable-able per-program.
- **Gate 5 mostly RESOLVED**: JWT TTL=12h; rate limit=429/credential; events at-least-once, dedupe by event.id, order by per-entity `sequence` (NOT timestamp), push retried ≥5×, pull `since` inclusive, pages ≤20. Only retention WINDOW still unspecified.
- **NEW (not in project)**: explicit-order track REJECTS floating-NAV MMFs (OrderRejectionCode SYMBOL_NOT_SUPPORTED "e.g. floating-NAV money market funds"; assets navType FLOATING/STABLE). JPMAM govt=STABLE ok. Sweep track unaffected. Also: docs MCP renders full proto schema (id62/decimal/oneofs) → "no OpenAPI/blind on contract" risk reduced, still want .proto for codegen.

2026-10-13 (prism): Kevin paused #9083 to review the adapter abstraction; wants buy/sell before account creation; Frec is already sweep-modeled (no execute_buy!; buy = TP wire, completion via fetch_deposits). Leak: OrderService parses Frec JSON from fetch_deposits/fetch_liquidation + hardcodes PaymentProcessor::Frec; provider_order_id columns exist unused. Interface doc: claude.ai/code/artifact/da978912-1981-471e-aafb-7ca9e92f84ce. Sandbox 10/13: account-number create still 400 → buy = achPull only; $1,000 pull 034FrJV2nfvSlPnZA2fYbu on 034BpTJEIHbujd3eMOokAB SUCCESS; pending test = achPush $400 from swept cash after 10/14 20:30Z cutoff (poller wait_sweep.sh in session 00f50f7d scratchpad).
2026-10-13 later: Kevin sent Interchange outreach (#interchange-angellist C0C11Q9BHSM p1791932733493559); Interchange enabled account numbers for ANGL same day. Account number 034FsPzufiVWgzKBIkKHUr on sweep acct; banksim inbound-wire (needs id62 wireId + accountId + accountNumberId) → incomingTransfer SUCCESS, settled instantly, memo NOT on the transfer (match by acct number + amount). Wire push still off (Program Config). $50k ACH cap gone ($60k pull OK). Sandbox map v8 = ranked+reverified questions. Interface doc switched to wire-in buy, ACH pull fallback.

## Current code vs George's answers

Re-verified against treasury `origin/main`, Linear and the Slack thread on 2026-11-03. `adapter` means `app/services/money_market_fund/adapters/interchange.rb`. The line numbers move, so grep for the symbol.

George's answers are in Slack C0C11Q9BHSM, thread 1791932733.493559. The per-question write-up is arti `interchange-sandbox-map` v9, but **its #1 and #6 rows are stale**; use the thread instead. Migration and blocker planning are in § BANK-2597 onboarding (Frec to Interchange). Don't duplicate them here.

**Gaps that are still open in code**
- **No wire-in destination.** `create_sub_account!` raises `NotImplementedError`, and onboarding gives the fund only `display_id` as a wire memo. Sandbox inbound wires need an `account_number_id`. Fix: BANK-2298, now in Todo, which blocks BANK-2000 and BANK-2594.
- **Buys match on amount alone** (`matching_incoming_transfer`), so two equal buys on one account can be swapped. Per-account numbers fix this. George never answered our 10-13 request for IMAD or the originator memo on `incomingTransfer`.
- **Consent is faked.** `lib/interchange/api/registration.rb` sends `customerConsent: true` dated the application date. George #9 says it attests that an authorized signer e-signed a Compliance-approved agreement version that we retain. No signing flow exists, and no owner has been named.
- **CIP timestamp is wrong.** The adapter submits minimal evidence with `Time.current`. George's follow-up says to use the timestamp of the vendor's check and keep the document evidence on our side. No reference ID is needed in minimal evidence, so the "where does Alloy's ref ID go" question is moot.
- **Required fields are missing.** George's recipe requires `investmentProfile` on the individual, `w9.foreignOwners` on the org, and `risk` plus `usEquities.canPlaceOpening/Closing: false` on the account. None of these appear in `lib/interchange` or the adapter. It's unverified whether sandbox rejects a request without them.
- **`INTERCHANGE_SWEEP_PLAN_ID` is `"TODO"`** in prod and sandbox `config.yaml`. Staging has the Interchange-sandbox OGSXX id `033Z9key7TFK5je2cuYM03`. OGSXX is the program default (#12), but the prod id must come from Interchange.
- **`country_of_citizenship: 'US'` is hard-coded**, and the adapter refuses non-US signers. That blocks the interim path below.

**Superseded since 2026-10-15**
- **#1, foreign signers.** Bisher pushed back. George is scoping foreign IDs for control persons of US-registered entities. Interim path agreed in the thread:
  - send a placeholder `taxIdentifier` of all zeroes, incremented per person because dupes are rejected;
  - set the real `countryOfCitizenship`;
  - use the entity address as `physicalAddress`;
  - omit `w9`.
  
  Kevin told George that wave 1 is UK only (Cocoa VC Fund II and Elevata Ventures Fund I). One trust grantor who owns 38% of a fund has no country on file yet.
- **Non-US census.** On 10-15, prod showed 3 applications flagged non-US: app 19 (Federacy2, CA, a test account per Kevin), app 31 (Cocoa) and app 43 (Elevata). App 2 has a blank flag and predates the field. That flag is self-attested, so the census in BANK-2597 is authoritative.

**Settled, no action**
- #3: production credits ACH the morning after settlement. We never originate ACH pulls and ACH withdrawals are blocked, so only a returned inbound ACH credit can drive cash negative.
- #4: see § Schedule A fees.
- #5: no explicit orders; sells are a wire push.
- #11: accounts open on submit. This contradicts the 10-06 "clearingManualApproval" note in § BANK-1678 sandbox probe; the adapter waits for OPEN either way.

Related: this file · [[fund-beneficial-owners-not-majorshareholder]] (BANK-2297, Todo)

## Reversals and dividend reversals

Observed 2026-11-03 on sandbox account 034BpTJEIHbujd3eMOokAB (TransactionList, pageSize max 20): ACH pull returns appear as new FundingTransactions with `accountDeltas[].isReverse: true` and a negative delta, but NO `reverses`/`reversedBy` field; the original stays `SETTLED` (TransactionStatus enum has no REVERSED despite docs mentioning it). `detail.amount` on the reversal is positive ("500") while the delta is -500.

**Why:** BANK-1689's portfolio.rb detected reversals only via reverses/reversedBy and read detail.amount — a delta-flagged dividend reversal would book as a second positive yield.
**How to apply:** derive Interchange amounts from signed cash deltas (net of isReverse), never from detail.amount or link fields. No dividend reversal had been observed as of this date. See [[bank-1689-interchange-yield]].

**Dividend reversals, per George (Slack C0C11Q9BHSM, thread 1793727003.714689, 2026-11-05):** sweep dividends aren't reversed once paid. In the rare case one is, Interchange reverses it in full and posts the corrected amount as a new dividend. Merged BANK-1689 already handles that: the signed-delta sum sends a negative to the clawback alert, and the correction books as normal yield. He didn't say which `detail.!type` a reversal carries. We read only `DividendPaymentTransaction`, so another type would be missed silently. Kevin decided (11-05) that this needs no code change and no follow-up, because the MMF balance check flags the drift. He also said not to hard-code the sandbox ACH return shape yet.

## BANK-2597 onboarding (Frec to Interchange)

**Status as of 2026-11-03: design and data only, no code.** Branch wt/fern was clean. Check Linear BANK-2597 and the docs for anything newer.

**Docs**
- Meeting doc, the source of truth for the meeting with Bisher Anadani (Slack U097W03972T): https://claude.ai/artifact/MM58LdQVpv9LhaGPSY8uuz (Claude Docs a4c43110-ad5e-42ca-ad82-1b3c344f73f9). It holds the migration plan, the 9 compliance questions, the findings, and a filterable tracker of all 50 MMF accounts.
- Parent sourcing-plan doc: https://claude.ai/artifact/UqcfR8tsZFgcy3YT67v3Zm (e1706c27-c8e8-41d8-98bc-88fce29ee47c).
- George's answers to the questions live in Slack C0C11Q9BHSM, thread 1791932733.493559:
  - #1: no foreign TIN.
  - #5: no explicit MMF orders. Interchange auto-sweeps into OGSXX.
  - #7: any officer with management or signing authority can be the control person.
  - #8: beneficial owners are required, with no exemption initially.
  - #13: revocable trust account types are in progress.
- After the meeting, post the Granola link and takeaways in #proj-mmf-interchange-integration (C0BESGMTQ64).

**Nov 4 meeting with Bisher (supersedes the earlier "support both" fallback in treasury)**
- Control person: ipseity control person, else fund lead, else error. **Venture resolves it**, and treasury does no fallback. The ControlPerson backfill is dropped.
- Contract: the caller passes ipseity ids (owning entity, control person), or a raw payload when no entity exists. Treasury stops reading the CCA through the IVC. It validates the application and returns missing fields, and standalone banking shows them. Venture owns the "no control person or fund lead" error. ipseity dedupes, so no new entities are created.
- Beneficial owners are **in discussion**. Kevin's wording: "we intend to not pass them for now". Bisher is confirming with Interchange, which conflicts with George #8. If none are on file, send none. A trust's person is its trustee.
- Non-US GPs: individual profiles using George's no-SSN workaround.
- Who migrates: bona fide full-service customers and long-standing standalone customers, even with $0 (J-Ventures, Texas II, Pack). Not the self-serve applications that never became customers: DWS Holdings, Bostwick Compound, Aj turner, Lindacarducci.
- New scope:
  - close pending applications and inactive self-serve accounts;
  - turn off self-serve MMF onboarding in standalone banking (route it to "contact us").
- Open with Interchange: a KYC-provider enum value (Kevin), and IMAD on inbound wires (Bisher).

**Kevin's decisions**
- Superseded Nov 4 (see above): ~~treasury falls back from the venture control person, to the ipseity ControlPerson, to the ipseity fund lead~~.
- Order-level Linear issues are canceled per George #5: BANK-1680, 1818, 1820, 1683, 2240 and 1801.
- Issues to pick up next:
  - BANK-1803: sell over ACH or wire (PR #9176).
  - BANK-1689: reconcile sweeps.
  - BANK-1687: balances.
  - BANK-1688: negative-cash guard.
  - BANK-2291: credential scope.

**Dropped Nov 4 (venture resolves the control person): Kevin had proposed backfilling ipseity ControlPerson from the fund lead.**
- A backfill alone isn't enough. Venture would also need to forward-write the role for new funds.
- It reverses "support both".
- It has side effects in treasury:
  - bank_eligibility/entity_info_service.rb:36-42. Increase stops verifying the fund lead separately once the fund lead is a control person.
  - watchlist_checks_service.rb:27.
  - treasury_prime/account_applications/create_service.rb:75.

**Facts that are easy to get wrong**
- The fund lead is an FSFM-only concept. `resolve_fund_lead` returns nothing for STANDALONE_BANKING accounts. Standalone accounts use an ipseity control person instead.
- Of the 50 MMF accounts:
  - 21 are FSFM.
  - 27 are standalone. 4 of those are in Comptroller under a different entity id.
  - 1 is Nova (Aito).
  - 1 is AngelList but not in Comptroller (Avlok Kohli).
- "15 ready if no owners" means 14 standalone accounts plus Aito.
- 19 accounts have MMF activity. Tenacity Affiliate's buys exist only as ledger entries. 30 accounts have no MMF activity, which is not yet verified against Frec.
- None of the 21 Comptroller funds has an individual 25%+ owner. Their 25%+ owners are trusts (MBA VC III, Carbon Silicon) and companies (Karman, M31, Avlok E4).
- A beneficial owner's profileId is not restricted to individual profiles by the schema. Interchange's EntityType has no TRUST value.

**Unlock plan, by blocker (funded total $19.05M)** — merged into the meeting doc's Migration plan table (wave + funded $) on 2026-11-03
1. **Ready now: 7 funds, $8.42M.** Needs the fund-lead fallback or the backfill, plus `INTERCHANGE_SWEEP_PLAN_ID` set in prod (it is unset).
2. **Missing fund address: $7.28M.** FDVC II, J-Ventures III-A, Essence IV, and Texas II ($0). This is an ops data fix in ipseity. Batch it with:
   - the invalid ZIP on M31;
   - W-9 re-certification for Pack QP (payee code "None"), Avlok E4 and ZERORENDER.
3. **Fund lead is in GB with no SSN: $2.25M.** Cocoa II and Elevata I. Ask each GP for a US officer to act as control person (George #7). Otherwise the fund stays on Frec.
4. **Entity owners: $1.10M plus small balances.** Looking through to individuals:
   - Karman: a person needs about 89% of Expa-MC to reach 25%.
   - M31: a person needs about 91% of GL-Regal Pine.
   - Avlok E4: a person needs about 52% of the Canadian company.
   
   The question for Bisher is whether "no individual at 25%+" satisfies George #8. MBA VC III (irrevocable trust, trustee Joanne Poon) and Carbon Silicon (revocable trust) depend on whether a beneficial owner can be the trust's own profile.

**Other open items**
- Venture-to-treasury transport and PII handling are undecided.
- Who fills in owner citizenship is undecided. It is blank in ipseity, and the adapter hard-codes 'US'.
- Verify the 30 no-activity accounts against Frec. This needs Kevin's go-ahead.

**Scripts** are read-only and run on a prod console with `al console create -a treasury -e prod --no-attach`. Always run `al console delete` afterwards. They are in `bank2597-scripts/` beside this file:
- mmf_cleanup_census.rb: the current census; it replaced the older gap, fund-lead, activity and name scripts.
- mmf_addresses.rb: address data for the census.
- mmf_frec_equity.rb, mmf_frec_last_check.rb: read-only Frec checks, for verifying the no-activity accounts.

Related: this file · [[fund-beneficial-owners-not-majorshareholder]] · § BANK-1669 client stack

## Migration tracker of record (BANK-2597)

Since 2026-11-10 the tracker of record is the Arti app https://arti.internal.angellist.com/app/mmf-migration-tracker. It holds the 50 MMF accounts, with a status filter and a skip toggle, and stores per-row Status edits in the shared Arti map `mmf-migration-tracker-status`. The "MMF account tracker" table in the Claude Doc plan (https://claude.ai/artifact/MM58LdQVpv9LhaGPSY8uuz) is a stale copy: update rows through the Arti map, not the doc. Related: BANK-2807 (Belltower address for in-house funds), BANK-2808 (attest org CIP for in-house FBO funds).

## BANK-1669 client stack

PR #9068 (`kevinliang/bank-1669`, `lib/interchange/auth.rb`) opened 2026-10-07 after 11 review rounds (clean 10+11). Kevin said **pause after 1669** — do not start BANK-1679 until he says so.

Contract 1679 builds on (all verified live on sandbox):
- Token TTL is 3600s on sandbox (docs say 12h); expiry read from JWT `exp`, refresh 5 min early. `whoami` claim `tenantType: program`, `tenantId` = programId `031pQ8iMdPhiS0Iisn8Ie0`.
- No retry inside Auth (deliberate: never hold the mutex across a sleep). Callers own backoff.
- A failed fetch is remembered 30s: serve still-valid token, else re-raise without a request. Never serves a token at/past exp.
- `invalidate!(rejected_authorization_header)` clears only if it matches the current token; bare `invalidate!` clears unconditionally (spec reset).
- 2026-10-07 stress test (Kevin asked) OVERTURNED 3 of my 6 dismissals; I had declined them on false/unchecked claims ("skew breaks TLS first" is false; "~100ms" was unmeasured). Now: any decode failure wraps to Error and backs off; a token issued inside the margin backs off 30s (`@backoff`, renamed from @failure); an already-expired one is refused; whoami actor/claim guarded. URI config errors escape unwrapped on purpose.
- 2026-10-07 Kevin: env config goes in BANK-1692; 1679 UNPAUSED as a local unpushed draft stacked on 1669 to judge ergonomics; possible slim of 1669 to `Interchange::TokenProvider` (JPM AccessTokenProvider precedent) decided after the draft.
- 1679 TODO from review: if minting works but every call 401s, invalidate-and-retry mints per call — rate-limit that in the client.

Worktree gotcha hit here: host has no `lsof`, so the Makefile port scan always picks 7021 (taken); write a free port to `.worktree-port` by hand. The atlas container also dies on boot (`next: command not found`, no node_modules) — run specs host-side per [[treasury-worktree-spec-env-quotes-and-rustfs]] with `RUSTFS_ENDPOINT=http://127.0.0.1:9000` (treasury-rustfs-1 publishes 9000; there is no minio container now). Related: this file, § BANK-1678 sandbox probe.

2026-10-07 1679 draft: local commit af76bdfdd on `kevinliang/bank-1679` (stacked on 1669, NOT pushed, no PR, gate not run). `lib/interchange/client.rb` (query!/command!, queries retry 429/5xx/timeouts, commands retry only 429, 401 → invalidate!+retry once with a 30s forced-refresh cooldown) + `lib/interchange/sweeps.rb` (typed cutoff/plans). Smoked green on sandbox. Verified API facts: GET object params (`page`, `query`) are JSON-string query params (dotted keys 400); filter shape `{field:{name:,type:{value:}}}`; protojson omits zero fields (`lastSequence` absent on never-updated entities). Recommended to Kevin: slim Auth to TokenProvider, move cooldown into the provider's invalidate!, move whoami/connection/error into Client.

2026-10-07 Kevin said "yes" to the slim: #9068 re-cut and PUSHED as `Interchange::TokenProvider` (2d5f19570; gate rounds 17-19, clean 18+19 with 2 declined nits logged in review-findings). `invalidate!(rejected)` now backs off 30s if the rejected token was fetched <30s ago (no client-side cooldown state). Shared `Interchange::Error` in lib/interchange/error.rb. whoami/`verify_program_scope!`/PROGRAM_ID moved to 1679 `Interchange::Client` (BANK-1669 ticket text still lists whoami). 1679 rebuilt locally at 2a3eec3a5 (unpushed, no PR, gate not run), 55 specs green, sandbox smoke green.

2026-10-07 later: config PR #9073 (BANK-1809, staging sandbox creds encrypted; prod/poseidon "TODO" pending BANK-1692; readonly ""; no creds in committed .devcontainer/.env). 1679 PR #9076 OPEN, stacked on #9068, after 8 gate rounds (clean 7+8). 1679 also refactors 1669 files: `Interchange::Http` (connection/timeouts/error_for/transport_error), `status` on `Interchange::Error`, `Client.query` (no bang) / `command!`. Declined (logged): URI::Error unwrapped on bad base URL; AmbiguousCommandError deferred to BANK-1818/1819; 0% percentage omission. WebMock `to_timeout` = connect timeout (ConnectionFailed); use `to_raise(Net::ReadTimeout)` for Faraday::TimeoutError.

2026-10-07 restack (Kevin: clean per-PR diffs, sweeps out of #9076): local, UNPUSHED, awaiting Kevin's gate call. 1669 `23bec0d01` (+Http, Error#status), 1679 `e2a9e1d10` (Client only, no id62!), new `kevinliang/bank-1686` `e3c639195` (Sweeps + id62!, gt-tracked on 1679; ticket fit unconfirmed). Top tree == gated `0a2a4ec`. Specs 34/68/83 green.
PUSHED 2026-10-07 after Kevin chose "one gate round per PR": #9068 597668f92 (clean r21), #9076 a4b370c12 (clean r18; added non-numeric Retry-After spec + PROGRAM_ID.present? fail-closed), new #9081 `kevinliang/bank-1686` 52bf444ce (Sweeps + id62!, base bank-1679). Declined + surfaced to Kevin: central absolute/.. path guard in Client#perform! (awaiting his call on follow-up). Bodies updated.

2026-10-07: BANK-1808 (enum + factory arm + NotImplementedError skeleton `Adapters::Interchange`) → PR #9083 off MAIN (Kevin chose main over stacking on #9076; skeleton needs no Client). Gate clean r1+r2; declined trio stubs (BANK-1805 owns) + PROVIDER_FEES (BANK-1810). Merge-order: #9046/#9066/#9069 add Base abstracts → whichever lands second stubs Interchange. Worktree prism test DB: TREASURY_DB_SUFFIX=_prism; RUSTFS creds now come from .devcontainer/.env (minioadmin override breaks it — rustfs-1 publishes 9000).

2026-10-08: Kevin approved review (dcetlin) on #9076 -> BANK-2242 (metrics/logs + MMF section on banking dashboard); reply posted. #9081 ON HOLD (Kevin): enrollment needs no cutoff/plans (no enrollment API; canSweepAccount at create, default plan). Body corrected.

2026-10-10: Kevin found #9083 too barebones → expanded to full account-creation chain (control person profile → org profile → sweep CASH account) via create_provider_account!/poll_application_state! + lib/interchange/registration.rb. Pushed 707502888 at Kevin's "push it" after 9 gate rounds (bypassed; last round's schema reviewer had 2 open items: presence checks on required strings, USState closed list). Sandbox facts: idempotent create with client id62 returns STALE snapshot (find-then-create); profiles deduped per SSN/EIN (409); our sandbox program currently attaches NO profile checks; account checks are clearing-only; account create needs sameDayAch. Open Kevin decisions: compliance on minimal CIP attest/consent/timestamp; re-application needs UpdateProfile; secret_key_base rotation strands HMAC person ids.

2026-10-10 prod read (BANK-1808): 49 MMF apps, 3 non-US signers (#19 CA pending, #31 GB active = CA 393632 Cocoa VC LP, #43 GB active), all US-formed/US-address entities → Interchange US-address rule OK, our citizen-only gate too strict. 19/48 live apps' entities return ZERO ipseity control_persons (all FBO) → adapter's owner_control_persons.first source fails for ~40%; fund-lead via FundLeadResolution (Venture callback) errors from read console — unverified. Proposed to Kevin: relax gate to US address + SSN/ITIN; switch person source to fund lead w/ fallback. Arti interchange-sandbox-map v5 has the new provider questions. Plan doc: claude.ai/artifact/FTK7sG5E4yQovy6VoWhCmP.

## BANK-1678 sandbox probe

2026-10-05 read-only probe of sandbox.api.interchange.com (creds in ~/.interchange/credentials work; program ANGL `031pQ8iMdPhiS0Iisn8Ie0`). Extends this file.

- Sweep plans (all ACTIVE, JPMAM, 100% single fund): OGSXX govt `033Z9key7TFK5je2cuYM03`, IJTXX `031Q1Tmrcs2vkealeiRIL3`, test `033Vf5K0LNKUsjJPpghnAF`. Program default NOT discoverable via API.
- Program created-event showed no ORGANIZATION — STALE: 2026-10-06 an ORGANIZATION (LLC_PARTNERSHIP) account create succeeded with OGSXX sweepPlanId. Acct `034BpTJEIHbujd3eMOokAB` stuck PENDING on `clearingManualApproval` — clearing-tenant-only evidence; Interchange must approve. Account APPROVED by Interchange 2026-10-07. API `clearingControls.instantDeposit.canUseAdvance: true` is only the clearing ceiling — portal Controls shows Allow Advances OFF via Program Config (effective). Advance-reversal risk is moot; I wrongly called it live before checking the portal. EntityType enum has no TRUST.
- JWT TTL is 1h on sandbox, docs claim 12h — refresh off `exp`.
- Events poll: live path `/events/v1/receive` (documented `/ixm/events/v1/receive` 404s); nextToken never null at head — stop on empty page; history back to 2025-12-10.
- Harness: scratchpad `probe.sh` / `pull_events.rb` (GET-only, never prints token).

**Why:** gates 2/3/6 blocked on Interchange approving the org account; was pending Kevin's call on asking Interchange vs trying an ORGANIZATION account create.
**How to apply:** harness `ix.rb` + step*.rb in pulse-2 scratchpad; check account status before resuming funding/sweep steps.

2026-10-07 gate 2 run: source `034Bv4YFUUJNhNYMCs5jBU`, $1,000 ACH pull `034Bv4Z3vnarxv113lwhlo` → SUCCESS in ~1s and credited as SETTLED cash immediately (Transaction settleDate 10-06) though transfer estimatedSettleDate = 10-08; no deposit advance. Return-after-sweep is the live gate-3 vector — ask Interchange if prod does the same. Banksim (`/exc/banksim/v1/sandbox/{settle,return,reject,reverse}/:transferId`, inbound-wire, inbound-ach-push) drives outcomes. Sweep expected at 4:30pm ET cutoff; poller `wait_sweep.rb`. Kevin has NOT yet approved the banksim Return test.

2026-10-07 later: return-before-sweep clean (new Transaction, same fundingId, isReverse:true). Billing 412 "no billing account for program". Account-number create 400 "not enabled by clearing controls". 2nd org acct `034Bvodjm734e6pNMjj4qj` (orders on, sweeps off) AUTO-approved. MMF order 403 "restricted to clearing users" → explicit-order track BLOCKED. Arti doc `interchange-sandbox-map` v3 is canonical; Kevin moved BANK-1679 to another session but wants remaining gates resolved here. Kevin OK'd sandbox banksim tests.

2026-10-07 AM: NEGATIVE CASH CONFIRMED on orders acct: pull $500 (034BSpv4eSVgdVwBIGXqIe) SUCCESS instantly → ACH push $1,500 (034BSpABt0OsBNIGsFGp51) SUCCESS instantly (withdrew unsettled ACH funds) → banksim return of pull → settled cash −$500, no hold. Treasury must guard (don't forward pulled cash before ACH return window). No API/banksim sweep trigger; portal session expired (don't log in for Kevin).

2026-10-07 17:20Z: Interchange manually triggered sweep (Kevin asked them). GATE 2 RESOLVED: one Transaction, deltas cash −1000 / OGSXX +1000 (sweepAsset:true), detail `ixc.sweeps.clearing.v1.SweepsTransaction` orderType PURCHASE fillPrice 1 adapterOrderId confirmTime. sweptBalance counts toward availableToWithdraw. Return of swept pull → cash −1000, swept 1000 untouched, availableToWithdraw 0 (no auto-redeem). Poller `wait_redeem.rb` watching whether next sweep cycle cures it. Arti doc NOT yet updated with gate 2/3 final results.

2026-10-07 20:35Z: 4:30pm cutoff sweep auto-REDEEMed 1000 OGSXX to cure the −1000 cash → cash 0, swept 0. Gates 1–5 RESOLVED, 6 BLOCKED (MMF orders restricted to clearing users). Arti v4 published (sha 30f9bc54…). Orders acct still at −$500. Offered Kevin: update BANK-1678 description + close, split gate 6 into its own issue — awaiting answer.

2026-10-07 21:06Z: BANK-1678 moved to Done with per-gate verdicts + Arti link. Gate 6 split to BANK-2240 (blocks BANK-1680). Remaining Interchange questions live in the Arti doc.

Status (2026-10-14, unverified, carried from the index line): probe done; gate 6 moved to BANK-2240.

## Schedule A fees

"Schedule A" = SCHEDULE OF FEES in the Interchange Advisers LLC Direct Account Platform Agreement (AL Advisors Management is the Intermediary). Latest copy as of 2026-10-15: Aryeh Friedman's 10/6 redline docx in #nova-interchange, Slack file F0C77TA29SQ, https://angellist.slack.com/archives/C0C32DWL44U/p1791295491506699?thread_ts=1790959622.193159&cid=C0C32DWL44U. Unsigned; Aryeh committed to signing by mid-Nov 2026. Not in GDrive or arti.

George (Interchange) 2026-10-14 in #interchange-angellist: no Interchange fees debit customer accounts; Schedule A charges are invoiced to AngelList.

Per-rail (Interchange draft -> AL redline): ACH regular waived (struck in their own draft); ACH reversal $30; same-day ACH greater of $0.50 or 0.50% capped $5 -> cap $1; domestic wire $25 -> $15; FedNow/RTP greater of $0.75 or 0.75% capped $25 -> cap $1; batch transfers waived. Implementation, platform, AUC and per-account fees waived in their draft. Deposit $50k -> $25k. Initial term 1y -> 2y.

Extraction trap: the docx mixes strikethrough formatting (Interchange's own waivers) with tracked changes (AL edits); a plain text dump concatenates them ("$2515.00"). Parse w:del/w:ins and w:strike separately.

Related: this file, § BANK-1678 sandbox probe.

## Empty account limits don't block

Interchange's `ProgramControls_Funding_Limits_*` schemas say "If unset, the account cannot deposit/withdraw via X". In sandbox, account `034BpTJEIHbujd3eMOokAB` has `funding.limits: {}` and an `achPull` of $1000 still reached SUCCESS (2026-10-13). So empty account-level limits don't block; a reviewer citing that doc line is not evidence by itself.

Separately, `settings.wire.canWithdraw` must be `true`: every Treasury MMF sell is a `wirePush` ("Wire withdrawal"). The Treasury guide's example sets it false; onboarding copied that until 2026-10-14.

**How to apply:** check a live sandbox account's controls and transfer history (`ix.sh GET`) before acting on a doc-only claim about Interchange controls. Related: [[treasury-tp-idempotency-replay-undefined]]

## Wire beneficiary on Interchange sub accounts (2026-11-06, BANK-2298/2594)
- George: no FBO; wire straight to the fund. Beneficiary name = fund legal name (`owner_identity_data.name`); `bankDetails.accountHolderName` is an internal Interchange ID, never a name. Address = "the fund's address" (provisional pending their ops).
- Kevin chose to cover both rails: `setup_counterparty!` creates the TP counterparty AND the DIBS counterparty eagerly with the fund address (`DIBS::Client.set_up_sub_account_counterparty!(…, beneficiary:)`). Otherwise DIBS creates it lazily with the partner-bank address on the first buy from a DIBS-bank CCA, and it never rebuilds once its id is set.
- Flag-on prerequisites: real Interchange partner-bank name/address (TP/DIBS copy once), and Interchange's production routing number in the DIBS wire-eligible ABA table.

2026-11-09: BANK-1812 stack renamed InterchangeEvent → `Interchange::WebhookEvent` (table `interchange_webhook_events`) on Kevin's call, matching `DIBS::WebhookEvent` (holds both pushed and polled Increase events). Kevin: webhook push is the PRIMARY path, the pull is the backstop; webhook receiver = planned step 4 writing to the same table. Service namespaces `InterchangeEvents::*`, metrics, flag kept.

## Venture submit over Prophet (BANK-2785 / BANK-2799, merged 2026-11-09)
- Treasury #9548 (b4337f666) + venture #39063 (c505050c): Venture's CreateMmfAccount calls `money_market_fund_accounts.submit_application` with `vehicle.entity_id` and a control person (ipseity control person, else fund lead). The client raises `RequestFailedError` whose message is treasury's own text (no backtrace); Venture shows only `validation_error` text, sends other categories to Sentry tagged and fingerprinted by category, and turns a `Prophet::TimeoutError` into "may still be processing".
- Known gap, not yet ticketed: Venture keeps its own `Banking::MoneyMarketFundApplication`, and treasury emits only ActivatedEvent. A treasury rejection leaves Venture "pending" forever and blocks resubmit; an app treasury keeps after a timeout or onboarding error makes ActivatedEvent dead-letter. Kevin's direction: Venture should read application state from treasury (new read route).

## BANK-2611 risk / investmentProfile probe (2026-11-09)

- **Sandbox ANGL program does NOT enforce George's prod rules.** Org account create with no `risk` → 200 OPEN (accts 65edUrLVG9fX0lLEmEKDXr, 4djwBBbKXJScB6Ah4yhVK7 on profile 034BpTqsAhHmhZs6chbVLm). GB individual with a placeholder `000-00-02xx` SSN and no `investmentProfile` → ACTIVE after the 2 minimal checks; LP org on it → ACTIVE → account OPEN without risk. So "sandbox create succeeds" proves nothing about the requirement; ask George to mirror the prod program config in sandbox.
- George 10-21 (C0C11Q9BHSM p1792621102430359): `risk.objectives` required for the Direct program, 400 "risk profile is required"; customer must answer (Interchange Advisers is the RIA). 10-16 recipe (p1792187124489349): `investmentProfile` required on the foreign-signer workaround; example risk = CONSERVATIVE / VERY_IMPORTANT / PRESERVE_WEALTH.
- `usEquities.canPlaceOpening/Closing: false` is the protojson zero value: sent false, echoed `{}`. The adapter's `usEquities: {}` already means false.
- `investmentProfile` requires annualIncome + netWorth (uint32 dollars); `Objectives` enum has 19 values (registry `ixc.registration.v1.Objectives`).
- Frec never collected suitability: `lib/frec/payload_validation.rb` hardcodes GROWTH / MEDIUM / OVER_5M for every account, so migrants have nothing to reuse.
- SSN must be `^\d{3}-\d{2}-\d{4}$`; id62 must fit 16 bytes; businessClassification 'NONE' and entityType 'LIMITED_PARTNERSHIP' are valid enum spellings (no prefix). Interchange docs MCP now needs OAuth (`mcp__interchange__authenticate`); the API JWT gets 401 at /mcp.

2026-11-10: Interchange webhook push has NO auth: `TargetSpec` = only `destination.url`; registry api.json (line 17 URL) and docs have no signature/secret/HMAC fields. So the BANK-1811 receiver is a doorbell: ignore the body, start the pull with fixed workflow id `interchange-events-consume-run`, rate-limit the endpoint (same conclusion as arti `interchange-inbox-vs-treasury-webhooks`).

2026-11-10 George (C0C11Q9BHSM thread 1794337354.678029): pushes NOT signed (no HMAC/mTLS/auth header; feature request logged). Recommends push-as-signal → pull `/events/v1/receive`, plus a long random token in the target URL path. One event per POST, at-least-once, non-2xx → retry. Pending from eng: egress IPs, body shape vs `/receive`, retry schedule/timeout.

## Webhook doorbell auth: provider-scoped ApiKeys (2026-11-13)
Kevin rejected the `INTERCHANGE_WEBHOOK_TOKEN` env var in favour of DB-issued ApiKeys, with vendor-agnostic naming and vendor A's key never working for vendor B. BANK-2833 / #9600 adds `api_keys.purpose` (rest_api | provider_webhook) and `api_keys.provider` (interchange | piermont). REST accepts only rest_api. #9586's doorbell uses `TreasuryApp::ApiKeyService.verify_interchange_webhook?`. Piermont's /dibs/api endpoint accepts its legacy REST key or a Piermont webhook key until BANK-2835 rotates it. BANK-2834 drops the purpose column default after deploy. Stack order: #9536 → #9537 → #9525 → #9600 → #9586 (gh stack #9601). Ingress for /webhooks/interchange is still undecided; check that ingress access logs don't keep the query string.
