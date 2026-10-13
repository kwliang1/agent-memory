---
name: feedback_verify_fixture_assumptions
description: Before citing a live record as proof a mechanism works, verify it has the properties the test assumes — a fixture picked off the top of a list proves nothing.
metadata:
  node_type: memory
  type: feedback
---

Ran a new CI script against "an open PR off the top of `gh pr list`" and reported the passing
result to Kevin as evidence the mechanism worked. A reviewer then showed the PR had a **non-main
base** (a Graphite stack), so under the real env var the script would no-op — my run only passed
because I had hardcoded the variable to the value I expected. The evidence proved the mechanism
works on a path production never takes.

**Why:** a live record is not a controlled fixture. Picking the first one off a list silently
selects for whatever is most recent, not for the properties under test.

**How to apply:** before using a real PR/account/row as proof, state the properties the test needs
and query them (`gh api .../pulls/N --jq .base.ref`, etc.). Then run the **unset/default** case too
— if a variable's real value differs from your stub, you tested your stub. Cover both the typical
and the awkward instance (stacked base, conflicting, stale). Relates to
[[feedback_verify_new_assertions_can_fail]] and [[feedback_verify_reviewer_negative_results]].
