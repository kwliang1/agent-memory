---
name: treasury-worktree-gemnotfound-gh-token
description: "Worktree `make setup-worktree`/`make up` dies with Bundler::GemNotFound when main's Gemfile.lock moved ahead; bundle install needs a GitHub Packages credential, use `gh auth token`"
metadata:
  node_type: memory
  type: reference
  originSessionId: c8ae6210-0d96-4610-a63a-ca664ed6fb67
  modified: 2026-10-07T16:57:31.515Z
---

Seen 2026-10-06 (BANK-2227): `make setup-worktree` and `make up` died with `Could not find rubyzip-3.4.0 in locally installed gems`. The worktree app container mounts the SHARED `treasury_app-gems` volume (`docker-compose.worktree.yml`), and that volume lags origin/main's Gemfile.lock. `make rebuild` does not help.

`bundle install` needs credentials for `rubygems.pkg.github.com/angellist`. Neither the container env nor `.devcontainer/.env` has them. `gh auth token` has `read:packages`, so pass it per command:

```sh
TREASURY_WORKTREE_NAME=<name> TREASURY_APP_PORT=<port> docker compose -f docker-compose.yml -f docker-compose.worktree.yml \
  run --entrypoint "" --rm --no-deps -e BUNDLE_RUBYGEMS__PKG__GITHUB__COM="kwliang1:$(gh auth token)" app bundle install
```

The host bundle needs the same fix, or the PreToolUse lint hook blocks `git commit`: `BUNDLE_RUBYGEMS__PKG__GITHUB__COM=... bundle install`.

**Then run `git checkout -- Gemfile.lock`.** bundle install drops the GitHub-packages `GEM` block from the lockfile.

Port gotcha: the Makefile picks a port by `lsof` and missed a docker-bound 7021, so the new container collided with another worktree's. Write a free port into `.worktree-port` by hand. Related: [[treasury-worktree-spec-run]], [[feedback_worktree-never-raw-docker-compose]].
