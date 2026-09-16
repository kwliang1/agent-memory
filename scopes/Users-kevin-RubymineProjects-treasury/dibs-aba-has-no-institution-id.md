---
name: dibs-aba-has-no-institution-id
description: "DIBS dibs_aba_routing_records has NO institution id; only stable key is routing_number, RSSD is the real answer — full analysis lives in the nova scope"
metadata:
  type: reference
---

treasury owns `dibs_aba_routing_records`, and the table has **no institution id**. The only stable key is `routing_number`; RSSD is the correct identifier if one is ever added.

The full analysis, and the nova-side consequence, are in the nova scope: `n-167-bank-institution-id.md` (N-167, `graph/src/services/externalBankReference/railConsistency.ts`). Read it before changing the ABA parser in `backend/dibs/app/services/dibs/fed_directory/ach_parser.rb`.
