---
name: alloy-alert-dri-mapping-automation
description: "The automation" that tags KYC DRIs in ipseity Alloy alerts = the angellist_user_mapping shared gem (config/mappings.yml), NOT ipseity code. How to add users.
metadata:
  type: reference
---

When Viv Hong / Madison Stomberg (KYC ops) ask Kevin to "add users to the automation" (in #alloy-alerts), the automation is **`AngellistUserMapping.map_flowdash_account_email(email, :slack_id)`** — it @-mentions the FD DRI in ipseity's Alloy KYC alerts.

**The user list is NOT in ipseity.** ipseity only *pins* the gem and calls it:
- `ipseity/app/services/alloy/slack_notification_service.rb:32` reads `task_assignee_email = task.dig(...ASSIGNED_TO)` (FlowDash owns assignment — **not round-robin**; the mapping is a passive email→slack-mention lookup).
- `ipseity/lib/slack_notifications.rb:55-59` → `AngellistUserMapping.map_flowdash_account_email`.

**The data lives in the `angellist_user_mapping` gem** (`git@github.com:angellist/angellist_user_mapping`, default branch `master`, local clone `/Users/kevin/RubymineProjects/angellist_user_mapping`), file `config/mappings.yml`. Lookup is reverse: find the entry whose `flowdash_account_email` == the email, return its `slack_id`.

To add a user (mirror Kevin's PRs #143 BT→AL email updates, #144 new add):
1. In the gem: add/update the entry keyed by email-localpart (dots kept, e.g. `paulomi.das:`), fields `slack_id` + `flowdash_account_email` (`user_id` optional — the flowdash→slack path never reads it; many entries omit it).
2. Bump `lib/angellist_user_mapping/version.rb` (patch) + prepend `CHANGELOG.md` (there's a `bump.sh`). Only CI gate = `ruby sort_mappings.rb --check` (keys sorted case-insensitive). No test suite.
3. After the gem PR merges to master, bump ipseity's `Gemfile.lock` pin via `bundle update angellist_user_mapping` (precedent = ipseity PR #1482). Two-repo change. **Also regenerate the gem's Sorbet RBI** — it's version+SHA-tagged (`sorbet/rbi/gems/angellist_user_mapping@<ver>-<sha>.rbi`), so the pin bump makes it stale: `bundle exec tapioca gem angellist_user_mapping --no-loc --no-doc` (= `make gem-rbis` scoped; runs on host, no docker needed for one gem). Repo convention is `--no-loc` (243 files vs 26 with locs). #1482 did the RBI regen too.

Belltower→AngelList ("BT→AL") credentials transition context: BT staff moved from `@belltowerfunds.com` to `@angellist.com`; their existing entries need the flowdash email domain updated or alerts silently drop the mention. See [[treasury-ewa-name-collision-rca]] for other KYC-ops-adjacent work.

2026-08-11 instance (DONE, both open→gem merged): gem PR #150 MERGED (add `paulomi_das` U0BLCLEAUFM — note underscore key per mehul review, not dot; move `thomas` U01UHAMN4HJ belltower→angellist; v1.0.132, master SHA d6e77f9). ipseity bump PR #1532 OPEN/not-merged (Gemfile.lock pin f39dc912/1.0.128 → d6e77f9/1.0.132). Gotcha: ipseity `git commit` needs `--no-verify` (husky lint-staged script missing) — keep `--gpg-sign`.
