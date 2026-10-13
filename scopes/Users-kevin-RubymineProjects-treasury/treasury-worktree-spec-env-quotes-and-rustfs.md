---
name: treasury-worktree-spec-env-quotes-and-rustfs
description: "Host-side treasury spec env: `export \"$l\"` keeps .env's literal quotes and corrupts URLs; RustFS needs MinIO on 127.0.0.1:9000 with minioadmin creds, not unsetting RUSTFS_ENDPOINT"
metadata:
  type: reference
---

Two defects in the host-side worktree spec recipe from [[treasury-worktree-spec-run]] that produced
7 fake failures on 2026-09-28 and had me about to write them off as "environmental, pre-existing".

**1. The env loader kept the quotes.** `while IFS= read -r l; do export "$l"; done` on
`.devcontainer/.env` exports `ENTITY_API_BASE_URI` as the 22-character string
`'http://ipseity:3001'` — single quotes included — so every spec touching the entity API dies with
`URI::InvalidURIError: bad URI (is not URI?)` deep inside `CustomerAccount::OwnerIdentity#owner`.
The stack points at `owner_identity.rb:16`, nowhere near the env, which is why it reads as a broken
service rather than a broken variable. Strip them:

```sh
while IFS='=' read -r k v; do
  case "$k" in ''|\#*) continue;; esac
  v="${v%\'}"; v="${v#\'}"; v="${v%\"}"; v="${v#\"}"
  export "$k=$v"
done < <(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' /Users/kevin/RubymineProjects/treasury/.devcontainer/.env)
```

**2. Do NOT `unset RUSTFS_ENDPOINT`.** The suite now needs an S3 endpoint for
`state_machine_transitions` sensitive-data writes. Unsetting it silently retargets the AWS SDK at
`treasury-sensitive-data.s3.amazonaws.com`, and WebMock then fails whichever spec happens to drive a
state transition — a moving target that looks flaky. `treasury-rustfs-shared` publishes no host
port, but `treasury-minio-1` does and is S3-compatible. Its root creds are **minioadmin/minioadmin**,
not the `admin/admin` that `.devcontainer/.env` sets for rustfs, so the creds must be overridden too:

```sh
export RUSTFS_ENDPOINT=http://127.0.0.1:9000
export AWS_ACCESS_KEY_ID=minioadmin AWS_SECRET_ACCESS_KEY=minioadmin
```

With both fixed, `bundle exec rspec spec/services/ach_pushes` went 7 failures → **42/42 green**, no
code change. **Suspect this recipe before concluding a failure is pre-existing** — the control-run
habit from [[review-loop-attribution-discipline]] would have confirmed "fails on base too" and still
left me with a broken local suite and no real signal.

**Still unsolved:** `MOCK_IPSEITY` cannot be unset from the host, because `ipseity:3001` only
resolves inside the compose network. CLAUDE.md's stricter-than-CI rule therefore needs the
containerised form for any entity-API-touching spec; from a worktree the host run is CI-equivalent
at best, so say so rather than claiming mocks were off. See [[mock-env-vars-differ-by-repo]].

---

**Update 2026-10-01 (BANK-2200).** Two more corrections. Both made a spec pass locally and fail in CI:

- **MinIO is gone.** `treasury-rustfs-1` now publishes 9000 itself, and the `minioadmin` creds fail with `InvalidAccessKeyId`. Keep `.devcontainer/.env`'s `admin/admin`, which matches CI (`.buildkite/pipeline.rb`), and set `RUSTFS_ENDPOINT=http://127.0.0.1:9000`.
- **`.devcontainer/.env` writes the TP vars as `KEY =value`, with a space before the `=`.** The `^[A-Za-z_][A-Za-z0-9_]*=` loader skips those lines, so `TREASURY_PRIME_BASE_URI` is unset. TP API calls then never reach a host WebMock blocks, and a spec that makes a TP book transfer passes locally while CI fails it with `NetConnectNotAllowedError POST https://api.sandbox.treasuryprime.com/book`. Export CI's values explicitly: `TREASURY_PRIME_BASE_URI=https://api.sandbox.treasuryprime.com TREASURY_PRIME_API_KEY=test_api_key TREASURY_PRIME_API_SECRET=test_api_secret TREASURY_PRIME_MANAGEMENT_COMPANY_API_KEY=test_management_api_key TREASURY_PRIME_MANAGEMENT_COMPANY_API_SECRET=test_management_api_secret`.
