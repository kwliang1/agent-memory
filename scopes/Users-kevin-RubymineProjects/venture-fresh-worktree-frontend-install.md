---
name: venture-fresh-worktree-frontend-install
description: "Venture frontend pnpm install in a worktree — since 2026-10-13 pnpm 12 ignores ${GITHUB_TOKEN_PKG} in the repo .npmrc; pass a userconfig. Don't symlink the main checkout's node_modules."
metadata:
  node_type: memory
  type: reference
  originSessionId: 67f59b96-4abd-4a4b-b4f7-58fb806b1d78
  modified: 2026-10-14T23:27:57.647Z
---

Since 2026-10-13 venture pins pnpm 12.11.2, which ignores `${GITHUB_TOKEN_PKG}` in committed `.npmrc` files (401 from npm.pkg.github.com even with the env var set, and `--config.userconfig=` does not help). asdf here lacks pnpm 12. Working recipe from `frontend/fundraising`, without touching Kevin's `~/.npmrc`:

```sh
echo '//npm.pkg.github.com/:_authToken=${GITHUB_TOKEN_PKG}' > $SCRATCH/npmrc
NPM_CONFIG_USERCONFIG=$SCRATCH/npmrc GITHUB_TOKEN_PKG=$(gh auth token) npx -y pnpm@12.11.2 install --frozen-lockfile --ignore-scripts
```

Kevin's gh token has `read:packages`. Symptom of a stale worktree install: vitest "Failed to resolve import clsx".

Symlinking the main checkout's `node_modules` looked fine but held Apollo 3 while the lock wants 4. Main checkout node_modules are as stale as the checkout itself ([[stale-shared-checkouts-are-the-norm]]).

Typecheck is `next typegen && tsc --noEmit`; bare tsc without typegen reports TS6053 for `.next/types`. On macOS it always reports pre-existing `components/admin` vs `components/Admin` casing errors; filter for your own files.
