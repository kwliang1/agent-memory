---
name: treasury-worktree-shares-nats-prophet
description: A treasury worktree container (`make up`) joins the shared local NATS and silently takes a share of EVERY session's treasury Prophet calls against its own `_<name>` DBs; recipe to isolate it on a private NATS for e2e
metadata:
  type: project
---

Verified 2026-10-01 (treasury-plaidcat + nova plaidblock e2e).

**The trap:** `config/initializers/prophet.rb` hardcodes `nats://nats:4222` in docker dev. Every treasury container (main `treasury` and each `treasury-<wt>`) is on the `treasury`/`angellist` networks where `nats` = the one shared `nats` container (host :4222). The Prophet server pulls from a durable JetStream consumer named `q` (`prophet/scheduler.rb:100`), so it's a work queue: each request goes to ONE worker. A worktree container therefore (a) serves a random share of other sessions' nova→treasury Prophet calls against its empty `_<wt>` DB (seen: `customer_accounts.balance/details` → "Customer account not found"), and (b) does NOT reliably serve your own e2e calls. `make up` gives no hint. Check `docker logs treasury-<wt> | grep 'Request completed'`.

**Two transports nova→treasury:** Prophet/NATS (`graph/src/clients/treasury/request.ts`, e.g. create_microdeposit_verification) AND REST SDK (`graph/src/lib/sdk/treasury.ts`, `TREASURY_API_BASE_URI`, e.g. find_or_retrieve_and_store_bank_account). Venture's `TREASURY_API_BASE_URI` is a third, unrelated knob.

**Isolation recipe:**
1. `docker run -d --name nats-<wt> --network treasury -p 4223:4222 -v ~/RubymineProjects/deps/nats:/app:ro nats:latest --config=/app/nats.conf`
2. Scratch compose override: `services.app.extra_hosts: ["nats:<nats-<wt> IP on treasury net>"]`; `make up COMPOSE="docker compose -f docker-compose.yml -f docker-compose.worktree.yml -f <override>"`. Verify the peer via `/proc/net/tcp` inside the container.
3. Nova worktree: append `NATS_URL=nats://127.0.0.1:4223` and `TREASURY_API_BASE_URI=https://angellist.dev:<wt port>` to `.devcontainer/.env.worktree` (gitignored; last definition wins). Editing `.devcontainer/.env` is useless — `just dev up` regenerates it. Restart the process-compose stack, then confirm via `ps eww`.
4. Side effects: the private NATS also has NO ipseity (or other service) workers, so any nova→ipseity Prophet call fails. That includes `findOrCreateIpseityEntityId` on an entity whose `al_ipseity_entity_id` is NULL, which surfaces as a generic "Failed to create external bank reference" in 4ms with no treasury call. Workaround: seed `al_ipseity_entity_id` in the worktree DB (treasury runs `MOCK_IPSEITY=1`). Graph also logs `StreamNotFoundError` for the treasury events consumer.

Gotchas: restarting nova `graph` and `app` together races the sdk-treasury turbo build (ENOENT rename in `dist/core`). Restart them one at a time. Plaid sandbox can't trigger `BANK_TRANSFER_ACCOUNT_BLOCKED`, and `error_<CODE>` passwords fail inside Link before our server sees them, so server-side Plaid errors need a local fault hook.

Cleanup: `docker rm -f nats-<wt>`, revert `.env.worktree`, and recreate the container without the override.

Related: [[treasury-worktree-dev-loop]], [[worktree-never-raw-docker-compose]], [[treasury-nova-event-bridge]].
