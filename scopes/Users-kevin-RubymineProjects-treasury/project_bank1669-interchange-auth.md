---
name: project_bank1669-interchange-auth
description: "BANK-1669 Interchange::Auth shipped as PR #9068 (2026-10-07); design contract BANK-1679 client must build on, and 1679 is paused pending Kevin"
metadata:
  node_type: memory
  type: project
  originSessionId: 9140adc9-2aeb-4774-a4a9-c18d0f12f321
  modified: 2026-10-07T07:02:00.457Z
---

PR #9068 (`kevinliang/bank-1669`, `lib/interchange/auth.rb`) opened 2026-10-07 after 11 review rounds (clean 10+11). Kevin said **pause after 1669** — do not start BANK-1679 until he says so.

Contract 1679 builds on (all verified live on sandbox):
- Token TTL is 3600s on sandbox (docs say 12h); expiry read from JWT `exp`, refresh 5 min early. `whoami` claim `tenantType: program`, `tenantId` = programId `031pQ8iMdPhiS0Iisn8Ie0`.
- No retry inside Auth (deliberate: never hold the mutex across a sleep). Callers own backoff.
- A failed fetch is remembered 30s: serve still-valid token, else re-raise without a request. Never serves a token at/past exp.
- `invalidate!(rejected_authorization_header)` clears only if it matches the current token; bare `invalidate!` clears unconditionally (spec reset).
- 2026-10-07 stress test (Kevin asked) OVERTURNED 3 of my 6 dismissals; I had declined them on false/unchecked claims ("skew breaks TLS first" is false; "~100ms" was unmeasured). Now: any decode failure wraps to Error and backs off; a token issued inside the margin backs off 30s (`@backoff`, renamed from @failure); an already-expired one is refused; whoami actor/claim guarded. URI config errors escape unwrapped on purpose.
- 2026-10-07 Kevin: env config goes in BANK-1692; 1679 UNPAUSED as a local unpushed draft stacked on 1669 to judge ergonomics; possible slim of 1669 to `Interchange::TokenProvider` (JPM AccessTokenProvider precedent) decided after the draft.
- 1679 TODO from review: if minting works but every call 401s, invalidate-and-retry mints per call — rate-limit that in the client.

Worktree gotcha hit here: host has no `lsof`, so the Makefile port scan always picks 7021 (taken); write a free port to `.worktree-port` by hand. The atlas container also dies on boot (`next: command not found`, no node_modules) — run specs host-side per [[treasury-worktree-spec-env-quotes-and-rustfs]] with `RUSTFS_ENDPOINT=http://127.0.0.1:9000` (treasury-rustfs-1 publishes 9000; there is no minio container now). Related: [[mmf-interchange-integration]], [[bank-1678-interchange-sandbox-probe]].

2026-10-07 1679 draft: local commit af76bdfdd on `kevinliang/bank-1679` (stacked on 1669, NOT pushed, no PR, gate not run). `lib/interchange/client.rb` (query!/command!, queries retry 429/5xx/timeouts, commands retry only 429, 401 → invalidate!+retry once with a 30s forced-refresh cooldown) + `lib/interchange/sweeps.rb` (typed cutoff/plans). Smoked green on sandbox. Verified API facts: GET object params (`page`, `query`) are JSON-string query params (dotted keys 400); filter shape `{field:{name:,type:{value:}}}`; protojson omits zero fields (`lastSequence` absent on never-updated entities). Recommended to Kevin: slim Auth to TokenProvider, move cooldown into the provider's invalidate!, move whoami/connection/error into Client.

2026-10-07 Kevin said "yes" to the slim: #9068 re-cut and PUSHED as `Interchange::TokenProvider` (2d5f19570; gate rounds 17-19, clean 18+19 with 2 declined nits logged in review-findings). `invalidate!(rejected)` now backs off 30s if the rejected token was fetched <30s ago (no client-side cooldown state). Shared `Interchange::Error` in lib/interchange/error.rb. whoami/`verify_program_scope!`/PROGRAM_ID moved to 1679 `Interchange::Client` (BANK-1669 ticket text still lists whoami). 1679 rebuilt locally at 2a3eec3a5 (unpushed, no PR, gate not run), 55 specs green, sandbox smoke green.

