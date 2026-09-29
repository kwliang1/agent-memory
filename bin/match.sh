#!/bin/zsh
# Text -> the symbols worth injecting. Reads the text on stdin.
# Usage: match.sh <db> <repo> [--seeds]
#
# Matching a prompt token to a concept by NAME EQUALITY returns the wrong concept:
# `wire` names a 2-symbol namespace of undirected degree 1, while outgoing_wire (149),
# incoming_wire (109) and external_wire_account (95) are what the question means. So
# match broadly, rank, cut -- the rule that governs traversal governs matching too.
#
# Concepts are ranked by tier before degree, because degree alone kept answering with
# the biggest thing that happened to match. Each tier was added against a measured
# failure:
#   3  the concept owns a symbol the text named outright, by path or by constant.
#      Reading app/models/ach_pull.rb otherwise answered `dibs` -- dibs has treasury's
#      highest degree (943) and the file mentions it.
#   2  the concept's own NAME matched. Without this, customer_account (degree 346,
#      owns a WireInfoService) outranked every concept actually named for `wire`.
#   1  only a top symbol matched. Enough for a deliberate prompt, too weak for
#      incidental tool output -- see MATCH_MIN_TIER.
#
# Each concept is ranked on its own and the blocks concatenated. One traversal seeded
# from every matched concept at once sums into the repo's hubs: a question about a
# stuck wire came back LedgerEntry, SubAccount.
set -uo pipefail
here=${0:A:h}
db=${1:?db path}; repo=${2:?repo name}; mode=${3:-}
[[ "$repo" =~ '^[A-Za-z0-9._-]+$' ]] || { print -u2 "match.sh: unsafe repo name: $repo"; exit 1; }
[ -f "$db" ] || exit 0

