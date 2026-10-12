---
name: mock-env-vars-differ-by-repo
description: "CLAUDE.md's pre-push `unset MOCK_ENTITY_API` is a no-op in every repo that names it — the real mock vars differ per repo, and unsetting them is stricter than CI"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 6a16a573-0d6f-46b0-926a-158d11ceeb46
  modified: 2026-09-25T21:20:55.044Z
---

The pre-push gate says to run specs with `unset MOCK_ENTITY_API`. **That variable does not exist in any of the repos the rule names**, so the unset silently succeeds and the suite runs with every mock still on — a confident green that hides exactly what the step exists to catch.

Real vars, per repo:

- **treasury** — `MOCK_IPSEITY`, `MOCK_ANGELLIST`, set in `.devcontainer/.env`, and specs run in the container. CI runs *with* both on, so unsetting locally is **stricter** than CI, not weaker.
- **venture** — `CPTR_MOCK_IPSEITY`, `CPTR_MOCK_TREASURY`, `CPTR_MOCK_ANGELLIST`, `MOCK_TWO_FACTOR`. Leaving `MOCK_TWO_FACTOR` on is what hides the SEC-829 two-factor surface.
- **comptroller** — `MOCK_ANGELLIST`, `MOCK_TREASURY`, `MOCK_IPSEITY`.
- **ipseity** — it *is* the entity API; there is nothing to unset.

**The right way to turn one off is per-repo — do not generalise from treasury.**

- **treasury** — `-e MOCK_IPSEITY=` does *not* disable it: those call sites test truthiness and `""` is truthy in Ruby. Use `env -u`.
- **venture / `MOCK_TWO_FACTOR`** — exactly the opposite, and `env -u` is the one that silently fails. Verified 2026-09-25 against dotenv 2.7.6:
  - `config/environments/test.rb:15` runs `Dotenv.load(Rails.root.join('.env'))`, and `Dotenv::Environment#apply` is `ENV[k] ||= v`. `env -u MOCK_TWO_FACTOR` leaves the key `nil`, so `||=` puts `MOCK_TWO_FACTOR=true` straight back and the mock stays **on**.
  - `MOCK_TWO_FACTOR=` sticks, because `""` is truthy in Ruby so `||=` does not replace it — and every call site is `ENV['MOCK_TWO_FACTOR'].present?` (`app/models/user.rb:512`, `info_service.rb:31`, `backend/banking/app/services/banking/presenter/two_factor_config.rb:12,19,26`), and `"".present?` is `false`.
  - So: `direnv exec . env MOCK_TWO_FACTOR= bundle exec rspec <path>`.

The general rule: read the call site (`.present?` vs truthiness) *and* check whether the repo re-loads `.env` at boot with `Dotenv.load` rather than `overload`. Those two together decide which of `env -u` / `VAR=` actually works, and they differ per repo.

This lives in the umbrella deliberately. The gate runs at the umbrella cwd and in worktrees that have no memory directory at all, so a correction filed in the repo's own scope loads only after the wrong command has already run. Treasury's CI diagnostics — Knapsack Queue shard behaviour and the two known local-only failures — stay in `treasury-mock-ipseity-not-mock-entity-api.md`.
