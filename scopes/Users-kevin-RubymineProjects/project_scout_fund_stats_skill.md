---
name: project_scout_fund_stats_skill
description: "Scout fund stats across all 7 programs: the method, where the skill lives (arti + venture PR #37465), and the one open reconciliation item (Aleph)"
metadata:
  node_type: memory
  type: project
  originSessionId: d9e5eaea-6715-4c6a-ab71-f47fc5871200
  modified: 2026-10-15T19:49:26.355Z
---

The marketing scout numbers ($388M / 437 scouts / 3,830 investments, all time as of 2024-12-31) come from Kevin's RubyMine scratch `scout_funds/data_pulls/updated_marketing_site_data_pull.rb` (Feb 2025). On 2026-10-15 that method was written up as a skill: arti `scout-fund-stats-skill` (v2) and venture PR #37465 adding `.agents/skills/scout-fund-stats/SKILL.md`.

Seven buckets: productized (`is_scout_fund` + `ScoutFunds::InfoService`), Spearhead (LP invest-account slugs + `marked_as_spearhead_at` + `is_spearhead_fund` + rfund `is_spearhead`), Galaxy (`marked_as_galaxy_at`, partly INR), Powerset (`is_powerset_fund` + `marked_as_powerset_at`), Aleph (FundCampaign 37394), Valor Intrepid (hard-coded FundCampaign ids 30415, 30438, 31177, 32889, 36765, 39762; no flag exists), Foundation Capital (invest account 130998 `foca-admin`, count its own paid-in, never the whole funds).

Legacy-program dollars = parent-firm capital INTO the vehicle, not vehicle capital out.

Reconciled in Snowflake 2026-10-15: 8 of 9 lines match (exact or FX). Open: Aleph $7.43M in warehouse vs "$9.2M" rounded comment in the script. Rerun today gives ~$409M for the same as-of date because ~245 vehicles were flagged Spearhead after Feb 2025.

Devin reads `.agents/skills/` in venture (same dir as `testing-venture-staging`). Related: [[chaos-testing-devin-playbooks]], [[feedback_verify_totals_not_just_counts]].
