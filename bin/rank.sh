#!/bin/zsh
# Ranked neighbours of a symbol. Usage: rank.sh <db> <symbol> [depth] [k]
set -uo pipefail
db=${1:?db path}; start=${2:?symbol}; depth=${3:-2}; k=${4:-10}
[ -f "$db" ] || { print -u2 "no such db: $db"; exit 1; }
sed -e "s/:start/'${start//\'/\'\'}'/g" -e "s/:depth/$depth/g" -e "s/:k/$k/g" \
    "${0:A:h}/rank.sql" | sqlite3 -header -column "$db"
