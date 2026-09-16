# Step 0 — baseline

The "before" measurement. Step 5 replaces what a session is handed at startup, which
ends the ability to add sessions to the before-set. Captured 2026-09-16, against the
corpus as it stood that morning.

Scripts here reproduce every number in the committed data files. The census below is
frozen at capture; the corpus has grown since and a re-run will return different totals.

---

## The corpus is much smaller than SPEC.md assumes

SPEC.md says to pull prompts from "the 2,050 transcripts". Most of those are not Kevin's.

```
2,095   .jsonl files under ~/.claude/projects/     (find -name '*.jsonl')
2,066   hex-named, >2KB, with a string-content user message   (corpus-census.sh)
1,722   are subagent transcripts          — agent-to-agent, not a grader
  104   are workflow transcripts (wf_*)   — same
  240   real sessions
1,933   non-system prompts from those sessions   (extract-prompts.sh without
        the > 40-char floor)
  618   dropped by the > 40-char floor (32%)
1,315   prompts > 40 chars, across 156 sessions   (extract-prompts.sh)
```

`./corpus-census.sh` produces the session-level rows. `./extract-prompts.sh` produces
the prompt counts. Row 1 is a plain `find` count; `corpus-census.sh` only enumerates
hex-named files over 2 KB, so it cannot produce it. The 1,933 total is not directly
script-produced; derive it by replacing the length floor in `extract-prompts.sh`.

The > 40-char floor drops 32% of non-system prompts. Short prompts are the ones most
dependent on recalled context — exactly what step 5 targets — so this exclusion skews
the pool away from the use case the project exists to measure.

So the grader pool is **1,315 prompts across 156 sessions** (1,310 at draw time; now
1,315), not 2,050 transcripts. Of those prompts, 1,052 arrived over the Slack bridge
and 263 were typed in a terminal. Not all are prompts Kevin typed: the pool includes
cross-session relay messages, image placeholders, retry messages, compaction summaries,
and loop-tick re-injections that passed the non-system filter. Seven additional
machine-authored families still pass the predicate (e.g. throwaway `/private/tmp` probe
scopes); these are a known limitation of the frame, not corrected here — their effect
belongs to the after-measurement's design, which is a question for Kevin.

This matters beyond bookkeeping: a subagent transcript has no "answer Kevin accepted" in
it, so scoring against one measures nothing.

SPEC.md asks for `tokens injected` per prompt. There is no before value: step 5 is what
injects tokens, so this column has no baseline to beat.

---

## Measurements

45 prompts drawn from the 1,310-prompt pool (selector in `sample-in.tsv`, measured by
`./measure-sample.sh`, output in `sample-45.tsv`).

10 of the 45 are not gradeable: 3 image placeholders, 2 autonomous-loop ticks, 1 loop
re-injection (detected by the `repeats >= 3` rule — same normalised prompt text at 3+
indices in the session), 2 cross-session relay messages, 1 tool-call retry, 1 compaction
summary. The `gradeable` column flags them (1 = gradeable, 0 = not); the `repeats`
column exposes the repeat count so the split is fully checkable:
`awk -F'\t' '$10==1' sample-45.tsv`.

2 gradeable rows have empty answer windows (`ans_chars=0`): `cb150723` idx 6 (three
Kevin messages before any reply) and `c67a5b3d` idx 11 (a duplicate Slack delivery
closes the window immediately). They score 0 on every citation metric,
indistinguishable from a genuine uncited answer. Excluding them moves mean answer
length to 2,778 and changes no citation numerator.

| metric | all 45 | gradeable 35 |
|---|---|---|
| Mean context at session start | **50,239 tokens** | **50,592 tokens** |
| Mean answer length | 2,984 chars | 2,619 chars |
| Answers citing a `file:line` | 11 / 45 (24%) | 7 / 35 (20%) |
| Answers citing a PR number | 22 / 45 (49%) | 19 / 35 (54%) |
| Prior decision | 0 / 35 (0%, upper bound 10%) — too wide to set a threshold on |

