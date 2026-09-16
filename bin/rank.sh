#!/bin/zsh
# Ranked neighbours of a symbol.
# Usage: rank.sh <db> <symbol> [depth] [k] [repo]
set -uo pipefail
db=${1:?db path}; start=${2:?symbol}; depth=${3:-2}; k=${4:-10}; repo=${5:-}
[ -f "$db" ] || { print -u2 "no such db: $db"; exit 1; }

# default to the repo with the most nodes, so a single-repo db needs no argument
if [ -z "$repo" ]; then
  repo=$(sqlite3 "$db" "SELECT repo FROM node GROUP BY repo ORDER BY count(*) DESC LIMIT 1") || exit 1
fi
[ -n "$repo" ] || { print -u2 "no repo in $db — run bin/index.sh first"; exit 1; }

q=$(sed -e "s|:start|'${start//\'/\'\'}'|g" \
        -e "s|:repo|'${repo//\'/\'\'}'|g" \
        -e "s|:depth|$depth|g" \
        -e "s|:k|$k|g" "${0:A:h}/rank.sql")

# a literal :param surviving substitution means a silent empty result, so fail loud
if print -r -- "$q" | grep -qE '(^|[^:[:alnum:]]):[a-z_]+\b'; then
  print -u2 "rank.sh: unsubstituted parameter in query — refusing to run"
  exit 1
fi
print -r -- "$q" | sqlite3 -header -column "$db"
