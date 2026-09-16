---
name: bank1586-alloy-response-received-mover
description: "BANK-1586 \"update the Zap\" is really an ipseity code change; where the Alloy pending-docs→Flowdash flow lives, how to move a KYC task stage, and the design gotchas."
metadata: 
  node_type: memory
  type: project
  originSessionId: 7862d756-c4f4-474a-b5c6-7d740298348d
  modified: 2026-08-26T17:35:46.436Z
---

BANK-1586 ("auto-move linked tasks to Response Received on pending document upload") is **ipseity code**, not Zapier/Flowdash-native. Ops (Madison) call it "the Zap" but the #alloy-alerts poster is **Ipseity Bot** (the `Unabled to find task` typo is our code string).

**The flow:** `ipseity/app/models/alloy/journey/entity_application.rb:106` `after_pending_documents` (Alloy state-machine transition → `pending_documents`, skips if `approved?`) → `Flowdash::Workflow::KycReview.get_tasks_by_entity_id` (workflow `jWaIEG`, filter `Entity Id`, falls back to `entity.related_entities`) → `Alloy::SlackNotificationService.pending_documents_uploaded_message` posts to #alloy-alerts (C06SP940UDN).

**How to move a KYC task stage:** Flowdash `POST /workflows/:id/tasks` is an upsert that moves stage via `stage_name = params['Stage']` (flowdash `tasks_controller.rb:141`); data is MERGED, so a minimal payload is safe. Unique-id field is **`Id`** (= CustomerAccount uuid, else entity.id — treasury `build_flowdash_data`). Fetched task hashes already include `Id` and `Stage`. So: `Flowdash::Client.upsert_flowdash_task!('jWaIEG', { 'Id' => task['Id'], 'Stage' => 'Response Received' })`.

**Gotchas / design decisions:**
- **`Response Received` is NOT in treasury's `Flowdash::Workflow::KycReview::STAGES`** — treasury doesn't manage that stage (it's ops/outreach-set). MUST verify exact casing vs live workflow `flowdash.internal.angellist.com/workflows/jWaIEG/stages/all`. `Verified`/`In Progress` are in treasury's enum.
- Ticket's literal "skip only Response Received/Verified" is **unsafe** — would yank tasks out of Rejected/Suspicious LPs/Invalid/Inactive/Test/Duplicate/Verified Externally.
- **BEST GUARD: fetch active tasks only (`/tasks/active`), don't hardcode a list.** Flowdash Tasks API `/tasks/active` = "tasks not in an end stage" (confirmed in flowdash `docs/api/tasks-api/index.md`). ipseity client already supports it: `get_flowdash_tasks_with_filters(..., only_active: true)`. So fetch active tasks by entity id → terminal stages (Verified + Rejected/Invalid/Inactive/Test/Duplicate/etc. IF ops flagged them `end_stage`) auto-excluded. Keep an explicit `next if Stage == 'Response Received'` to avoid a no-op self-move retriggering automations.
- REST **stages list exposes `name` ONLY** (`stages/base.json.rabl`; docs example `[{"name":...}]`) — no `end_stage`/terminal flag (that's GraphQL-only). Good for validating exact casing, useless for terminal detection → hence use `/active` instead.
- Caveat `/active` can't resolve: non-end but in-flight stages (e.g. `Escalated`, active compliance-review) are NOT excluded by the active filter. Ask Madison/Nick if any working stage must be protected; if so add explicit skips on top.
- Pre-existing bug: `slack_notification_service.rb:25` computes `filtered_tasks` (rejects In Progress) but line 30 iterates unfiltered `tasks` → filter is dead. Fix in same PR.
- ipseity `FLOWDASH_WORKSPACE_API_KEY` currently read-only against jWaIEG — confirm write scope.
- Low race: treasury hourly `sync_in_progress_tasks` re-derives stage for In-Progress tasks; rare clobber.

Implement in ipseity (trigger + client live there). See [[flowdash-treasury-ca-creation]].

**SHIPPED + evolution (as of 2026-08-26).** Logic now lives in `ipseity/lib/flowdash/workflow/kyc_review.rb` as a fail-closed **allow-list** `ADVANCE_FROM_STAGES` — a task advances to Response Received only if its current Stage is on the list. `advance_tasks_to_response_received!` is the ONLY writer of the RESPONSE_RECEIVED stage; caller is `app/models/alloy/journey/entity_application.rb:186` (after_pending_documents). Same Slack thread (C06SP940UDN ts 1783548570.190979) has spawned successive ops tweaks, each just editing the allow-list:
- Original BANK-1586: allow-list = In Progress, Needs Review, Needs Follow-Up, Time Sensitive.
- Tweak 1 (Viv, live ~08-12): exclude **In Progress** (unassigned 24h buffer → auto-flows to Needs Review where assignment happens).
- Tweak 2 (Viv, PR #1573, 2026-08-26): exclude **Needs Review** too (assignment + time-tracking stage). Now `[Needs Follow-Up, Time Sensitive]`.
- Non-strand guarantee: `app/services/alloy/slack_notification_service.rb:25` only filters In Progress from the #alloy-alerts ping, so excluded-stage tasks still notify ops → they work them manually. Note the historical dead-filter bug there was about `filtered_tasks`; verify current state before citing.
Future asks on this thread are almost certainly "add/remove a stage from ADVANCE_FROM_STAGES" — a ~1-line change + spec.

**DEPRECATION IN FLIGHT (2026-08-26).** Thomas Ambrosia now has a **Flowdash-native** automation that does the same stage-change on doc upload (FD workflow automations jWaIEG/Qnu3qbn and X0I0K2/29u3NP1). Plan: validate his solo, then delete the ipseity hook entirely. PR #1574 (kevinliang/kyc-auto-advance-flipper, stacked on #1573) adds a Flipper **kill-switch** `:pause_kyc_auto_advance_response_received` around the advance call in `entity_application.rb after_pending_documents` (`advance… if !Flipper.enabled?(:pause_…)`; rubocop enforces `if !` over `unless`). Defaults OFF = no behavior change; flip ON in `/flipper` prod to pause the ipseity auto-advance (the #alloy-alerts notification still fires). ipseity Flipper: AR adapter, bare-symbol flags, no registration, `/flipper` UI (routes.rb:32); specs use `Flipper.enable(:flag)` (rolled back by transactional fixtures). If asked to "kill the hook", the whole `after_pending_documents` advance path + `advance_linked_kyc_tasks_to_response_received!` + `Flowdash::Workflow::KycReview` can go once Thomas's is at parity.
