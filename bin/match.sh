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
#   2  a multi-word concept's whole NAME matched. Without this, customer_account
#      (degree 346, owns a WireInfoService) outranked every concept named for `wire`.
#   1  a single bare word, or two words of the name or its top symbols. Enough for a
#      deliberate prompt, too weak for incidental tool output -- see MATCH_MIN_TIER.
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
STOP="user users policy file files application internal demo mock main check data input base handler string util info state account provider tool role address angellist cursor sandbox loan document documents network session sessions thread message messages channel source plugin discord slack chat reply $repo"
WEAK="service services create record records instance enum type types controller model details apply update find concern error errors activity activities workflow job jobs request requests pull push bank"
[[ "$C$N$MINLEN$MINTIER" =~ '^[0-9]+$' ]] || { print -u2 "match.sh: C/N/MINLEN/MINTIER must be integers"; exit 1; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/match.XXXXXXXX") || exit 1
cleanup() { rm -rf "$tmp" }
trap cleanup EXIT
trap 'cleanup; trap - INT;  kill -INT  $$' INT
trap 'cleanup; trap - TERM; kill -TERM $$' TERM

q1() { print -r -- "${1//\'/\'\'}" }
sq() { sqlite3 -cmd '.timeout 2000' "$db" "$@" 2>/dev/null }

cat > $tmp/in.txt
# A path contributes its BASENAME to the token set and nothing else. The directory
# components are not what the text is about, and they match concepts hard: Read sends
# file_path absolute, so /Users/... put `users` in the set, which matched the concept
# `user` and injected User, Users::OauthService and Role into a question about an ACH
# pull. The path itself is looked up whole, below -- this only governs tokenising.
#
# URLs and ticket ids go entirely: every PR URL carries /pull/ and every Linear id and
# branch carries bank-, which named ach_pull and partner_bank on every fetch.
perl -pe 's{https?://\S+}{ }g; s{\b[A-Za-z]{2,10}-[0-9]+\b}{ }g; s{[A-Za-z0-9_./-]*/([A-Za-z0-9_.-]+[.](?:rb|erb))}{$1}g' $tmp/in.txt > $tmp/tok-src.txt 2>/dev/null \
  || cp $tmp/in.txt $tmp/tok-src.txt
tr -cs 'A-Za-z0-9_:' '\n' < $tmp/tok-src.txt > $tmp/raw.txt

# Normalise to lowercase alphanumerics on BOTH sides of the comparison. That is what
# lets one comparison cover PascalCase, snake_case and prose: AchPull, ach_pull
# and "ach pull" all become achpull (the last through the joined pairs below).
{
  sed -e 's/\([a-z0-9]\)\([A-Z]\)/\1 \2/g' -e 's/::/ /g' -e 's/_/ /g' $tmp/raw.txt | tr ' ' '\n'
  tr -d '_:' < $tmp/raw.txt
} | tr 'A-Z' 'a-z' | tr -cd 'a-z0-9\n' | awk -v n="$MINLEN" 'length($0) >= n' > $tmp/tokens.txt
# Adjacent words joined, so "sub account" names sub_account and "ach pull" names ach_pull
# although "sub" and "ach" are under the length floor alone. Plurals fold to singular.
# CamelCase splits first, so a pasted IncomingWires::AutoAssignService names incoming_wire.
# Never across a sentence or a JSON string: "the account. Merge" named account_merge.
perl -pe 's/([a-z0-9])([A-Z])/$1 $2/g; s/::/ /g; s/[|.;!?"{}\[\]\n]/ | /g' $tmp/tok-src.txt | tr -cs 'A-Za-z0-9|' '\n' | tr 'A-Z' 'a-z' \
  | awk 'function flush(   i) { for (i = 1; i < n; i++) { print w[i] w[i+1]; if (i + 1 < n) print w[i] w[i+1] w[i+2] } n = 0 }
         /^\|+$/ { flush(); next } NF { w[++n] = $0 } END { flush() }' \
  >> $tmp/tokens.txt
awk -v n="$MINLEN" 'length($0) >= n { print; if (sub(/ies$/, "y")) print; else if (sub(/s$/, "")) print }' $tmp/tokens.txt \
  | sort -u > $tmp/t && mv $tmp/t $tmp/tokens.txt

# What the text named outright. A path is the better signal of the two and the graph
# already records which symbols each file declares, so ask it rather than infer.
# node.path is repo-relative; the tool may have used an absolute path, so match either.
: > $tmp/direct.txt
# Capped, and ONE query. A grep result carries as many paths as it found -- 66 of them
# measured at 1.5s, a sqlite3 process each -- and the direct set is capped at 8
# regardless, so reading more than that buys nothing.
grep -oE '[A-Za-z0-9_][A-Za-z0-9_/.-]*\.(rb|erb)' $tmp/in.txt | sort -u | head -n 8 > $tmp/paths.txt
if [ -s $tmp/paths.txt ]; then
  where=""
  while IFS= read -r pth; do
    where+=" OR path = '$(q1 "$pth")' OR substr('$(q1 "$pth")', -(length(path) + 1)) = '/' || path"
  done < $tmp/paths.txt
  sq "SELECT name FROM node WHERE repo = '$(q1 "$repo")' AND (1 = 0$where)
      ORDER BY length(name) LIMIT 8" >> $tmp/direct.txt
fi

grep -E '^[A-Z][A-Za-z0-9_]*(::[A-Za-z_][A-Za-z0-9_]*)+$' $tmp/raw.txt | sort -u > $tmp/qualified.txt
if [ -s $tmp/qualified.txt ]; then
  names=$(sed "s/'/''/g; s/^/'/; s/\$/'/" $tmp/qualified.txt | paste -sd, -)
  sq "SELECT name FROM node WHERE repo = '$(q1 "$repo")' AND name IN ($names)" >> $tmp/direct.txt
fi
sort -u $tmp/direct.txt | grep -v '^$' | head -n 8 > $tmp/d && mv $tmp/d $tmp/direct.txt
: > $tmp/exclude.txt
[ -n "$exclude" ] && [ -f "$exclude" ] && cp "$exclude" $tmp/exclude.txt
awk -v EX="$tmp/exclude.txt" 'FILENAME == EX { skip[$0] = 1; next } !($0 in skip)' \
  $tmp/exclude.txt $tmp/direct.txt > $tmp/d && mv $tmp/d $tmp/direct.txt

: > $tmp/top-concepts.tsv
if [ -s "$concepts" ] && [ -s $tmp/tokens.txt ]; then
  # Discriminate on FILENAME, never NR == FNR. With several inputs and an EMPTY first
  # file NR == FNR is still true while reading the second, so a set loads into the
  # wrong array and the matcher then matches nothing, successfully.
  # Match whole names, never a substring of a word: containment let "main" answer
  # maintenance_tasks_ui and "fundamentally" answer fund.
  # A bare word -- a one-word concept's name, or a multi-word one's last word -- goes to
  # the ONE concept it names with the highest degree: `transfer` is transfer (221), not
  # cross_transfer (59); `wire` is outgoing_wire (149), not the 2-symbol wire namespace.
  # A bare word inside a whole-name match is already answered by it. Tier 1 otherwise
  # needs two distinct words: one coincidental word ("push it") was most of the noise.
  # STOP holds words that are concept-name words AND ordinary English or envelope text.
  perl -F'\t' -lane 'if ($. == 1) { print; next } my $w = $F[4]; $w =~ s/::/ /g; $w =~ s/([a-z0-9])([A-Z])/$1 $2/g; print join("\t", @F[0..4], $F[5] // "", lc $w)' \
    "$concepts" > $tmp/concepts.tsv
  awk -F'\t' -v STOP="$STOP" -v WEAK="$WEAK" '
    function norm(s) { gsub(/[^A-Za-z0-9]/, "", s); return tolower(s) }
    function sing(s) { if (sub(/ies$/, "y", s)) return s; sub(/s$/, "", s); return s }
    function bare(t, c) {
      if (!(t in tok) || (t in stop)) return
      if (!(t in best) || deg[c] > deg[best[t]] || (deg[c] == deg[best[t]] && c < best[t])) best[t] = c
    }
    BEGIN {
      n = split(STOP, s, " "); for (i = 1; i <= n; i++) stop[s[i]] = 1
      n = split(WEAK, s, " "); for (i = 1; i <= n; i++) weak[s[i]] = 1
    }
    FILENAME == DIR { direct[$0] = 1; next }
    FILENAME == TOK { tok[$0] = 1; next }
    FNR == 1        { next }
    {
      name = $1; order[++nc] = name; deg[name] = $3 + 0; tops[name] = $5
      tier = 0
      n = split($5, sym, " ")
      for (i = 1; i <= n; i++) if (sym[i] in direct) { tier = 3; break }
      m = split(name, w, "_")
      if (tier < 3 && m > 1 && (norm(name) in tok)) tier = 2
      if (tier >= 2) for (i = 1; i <= m; i++) covered[sing(tolower(w[i]))] = 1
      if (tier < 2) {
        delete own; for (i = 1; i <= m; i++) own[sing(tolower(w[i]))] = 1
        delete words; for (i in own) words[i] = 1
        k = split($7, x, " "); for (i = 1; i <= k; i++) words[sing(x[i])] = 1
        delete hit
        for (t in tok) {
          st = sing(t)
          if ((st in words) && !(t in stop) && !(t in weak) && !(st in stop) && !(st in weak) && !(st in hit)) { hit[st] = 1; hitw[name] = hitw[name] " " ((st in own) ? "+" : "") st }
        }
        if (!(tolower(w[m]) in weak)) bare(tolower(w[m]), name)
      }
      tiers[name] = tier
    }
    END {
      for (t in best) if (!(sing(t) in covered)) claimed[sing(t)] = best[t]
      for (c in hitw) {
        k = split(hitw[c], x, " "); hits = 0
        for (i = 1; i <= k; i++) { o = sub(/^\+/, "", x[i]); if (!(x[i] in covered) && (o || !(x[i] in claimed))) hits++ }
        if (hits >= 2 && tiers[c] < 1) tiers[c] = 1
      }
      for (t in claimed) if (tiers[claimed[t]] < 1) tiers[claimed[t]] = 1
      for (i = 1; i <= nc; i++) {
        c = order[i]
        if (tiers[c] >= 1 && tiers[c] >= MINTIER) printf "%d\t%d\t%s\t%s\n", tiers[c], deg[c], c, tops[c]
      }
    }
  ' DIR=$tmp/direct.txt TOK=$tmp/tokens.txt MINTIER="$MINTIER" \
    $tmp/direct.txt $tmp/tokens.txt $tmp/concepts.tsv \
    | sort -k1,1nr -k2,2nr -k3,3 | head -n "$C" > $tmp/cut.tsv
  # Drop what this session already has AFTER the cut, not before. Before it, a second
  # prompt on the same subject backfills the quota with whatever ranked fourth --
  # measured, a repeat ach_pull question came back with fdic. If the top concepts are
  # already in context the session has them, and the right answer is nothing.
  awk -F'\t' -v EX="$tmp/exclude.txt" \
    'FILENAME == EX { skip[$0] = 1; next } !($3 in skip)' \
    $tmp/exclude.txt $tmp/cut.tsv > $tmp/top-concepts.tsv
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
  local label=$1 seeds=$2 name=${3:-}
  local joined=$(print -r -- "$seeds" | tr ' ' '\n' | grep -v '^$' | sort -u | paste -sd, -)
  [ -n "$joined" ] || return 0
  {
    rows_for "$seeds"
    # Tab-separated, and a row with no path is dropped rather than rendered: the
    # column format is for humans and parsing it positionally turned a scoreless row
    # into "PhantomThing  0.769:1".
    RANK_FORMAT=tsv "$here/rank.sh" "$db" "$joined" 2 "$N" "$repo" 2>/dev/null \
      | awk -F'\t' 'NF >= 5 && $4 != "" && $5 != "" { printf "%s\t%s:%s\n", $1, $4, $5 }'
  } > $tmp/rows.tsv
  # A symbol already shown earns nothing by being shown again, and the blocks overlap
  # hard: a concept and the symbol that named it share most of their neighbours. On a
  # read of ach_pull.rb the first two blocks were five rows each and four were the same.
  awk -F'\t' -v E="$tmp/emitted.txt" \
    'FILENAME == E { seen[$0] = 1; next } !($1 in seen) && !dup[$1]++' \
    $tmp/emitted.txt $tmp/rows.tsv > $tmp/new.tsv
  judgment "$name"
  [ -s $tmp/new.tsv ] || [ -s $tmp/judgment.txt ] || return 0
  cut -f1 $tmp/new.tsv >> $tmp/emitted.txt
  # Only what actually reached the session is recorded, and only once it has.
  if [ -n "$chosen" ]; then
    cut -f1 $tmp/new.tsv >> "$chosen"
    [ -n "$name" ] && print -r -- "$name" >> "$chosen"
  fi
  print -r -- "$label"
  awk -F'\t' '{ printf "  %s  %s\n", $1, $2 }' $tmp/new.tsv
  [ -s $tmp/judgment.txt ] && { print -r -- "  judgment (Kevin's recorded decisions; follow them over your own inference, but check the code before acting on one):"; sed 's/^/    /' $tmp/judgment.txt }
  return 0
}

