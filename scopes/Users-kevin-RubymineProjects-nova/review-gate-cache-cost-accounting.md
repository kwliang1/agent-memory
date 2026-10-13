---
name: review-gate-cache-cost-accounting
description: How to cost a session correctly (subagents are a separate bucket; dedupe on message.id-last) and the two structural wastes the pre-push gate creates
metadata:
  node_type: memory
  type: feedback
  originSessionId: fb2c3e87-3f79-4685-8cab-fd7094f08e48
  modified: 2026-09-29T17:55:01.565Z
---

Measured on BANK-2122 / PR #10576 (+240/−18, 12 files): **$181.40 · 217.8M cache read · 968
requests**, Opus 5 list ($5/$25; cache read $0.50, 5m write $6.25, 1h write $10; no 1M premium).
Cache read was 61% of spend, ~$0.75 per changed line, ~10× the implementation cost.

**Why:** cache read bills the whole prefix **per request**, so cost is `requests × context size` and
grows quadratically with session length — the same tool call at turn 300 costs ~3× turn 50. Context
ran 25K → 684K with no compaction.

**Three counting traps, all of which I hit:**
1. **Subagents are a separate bucket.** The main transcript is `isSidechain: false` throughout;
   reviewer usage lives in `<session>/subagents/agent-*.jsonl`. On this PR that was **84.3M cache
   read / $76.98** invisible to the main total.
2. **`subagent_tokens` in a completion notification is not cache reads.** Summing it gave 3.3M
   against an actual 84.3M — **25× off**. Open the transcripts; don't reuse the number in context.
3. **Dedupe on `message.id`, taking the LAST row.** One row per content block shares a `message.id`;
   input fields repeat but `output_tokens` is a growing streaming snapshot. Naive row-summing
   inflates cache read **1.96×**.

**Two wastes the gate causes, both fixable:**
- **5m cache TTL expiring while waiting on reviewers.** 11 re-writes >100K (4.31M tokens, **~$25
  avoidable**), each after a 5.4–11.3 min idle. Only the first 41,677 tokens used the 1h TTL. Put
  history on 1h TTL, or send a `max_tokens: 0` keep-alive before each round.
- **Cosmetic follow-ups at the end of a long session.** The post-push tail (screenshots, a Mermaid
  diagram, a Raindrop lookup) cost **$28.81** vs **$14.61** for the whole plan-and-build — trivial
  work billed at 530–684K of context. **Run follow-ups in a fresh session.**

Also: reviewer agents twice left mutation scratch (`zzmut.ts`, `_mutHelpers.ts`) inside `app/src`,
where vitest's default include runs it and `gt modify -a` would commit it. Tell read-only reviewers
to keep scratch in `/tmp`, and check `git status --porcelain` for `??` before every commit.

See [[hydra-raindrop-session-id-mismatch]] and [[feedback-two-reviewers-per-round]].
