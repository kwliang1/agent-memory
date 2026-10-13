---
name: selectcandidate-repick-test-is-flaky-on-main
description: "graph selectCandidate 're-pick after a bounced commit' fails when run beside sibling matchmaking suites — reproduced on bare main, not caused by your branch"
metadata:
  node_type: memory
  type: reference
---

`graph/src/services/entityMatchmaking/selectCandidate.test.ts` → *"a re-pick after a bounced commit
is not blocked by the prior pick's idempotency key"* returns `FAILED` instead of `COMMITTED` when the
file runs alongside the other matchmaking suites. It passes 25/25 alone on a freshly reset test DB.

**Proven pre-existing (2026-09-24, during #10269):** reverted the branch's six runtime files to main
`791bae97b7` with `git checkout <sha> -- <paths>`, kept only the branch's test files, re-ran — same
failure. So it is main's, not the branch's.

The surfaced error is `Raw query failed. Code: 22012 ... division by zero` from `$executeRaw`, which
is the deliberate failure injection the bounce test uses; it leaks into the second commit.

**How to apply:** don't chase it when it appears in a local multi-file run. Do the same control —
revert your runtime files to main and re-run — before concluding anything is yours. Note the trap in
the reverse direction too: `git checkout <sha> -- <paths>` *stages* those versions, so after copying
your files back, `git restore --staged <paths>` or the index still holds main's.

Related: [[graph-tests-share-one-db-across-4-forks]], [[nova-tests-self-poison-warm-db]].
