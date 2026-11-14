---
name: feedback_banking_issues_nova_team
description: "Linear issues from a treasury-repo session go to Nova Foundations (BANK); nova-side banking / transactions-API issues go to Nova or the project's team"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 8d0e0c9f-b22f-41d0-8ccb-4d5c43d1879b
  modified: 2026-10-28T21:15:33.637Z
---

**Treasury repo → Nova Foundations (BANK).** On 2026-10-28 Kevin said: "All linear issues created during a session in the treasury repo should be for that team." I had filed the INC-5851 dedupe fix under Nova by following the rule below, and he moved it to BANK (it became BANK-2461). Assign it to Kevin (`assignee: "me"`).

**Nova-side banking work → Nova (NOVA).** On 2026-10-22 he asked that banking / transactions-API issues go under Nova, assigned to Cameron Austgen "for now". The project wins over the team: those issues ended up in NIS, under the Transactions API V1 project.

**Why:** BANK owns treasury code. The 10/22 rule was about nova-side banking work, and I over-applied it to a treasury session.

**How to apply:** decide by the repo the work lands in. For treasury, pass `team: "Nova Foundations"`; BANK auto-attaches the current cycle, so mention that. A team change re-keys the issue and its `gitBranchName`, so rename the branch afterwards (`gt rename`). A team move drops the project if the project doesn't include the target team; check first and tell Kevin when it happens.

Related: [[feedback_session_linear_issues_todo]], [[linear-triage-auto-assigns]].
