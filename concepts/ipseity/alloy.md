<!-- machine-owned: regenerated every run, never hand-edit -->
---
concept: [ipseity, alloy]
related:
  - [ipseity, entity]
  - [ipseity, kyc]
  - [ipseity, encrypted_file]
---
symbols:  Alloy::ApiService, Alloy::ApiService::AuthError, Alloy::ApiService::ClientError, Alloy::ApiService::Error, Alloy::ApiService::FetchResult, Alloy::ApiService::NotFoundError, Alloy::ApiService::ResponseCounter, Alloy::ApiService::TransientError, Alloy::CaseService, Alloy::Document, Alloy::DocumentService, Alloy::Entity, Alloy::Evaluation, Alloy::EvaluationIngestService, Alloy::EvaluationIngestService::RowResult, Alloy::IngestEvaluationsJob, Alloy::Journey::EntityApplication, Alloy::Journey::EntityApplication::DashboardStatusLabel, Alloy::Journey::EntityApplication::Outcome, Alloy::Journey::EntityApplication::Status, Alloy::JourneyApplication::BodyService, Alloy::JourneyApplication::CreateService, Alloy::JourneyApplication::InfoService, Alloy::JourneyApplication::ParserService, Alloy::JourneyApplication::StateService, Alloy::JourneyApplication::UpdateService, Alloy::ListService, Alloy::SlackNotificationService, Alloy::SubmitSupportingDocumentsJob, Alloy::SubmitSupportingDocumentsJob::DocumentsStillProcessingError, Alloy::VerificationRecords::UpdateService, Alloy::VerificationStatus, Alloy::VerificationStatus::Status, Alloy::WebhookEvent, Alloy::WebhookService, Alloy::WebhookService::JourneyApplicationStatusChangeEvent, Alloy::WebhookService::WebhookType
files:    app/jobs/alloy/ingest_evaluations_job.rb, app/jobs/alloy/submit_supporting_documents_job.rb, app/models/alloy/document.rb, app/models/alloy/entity.rb, app/models/alloy/evaluation.rb, app/models/alloy/journey/entity_application.rb, app/models/alloy/verification_status.rb, app/models/alloy/webhook_event.rb, app/services/alloy/api_service.rb, app/services/alloy/case_service.rb, app/services/alloy/document_service.rb, app/services/alloy/evaluation_ingest_service.rb, app/services/alloy/journey_application/body_service.rb, app/services/alloy/journey_application/create_service.rb, app/services/alloy/journey_application/info_service.rb, app/services/alloy/journey_application/parser_service.rb, app/services/alloy/journey_application/state_service.rb, app/services/alloy/journey_application/update_service.rb, app/services/alloy/list_service.rb, app/services/alloy/slack_notification_service.rb, app/services/alloy/verification_records/update_service.rb, app/services/alloy/webhook_service.rb
indexed:  3d8de9038bbe812df55253c6f34357c67e53da57
<!-- end machine-owned -->

## Judgment
`Entities::Verifications::AlloyService.verify!` returns nil without calling Alloy for anyone `can_verify?` rejects: no birthdate, no address, missing name parts, or no SSN on a US address. Grantors and other related parties are usually just a name, so "re-run verification" or "reopen review so it re-closes" screens nobody for them. A flow that must guarantee screening gates on the watchlist check having actually cleared.
src: ~/.claude/projects/-Users-kevin-RubymineProjects/247c459e-21ec-4c90-a730-85d262c513b0.jsonl 2026-10-13T16:36:07.086Z "1"
src: https://github.com/angellist/ipseity/pull/1646 2026-10-15T16:53:48Z "Re-closing review runs the Alloy identity check, which skips anyone without a birthdate and address (and an SSN for a US address), and a grantor is usually just a name." (kwliang1)

A method that rescues into `ErrorTracker.error` returns a truthy `Sentry::Event` in production, so `if result` treats a failure as success. `Alloy::JourneyApplication::CreateService.create_for_entity!` ends its rescue that way: check `result.is_a?(Alloy::Journey::EntityApplication)`. Specs that stub ErrorTracker hide it.
src: https://github.com/angellist/ipseity/pull/1408 2026-04-09T20:30:32Z "`create_for_entity!`'s rescue block ends with `ErrorTracker.error(...)` which in production returns a truthy `Sentry::Event` from `Sentry.capture_message`." (dcetlin)

New Alloy background work goes on Temporal, not GoodJob. Starting a workflow from inside `create_for_entity!`'s `ensure` puts Temporal's frontend and a lazy client connect on venture's synchronous `verify_identity` path, which is why that job is still GoodJob. On a GoodJob job, dedupe with `enqueue_limit: 1, perform_limit: 1`: `total_limit` counts the running job and drops a re-verification that arrives mid-run.
src: ~/.claude/projects/-Users-kevin-RubymineProjects/f5e54d3f-cd3b-43aa-8595-601b1c659ad3.jsonl 2026-10-28T03:52:33.347Z "Temporal is preferred over good job now"
src: https://github.com/angellist/ipseity/pull/1639 2026-10-06T22:40:31Z "This runs inside the request's `ensure`. What happens to `verify_identity` latency when Temporal's frontend is slow or unreachable?" (nes-angellist)

Consumers read Alloy application states from the gem's `EntityAPI::Alloy::EntityApplication::State` constants, never hard-coded strings. They are plain strings on purpose: a proto enum would change the wire type for every consumer. A new state changes the state machine and `State::ALL` together and bumps the gem.
src: ~/.claude/projects/-Users-kevin-RubymineProjects/5e2b44a5-2663-4af8-af44-1c614f3e335a.jsonl 2026-10-15T17:56:42.027Z "are these consts still relevant? shouldn't they come from ipseity?"
src: https://github.com/angellist/ipseity/pull/1685 2026-10-15T18:44:06Z "This adds `EntityAPI::Alloy::EntityApplication::State` ... to the gem as plain string constants, no wire change" (kwliang1)
