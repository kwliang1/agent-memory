---
name: nova-ci-flakes-2026-10-14
description: Three unrelated nova CI reds on one PR in an hour — CI gh-user rate limit on Load Pipeline, capital-api Postgres sidecar P1001, EntityMigrationTab app tests timing out at 5s under agent load; all cleared by retry
metadata:
  type: reference
---

On nova#10980 (2026-10-14, 20:45–21:58 UTC) build #53650 went red three times, none from the diff:

1. **Load Pipeline 403**: `gh api … .buildkite/pipeline.rb` hit "API rate limit exceeded for user ID 77301977". Repo-wide (main and 3 other PRs died in ~10s). Only fix is waiting for the hour window; check main's latest build before retrying.
2. **`test-capital-api` P1001** `Can't reach database server at localhost:5432`, 3s, auto-retry also failed; the job-level Retry on a fresh agent passed.
3. **`test-app` timeouts**: 4 tests in `app/src/components/views/AdminTools/EntityMigrationTab/` timed out at 5000ms with 4668 passing; shard collect phase took 650s. Retry passed.

Reading the log without a Buildkite token: `al bk logs` needs `BUILDKITE_API_TOKEN`; use [[ci-failure-via-chrome-skill]] (click the failed step, `get_page_text`, failure block is at the end). `gh api repos/angellist/nova/commits/<sha>/status` carries the buildkite state; "is failing" means still running with a red step, "failed" is terminal.
