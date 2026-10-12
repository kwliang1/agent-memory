---
name: notion-mcp-verification-and-stale-client
description: "Notion MCP: only `fetch` proves page content (search + failed-write probes give false negatives); the desktop client can render deleted blocks while still accepting writes — fix is a NEW page, not a reload"
metadata:
  node_type: memory
  type: reference
  originSessionId: 0400d7ae-e588-46cb-bc02-083c3fabbe34
  modified: 2026-09-25T21:01:47.806Z
---

Three traps, all hit in one session (2026-09-25, entity-matchmaking doc). Cost ~40 min and
several rounds of me telling Kevin his client was stale when he was reporting real symptoms.

**1. Only `notion-fetch` proves what is on a page.** Two cheaper checks both lie:
- `notion-search` reads an eventually-consistent index, so recently-edited content is stale.
- A deliberately-failing `update_content` used as a read ("No matches found" ⇒ absent) is
  **wrong**: the matcher is block/line-scoped, not substring. A token welded onto a paragraph
  tail — `…no reviewer can override.@@MARKER@@` — returns "No matches found" while plainly
  present. That also makes it invisible to the user, who is scanning for it on its own line.

A failing probe additionally writes nothing, so it never bumps `page_last_edited_at` — which
is what a stuck client needs in order to re-pull. Using one as a read actively prevents the
recovery you are hoping for.

**2. The Notion desktop app can render blocks you deleted, while writing fine.** Symptom set:
user sees a section removed 30+ min ago, headings with no content under them, images
interleaved into numbered lists so numbering restarts at 1, markers you already overwrote.
Their hand-edits *do* reach the server (they land in the current structure, in the wrong
places, because they are typing against a stale view). Reload and `Cmd+Q` did not clear it.

**The fix that works: create a NEW page and copy the content.** A page id their machine has
never cached cannot render stale. Do this instead of a third "please reload" — after two
screenshots, believe the user and stop re-asserting the API's answer.

**3. Image blocks cannot be relocated by text edit.** They serialize as expiring signed S3
URLs, so `update_content` can't move them and re-submitting the URL breaks on expiry. To
reorder a page containing images you must `replace_content` the whole page and **re-upload
every image first** (`notion-create-file-upload` → POST the file → use the returned
`file-upload://` id). `MemcachedCrossCellError` on upload is transient — retry, though one
file failed 6×.

Corollary: never try block-relocation tricks on a live doc someone is reading. Replacing a
heading's *text* with a placeholder anchor does not move the content under it — it just puts
`@@MARKER@@` in their face. Work on a duplicate.
