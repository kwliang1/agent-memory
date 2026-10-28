<!-- machine-owned: regenerated every run, never hand-edit -->
---
concept: [ipseity, role]
related:
  - [ipseity, entity]
  - [ipseity, roles_handler]
  - [ipseity, integration]
---
symbols:  Roles, Roles::AccreditationVerifier, Roles::Companies::Investor, Roles::ControlPerson, Roles::FundLead, Roles::Grantor, Roles::Individual, Roles::MajorShareholder, Roles::Signatory
files:    app/models/roles/accreditation_verifier.rb, app/models/roles/companies/investor.rb, app/models/roles/control_person.rb, app/models/roles/fund_lead.rb, app/models/roles/grantor.rb, app/models/roles/individual.rb, app/models/roles/major_shareholder.rb, app/models/roles/signatory.rb
indexed:  3d8de9038bbe812df55253c6f34357c67e53da57
<!-- end machine-owned -->

## Judgment
A grantor is deliberately not in `AdminRoleUpdateService::OWNERSHIP_KINDS`, so adding or removing one doesn't reopen major-shareholder review. Reopening only unverified the trust and froze its money: `verified_trust?` never reads grantors, and a trust's beneficial owner is the trustee. Instead a grantor add, including a swap into the grantor seat, is refused until that person's watchlist check has cleared.
src: https://github.com/angellist/ipseity/pull/1646 2026-10-15T16:53:49Z "That unverifies the trust, and blocks its money movement, until ops re-approves. It bought nothing: `verified_trust?` never reads grantors." (kwliang1)
src: ~/.claude/projects/-Users-kevin-RubymineProjects/247c459e-21ec-4c90-a730-85d262c513b0.jsonl 2026-10-14T20:30:50.337Z "tighten, 2"

The beneficial-owner count and its confirmation date live on `Roles::Companies::Investor` in ipseity. Venture must not cache or dual-write them; if venture needs an "ask again" signal, ipseity returns a freshness status. The role's 1-year expiry can't serve: it is fixed at creation and terminal.
src: ~/.claude/projects/-Users-kevin-RubymineProjects/1a2fe1c6-7645-48a2-870e-0ff8216cd14f.jsonl 2026-10-25T15:53:55.956Z "My main concern was that we were caching beneficial owners in venture. Tell me if it exists in ipseity and design an action plan with proper boundaries"
src: ~/.claude/projects/-Users-kevin-RubymineProjects/1a2fe1c6-7645-48a2-870e-0ff8216cd14f.jsonl 2026-10-25T18:35:23.754Z "I believe venture has an annual attestation, but it sounds like ipseity should be aware and return a status accordingly"
