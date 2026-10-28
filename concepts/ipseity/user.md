<!-- machine-owned: regenerated every run, never hand-edit -->
---
concept: [ipseity, user]
related:
  - [ipseity, encrypted_note]
  - [ipseity, entity]
  - [ipseity, alloy]
---
symbols:  User, Users::OauthService, Users::SessionsController
files:    app/controllers/users/sessions_controller.rb, app/models/user.rb, app/services/users/oauth_service.rb
indexed:  3d8de9038bbe812df55253c6f34357c67e53da57
<!-- end machine-owned -->

## Judgment
Production admin login is SSO-only through the OAuth2 proxy, so admins have no Devise password. Routes expose only Devise sessions, and the change-password page was deleted rather than patched. Don't add `:registerable` or password flows back during an upgrade.
src: https://github.com/angellist/ipseity/pull/1651 2026-09-30T21:23:43Z "nothing in the app links to it; production login is SSO-only via the OAuth2 proxy, so admins have no known Devise password to satisfy `current_password`" (devin-ai-integration for nickgervasi)
