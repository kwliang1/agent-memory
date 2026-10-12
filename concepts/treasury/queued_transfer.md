<!-- machine-owned: regenerated every run, never hand-edit -->
---
concept: [treasury, queued_transfer]
related:
  - [treasury, transfer]
  - [treasury, fdic]
  - [treasury, customer_account]
---
symbols:  QueuedTransfer, QueuedTransfers::CreateService, QueuedTransfers::FetchService, QueuedTransfers::InfoService, QueuedTransfers::StateService
files:    app/models/queued_transfer.rb, app/services/queued_transfers/create_service.rb, app/services/queued_transfers/fetch_service.rb, app/services/queued_transfers/info_service.rb, app/services/queued_transfers/state_service.rb
indexed:  b9e45f71df9f1334507931a1f0b575bc976578a7
<!-- end machine-owned -->

## Judgment
Open as of 2026-10-01 (INC-5717): back-to-back TP books on one sub-account can each pass the pre-submit balance check and then be NSF-rejected. Kevin rejected gating on the 15-minute queued cron (it re-races at the queued run or drains at N x 15 min). He doubted subtracting in-flight transfers (double counting), floated living with it, then asked about catching the NSF and retrying. A four-option draft for #banking-cool-people was saved, not posted; no decision.
src: -Users-kevin-RubymineProjects/e268aac8-3bb3-4e9c-b1c9-c8b3c868193a.jsonl 2026-10-01T05:33:01Z "they race against each other at the subsequent queued run, or they get spaced out N * 15"
src: -Users-kevin-RubymineProjects/e268aac8-3bb3-4e9c-b1c9-c8b3c868193a.jsonl 2026-10-01T05:34:15Z "I'm not convinced double counting isn't an issue.   we still run into the subsequent queued race.   this feels like a race condition we live with"
src: -Users-kevin-RubymineProjects/e268aac8-3bb3-4e9c-b1c9-c8b3c868193a.jsonl 2026-10-01T05:35:42Z "can we catch the submission error and roll the transaction back, then reattempt?"
