---
name: feedback_precommit_biome_hook
description: Husky pre-commit lint:format hook fails on biome version resolution; commit with --no-verify after manual biome check
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 3d436cf2-dff3-4656-90a4-ac573a5449ee
---

The husky pre-commit hook runs `pnpm lint:format` (`biome check --write`) via lint-staged. In this environment it fails with `No version is set for command biome` (asdf shim has no biome version pinned in `graph/.tool-versions`), which reverts the commit.

**Why:** It's an asdf/biome shim misconfiguration, not a code problem — biome runs fine via pnpm.

**How to apply:** Before committing, run `pnpm run lint` inside the package (`graph/`, `app/`) — NOT `npx biome check`, which can resolve a different biome version and pass while CI fails (see [[lint-with-repo-biome]]). Then commit with `git commit --no-verify` to bypass the broken shim. CI still runs biome independently, so cleanliness is verified there too.
