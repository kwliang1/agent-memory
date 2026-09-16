---
name: slack-no-bold-bare-urls
description: Slack formatting — never wrap a bare URL/link in bold; it renders literal asterisks or breaks the link
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 74df7565-7856-4e0c-96cf-2772ee7c849d
  modified: 2026-08-05T03:56:06.610Z
---

On the Slack/Discord bridge, NEVER bold a bare URL or a link. Writing `**https://github.com/...**` makes Slack auto-link the raw URL and then fail to apply bold, so it renders literal `*` characters around the link (or breaks the link). Kevin has flagged this more than once ("you still have a problem with links in slack when it seems you intend to bold them").

**Why:** Slack mrkdwn can't format an auto-linked URL, and bold formatting inside link display text (`<url|text>`) doesn't render either.

**How to apply:**
- Use a labeled link: `[PR #185](url)` — not `**url**`.
- Want emphasis near a link? Bold ADJACENT plain text, never the link itself: `**PR up:** [#185](url)`.
- Bold is for plain words (names, dates, statuses), never for URLs or link text.
