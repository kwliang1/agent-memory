---
name: prophet-rails8-ref
description: The prophet git-gem ref that unblocks Rails 8 across AngelList consumers (ipseity/treasury/venture)
metadata: 
  node_type: memory
  type: reference
  originSessionId: 2e75f0f0-fa64-4a79-9860-e372426381a1
  modified: 2026-08-19T19:47:18.805Z
---

The internal `prophet` git gem's old gemspec pinned `activesupport`/`railties` `~> 7.1` (`< 8.0`) — a HARD bundler blocker for any Rails 8 upgrade in a prophet-consuming repo.

**Fixed upstream:** prophet PR #24 (gemspec-only, no code) widened both to `>= 7.1, < 9` and declared `zeitwerk ~> 2.6`. The Rails-8-ready ref is **`8c94a09d21fcebd78e4350ea5231ffc02c23212c`**.

**How to apply:** In any repo hitting the prophet `< 8.0` block (Gemfile `gem 'prophet', ref: ...`), bump the ref to `8c94a09`. Use `bundle lock` (NOT `bundle lock --update prophet` — the latter churns ~40 unrelated gems). Regen the sorbet RBI (filename embeds the ref). Confirm `8c94a09` is a safe superset of the repo's current ref before adopting. Precedent: treasury PR #8595. Related: [[project_ci_ssh_only_git_gems]] (prophet uses git@ remote), [[project_ipseity_is_entity_api]].
