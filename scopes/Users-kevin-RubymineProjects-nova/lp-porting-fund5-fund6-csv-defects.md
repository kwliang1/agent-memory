---
name: lp-porting-fund5-fund6-csv-defects
description: "CF Fund 5/6 LP porting (PROD nova): the CSV is a LOOKUP KEY not a payload (nova takes name/type from ipseity) so the TIN decides everything incl. which bank account is inherited; 7 disregarded entities carry SSNs not EINs. 2026-09-13 prod check: all 20 committable rows are already-held no-ops and 29 TINs still match nothing — committing migrates ZERO LPs."
metadata:
  node_type: memory
  type: project
  originSessionId: cda35891-f09f-4f32-bc13-2ae715f4ba49
  modified: 2026-09-11T20:57:33.498Z
---

Context 2026-09-11. Slack thread `C0A0PQ1DX55` / `thread_ts=1788897311.556309` (Anna Koh, Jack Plank, Conor Queenan, Susan Tang, Mitchel Kenney). Two Capital Factory distributions: **Fund 5 $1,120,000**, **Fund 6 $1,040,000**; Flowdash tasks `LRIrzQ/tasks/366` and `/367`. Kevin owns the **LP porting** side. Anna pulled the porting CSV from the IA Migration Drive via the AngelList GDrive runlayer MCP; local copies at `/tmp/lp-porting/`.

## Source of truth (Kevin's ruling, in order)

1. **Accounting's distribution-calc workbooks** — `Capital Factory 5/6, L.P. Distribution Calc.xlsx`, sheets `CF V Calc` / `CF VI Calc`; col A = Investor Name, B = Investor No. (`INVR000xx`), C = Type Code (GP/LP). Kevin: *"I'd treat the entity names here as source of truth."*
2. Drive IA Migration folders — Fund V `1FroDkjtrKcPc4i-Y7dKPWJyleZHum1mH`, Fund VI `1e53I13oqJcm7Zckv-l-zQDN0-TjqWsli`; the per-LP folders live under `5. Investor Information`, which also holds consolidated `Fund 5 LPs`, `CF 5 Partners Info PBC.xlsx`, `Fund 5 contact info`.
3. **NOT the reference file's `matched_to` / `name_cont` annotation columns** — see below.

## The LP set is correct

Fund 5 register = 62 named investors, Fund 6 = 18, total 80. Every register entry matched exactly one CSV row, **zero unmatched in either direction**. Nobody missing, extra, or in the wrong fund. Only names and types were wrong.

## 19 rows need correcting — and `matched_to` is what misled

An early pass off `matched_to` derived 25 defective rows. Wrong: the real count is **19**, and **10 rows flagged that way were already correct in the CSV** — Tabrizi Legacy LP, Joshua Gutman, Charles Cline (Fair Winds Capital), Howard Love, Lloyd Walker, Scott Francis, Steve Schaffer, Susan Schaffer, Christopher Camillo, Sanjay Chandra. `matched_to` claimed row 4 was `Base Case Capital, LLC`; the register says `Joshua Gutman`. **Never infer a correction from `matched_to`/`name_cont` — go to the register.**

Two further flags were regex artifacts, not defects: row 30 `Portcullis Trust (SIngapore) LTD` is a Singapore LTD (not a trust), and row 34 `Satterfield Vintage Investments L.P.` (dotted `L.P.` missed a suffix pattern). Both keep the CSV's `company`.

The genuine pattern on the remaining rows: `legal_name` holds the natural person while the investor of record is an LLC/LP/Trust (e.g. `Russell Hinds`→`RSH VENTURES LLC`, `Rich Crockett`→`Maruku Investments, LLC`, `Daniel Graham`→`Notley Investments, LP`, `Dean Drako`→`Drako Family Trust`, `Margarite Crockett`→`Five Roots Rising LLC`, `Matthew Briggs`→`The Briggs Management Trust`). Contributing cause: `etype_src` reads `"Individual (Default)"` on **52 of 80** rows — a default, i.e. the source classification was never read.

