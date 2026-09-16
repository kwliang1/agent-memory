---
name: hydra-codex-setup
description: "Codex engine requirements + 2026-07-21 spawn-failure diagnosis (bun ws shim, auth rotation gotcha)"
metadata: 
  node_type: memory
  type: project
  originSessionId: a060a12c-ac79-4234-8299-9dd2540fd217
  modified: 2026-07-21T16:33:57.836Z
---

Hydra's codex engine (`daemon/codex-engine.ts`, WS over unix socket) has two environment requirements that failed silently on 2026-07-21:

1. **Bun >= 1.3.14 is a hard requirement** (ws shim perMessageDeflate fix, stated in the engine header). Repo `.tool-versions` pinned 1.3.13 → every codex spawn died with "codex socket not ready after 15s … Connection ended" while the app-server itself was healthy. RESOLVED 2026-07-21: bumped repo AND global `~/.tool-versions` to 1.3.14, daemon restarted via watchdog (kill `slack-daemon` tmux session; launchd `com.hydra.watchdog` revives it ≤2min, clean env) and verified running `~/.asdf/installs/bun/1.3.14/bin/bun`. PR: sf8193/hydra#128 (repo is NOT Graphite-synced — `gt submit` fails; use `gt create` + plain `git push` + `gh pr create`). Ws probe trick for future debugging: connect `ws+unix://<CODEX_HOME>/app-server-control/app-server-control.sock:/` and expect an `initialize` response.
2. **`codex login status` lies** — it checks file shape, not token validity. The real signal is in `$CODEX_HOME/logs_2.sqlite` (`logs` table, `feedback_log_body`): "refresh token was already used. Please log out and sign in" = auth.json is dead (refresh tokens are single-use; syncing auth.json across machines invalidates copies). Fix: `codex logout && codex login`.

Codex installed via brew cask (0.144.6, 2026-07-21). Its `app-server --listen unix://` still speaks WebSocket upgrade on the unix socket (server module: `codex_app_server_transport::transport::unix_socket`).

Related: [[hydra-rebase-followups]] (.tool-versions was already a known TODO).
