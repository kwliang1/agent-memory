#!/bin/zsh
# Run the rank regression corpus. Every case is a real query someone would make.
#
# This exists because the two worst ranker bugs on this branch — an in-degree weight
# against undirected traversal, and GraphQL roots ranking 2nd — survived six review
# rounds and died to a single realistic query. Reviews check the code; these check
# the answers.
set -uo pipefail
here=${0:A:h}
repo=${here:h}
db=${1:-$repo/index/graph.db}
k=${2:-10}
[ -f "$db" ] || { print -u2 "no db: $db — run bin/index.sh first"; exit 1 }

pass=0; fail=0
typeset -A cache
while IFS=$'\t' read -r seed kind symbol why; do
  [[ -z "$seed" || "$seed" == \#* ]] && continue
  if [ -z "${cache[$seed]:-}" ]; then
    cache[$seed]=$("$repo/bin/rank.sh" "$db" "$seed" 2 "$k" 2>/dev/null | awk 'NR>2{print $1}')
    if [ -z "${cache[$seed]}" ]; then cache[$seed]="<none>"; print "  ERROR  $seed -> no results"; fi
  fi
  if print -r -- "${cache[$seed]}" | grep -qx "$symbol"; then hit=1; else hit=0; fi
  if { [ "$kind" = want ] && [ $hit -eq 1 ]; } || { [ "$kind" = deny ] && [ $hit -eq 0 ]; }; then
    pass=$((pass+1))
  else
    fail=$((fail+1))
    print "  FAIL   $seed  $kind  $symbol"
    print "         $why"
  fi
done < "$here/rank-cases.tsv"

print "\n$pass passed, $fail failed (top-$k)"
[ $fail -eq 0 ]
