---
name: reference_depthfirst_scanner_vs_reviewer
description: Depthfirst's dependency scanner reads bun.lock (transitive too); its PR reviewer does not — and fix PRs + Slack posting are app settings, not code
metadata:
  type: reference
---

Depthfirst has two separate things that look like one:
- **PR reviewer** (the `depthfirst Bot` check): reviews a PR once, when it goes ready. On 10/28 it missed a vulnerable transitive `ws` that appeared only in `frontend/bun.lock` (treasury#9304) while flagging a `package.json` pin (#9303).
- **Dependency scanner** (app → repo → Dependencies): daily auto-scan of every lockfile, including `bun.lock` transitives, with reachability and target versions. On 10/29 it listed 16 vulnerable treasury packages, 15 transitive.

Don't conclude "depthfirst can't see bun.lock" from the reviewer alone; I did, and had to retract it.

Fix PRs ("repairs") are a per-repo toggle: Settings → Dependencies → "Enable automatic remediation" (org default OFF on 10/29). Posting them to Slack is a Workflow: trigger "Dependencies repair created" → "Send message" (channel ID, `{{ prUrl }}`). usvc and fin have that workflow. Docs (REST API, OpenAPI JSON, Workflows API, MCP server) live behind login at docs.depthfirst.com; Kevin got access 10/28.

Related: [[project_bank2387-bun-audit]]
