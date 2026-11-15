---
name: subagent-hook-and-memory-facts
description: What Claude Code subagents actually get from hooks and auto-memory (CLI 2.1.318), verified from logged payloads and transcripts; sub-agents.md is wrong on auto-memory
metadata:
  type: reference
---

Verified 2026-11-03 on CLI 2.1.318 (logged payloads via `claude -p --settings <probe.json>`, plus subagent transcripts):

- Subagent PostToolUse/PreToolUse payloads carry `agent_id` + `agent_type`; main-thread payloads omit both. `session_id` is the parent's.
- SessionStart and UserPromptSubmit never fire for subagents.
- SubagentStart payload: agent_id, agent_type, cwd (parent's), session_id, prompt_id, transcript_path (PARENT's). **No prompt.** At that moment the subagent transcript doesn't exist and the parent's doesn't yet hold the Agent tool_use. PreToolUse(Agent) fires first and has the prompt, but has no agent_id to pair with.
- SubagentStart `additionalContext` does reach the subagent.
- **Subagents DO load their cwd's auto-memory MEMORY.md** (an `attachment` row, `isSidechain:true`), even though sub-agents.md "What loads at startup" says they don't. Don't re-inject it.
- The Agent PostToolUse `tool_response` holds `agentId` + `prompt`, which is how to map tool_use_id to agent_id after the fact.

Used by the agent-memory PR "Give subagents their own memory-hook state" ([[hook-context-10k-cap]]).