2026-10-07 later: config PR #9073 (BANK-1809, staging sandbox creds encrypted; prod/poseidon "TODO" pending BANK-1692; readonly ""; no creds in committed .devcontainer/.env). 1679 PR #9076 OPEN, stacked on #9068, after 8 gate rounds (clean 7+8). 1679 also refactors 1669 files: `Interchange::Http` (connection/timeouts/error_for/transport_error), `status` on `Interchange::Error`, `Client.query` (no bang) / `command!`. Declined (logged): URI::Error unwrapped on bad base URL; AmbiguousCommandError deferred to BANK-1818/1819; 0% percentage omission. WebMock `to_timeout` = connect timeout (ConnectionFailed); use `to_raise(Net::ReadTimeout)` for Faraday::TimeoutError.

2026-10-07 restack (Kevin: clean per-PR diffs, sweeps out of #9076): local, UNPUSHED, awaiting Kevin's gate call. 1669 `23bec0d01` (+Http, Error#status), 1679 `e2a9e1d10` (Client only, no id62!), new `kevinliang/bank-1686` `e3c639195` (Sweeps + id62!, gt-tracked on 1679; ticket fit unconfirmed). Top tree == gated `0a2a4ec`. Specs 34/68/83 green.
PUSHED 2026-10-07 after Kevin chose "one gate round per PR": #9068 597668f92 (clean r21), #9076 a4b370c12 (clean r18; added non-numeric Retry-After spec + PROGRAM_ID.present? fail-closed), new #9081 `kevinliang/bank-1686` 52bf444ce (Sweeps + id62!, base bank-1679). Declined + surfaced to Kevin: central absolute/.. path guard in Client#perform! (awaiting his call on follow-up). Bodies updated.

2026-10-07: BANK-1808 (enum + factory arm + NotImplementedError skeleton `Adapters::Interchange`) → PR #9083 off MAIN (Kevin chose main over stacking on #9076; skeleton needs no Client). Gate clean r1+r2; declined trio stubs (BANK-1805 owns) + PROVIDER_FEES (BANK-1810). Merge-order: #9046/#9066/#9069 add Base abstracts → whichever lands second stubs Interchange. Worktree prism test DB: TREASURY_DB_SUFFIX=_prism; RUSTFS creds now come from .devcontainer/.env (minioadmin override breaks it — rustfs-1 publishes 9000).

2026-10-08: Kevin approved review (dcetlin) on #9076 -> BANK-2242 (metrics/logs + MMF section on banking dashboard); reply posted. #9081 ON HOLD (Kevin): enrollment needs no cutoff/plans (no enrollment API; canSweepAccount at create, default plan). Body corrected.

2026-10-10: Kevin found #9083 too barebones → expanded to full account-creation chain (control person profile → org profile → sweep CASH account) via create_provider_account!/poll_application_state! + lib/interchange/registration.rb. Pushed 707502888 at Kevin's "push it" after 9 gate rounds (bypassed; last round's schema reviewer had 2 open items: presence checks on required strings, USState closed list). Sandbox facts: idempotent create with client id62 returns STALE snapshot (find-then-create); profiles deduped per SSN/EIN (409); our sandbox program currently attaches NO profile checks; account checks are clearing-only; account create needs sameDayAch. Open Kevin decisions: compliance on minimal CIP attest/consent/timestamp; re-application needs UpdateProfile; secret_key_base rotation strands HMAC person ids.

2026-10-10 prod read (BANK-1808): 49 MMF apps, 3 non-US signers (#19 CA pending, #31 GB active = CA 393632 Cocoa VC LP, #43 GB active), all US-formed/US-address entities → Interchange US-address rule OK, our citizen-only gate too strict. 19/48 live apps' entities return ZERO ipseity control_persons (all FBO) → adapter's owner_control_persons.first source fails for ~40%; fund-lead via FundLeadResolution (Venture callback) errors from read console — unverified. Proposed to Kevin: relax gate to US address + SSN/ITIN; switch person source to fund lead w/ fallback. Arti interchange-sandbox-map v5 has the new provider questions. Plan doc: claude.ai/artifact/FTK7sG5E4yQovy6VoWhCmP.
