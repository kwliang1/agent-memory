---
name: hermetic-git-test-fixtures-pr
description: "PR #418 (hydra) 2026-09-29 — ambient-git scrub in the bun preload; the Bun env-snapshot trap, why a toEqual on a constant is not a pin, and 5 follow-ups"
metadata:
  node_type: memory
  type: project
  originSessionId: 94dad8bc-be91-44f3-b4db-440751388dfd
  modified: 2026-09-29T21:46:54.774Z
---

**PR #418**, https://github.com/sf8193/hydra/pull/418 — `kevinliang/hermetic-git-test-fixtures`,
commit `47898d8` on base `0f8b447`. Opened 2026-09-29 after a 15-round gate; @sf8193 reviewed, and
rounds 16-18 on his one nit found four more real defects. 8 files, +248/−43. CI green.

Neutralises ambient git in `test-setup.ts` (the bun preload) so the git fixtures — and the daemon
code they drive — stop inheriting the developer's gitconfig. Sam Felder reported the raindrop flakes;
#411 had already fixed the CI-timing half by bumping a timeout and deleting three real-git tests.

## The fact worth carrying to any other bun work

**`Bun.spawnSync`/`Bun.spawn` with no `env` read the environment as it was at PROCESS START** and
ignore runtime mutation of `process.env`. `child_process` honours it. An explicit `env:` **replaces**
rather than merges. Verified on bun 1.4.2 by ~10 independent reviewers.

Two consequences that cost real time:
- A preload that mutates `process.env` covers `execFile`-based code but **not** a bare Bun spawn.
- **No test in the suite's own process can pin a fix to a bare Bun spawn's env.** The production fix
  here was fully green with the fix deleted (2329 pass / 0 fail) until a `bun -e` subprocess test was
  added. The tree has this idiom at `codex-piggyback.test.ts:581`, `bridge-transport.test.ts:358`,
  `codex-runtime-boot.test.ts:239` for exactly this reason.

## Gate/tooling facts

- **`gt submit` does not work on this repo** — `ERROR: You can only submit to repos synced with
  Graphite`. `gt modify -a` and restack are fine. Push with `git push -u origin <branch>` then
  `gh pr create`. See [[daemon-restart-via-bash-not-cli]] for the sibling "the CLI isn't the path" trap.
- **Local `main` in the worktrees is stale.** `git diff main...HEAD` returned 137 files for an 8-file
  branch. Always diff against `origin/main` or use `git show HEAD`, and never hand a reviewer a path
  or a `main...HEAD` range — see [[worktree-claimed-by-wt-spawn]].
- A `bun test --isolate` **wedged for 19 hours** and was still competing for the machine. It does not
  self-clear: `pgrep -fl "bun test"` before trusting any timing measurement.
- Concurrent `bun test` runs produce ~60 spurious failures clustered at the 5000 ms tmux timeout.
  Run one at a time.

## What the review cycle taught (2026-09-29, after Sam's one-line nit)

**A `toEqual` on a constant is not a pin.** The new drop-set key's only test asserted
`gitProbeEnv`'s output object — "the constant looking in a mirror". It proves the filter filters,
not that filtering is necessary. Same shape had already let a wrong item sit on the declined list
for fifteen rounds. **A behavioural pin needs the hostile condition actually applied**: here, probing
a *subdirectory* under an ambient ceiling, because a ceiling at the repo root is inert from the root.

**`GIT_CEILING_DIRECTORIES` blinds `rev-parse --git-common-dir`** when it is a strict ancestor of
the probed path and at or below the repo root. `ceiling == cwd` is inert. Git **realpaths** ceiling
entries by default — any spelling matches — skipping resolution only after an empty list entry.
Reachable here because `readProjectName` is called with `latestCwd(transcript)`, the session's real
cwd, so a subdirectory is routine.

**Three of my own asserted facts were wrong** and reviewers caught all three. Two were in a draft
reply to a human reviewer; the CLAUDE.md gate on replying to humans caught them before they shipped.
Measure before asserting a git behaviour — and check the *experiment* actually varies the thing
being claimed (mine used a ceiling above the root, which is inert regardless, so it never tested
realpath at all).

## Five follow-ups, none filed

1. `workAtRisk` (`daemon/worktree-manager.ts:89`) runs bare `git status --porcelain` **in the live
   daemon**, so the `core.excludesFile` data-loss hazard is live in production.
2. `shared/__tests__/spawn-env.test.ts` has no `rmSync`/`afterAll` at all — 3938 orphan temp dirs.
3. Three bare Bun spawns still inherit the hazard: `cli-handler`'s tmux probes, the engines'
   `send-keys Escape`, `pr-watch.ts:509`'s `gh pr view`.
4. **`timeout: 5000` on a `Bun.spawnSync` is not a bound** — Bun sends SIGTERM then waits for
   natural exit (a trapping child returned at 8.2 s, no SIGKILL). On the daemon's only thread a
   wedged mount is a freeze, not degradation.
5. `sessionProject` bounds the *cwd* with `underSpawnRoot` but the probe walks up, so it can name a
   repo rooted above `SPAWN_CWD`.
