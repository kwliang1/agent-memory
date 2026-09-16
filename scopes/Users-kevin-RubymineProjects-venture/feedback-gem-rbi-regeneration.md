---
name: feedback-gem-rbi-regeneration
description: "After bumping gems in venture, always run `make gem-rbis` and `make rbi` to regenerate Sorbet RBIs"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: ed54afd3-2fb9-49a6-9239-310e9517e893
---

After bumping any gem in venture, always run `make gem-rbis` (for gem RBIs via `bin/tapioca gems`) and `make rbi` (for DSL RBIs via `bin/tapioca dsl`) to regenerate Sorbet type definitions. Do NOT use `bin/tapioca dsl <ClassName>` directly — use the Makefile targets.

Also use `bundle update <gem> --conservative` to avoid pulling unnecessary transitive dependency bumps (e.g. zeitwerk 2.8.2 broke tapioca in an earlier attempt).

**Why:** Kevin flagged this — the Makefile targets are the canonical way to regenerate RBIs in venture. Stale RBIs caused a Devin review false positive and would have caused CI failures.

**How to apply:** Any time Gemfile.lock changes, run both `make gem-rbis` and `make rbi` before committing. Use `--conservative` flag on `bundle update` to minimize blast radius. Also check for merge conflicts with main before pushing — rebase, re-run the conservative update, and regenerate RBIs if main has moved.
