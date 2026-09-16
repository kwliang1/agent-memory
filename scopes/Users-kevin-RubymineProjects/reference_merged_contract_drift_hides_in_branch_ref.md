---
name: reference_merged_contract_drift_hides_in_branch_ref
description: "Verifying a client against a just-merged cross-repo contract — diff the MERGED artifact directly, not the source branch ref (it advances too)"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 9dee68cf-c5ba-4556-bd17-93523c9255a1
  modified: 2026-08-21T17:24:25.382Z
---

When a client (e.g. nova ipseity op) is built to another repo's PR contract while that PR is OPEN, and the PR later merges, re-verify by reading the **merged artifact directly** (`git show origin/main:<file>`), NOT by diffing the source branch ref against main.

Failure mode I hit on NOVA-3884: I built the client to ipseity `#1557` (branch `kevinliang/nova-3883`) while open. To check for drift after merge I ran `git diff origin/kevinliang/nova-3883 origin/main` on the contract file and got "no diff" — concluded byte-identical. But the branch ref had been **force-updated to the final state** before merge (the input wire field was renamed `name` → `entity_name`), so BOTH sides of my diff carried `entity_name` while **my client still sent `name`**. The diff compared two evolved refs and masked that my own code diverged. The handler would have rejected every request.

Also: a stacked PR can squash-merge under a DIFFERENT number/title than the one you tracked (#1557 landed as part of #1560 "...to IdentityLookupService"), and a post-open refactor can move logic between services (`NameLookupService` → `IdentityLookupService`) — the merged commit BODY often documents the wire-facing change ("Input field is `entity_name` (not `name`)"). Read the merged commit message + the merged message/struct file, not the branch you first read.

Rule: to check a client against a merged contract, diff the client's emitted shape against the merged struct/schema read straight from `origin/main`; treat the merged artifact as the only source of truth. Related: [[reference_treasury_transfer_state_machine]].
