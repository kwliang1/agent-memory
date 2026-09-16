---
name: nova-matchmaking-retro-artifact
description: "LP Wallet Matchmaking as-built-vs-as-specced retro. CANONICAL = the claude.ai artifact (a2818f97…, v19). 22 faults, 16-row drift table, 6 diagrams. Includes the claude.ai mermaid-runtime trap that squeezed wide diagrams, and the scratchpad-survives-on-disk recovery."
metadata:
  node_type: memory
  type: reference
  originSessionId: c3dae879-3845-41bb-ac48-e79416fcf4cc
  modified: 2026-09-14
---

**CANONICAL: https://claude.ai/code/artifact/a2818f97-91c8-4f1c-8dff-44e6508f997c** — v19 as of 2026-09-14. Kevin's call ("claude artifact should be available now, let's stay there") after the Artifact tool came back on a re-login.

**Updated 2026-09-15 at Kevin's request:** https://arti.internal.angellist.com/s/lp-wallet-matchmaking-retro is now **v22**, Markdown with six native fenced Mermaid diagrams, migrated from the saved published Claude v19 source. It is **not stale and must not be archived**. Claude v19 remains the source snapshot; arti v22 includes one verified correction: conflict rows can be re-picked (with a matching-type candidate) or rejected, so the old claim that none have an in-product resolution was too broad.

Arti v22: 56,033 bytes, SHA256 `579651fa47af518349014ac931990aea38beda31c60cb8c9f67d3410862e3509`. Local published master: `artifacts/nova-matchmaking-retro/v22-arti-published.md`; reproducible conversion, browser harness, review correction and readback evidence under `artifacts/nova-matchmaking-retro/markdown-migration/`. All 6 diagram sources, 17 headings, 5 tables (including the 16-row drift table), 111 links and 22 expandable fault bodies were checked. One prose correction is recorded in `review-corrections.json`; all other prose retained. Browser-tested using arti's real Markdown/Mermaid source at `61b7436e5146676884848f24d17d84ca2bf5545b`, including 390px mobile scrolling, natural diagram widths, all fault disclosures, zero browser errors. Published content read back byte-for-byte; access unchanged. No authenticated production-browser render, no fresh fetch of live Claude, no re-audit of historical PR/ticket statuses.

**Markdown width trick:** use a raw outer `<div style="overflow-x:auto;max-width:100%">`, an inner `<div style="min-width:NNNpx">`, then a fenced mermaid block; put blank lines around each HTML tag and the fence. Arti's Markdown renderer recognizes the fence and preserves the inline container styles. Without these wrappers it squeezes wide diagrams into the prose column. `<details><summary>...</summary>` with blank lines before Markdown body preserves collapsible faults.

Contents: **6** rendered-SVG diagrams, a 16-row spec-vs-shipped drift table, **22 collapsible faults** (11 unowned) each with GitHub `file:line` links, two structural seams (the overloaded commit key; the Temporal/FSM split with the in-process port plan in the gap), and an "If you change the criteria" section.

Local masters: `~/.claude/projects/-Users-kevin-RubymineProjects/artifacts/nova-matchmaking-retro/` — `v18.html` (the last Claude-artifact state), `v19-arti.html` (the diagram rework), `as-published.html` (byte-identical to arti v21), `d1/a2/b2/c/d3/d4.svg`, `mm/*.mmd`, `render.mjs`.

## The claude.ai mermaid runtime — it does NOT render into your `<pre>`

**This cost real legibility and was invisible in local rendering.** At publish time claude.ai injects a runtime (`<!--claude-mermaid-runtime-begin:N-->` … `-end-->`, ~3.5 KB, loading `/_runtime/mermaid-11.16.1.min.js`). For each `pre.mermaid` it creates a **sibling** `div.mermaid-diagram`, inserts it *before* the pre, puts the SVG in it, and sets the pre to `display:none`. Its only styling is `.mermaid-diagram svg{display:block;margin:0 auto;max-width:100%;height:auto}`.

Consequences for any artifact styling mermaid:
- CSS on `.mermaid` styles a **hidden** element — frames, padding and background never appear.
- `.mermaid svg{...}` never matches, because the SVG is not inside `.mermaid`.
- The runtime's `max-width:100%` wins, so a diagram wider than the column is **squeezed**, not scrolled. v18's classifier (1430px) and commit sequence (1650px) were being crushed into a 960px column.
- It also uses its **own warm palette** (`#f4efe4` surface, `#42392e` text), ignoring the page's theme variables — so a local render never looks like the published page.

Fix that works: wrap each diagram in `<div class="diagram" style="--nat:NNNpx">`, then style
`.diagram{overflow-x:auto;...}` / `.diagram .mermaid-diagram svg{min-width:var(--nat);max-width:none}`.
The runtime inserts its div **inside** that wrapper (it uses `pre.parentNode.insertBefore`), and the two-class selector out-specifies the runtime's one-class rule regardless of source order.

**To verify without a browser:** copy the injected block verbatim out of a live `action:"read"`, swap `/_runtime/mermaid-*.js` for the jsDelivr build, append it to the page, render headless. That is a faithful replica and it caught this.

