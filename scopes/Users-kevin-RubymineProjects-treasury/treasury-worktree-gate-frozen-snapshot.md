---
name: treasury-worktree-gate-frozen-snapshot
description: Running the pre-push gate from a treasury worktree — reviewers read a git-archive snapshot so the mutation agent can use the live tree; biome/tsc recipe inside the worktree container
metadata:
  type: reference
---

A mutation-sweep agent spawned with `isolation: worktree` gets no app container, so it applies mutants in the parent worktree's bind mount and reverts with `git checkout --`. Reviewers reading the live tree then see half-applied mutants, and any uncommitted edit of yours gets wiped.

**How to apply:** before each round, `git archive HEAD app spec frontend/lib frontend/app backend/dibs/app app/public_api ops | tar -x -C <scratch>/frozen` and point every reviewer at that path (plus `git diff` written next to it). Only the mutation/verification agent touches the live tree, one at a time, and it must confirm `git status --porcelain` is empty before and after.

Container FE checks (PR #9156, 2026-10-14): `bunx` does not exist and `biome` is not in `frontend/node_modules/.bin`; `bun x @biomejs/biome@2.3.4 check --write <files>` from `frontend/` works and resolves the root `biome.jsonc` (`@angellist/biome-config`). `bun run typecheck` reports `TS2307 Cannot find module '@angellist/adapt'` everywhere and a pre-existing `TS2578` at `aba_routing_records/page.tsx:119`; filter to your files and ignore those two codes. CI type-checks via `bun run build` with adapt installed, never `*.test.ts`. CI rubocop (`bin/ci/rubocop_changed_files.sh`) fails only at error level, so convention-level offenses (`Rails/DynamicFindBy` on the DIBS facade finders, spec `update_columns`) are not CI failures.

Related: [[gate-checklist]], [[treasury-worktree-spec-run]].
