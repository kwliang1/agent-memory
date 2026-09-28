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
for s in $seeds; do
  [[ "$s" =~ '^[A-Za-z_][A-Za-z0-9_]*(::[A-Za-z_][A-Za-z0-9_]*)*$' ]] \
    || { print -u2 "not a ruby constant: $s"; exit 1; }
done

# default to the repo with the most nodes, so a single-repo db needs no argument
if [ -z "$repo" ]; then
  repo=$(sqlite3 "$db" "SELECT repo FROM node GROUP BY repo ORDER BY count(*) DESC LIMIT 1") || exit 1
fi
[ -n "$repo" ] || { print -u2 "no repo in $db — run bin/index.sh first"; exit 1; }

q=$(sed -e "s|:repo|'${repo//\'/\'\'}'|g" \
        -e "s|:depth|$depth|g" \
        -e "s|:k|$k|g" "${0:A:h}/rank.sql")

[ -n "$q" ] || { print -u2 "rank.sh: query substitution produced nothing"; exit 1; }

# The seed set is a table, not a substituted literal: :start appeared in two positions
# and a list splices cleanly into neither past the sed delimiter traps above.
seed_sql="CREATE TEMP TABLE seed(name TEXT PRIMARY KEY);"
for s in $seeds; do
  seed_sql+="INSERT OR IGNORE INTO seed(name) VALUES ('${s//\'/\'\'}');"
done
q="$seed_sql
$q"

# a literal :param surviving substitution means a silent empty result, so fail loud
if print -r -- "$q" | grep -qE '(^|[^:[:alnum:]]):[a-z_]+\b'; then
  print -u2 "rank.sh: unsubstituted parameter in query — refusing to run"
  exit 1
fi
print -r -- "$q" | sqlite3 -header -column "$db"
