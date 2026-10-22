---
name: treasury-program-name-enum-hand-maintained
description: A new PartnerBank::Program name must also be added by hand to the GraphQL PartnerBankProgramNameEnum, then schema + frontend types regenerated the CI way; otherwise the first SubAccount on that program 500s the admin pages
metadata:
  type: project
---

`Types::PartnerBank::ProgramNameEnum` (`app/graphql/types/partner_bank/program_name_enum.rb`) is a
hand-written list, not derived from `PartnerBank::Program` constants. `ProgramType.name` is non-null
and serializes through it, and graphql-ruby raises `UnresolvedValueError` on an unknown value.
Found on BANK-1810 (2026-10-15): adding 'Interchange Money Market Fund' to the model constants alone
left a latent 500 for the first Interchange SubAccount. 'Grasshopper Bank Sweep' is missing too on
main (no row exists, so inert).

**Why:** nothing enforces the list; no spec compares it to the Program constants.

**How to apply:** when adding a program name, add the enum value in the same PR and regenerate with
`bundle exec rake graphql:schema:dump` plus `cd frontend && bun run graphql:export:client`
(not `make graphql`, see [[reference_schema-json-rake-not-make-graphql]]), then commit
`schema.graphql`, `schema.json`, `frontend/lib/types/graphql.ts`. Related:
[[treasury-enum-value-ci-and-rollback]].
