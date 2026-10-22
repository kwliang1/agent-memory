<!-- machine-owned: regenerated every run, never hand-edit -->
---
concept: [treasury, frec]
related:
  - [treasury, money_market_fund]
  - [treasury, money_market_fund_account]
  - [treasury, application]
---
symbols:  Frec::Client, Frec::PayloadValidation, Frec::PayloadValidation::CreateAccountRequestBody, Frec::PayloadValidation::CreateAccountRequestBody::AccountInformation, Frec::PayloadValidation::CreateAccountRequestBody::AccountTradingInformation, Frec::PayloadValidation::CreateAccountRequestBody::AdditionalAccountInformation, Frec::PayloadValidation::CreateAccountRequestBody::Address, Frec::PayloadValidation::CreateAccountRequestBody::AffiliatedFinra, Frec::PayloadValidation::CreateAccountRequestBody::Args, Frec::PayloadValidation::CreateAccountRequestBody::AuthorizedSigner, Frec::PayloadValidation::CreateAccountRequestBody::Citizen, Frec::PayloadValidation::CreateAccountRequestBody::ControlPerson, Frec::PayloadValidation::CreateAccountRequestBody::Diligence, Frec::PayloadValidation::CreateAccountRequestBody::Disclosure, Frec::PayloadValidation::CreateAccountRequestBody::Disclosure::PoliticallyExposed, Frec::PayloadValidation::CreateAccountRequestBody::ExemptLegalCustomer, Frec::PayloadValidation::CreateAccountRequestBody::InvestmentProfile, Frec::PayloadValidation::CreateAccountRequestBody::Name, Frec::PayloadValidation::CreateAccountRequestBody::Person, Frec::PayloadValidation::CreateAccountRequestBody::SuitabilityProfile, Frec::PayloadValidation::CreateAccountRequestBody::W9Certification
files:    lib/frec/client.rb, lib/frec/payload_validation.rb
indexed:  b9e45f71df9f1334507931a1f0b575bc976578a7
<!-- end machine-owned -->

## Judgment
`Frec::Client.get_deposit_accounts` entries carry `id`, `status` (ACTIVE/PENDING/...),
`maskedRoutingNumber`, `maskedAccountNumber` (`********6168`) and `name`, verified from prod.
Only masked last-4s come back, so two bank accounts sharing both last-4s are
indistinguishable. `create_deposit_account` is not idempotent, and a new account lists as
PENDING. Frec account ids are 36-char UUIDs.
provenance: mmf-frec-deposit-account-routing-collision.md
