---
name: npx-biome-is-a-different-package
description: In venture worktrees `npx biome` resolves to an unrelated npm package "biome" v0.3.3 that exits 0 silently; use the asdf `biome` (2.3.9) instead
metadata:
  type: feedback
---

In a venture worktree, `npx biome check ...` does not run Biome. It resolves to an unrelated npm package named `biome` (v0.3.3), which prints nothing and exits 0. The real linter is the asdf shim `~/.asdf/shims/biome` (2.3.9, pinned in the root `.tool-versions`). Neither `node_modules/.bin` has a biome binary.

**Why:** on BANK-2314 (2026-10-23), a whole session of "biome clean" checks were no-ops. CI's `lint-angellist-fundraising` (`pnpm lint` = `biome check`) then went red on formatting in two files.

**How to apply:** from `frontend/fundraising`, run `~/.asdf/shims/biome check <files>` (or `biome check` with no args, the same as CI). Sanity-check with `biome --version` and expect `Version: 2.x`. This also applies to the husky-workaround recipe in handoff letters that says `npx biome check`. Related: [[venture-worktree-dev-loop]], [[gate-checklist]].
