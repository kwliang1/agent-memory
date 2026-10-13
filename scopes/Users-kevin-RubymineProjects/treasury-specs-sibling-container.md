---
name: treasury-specs-sibling-container
description: Run treasury specs for a worktree with no container by `docker run` of another worktree's app image; revert the Gemfile.lock reorder it leaves behind.
metadata:
  type: reference
---
When a treasury worktree has no running container, borrow a running one's image: copy its env (`docker inspect <c> --format '{{range .Config.Env}}…'`) minus MOCK_IPSEITY/MOCK_ANGELLIST, set `TREASURY_DB_SUFFIX=_<yours>` and `RAILS_ENV=test`, then
`docker run --rm --network treasury --env-file … -v "$PWD":/app -v treasury_app-gems:/usr/local/bundle -w /app <c>-app bash -lc 'bundle exec rspec …'`.

Traps: the entrypoint's bundler rewrites `Gemfile.lock` GEM-section order — `git checkout -- Gemfile.lock` before committing. Inside the container git can't resolve the worktree's `.git` file, so `git diff` there is empty. `db:schema:load` may fail on an existing suffix DB (FK drop order) yet specs still run.
