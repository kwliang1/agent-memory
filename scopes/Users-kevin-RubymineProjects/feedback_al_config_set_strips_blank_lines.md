---
name: feedback-al-config-set-strips-blank-lines
description: "`al config set --secret` silently removes adjacent blank lines in YAML configtool files; restore them before committing"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: b010282a-6e5c-4137-9094-c83f5c251f86
---

After running `al config set --secret --config <file> KEY VALUE` against a YAML-format configtool config, `git diff` the file before staging. The tool re-serializes the file and may delete blank lines adjacent to the touched key (e.g. the blank line above the `# TODO: update for staging` comment block in USVC's staging configtool). Restore any such removed blank lines manually so the diff is a true one-line ciphertext swap.

**Why:** Caught in USVC-996 staging secret rotation. The first push had an incidental blank-line deletion at config.yaml:15. Kevin flagged it as unwanted churn — "why was a line break removed on line 15? don't do that."

**How to apply:** Any time you use `al config set` (with or without `--secret`) on a YAML configtool file in any AngelList repo:
1. Run `git diff <file>` immediately after.
2. If you see blank-line removals beyond the intended key, use Edit to restore them.
3. Only then stage and commit.

Prefer `al config set` over hand-editing the ciphertext — it's still the canonical encrypt path — but treat the formatting as untrusted output.
