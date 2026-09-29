#!/bin/zsh
# Run the prompt regression corpus: does a question someone would actually ask surface
# the file a correct answer has to cite?
#
# test/rank-cases.tsv asks the same of the ranker, seeded from a symbol. This asks it of
# the whole retrieval path -- tokenising, concept matching, tiering, ranking -- seeded
# from English, which is what a hook is handed.
set -uo pipefail
here=${0:A:h}
repo=${here:h}
db=${1:-$repo/index/graph.db}
name=${2:-treasury}
[ -f "$db" ] || { print -u2 "no db: $db — run bin/index.sh first"; exit 1 }

pass=0; fail=0
typeset -A cache
# NOT `path`: zsh ties that to $PATH, and reading a case into it wipes the PATH for
# the rest of the run -- grep, sed and sort all vanish mid-suite.
while IFS=$'\t' read -r prompt kind want_path why; do
  [[ -z "$prompt" || "$prompt" == \#* ]] && continue
  if [ -z "${cache[$prompt]:-}" ]; then
    cache[$prompt]=$(print -r -- "$prompt" | "$repo/bin/match.sh" "$db" "$name" \
      | grep -oE '[A-Za-z0-9_/.-]+\.rb:[0-9]+' | sed 's/:[0-9]*$//' | sort -u)
    [ -z "${cache[$prompt]}" ] && cache[$prompt]="<none>"
  fi
  if print -r -- "${cache[$prompt]}" | grep -qx -- "$want_path"; then hit=1; else hit=0; fi
  if { [ "$kind" = want ] && [ $hit -eq 1 ]; } || { [ "$kind" = deny ] && [ $hit -eq 0 ]; }; then
    pass=$((pass+1))
  else
    fail=$((fail+1))
    print "  FAIL   $kind  $want_path"
    print "         prompt: $prompt"
    print "         $why"
  fi
done < "$here/prompt-cases.tsv"

print "\n$pass passed, $fail failed"
[ $fail -eq 0 ]
