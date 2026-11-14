---
name: feedback-always-full-links
description: Never hand Kevin (or a reader like Bisher) a bare path such as /admin/flipper/...; always a full clickable URL
metadata:
  node_type: memory
  type: feedback
  originSessionId: 19c2100b-ace4-4983-a79e-e378a82b91c1
  modified: 2026-11-04T00:22:45.473Z
---

Always give a proper, full clickable link — never a bare route path like `/admin/flipper/features/x` "in venture admin".

**Why:** Kevin, 2026-11-03, on BANK-2354: "no. always give a proper link" after I wrote the Flipper path as inline code.

**How to apply:** resolve the real host first (grep the repos for an existing absolute URL; don't guess). Known hosts: venture admin = `https://venture.angellist.com/admin/...` (Flipper at `/admin/flipper/features/<flag>`), nova admin = `https://portal.angellist.com/admin/...`, ipseity = `https://ipseity.internal.angellist.com/admin/...`. Give each link a label ([[feedback_link_linear_issues_in_comments]]). PRs in Linear descriptions are the exception: cite by branch to avoid auto-attach ([[linear-pr-url-in-description-attaches-pr]]).
