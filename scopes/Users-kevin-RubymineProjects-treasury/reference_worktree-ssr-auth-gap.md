---
name: worktree-ssr-auth-gap
description: "Worktree e2e blocked by Next SSR auth fetch targeting main checkout's treasury:3001 host"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 17e0b963-d148-4cdf-ab88-58e767c74903
---

Worktree dev e2e in the browser 302s to `/v/login` even with the seeded `venture@angellist.com` dev-auto-login user. Cause: the frontend `CurrentUserProvider` is a Next SERVER component (`frontend/contexts/CurrentUser/server.tsx`) that does an SSR `serverSideQuery` to the backend at `TREASURY_API_BASE_URI`, which the container env sets to `http://treasury:3001` — the MAIN checkout's compose service name, unreachable from a `treasury-<name>` worktree container (whose own Rails listens on `:3001` internally, nginx on `:3000`). SSR fetch fails → `currentUser` null → `LoginRedirect` fires. The client `/graphql` DOES auto-auth in dev (via `try_oauth_sign_in!` before_action returning `venture@angellist.com`), so curl/GraphQL work — only SSR is broken.

Local workaround for a running worktree container: `docker exec treasury-<name> bash -lc "grep -q '127.0.0.1 treasury' /etc/hosts || echo '127.0.0.1 treasury' >> /etc/hosts"` — aliases `treasury`→localhost so the SSR fetch reaches the worktree's own Rails on `:3001`. Then reload the page; auth works.

Real fix (worth a ticket): worktree `make up` should set `TREASURY_API_BASE_URI=http://localhost:3001` (the frontend `.env` already has this; a compose override clobbers it to `treasury:3001`). Until then, worktree browser e2e needs the host-alias workaround. See [[bank1620-url-persistence]], [[worktree-dev-auth]].
