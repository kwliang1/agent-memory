<!-- machine-owned: regenerated every run, never hand-edit -->
---
concept: [ipseity, encrypted_note]
related:
  - [ipseity, user]
  - [ipseity, address]
  - [ipseity, alloy]
---
symbols:  EncryptedNote
files:    app/models/encrypted_note.rb
indexed:  3d8de9038bbe812df55253c6f34357c67e53da57
<!-- end machine-owned -->

## Judgment
Admin role-change notes go on the Entity, not the KYC status: `kyb_statuses` can return an auto-built, unsaved status, and `create!` on an unsaved parent raises. The Entity is always persisted.
src: https://github.com/angellist/ipseity/pull/1644 2026-09-28T16:29:16Z "`kyb_statuses` can return an auto-built, unsaved status for an entity that has no row yet, and `create!` on an unsaved parent raises. The Entity is always persisted." (kwliang1)
