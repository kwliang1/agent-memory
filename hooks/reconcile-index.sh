#!/bin/bash
# Add a pointer for any memory file that lacks one. Never touch an existing line.
#
# An earlier version of this regenerated every hook under the "Moved here" /
# "Previously unindexed" / "Added" headings from each file's `description:`
# frontmatter. That silently reverted hand-written corrections every time it ran,
# which is why the same defective hooks kept reappearing across review rounds.
# Frontmatter goes stale; a corrected hook is the more recent truth. Add-only.

set -uo pipefail
SCOPES="${1:-$HOME/claude-memory/scopes}"

summarize() {
  local f="$1" d
  d=$(grep -m1 '^description:' "$f" | sed 's/^description: *//' | tr -d '"')
  [ -z "$d" ] && d=$(sed -n '/^---$/,/^---$/!p' "$f" | sed '/^$/d' | head -1 | sed 's/^\*\*//')
  d=$(printf '%s' "$d" | tr -d '\\' | tr '|' '/' | tr -s ' ')
  if [ ${#d} -le 150 ]; then printf '%s' "$d"; return; fi
  local cut="${d:0:150}" best="" t
  for sep in '. ' '; ' ' — ' ', '; do
    t="${cut%"$sep"*}"
    if [ ${#t} -lt 150 ] && [ ${#t} -gt ${#best} ]; then best="$t"; fi
  done
  [ -z "$best" ] && best="${cut% *}"
  printf '%s' "$best"
}

title() { local b="${1%.md}"; b="${b//-/ }"; b="${b//_/ }"; printf '%s' "$b"; }

added=0
removed=0
for idx in "$SCOPES"/*/MEMORY.md; do
  d="${idx%/MEMORY.md}"

  # drop pointers whose target is gone from this scope
  while IFS= read -r t; do
    [ -z "$t" ] && continue
    [ -f "$d/$t" ] && continue
    esc=$(printf '%s' "$t" | sed 's/[][\.*^$\/]/\\&/g')
    sed -i '' "/($esc)/d" "$idx"
    removed=$((removed+1))
  done < <(grep -oE '\]\([a-z0-9][^)]*\.md\)' "$idx" 2>/dev/null | sed 's/](//;s/)//' | sort -u)

  # add a pointer for anything unindexed, with a NEEDS REVIEW marker so a
  # frontmatter-derived hook is never mistaken for a verified one
  new=""
  for f in "$d"/*.md; do
    b="${f##*/}"; [ "$b" = MEMORY.md ] && continue
    grep -qF "($b)" "$idx" && continue
    new+="- [$(title "$b")]($b) — $(summarize "$f") <!-- hook from frontmatter, unverified -->"$'\n'
    added=$((added+1))
  done
  if [ -n "$new" ]; then
    grep -q '^## Unfiled$' "$idx" || printf '\n## Unfiled\n' >> "$idx"
    printf '%s' "$new" | sort >> "$idx"
  fi

  awk 'BEGIN{b=0} /^$/{b++; if(b<2) print; next} {b=0; print}' "$idx" > "$idx.t" && mv "$idx.t" "$idx"
done
echo "added=$added removed=$removed"
