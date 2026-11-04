#!/bin/zsh
# Ranked neighbours of a symbol.
# Usage: rank.sh <db> <symbol>[,<symbol>...] [depth] [k] [repo]
set -uo pipefail
db=${1:?db path}; start=${2:?symbol}; depth=${3:-2}; k=${4:-10}; repo=${5:-}
[ -f "$db" ] || { print -u2 "no such db: $db"; exit 1; }
# depth and k land bare in the SQL and the :param guard cannot see them
[[ "$depth" =~ '^[0-9]+$' ]] || { print -u2 "depth must be an integer: $depth"; exit 1; }
[[ "$k" =~ '^[0-9]+$' ]]     || { print -u2 "k must be an integer: $k"; exit 1; }
# Several entry points rank as ONE traversal. A concept resolves to more than one
# symbol and each gives a different view — from ach_pull, AchPull surfaces model peers
# while AchPulls::StateService surfaces state-machine peers — so ranking from one of
# them silently picks one view. Comma-separated; a single symbol is the degenerate case.
#
# A Ruby constant is [A-Za-z0-9_:] only. Validating up front kills the cases the
# post-hoc guard cannot see: '|' is the sed delimiter and aborts it silently, and '&'
# expands to the matched text, leaving a :param the guard regex steps over.
seeds=(${(s:,:)start})
(( ${#seeds} )) || { print -u2 "no symbol given: $start"; exit 1; }
is_constant() { [[ "$1" =~ '^[A-Za-z_][A-Za-z0-9_]*(::[A-Za-z_][A-Za-z0-9_]*)*$' ]] }
is_repo_name() { [[ "$1" =~ '^[A-Za-z0-9._-]+$' ]] }
# The repo argument reaches SQL as a filter and then the sed substitution in rank.sql,
# where '|' is the delimiter and '&' expands to the match. bin/index.sh validates the
# names it writes with this same pattern; the 5th argument has been through nothing.
if [ -n "$repo" ] && ! is_repo_name "$repo"; then
  print -u2 "rank.sh: unsafe repo name: $repo"; exit 1
fi
for s in $seeds; do
  is_constant "$s" || { print -u2 "not a ruby constant: $s"; exit 1; }
done

# Resolve each seed against the nodes that exist, and take the repo from what it
# resolved to. Defaulting to the repo with the most nodes answered every hydra query out
# of treasury the moment both lived in one db: treasury has 2,113 nodes to hydra's 230,
# so it won every time and returned nothing, successfully.
#
# The suffix pass exists because a TypeScript module is named for its whole path --
# daemon/session-lifecycle.ts is Daemon::SessionLifecycle, since basenames collide
# (daemon/commands/review.ts and protocols/review.ts are both Review). Without it the
# name a person actually types never matches. An exact match wins outright, so a Ruby
# query that already resolved is unaffected; a bare name that used to return nothing and
# exit 0 now either resolves or reports its candidates.
typeset -a resolved reposeen
repofilter=""
[ -n "$repo" ] && repofilter="AND repo = '${repo//\'/''}'"

# Exact matches for every seed in ONE query. bin/match.sh passes ~20 exact node names
# per hook invocation, and a query per seed cost +30% on UserPromptSubmit (393 -> 512ms).
# A name matching in two repos is left for the per-seed pass, which reports it.
inlist=""
for s in $seeds; do inlist+="${inlist:+,}'${s//\'/''}'"; done
typeset -A exactrepo exactcount
while IFS=$'\t' read -r nm rp; do
  [ -n "$nm" ] || continue
  exactcount[$nm]=$(( ${exactcount[$nm]:-0} + 1 ))
  exactrepo[$nm]="$rp"
done < <(sqlite3 -cmd '.timeout 2000' -noheader -separator $'\t' "$db" \
  "SELECT name, repo FROM node WHERE name IN ($inlist) $repofilter ORDER BY repo, name")

for s in $seeds; do
  if (( ${exactcount[$s]:-0} == 1 )); then
    resolved+=("$s"); reposeen+=("${exactrepo[$s]}"); continue
  fi

  esc="${s//\'/''}"
  # substr with a negative start, NOT LIKE: `_` is a LIKE wildcard and the constant
  # regex above allows it, so LIKE '%::'||s matches names it has no business matching.
  rows=("${(@f)$(sqlite3 -cmd '.timeout 2000' -noheader -separator $'\t' "$db" "
    SELECT name, repo FROM node
     WHERE (name = '$esc'
            OR substr(name, -(length('$esc') + 2)) = '::' || '$esc')
       $repofilter
     ORDER BY repo, name")}") || exit 1
  rows=(${rows:#})
  exact=(${(M)rows:#${s}$'\t'*})
  (( ${#exact} )) && rows=($exact)
  # Ambiguity is fatal only when it is the WHOLE question. bin/match.sh hands over a
  # concept's symbols at once, and a qualified name whose node was deleted falls into
  # the suffix pass and matches its namespaced siblings -- deleting AchPulls::StateService
  # made the ach_pull block collapse from 8 neighbours to 2, because one "ambiguous"
  # seed aborted the call. In a multi-seed call, drop it the way a miss is dropped.
  if (( ${#rows} > 1 )); then
    print -u2 "rank.sh: '$s' is ambiguous —"
    for r in ${rows[1,6]}; do print -u2 "    ${r%%$'\t'*}  (${r##*$'\t'})"; done
    (( ${#rows} > 6 )) && print -u2 "    … and $(( ${#rows} - 6 )) more"
    if (( ${#${(@u)seeds}} == 1 )); then
      # Naming it in full only helps when the candidates differ by name. When they
      # differ by REPO the full name is already what was typed.
      ambrepos=()
      for r in $rows; do ambrepos+=("${r##*$'\t'}"); done
      ambrepos=(${(u)ambrepos})
      if (( ${#ambrepos} > 1 )); then
        print -u2 "  pass the repo as the 5th argument"
      else
        print -u2 "  give the full name to disambiguate"
      fi
      exit 1
    fi
    continue
  fi
  # A seed that resolves to nothing is dropped rather than fatal: bin/match.sh hands over
  # a whole concept's symbols at once, and one stale name must not cost the other seeds
  # their answer. Fatal only when NOTHING resolved.
  if (( ${#rows} == 0 )); then
    print -u2 "rank.sh: no node named '$s'${repo:+ in $repo}"
    continue
  fi
  resolved+=("${rows[1]%%$'\t'*}")
  reposeen+=("${rows[1]##*$'\t'}")
done
(( ${#resolved} )) || { print -u2 "rank.sh: no seed resolved to a node in $db"; exit 1 }
if [ -z "$repo" ]; then
  repo=${reposeen[1]}
  for r in $reposeen; do
    [ "$r" = "$repo" ] \
      || { print -u2 "rank.sh: seeds span repos ($repo and $r) — pass one explicitly"; exit 1 }
  done
fi
# Resolved names and the repo come from the db, not from the validated argv. $repo in
# particular reaches the sed substitution below, where '|' is the delimiter and '&'
# expands to the match -- the trap this file's own header describes.
for s in $resolved; do
  is_constant "$s" || { print -u2 "rank.sh: resolved name is not a constant: $s"; exit 1; }
done
is_repo_name "$repo" \
  || { print -u2 "rank.sh: unsafe repo name from db: $repo"; exit 1; }
seeds=($resolved)
# Opt-in, on stderr, so callers that already capture stderr can read the repo this
# resolved to instead of re-deriving it. test/rank-regression.sh mirrored the predicate
# and got both halves wrong: it dropped the exact-match preference and the ordering, and
# it could not handle a comma-separated seed list at all.
[ -n "${RANK_EXPLAIN:-}" ] && print -u2 "rank.sh: resolved-repo $repo"

q=$(sed -e "s|:repo|'${repo//\'/''}'|g" \
        -e "s|:depth|$depth|g" \
        -e "s|:k|$k|g" "${0:A:h}/rank.sql")

[ -n "$q" ] || { print -u2 "rank.sh: query substitution produced nothing"; exit 1; }

# The seed set is a table, not a substituted literal: :start appeared in two positions
# and a list splices cleanly into neither past the sed delimiter traps above.
seed_sql="CREATE TEMP TABLE seed(name TEXT PRIMARY KEY);"
for s in $seeds; do
  seed_sql+="INSERT OR IGNORE INTO seed(name) VALUES ('${s//\'/''}');"
done
q="$seed_sql
$q"

# a literal :param surviving substitution means a silent empty result, so fail loud
if print -r -- "$q" | grep -qE '(^|[^:[:alnum:]]):[a-z_]+\b'; then
  print -u2 "rank.sh: unsubstituted parameter in query — refusing to run"
  exit 1
fi
# RANK_FORMAT=tsv is for callers that parse this; the default stays human-readable.
if [ "${RANK_FORMAT:-}" = tsv ]; then
  print -r -- "$q" | sqlite3 -cmd '.timeout 2000' -noheader -separator $'\t' "$db"
else
  print -r -- "$q" | sqlite3 -cmd '.timeout 2000' -header -column "$db"
fi
