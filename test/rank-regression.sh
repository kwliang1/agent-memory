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
# A third argument points at a different corpus, so the suite can assert this script's
# own guards against a case built to trip them.
cases=${3:-$here/rank-cases.tsv}
[ -f "$db" ] || { print -u2 "no db: $db — run bin/index.sh first"; exit 1 }

pass=0; fail=0
typeset -A cache dead target seedrepo
tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT
while IFS=$'\t' read -r seed kind symbol why; do
  [[ -z "$seed" || "$seed" == \#* ]] && continue
  if [ -z "${cache[$seed]:-}" ]; then
    # Keep rank.sh's own stderr and status from the ONE call. Re-running the traversal
    # just to recover an exit code reported "did not resolve" for a seed that was
    # actually ambiguous, which points at re-indexing a repo that is already indexed.
    err=$(RANK_EXPLAIN=1 RANK_FORMAT=tsv "$repo/bin/rank.sh" "$db" "$seed" 2 "$k" 2>&1 >"$tmp/rows.txt")
    rc=$?
    # tsv, not the -column display format bin/match.sh warns against parsing positionally.
    cache[$seed]=$(cut -f1 "$tmp/rows.txt")
    seedrepo[$seed]=$(print -r -- "$err" | sed -n 's/^rank.sh: resolved-repo //p' | tail -1)
    if [ -z "${cache[$seed]}" ]; then
      cache[$seed]="<none>"
      if [ $rc -eq 0 ]; then
        dead[$seed]="resolved, but the graph gives it no neighbours"
      else
        dead[$seed]=$(print -r -- "$err" | sed -n 's/^rank.sh: //p' \
          | grep -v '^resolved-repo ' | head -1)
        [ -n "${dead[$seed]}" ] || dead[$seed]="rank.sh exited $rc"
      fi
      print "  ERROR  $seed -> no results (${dead[$seed]})"
    fi
  fi
  # A seed that resolves to nothing used to score every `deny` on it as a PASS, so
  # reverting the indexer -- or just not indexing the repo at all -- turned two
  # type-only-import assertions green. A dead seed asserts nothing; count it as failed.
  if [ -n "${dead[$seed]:-}" ]; then
    fail=$((fail+1))
    print "  FAIL   $seed  $kind  $symbol"
    reason=${dead[$seed]}
    print "         ${reason%% —*} — the case asserts nothing"
    continue
  fi
  # A `deny` naming a symbol that is no node at all passes without asserting anything --
  # move gateway.ts into a subdirectory and the only type-only-import guard in the corpus
  # silently disarms, because grep -qx matches the exact name.
  # Scoped to the repo the seed resolved into, because the traversal is too
  # (bin/rank.sql:41,45) and the corpus is deliberately two-repo: an unscoped count let a
  # treasury-only node satisfy a hydra deny. The repo comes from rank.sh itself --
  # re-deriving it here got the exact-match preference and the ordering wrong, and could
  # not read a comma-separated seed at all.
  tkey="${seedrepo[$seed]:-?}|$symbol"
  if [ "$kind" = deny ] && [ -z "${target[$tkey]:-}" ]; then
    target[$tkey]=$(sqlite3 -cmd '.timeout 2000' "$db" \
      "SELECT count(*) FROM node WHERE repo = '${seedrepo[$seed]:-}'
          AND name = '${symbol//\'/''}'" 2>/dev/null)
    [ -n "${target[$tkey]}" ] || target[$tkey]=0
  fi
  if [ "$kind" = deny ] && [ "${target[$tkey]}" = 0 ]; then
    fail=$((fail+1))
    print "  FAIL   $seed  deny  $symbol"
    print "         no node by that name — the case asserts nothing"
    continue
  fi
  # -F: the symbol is a literal. As a BRE, a case naming `Ach.*` matched AchPush.
  if print -r -- "${cache[$seed]}" | grep -qxF "$symbol"; then hit=1; else hit=0; fi
  if { [ "$kind" = want ] && [ $hit -eq 1 ]; } || { [ "$kind" = deny ] && [ $hit -eq 0 ]; }; then
    pass=$((pass+1))
  else
    fail=$((fail+1))
    print "  FAIL   $seed  $kind  $symbol"
    print "         $why"
  fi
done < "$cases"

# Zero cases is not a pass. A missing, empty or all-comment corpus scored green, and two
# assertions in test/ts-indexer-test.sh route their own corpus through $3.
(( pass + fail > 0 )) || { print -u2 "no cases ran from $cases"; exit 1 }
print "\n$pass passed, $fail failed (top-$k)"
[ $fail -eq 0 ]
