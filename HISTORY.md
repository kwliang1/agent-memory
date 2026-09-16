# Curation history

This repository was recreated on 2026-09-16 with a fresh history. The original 22
commits could not be published: 20 of them contained customer SSNs in their diffs,
and rewriting them was less certain than starting clean. Nothing else was lost —
the tree is identical to the final commit of that history, and the reasoning for
every change is preserved below.

The full original history, signatures included, is archived locally.

## Import Claude auto-memory under version control

431 memory files across 12 scopes, captured as-is. Each
~/.claude/projects/<scope>/memory is now a symlink into scopes/, so edits are
live and reviewable. Transcripts stay out of the repo.

210 files have no pointer in their scope MEMORY.md and are therefore
unreachable; 27 of those are behavioral rules. Verified against 2,050
transcripts that MEMORY.md is the only retrieval path — index injection appears
454 times, automatic body recall zero.


## Track CLAUDE.md and the bridge context in the repo

Both are symlinked from ~/.claude/ the same way the memory scopes are, so rule
changes become reviewable diffs instead of silent edits.


## Move repo-agnostic rules into CLAUDE.md, keep the detail in memory

20 behavioral rules were reachable only through the umbrella MEMORY.md index, so
any session outside that cwd loaded none of them.

CLAUDE.md now carries the directive for each, so it loads everywhere. Bridge-only
mechanics go to the bridge context, which the SessionStart hook loads only when
CHAT_PLATFORM is set. The index pointers stay: the operational detail (endpoints,
GraphQL vs REST, deploy ordering, the failure that produced the rule) lives in the
memory files and does not fit in a one-line directive.

Cost: +779 tok in a repo session, +890 umbrella, +1509 umbrella bridge.

Also fixes a contradiction this change surfaced: a reply-and-resolve rule written
as "bot or human" authorised exactly what the BLOCKING human-review gate forbids.
Scoped to bots; the human case defers to the gate. Widens the Writing section,
which was scoped to PR text only and so covered neither chat replies nor alert
messages. Extends the serialize-agents override to name the gate step it also
overrides.

No memory file deleted.


## Add a SessionStart hook for memory a cwd cannot reach

Auto-memory keys the index to cwd, which leaves two gaps. A worktree cwd gets its
own empty scope, so 7 sessions running right now load no memory at all. And no
scope can see another, so cross-repo work has no way in.

The hook injects the parent repo index for a worktree cwd, and a scope directory
everywhere. 181 tokens; it does not re-inject an index auto-memory already loads.

Not wired up — settings.json is Kevin's to change, the command is in the PR body.


## Index every treasury memory: 13 of 86 to 86 of 86

Treasury was the worst scope on the machine — 73 of its 86 files had no pointer,
so a treasury session could reach 15% of its own memory. Index-and-keep per
Kevin; nothing deleted.

The sweep surfaced two things worth acting on separately. Twelve of the stranded
files are not treasury-specific at all — they are global working rules, including
one that says Kevin raised the review gate to 5 reviewers per round, which
contradicts the 2-3 in CLAUDE.md and has been unreachable since July. Five more
are venture rules a venture session cannot see. Both groups are grouped under
their own headings rather than filed as treasury knowledge.

Index grows 3,165 to 10,940 bytes, paid only by treasury-cwd sessions.


## Index nova memories and close the human-reply contradiction at every layer

Round-2 review found the bot/human fix had only landed in CLAUDE.md. The memory
file it sends you to for the how still said "bot or human" in its description —
the text the index surfaces — and handed over a runnable gh command for replying
to a human comment. Scoped the description and added a dated correction to the
body. Kevin's words stay verbatim; only the scope narrows.

Two more parallel-spawn instructions were unqualified: gate step 4 and rule 4.
Both now point at rule 7. Adds the PR-description form rule and artifact concision,
both of which existed only in a memory file, and the pronoun default, which
existed in neither config file.

