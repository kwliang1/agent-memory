---
name: csv-entity-migration-tool
description: Design for the nova admin tool that ingests a CSV of external entities (TIN+name/email/type/address) and one-way ports matched venture InvestmentEntities into nova.
metadata: 
  node_type: memory
  type: project
  originSessionId: 0e543ade-488f-42be-95ee-8849ec3b5a75
---

Design started 2026-07-02 (thread "Design: CSV entity ingest → venture→nova migration"). Admin-facing tool living in `nova` that ingests a CSV of external entities and migrates pre-existing `venture` InvestmentEntity models into nova, keeping treasury/ipseity relations attached.

**The spine:** every system joins on the **ipseity Entity id** (`entity_api_id`), NOT on TIN. venture=`investment_entities.entity_api_id`; treasury=`customer_accounts.owner_entity_api_id` (1:many); nova=`Entity.alIpseityEntityId`+`alInvestEntityId` (both @unique); ipseity=`Entity.id` (TIN stored encrypted in `[EntityType]::IdentityData` — `Person.ssn`, `Company/Trust/Ira.tax_id`).

**Locked decisions (Kevin):**
1. **Keep the ipseity entity id** through the port → treasury work ≈ nil (no re-own endpoint needed; verify/sync only).
2. CSV carries **TIN only** (no ipseity/venture ids). **Kevin chose TIN as the PRIMARY match key (Path A)** over the cheaper email-first Path B — so a **new ipseity lookup-by-TIN capability is required** (see critical-path finding below). Kevin OK with building it as a "small side project".
3. No-match rows → review queue, admin decides (no ipseity-create/KYC path in v1).
4. Not a validation gate — **confidence-scored matchmaking + human review; NOTHING auto-commits** (every write human-confirmed). AUTO_MATCH is just a confidence/sort label. Anchor on TIN, score name/entity_type/email/address as soft signals → route AUTO_MATCH / NEEDS_REVIEW / NO_MATCH / CONFLICT. Email compared across **all Invest::TeamMembers** + all of each user's emails (`User#all_emails` `user.rb:667`; `secondary_emails` table `user.rb:224`; normalize via `HasComparisonEmail.comparison_email` `concerns/has_comparison_email.rb:36`). entity_type is a soft signal (venture vs ipseity enums differ).
5. **One-way port** — no dual-write, no venture writes, no drift/backfill scope. venture is read-only source.
6. **Self-serve** → admin GraphQL + review UI, two-phase (Stage: score into DRAFT rows; Commit: admin confirms → port). Reuse `DirectoryEntityBulkEntityUpload → DraftEntity` (`packages/prisma/models/directory.prisma:251-340`).
7. **CSV row = one `owner_email` + N optional `member_email_*`.** Owner → `OrganizationEntity` owner (roles Owner/Admin). Members → upsert nova `Account` by email + `OrganizationEntityMember` + `BankingPermission`, **non-owner role** (per-user block at `onboardDistributionRecipient.ts:199-231`).

**CRITICAL-PATH FINDING (verified):** ipseity CANNOT be queried by TIN today. `ssn`/`tax_id` use Rails 7 `encrypts` NON-deterministically (per-record random keys, `EnvelopeEncryptionKeyProvider` `config/application.rb:64`), NO blind index, NO `deterministic:true`, zero query paths (`identity_data/person.rb:47`, `company.rb:78`, `trust.rb:37`, `ira.rb:36`). Path A therefore requires **Phase 0**: add blind-index columns (`ssn_bidx`/`tax_id_bidx` = HMAC of normalized TIN) on 4 identity_data tables + write-path hook + **backfill (decrypt-in-Ruby) over ALL historical rows** + new Prophet `entities:lookup_by_tax_id` returning candidates. This backfill is the long pole. See [[feedback-backfill-with-ledger-changes]].

**Phased plan (Path A):** P0 ipseity TIN-index+backfill+lookup handler (long pole, parallelizable) · P1 venture REST fetch (InvestmentEntity by entity_api_id[], eager-load team members+emails+treasury_account_id, filter state) · P2 nova staging schema (EntityMigrationBatch/Row) · P3 scoring service (depends P0+P1) · P4 admin GraphQL (upload/query/commit, angelListAdmin) · P5 port exec (upsertFromVentureInvestmentEntity, keep ipseity id, treasury verify no-reown, conflict-guard the :390-433 mismatch path) · P6 review UI (ADAPT). Sequential-per-entity; external calls outside Prisma tx.

**Cross-service surface:** ipseity (blind-index + lookup-by-TIN — hardest) · venture (REST fetch) · treasury (none new — id preserved) · nova (staging + scoring + admin GraphQL + UI + port core).

**Reuse:** `graph/src/services/entities/upsertFromVentureInvestmentEntity/index.ts` (~80% of write path; conflict path `:390-433`); `graph/engbot/onboardDistributionRecipient.ts` (record-set template); `lib/directory/entity/holdings/loadCsv.ts`+`importFromCsv.ts` (CSV). Nova pulls venture via legacy REST SDK `@angellist/sdk-venture`.

**Open items:** ipseity backfill row-count (P0 sizing) · TIN normalization rules · fuzzy-name threshold + entity_type mapping table (CSV↔venture↔ipseity enums). Design delivered in Slack thread `Design: CSV entity ingest → venture→nova migration`; awaiting Kevin's next-step pick (ticketize / start P0 / adjust).
Superseded 2026-07-02. Current design: [csv-entity-ingest-linear-filing](csv-entity-ingest-linear-filing.md).
