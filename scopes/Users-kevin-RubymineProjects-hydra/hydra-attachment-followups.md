---
name: hydra-attachment-followups
description: "PR #352 shipped (Slack thread attachments); three deferred follow-ups, one of which can destroy a worktree"
metadata: 
  node_type: memory
  type: project
  originSessionId: d9380142-3df6-4689-9e54-52d39643be52
  modified: 2026-09-14T18:56:36.178Z
---

**PR [#352](https://github.com/sf8193/hydra/pull/352)** merged-ready as of 2026-09-14 — Slack thread attachments delivered another message's file. Fixed `daemon/router.ts:95` (pass `registry.resolveThreadId(msg)`, not the bare channel) plus the gateway lookup (exact-ts match, pinned window, throw on miss). CI green, signature verified. **Needs a daemon restart to take effect.**

Kevin approved three additional changes mid-review, then cut them back to this minimal PR after round 4 found problems in each. They remain unfixed:

1. **Inbox filename collision.** `INBOX_DIR` is one directory for the whole daemon and Slack names every pasted screenshot `image.png`, so two files on one message overwrite each other — both returned paths point at the second file's bytes. Use the **loop index**, not the file ID: `String(undefined)` is `"undefined"` and `@slack/web-api` types `file.id` as optional. The Discord gateway has the identical line and zero coverage.
2. **`getThreadStarterInfo` has the same caller bug** and therefore has *never* run on Slack (its `split(':')` guard bails on a bare channel). Don't just fix the argument: it would add two uncached Slack calls per threaded message on the awaited delivery path, and `@slack/web-api` defaults to ~30 minutes of retries with `timeout: 0`, so one 429 could stall the whole fleet's inbound. Needs a cache or timeout first, plus scrubbing — the starter text is the only unescaped value in the notification payload.
3. **`meta.chat_id` stays bare for a dead-session thread.** ⚠️ **Do not ship the obvious one-line fix.** Making it the composite reaches `session-lifecycle.ts:455`, which calls `killSession` with no `skipWorktreeDestroy` — so "spawn a session for this" in a dead-session thread **destroys that session's worktree**, including unpushed work. That block was unreachable before. Resolve the destroy path first.

**Why:** each of these looks like a one-token fix and isn't; #3 is irreversible data loss that two independent reviewers found only by tracing the full call chain through `spawn_session`.

**How to apply:** one PR each, own review. Start with #1 (pure correctness, no behavior change beyond filenames).

**Testing gotchas learned here:** `~/.bun/bin/bun` (1.2.22) shadows the repo's pinned 1.3.14 — on 1.2.x the suite reports **38 spurious** `jest.advanceTimersByTime` failures. Use `~/.asdf/installs/bun/1.3.14/bin/bun`. Worktrees have no `node_modules`; run `bun install --frozen-lockfile`. `tsconfig.json` **excludes `slack-gateway.ts`** (which also has `@ts-nocheck`), so tsc parity proves nothing about it — typecheck it directly with the pragma stripped. And `gt` refuses to branch off `wt/*` worktree branches (untracked); those branches are also *not* on `origin/main`, so a plain rebase silently absorbs Kevin's unpushed commits — use `git rebase --onto origin/main <base>`.

See [[hydra-slack-api-facts]] for the API semantics behind the fix and [[hydra-worktree-name-divergence]] for related worktree gotchas.
