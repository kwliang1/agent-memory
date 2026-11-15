---
name: treasury-lint-staged-reorders-graphql-args
description: "Treasury's commit hook runs rubocop autocorrect, which can alphabetise GraphQL `argument` lines after you exported the schema, leaving schema.json stale for CI's ensure_server_in_sync."
metadata:
  node_type: memory
  type: feedback
  originSessionId: 873b0b86-5685-4cab-ac3a-11d0645987aa
  modified: 2026-11-13T08:59:14.490Z
---

On BANK-2833 (#9600), I exported the GraphQL schema and then committed. The lint-staged `rubocop --auto-correct` reordered the mutation's `argument` lines to label, provider, purpose. schema.json still had the old order, so `bin/ci/ensure_server_in_sync` would have failed. A gate reviewer caught it by dumping the schema from the frozen tree.

**Why:** schema.json keeps declaration order, and the commit hook rewrites Ruby after the export has already run.

**How to apply:** after any commit that touches `app/graphql/`, re-run `bun run graphql:export` and confirm `git status` is clean before pushing. In the same session, a `git grep "ApiKey.verify!("` that covered only the obvious spec directories missed `spec/lib/dev_tools/tonic/`, so CI went red. Sweep the whole repo (app, lib, backend, spec) for every caller of a changed signature. See [[feedback_pr_call_site_inventory]].
