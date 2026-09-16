---
name: ci-failure-via-chrome-skill
description: "Personal skill exists for pulling a red CI build's actual failing example via Claude-in-Chrome when there's no CI token; lives in ~/.claude, so bridge sessions won't auto-list it"
metadata: 
  node_type: memory
  type: reference
  originSessionId: efbf16a9-1291-492d-bd66-682b2f8fd832
  modified: 2026-07-29T03:16:43.021Z
---

A personal skill `ci-failure-via-chrome` lives at `~/.claude/skills/ci-failure-via-chrome/SKILL.md` (created 2026-07-28). It packages the workflow for extracting a red CI build's actual failing test/example when there's no CI-provider token/CLI and Datadog has no test data: verify the failure via `gh .../statuses` (Buildkite = commit statuses, not check-runs), rule out a base/flake, then drive Kevin's authenticated Chrome via Claude-in-Chrome to the failing job URL, `get_page_text`, parse with `node` (python3 shim is broken here), handle the virtualized-log tail (scroll/"Jump to end"), diagnose your-change-vs-flake, and Retry to confirm a flake.

IMPORTANT: this bridge session is pinned to `CLAUDE_CONFIG_DIR=~/.claude-byte`, so the skill does NOT appear in this session's skill roster — but it's real and Kevin's normal Claude Code sessions (`~/.claude`) load it. If a CI failure comes up here, follow the SKILL.md steps manually (read it) rather than assuming no skill exists. `~/.claude` is not a git repo, so the skill is intentionally not checked in. See [[claude-config-topology]], [[treasury-outgoing-transfers-resolver-flake]].
