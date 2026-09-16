---
name: worktree-dev-auth
description: Worktree dev DB needs venture@angellist.com user for auto-login — should be added to db/seed_local_admin.rb in a separate PR
metadata: 
  node_type: memory
  type: project
  originSessionId: 215788ce-471e-49a7-80fb-6f434420db54
---

When seeding a fresh worktree database for local testing, create a User with email `venture@angellist.com`. The `Users::OauthService.user_from_oauth` method (line 10) auto-returns this user in development mode, enabling passwordless auto-login.

**Why:** Worktree DBs are separate from the main checkout's Tonic-seeded DB and start empty. Without this user, the admin UI shows "must be logged in" (Pundit auth error).

**How to apply:** When seeding worktree data for E2E testing, always include:
```ruby
User.find_or_create_by!(email: "venture@angellist.com") { |u| u.password = "password123"; u.password_confirmation = "password123" }
```
No manual sign-in needed after this — the OAuth auto-login handles it.

**TODO:** Add this to `db/seed_local_admin.rb` so `make setup-worktree` includes it automatically. Kevin confirmed this should be a separate PR (not part of BANK-1550).
