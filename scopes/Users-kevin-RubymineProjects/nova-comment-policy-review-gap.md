---
name: nova-comment-policy-review-gap
description: nova AGENTS.md comment policy is strict; police it when writing code AND in review-agent briefs (missed twice on NOVA-3786)
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 7aa4f111-4f38-47ef-8600-37ef55b2247d
  modified: 2026-08-16T05:43:36.466Z
---

On nova PRs, enforce the repo's **comment policy** — it's stricter than most and reviewers/bots (Cursor Bugbot) + Kevin actively flag violations. On NOVA-3786 I shipped a schema file that broke it twice (ticket refs in comments, then a 16-line file-header block), both caught in PR review, not by my gate.

**The rules (nova AGENTS.md):**
- **Never add comment blocks at the top of files** — no file-header narrative/docstring. Comments go on functions/types/non-obvious logic only.
- **Never put ticket numbers in code comments** — no `NOVA-####`, `#1234`, `MER-####`, Figma ids. The comment must stand alone; ticket refs belong in the PR/commit.
- **Default to no comments**; cut fluff that restates the code. A comment earns its place only for a hidden constraint / non-obvious WHY.

**Why:** violations rot and get flagged, costing extra review rounds. **How to apply:** (1) write nova comments terse-WHY only, no headers/tickets; (2) put narrative (what/why/context) in the PR description + link the design doc, not the code; (3) **add "police comment policy" to every nova review-agent brief** — my 5-round schema gate passed clean while missing both violations because the brief only checked correctness/migration-safety, not comment style. Related: [[nova-3786-staging-schema]], [[nova-worktree-dev-gotchas]].
