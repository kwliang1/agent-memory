<!-- machine-owned: regenerated every run, never hand-edit -->
---
concept: [ipseity, kyc_aml_status]
related:
  - [ipseity, entity]
  - [ipseity, integration]
  - [ipseity, kyc_aml_statuses_job]
---
symbols:  KycAmlStatus::AdverseMediaConcern, KycAmlStatus::BaseConcern, KycAmlStatus::IdentityConcern, KycAmlStatus::RelatedEntitiesConcern, KycAmlStatus::WatchlistConcern, KycAmlStatuses, KycAmlStatuses::FetchService, KycAmlStatuses::India, KycAmlStatuses::India::Company, KycAmlStatuses::India::Person, KycAmlStatuses::India::Trust, KycAmlStatuses::UnitedStates, KycAmlStatuses::UnitedStates::Company, KycAmlStatuses::UnitedStates::Person, KycAmlStatuses::UnitedStates::Trust
files:    app/models/concerns/kyc_aml_status/adverse_media_concern.rb, app/models/concerns/kyc_aml_status/base_concern.rb, app/models/concerns/kyc_aml_status/identity_concern.rb, app/models/concerns/kyc_aml_status/related_entities_concern.rb, app/models/concerns/kyc_aml_status/watchlist_concern.rb, app/models/kyc_aml_statuses/india/company.rb, app/models/kyc_aml_statuses/india/person.rb, app/models/kyc_aml_statuses/india/trust.rb, app/models/kyc_aml_statuses/united_states/company.rb, app/models/kyc_aml_statuses/united_states/person.rb, app/models/kyc_aml_statuses/united_states/trust.rb, app/services/kyc_aml_statuses/fetch_service.rb
indexed:  3d8de9038bbe812df55253c6f34357c67e53da57
<!-- end machine-owned -->

## Judgment
Emit IdentityState whenever `major_shareholders_reviewed` changes, in both directions. When only the reopen emitted, re-closing review left treasury's cached verification stale indefinitely. Consumers re-read the authoritative value, so over-emitting is the safe side.
src: https://github.com/angellist/ipseity/pull/1644 2026-09-29T16:14:40Z "Reopening major-shareholder review told consumers the entity had gone unverified, but re-closing it emitted nothing — so a consumer caching verification state stayed stale indefinitely. Treasury gates money movement on that cache." (kwliang1)