Session-start context is the number step 5 has to beat: SPEC.md budgets ~500 tokens for
the eager layer; today's startup load is roughly a hundred times that. `ctx_at_start` is
a session constant (first positive usage over the whole transcript), so the 45 rows carry
only 29 distinct values. Session-level: n=25 gradeable sessions, mean 49,621. The
sample-SD t-interval is [46,050–53,193], but the pool SD is 63,142 (heavy tail; session
`e4c054c8` carries 824,954 — 824k of it cache-read, 775 turns). A 20,000-rep simulation
puts coverage of the sample-SD interval at ~40%, so it is not trustworthy at this pool
shape. Pool centre: median 46,614, 5% trimmed mean 45,830 (both excluding `e4c054c8`'s
value, which is a resumed transcript, not a session-start context under this document's
definition). No detectable discrepancy at n=25.

Three sampled rows from session `ca52b8bd` had zero-sum usage; the leading entry is a
synthetic error message. The scripts select first positive-sum usage.

### Channel contrast

All 35 gradeable rows are bridge; all 10 non-gradeable are terminal. On the measured
arm the flag removes nothing: 0 of 1,052 bridge rows are demoted by either half of the
rule, so `gradeable=1 ⟺ src=="bridge"` holds exactly on all 45.

This is a sampling accident — 45 terminal pool prompts do pass `is_gradeable` — but
under the true 45/263 passage rate, drawing 10 terminal prompts with zero gradeable is a
15–31% event, depending on the draw model. An after-set drawn the same way will carry a
nonzero terminal share, and the two arms will then differ by channel mix on top of
step 5. Pool-wide (checkable: `awk -F'\t' '$10==0' sample-45.tsv` for the sample;
the pool figures below require re-running `extract-prompts.sh` with the current
`is_gradeable` applied):

```
bridge  failing is_gradeable:     0 of 1,052
terminal failing is_gradeable: 218 of   263 (83%)
repeats >= 3 (terminal only):  40 of   263
```

The real reason no bridge prompt reaches the repeat threshold: no bridge prompt over 40
characters happens to repeat three times in one session. The after-set design recommends
dropping that floor, which may change this.

The all-45 PR count of 22 includes one false positive (`d14d2ed3` idx 4: `OP #778` is
an OutgoingPayment record, not a PR; this row is non-gradeable, so it does not affect
the gradeable 19).

The step-5 after-measurement should be compared against the gradeable rows
(`gradeable=1`). The `file:line` regex covers `.rb`, `.ts`, `.tsx`, `.sql`, `.mjs`,
`.sh` plus the `#L` GitHub permalink form; no `.py`, `.go`, or `.md` citation occurs
in the 45, so this costs nothing in the current sample.

`cites_pr` has ICC 0.55 (effective n ≈ 29) and `cites_file` has ICC 0.30 (effective
n ≈ 31); neither is distinguishable from zero at k=25 (permutation p = 0.055 and 0.318).
The after-run must come from ≥35 distinct sessions; clustering moves the Fisher p on
`file:line` from 0.035 to ~0.049 — still under alpha, but barely.

---

## What the citation numbers are, and are not

They are **mechanical proxies**, measured by regex over the assistant text between one
prompt and the next Kevin-authored prompt:

- `file:line` — `foo.rb:123`, `bar.ts:45` (six extensions plus `#L` permalinks)
- PR — `#1234`
- prior decision — previously / earlier decision / `\bprior\b` / we decided / as noted / last time

Six phrases, all but `\bprior\b` fire zero times. `\bprior\b` matches once on all-45
and zero on gradeable rows. The metric has no signal at this sample size; the
`cites_prior` column is retained but no threshold is set. The confound with step 5
(installing a memory graph makes `memory`-family words appear more often) killed the
original regex; the surviving phrases are not confounded but are inert.

They measure whether a citation of the right *shape* appeared. They do **not** measure
whether it pointed at the right file, the right PR, or a decision that actually says what
the answer claimed. SPEC.md step 0 asks for rightness, and rightness needs a human read.

### Answer window

Any window that closes on a fixed entry count, or on any `type:"user"` entry,
undercounts. Claude Code writes task notifications, compaction summaries, harness
injections (usage-limit resets, builder-session seeds, loop bookkeeping, output-limit
resumes, and others) as user entries; close on the next Kevin-authored entry that passes
`is_gradeable` instead.

