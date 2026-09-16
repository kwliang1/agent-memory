---
name: Surface plan file paths for IDE review
description: When a plan file is large enough that the iterm-rendered ExitPlanMode preview is hard to scan, give the user the absolute path so they can open it in their IDE.
type: feedback
originSessionId: ceb48a67-d4b7-47ac-bbed-9e209cf22b36
---
When you've written a long plan file (especially anything more than a few hundred lines), surface the absolute path **before or alongside** calling ExitPlanMode so the user can open the file in their IDE (RubyMine for this project) instead of trying to read it in iterm's preview.

**Why:** The user explicitly asked for the file name to open the plan in their IDE because it was too big to view in iterm. ExitPlanMode's rendering doesn't fit large plans on the user's terminal.

**How to apply:** For any plan file you write, in the message that includes the ExitPlanMode call (or just before), state the absolute path on a clear line. Default form: "Plan file: `<absolute path>`. Open in your IDE for review." — then call ExitPlanMode.
