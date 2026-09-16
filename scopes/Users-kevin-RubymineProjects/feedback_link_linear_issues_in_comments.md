---
name: feedback-link-linear-issues-in-comments
description: "In GitHub PR comments/replies (and similar prose), hyperlink Linear issue references to their URL instead of a bare identifier"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: cb150723-8a16-47fc-9f46-a1010134e6e4
  modified: 2026-08-26T17:15:59.685Z
---

When referring to a Linear issue (e.g. BANK-1913) in a GitHub PR comment/reply or other written output, link to the underlying Linear issue URL — `[BANK-1913](https://linear.app/angellist/issue/BANK-1913)` — not just the bare identifier.

**Why:** Kevin asked for this directly (2026-08-26). A bare ID forces the reader to look it up; a link is one click.

**How to apply:** Render Linear references as markdown links in PR comments/replies. The `save_issue`/`get_issue` MCP tools return a `url` field — use it (or construct `https://linear.app/angellist/issue/<ID>`). This is distinct from the code-comment rule, which forbids ticket IDs in source comments entirely; and from Linear issue *bodies*, where `BANK-xxxx` auto-links already. Scope: GitHub/Discord prose where the ID would otherwise be inert text.
