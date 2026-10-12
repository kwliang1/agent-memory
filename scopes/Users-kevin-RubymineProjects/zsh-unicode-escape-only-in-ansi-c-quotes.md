---
name: zsh-unicode-escape-only-in-ansi-c-quotes
description: "In a zsh script \"é\" is a literal backslash, not é — so a non-ASCII test fixture silently becomes a backslash filename, which git quotes unconditionally"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 85319a80-b18c-4af4-861c-0876f903e673
  modified: 2026-09-29T23:14:15.455Z
---

Inside a **zsh script file**, double quotes do not expand `\u`:

```zsh
: > "café.ts"     # creates  café.ts   -- a literal backslash
: > $'café.ts'    # creates  café.ts
```

Do not check this with `zsh -c '...'` from another shell — the outer shell eats a quoting layer
and `"café.ts"` *does* produce `café.ts` there. It disagrees with what the same line does in a
script, which is how the bug survives a spot check. Test it by writing an actual `.zsh` file.

**Why it matters beyond the typo.** A backslash in a filename is a character git quotes in
`ls-files` output **regardless of `core.quotePath`**. So a fixture written to prove "a repo config
setting `core.quotePath=false` must not widen the file listing" passes *identically* with the pin
present and with it removed — the file is skipped either way, for the wrong reason. On 2026-09-29
that made an `agent-memory` guard untestable and a one-line mutation read as caught when nothing
covered it.

**How to apply:** in a fixture, write the non-ASCII character **literally** (`café.ts`,
`日本語.ts`) the way the surrounding fixtures already do, or use `$'…'`. Then mutation-test it:
delete the guard and confirm *that* assertion turns red. And when a test claims to exercise an
unusual filename, `ls -b` the fixture directory once and look at what was actually created.

Related: [[feedback_verify_new_assertions_can_fail]], [[verify_fixture_assumptions]].
