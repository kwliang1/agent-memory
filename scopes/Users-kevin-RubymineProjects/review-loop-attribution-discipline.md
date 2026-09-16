---
name: review-loop-attribution-discipline
description: "In a long multi-round review loop, never tell reviewer B that finding X was 'yours' without checking the transcripts — I did it twice and both reviewers caught it"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: f47c16b3-3921-4f56-973d-9f74cd90f794
  modified: 2026-07-29T07:39:42.870Z
---

In a long review loop with several concurrent reviewer agents, **verify who actually raised a finding before attributing it back to anyone.** Grep the agent output files under the session's `tasks/` dir for distinctive phrasing; don't reconstruct from memory.

**What went wrong (BANK-1544 loop, 11 rounds, 2026-07-28/29):** I twice attributed a finding to the wrong agent, both times confusing the round-1 engineering reviewer with the round-6 fresh completeness reviewer.
1. I asked the round-6 reviewer to certify that a new constants spec didn't contradict "his" earlier objection to deleting one. That objection was the round-1 reviewer's. He refused: *"a PR body shouldn't launder one reviewer's argument through another's name."*
2. I then told the round-1 reviewer that the `create_service.rb:57` prefilter-literal finding was his round-2 item. It wasn't — it was the round-6 reviewer's. He listed his actual findings back to me and said: *"you're using attribution to decide who certifies what, which is the exact failure mode you're writing to fix."*

**Why it matters:** in this loop I was deliberately routing "does my fix faithfully resolve your finding?" back to the originating reviewer, because that reviewer has the context to judge. Misattribution asks someone to defend a position they never took, and invites them to rubber-stamp reasoning they can't actually check. Both agents caught it; a less careful one would have agreed.

**How to apply:** before writing "your finding #N" or "you asked me to X", grep the transcripts. When summarising another reviewer's argument to a third party, name it as another reviewer's and say so. Cheap check: `grep -l "<distinctive phrase>" <tasks-dir>/*.output`.

Corollary that worked well: asking reviewers whose earlier positions were later **overturned** to accept or defend the reversal in their own words. Both did, and both articulated the generalizable error (one: "I applied a no-regression bar to net-new code"; the other: "I reasoned from present reachability about a guard whose purpose is to be the backstop when reachability changes"). That is much stronger evidence than only polling reviewers who already agree.

Related: [[treasury-worktree-dev-loop]], [[treasury-spec-tasks-maintenance-flake]].

## Verify the BASE before characterising a delta (2026-09-11, nova #9989)

Any claim of the form "this is better/worse than before" needs the base's own copy of the file in front of it — never a read of the working diff or of a version you looked at last round. **Resolve the base relationally, never as a pinned SHA:** `git show "$(git merge-base origin/main HEAD):<path>"`, or `<branch-head>^:<path>` while the branch is a single commit.

**On a stacked branch, `merge-base origin/main` is the wrong base** (added 2026-09-15): it returns the fork point from trunk, so the delta silently swallows every parent-branch commit — the same mis-characterisation this rule exists to stop, in the same flattering direction. Since Graphite is mandatory for branch work, the stack parent is the real base: `gt down` checks it out, `gt log` prints the stack graph. Fall back to `merge-base origin/main` only when the branch sits directly on trunk. A hardcoded base SHA goes stale the moment you rebase, and the error it then produces runs in the same flattering direction one level up — somebody else's merged improvement reads as your branch's work. On a long-lived branch there are three states in play (base, your intermediate revisions, current), and "pre-refactor" silently means "the version I last read."

This trap caught **two different reviewers on the same branch**, and both times the error direction **flattered the diff**:

- A reviewer reported that deleting `RowsTable` settle-gate tests lost coverage. It had diffed against `HEAD` (my intermediate commit) rather than the stated base; main never had those tests. Retracted.
- A reviewer reported that a dependency-array change "strictly removes spurious timer restarts" — an improvement over shipped behaviour. `git show db3dd3429d:…/index.tsx` showed the base deps were `[refetch]` and that `listIsWorking` did not exist on main at all. The spurious-restart window existed only between my own hook extraction and its fix, so the change restored parity rather than improving anything. Paragraph struck.

A reviewer caught exactly this in my first draft of this note: I had written "always `git show db3dd3429d:<path>`", and after the branch rebased onto main that SHA was 18 commits behind the real merge-base, making `git diff --stat db3dd3429d` report 213 files instead of the PR's 9.

**How to apply:** when a reviewer hands you a "better/worse than before" claim, run the `git show` yourself before repeating it to Kevin — a flattering error is the one you're least likely to question. State which of the three states you mean ("vs main", "vs my intermediate version") rather than "pre-refactor". Same discipline as [[nova-worktree-lightweight-verify]] item 8 (prove it against the base, don't assert it).
