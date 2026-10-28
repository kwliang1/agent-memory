<!-- machine-owned: regenerated every run, never hand-edit -->
---
concept: [ipseity, ipseity_event]
related:
  - [ipseity, action_item]
  - [ipseity, entity]
  - [ipseity, application_job]
---
symbols:  IpseityEvent, IpseityEvents::CreateService, IpseityEvents::PublishJob, IpseityEvents::PublishService
files:    app/jobs/ipseity_events/publish_job.rb, app/models/ipseity_event.rb, app/services/ipseity_events/create_service.rb, app/services/ipseity_events/publish_service.rb
indexed:  3d8de9038bbe812df55253c6f34357c67e53da57
<!-- end machine-owned -->

## Judgment
When ipseity changes something a consumer caches, emit an event with the ChangedField that consumer handles; never patch the consumer's cache from ipseity. Treasury acts only on IdentityState, EntityName, TaxId, AlloyApplication and Address, and re-syncs `customer_accounts.verified` (which gates wires, ACH and MMF) on IdentityState. Any change to an input of `verified?` must emit IdentityState or treasury keeps clearing money for an entity ipseity calls unverified.
src: ~/.claude/projects/-Users-kevin-RubymineProjects/dbaff02e-c756-46e4-b80c-26d759043df3.jsonl 2026-09-25T18:05:47.382Z "the ideal pattern would be that an event is emitted and they handle accordingly"
