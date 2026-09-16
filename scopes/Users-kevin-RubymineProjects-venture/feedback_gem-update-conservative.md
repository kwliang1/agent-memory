---
name: gem-update-conservative
description: "Gem update checklist -- conservative, RBI regen, rebase if base changes"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 021ac3c2-b0c1-4819-a048-9574a5a80dda
---

When updating gems in venture:
1. `bundle update --conservative <gem>` -- never bare `bundle update`
2. `bundle exec tapioca gem <gem>` -- regenerate RBI files (names encode version+revision)
3. Never hand-edit Gemfile.lock -- wait for SSH/tooling to work
4. If the gem's source branch merges to main, rebase and re-run steps 1-2 against main
5. Stale RBI filenames cause ALL CI test shards to fail at boot (not just sorbet check)
