---
name: inc-5437-alloy-path-deleted-not-fixed
description: "INC-5437 was misdiagnosed because ipseity AND treasury both had an Api::AlloysController#process_webhook_event; treasury's whole Alloy path was later deleted by #8458, so the exposure closed by removal"
metadata:
  type: reference
---

**The trap that caused the misdiagnosis:** ipseity and treasury each had a controller at the same path with the same action — `Api::AlloysController#process_webhook_event`. A fix was merged in ipseity (#1522) and reverted (#1526) once it turned out the crashing code was the *other* one.

**Current state — do not go hunting.** Treasury's Alloy webhook path no longer exists. PR #8458 (merged 2026-08-11) deleted `app/controllers/api/alloys_controller.rb`, `app/services/alloy/webhook_service.rb` and the alloy route. Verified 2026-09-16: `grep -rl AlloysController` over treasury's `app`, `config` and `lib` returns nothing, and the only match on this machine is ipseity's.

So INC-5437's exposure closed **by removal, not by a guard**. Do not re-add a nil-guard to a deliberately deleted file, and do not treat Sentry `TREASURY-69W` as live.

`Alloy::WebhookEvent` survives at `app/models/alloy/webhook_event.rb:18` with no writers — dormant, not in use.

Background and the revert chain are in the ipseity scope: `bank-1586-response-received-plan.md`.
