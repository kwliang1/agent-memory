---
name: nova-lockfile-pnpm-version-trap
description: "nova's pnpm-lock.yaml on main was written by a newer pnpm than the 10.17.1 pin — any local install regenerates ~190 unrelated lines (some semantically live); hand-edit the importer entry instead."
metadata: 
  node_type: memory
  type: project
  originSessionId: a1fcbcee-9120-4ae9-8587-5d692f896e14
  modified: 2026-09-02T00:36:02.088Z
---

nova pins pnpm 10.17.1 (`.tool-versions` + `packageManager`), but some lockfile hunks on main (from PR #9822, 2026-09-01) were written by a newer pnpm. Running `pnpm install` at the pinned version after touching any package.json regenerates the whole lockfile and REVERTS those hunks: ~63 `libc:` platform-selector fields, `@next/swc-*` optionalDependencies blocks, and — semantically live — `@angellist/adapt`'s `peerDependenciesMeta` (chart.js/intl-tel-input/jsdom/react-chartjs-2 flip from optional to hard deps in the resolved graph).

**Why:** whatever wrote main's lockfile formats those sections differently; 10.17.1 deterministically rewrites them. This ping-pongs on every PR until someone reconciles pnpm versions.

**How to apply:** when a PR only adds/moves a dependency, don't commit the full regeneration. `git checkout <merge-base> -- pnpm-lock.yaml`, hand-insert the 3-line importer entry (key/specifier/version, alphabetical, copy the format from an existing entry for the same package), then validate with `pnpm install --frozen-lockfile --ignore-scripts` (passes at 10.17.1). Done for BANK-1942 (nova#9834); reviewers verified structure and frozen install.

Related: [[spawned-nova-worktree-is-bare]]