Drops the treasury-specific deploy ordering from CLAUDE.md back to the memory file.

nova: 27 of 45 indexed to 45 of 45.


## Fix two hook bugs, two stale mechanisms, and trim CLAUDE.md

Round-2 review, five lenses, all with findings.

Hook, both reproduced: printf %b processed escape sequences that came out of
MEMORY.md, so a literal backslash-c in any index line silently truncated the rest
of the injection. And matching the first dash-component of a worktree leaf picked
prophet for a prophet-js worktree; longest-prefix fixes it. Also handles conductor
workspaces, guards on jq and on an unreadable index, and converts underscores and
dots in the slug the way Claude Code does.

Mechanisms: the isBot drop is router.ts:295, not :142. build-wt does not exist —
it went with the v1 protocol in d7b6f24, and in a thread it half-matches the build
regex and errors with an unknown model, so the old instruction sent an agent into
a silent failure.

CLAUDE.md: applied the cost review's cut list. No directive removed; incident
narration and restated rationale go back to the memory files. Adds the Graphite
stack parent to the base-verification rule, since merge-base against origin/main
swallows parent commits on a stacked branch, and gives the tasks/ dir a real path.

Also scopes two contradictions this change introduced: the bridge told a session to
write a full structured report while CLAUDE.md caps replies at 1-4 lines, and the
Slack-posting rule did not exclude relaying to a human PR reviewer.


## Restore three directives the cut list took too far

Round-3 fidelity review. The ledger bullet had been trimmed to "idempotent, safe
while the new write path is live" — which reads as the whole safety story and
isn't. The removed part was deploy ordering, and shipping a write path without it
is what inflated one account by $1M. An agent satisfying the trimmed directive
literally reproduces that incident. Scope also went back to double-entry changes
generally, not just ones labelled ledger.

The recommendations rule was dropped rather than subsumed: the chat bullet caps a
channel at 1-4 lines, that one caps a content type in any channel, including inside
a long artifact — which CLAUDE.md now explicitly licenses depth in.

Repair-data lost its counter-objection. "There is no legal transition for that" is
the specific objection that previously talked the agent out of the correct fix, and
the trimmed directive answered nothing at that fork.

Also documents the Graphite stack-parent base in the memory file. Layer 1 was
asserting a mechanism layer 3 never carried.


## Fix a hook regression, two wrong index hooks, and a command that silently no-ops

Round 3, five lenses, all with findings.

Hook: gating the prefix walk on directory-exists rather than index-exists was a
regression my own previous fix introduced — nova-bank-1667, nova-worktrees,
treasury-worktrees, ipseity-worktrees and both usvc-usvc-* dirs exist but have no
scope, so the walk stopped there and injected nothing. Gate on the index instead.
The conductor layout is <repo>/<city>, not <repo>-<city>, so that branch needs an
exact match, not a walk. File counts now use a zsh glob; ls piped to wc counted a
directory named *.md as its children.

Index hooks: two treasury entries asserted state their own file bodies contradict.
The in-progress writer is not a by-design gap, it shipped in #8147 and has been live
since July. The FBO entry is BANK-1666, not BANK-1665, and its IVC question was
resolved as standalone. Both came from description frontmatter that had gone stale —
the body is the source of truth, not the frontmatter.

git rebase --gpg-sign does not re-sign anything without -f: git fast-forwards,
prints "up to date", and leaves the commits unsigned while reporting success. A
reviewer reproduced it in a scratch repo. The treasury memory already had this right.

Also: build-wt was corrected in the memory file, which still claimed it was
thread-only; the gate exceptions list now names rule 6; Sorbet no longer reads as
something to turn off; and the persona crew section points at rule 7, since its
executor edits files.


## Correct four directives that misstate their source

Round-4 fidelity review.

The alert-text rule said "one terse line, same bar as a code comment". The source
prescribes four components for a Datadog message — intro, triage, oncall handle,
markers. An agent that believed the compressed version would strip the routing
machinery and ship a monitor nobody gets paged by.

