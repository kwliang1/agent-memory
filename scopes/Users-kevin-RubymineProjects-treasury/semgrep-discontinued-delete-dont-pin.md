---
name: semgrep-discontinued-delete-dont-pin
description: Semgrep was discontinued org-wide 2026-09-03; delete leftover semgrep workflows instead of pinning/reviving them, and check a dead workflow's history before "fixing" it
metadata:
  type: project
---

Semgrep was discontinued org-wide: Utkarsh in #ask-security on 2026-09-03 said "we have discontinued Semgrep in favor of other AI tools" ([thread](https://grid-angellist.enterprise.slack.com/archives/C06E36GJSRX/p1788452671394409?thread_ts=1788452448.963689&cid=C06E36GJSRX)). Treasury's SAST workflow went in #8456. The SCA cron was left behind and never ran: it targeted the retired `ubuntu-20.04` runner, so all 419 runs were cancelled after 24h queued.

On BANK-2385 I first SHA-pinned it and moved it to `ubuntu-latest`, which would have revived it. Kevin then chose to delete it (#9276, merged 2026-10-28). The org `SEMGREP_APP_TOKEN` still authenticated on 2026-10-27, so revoking it is an open org-admin follow-up.

**Why:** pinning a workflow nobody wants spends review effort and turns a vendor integration we cancelled back on.

**How to apply:** before pinning or repairing a CI workflow, check `gh run list --workflow <f>` for when it last succeeded, and search Slack for whether the tool is still in use. When a workflow is dead and the tool is retired, propose deleting it. ipseity#1702 pinned semgrep and may need the same correction.
