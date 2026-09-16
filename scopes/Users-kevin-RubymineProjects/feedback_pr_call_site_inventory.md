---
name: PR descriptions list call sites with permalinks for unmigrated primitives
description: When a PR introduces a primitive (helper, service method, gate) without migrating existing call sites, the PR body must inventory those call sites with deep permalinks and outline the behavioral change a future migration would imply, per call site
type: feedback
originSessionId: e79fe952-a780-4897-987b-b41c3ccaade8
---
When a PR adds a new primitive (helper method, service, gate) but deliberately does NOT migrate existing call sites in the same diff, the PR description must:

1. List every existing call site that *could* migrate to the new primitive, in a table.
2. Use **GitHub permalinks pinned to a specific SHA** (e.g., `/blob/<sha>/path#L62-L73`) — not `main` URLs that drift as the codebase changes.
3. Outline the behavioral change implied by each migration, per call site (not just a generic note). Distinguish "strictly tighter" from "strictly looser" from "depends on entity type".
4. Call out any per-type gotchas (e.g., the Trust-propagation gap in Ipseity).

**Why:** in this codebase the team makes per-call-site migration decisions deliberately — primitives may ship unused for a reason, and the PR description is the place to capture which call sites are candidates and what the trade-off is for each. Without the inventory + per-site behavioral note, future migrators have to redo the analysis to decide whether migration at a given site is safe.

**How to apply:** triggered when the PR adds a new primitive that competes with or supersedes an existing one (e.g., a tri-state Ipseity-holistic outcome alongside `responsible_alloy_outcome`, a new state-machine helper alongside an old one, a new auth-decision service alongside a User#kyc_verified? helper). Use `git grep` plus `gh api` for the SHA, and group the call sites by the *kind* of behavioral change a migration would cause (e.g., "auto-approve gates: strictly tighter", "polling-chain terminate: longer chains").
