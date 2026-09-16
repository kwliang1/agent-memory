---
name: venture-read-agents-md-best-practices
description: "Read venture's AGENTS.md + best_practices/react.md|ruby.md BEFORE writing venture code — I missed react.md on #31974 and a reviewer flagged it"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: dca55113-0865-4f83-a97d-a95da7ec9c6b
  modified: 2026-08-24T07:05:07.950Z
---

Before writing/editing ANY code in the **venture** repo, read its root `AGENTS.md` first. It has a hard convention gate (~line 120): "While working in React files follow `best_practices/react.md`; while working in Ruby files follow `best_practices/ruby.md`." Load those docs before touching `.tsx`/`.ts`/`.rb`.

**Why:** On BANK-1506 (venture PR #31974) human reviewer @FoodProduct flagged *"nit: please abide by best_practices/react.md for new TSX code."* I'd written the blade/query without reading venture's AGENTS.md this session (I'd read *nova's* AGENTS.md when grabbing a design reference, but never venture's — even though all the work was in venture). The specific misses react.md would have caught: colocate the GraphQL query in a `use*` hook next to the component (not a global `graphql/queries/` file), no IIFE in components.

**Compounding trap:** `frontend/fundraising/graphql/queries/` already has ~118 global-query files, so "match the surrounding code" actively leads AWAY from react.md's colocation rule. Don't infer conventions from the majority of existing files — read the written standard; the codebase can lag it.

**How to apply:** (1) At the start of venture work, `cat AGENTS.md` + the referenced `best_practices/*.md`. (2) DETERMINISM (settled 2026-08-24): the chosen fix is a **PreToolUse hook**, not a CI gate. `~/.claude/hooks/agents-md-reminder.js` (registered in `~/.claude/settings.json` under `hooks.PreToolUse`, matcher `Edit|Write|MultiEdit`) walks up from the edited file to the nearest `AGENTS.md` and injects a once-per-session-per-repo `additionalContext` reminder to read it + its `best_practices/*.md`. Zero blast radius, generalizes to ANY repo with an AGENTS.md. The CI-gate alternative (venture PR #33426, a `pipeline.rb` guard blocking new `graphql/queries/` files) was **CLOSED as over-built** — Kevin: a hard pipeline-gen gate in the critical CI path for a nit is the wrong weight class. If human-facing enforcement is ever wanted, right-size it as a one-line check on the *existing* lint step or a biome/danger rule — never a new pipeline gate. Related: [[nova-comment-policy-review-gap]] (same "police the repo's written conventions" theme), [[bank-1506-imad-omad-trace]].
