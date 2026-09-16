---
name: ipseity is the entity API
description: ipseity is the producer of the entity API; consumer repos like treasury/venture mock it via MOCK_ENTITY_API
type: project
originSessionId: 03d0390b-ef5f-4d14-b91d-87282bab067d
---
ipseity *is* the entity API service. It is not a consumer of one.

Why: Affects pre-push spec runs. The global CLAUDE.md directive to `unset MOCK_ENTITY_API` before specs applies to consumer repos (treasury, venture, comptroller, etc.) that mock calls *to* ipseity in development. ipseity itself has no MOCK_ENTITY_API to unset.

How to apply: In ipseity, run `bundle exec rspec` directly without the unset prefix. Look elsewhere for ipseity-specific mock toggles if any exist (none identified yet).