# What a person wrote below the machine block of the concept's markdown. The job never
# writes there, so this is the only place a hand-recorded decision reaches a session.
judgment() {
  : > $tmp/judgment.txt
  local file=${MATCH_CONCEPTS_DIR:-$here/../concepts}/$repo/$1.md
  [ -n "$1" ] && [[ "$1" =~ '^[a-z0-9_]+$' ]] && [ -f "$file" ] || return 0
  awk '/^<!-- end machine-owned -->/ { body = 1; next }
       body && !/^## Judgment[[:space:]]*$/ && !/^[[:space:]]*(src|provenance):/ && NF' "$file" \
    | head -c "${MATCH_JUDGMENT_BYTES:-1500}" | awk 1 > $tmp/judgment.txt
}

out=$(
  # The thing the text actually named goes first; a concept match is an inference about
  # it. Its own symbols are printed in the label, so they are not lost to the ranker
  # excluding its seeds.
  [ -s $tmp/direct.txt ] \
    && emit "named here: $(paste -sd, - < $tmp/direct.txt | sed 's/,/, /g')" "$(tr '\n' ' ' < $tmp/direct.txt)"
  while IFS=$'\t' read -r tier deg name tops; do
    emit "$name" "$tops" "$name"
  done < $tmp/top-concepts.tsv
)
[ -n "$out" ] || exit 0
print -r -- "Related code in $repo (ranked, 2 hops):"
print -r -- "$out"
