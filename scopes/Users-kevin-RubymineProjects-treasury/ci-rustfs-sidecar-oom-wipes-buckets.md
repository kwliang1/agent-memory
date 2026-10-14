---
name: ci-rustfs-sidecar-oom-wipes-buckets
description: CI-only S3 flakes (NoSuchBucket, NoSuchKey after a successful put) come from the RustFS sidecar being OOM-killed at its 1Gi limit and restarting with an empty /data; verified in Datadog 2026-10-13
metadata:
  type: project
---

Root cause of `SensitiveDataService.create! persists the payload and returns a retrievable URL`
failing in CI on 2026-10-13 with `fetch` returning nil, and of the `NoSuchBucket` flake #8980 masked
in `spec/support/rustfs.rb`.

**What the data says.** `kubernetes.memory.working_set{kube_container_name:rustfs}` on the Buildkite
rspec pods (cluster `atlas`, pool `test`) sits at ~940MB from the first sample and climbs to the
1073741824-byte limit within ~2.5 min, then `kubernetes.containers.last_state.terminated{reason:oomkilled}`
fires. OOM kills happened in nearly every 6h window since RustFS replaced MinIO on 2026-09-24
(bursts of 38, 21, 24). The sidecar had no volume, so a restart recreates the container with an empty
`/data`. `RustfsRecreateBucketOnMissing` then recreates the bucket on `NoSuchBucket`, and a get that
follows a pre-restart put answers `NoSuchKey`.

**What it is not.** RustFS is read-after-write consistent: 3000 and 5000 put/get round-trips locally
(1.0.0 and 1.0.1, flat and deep prefixes) had 0 misses. Local RSS stays 140-240MB, so the ~940MB CI
baseline is unexplained; worker-thread count, buffer profile, cache/scanner/heal toggles and 1.0.1 did
not change it locally.

**Fix (PR #9133, branch `kevinliang/ci-rustfs-sidecar-oom`, pushed 2026-10-13 after a 3-round gate, 2 clean).** `.buildkite/pipeline.rb`: RustFS limit 1Gi → 2Gi
and an `emptyDir` named `rustfs-data` mounted at `/data` so a restart keeps buckets (verified locally:
objects survive a container recreate when `/data` is a volume).

**How to apply.** A CI-only S3 flake in treasury is this until proven otherwise: check the pod's
`rustfs` working set and restarts in Datadog before touching the spec. The spec-side retries in
`spec/support/rustfs.rb` cannot recover data that was never persisted.
