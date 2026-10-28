<!-- machine-owned: regenerated every run, never hand-edit -->
---
concept: [ipseity, dev_tool]
related:
  - [ipseity, alloy]
  - [ipseity, production_console]
---
symbols:  DevTools, DevTools::Tonic, DevTools::Tonic::AlloyJourneyTokenAligner, DevTools::Tonic::IpseityGenerator, DevTools::Tonic::VentureApiKeySeeder
files:    lib/dev_tools/tonic/alloy_journey_token_aligner.rb, lib/dev_tools/tonic/ipseity_generator.rb, lib/dev_tools/tonic/venture_api_key_seeder.rb
indexed:  3d8de9038bbe812df55253c6f34357c67e53da57
<!-- end machine-owned -->

## Judgment
The weekly Tonic restore wipes staging's `api_keys` (prod digests must not authenticate there), so the restore's finalize step re-seeds the key Venture staging already sends. Falling back to `ENTITY_API_SECRET` was rejected because it reverses the ApiKey rollout. A new staging API consumer needs the same seeding or it 401s after the next restore.
src: https://github.com/angellist/ipseity/pull/1687 2026-10-19T19:55:21Z "Let's re-seed the staging key in each service's `additionalFinalizeCommands`" (thibaut-pro)

A Tonic restore copies prod's Alloy `journey_token` values unmasked, and every Alloy lookup is scoped by the local `ALLOY_JOURNEY_TOKEN`, so verification status 404s until `tonic:align_alloy_journey_tokens` runs in finalize. A replacement rule in `IpseityGenerator` can't work: the generator runs against prod and doesn't know the destination's token.
src: https://github.com/angellist/ipseity/pull/1647 2026-10-03T15:17:08Z "Why not a Tonic replacement rule in `IpseityGenerator`: the generator runs against prod and can't know the destination environment's token" (devin-ai-integration for thibaut-pro)
