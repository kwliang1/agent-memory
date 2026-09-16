---
name: treasury-local-dev-gotchas
description: "treasury repo — host-side rspec can't boot from tooling (secret env), and git push needs --no-verify (broken husky) but keep --gpg-sign. Affects the pre-push review gate."
metadata: 
  node_type: memory
  type: reference
  originSessionId: ddd981c0-1836-4867-be4b-af3bc868808c
  modified: 2026-08-10T19:55:07.888Z
---

Working in `/Users/kevin/RubymineProjects/treasury` from Claude Code tooling (2026-07-27):

**Host-side `bundle exec rspec` CANNOT boot.** The Rails env needs secrets that are NOT in any reachable file or shell: `TREASURY_ENCRYPTION_PRIMARY_KEY` / `_DETERMINISTIC_KEY` / `_KEY_DERIVATION_SALT` (config/application.rb:64-71), `AL_API_CLIENT_ID` (config/initializers/angellist_api_setup.rb), etc. `.envrc` is just `dotenv_if_exists ".env"`; `.env`/`.env.local` hold only MOCK/CRONITOR vars — NOT these. Not in the login shell (`zsh -lic` check = empty). They're injected by RubyMine run-configs / 1Password at a layer the Bash tool can't see. Setting dummy `TREASURY_ENCRYPTION_*` gets past encryption but then `AL_API_CLIENT_ID` (and a cascade) fail. → For [[the pre-push review gate]], **rely on Buildkite rspec shards + independent review agents**; you can't reproduce the local green run here. Be explicit to Kevin about this.

**Sorbet DOES run host-side:** `bundle exec srb tc` (static, no creds/DB) — use it for local type validation.

**Read-only PROD console DOES work for DB reads (2026-08-10 update):** `al console exec -p -- bundle exec rails runner /tmp/foo.rb` runs Ruby against an existing read-only console pod (e.g. `console-read-kevin.liang-0`, see `al console list -p`); push a script first with `al console push -p local.rb /tmp/foo.rb`. Each runner boots Rails (~30–60s) — batch all reads into one script. Confirmed: `CustomerAccount`/`LedgerEntry`/`MoneyMarketFund::Yield` lookups, `net_liquidation_value`/`cash_balance`/`position_balance`. **Caveat:** read-only console still has NO Frec creds — `Frec::Client.*` won't reach Frec's API (need the write console for that). Reads only, never writes.

**git push/commit need `--no-verify`:** husky hooks are broken in this env (`.husky/_/husky.sh: No such file or directory`, `lint-staged` not found) — they abort every `git commit`/`git push`. Use `--no-verify` to skip the broken hook, but ALWAYS keep `--gpg-sign` (signing is separate; branch protection requires verified signatures — see global CLAUDE.md "never disable commit signing"). Amend/rebase with `--gpg-sign` re-signs.

**Signed commits show `N`/"No signature" locally — DON'T panic, they ARE signed.** `git config commit.gpgsign=true`, `gpg.format=ssh`. After `git commit --gpg-sign`, `git log --show-signature`/`%G?` reports `N` and errors `gpg.ssh.allowedSignersFile needs to be configured` — that's only LOCAL verification failing (no allowedSignersFile configured), NOT an unsigned commit. Confirm it's actually signed via `git cat-file commit HEAD | grep gpgsig` (SSH signature header present) — every already-merged commit on a branch shows the same local `N`. GitHub verifies it server-side: `gh api repos/angellist/treasury/commits/<sha> --jq .commit.verification.verified` → `true`/`valid`. Do NOT re-sign or worry when you see `N`.

**Main checkout is usually dirty** (Kevin keeps ~30 uncommitted WIP files on `main`) and the Graphite stack shows "needs restack" throughout. To operate on a branch without disturbing his WIP, use a **git worktree** off `origin/<branch>` (must `cp` `.env` `.env.local` in, though rspec still won't boot per above). `git worktree remove --force` when done.

Related: this came up doing [[bank-1572]] PR #8126 review-thread fixes.
