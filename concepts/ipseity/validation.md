<!-- machine-owned: regenerated every run, never hand-edit -->
---
concept: [ipseity, validation]
related:
  - [ipseity, entity]
  - [ipseity, identity_data]
  - [ipseity, address]
---
symbols:  Validation::BankAccountDataService, Validation::Concerns, Validation::Concerns::ProgressLoggable, Validation::Concerns::Validatable, Validation::TaxIdService, Validation::Utils::ProgressTracker, Validation::Utils::ValidationError, Validation::Utils::ValidationHelpers, Validation::Utils::ValidationResult, Validation::Validators::Address, Validation::Validators::Common, Validation::Validators::Entity, Validation::Validators::Entity::Company, Validation::Validators::Entity::Ira, Validation::Validators::Entity::Person, Validation::Validators::Entity::Trust, Validation::Validators::Entity::Unknown, Validation::Validators::IdentityData::Name, Validation::Validators::IdentityData::RegisteredAgent, Validation::Validators::Verification
files:    app/services/validation/bank_account_data_service.rb, app/services/validation/concerns.rb, app/services/validation/concerns/progress_loggable.rb, app/services/validation/concerns/validatable.rb, app/services/validation/tax_id_service.rb, app/services/validation/utils/progress_tracker.rb, app/services/validation/utils/validation_error.rb, app/services/validation/utils/validation_helpers.rb, app/services/validation/utils/validation_result.rb, app/services/validation/validators/address.rb, app/services/validation/validators/common.rb, app/services/validation/validators/entity.rb, app/services/validation/validators/entity/company.rb, app/services/validation/validators/entity/ira.rb, app/services/validation/validators/entity/person.rb, app/services/validation/validators/entity/trust.rb, app/services/validation/validators/entity/unknown.rb, app/services/validation/validators/identity_data/name.rb, app/services/validation/validators/identity_data/registered_agent.rb, app/services/validation/validators/verification.rb
indexed:  3d8de9038bbe812df55253c6f34357c67e53da57
<!-- end machine-owned -->

## Judgment
`Validation::TaxIdService` is the wire hold: treasury holds an outgoing wire on any error it returns, and tax-ID validity is owned here, not in consumers. Historical bad data is fixed when money moves, not by loosening the rule. Every rule change widens or narrows the hold, so count the affected prod wire owners before changing one, and ship ipseity before treasury depends on it. It runs with `repeated_characters: false` because that heuristic rejects real SSNs that happen to repeat a digit; the bank-account-data report still uses it.
src: ~/.claude/projects/-Users-kevin-RubymineProjects--worktrees-treasury-haze/0aa676bd-8e4a-417d-b359-c88c99498977.jsonl 2026-10-19T18:59:13.963Z "I'd say B. domain wise we should move to ipseity.  If these are historical issues, they should be addressed point-in-time at time of money movement"
src: ~/.claude/projects/-Users-kevin-RubymineProjects/b5b83b14-e4e6-45b9-bfa6-2fa1de78fbf5.jsonl 2026-10-13T16:26:01.150Z "let's tighten it up per treasury and ensure they match.   Just limit the adoption to this use case for now in treasury."

A revocable trust with no EIN is checked on the first grantor's SSN, then the first signatory's. Grantor-only is the IRS-correct rule, but prod grantor data is empty (none of 46 such trusts had a grantor SSN, 31 had a signatory one), so don't drop the fallback until grantor data exists.
src: https://github.com/angellist/ipseity/pull/1681 2026-10-13T17:37:20Z "In prod, none of the 46 such trusts among recent wire owners has a grantor SSN on file, so a grantor-only rule would have newly held 31 of them." (kwliang1)

Deliberate differences: a person's SSN is validated as a US SSN whatever their address, while trusts and companies keep the address gate; a blank country counts as US for tax IDs but non-US in the report; EINs are checked on their 9 digits, ignoring hyphen placement. Each was left alone on purpose, so don't "align" them.
src: ~/.claude/projects/-Users-kevin-RubymineProjects/b5b83b14-e4e6-45b9-bfa6-2fa1de78fbf5.jsonl 2026-10-13T16:52:15.520Z "yes"
src: https://github.com/angellist/ipseity/pull/1681 2026-10-13T17:37:24Z "Declining. Pinning `XX-XXXXXXX` would hold wires for stored EINs that only have unusual hyphen placement." (kwliang1)