## Publishing to an existing artifact

`action:"read"` then publish with `url`. The gate is strict and correct: it refuses until you have **actually Read every line** of the saved source file it hands you — a sha256 comparison does not satisfy it, and re-Reading a file an *earlier refusal* handed you does not either (re-fetch, then publish). The saved file = your authored HTML + the platform skeleton + the injected runtime; diff against your local copy before overwriting so you can prove nothing of anyone else's is being discarded.

## The 2026-09-14 diagram rework

The old single row-state-machine diagram (27 edges, 12 nodes) became three: **scoring** (staged → five resting states, committable ones shaded), **reviewer re-pick** (conflict/auto-match/needs-review + the six pick-and-undo edges), **commit** (→ pending → committed/failed/needsReview-drift/blocked-stale). Reject moved to prose — as edges it drove five crossings for one fact.

**Correction to the earlier framing:** merging `selectCandidate / deselect` on one edge was *not* wrong on substance. Verified against `graph/src/services/fsm/entityMatchmaking.ts:317-419`: `SELECT_CANDIDATE_SOURCES` = {AUTO_MATCH, NEEDS_REVIEW, CONFLICT} × targets {AUTO_MATCH, NEEDS_REVIEW}, and deselect is the transpose — so AUTO_MATCH↔NEEDS_REVIEW genuinely carries **both** actions both ways while the CONFLICT edges carry one each. The old label was accurate; the defect was purely legibility (same visual grammar encoding two different facts). Also: the `[*]` sink added **4** edges, not six.

## Still missing from the doc

Kevin's two original questions, answered in Slack only, never written in: (1) are the open idempotency PRs worth pushing and in what seam, (2) Temporal vs FSM for commit. This is the biggest omission and it is what he originally asked for. Also absent: the stale-SCORING finding ([[nova-matchmaking-upload-status-stale]]) and the 2026-09-13 prod batch assessment ([[lp-porting-fund5-fund6-csv-defects]], operational, arguably right to omit).

## Recovery: the scratchpad files SURVIVE on disk

The old version of this memory said the working copy "went with the scratchpad" and that the fix was to respawn for a fresh Artifact tool. **Both were wrong.**

When the scratchpad *tool* is withdrawn mid-session, the files are untouched at
`/private/tmp/claude-501/<project-slug>/<session-uuid>/scratchpad/`.
That is where v18 was found intact (70,147 B, mtime matching the publish to the minute). Check there first — before assuming any loss, and before asking Kevin to save a page.

**Prophylaxis:** copy a multi-day working document out of `/tmp` immediately. One tmp cleanup is the difference between "recovered" and "gone".

## The Artifact tool is gated, and a respawn does not fix it

`Artifact` / `ArtifactComments` / `ArtifactData` / `ArtifactCheck` vanished fleet-wide on 2026-09-14 ~17:07 UTC. Verified **not** a version removal (the `code/artifact` string count is identical in CLI 2.1.269 and 2.1.270), **not** local settings (`disableArtifact` absent everywhere; managed-settings.json is only `{"channelsEnabled": true}`), **not** the SDK default-off branch (a fresh `claude -p` with `CLAUDE_CODE_ARTIFACT=1` still resolves nothing), and **not** session-scoped — a peer session started after the drop never listed it either.

The gate, from the bundle: `vl()` returns non-null (→ tool off) when the provider isn't `firstParty`, when essential-traffic-only is set, when `CLAUDE_CODE_ARTIFACT` is explicitly falsy, or when the entrypoint is `sdk-ts|sdk-py|sdk-cli|mcp|github-action` without that env var. `QQt()` also short-circuits on a settings-layer disable, and `flagSettings`/`policySettings` are layers — so a remote push can turn it off. **Hypothesis, unverified:** all three config dirs are `billingType: usage_based` / `subscriptionType: null` on Console org `47845747`, and Artifact publishes to claude.ai (a subscription surface), so this may be an account entitlement. One `/login` to a subscription account would settle it. Doesn't fit cleanly: it worked on this same Console config for three days first.

See [[arti-chunked-upload-large-html]], [[nova-matchmaking-owner-gate]], [[nova-directory-email-banking-door]], [[arti-html-needs-charset-meta]].

## Working access from Codex (2026-09-15)

The native Codex catalog still has no arti tool, but the local **Runlayer CLI is already authenticated**. `uvx runlayer status` confirms this without exposing secrets. Connect an MCP stdio client to `uvx runlayer run 0887f01a-1453-4e8a-a954-2d4767066de0 --host https://angellist.runlayer.com`. Working helper: `artifacts/nova-matchmaking-retro/markdown-migration/arti_mcp.py` (run with `uv run --with mcp python ...`). It calls list_tools or a named tool with arguments read from a JSON file, and saves outputs. No token scraping, no new OAuth needed. `add_artifact` supports `allow_type_change:true` (required HTML → Markdown), `expected_latest_version` (protect concurrent edits), and inherited ACLs when omitted. Read metadata + current content before replacing. Programmatic file → tool arguments avoids model-output size limits; v22 was one complete publish, not partial versions. This supersedes the earlier memory's claim that no usable local access existed.
