---
name: feedback_freeze_tree_during_review_rounds
description: "Commit and then freeze the tree while pre-push review agents run; editing under them wastes a round"
metadata:
  node_type: memory
  type: feedback
---

During the pre-push review gate, **commit the diff and do not touch the tree until every agent in
the round has reported.**

**Why:** on BANK-1997 I applied one lens's findings while two other lenses were still reading. One
reviewer opened its report with "the diff you handed me is stale — the branch moved under me four
times", caught two transient `tsc` errors that belonged to my in-flight edits, and had to retract a
clean typecheck. That round's verdict no longer described any single state of the code, so it could
not count toward the successive-clean requirement.

**How to apply:**
- Commit (amend is fine), capture `git diff origin/main...HEAD` to a file, and pass reviewers that
  file **and** the HEAD sha so they can confirm what they read.
- Tell them explicitly the tree is frozen and to report it if `git status` is dirty — it's a cheap
  tripwire for this exact mistake.
- Apply all findings from the whole round at once, commit, then spawn the next round.
- Corollary: a round only counts if every agent read the same commit.

## Review agents leave scratch files IN the repo

More than once a reviewer wrote probe scripts under `graph/scripts/` or `graph/.perfscratch/` — untracked, **not** gitignored, and one hardcoded the Postgres password on line 3. A `git add -A` would have committed it.

Always run `git diff --cached --name-only` (or `--name-only origin/main...HEAD`) before committing and read the list: every path must be one you edited. Do not rely on `git status` being clean at the moment you stage — the agents write asynchronously, so a file can appear between your check and your `git add`.
