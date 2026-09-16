---
name: bridge-outbound-dead-curl-fallback
description: "When the bridge reply tool silently drops outbound (ACKs but never posts), reach Kevin by curl chat.postMessage to the thread he's actively watching; verify with conversations.replies."
metadata: 
  node_type: memory
  type: reference
  originSessionId: 39e25e7a-10d0-4be9-b8a1-f260891e5fc4
  modified: 2026-07-31T00:28:06.425Z
---

Failure mode seen 2026-07-30 (heavy daemon flapping — dozens of "Recovery report — back online after 17–42m outage" from the daemon bot in the DM main channel): the bridge **outbound** dies while **inbound still works**. The `reply` tool returns `sent (id: <ts>)` and `fetch_messages` looks normal, but the message NEVER posts. Do not trust either:

- `list_sessions` / daemon vitals can report a session `status: "connected"` while its outbound is in fact broken — the label lags. Verify posting empirically, not by the status field.
- `fetch_messages` only reads top-level `conversations.history`, so it can't see thread replies at all (see [[slack-attachments-thread-reply-bug]]) — it is NOT evidence a reply did/didn't land.
- `reply`'s returned message id is an **optimistic/fake ts**; a real Slack `chat.postMessage` returns `ok:true` + a real ts.

**Reliable outbound fallback** (bot = `senna`, bot_id B0BD5UVSD61; `SLACK_BOT_TOKEN` is in env, also `~/.claude/channels/slack/.env`):
```
curl -s -X POST https://slack.com/api/chat.postMessage \
  -H "Authorization: Bearer ${SLACK_BOT_TOKEN}" -H "Content-Type: application/json; charset=utf-8" \
  --data '{"channel":"D0BE3RB4Y00","thread_ts":"<ts>","text":"..."}' | jq '{ok,ts,error}'
```
Build the JSON with `jq -n --rawfile text f.txt --arg ch ... --arg tts ... '{channel:$ch,thread_ts:$tts,text:$text}'` (python3 is shimmed off; use jq). **Verify it landed** with `conversations.replies?channel=D0BE3RB4Y00&ts=<thread_root_ts>` — NOT fetch_messages.

**Which thread to post into:** post into the thread Kevin is ACTIVELY watching, which may NOT be your registered `thread_id`. When a session's checkpoints don't reach him he often opens a NEW top-level msg like "<name> seems to be dead"; the main session (user U0BD78J1M9C = senna) relays there too. Read `conversations.history?channel=D0BE3RB4Y00` to find his latest top-level message / active thread, then reply in THAT thread_ts. Posting to your own dead registered thread = invisible to him. Kevin's user id = U056CLXJY8P.

Related: [[disconnected-live-sessions-bridge-death]] (that note says `/mcp` fixes it — but here `/mcp` did NOT, because the break was gateway-level, not session-level: `~/hydra-slack-daemon.log` showed `slack gateway: connection stale (Ns since last event) … reconnected`). Gateway-level staleness self-heals on reconnect or a bash `restart-daemon.sh` ([[daemon-restart-via-bash-not-cli]]); it drops all outbound during the gap. **Kevin restarting the MCP process (his side) also revives the `reply` tool mid-session** — after that, prefer the `reply` tool again over curl.

**Registered-thread-is-itself-a-reply quirk (2026-07-30, cost real confusion):** a spawned session's registered `chat_id` (`D0BE3RB4Y00:<ts>`) can point at a message that is ITSELF a reply inside another thread (check: `conversations.replies?ts=<my_ts>` returns one msg whose `thread_ts` ≠ its own ts). Slack has only one thread level, so: (1) the `reply` tool posting to my `<ts>` actually lands in the PARENT thread (`thread_ts`), which is correct/visible; but (2) if Kevin clicks "reply in thread" on my registered message he opens an EMPTY sub-thread (a reply can't host children) and sees nothing — he'll say "I don't see it / slack bug." Tell him to open the PARENT thread (the "<name> seems to be dead" root), not my message. Confirm placement with `conversations.replies?ts=<parent_root_ts>`.

**Don't tear down the worktree while the user is still actively reviewing** — I cleaned up `.worktrees/treasury-8067-final` after "done", then Kevin sent a large review batch and I had to `git worktree add` again (full 5866-file checkout). Keep the worktree until the PR is actually merged/abandoned.

**New variant 2026-09-10 — the tool HANGS instead of fake-ACKing.** `reply` did not return `sent (...)`; it ran past 120s and the harness backgrounded it ("moved to the background as task <id>, keeps running"). The message had NOT posted. Handling that worked, in order:
1. **Verify before re-sending** — `conversations.history?channel=D0BE3RB4Y00&limit=5` (top-level DM replies are top-level messages, so history IS valid evidence here; only *thread* replies are invisible to it). Kevin's question was the newest message → confirmed dropped.
2. **`TaskStop` the backgrounded tool call first**, or it may land later and duplicate the curl post.
3. curl `chat.postMessage` as below, then re-check history for a real ts.
Also: raw `chat.postMessage` does NOT get the bridge's markdown→mrkdwn conversion. Write Slack mrkdwn by hand — `*bold*`, `_italic_`, `<url|label>`, `• ` bullets. GitHub-style `**bold**`, `## headings` and `[label](url)` render literally. Build the payload with `jq -n --rawfile text <file>` (heredoc the text to a temp file); set `unfurl_links:false` so a pile of GitHub file links doesn't unfurl.