"Human threads: draft only" read as take-no-action. The source gates only the
reply: resolve freely on anyone's thread, draft and wait before replying to a
human. As written it left fixed human threads sitting open.

The ledger rule attributed the $1M to deploy ordering. The source says BANK-1474
shipped with no backfill planned at all, which is a different and more common
mistake, and it requires the backfill in the same milestone rather than as a
follow-up ticket — the exact out the compressed version left open. (The commit
message on 552f1c5 carries the same misattribution.)

Rule 7 presented worktree isolation as the whole remedy. The source says snapshot
and verify "either way", because each agent restores from its own snapshot.

Also: the hook counted index lines rather than links, so a line carrying two
pointers undercounted; and the README's restore recipe was a merge that kept
anything added since and left the result staged, which Graphite's pre-push hook
auto-commits.


## Count distinct index targets, not link occurrences

nova reads 46 of 45 because one file is deliberately cross-referenced from a
second entry's hook.


## Resolve worktrees with git, and fix six index hooks that contradict their files

Round 4.

The hook matched worktrees by string, so four real ones outside .worktrees/ —
nova-bank-1667, usvc-usvc-673/702, nova-worktrees/wt-mm-comment — fell through and
got nothing. Widening the pattern would have made a plain repo cwd re-inject its
own index, so instead it asks git: rev-parse --git-common-dir names the parent
exactly, and a guard skips anything whose own scope already has an index. That also
fixes conductor sessions, which were being told their scope was empty while its
contents sat in their context.

Six index hooks asserted state their own file bodies contradict. BANK-1492 is not
blocked: the file carries an explicit correction, and the real state is a
prod-validated draft awaiting a ~$9.92M inter-FBO coordination. BANK-1594 is a
2-PR stack, not 3, and the other three are closed. The venture idempotency fix is
an open PR, not shipped, for a collision already seen in prod. Hydra #352 is
merge-ready and needs a daemon restart; the stale-worktree-names entry has no PR at
all. Nova's owner gate was renamed to entity owner, so the hook carried the one
term Kevin rejected.

Two entries fire raw TreasuryPrime book calls with no ledger record. Both are
unexecuted and gated on Kevin confirming live balances, and the hooks now say so.

Also from review: gt down switches branches while gt parent is the lookup; rebasing
a stacked branch onto origin/main strands the parent ref; the tasks/ grep needed -r
and a pattern or it reads stdin and hangs; {N} is not a gh placeholder and the call
needs --paginate. And resolving a human's thread while their reply waits for Kevin
reads as dismissing them, so leave it open.


## Scope memory by repo: 210 unreachable files down to zero

Phase B. Every memory file on this machine now has a pointer in the index of the
scope that loads it.

181 files moved out of the umbrella into the repo whose code they describe —
treasury 90, nova 55, hydra 22, ipseity 8, venture 6. The umbrella keeps the 43
that are genuinely cross-cutting: Kevin's working rules, bridge mechanics, and
tooling that belongs to no repo.

Two passes were needed. The first moved the 77 entries that were already indexed,
carrying each pointer line to the destination. That left 110 orphans, and most of
them turned out to be repo-specific too — they had simply never been indexed, so a
manifest built from the index could not see them. Those 104 moved in a second pass
with hooks generated from their own frontmatter.

The umbrella's per-repo section headers are replaced by a scope directory. Sessions
spawned by hydra run at the umbrella cwd and would otherwise have lost sight of
everything that moved, so the directory names each scope and how to read it
directly. That matters until the SessionStart hook is wired up; after that the hook
supplies the same thing automatically.

Verified against a pre-move backup: the set of filenames is identical, 419 files,
no broken links in any scope.


## Fix the misfilings and blind truncation the phase-B second pass introduced

Five reviewers on the phase-B diff. The first pass held up; the second pass —
104 files auto-classified by filename and auto-summarized from frontmatter —
did not.