## Rows 61 and 80 are the GP, not an LP

Investor code **`CFM GP`**, name **`Capital Factory Management, LLC`**, in BOTH funds — Fund 6's calc names it identically, **not** "Capital Factory Management 6, LLC" as the annotation claimed. The CSV had "Joshua Baer" + his personal SSN. Same legal entity, one TIN — that is why rows 61/80 shared a TIN; it was never a duplicate-LP artifact. **Open: should the GP be ported as a recipient at all (product call)? It needs the LLC's EIN either way.**

## CORRECTION — the CSV is a lookup key, not a data payload

I earlier wrote in this file that `legal_name` is used VERBATIM as the ported nova Organization and Entity name. **That is WRONG.** Verified in `graph/src/services/entityMatchmaking/gatherPortReads.ts:109`:

```ts
const legalName = identityDisplayName(entity);   // entity = ipseity's own record
novaEntityType: ipseityToNovaEntityType(entity.entityType, ...)
```

The name and type written to nova come from **ipseity**, not the CSV. `plan.legalName` reaching `createPortedEntity` originates in ipseity. So the CSV's `legal_name` and `entity_type` are **matching inputs only** and are never stored — a wrong name in the CSV mis-names nothing in nova; it only affects name-similarity scoring (no-TIN rows) and the reviewer's on-screen display. The earlier alarm that "19 wrong names would create wrongly-named prod orgs" was overstated.

## THE TIN decides everything — including which bank account is inherited

One key drives the whole port: the TIN → ipseity blind-index lookup → ipseity Entity → and from that entity, all three of: name+type, the treasury INVESTMENT wallet, and the external bank accounts.

- `gatherPortReads.ts:47-51` — `clients.treasury.listCustomerAccountsByEntity({ entityId: ipseityEntityId, accountPurpose: INVESTMENT })`
- `gatherPortReads.ts:125` — `fetchActiveExternalBankAccounts({ ipseityEntityId, treasuryCustomerAccountId })`

The CSV carries **no** bank details. So **a personal SSN resolves to the person and inherits the person's bank account; an LLC's EIN resolves to the LLC and inherits the LLC's.** For a disregarded entity with no EIN there is *no key that reaches the LLC's account through this tool at all* — porting it necessarily ports the individual and the individual's account. That is the decisive consequence of the DRE finding, not a cosmetic one.

Also: `gatherPortReads.ts:61-69` requires **exactly one** INVESTMENT wallet — 0 or >1 sends the row to review instead of porting. And `entity_type` in the CSV is purely the `typeMatched` gate, never stored data.

## The authoritative TIN register (found 2026-09-11)

`5. Investor Information/CF 5 Partners Info PBC.xlsx` (id `1STMQgdVQiSzwXxHodsXHBxu2CnO1B1kO`) is the **tax-prep partner register and the real source of the CSV**. Sheet1 cols: A `* Number`, B `Entity or First Name`, C MI, D `Last Name`, E Suffix, F **`Name (Continued)`**, O **`SSN / EIN`**, P **`Entity Type`**, R **`Nominee / Disregarded Entity`**. Fund 6 equivalent: `CF 6 Partner Info PBC.xlsx` (id `1HTbw61JWLSLtCPdQDmXt0AotWRcj3nTk`).

Proven, not assumed: register rows 1-62 align with CSV Fund 5 rows 1-62 **62/62 exact on BOTH name and TIN**, and TIN values are **62/62 identical**. So the CSV's TINs are the preparer's certified values — no transcription error anywhere. `etype_src` = col P, `name_cont` = col F.

