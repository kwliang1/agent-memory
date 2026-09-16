# Step 0 — baseline

The "before" measurement. Step 5 replaces what a session is handed at startup, which
destroys the ability to measure this afterwards. Captured 2026-09-16, against the corpus
as it stood that morning.

Scripts here reproduce every number. Run them before trusting anything below.

---

## The corpus is much smaller than SPEC.md assumes

SPEC.md says to pull prompts from "the 2,050 transcripts". Most of those are not Kevin's.

```
2,095   .jsonl files under ~/.claude/projects/
2,066   contain at least one string-content user message
1,722   are subagent transcripts          — agent-to-agent, not a grader
  104   are workflow transcripts (wf_*)   — same
  240   real sessions
1,310   Kevin-authored prompts            — after removing task notifications,
                                            spawn topics and system messages
```

`./corpus-census.sh` produces the first four rows, `./extract-prompts.sh` the last.

So the grader pool is **1,310 prompts across 240 sessions**, not 2,050 transcripts. Of
those prompts, 1,051 arrived over the Slack bridge and 259 were typed in a terminal.

This matters beyond bookkeeping: a subagent transcript has no "answer Kevin accepted" in
it, so scoring against one measures nothing.

---

## Measurements

45 prompts sampled from the 1,310 (`./measure-sample.sh`, table in `sample-45.tsv`).

| | |
|---|---|
| Mean context at session start | **45,409 tokens** |
| Mean context at session start, all 240 real sessions | **48,331 tokens** |
| Mean answer length | 1,852 chars |
| Answers citing a `file:line` | **7 / 45 (16%)** |
| Answers citing a PR number | **17 / 45 (38%)** |
| Answers referencing a prior decision | **8 / 45 (18%)** |

The session-start figure is the number step 5 has to beat. SPEC.md budgets ~500 tokens
for the eager layer; today's startup load is roughly ninety times that.

---

## What the citation numbers are, and are not

They are **mechanical proxies**, measured by regex over the assistant text between one
prompt and the next:

- `file:line` — `foo.rb:123`, `bar.ts:45`
- PR — `#1234`
- prior decision — the words memory / previously / prior / we decided / as noted

They measure whether a citation of the right *shape* appeared. They do **not** measure
whether it pointed at the right file, the right PR, or a decision that actually says what
the answer claimed. SPEC.md step 0 asks for rightness, and rightness needs a human read.
Treat these as the floor: an answer with no citation at all cannot have cited correctly,
so 16% is a ceiling on file-level correctness, not an estimate of it.

Re-running step 5 against `sample-45.tsv` and comparing these same three rates is a valid
before/after. Claiming a correctness delta from them is not.

### One measurement trap, because it nearly shipped

The first run reported 4% file:line and 2% prior-decision. Both were artifacts. The
extractor took the next 7 entries after a prompt as "the answer", but a session's
assistant turns are mostly `tool_use` — 186 of 443 in one checked transcript, against 102
carrying text. The real answer lands after a long tool sequence, outside a 7-entry window.

Correct window is *every* assistant entry between this prompt and the next user prompt.
That alone moved file:line from 4% to 16% and prior-decision from 2% to 18%. Anything
that samples a fixed number of entries after a prompt will undercount the same way.

---

## PII

`prompts-clean.tsv` — the full 1,310-prompt corpus — is **deliberately not committed.** It
carries 2 SSN-shaped and 1 EIN-shaped strings, because Kevin quoted them into prompts
during the Fund 5/6 porting work. The same values that were scrubbed from `scopes/` are
still sitting in the transcripts they were discussed in.

`sample-45.tsv` is committed and scans clean: 0 SSN-shaped, 0 EIN-shaped. Its three
9-plus-digit runs are Slack message timestamps.

Anything that reads `~/.claude/projects/*/*.jsonl` and writes the result into this repo
must scan before it commits. The `hooks/pre-commit` guard covers it, but do not rely on
the guard to discover it for you.

---

## Reproducing

```sh
cd baseline
./corpus-census.sh   > census.tsv        # per-transcript: scope, start context, prompts
./extract-prompts.sh > prompts-clean.tsv # Kevin-authored prompts only — DO NOT COMMIT
shuf -n 45 --random-source=<(yes) < prompts-clean.tsv > sample-in.tsv
./measure-sample.sh  < sample-in.tsv > sample-45.tsv
```

`--random-source=<(yes)` fixes the sample, so the same 45 prompts come back on a re-run.
Use the committed `sample-45.tsv` for the after-measurement rather than resampling.
