---
name: ca-au-branch-code-ewa-rule
description: "EWA branch-code rule for Canadian/Australian SWIFT wires (2026-10-01) — prod shapes, why 5-or-9 digits, copy/merge exemption"
metadata:
  node_type: memory
  type: project
  originSessionId: 2e1a9ce8-05c2-4941-8676-3b34e8649b73
  modified: 2026-10-01T19:45:18.944Z
---

Increase (via DIBS) needs `routing_number` for CA/AU SWIFT wires; DIBS sends `beneficiary_branch_code` (`increase/payment_service.rb:207`), presence-checked by #8764. Treasury branch `kevinliang/ewa-ca-au-branch-code` adds an EWA model rule; nova #10662 adds the input and must merge first.

Prod facts (read-only query 2026-10-01): of 2,881 CA/AU-SWIFT EWAs, 1,764 CA hold a 5-digit transit and only 43 a 9-digit routing number; all 7 CA Increase wires completed (6 × 5-digit, 1 × "XXX", OW 136394). Non-Increase rails complete CA wires with any shape, including nil. About 930 legacy rows fail the rule.

**Why:** a strict `0\d{8}` rule would have blocked the working format; Kevin chose CA = `\d{5}|0\d{8}`, AU = `\d{6}`. Kevin chose to exempt copies (`save!(context: :copy)` in MergeService + `find_or_create_from_existing!`) and archived rows, because MergeService dups every EWA and would otherwise half-merge entities.

**How to apply:** don't tighten the CA format without asking Increase which form they want; a copied EWA is not new input. Related: [[treasury-prod-console-access]].
