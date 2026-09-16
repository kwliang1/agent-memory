---
name: arti-html-needs-charset-meta
description: "arti serves HTML raw with no charset wrapper — always put <meta charset=\"utf-8\"> in the file or em dashes/middots render as mojibake"
metadata: 
  node_type: memory
  type: reference
  modified: 2026-09-11T17:24:36.759Z
  originSessionId: 041ce951-2dc5-4fa4-9bd3-9229eedf0f06
---

**Any HTML published to arti MUST carry its own `<meta charset="utf-8">` as the first line of the file.** arti serves the bytes raw; with no charset the browser falls back to Latin-1 and every multi-byte char decodes as two:
- `—` U+2014 (`E2 80 94`) → `â€"`
- `·` U+00B7 (`C2 B7`) → `Â·`

Also pass `--content-type "text/html; charset=utf-8"`, but the meta tag is the load-bearing fix (works regardless of response headers).

**Why this bites:** the Claude Artifact renderer *injects* a charset+viewport meta into its `<head>` skeleton, so a page authored for a Claude artifact looks fine there and breaks on arti. Anything written for one surface and pushed to the other needs the meta in the file. Hit this on `op-v2-rerollout` v1 (2026-09-11) — Kevin caught it from a screenshot.

**Verify after publish:** `arti get <slug> -m` → check `type:` shows the charset, and compare `size:` against `wc -c` on the local file (equal = byte-exact upload, no corruption).

Related: [[reference_arti_publish]] (CLI build + login), [[op-v2-rerollout-gate-model]].
