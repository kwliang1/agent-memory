<!-- machine-owned: regenerated every run, never hand-edit -->
---
concept: [ipseity, maintenance_tasks_ui]
---
symbols:  MaintenanceTasksUi::CsvUpload, MaintenanceTasksUi::DocumentCsvFile, MaintenanceTasksUi::InfoService, MaintenanceTasksUi::InfoService::TaskStats, MaintenanceTasksUi::RunCsvFile, MaintenanceTasksUi::TasksController
files:    app/controllers/maintenance_tasks_ui/tasks_controller.rb, app/services/maintenance_tasks_ui/csv_upload.rb, app/services/maintenance_tasks_ui/document_csv_file.rb, app/services/maintenance_tasks_ui/info_service.rb, app/services/maintenance_tasks_ui/run_csv_file.rb
indexed:  3d8de9038bbe812df55253c6f34357c67e53da57
<!-- end machine-owned -->

## Judgment
CSV uploads go straight to Document Service, and the run keeps only `document_id` in its metadata. There is no local record: ipseity has no ActiveStorage, and `DocumentServiceDocument` must belong to an `EncryptedFile`, whose owners have UUID ids while a run's id is an integer.
src: https://github.com/angellist/ipseity/pull/1655 2026-10-07T19:39:22Z "`DocumentServiceDocument` must belong to an `EncryptedFile`, and `EncryptedFile` has a fixed owner type list with UUID owner ids. A run has an integer id." (harsohailB)
