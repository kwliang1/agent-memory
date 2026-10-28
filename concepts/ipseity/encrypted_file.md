<!-- machine-owned: regenerated every run, never hand-edit -->
---
concept: [ipseity, encrypted_file]
related:
  - [ipseity, action_item]
  - [ipseity, alloy]
  - [ipseity, integration]
---
symbols:  EncryptedFile, EncryptedFiles::CreateService, EncryptedFiles::DocumentService, EncryptedFiles::DocumentService::StillProcessingError, EncryptedFiles::UpdateService
files:    app/models/encrypted_file.rb, app/services/encrypted_files/create_service.rb, app/services/encrypted_files/document_service.rb, app/services/encrypted_files/update_service.rb
indexed:  3d8de9038bbe812df55253c6f34357c67e53da57
<!-- end machine-owned -->

## Judgment
`skip_file_contents` on `EncryptedFileQuery` is an opt-in flag, chosen over a new metadata endpoint because Protip `find` and `.all` already send that query. Metadata-only callers should pass it: the default polls document-service for up to 30s and returns 409 when it gives up, which a permanently missing document also produces. Flipping the default waits on venture's six byte-reading callers. An older entity_api client raises `ArgumentError: Unrecognized field` on the flag, so a consumer bumps its gem first.
src: ~/.claude/projects/-Users-kevin-RubymineProjects--worktrees-ipseity-scout/2d8a97ff-137d-4ae8-b0fb-85025e17f650.jsonl 2026-10-06T20:08:28.232Z "why make it opt-out instead of a net new metadata endpoint?   what about venture callers?"
src: https://github.com/angellist/ipseity/pull/1654 2026-10-08T17:16:05Z "It stays opt-in: seven callers (six venture, one treasury) still read the bytes, so flipping the default would silently hand them empty files." (kwliang1)
