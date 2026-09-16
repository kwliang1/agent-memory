---
name: lint-with-repo-biome
description: "Biome version drift causes CI-only format failures; match CI by pinning npx to biome.jsonc's $schema version"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 863ddaed-ea2b-4514-b194-5ae6ae2691fa
---

The authoritative biome version is in `biome.jsonc`'s `$schema` URL (e.g. `.../schemas/2.3.9/schema.json`). CI runs that exact version. `lineWidth` is unset → default **80**.

**Why:** The local biome that runs in `pnpm run lint`/`lint:format` and the husky hooks can be a DIFFERENT version than CI (often not even installed at `node_modules/@biomejs/biome` → "No version is set for command biome"). Different versions format identically-valid code differently, so a file the local hook "fixed" still fails CI. Seen twice: PR #8374 (long `vi.mocked(...)` lines) and PR #8495 (an `it.each([a, b, c])('...', fn)` line at 107 chars — local biome wrapped the callback args, CI's 2.3.9 wrapped the array elements). Buildkite builds burned each time.

**How to apply (proven):** To match CI exactly, run the version-PINNED biome:
`npx --yes @biomejs/biome@<version-from-$schema> check [--write] <files>` (e.g. `@2.3.9`). Exit 0 from that = CI lint will pass. Do NOT trust `pnpm run lint`/`lint:format` or unpinned `npx biome` — both can be drifted. When CI prints the desired diff, that output is also authoritative — copy it verbatim. Because the drifted local hooks will reformat your CI-correct file BACK to the rejected style, commit with `git commit --amend --no-verify` and push with `git push --no-verify --force-with-lease` to bypass them ([[feedback_precommit_biome_hook]]). Watch shell word-splitting when passing a `$files` list to biome — it can spuriously exit 1; pass explicit paths. Only fix files in your diff (local biome may flag unrelated files CI doesn't).