Misfiled, all confirmed against file bodies rather than names:
- treasury-mock-ipseity-not-mock-entity-api went to ipseity on the token in its
  filename. It is a treasury file, and its whole point is that CLAUDE.md's
  pre-push `unset MOCK_ENTITY_API` is a silent no-op in treasury because the
  variable there is MOCK_IPSEITY. CLAUDE.md is corrected accordingly.
- inc-5462-piermont went to nova though every code reference and the fix PR are
  treasury; its nova counterpart already lived in nova, so the pair was split
  down the wrong seam.
- alloy-alert-dri-mapping went to ipseity despite its own thesis being that the
  data is not in ipseity. It belongs to the angellist_user_mapping gem, which has
  its own scope.
- n-167 went to treasury; the issue and both call sites are nova.

96 of 104 generated hooks were cut blind at 118 characters. Several inverted their
file: "the human-facing side is" lost "Slack", and one dropped "does NOT fix it"
immediately before the verb. Regenerated from file bodies on a clause boundary.
Five more asserted state their bodies refute — build-wt has no allowlist, the
matchmaking prod gate is on, treasury's cron schedules left cdk8s — and are now
hand-written. Ticket IDs are back in canonical form, with PR numbers distinguished
from Linear IDs by checking each file's own usage.

Bridge mechanics had been split across two scopes on no principle. They govern how
any session talks to Kevin regardless of cwd, so they are back in the umbrella;
hydra keeps its implementation files.

Ten working rules were stranded in the usvc scope, including one setting the
pre-push gate at two clean rounds. They are cross-cutting and now sit in the
umbrella. Four rules whose every trigger is a treasury path moved the other way.

The scope directory now names all eight scopes with counts, states that reading it
is the primary path rather than a fallback, and explains that wikilinks cross
scopes now.

419 files, zero orphans, zero dangling links.


## Rewrite the pre-push gate around the rules that were stranded from it

The gate's own refinements had been accumulating in scopes that never load
alongside it. Folded them back in and resolved the contradictions that created.

- 5 reviewers per round, not 2-3. Kevin raised it on 2026-07-08 and the note has
  sat unreachable in the treasury scope since, so no session outside that cwd
  ever applied it.
- Stop at the second clean round. The usvc scope carried "the bar is 2, not 3 —
  don't add a defensive round"; the gate never said the ceiling out loud.
- Fix only what the finding requires. Reaching further during a gate produced
  four regressions in one session, most of them while fixing an earlier finding.
- Step 5 and performance rule 5 contradicted each other on fresh-vs-same agent
  for the same set of rounds. A round is now always fresh agents; messaging a
  prior reviewer is verification of one fix and does not count as a round.

dry-kiss-review and ts-best-practices both claimed to apply in any session and
any repo while living only in the bridge context, so a terminal session running
the gate silently skipped them. They are gate steps now, and the duplicate copies
are gone.

Performance rule 1 still said 2-3 agents and rule 4 still authorized its own
parallel spawn; both now defer to the gate. Rule 7's cross-reference followed the
renumbering.


## Make git authoritative in the hook, and correct ten hooks that misstate their files

Round 6, five lenses, all with findings.

Hook blocker: git's answer was used only to FIND a parent, never to rule one out.
A repo standing at its own root fell through to the string walk, so an unrelated
treasury-dashboard clone was told it was a worktree of treasury and handed
treasury's whole index. Reproduced. git is now authoritative both ways — if it
answers at all, the walk never runs. That also collapsed three parent-finding
mechanisms into one, so the simplification and the fix were the same edit. A
trailing slash on the cwd defeated the has-index check and re-injected an index
auto-memory had already loaded; the cwd is normalized now.

Index hooks, in descending order of how badly they mislead:
- SEC-829 claimed 2FA step-up guards import and purge. Those guards were removed
  on 2026-09-14; the PR now guards delete alone while its body still says it fixes
  the pentest ticket. Asserting a security control that does not exist is the worst
  shape this class of error takes.
