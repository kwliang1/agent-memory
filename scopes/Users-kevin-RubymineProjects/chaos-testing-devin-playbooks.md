---
name: chaos-testing-devin-playbooks
description: "AngelList \"chaos testing\" = two Devin playbooks (visual chaos on a venture FE PR via macro !visual_chaos_test; daily staging chaos). Frontend-only gate. Backed up in angellist/skillz."
metadata:
  type: reference
---

"Chaos testing" at AngelList is **not** a CI step, Buildkite pipeline, or GitHub workflow — it's two **Devin playbooks**. Nothing named "chaos" exists in venture/nova/treasury/ipseity/infra source or `.buildkite/`.

Backups live in [`angellist/skillz`](https://github.com/angellist/skillz/tree/main/archive/devin/playbooks). **`archive/` is a versioned backup of live platform config (Devin + Runlayer), NOT deprecated code** — see `archive/README.md`. Both playbooks are `status: published`.

**1. Visual Chaos Test on a Venture Frontend PR**
- `playbook-92a14bc7829a4e9bbda74e864f851cbc`, macro **`!visual_chaos_test`**, author Thibaut Labarre
- Driven by Devin automation `auto-b05d1db0325641c183b4080bf1d83b9e`
- Needs: PR number + head SHA + base branch
- Flow: boot deps + app → seed → screenshot BEFORE (base) → screenshot AFTER (head, same seed) → mutate seed for nulls / long strings / empty lists / extreme numbers → post ONE PR comment
- Comment format is mandated: first line `## <badge> Visual Chaos Test — <label>` (🟢 no issues / 🟡 nits only / 🟠 should fix before merge / 🔴 blocking / 🟠 could not complete), second line the head SHA + Devin session link. Idempotent per commit.
- **GATE: it stops unless `git diff --name-only <base>...<head>` has files under `frontend/`.** A backend-only PR is out of scope and the automation silently skips it.
- Login in its env: `venture@angellist.com` / `<dev password redacted>`, 2FA bypassed via `MOCK_TWO_FACTOR=true`.
- Playbook text says base is "usually `master`" — stale, venture uses `main`.

**2. Daily Staging Chaos Test (LP / GP / Admin)**
- `playbook-a285f42758ea4d37a6f3b62b204f5ba2`, no macro (scheduled daily)
- Targets `https://venture.angellist-staging.com`, reports to Slack channel `C0ARAPKC5C1`
- Covers all three personas each run + one feature not covered by a previous run
- Reads venture's own `.agents/skills/testing-venture-staging/SKILL.md` (login/SSO, URL rules, flaky surfaces, staging-config-vs-product-bug attribution). Venture also has `.agents/skills/cptr-local-testing` and `fc-admin-local-testing`.

**How to fire it:** the macro in a Devin session, or — since Devin monitors PR comments — a comment on the PR asking for the visual chaos test on a given head SHA. Cannot be invoked from a Claude Code session directly.

Came up on [[sec-829-2fa-stepup-wizard-gap]] (backend-only PR → out of scope until the frontend fix lands).
