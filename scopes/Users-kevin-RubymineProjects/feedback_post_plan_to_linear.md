---
name: Upload approved plan markdown to the Linear issue
description: After a /plan is approved and the branch is associated with a Linear issue, post the plan content as markdown to that Linear issue
type: feedback
originSessionId: 5373b9a5-1979-4b34-ad89-cd2d64bd29d2
---
After the user approves a plan via ExitPlanMode AND the plan is associated with a Linear issue (i.e., a `kevinliang/<issue-slug>` branch + USVC-XXX or similar reference), upload the approved plan markdown to that Linear issue automatically.

**Why:** The user explicitly asked: "after I approve this plan should be uploaded as a markdown file in the linear issue." The Linear issue becomes the source of truth for design context that reviewers, future-Kevin, and downstream collaborators can find without having to dig through Claude session history.

**How to apply:**
- Trigger: ExitPlanMode approved AND a Linear issue ID was referenced in the plan (or in the conversation prior to plan finalization).
- Mechanism: post as a comment on the Linear issue using `mcp__linear__save_comment` with the full plan markdown body. Comment is non-destructive (doesn't clobber the issue description).
- Do this immediately after approval, before starting implementation work — the plan's value as documentation is highest at hand-off, not after edits start.
- Do NOT do this for plans that are not associated with a Linear issue.
