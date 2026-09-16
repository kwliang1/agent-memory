---
name: bank-1757-passport-pan-bidx-find-by-identity
description: "ipseity PR #1549 (BANK-1757) passport+PAN blind indexes + find_by_identity; consolidated into IdentityLookupService, owned by dcetlin. Kevin's role = reviewer."
metadata: 
  node_type: memory
  type: project
  originSessionId: 4024f7d7-05ec-41ef-8b11-8c1f329d11e5
  modified: 2026-08-17T19:53:09.937Z
---

ipseity **PR #1549** `add-passport-pan-blind-indexes` (BANK-1757, OPEN). Adds `passport_bidx` (~47.7K people) + `pan_bidx` (~9.2K) on `identity_data_people` (same KMS `GenerateMac`/HMAC-SHA256 as `ssn_bidx`) + `POST /api/entities/find_by_identity`. **Owner = Dan Cetlin (dcetlin), NOT Kevin.** Kevin (kwliang1) is reviewer; I review on his behalf.

**Design was force-pushed mid-review (2026-08-17):** original had a dedicated `Entities::FindByIdentityService`; Kevin commented "consolidate LookupServices here" → Dan **deleted FindByIdentityService and extended the NOVA-3784 `Entities::IdentityLookupService`** (`lookup_by_tax_ids`) with passport/PAN domains. So find_by_identity now builds one `Query` per identifier and delegates. **Any local patches I made against FindByIdentityService are moot — that file is gone.** HEAD churns fast (466caead→65712573→a40fef5b within an hour); ALWAYS re-fetch + read the current file before commenting — I anchored a comment to a stale line once.

**`IdentityLookupService` design (the real code, `app/services/entities/identity_lookup_service.rb`):** per-row KMS soft-fail — `compute_hmac` RAISES on KMS outage (degradation is write-path-only), so `prepare` wraps each row → `report_degraded` (class only, never the tin) → per-row `kms_error` status, no batch crash, no PII leak. `domains_for('person', tin)` = [ssn (only if us_numeric: no `\p{L}` + 9 digits), passport, pan]; tax types → [tax_id]. Returns `Candidate{entity_id, entity_type, name}` — name IS returned (see below).

**Adversarial-review outcomes (mine) vs final consolidated state:**
- **PII-on-error** → Dan's controller rescue `report_degraded(class only) → 500 {status:'error', error: e.class.name}` closes it (my rec was 503 `status:degraded` to keep transient-vs-permanent signal for create-anyway; minor, his call). Also double-covered by IdentityLookupService per-row soft-fail.
- **Passport permanently weak** (unique only per issuing country AND reissued after expiry → even issuer-scoping can't fix; `citizenship_country_code` ≠ issuer, NULL fractures matching). Dan quantified it: **no `passport_issuing_country` column; `citizenship_country_code` populated on 46/145,760 passport records = 0.03%** → country-scoping impossible now. Disposition (in dedup subworkstream canon): passport matches on number alone → cross-country false positives route to the **review queue as candidates** (= the candidate-only contract). My `confidence: strong|weak` payload field was LOST in consolidation. **STILL OPEN**: response is `{entity_id, entity_type, name}`, no match_type/confidence → weak passport match indistinguishable from SSN hit. I flagged inline on controller:104; cheap fix = tag via the `ref` already on each `Result` (no shared-service change), else carry into BANK-1774 contract.
- **Degrade-OPEN consumer contract** (BANK-1774): degraded → create anyway + reconcile, never block; never auto-merge on weak match, confirm name+DOB.

**Bot review round (2026-08-17):** cursor + devin found `||` identifier-collapse (blank-string ssn blocks rest; first-truthy-wins) [HIGH] and status-after-exclude [MED] — **both FIXED by Dan at a40fef5b** (per-identifier queries; status from post-exclude set). Rebutted/false-positive: `name` oracle (name already plaintext to secret-holders via `show`+Snowflake REPORTER — I conceded), `typed: true` (Kevin's pre-existing file), log-redaction-incomplete (base list `[:ssn,:passport,:tax_id]`+`/\bpan\b/` covers all four — verify the FULL file, not `tail -1`).

Extends [[nova-3784-ipseity-lookup-by-tin]] (the service this consolidated into) and [[csv-entity-ingest-linear-filing]]. Blind-index mechanism in `app/models/concerns/blind_index_concern.rb`.
