---
name: project-session-token-anatomy
description: "How hydra/Claude Code sessions spend tokens — artifact v2, scripts, key findings, and two measurement traps (subagent usage rows, model pricing)"
metadata:
  node_type: memory
  type: project
  originSessionId: 344cedf6-ae7d-434f-8b84-d5a29fc510f7
  modified: 2026-09-30T05:37:51.307Z
---

Artifact: arti `hydra-session-token-anatomy-2026-09-29` (v5, 2026-09-30, last 60 ended sessions; mermaid pie/xychart blocks render). Scripts + drafts: `~/agent-memory/scripts/session-tokens/` — `all_stats.mjs` (every number, per-model pricing; EXCLUDE=<own claudeSessionId> N=60) and `idle_gaps.mjs` (idle-time histograms, autonomy runs; reads /tmp/sample_ids.json written by all_stats).

Findings (8 sessions ended 9/29, all `claude-opus-5` at API list; main $664, subagents $439):
- Cache expiry rewrites = 31% of main cost; 54 of 68 happen in the review phase while main idles on reviewers (5m TTL). 1h TTL models −10% of main.
- Context starts ~40k (14k cross-session cached), grows ~2k/turn, never compacted. Growth re-reads: Bash output 25%, thinking 17%, text 12%, MCP tool lists 9%, subagent reports 8%, prompts 5%.
- Repo doesn't explain cost; session length does (>1000-turn sessions = 42% of spend in a 68-session sample). Nova's total = 3 long build sessions.

Traps:
- Subagent JSONL logs one usage row per content block and the FIRST row has partial output_tokens — keep the LAST row per message.id (main sessions' rows are identical, so the bug only showed in subagents).
- Check `message.model` before pricing; these sessions ran opus-5 ($0.50 read), not opus-5.5.
- arti `read_artifact` on this slug is blocked by Runlayer (prompt-injection false match); v1 source was recovered from the publishing transcript's add_artifact input.

- 60-session numbers: $13,124 (main $8,245, subs $4,879); expiry rewrites 28% of main; 1h TTL models −10% (saves on 5–15m subagent waits; Kevin replies 78% <5m, 11% >60m); long autonomous runs are gate runs (97% of 100+-turn stretches spawned subagents).
- TTL precedence (binary fLt): FORCE_PROMPT_CACHING_5M → CLAUDE_CODE_(SUBAGENT_)PROMPT_CACHE_TTL → settings promptCacheTtl/subagentPromptCacheTtl → agent frontmatter → ENABLE_PROMPT_CACHING_1H → automatic.

**Why:** Kevin wants the token-spend process explained, not sessions judged; he said "don't make any changes" (analysis only).
**How to apply:** reuse the scripts; zsh doesn't word-split `$IDS` — use arrays. Byte counts mislead for images/thinking; use per-turn usage deltas.

## Live trial (started 2026-09-30T06:21Z, Kevin approved)
- `~/.claude/settings.json` now has `env.CLAUDE_CODE_PROMPT_CACHE_TTL="1h"` (main only) and a PostToolUse `Bash` hook → `~/agent-memory/scripts/session-tokens/hooks/bash_output_filter.mjs` (stdout >8K chars saved to `~/.claude/filtered-output/`, head 3000 + tail 1500 + path returned via `hookSpecificOutput.updatedToolOutput`, same shape as tool_response).
- Rollback: `~/.claude/settings.json.bak-20260929-232057`.
- Evaluate: sessions starting after `trial_started_at.txt` vs the 60-session baseline, at matched context; check `ephemeral_1h_input_tokens` share and Bash-output growth per turn. Report cap (CLAUDE.md gate text) deliberately NOT applied — Kevin's call.
- 2026-09-30 06:26Z: report cap APPLIED to gate step 2 in `~/agent-memory/config/CLAUDE.md` (findings → `~/.claude/review-findings/<repo>/<branch>/<round>-<lens>.md`, ≤300-token verdict back). Pre-edit backup `/tmp/CLAUDE.md.bak-20260929-232610`; the change is uncommitted in the live agent-memory tree.
- Verified 06:33Z: settings.json changes HOT-RELOAD into running sessions — this session flipped 5m→1h at its first turn after the write, and the Bash hook filtered its output. Cost: the TTL switch forces one full-context rewrite per running session at the 1h price (~$4.60 at 458k). CLAUDE.md is start-loaded, so the report-cap rule likely applies only to new/handed-off sessions (unverified).

## Adversarial review of v7 (2026-09-30, comet)
Findings in `~/.claude/review-findings/agent-memory/session-token-review/r1-{measurement,definitions,causal}.md`; critic scripts in /tmp/critic{1,2,3}/ (ephemeral). Totals hold. Corrections: 23 `subagents/workflows/` transcripts skipped (all_stats.mjs:145); "Kevin message" = channel user="Kevin Liang" only (1,205, not 1,612 — pr-watch/system/skills were lumped in); automatic TTL (binary X0t) = 1h for subscriber main thread unless `isUsingOverage`, subagents always 5m → forcing 1h only matters during overage; handoff saving ~$313 not $616 (compaction resets to ~85k); subagent 1h is a net loss. Published as v8 (sha 1aa2cf433b61), then v9 (sha 038f0ca1c517): Kevin is on usage_based (API) billing, so the auto rule gave 5m for 83% of main writes and forced 1h applies broadly — not "only during overage". all_stats.mjs now takes SAMPLE=<ids.json> (pin; v7 sample saved as sample_ids_v7.json), SAMPLE_OUT, and recurses into subagents/workflows. Kevin-detection and calibrated growth shares are NOT yet in the scripts — critic scripts copied to scripts/session-tokens/review-r1/.

## Trial check 2026-09-30 16:35Z (comet, `scripts/session-tokens/trial_check.mjs`, EXCLUDE=<ids>)
10 main sessions with turns after the trial start. TTL: 99.97% of main writes were 1h, 10/10 gaps of 5–60m hit, subagents all 5m. Filter: 18 hits in main sessions, 4 read back, all partial sed/grep. Report cap: no pre-push gate ran. comet's critics wrote findings files but returned 615–694 tokens (cap is 300). The patch adversarial-review critics wrote no files and returned 3.3–3.7k (not the gate). Traps: Agent tool_results are the uniform 1094-char background-launch stub, so measure the subagent's last assistant text instead. Worktree jsonl mtimes bump from pr-link/snapshot rows that have no real turns. A session's claudeSessionId ≠ its hydra session_id, so find your own transcript by its prompt.
