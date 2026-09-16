---
name: al-console-access
description: "al CLI prod console access levels — read works, write needs GlobalConsoleWriters (Kevin runs write ops himself), legacy deprecated"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 0f9e1e6b-1a6e-46ed-8326-d393706dd013
---

`al console` (prod, `-a treasury -p`): read-only consoles work under kevin.liang's SSO. **Write consoles (`-w`) fail with `no access to role "GlobalConsoleWriters"`** (seen 2026-07-08) — hand Kevin the code to run himself. Legacy consoles (`-l`) are deprecated for treasury. Read consoles can't reach the Treasury Prime API (`not an HTTP URI`; base-URL env absent). Scripted recipe: `create --no-attach` → `push` script → `exec -- bin/rails runner` → `pull` output → `delete`. First use each session triggers AWS SSO device auth in the browser.

**Note (2026-07-08):** repo-local memory `.claude/memory/kwliang1/` vanished from the working tree (was on branch `kevinliang/local-memory-by-handle`, PR #7852) — richer al-console notes lived there; reconstruct from this if it doesn't come back.
