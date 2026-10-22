---
name: feedback_banking_issues_nova_team
description: "File banking / transactions-API Linear issues under the Nova team (not Nova Foundations/BANK); assignee Cameron Austgen \"for now\" (2026-10-22)"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 8d0e0c9f-b22f-41d0-8ccb-4d5c43d1879b
  modified: 2026-10-22T05:59:42.247Z
---

On 2026-10-22, Kevin asked that all banking issues go under the **Nova** team (key NOVA), not Nova Foundations (BANK), and be assigned to Cameron Austgen (caustgen@angellist.com) "for now". Re-check the assignee later.

**Why:** these are owned on the Nova side. BANK auto-cycles them, and Kevin had me move eight issues after the fact (BANK-2368…2375 → NOVA-995…1002).

**Update, same day:** the project wins over the team. Kevin said "move it to NIS then, whatever is supported in the project", so the issues ended up in NIS (NIS-4402…4411), under Transactions API V1 › Miscellaneous milestone. Use Nova only when the target project includes the Nova team.

**How to apply:** pass `team: "Nova"` when creating issues. A team move drops the project if that project doesn't include the target team; Transactions API V1 (P-NIS-1576) only had NIS and BANK. Check the project's teams before moving, and tell Kevin when the project gets dropped.

Related: [[feedback_session_linear_issues_todo]], [[linear-triage-auto-assigns]].
