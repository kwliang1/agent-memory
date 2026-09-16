---
name: mock-env-vars-differ-by-repo
description: "CLAUDE.md's pre-push `unset MOCK_ENTITY_API` is a no-op in every repo that names it — the real mock vars differ per repo, and unsetting them is stricter than CI"
metadata:
  type: feedback
---

The pre-push gate says to run specs with `unset MOCK_ENTITY_API`. **That variable does not exist in any of the repos the rule names**, so the unset silently succeeds and the suite runs with every mock still on — a confident green that hides exactly what the step exists to catch.

Real vars, per repo:

- **treasury** — `MOCK_IPSEITY`, `MOCK_ANGELLIST`, set in `.devcontainer/.env`, and specs run in the container. CI runs *with* both on, so unsetting locally is **stricter** than CI, not weaker.
- **venture** — `CPTR_MOCK_IPSEITY`, `CPTR_MOCK_TREASURY`, `CPTR_MOCK_ANGELLIST`, `MOCK_TWO_FACTOR`. Leaving `MOCK_TWO_FACTOR` on is what hides the SEC-829 two-factor surface.
- **comptroller** — `MOCK_ANGELLIST`, `MOCK_TREASURY`, `MOCK_IPSEITY`.
- **ipseity** — it *is* the entity API; there is nothing to unset.

`-e VAR=` does not disable any of them: the call sites test truthiness and `""` is truthy in Ruby. Use `env -u`.

This lives in the umbrella deliberately. The gate runs at the umbrella cwd and in worktrees that have no memory directory at all, so a correction filed in the repo's own scope loads only after the wrong command has already run. Treasury's CI diagnostics — Knapsack Queue shard behaviour and the two known local-only failures — stay in `treasury-mock-ipseity-not-mock-entity-api.md`.
