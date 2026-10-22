---
name: feedback_pr_comments_in_diff_order
description: "Inline PR comments are read in diff order (files alphabetical, then line); a comment that says 'if X goes' must not depend on a comment that appears later in the diff"
metadata:
  type: feedback
  originSessionId: 6df95c8e-6a45-47e8-828f-c4b8a643b40e
  modified: 2026-10-14
---

When drafting a set of inline PR comments, order and word them for how a reviewer reads a diff: files alphabetical by path, lines ascending. A comment on `app/services/investment_vehicle_configurations/...` is read before one on `app/services/sub_accounts/...`, so "not needed if the IVC hop goes" pointed at a comment the reader hadn't reached. Kevin edited it to "(see below)" and told me to "see the consideration for comment ordering within the context of a diff review" (2026-10-14).

Also: when a comment leans on a decision made elsewhere (e.g. "authorization is nova's problem now"), link the Linear issue that records it so the author has context.

**How to apply:** sort the comments array by (path, line) before posting; make each comment stand alone or say "above"/"below" correctly; put the cross-cutting ask in the review body, which renders first. Link the Linear issue for any policy claim. See [[feedback_external_writing_style]], [[feedback_link_linear_issues_in_comments]].
