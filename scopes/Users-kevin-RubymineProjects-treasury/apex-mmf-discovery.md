---
name: apex-mmf-discovery
description: "APEX Direct integration discovery — M7 milestone on Money Market Funds v2, AscendOS OpenAPI specs location"
metadata: 
  node_type: memory
  type: project
  originSessionId: a060a12c-ac79-4234-8299-9dd2540fd217
  modified: 2026-07-21T00:22:33.847Z
---

Kevin is assessing an **APEX Direct (Apex Fintech Solutions / AscendOS)** integration for treasury MMFs.

- **Linear**: milestone "M7 — APEX Direct Integration Discovery" (id `2e9d3d64-5ecb-4a1c-91b9-cf16be702c6f`) on project "Money Market Funds v2" (`money-market-funds-v2-41fec0436761`, team BANK), created 2026-07-20. Discovery spike issue **BANK-1665** (assigned to Kevin, branch `kevinliang/bank-1665`) carries the spec tarball as an attachment — Linear only supports file attachments on issues, not milestones/projects. Goal: gauge integration effort vs. current system shape + sketch refactoring. Open question: project/M5 name Interchange as the second MMF provider — APEX may take that slot; M5 framing may need revision.
- **OpenAPI specs**: `~/Downloads/apex-ascendos-api-references/references/` — 17 OpenAPI 3.0.3 YAMLs (one per AscendOS service, UAT servers, ~350 ops; transfers=112, advisorarch=68, accounts=42). Source: Apex Developer Dashboard → Agentic Development Kit (https://developer.uat.apexascend.com/adk), skill `apex-ascendos-api-references` (specs are NOT on the public docs site or in the afs-public SDK repos).
- AngelList's Apex sandbox dashboard: developer.uat.apexascend.com (trial, ~70 days left as of 2026-07-20); sandbox API base `https://sbx.apexapis.com/`.
