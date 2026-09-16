---
name: repo-workflow-quirks
description: "angellist_user_mapping repo — not Graphite-synced, dotted key convention beats stale header comment, bump.sh PR workflow"
metadata: 
  node_type: memory
  type: project
  originSessionId: 140ea138-6756-48f2-a68a-0ffc07af2cdf
---

Quirks of the angellist_user_mapping repo (learned 2026-06-10):

- **Not synced with Graphite**: `gt submit` fails ("You can only submit to repos synced with Graphite"). `gt create` works for branch+commit; use `git push` + `gh pr create` to submit.
- **Key naming**: the header comment in `config/mappings.yml` says to sub `_` for `.` in usernames, but it's stale — recent entries (karen.salcedo, madison.stomberg, viv.hong, ahmed.mohsen) use dots. Use the dotted email local-part.
- **PR workflow**: edit `config/mappings.yml`, run `./bump.sh` (patch bump + dated empty changelog stub), fill in the changelog bullet, verify with `ruby sort_mappings.rb --check` (the only CI check) and a YAML parse. Gem auto-publishes on merge to master.
- Kevin's old branches here used the `kliang/` prefix; his global preference is `kevinliang/`.
