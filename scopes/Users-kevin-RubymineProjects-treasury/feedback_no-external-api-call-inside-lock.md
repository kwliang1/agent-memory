---
name: feedback_no-external-api-call-inside-lock
description: Never hold a MySQL advisory lock (or any DB lock/transaction) across an external API call — Kevin called it "very bad"
metadata:
  type: feedback
---
Never wrap an external HTTP call (Treasury Prime, Ipseity, any bank API) inside `MysqlAdvisoryLock.with_lock`, a DB transaction, or a row lock.

**Why:** On PR #9324 (BANK-2459, 2026-10-29) I put `TreasuryPrime::ApiService.post('deposit_sweep')` inside a 30s per-sub-account advisory lock to stop double enrollment. A reviewer (sf8193) flagged "api call inside of a lock seems like a bad idea" and Kevin said "this is very bad". `GET_LOCK` is session-scoped (`lib/mysql_advisory_lock.rb`): it pins a DB connection for the full network round trip, makes every other caller block on the remote API's latency, and if the connection drops mid-call the lock silently releases while the POST may still land — so it doesn't even guarantee the dedupe it was added for. Four review-gate rounds passed it; no lens asked the question.

**How to apply:** Locks guard only local reads/writes and must be short. For dedupe around a remote side effect, use: a claim row with a unique index written before the call (lock only for the claim, released before the call), an idempotency key the remote honors, or a single owner (one workflow id). In review briefs for any change that adds a lock, ask reviewers explicitly: "what runs inside the lock, and can any of it block on the network?" Related: [[gate-checklist]], [[mmf-concurrent-sells-fee-leg-insufficient-funds]].