- The Upekkha/IKYAM $198,300 repair reads as in-progress and blocked. It was
  executed 2026-09-01 and verified in prod.
- BANK-1634 reads as blocked on a cert-key mismatch, which a later session proved
  was a misdiagnosis of BNY's own server cert.
- NOVA-3740 reads as shipped, hiding a follow-up PR with auto-merge deliberately
  off and "do not merge without Kevin".
- BANK-1750's hook lost Kevin's finding that the issue premise is inverted.
- BANK-1943 pointed at a base branch that has since merged.
- BANK-1586 reads as unmerged; it is live in prod and has been tweaked twice since.
- Plus post-resign recovery still marked ACTIVE 2.5 months on, a superseded CSV
  design presented as current, and a Slack-attachment note whose truncation hid
  that OUTBOUND is broken the same way as inbound.

Thirteen more files were in the wrong scope, including five that treasury's own
index has been labelling "venture rules filed here by mistake — move them".

Instructions: the treasury mock-unset command was a no-op twice over — those vars
live in .devcontainer/.env and specs run in the container, and `-e VAR=` cannot
disable them because "" is truthy in Ruby. Step 1 opened by saying to match CI's
env and then spent four lines saying to do the opposite. `gt parent` inline turns
`git show ":path"` into the index-stage shorthand, which succeeds against staged
content, so the base is assigned first now. The tasks/ grep needed -R, since those
entries are symlinks and -r silently returns nothing.


## Document the two hazards putting a live directory under git creates

A reviewer established by string analysis of the Claude Code binary — not by
assumption — that a missing CLAUDE.md surfaces as "no rules found" rather than an
error. Other optional config in the same binary carries explicit read-failure
strings; CLAUDE.md does not. So a branch without config/ silently strips every
behavioural rule, BLOCKING gates included, from each session started under it,
while already-running sessions keep their copy. The README now says config/ and
hooks/ must stay on the default branch.

Also documents that git clean -xfd, checkout -- ., and reset --hard destroy
uncommitted memory unrecoverably. Before this directory was a git tree nothing
swept it, so that is the one way the repo is worse than no repo, and it is what
makes committing after a curation pass matter.

And that the git index is shared across sessions, so staging anything here invites
whichever session next runs gt to commit it.

Pushed back on one dry-kiss finding rather than applying it: the third
parent-resolution fallback was called speculative, but usvc-usvc-673 and -702 both
have pruned gitdirs, so git errors on them and only that branch resolves them.
Verified before declining.


## Give the gate an exit when a finding is declined

Rewriting the gate introduced a logic flaw. Step 4 sanctions declining a finding,
but step 5 offered only "address them" and step 7 reset the counter on any feedback
regardless of disposition. A correctly-declined finding leaves the code unchanged,
so the next round of fresh agents raises it again and the counter resets again —
step 8 becomes unreachable and a BLOCKING section stalls forever. The wording I
replaced had "or deliberately push back with reasoning" and did not have this
problem. A declined finding with recorded reasoning no longer resets the counter.

I hit this in the same round it was found, having declined a dry-kiss finding.

Also from review: "read-only lenses" was stated three times and one copy
contradicted the other two on whether an editing reviewer is ever allowed; the
performance section's header called itself optimization while holding two
prohibitions and a round-count change; and gate step 2 had absorbed four of that
list's rules verbatim, so the list is down to what the gate does not already say.
Renumbered, and every cross-reference resolves — one bare "rule 7" was ambiguous
between two numbered lists and pointed at the counter rule when read from the gate.

Step 5's same-agent follow-up named no mechanism, and the mechanism was documented
only in the bridge file, which a terminal session never loads. It also carries a
constraint worth stating where the rule is: a sub-agent cannot do it, so a
sub-agent cannot run this gate.

