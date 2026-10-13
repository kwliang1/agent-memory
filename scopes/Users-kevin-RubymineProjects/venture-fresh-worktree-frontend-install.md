---
name: venture-fresh-worktree-frontend-install
description: In a fresh venture worktree, frontend pnpm install needs GITHUB_TOKEN_PKG; `gh auth token` works (has read:packages). Don't symlink the main checkout's node_modules — it's stale.
metadata:
  type: reference
---
`GITHUB_TOKEN_PKG=$(gh auth token) npx -y pnpm@8.15.7 install --frozen-lockfile --ignore-scripts` from `frontend/fundraising` (and repo root). Kevin's gh token has `read:packages`.

Symlinking `/Users/kevin/RubymineProjects/venture/frontend/fundraising/node_modules` looked fine (same lockfile) but held Apollo 3 while the lock wants 4 — typecheck exploded with unrelated errors. Main checkout node_modules are as stale as the checkout itself ([[stale-shared-checkouts-are-the-norm]]).

`pnpm typecheck` on macOS always reports pre-existing `components/admin` vs `components/Admin` casing errors (TS1149/TS1261); filter for your own files.