**7 rows are explicitly flagged `Disregarded entity` (col R), and ALL 7 carry an SSN, not an EIN**: #4 Joshua Gutman||Base Case Capital LLC, #5 William Boebel||Boebel Ventures LLC, #33 Russell Hinds||RSH Ventures LLC, #48 Rich Crockett||Maruku Investments LLC, #51 Daniel Graham||Notley Investments LP, #61 Joshua Baer||Capital Factory Management 5 LLC, #62 Margarite Crockett||Five Roots Rising LLC. Register-wide: **42 SSN / 19 EIN / 1 blank**.

A disregarded entity (single-member LLC, grantor trust) is ignored by the IRS as separate from its owner: W-9 line 1 = the owner, line 2 = the entity, TIN = the owner's SSN. **Often no EIN exists at all.** Only 3 of the 7 have one (Maruku confirmed later — see the VERIFIED EIN table below): **Notley `<EIN redacted>`** (VERIFIED — W-9 + the register's own note `H2 as "DRE": Notley Investments, LP, TIN <EIN redacted>`) and **CFM `<EIN redacted>`** (SINGLE-SOURCE, W-9 only — wanted a 2nd source).

**Kevin's decided rule: port as the entity only where the entity has its own EIN; otherwise port the individual.** Applied → Notley (51,70) + CFM (61,80) = entity name + `company` + EIN; Base Case (4), Boebel (5), RSH (33,72), Maruku (48), Five Roots (62), Briggs (74) = individual + `individual` + SSN.

**Cross-register contradiction:** CF6 classifies RSH Ventures (row 72) and CFM (row 80) as `Limited liability company` while CF5 classifies the same entities/same TINs as `Individual (Default)` + disregarded — and CF6 pairs `Limited liability company` with a personal SSN. That is the origin of the row 72/80 "TIN collision".

## Decided: pay the ENTITY (2026-09-11)

Kevin's question was "do we pay the entity or the individual's on-platform account?" **Answer: the entity — it holds the partnership interest.** Every fund record agrees (subscription agreement, distribution workbook, contact sheet, tax register). Crediting the member personally is a distribution to a different legal person and sets up a third-party withdrawal. Compliance owns formal sign-off; Kevin is confirming the named list with finance.

**Corrected model (Kevin corrected me):** the port is fund's on-platform account → LP's on-platform account. The LP later withdraws off-platform using bank details they control. So the external bank references the port carries are **withdrawal destinations**, not the rail the distribution travels. My earlier "we'd wire real money to the wrong account" framing was wrong — what's at stake is *whose wallet gets credited*.

Corroboration worth keeping: past distribution statements in each LP's `Distribution` subfolder show the fund paid an account in the **investor-of-record's** name 7 for 7 (Boebel Ventures, RSH Ventures, Maruku Investments LLC, Notley Investments LP, PreCurve LLC entity accounts; Hehman → grantors' joint account, normal revocable-trust titling; Adam Salamon → individual, because his *record* is the individual and the LLC is only in the wire's reference line). Tax status does not predict the payee; investor-of-record does.