A reviewer tested my own worry that `$(gt parent)` might exit 0 with empty output
and could not reproduce it — both empty cases exit 1, so the fallback fires.
Left as written.


## Move the rules I only labelled, and restore the gates the migration dropped

Two classes of defect from round 7, both mine.

**Labels are not fixes.** The treasury index carried a heading reading "Working
rules that are NOT treasury-specific — these apply everywhere but were only ever
reachable from this scope", under which twelve rules then sat unmoved. A nova
session still could not read them. Same disease unlabelled in nova (six) and
venture (one). Nineteen moved to the umbrella, where hydra-spawned sessions
actually run. The sharpest: feedback_eyeballs-ack is a pure bridge mechanic and the
bridge session is never at the treasury cwd, so it could never fire where it
applies; feedback_buildwt_clean_round_count governs build-wt spawn syntax and sat
in nova, while build-wt sessions have no memory directory at all.

**The migration dropped operational gates from index hooks.** Fourteen corrected,
two of them dangerous:

BANK-1746 read as a description of a task and its options. Its body says the task
was merged and RUN in prod on 2026-08-10, applied 16 of 17 corrections, errored on
the seventeenth, and left CA 295243 at cash minus $3.04 from a half-applied ledger
repair. The old umbrella hook said "don't run in prod without Kevin"; the migrated
one said nothing.

BANK-1707 read as blocked awaiting a decision. Kevin made it, the task was reworked,
the prod dry run passed, and it is cleared to execute — force-destroying four
LedgerEntries, two BookTransfers and an IncomingWire on a $183,301 chain. The hook
stitched two superseded states together and hid the greenlight.

Also restored: BANK-1445's live ACH-index regression at 121 errors/14d with "do not
merge #8574 without Kevin"; BANK-1787's single approved PR awaiting Kevin; nova
#9436's approved-not-merged gate. Corrected against their bodies: INC-5462 is fixed
in treasury's PDF only and venture still collapses the routing; MMF IVC local e2e
was verified, not blocked; matchmaking scoring is live and its flag deleted, so the
hook's setup advice was dead; build-wt has no allowlist; the two BANK-1943 entries
held each other's content. Two hooks reading only "PR" and "Follow-up PR" now say
what those PRs do.

The three conductor worktree scopes were never swept and nothing loads them. Their
contents are relocated, the treasury one with its "run make graphql from the main
worktree" claim corrected — make graphql orders schema.json differently and fails
CI's cmp. Fixed the home scope's build-wt trailing-number reading, which Kevin
corrected away on 2026-08-19. Added three pointers where one repo owned a fact and
the other was blind: the DIBS ABA table has no institution id, INC-5437's real bug
is live in treasury after an ipseity fix was reverted on the misdiagnosis, and the
venture half of the CPTR backdate trap.

425 files, zero orphans, zero dangling links.


## Read the gitdir pointer instead of guessing a worktree's repo by name

The pruned-gitdir fallback handled one of the three worktree layouts on this
machine. It only ever tested `$base/$cand`, so `<repo>/.worktrees/<name>` computed
the repo root and then threw it away to go hunting for a child, and
`<base>/<repo>-worktrees/<name>` keeps the repo name in the container directory,
which the code never read. 24 live worktrees in each of those two forms; the
fallback covered the 3 in the sibling form. It was masked only because git answers
for everything except the two usvc worktrees, which happen to be that form. Prune
one .worktrees entry and the feature goes dark silently.

The same guessing could also hand an unrelated repo someone else's memory:
`treasury-dashboard-fix`, whose gitdir points at a different checkout entirely,
resolved to `treasury`. The comment two lines above names that exact failure and
the git path prevents it; the fallback put it back.

Both are one fix. Every cwd reaching that branch has a `.git` FILE whose contents
are authoritative, so read `gitdir:` rather than inferring from the directory name.
That deletes the loop and covers all three layouts. Verified against real pruned
worktrees and against the crossing-checkouts case.

