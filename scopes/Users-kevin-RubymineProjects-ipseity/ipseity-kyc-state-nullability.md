---
name: ipseity-kyc-state-nullability
description: identity_state/watchlist_state are nullable on US people and all India tables but NOT NULL on US companies, so a nil person reads as already screened
metadata:
  type: reference
---

On `kyc_aml_statuses_united_states_people` and all three India tables, `identity_state` and `watchlist_state` are nullable citext. On `kyc_aml_statuses_united_states_companies` both are `null: false`, and on the US trusts table `watchlist_state` is. Legacy people rows can hold nil, so a check like `watchlist_state != 'unchecked'` treats a never-screened person as screened.

**How to apply:** treat nil as unchecked in any "already ran checks?" logic on people, and check `db/schema.rb` for the table you're reading before assuming a state is present.
