---
name: hook-context-10k-cap
description: "Hook additionalContext over 10,000 chars is swapped for a file path + 2k preview; memory-scope.sh hands worktrees 19-20KB indexes, so they see ~2k"
metadata:
  node_type: memory
  type: reference
  originSessionId: cda8120a-e831-4b4b-a893-45908489eafa
  modified: 2026-10-13T16:43:45.724Z
---

Claude Code caps a hook's `additionalContext` / stdout at 10,000 characters (https://code.claude.com/docs/en/hooks). Over it, the text goes to a file in the session dir and Claude gets the path plus a 2,000-char preview, and is not told to read it. No setting raises the cap.

On 2026-10-13, `memory-scope.sh` on agent-memory main injected the full parent index into worktree sessions: treasury 19.4KB, nova 20.1KB, umbrella 17.7KB. So worktree sessions saw only the first ~2k. The in-flight branch `kevinliang/scope-index-on-topic` caps at 8000 and cuts the rest with a `cat` pointer.

**How to apply:** size any hook-injected index under ~9k chars, not under Claude Code's 200-line/25KB MEMORY.md limit. Related: [[project-memory-miss-audit-2026-10]].
