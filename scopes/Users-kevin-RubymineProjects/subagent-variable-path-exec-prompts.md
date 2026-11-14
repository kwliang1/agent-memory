---
name: subagent-variable-path-exec-prompts
description: Review subagents stall on permission prompts from unparseable commands — a variable script path ($h) or zsh nested expansions — so brief literal paths and bash-plain one-liners
metadata:
  type: feedback
---

On 2026-11-03, a round-16 domain reviewer on agent-memory stalled twice, for 30 minutes and then 3.2 hours, while the session sat unattended. Both times the command defined a shell function that ran `timeout 20 $h UserPromptSubmit`, with `$h` looping over a base-hook copy in /tmp and the worktree hook. Its other ~120 calls auto-ran, including the same hook called by a literal path. Kevin asked why it "stopped for a prompt" and what command was invasive. The answer: nothing was invasive. The transcript doesn't record the prompt's reason, so the trigger is inferred, not confirmed.

**Why:** an unattended prompt in a subagent blocks the whole gate round until Kevin is back. A prompt that fires while he's away (afk, laptop asleep) reads as a hang.

**How to apply:** in every reviewer or verifier brief, require hooks and scripts to be run by literal path, never as `$var args`. If a reviewer's transcript goes quiet, check for a pending tool_use before assuming the laptop slept. See [[review-gate-playbook]].

**Second trigger, confirmed by a screenshot (2026-11-04):** the checker reported "Dangerous rm operation not ruled out — the shell may read this command differently than it was parsed" on a command with no `rm` at all. It held zsh nested expansions (`${${f#*.}%.out}`, `${f%%.*}`) inside a `for f in $(cd x; find …)` loop. Unparseable expansions are what fire the prompt. Brief reviewers to keep one-liners in plain bash syntax, and to put zsh code in a script file run by literal path.

**Third trigger, and a repeat miss (2026-11-04):** `rm $T/$f` inside a for loop fired "Dangerous rm operation on possibly-empty variable path". The command was safe, since T was set inline to a scratch copy. The cause was the briefing session, which had this memory and still didn't put the rule in the round-4 brief. Kevin: "I thought we addressed this?? grrrr". A rule that lives only in memory doesn't reach the brief. It belongs in CLAUDE.md gate step 2.
