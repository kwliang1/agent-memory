---
name: nova-k8s-steps-have-no-checkout
description: "nova's Buildkite test/lint jobs have NO repo checkout — k8s_step_v2 defaults checkout:false — so .buildkite/hooks/* never run there; only build_step_v3 jobs and 2 Datadog steps check out."
metadata:
  node_type: memory
  type: reference
---

`BuildkiteUtils.k8s_step_v2` defaults `checkout: false` and emits `checkout: { skip: !checkout }`
(`angellist/infra` `packages/buildkite_utils/lib/buildkite_utils.rb:334,375`); agent-stack-k8s then
drops the checkout container entirely. `deploy_step_v4` hardcodes `checkout: { skip: true }` (`:312`).

Consequences when reasoning about nova CI:

- **Repository hooks in `.buildkite/hooks/` do not run on `test-graph`, `lint-types-graph`,
  `test-app`, `lint-prisma`, …** Of nova's 14 `k8s_step_v2` call sites only two pass
  `checkout: true` — the Datadog sync steps. Those jobs have no working copy; their `working_dir`
  is inside the image (`/nova/graph/`, `/configs`).
- **Source reaches those jobs only through the image.** `build_step_v3` runs on classic
  `queue: :runner` agents (which DO check out) and sends `--local context=.`, so the agent's
  working tree is the build context.
- **Images are tagged `<target>-$BUILDKITE_COMMIT-<arch>`** (gem `:61`, `:186`). The tag is the
  head sha, so anything that changes the built tree without changing the tag breaks
  content/tag identity — and `build_step_v3` auto-retries, so a per-job fallback can push two
  different trees under one tag in a single build.
- `BuildkiteUtils.changed_files` is `gh api /repos/<slug>/compare/HEAD~...<COMMIT>` (gem `:50`) — a
  **remote** call that `raise`s on failure. It never reads the local checkout, so a detached or
  shallow HEAD cannot silently empty it.
- `buildkite/nova` is the only *commit status* on a nova commit; check-runs are `Mintlify
  Deployment` / `check_merge_status`. For "was main's build red", `/commits/<sha>/status` is the
  right endpoint — switching to `/check-runs` would react to irrelevant signals.

Agents clone `--depth=2` (`angellist/infra` `pulumi/atlas/src/buildkite.ts:226-228,310-315`), so any
design needing a merge base must deepen — affordable in one job, not in 33.

**Caveat on every line number above:** `.buildkite/Gemfile` pins `buildkite_utils` by git URL with
no `ref:`/`branch:`, and `.buildkite/.gitignore` ignores `Gemfile.lock` (nothing tracked in
`.buildkite/` but the gitignore, rubocop config, Gemfile, hook and pipeline). So CI re-resolves
`angellist/infra` default-branch HEAD on every build. Re-verify against the gem before relying on a
line number — the pipeline's behaviour can change with no nova commit.