Also: the injected sentence claimed "this is a worktree" for any subdirectory of a
repo — `nova/app` is not a worktree and its scope does not go away — so the wording
is conditional now. The conductor branch accepted a parent without checking it has
an index, unlike the other two paths. And the index scan uses `grep -a`, since BSD
grep treats an index containing control bytes as binary and silently counts zero.


## Fix two commands that fail silently, and stop deriving a repo root from its git dir

Verified against the real tools, not reasoned about.

`gh api repos/{owner}/{repo}/pulls/{number} --method PATCH` 404s. gh substitutes
only {owner}, {repo} and {branch}; a literal {number} is not a placeholder. So the
PR-update step that another rule calls mandatory has been silently not landing.
Confirmed against gh 2.60.1 with the literal-N control returning fine.

The re-sign command's own fallback caused the disaster the same line forbids.
`B=$(gt parent) || B=origin/main` fires exactly when Graphite doesn't track the
branch, and rebasing onto main from there replays the parent branch's commits and
strands that ref. It now fails rather than falling back.

The declined-finding carve-out was written against the wrong variable. Saying a
declined finding "does not reset" the counter left such a round neither clean nor
resetting, which still breaks the consecutive chain — the gate remained
unterminating. Such a round now counts as clean.

The attribution grep keyed its path on `pwd`, but the tmp directory is keyed on the
session's project dir, so it returned nothing after any cd — reading as "no
reviewer said that", the exact failure the rule exists to prevent. Also softened
the -r/-R claim: the entries are symlinks and -R always follows them, but I could
not reproduce -r failing on this machine's BSD grep, and the previous wording
asserted behaviour I had not verified here.

Hook: deriving the parent from the git dir is wrong for bare repos,
separate-git-dir and submodules, each of which got handed whatever scope its
container happened to have. It asks `git worktree list --porcelain` for the main
worktree root instead. Paths are compared canonically, so a symlinked cwd, a double
trailing slash, or /tmp versus /private/tmp no longer make a repo root
self-classify as a worktree and re-inject its own index. GIT_* is cleared from the
environment — an inherited GIT_DIR made `git -C` ignore cwd entirely and answer for
another repo, which is reachable from any git hook, and there is a Graphite
pre-push hook here that commits. One `exec 2>/dev/null` replaces three per-command
redirections that missed `sort`, `wc` and `tr`.


## Redact SSNs, EINs and a street address, and add a guard that fails closed

A review lens found full nine-digit SSNs tied to named individuals and trusts in
two memory files, plus EINs and a residential address. I verified before acting:
6 SSN-pattern matches in the working tree and the same 6 in origin/main.

Redacted to placeholders. The analytical value survives intact because it was never
the digits — the findings are "the EIN field renders the same nine digits as the
SSN, shifted by one", "Carta's EIN is Briggs' SSN with the dashes moved, identical
nine digits", and "my W-9 read was an OCR misread; Carta's is right". Each of those
reads the same with the numbers gone.

Added hooks/pre-commit, wired via core.hooksPath, refusing SSN- and EIN-shaped
digits in staged memory. It fails closed: if the check cannot run it blocks rather
than waving the commit through, and it masks the digits in its own error output.
Tested both directions — blocks a probe, passes this commit.

**This does not close the exposure.** The digits are in origin/main's history on a
private personal GitHub account. Redaction here does not touch that, and a
force-push leaves the blobs addressable by SHA until GitHub GCs. That decision is
Kevin's and is open.

Also fixes a stub I added last round that pointed at a path which does not exist —
the DIBS ACH parser is under backend/dibs/, not app/services/ — and adds the two
remaining cross-repo pointers: venture is blind to the fact that its own
wire_manual.rb still collapses the two ABAs (the only one of the three surfaces
still unfixed), and treasury is blind to the date-independent half of venture
#33053 living in its own OP routing handlers.