concepts=$here/../seeds/$repo-concepts.tsv
C=${MATCH_CONCEPTS:-3}
N=${MATCH_PER_CONCEPT:-5}
MINLEN=${MATCH_MINLEN:-4}
MINTIER=${MATCH_MIN_TIER:-1}
exclude=${MATCH_EXCLUDE:-}
chosen=${MATCH_CHOSEN:-}
[[ "$C$N$MINLEN$MINTIER" =~ '^[0-9]+$' ]] || { print -u2 "match.sh: C/N/MINLEN/MINTIER must be integers"; exit 1; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/match.XXXXXXXX") || exit 1
cleanup() { rm -rf "$tmp" }
trap cleanup EXIT
trap 'cleanup; trap - INT;  kill -INT  $$' INT
trap 'cleanup; trap - TERM; kill -TERM $$' TERM

q1() { print -r -- "${1//\'/\'\'}" }
sq() { sqlite3 -cmd '.timeout 2000' "$db" "$@" 2>/dev/null }

cat > $tmp/in.txt
tr -cs 'A-Za-z0-9_:' '\n' < $tmp/in.txt > $tmp/raw.txt

# Normalise to lowercase alphanumerics on BOTH sides of the comparison. That is what
# lets one containment test cover PascalCase, snake_case and prose: AchPull, ach_pull
# and "ach pull" all become achpull, and `wire` is inside outgoingwire with no second
# rule for word boundaries.
{
  sed -e 's/\([a-z0-9]\)\([A-Z]\)/\1 \2/g' -e 's/::/ /g' -e 's/_/ /g' $tmp/raw.txt | tr ' ' '\n'
  tr -d '_:' < $tmp/raw.txt
} | tr 'A-Z' 'a-z' | tr -cd 'a-z0-9\n' | awk -v n="$MINLEN" 'length($0) >= n' | sort -u > $tmp/tokens.txt

# What the text named outright. A path is the better signal of the two and the graph
# already records which symbols each file declares, so ask it rather than infer.
# node.path is repo-relative; the tool may have used an absolute path, so match either.
: > $tmp/direct.txt
grep -oE '[A-Za-z0-9_][A-Za-z0-9_/.-]*\.(rb|erb)' $tmp/in.txt | sort -u > $tmp/paths.txt
while IFS= read -r pth; do
  sq "SELECT name FROM node WHERE repo = '$(q1 "$repo")'
        AND (path = '$(q1 "$pth")' OR '$(q1 "$pth")' LIKE '%' || path)
      ORDER BY length(name) LIMIT 5"
done < $tmp/paths.txt >> $tmp/direct.txt

grep -E '^[A-Z][A-Za-z0-9_]*(::[A-Za-z_][A-Za-z0-9_]*)+$' $tmp/raw.txt | sort -u > $tmp/qualified.txt
if [ -s $tmp/qualified.txt ]; then
  names=$(sed "s/'/''/g; s/^/'/; s/\$/'/" $tmp/qualified.txt | paste -sd, -)
  sq "SELECT name FROM node WHERE repo = '$(q1 "$repo")' AND name IN ($names)" >> $tmp/direct.txt
fi
sort -u $tmp/direct.txt | grep -v '^$' | head -n 8 > $tmp/d && mv $tmp/d $tmp/direct.txt

: > $tmp/top-concepts.tsv
if [ -s "$concepts" ] && [ -s $tmp/tokens.txt ]; then
  : > $tmp/exclude.txt
  [ -n "$exclude" ] && [ -f "$exclude" ] && cp "$exclude" $tmp/exclude.txt
  # Discriminate on FILENAME, never NR == FNR. With several inputs and an EMPTY first
  # file NR == FNR is still true while reading the second, so a set loads into the
  # wrong array and the matcher then matches nothing, successfully.
  awk -F'\t' '
    function norm(s) { gsub(/[^A-Za-z0-9]/, "", s); return tolower(s) }
    FILENAME == DIR { direct[$0] = 1; next }
    FILENAME == TOK { tok[$0] = 1; next }
    FNR == 1        { next }
    {
      name = $1; deg = $3 + 0; tops = $5
      tier = 0
      n = split(tops, sym, " ")
      for (i = 1; i <= n; i++) if (sym[i] in direct) { tier = 3; break }
      if (tier < 3) {
        nname = norm(name); ntops = norm(tops)
        for (t in tok) {
          if (index(nname, t) || index(t, nname)) { tier = 2; break }
          if (index(ntops, t)) { tier = 1 }
        }
      }
      if (tier >= MINTIER) printf "%d\t%d\t%s\t%s\n", tier, deg, name, tops
    }
  ' DIR=$tmp/direct.txt TOK=$tmp/tokens.txt MINTIER="$MINTIER" \
    $tmp/direct.txt $tmp/tokens.txt "$concepts" \
    | sort -k1,1nr -k2,2nr -k3,3 | head -n "$C" > $tmp/cut.tsv
  # Drop what this session already has AFTER the cut, not before. Before it, a second
  # prompt on the same subject backfills the quota with whatever ranked fourth --
  # measured, a repeat ach_pull question came back with fdic. If the top concepts are
  # already in context the session has them, and the right answer is nothing.
  awk -F'\t' -v EX="$tmp/exclude.txt" \
    'FILENAME == EX { skip[$0] = 1; next } !($3 in skip)' \
    $tmp/exclude.txt $tmp/cut.tsv > $tmp/top-concepts.tsv
  [ -n "$chosen" ] && cut -f3 $tmp/top-concepts.tsv >> "$chosen"
fi

if [ "$mode" = "--seeds" ]; then
  { cut -f4 $tmp/top-concepts.tsv | tr ' ' '\n'; cat $tmp/direct.txt } | grep -v '^$' | sort -u
  exit 0
fi

: > $tmp/emitted.txt
# The ranker excludes its own seeds -- they are the query, not the answer -- so a
# concept's own files never appeared in its block. Asking about ach_pull returned its
# neighbours and not app/models/ach_pull.rb, which is the one file the question is
# actually about. The seeds are looked up and printed first.
rows_for() {
  local names=$1 quoted
  quoted=$(print -r -- "$names" | tr ' ,' '\n\n' | grep -v '^$' | sort -u \
    | sed "s/'/''/g; s/^/'/; s/\$/'/" | paste -sd, -)
  [ -n "$quoted" ] || return 0
  sq "SELECT name || char(9) || path || ':' || line FROM node
      WHERE repo = '$(q1 "$repo")' AND name IN ($quoted) AND path IS NOT NULL
      ORDER BY length(name)"
}

emit() {
  local label=$1 seeds=$2
  local joined=$(print -r -- "$seeds" | tr ' ' '\n' | grep -v '^$' | sort -u | paste -sd, -)
  [ -n "$joined" ] || return 0
  {
    rows_for "$seeds"
    "$here/rank.sh" "$db" "$joined" 2 "$N" "$repo" 2>/dev/null \
      | awk 'NR>2 && NF { printf "%s\t%s:%s\n", $1, $(NF-1), $NF }'
  } > $tmp/rows.tsv
  # A symbol already shown earns nothing by being shown again, and the blocks overlap
  # hard: a concept and the symbol that named it share most of their neighbours. On a
  # read of ach_pull.rb the first two blocks were five rows each and four were the same.
  awk -F'\t' -v E="$tmp/emitted.txt" \
    'FILENAME == E { seen[$0] = 1; next } !($1 in seen) && !dup[$1]++' \
    $tmp/emitted.txt $tmp/rows.tsv > $tmp/new.tsv
  [ -s $tmp/new.tsv ] || return 0
  cut -f1 $tmp/new.tsv >> $tmp/emitted.txt
  print -r -- "$label"
  awk -F'\t' '{ printf "  %s  %s\n", $1, $2 }' $tmp/new.tsv
}

out=$(
  # The thing the text actually named goes first; a concept match is an inference about
  # it. Its own symbols are printed in the label, so they are not lost to the ranker
  # excluding its seeds.
  [ -s $tmp/direct.txt ] \
    && emit "named here: $(paste -sd, - < $tmp/direct.txt | sed 's/,/, /g')" "$(tr '\n' ' ' < $tmp/direct.txt)"
  while IFS=$'\t' read -r tier deg name tops; do
    emit "$name" "$tops"
  done < $tmp/top-concepts.tsv
)
[ -n "$out" ] || exit 0
print -r -- "Related code in $repo (ranked, 2 hops):"
print -r -- "$out"
