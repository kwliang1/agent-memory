---
name: ipseity specs run inside the docker container, not on host
description: rspec must be invoked via `docker exec ipseity-app-1 bundle exec rspec ...` because env vars like ENTITY_API_SECRET only exist inside the container
type: feedback
originSessionId: 03d0390b-ef5f-4d14-b91d-87282bab067d
---
In ipseity, run rspec inside the docker container: `docker exec ipseity-app-1 bundle exec rspec <path>`.

Why: the host shell does not have `ENTITY_API_SECRET` (and other dev env vars) loaded. `.env` and `.envrc` in the repo are empty placeholders. The values live in `.devcontainer/.env` and are injected only into the docker container. Running `bundle exec rspec` on the host fails with `Missing ENTITY_API_SECRET env variable` at boot.

How to apply: When you need to run ipseity specs locally for the pre-push gate (or any verification), check `docker ps` for `ipseity-app-1` first; start it via `docker-compose up -d` if needed; then `docker exec ipseity-app-1 bundle exec rspec <path>`. Sorbet typecheck (`bundle exec srb tc`) and `Rails.application.eager_load!` smokes do work on the host with `ENTITY_API_SECRET=test` because they don't need real secrets.