**Blank-TIN fallback works (Kevin's call).** `resolveCandidates.ts` routes no-TIN rows to `lookupEntitiesByName` with name+type. But `classify.ts:149-156`: *"No-TIN — name+type resolver. **Never AUTO**; a hit is the review ceiling, a miss is nothing to port."* So each blocked row needs a reviewer pick, and a name miss = NO_MATCH (fails closed, never a wrong port). Also `classify.ts:137` — a TIN matching >1 entity is CONFLICT, and the comment names the disregarded-entity case explicitly ("a TIN resolving to both a person and an entity").

**Arti published for finance sign-off:** https://arti.internal.angellist.com/s/cf-fund56-lp-porting-entities (slug `cf-fund56-lp-porting-entities`). Names 9 investors: the 7 DREs plus row 8 Hehman (trust or couple?) and row 9 Drako (register says individual only; workbook + contact sheet say the trust). Flags the row-62 naming conflict — Five Roots Rising LLC vs The Legacy Nest LLC. NOTE: arti publish **timed out at ~17KB**; a ~10KB payload went through. Keep arti content lean or split it.

## VERIFIED EIN status, read from each LP's own W-9 (2026-09-11, after Kevin said "check again")

The tax register's disregarded-entity flag is NOT reliable for the TIN. Read the W-9.

| row(s) | entity | EIN | evidence |
|---|---|---|---|
| 48 | Maruku Investments, LLC | **<EIN redacted>** | W-9 filed as the LLC on line 1, **SSN box empty** — NOT a disregarded entity. The register's DRE flag + SSN for row 48 are WRONG. |
| 51, 70 | Notley Investments, LP | **<EIN redacted>** | W-9 + the register's own note; digits differ from the SSN |
| 61, 80 | Capital Factory Management, LLC | **<EIN redacted>** | W-9, SSN box empty |
| 5 | Boebel Ventures, LLC | none | EIN box empty |
| 33, 72 | RSH Ventures LLC | **<EIN redacted>** | NOT in either W-9 (both blank). It sits in the CF6 workbook **misfiled in the "Foreign Province, State or County" column**, on the row addressed `<street address redacted> Austin` = Hinds' W-9 address. Found by another session; I verified it. |
| 62 | Five Roots Rising, LLC | none | see artifact below |
| 74 | The Briggs Management Trust | none | EIN box empty; W-9 has BOTH "individual/sole prop" AND "trust/estate" checked (filing error) |
| 8 | David & Sarah Hehman 2002 Revocable Trust | none | see artifact below |

**THE OFFSET-DIGITS ARTIFACT — do not mistake it for an EIN.** On several of these W-9s the "Employer identification number" row renders the *same nine digits as the SSN*, shifted by one cell (Hehman `<SSN redacted>` / `<EIN redacted>`; Five Roots `<SSN redacted>` / `5-9568782`). It is a form-fill artifact. Test for it: if the digit string matches the SSN, or the SSN box is populated on a single-member-LLC/grantor-trust form, treat the EIN as absent. All three real EINs pass the test (Notley's digits differ; Maruku's and CFM's SSN boxes are empty).

**Row 62's name is settled by its W-9: `Five Roots Rising, LLC`** (line 2), so the contact sheet's "The Legacy Nest LLC" is wrong and the register's/commitment sheet's name is right.

**Kevin's decided handling:** entity of record in `legal_name`; key on the EIN where one exists; **leave the TIN blank where it doesn't** so the row routes to name matching and lands in manual review (never auto-matches, fails closed on a name miss). Final file `<scratchpad>/lp_porting.FINAL.csv` — 80 rows, 44 individual / 34 company / 2 trust, 6 blank TINs (rows 5, 33, 62, 72, 74 + row 30 Portcullis). 5 rows land in review by design.

**Still open with finance:** row 8 Hehman (trust or the couple?) and row 9 Drako (register records only the individual; workbook + contact sheet say the trust).

## PROCESS FAILURE worth not repeating (2026-09-11)

I told Kevin an EIN "truly doesn't exist" for RSH Ventures after reading **two W-9s** and calling it confirmed. It existed the whole time, misfiled in the CF6 workbook's Foreign Province column. Root cause: **I never parsed `CF 6 Partner Info PBC.xlsx` at all** — I skipped it because extracting an xlsx was awkward and inferred Fund 6 from Anna's reference file instead — and **never opened `Carta LP Info.xlsx`**, which I saw in the folder listing and walked past. Kevin: *"tell me if you skip anything. I already said this was important. which implies being thorough."*

**Rules that follow.** Scan EVERY cell of a source workbook for TIN-shaped strings, not just the TIN column — a misfiled cell is a real pattern here (CF6 Foreign Province; Notley's EIN lives in a free-text note cell in CF5). When a source can't be read cheaply, say so out loud and get a route; never silently substitute an inference for it. And never report "certain"/"confirmed" on a negative when a named source is still unread.

**Reading xlsx from Drive is the practical blocker:** the Sheets API refuses Office files (`must not be an Office file`), Sheets renders the grid to canvas so `get_page_text` returns nothing, `copy_file` copies xlsx as xlsx (no convert option, and there is **no GDrive delete tool** — a copy made this way is stranded), and `fetch_file` returns base64 that's too large to move to disk by hand. Working routes: ask the user to File → Save as Google Sheets (then the Gsheets API reads it exactly), or get permission to download and parse locally.

**Still unverified as of this writing:** the full CF6 table, all of `Carta LP Info.xlsx`, and three conflicts another session surfaced — CFM 6 (`<EIN redacted>` per Carta vs my `<EIN redacted>` read off the W-9 — one digit differs, unresolved), P180 Investments (`<EIN redacted>` vs `<EIN redacted>`), Bryan Chambers (`<SSN redacted>` SSN vs `<EIN redacted>` EIN, typed S-corp).

## `Carta LP Info.xlsx` is the system of record — read it FIRST next time

Fund 6 `5. Investor Information/Carta LP Info.xlsx` (id `1FFXsu-KX2ObawVuB2EncWBm4De8n7sie`). Sheet `Partners` cols: A Partner, **B Tax ID**, **C Tax ID Type (SSN/EIN)**, D Class (Limited Partner / **General Partner**), F Entity Type (Individual / Single-Member LLC / Partnership / LLC taxed as a Partnership / Corporation-"S" / Personal trust (taxable to grantor) / Family partnership), **X Beneficial Owner Name**, **Y Beneficial Owner TIN**. Sheet `Contacts` has per-topic contact routing incl. wire instructions. This is the only source that states the entity/beneficial-owner split explicitly. There is no Fund 5 Carta export in that folder.

EINs it yielded that nothing else had: **RSH Ventures LLC `<EIN redacted>`** (also in CF6's misfiled Foreign Province cell — two sources), **Base Case Capital, LLC `<EIN redacted>`** (single-member LLC, BO Joshua Gutman), **Capital Factory Management 6, LLC `<EIN redacted>`** (GP class). Also confirmed MEH Capital L.P. `<EIN redacted>`, Compass Point `<EIN redacted>`, Hall Phoenix/Inwood `<EIN redacted>`, Puneet and Dev `<EIN redacted>`.

**My W-9 read of CFM as `<EIN redacted>` was an OCR misread; Carta's `<EIN redacted>` is right.** But note Carta's entity is "Capital Factory Management **6**, LLC", CF5 says "CFM **5**, LLC", and the W-9 says "CAPITAL FACTORY MANAGEMENT, LLC" — possibly three entities. Fund 5's GP row (61) is therefore still unresolved.

**Second artifact class — an SSN re-dashed into the EIN field.** Carta lists The Briggs Management Trust with EIN `<EIN redacted>`, which is Briggs' SSN `<SSN redacted>` with the dashes moved: identical nine digits. Not a real EIN, and it is sitting in the cap table. Always strip non-digits and compare an EIN against the known SSN before accepting it. Briggs is the only Carta row that fails this test. (Distinct from the earlier W-9 *offset-cell* artifact — see above.)

**Unresolved conflicts needing a human:** P180 Investments — CF6 register `<EIN redacted>` vs Carta `<EIN redacted>`, two genuine different EINs. Bryan Chambers — register individual+SSN vs Carta Corporation-"S"+EIN `<EIN redacted>` with no entity name given.

**Deliverable shape Kevin asked for (2026-09-11):** populate the Fund V and Fund VI sheets with **legal name of the entity to pay + entity type + owner email** for every row, TIN optional — blank TIN is fine and routes to name matching + manual review. Final files `<scratchpad>/lp_porting.fundV.csv` (62 rows, 4 blank TINs) and `lp_porting.fundVI.csv` (18 rows, 3 blank TINs) — **all 80 rows present including every flagged one**; zero blank names or emails in either. Blank TINs: 5 Boebel, 30 Portcullis, 61 CFM 5, 62 Five Roots, 64 Chambers, 71 P180, 74 Briggs. `lp_porting.flags.csv` carries 10 rows needing attention (those 7 + 8/9 pending finance + 80 for the GP question).

**Cross-fund EIN consistency rule:** when the same entity appears in both funds, the EIN applies to both rows — done for Base Case Capital LLC (rows 4 **and** 67 = `<EIN redacted>`; caught because row 4 was initially left blank), RSH (33/72) and Notley (51/70). **Exception: Capital Factory Management.** Rows 61/80 carry *different* entity names — "CFM **5**, LLC" vs "CFM **6**, LLC" — so they are plausibly two entities and Carta only covers CFM 6. Do NOT copy `<EIN redacted>` onto the Fund 5 GP row.

**Downloading Drive xlsx locally is the working route** (Kevin authorized): navigate Chrome to `https://drive.google.com/uc?export=download&id=<FILE_ID>` — lands in `~/Downloads`, then parse with zipfile+ElementTree. Beats every other option (Sheets API refuses Office files; Sheets renders to canvas so no text scrape; copy_file won't convert and there's no GDrive delete tool).

## Open blockers

- **Row 8** `David & Sarah Hehman 2002 Revocable Trust` — register `Grantor trust`, TIN is the grantor's SSN `<SSN redacted>`. Real-world correct but the SSN resolves to a person against a `trust` row → needs a reviewer pick or Kevin's call. (Its W-9 shows the same 9 digits in BOTH the SSN and EIN boxes — a form-fill artifact, NOT a separate EIN. Do not take it.)
- **Row 30** `Portcullis Trust (SIngapore) LTD` — blank TIN; **Kevin accepted leaving it blank.** Lands `NO_MATCH` silently (`classify.ts:152` does not error a blank TIN).
- **The 5 no-EIN DREs**: verify the account treasury already holds for each *individual* is the one the LP expects the distribution in — this tool cannot route to an LLC account without the LLC's EIN.
- GP question: should `Capital Factory Management, LLC` (rows 61/80, code `CFM GP`) be ported as a recipient at all?

## Method that worked (reusable)

Adversarial cross-source checker `<scratchpad>/xcheck.py` + `xcheck_run.py`, re-runnable. 6 checks: row-alignment (don't assume 1:1 — prove it), TIN value agreement, name-variant disagreement across all 5 sources, type↔TIN-format consistency (the `typeMatched` gate), DRE-flag coherence, and a **two-source rule for every asserted EIN** (it correctly refused to certify CFM's). Derive `entity_type` from the register's `Entity Type` column, **never from a name regex** — my regex produced 2 false flags (dotted `L.P.` read as individual; "Trust" in a Singapore LTD's name read as trust). Type/TIN conflicts went 12 → 4 → **2** once the regex was dropped.

## State

**The batch is in PRODUCTION nova**, blocked in the Entity Migration tab as a duplicate — see [[nova-matchmaking-duplicate-batch-unblock]] for why the empty-`owner_user_id` "conformed" file could never unblock it. Resolution: the genuinely corrected CSV shifts the hash legitimately → new document → new batch, no prod DB write, no engbot delete. **Do not commit the existing batch.**

Artifacts (scratchpad, session cda35891): **`lp_porting.v3.corrected.csv`** (current; register-driven types + Kevin's DRE rule; 50 individual / 29 company / 1 trust) + `lp_porting.v3.decisions.csv` (per-row basis), `cf5_partners_register.csv`, `xcheck_failures.csv`, `xcheck_name_variants.csv`, `w9_findings.md`, `lp_porting_diff.csv` (PII-free, safe to share). v1/v2 superseded. All carry real TINs except the diff — keep local.

GDrive MCP gotcha: its `search` and `list_folder` **cannot see shared-drive contents** (both return empty for folders Chrome lists fine); `list_folder` works on IDs you already know, and `fetch_file` returns native Google Sheets as CSV but .xlsx as raw base64. Auth does NOT propagate from Kevin's session to a spawned one.

See [[nova-matchmaking-duplicate-batch-unblock]], [[nova-matchmaking-owner-gate]], [[nova-entity-migration-names-docservice-sso]], [[nova-lp-porting-review-tab]].

## PROD BATCH ASSESSMENT 2026-09-13 — committing now would migrate ZERO LPs

Read-only nova prod console. Three Capital Factory batches exist; Kevin said to ignore `Capital Factory Fund V` in favour of `Capital Factory Fund V Reverified`.

| batch | id | rows | AUTO_MATCH | CONFLICT: TIN matches nothing | CONFLICT: TIN matches many | NEEDS_REVIEW |
|---|---|---:|---:|---:|---:|---:|
| Capital Factory Fund VI | `26d6adb6-bdd1-419c-a234-262f391b2ce8` | 18 | 7 | 3 | 4 | 4 |
| Capital Factory Fund V Reverified | `f168faf0-6bb6-43e3-b3cc-8c81d3499182` | 62 | 13 | 26 | 15 | 8 |
| Capital Factory Fund V (ignore) | `30f4f5cd-3e8b-4013-9dbf-fa77c41cd3da` | 80 | 26 | — | — | 7 |

**The finding that decides it: all 20 committable rows point at entities nova ALREADY holds, and every one already has exactly 1 BANK EFA with a treasury account set.** Fund VI 7/7, Reverified 13/13 — zero new ports in either. A commit short-circuits at `findExistingEntity`, creates no org, seats no owner, and re-upserts an existing wallet. Safe, but nothing moves.

**The real blocker is the 29 rows whose TIN matches nothing in ipseity** (26 of them in Reverified — 42% of that batch). **Reverifying did not fix this.** It is the disregarded-entity shape documented above: SSN-certifying entities where no EIN exists, so ipseity has nothing to match. No in-product fix.

**19 rows ARE recoverable in product** — "TIN matches more than one entity" is a reviewer pick away from committable (`SELECT_CANDIDATE_SOURCES` includes CONFLICT). Highest-value hour available on these batches. One Reverified row reports the matched entity has no investment wallet in Treasury — nothing to port there. NEEDS_REVIEW rows with 25 candidates are name-only fan-outs with no TIN, and 25 looks like a result cap, so the visible list may be short of the real one.

**Unverified risk, would check before any commit:** whether the treasury customer account the port would attach matches the one already on each entity's wallet. If it differs, the upsert adds a *second* wallet rather than no-op'ing. Needs the port plan (a live treasury/ipseity read) — a one-row dry-run settles it.

**A corrected TIN escapes the idempotency trap; a corrected owner email does not.** Changing a TIN shifts the file hash → new document → new batch → new row ids → fresh keys. Changing only an owner email keeps the same batch, row and pick, so it hits `IDEMPOTENCY_CONFLICT` permanently — see [[nova-matchmaking-uncommit-fsm-dedup]].

Both SCORING-status batches were actually in REVIEW; the stored column is stale by design flaw — see [[nova-matchmaking-upload-status-stale]].

**Prod console route (nova):** `al console create -a nova -e prod --no-attach`, then `al console exec -a nova -e prod -- node --input-type=module -e '<script>'`. The Prisma client must be imported by explicit path — `await import('/nova/packages/prisma/dist/gen/client/index.js')`; a bare `require('@angellist/nova-prisma')` dies with `ERR_UNSUPPORTED_DIR_IMPORT`. Note this is the **write** console namespace (`nova`, not a `-ro` one — `nova-ro` is forbidden for this user), so keep strictly to reads. Delete the console afterwards: a leftover blocks the next create with `AlreadyExists` while `list` cannot see it.
