---
name: slack-attachments-thread-reply-bug
description: Kevin's image attachments never reach the bridge (download_attachment says "no attachments", no downloaded_files) because they're thread replies and the download path only queries top-level conversations.history. Workaround = pull them myself via conversations.replies + SLACK_BOT_TOKEN.
metadata:
  node_type: memory
  type: reference
  originSessionId: 0e543ade-488f-42be-95ee-8849ec3b5a75
  modified: 2026-09-08T21:08:26.082Z
---

**Symptom (recurring):** Kevin sends an image; the `<channel>` tag shows `attachment_count="1"` but NO `downloaded_files`, and `download_attachment` returns "message has no attachments". `fetch_messages` separately throws `undefined is not an object (evaluating 'id.indexOf')`.

**Root cause (confirmed 2026-07-29, after two WRONG guesses — it is NOT "Slack gateway can't download files" and NOT "missing files:read scope"; the code at `slack-gateway.ts:607-624` downloads fine and `files:read`+`files:write` ARE granted):** the DM is **threaded** (thread_ts e.g. `1784760457.689249`), so Kevin's attachment messages are **thread replies**. The bridge's download path (`slack-gateway.ts` `downloadFiles`, ~line 588-604) resolves the message via **`conversations.history`** (`latest=<ts> inclusive limit 1`), which returns only top-level messages — it hands back the wrong/older message, code does `messages[0]` without verifying ts → `msg.files` empty → "no attachments". Real hydra fix: use `conversations.replies` (with the thread_ts) when the target message is a thread reply.

**WORKAROUND — retrieve the image myself (works):**
```bash
env=/Users/kevin/.claude/channels/slack/.env
BT=$(grep -E "^SLACK_BOT_TOKEN=" "$env" | head -1 | cut -d= -f2- | tr -d '"'\''')   # do NOT echo the token
# find the file in the THREAD (top-level history will NOT have it):
curl -s -H "Authorization: Bearer $BT" "https://slack.com/api/conversations.replies?channel=<DM_ID>&ts=<THREAD_TS>&limit=50" \
  | jq -r '.messages[]|select(.files)|.files[]|"\(.ts) \(.name) \(.url_private_download // .url_private)"'
# download with the bearer token:
curl -s -H "Authorization: Bearer $BT" -o /path/out.png "<url_private_download>"
```
Get THREAD_TS from the daemon log line `daemon: thread routing: … effectiveThreadId=<DM>:<ts>`. The DM id is `D0BE3RB4Y00`. Then `Read` the saved PNG. Never print the token value. `python3` is NOT available (asdf shim, no version set — exits 126/"No version is set"); use `jq`.

**OUTBOUND is broken the same way (confirmed 2026-09-08):** the `reply` tool's `files: [...]` param on a threaded DM returns success ("sent") and the file DOES upload to Slack, but it never surfaces to the user in the thread — so they see nothing. Frustrated Kevin twice. Don't rely on `reply` `files` for attachments; upload directly:
```bash
env=/Users/kevin/.claude/channels/slack/.env
BT=$(grep -E "^SLACK_BOT_TOKEN=" "$env" | head -1 | cut -d= -f2- | tr -d '"'\'' ')   # never echo it
F=/abs/file.csv; LEN=$(wc -c < "$F" | tr -d ' ')
R=$(curl -s -H "Authorization: Bearer $BT" "https://slack.com/api/files.getUploadURLExternal?filename=file.csv&length=$LEN")
UP=$(echo "$R"|jq -r .upload_url); FID=$(echo "$R"|jq -r .file_id)
curl -s -F "file=@$F" "$UP" >/dev/null
curl -s -H "Authorization: Bearer $BT" -H "Content-Type: application/json" -X POST https://slack.com/api/files.completeUploadExternal \
  -d "{\"files\":[{\"id\":\"$FID\",\"title\":\"file.csv\"}],\"channel_id\":\"D0BE3RB4Y00\",\"thread_ts\":\"<THREAD_TS>\",\"initial_comment\":\"…\"}"
```
`channel_id`=`D0BE3RB4Y00`, `thread_ts`= the second half of the chat_id. completeUploadExternal's response may have control chars that break `jq` locally even on success — verify via `conversations.replies` (look for your file id) rather than trusting the parse. For plain-text files, also paste the content inline as a fenced block so the user gets it regardless.

Related: [[bridge-is-slack]], [[reply-chat-id-must-be-thread]], [[disconnected-live-sessions-bridge-death]], [[bridge-outbound-dead-curl-fallback]].