---

## PII

`prompts-clean.tsv` — the full 1,315-prompt corpus — is **deliberately not committed.** It
carries 2 SSN-shaped and 1 EIN-shaped strings, because Kevin quoted them into prompts
during the Fund 5/6 porting work. The same values that were scrubbed from `scopes/` are
still sitting in the transcripts they were discussed in.

`sample-45.tsv` and `sample-in.tsv` are committed and scan clean: 0 SSN-shaped,
0 EIN-shaped. Their 9-plus-digit runs are session-ID fragments, message IDs, and
bridge timestamps, none PII.

Anything that reads `~/.claude/projects/*/*.jsonl` and writes the result into this repo
must scan before it commits. The `hooks/pre-commit` guard covers it, but do not rely on
the guard to discover it for you.

---

## Verifying the before-set

The sample was drawn from the 1,310-prompt pool with:

```sh
cd baseline
./corpus-census.sh   > census.tsv        # per-transcript: scope, start context, prompts
./extract-prompts.sh > prompts-clean.tsv # Kevin-authored prompts only — DO NOT COMMIT
shuf -n 45 --random-source=<(yes) < prompts-clean.tsv > sample-in.tsv
```

The `shuf` line emits 45 rows with no header; the committed `sample-in.tsv` has a header
added afterwards.

That selection is not reproducible (one-time observation, not regenerable: the corpus
has grown past the 1,310-prompt input that produced it). `shuf` depends on the input's
length and order; a re-run on a corpus grown by 3 prompts returned 25 of 45 rows
different.

The sample is frozen by the committed `sample-in.tsv`, not by the random source. The
acceptance criterion for this commit is:

```sh
tail -n +2 baseline/sample-in.tsv | ./baseline/measure-sample.sh | diff - baseline/sample-45.tsv
```

This must be empty **without regenerating `sample-45.tsv`** — regeneration is the
reviewable event. Its one hole: it proves the committed script+selector produce the
committed table, not that the table is correct. Every metric defect found in this
file's history reproduced perfectly.

To confirm the before-set still measures what it measured after transcript changes:

```sh
cd baseline
tail -n +2 sample-in.tsv | ./measure-sample.sh > sample-45-recheck.tsv
diff sample-45.tsv sample-45-recheck.tsv
```

If the diff is empty, the historical rows are stable. If not, a sampled session was
resumed or compacted and the affected rows must be investigated before trusting any
delta. 2 of 45 rows have no later Kevin-authored prompt, so their windows run to end of
transcript. The larger exposure is transcript compaction, which already affects 9 of the
29 sampled sessions.

Two sampled rows from `023f8de4` have overlapping windows (idx 107's window sits inside
idx 106's, 3,142 chars counted twice in all-45). n=35 is unaffected — idx 107 is
non-gradeable.

## The step-5 after-measurement

The original brief specified a same-45-rows before/after comparison. That cannot work:
`measure-sample.sh` scores historical transcripts, and step 5 changes what *new* sessions
are handed at startup — it cannot alter transcripts from 2026-09-15. Re-running the
committed selector after step 5 returns the before-numbers to the digit, forever.

The sample also cannot be replayed: 39 sit at idx >= 3 (median 13, max 108), so each
prompt is meaningless without its preceding turns.

The step-5 after-measurement has to be a fresh set of sessions scored by the same
regexes and compared as two independent groups. The committed selector is a frozen
definition of the before-set plus a drift tripwire — not a replay mechanism.

The before-set was drawn with a > 40-char floor that drops 32% of prompts — the short
prompts most dependent on recalled context. If the after-set applies the same floor,
both arms are blind to the population step 5 most needs to improve. The after-set
should either drop the floor or stratify by prompt length so the short-prompt effect is
visible.

### Statistical power

For two independent groups of n=35 gradeable rows (Fisher exact test, one-sided,
alpha = 0.05): from 7/35 (20%) `file:line`, the after-run needs **≥ 15/35 (43%)**
(Fisher p = 0.035 nominal; ~0.049 adjusted for clustering at ICC 0.30). 80% power
requires a true after-rate of ~49%, with the before-count frozen.
