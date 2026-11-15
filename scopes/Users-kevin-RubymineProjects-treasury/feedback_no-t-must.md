---
name: feedback_no-t-must
description: Kevin doesn't want new T.must in code — narrow with an explicit raise-if-nil on a local instead
metadata:
  type: feedback
---

Don't add `T.must(...)` in new or changed code — especially nested `T.must(T.must(x.y).z)`. Assign to a local and guard with an explicit `raise '<Thing> must have <field>' if local.nil?`; Sorbet narrows the local after the raise.

**Why:** Kevin, BANK-2380 PR #9226 (2026-10-26): "no T.must. I thought this was persisted in my preferences" — it wasn't, so it got through five review rounds.

**How to apply:** before committing, `git diff $(git merge-base origin/main HEAD) -- app | grep '^+.*T\.must'` should be empty. Pre-existing T.must lines you merely move should be converted too. Match nearby guard wording (e.g. `outgoing_payment/adapters/treasury_prime.rb` uses `raise 'SubAccount must have …' if x.nil?`). Brief reviewers to flag any new T.must.
