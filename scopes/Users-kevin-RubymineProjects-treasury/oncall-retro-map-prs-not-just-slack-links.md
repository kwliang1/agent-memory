---
name: oncall-retro-map-prs-not-just-slack-links
description: oncall-retro undercounts remediation if fixes are taken only from Slack channel links; map PRs and BANK issues by INC ref
metadata:
  type: feedback
---
On the 10/30 retro (Oct 16–30), readers credited only PRs linked in incident channels, which gave 5 shipped / 17 not done. Kevin said "this feels low" and he was right: 8 incidents had fixes that were never posted in the channel. The corrected count was 6 / 9 open PR / 12 not done.

**Why:** Kevin opens most fixes as BANK issues and PRs whose bodies cite `INC-xxxx`, and he rarely posts them back into the channel.

**How to apply:** before tallying, run `gh pr list --author @me --state all --search "created:>=<start>"` across treasury, venture, nova and ipseity, scan each body for `INC-\d{4}` and `BANK-\d{4}`, and list BANK issues created in the window. Hand each reader its incidents' matches. The retro goes to the Notion page "Nova Foundations On-Call Notes" as a new toggle at the top, not to ~/Documents.
