---
name: zsh-eats-colon-a-in-git-show-base-path
description: "In zsh, `git show \"$B:app/...\"` silently becomes an absolute-path expansion — CLAUDE.md's own review-conduct recipe breaks on any path starting with a modifier letter. Brace it: \"${B}:app/...\""
metadata:
  node_type: memory
  type: feedback
  originSessionId: 6a16a573-0d6f-46b0-926a-158d11ceeb46
  modified: 2026-09-25T21:21:05.594Z
---

CLAUDE.md's review-conduct rule prescribes `B=$(gt parent ...) ; git show "$B:<path>"` to verify a base
before characterising a delta. In zsh that command **breaks whenever `<path>` starts with a history-modifier
letter** — most importantly `a` (as in `app/...`), which is the `:a` "absolute path" modifier.

Observed 2026-09-25 in venture:

```
git show "$B:app/public_api/venture_app/two_factor_config.rb"
fatal: ambiguous argument '/Users/kevin/RubymineProjects/.worktrees/venture-2fa-rca/192f8bc…ae4pp/public_api/venture_app/two_factor_config.rb'
```

zsh applied `:a` to `$B`, turning the bare SHA into `<cwd>/<sha>`, and left the orphaned `pp/...` behind.
`echo "base=[$B]"` printed a perfectly clean SHA, so the variable looks fine and the blame lands on `gt parent`.
I wasted a round chasing a non-existent trailing `\r`.

**Fix: always brace it.** `git show "${B}:app/..."` — works in both shells, no downside.

This compounds the trap already in CLAUDE.md (an empty `$B` turns `git show ":<path>"` into the index-stage
shorthand and succeeds against staged content). Both failure modes are silent-ish and both make you doubt the
wrong thing. Guard the value *and* brace the expansion:

```sh
B=$(gt parent 2>/dev/null) ; [ -n "$B" ] || B=$(git merge-base origin/main HEAD)
git show "${B}:app/whatever.rb"
```

`gt parent` exits 1 on trunk and on any branch Graphite does not track, so the fallback fires often — see
[[review-loop-attribution-discipline]].
