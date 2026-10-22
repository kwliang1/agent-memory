---
name: treasury-worktree-pr-screenshots
description: Recipe for screenshotting a treasury worktree page with Playwright and hosting the PNGs in a PR body
metadata:
  type: reference
---

Verified 2026-10-19.

- App is HTTPS on the worktree port: `https://localhost:<.worktree-port>` (plain http gets nginx 400). Apply the SSR hosts fix first ([[worktree-ssr-auth-gap]]) and make sure `venture@angellist.com` exists ([[worktree-dev-auth]]).
- Frontend 500 with "Can't resolve '@angellist/adapt…'" means the container's `frontend/node_modules` is half-installed. Fix: `docker exec -e GITHUB_TOKEN_PKG="$(gh auth token)" treasury-<wt> bash -lc "cd /app/frontend && bun install --frozen-lockfile"`.
- Seeding with factories from `rails runner`: set `FactoryBot.definition_file_paths = %w[spec/factories spec/backend/dibs/factories]; FactoryBot.reload` (DIBS factories aren't on the default path).
- Playwright: the npx-cached `playwright-core` expects a browser build that isn't downloaded. Launch with `chromium.launch({ channel: 'chrome' })` to use installed Chrome; `ignoreHTTPSErrors: true`.
- Hosting: `gh gist create` (secret) then `git clone https://gist.github.com/<id>.git`, add PNGs, push. Use `https://gist.githubusercontent.com/<user>/<id>/raw/<file>` in `<img>` tags. Crop to the component — no customer-looking names in the shot.
- The repo's pre-commit docs hook fires on ANY `git commit` in the command, including the gist clone's; re-run after the marker is set.
