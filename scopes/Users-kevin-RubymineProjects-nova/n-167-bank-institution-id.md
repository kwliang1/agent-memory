---
name: n-167-bank-institution-id
description: "N-167 (stable bank/institution id for transfer recipient matching): DIBS ABA has NO institution id — only routing_number, which is the WRONG grain. RSSD is the real answer; canonicalized-name compare is the cheap fix."
metadata: 
  node_type: memory
  type: project
  originSessionId: b304a4b2-e5d7-49de-88f9-06c18e5a2a77
  modified: 2026-08-13T21:41:04.704Z
---

N-167 (Nova, Backlog, branch `kevinliang/n-167`) wants to replace the brittle **bank-name string** compare in transfer-recipient matching (`enteredAccountMatchesRecipient` in nova `graph/src/services/externalBankReference/railConsistency.ts` + FE `BeneficiaryDetailsStep/index.tsx` & `form.ts` lockedRails superRefine) with a "stable bank/institution id from DIBS ABA." Follow-up to [[nova-3740-transfer-reroute]]; escalated by PR #9413's inherit-lock (name drift → hard block on beneficiary step).

**Investigated treasury 2026-08-13 — the issue's premise has a gap:**

1. **DIBS ABA (`dibs_aba_routing_records`) has NO institution id.** Only stable key = `routing_number` (unique index). Columns: routing_number, bank_name (free-text), wire_eligible, ach_eligible, city/state/postal, provider, last_synced_at. Same for `dibs_swift_routing_records` (key=swift_code) and legacy `fed_ach_records`/`fed_wire_records` (key=routing_number). Parser `backend/dibs/app/services/dibs/fed_directory/ach_parser.rb` only pulls routing#, name, city, state, postal — the source `misc/FedACHdir.txt` carries nothing else. Only `institution_id` in treasury repo = `plaid_institution_id` (unrelated Plaid concept).

2. **`routing_number` is the WRONG grain for this match.** N-167's failure = a bank's wire vs ACH routing numbers resolve to different `bank_name` strings. Those rails have DIFFERENT routing numbers by construction (BofA ACH 021000322 vs wire 026009593). The match needs an id constant across a bank's wire+ACH+SWIFT records — routing_number varies along exactly that axis. So "compare the id" cannot be satisfied by anything in DIBS today.

**Real answer = RSSD ID (FFIEC/NIC institution id)** — Fed's permanent per-institution id, groups all of a bank's routing numbers. NOT in FedACH/Fedwire files, and there's no clean routing#→RSSD crosswalk in the Fed directory itself → needs separate FFIEC NIC ingest + mapping table. VERIFY a reliable public crosswalk exists before committing (data-sourcing project, not a column add).

**Recommended cheap fix (told Kevin):** canonicalize bank_name (upcase, strip punctuation + legal suffixes N.A./NA/N A, collapse whitespace) and compare normalized. Kills "BANK OF AMERICA, N.A." vs "BANK OF AMERICA NA" drift, ships in the same call sites, zero new ingest. Downsides: still name-based (won't catch a true rename), doesn't fix ~3% blank-bankName legacy rails. → Do canonicalization now to unblock #9413's false-block; pursue RSSD `institution_id` only later as its own scoped data project. Correct the issue's "expose id from DIBS ABA" framing either way.

Awaiting Kevin's pick: write canonicalization as the N-167 plan, or scope the RSSD ingest.
