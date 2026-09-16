---
name: ci-ssh-only-git-gems
description: "CI docker builds have ssh creds only — private git gems must use git@ remotes, never the github:/https shorthand"
metadata: 
  node_type: memory
  type: project
  originSessionId: cfc02842-b830-4d1e-b798-ea139c83ece6
---

The buildctl CI image build runs `RUN --mount=type=ssh bundle install` with **only ssh credentials** (no https token). The Bundler `github:` shorthand pins an **https** remote in Gemfile.lock, which fails for private repos with `fatal: could not read Username for 'https://github.com'`.

**Why:** Discovered 2026-06-10 when angellist/rubocop-angellist was made private (between 2026-06-01 and 2026-06-10) while still on a `github:` source — the next Gemfile.lock-changing PR (ipseity#1482) broke the build. The failure looks intermittent because the bundle-install docker layer is cached: only builds that change `Gemfile*` re-run the clone.

**How to apply:** Private angellist gems must use `git: 'git@github.com:angellist/<repo>'` in the Gemfile. Public repos (protip, zstd-ruby, temporal-ruby) are fine on https. Also: changing a git gem's remote forces bundler to re-resolve that gem to its default-branch HEAD (lockfile keeps no branch field), so expect a revision advance and regenerate the tapioca RBI (filenames embed version+revision). Related: [[ipseity-is-entity-api]].
