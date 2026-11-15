---
name: treasury-staging-ui-check-via-console
description: "Exercise treasury staging admin UI without a password: al staging write console + Integration::Session + Warden login_as; browser SSO doesn't reach authenticate-:user routes"
metadata:
  type: reference
---

Staging browser admin pages (`/maintenance_tasks`, `/typed_state_machines_v2`) return Devise "You need to sign in" (plain-text 401, `navigational_formats = []`). Staging is `Rails.env == "production"` (deploy_env distinguishes it), but OAuth header sign-in lives in `ApplicationController#try_oauth_sign_in!`, and these routes are inside `authenticate :user` in `config/routes.rb`, which rejects before any controller runs. Kevin has no staging password. Sentry is prod-only (`config/initializers/sentry.rb` enabled_environments), so use Datadog `env:staging` for errors.

**Recipe (verified 2026-10-27):** `/Users/kevin/bin/al console exec -a treasury -w -- echo ok` (staging is the default env; `create --no-attach` alone left a Konsole CR with no pod for 6+ min, but `exec` brought it up), then `al console push -a treasury -w <local.rb> /tmp/x.rb`, then `al console exec -a treasury -w -- bundle exec rails runner /tmp/x.rb`, then `al console delete -a treasury -w`. In the script: `Warden.test_mode!`, `login_as(user, scope: :user)`, `ActionDispatch::Integration::Session.new(Rails.application)` with `host! 'treasury.internal.angellist-staging.com'` and `https!`. Take the CSRF token from the form's hidden `authenticity_token` input; the MT UI page has no csrf meta tag. Dry-run locally in the worktree container first. The public `treasury.staging-us-west-2-hermes...` host 404s these admin paths.
