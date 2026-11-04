#!/bin/zsh
# CATALOG.md reach: memory-scope.sh injects the catalog lines a prompt is about, and
# reconcile-index.sh counts the catalog as indexed and files new pointers there.
set -uo pipefail
export LC_ALL=C
unset CLAUDE_PROJECT_DIR MEMORY_SCOPE_LIMIT MEMORY_CATALOG_LIMIT CATALOG_MIN CATALOG_MAX_LINES CATALOG_SEEN CATALOG_PARTIAL CATALOG_DEBUG
here=${0:A:h}
repo=${here:h}
hook=$repo/hooks/memory-scope.sh

pass=0; fail=0
check() {
  local what=$1 want=$2 got=$3
  if [[ $want == "$got" ]]; then print "ok    $what"; pass=$((pass+1))
  else print "FAIL  $what"; print "        want: $want"; print "        got:  $got"; fail=$((fail+1)); fi
}

tmp=$(mktemp -d) || exit 1; tmp=${tmp:A}
trap 'rm -rf "$tmp"' EXIT
export TMPDIR=$tmp/marks/
mkdir -p "$TMPDIR"
umbrella=$tmp/projects
scopes=$tmp/scopes
slug() { local p="${1#/}"; print -r -- "${p//[\/._]/-}" }
mkdir -p $umbrella/bank $umbrella/plain
bank="$scopes/$(slug $umbrella/bank)"
mkdir -p "$bank" "$scopes/$(slug $umbrella/plain)"
print -r -- "- [hot wire cutoff](hot-wire-cutoff.md) — already loaded" > "$bank/MEMORY.md"
{
  print "# Catalog"
  print "## Wires"
  print -r -- "- [hot wire cutoff](hot-wire-cutoff.md) — already loaded"
  print -r -- "- [Frozen Merge Ref](merge-ref-frozen.md) — refs/pull/N/merge is not live"
  print -r -- "- [CA 228379 self pulls](ca228379-self-pulls.md) — pulled from its own sub"
  print -r -- "- [scoring repair](upload-stuck-scoring.md) — repair an upload stuck at scoring"
  print -r -- "- **Returns:** [manual return](wire-manual-return.md) · [stale sub](wire-stale-sub.md)"
  for i in {1..12}; do print -r -- "- [common note $i](common-$i.md) — a common thing"; done
  print -r -- "- [should really look](stop-words.md) — stopwords only"
  print -r -- "- **Ledger drift:** [nightly sweep](ledger-sweep.md)"
  print -r -- "- [one more note](zebra-quokka.md) — named only by its file"
  print -r -- "- [pulled money](pulled-money.md) — pulled 445566 from a sub"
  print -r -- "- [limit 100 rows](limit-rows.md) — a three-digit number"
  for i in {1..5}; do print -r -- "- [gizmo sprocket $i](gs-$i.md) — a mid-frequency pair"; done
  print -r -- "- [gizmo turnip](gizmo-turnip.md) — one rare word and one mid"
  print -r -- "- [tango-the](tango-the.md) — a hyphenated name with a stop word"
  print -r -- "- [e2e recipe](e2e-recipe.md) — a short word with a digit"
  print -r -- "- [sweep 2026 rerun](sweep-2026.md) — a year in a name"
  print -r -- "- [TP ACH errors](tp-false-ach.md) — webhook errors"
  print -r -- "- [alder one](alder-one.md) · [birch two](birch-two.md) — shared note"
  print -r -- "- [cedar](cedar-x.md) — own note · loose prose · [dogwood](dogwood-x.md) — its note"
  print -r -- "- [elm](elm-x.md) — see also [fir](fir-x.md)"
  print -r -- "  - [gum](gum-x.md) · [hazel](hazel-x.md)"
  print -r -- "- [ivy [beta]](ivy-x.md) · [juniper](juniper-x.md)"
  print -r -- "- [1581 follow-ups](t1581.md) — a ticket's follow-ups"
  print -r -- "- [account_purpose follow-ups](ap-follow.md) — another"
  print -r -- "- [retry 42 times](retry-42.md) — a two-digit number"
  print -r -- "- [walrus narwhal long](wn-long.md) — xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  print -r -- "- [walrus narwhal short](wn-short.md)"
  print -r -- "- [kelp anchor](kelp-a.md) · [kelp dead](kelp-dead.md) · [web](https://example.com/x)"
  print -r -- "- [tpx achy notes](tpx-achy.md) — prefixes only"
  print -r -- "- [ticket 12345 fix](t12345.md) — a five-digit ticket"
} > "$bank/CATALOG.md"
for f in hot-wire-cutoff merge-ref-frozen ca228379-self-pulls upload-stuck-scoring wire-manual-return wire-stale-sub common-{1..12} stop-words ledger-sweep zebra-quokka pulled-money limit-rows gs-{1..5} gizmo-turnip tango-the e2e-recipe sweep-2026 alder-one birch-two cedar-x dogwood-x elm-x fir-x gum-x hazel-x ivy-x juniper-x t1581 ap-follow retry-42 wn-long wn-short kelp-a kelp-dead tp-false-ach tpx-achy t12345; do : > "$bank/$f.md"; done
print -r -- "- [p](p.md)" > "$scopes/$(slug $umbrella/plain)/MEMORY.md"; : > "$scopes/$(slug $umbrella/plain)/p.md"

match() { print -r -- "$1" | perl $repo/bin/catalog-match.pl "$bank" | grep -oE '\]\([^)]+\.md\)' | tr -d '])(' | paste -sd, - }
check "two rare title words pick a line"      merge-ref-frozen.md     "$(match 'the merge ref looks frozen')"
check "one rare word alone does not"          ""                      "$(match 'is the ref ok')"
check "a number alone does"                   ca228379-self-pulls.md  "$(match 'look at 228379')"
check "a description-only word does not count" ""                     "$(match 'pulled live')"
check "a common word does not count"          ""                      "$(match 'common note thing')"
check "a hot-index line is never repeated"    ""                      "$(match 'hot wire cutoff')"
check "a grouped line scores by its best link" wire-manual-return.md,wire-stale-sub.md "$(match 'manual return of a stale sub')"
check "plural matches singular"               upload-stuck-scoring.md "$(match 'scoring repairs')"
check "stopwords never match"                 ""                      "$(match 'should really look')"
check "seen lines are skipped"                ""                      "$(print -r -- '- [Frozen Merge Ref](merge-ref-frozen.md) — refs/pull/N/merge is not live' > $tmp/seen; print -r -- 'merge ref frozen' | CATALOG_SEEN=$tmp/seen perl $repo/bin/catalog-match.pl "$bank")"
check "lines are capped"                      1                       "$(print -r -- 'merge ref frozen 228379 scoring repair' | CATALOG_MAX_LINES=1 perl $repo/bin/catalog-match.pl "$bank" | wc -l | tr -d ' ')"
check "best first, ties in catalog order"   merge-ref-frozen.md,ca228379-self-pulls.md,gizmo-turnip.md "$(match 'turnip gizmo 228379 merge ref frozen')"
check "the cap keeps the best"                merge-ref-frozen.md "$(print -r -- 'turnip gizmo 228379 merge ref frozen' | CATALOG_MAX_LINES=1 perl $repo/bin/catalog-match.pl "$bank" | grep -oE '\(merge-ref-frozen.md\)' | tr -d '()')"
check "case does not matter"                  merge-ref-frozen.md     "$(match 'The MERGE Ref looks Frozen')"
check "a hyphenated word counts by its parts" merge-ref-frozen.md     "$(match 'merge-ref frozen?')"
check "a bold label names its links"          ledger-sweep.md         "$(match 'ledger drift')"
check "so does a filename"                    zebra-quokka.md         "$(match 'zebra quokka')"
check "a number only in prose does not count" ""                      "$(match '445566')"
check "a three-digit number is just a word"   ""                      "$(match 'set it to 100')"
check "two mid-frequency words are not enough" ""                     "$(match 'gizmo sprocket')"
check "a rare word and a mid one are"         gizmo-turnip.md         "$(match 'gizmo turnip')"
check "a capitalised acronym counts"          tp-false-ach.md         "$(match 'another TP ACH glitch')"
check "so does a lowercase one"              tp-false-ach.md         "$(match 'tp ach glitch')"
check "a hyphenated word scores its parts together" gizmo-turnip.md "$(match 'gizmo-turnip')"
check "but not on top of the whole word"     ""                      "$(match 'tango-the')"
check "a short word with a digit counts"      e2e-recipe.md          "$(match 'e2e recipe broken')"
check "a plural hyphen part is not a word"   ""                      "$(match 'any follow-ups?')"
check "but a ticket with it still matches"   t1581.md               "$(match '1581 follow-ups')"
check "a two-digit number is not a word"     ""                      "$(match '42 retry')"
check "a year inside a date does not"         ""                      "$(match 'deploy went out 2026-11-02')"
check "a number matches whole"                t12345.md               "$(match 'see 12345')"
check "not as a prefix"                       ""                      "$(match 'see 1234')"
check "nor inside a longer one"               ""                      "$(match 'see 123456')"
check "nor as a suffix"                       ""                      "$(match 'see 2345')"
check "a group label is not part of each link" ""                     "$(match 'returns stale')"

ask() { jq -nc --arg p "$1" --arg s "$2" '{session_id:$s,prompt:$p}' \
          | MEMORY_SCOPES_DIR=$scopes CLAUDE_PROJECT_DIR=$3 zsh "$hook" UserPromptSubmit }
ctx() { jq -r '.hookSpecificOutput.additionalContext // ""' }
lines() { ask "$@" | ctx | sed -n '/memory catalog/,$p' | grep -oE '^- .*\]\([^)]+\.md\)' | grep -oE '\]\([^)]+\.md\)' | tr -d '])(' | paste -sd, - }
check "the cwd's own catalog is searched"     merge-ref-frozen.md     "$(lines 'merge ref frozen' c1 $umbrella/bank)"
check "with where its files are"              1                       "$(ask 'merge ref frozen' c1b $umbrella/bank | ctx | grep -c "files are in \`$bank/\`")"
check "a line is injected once per session"   ""                      "$(lines 'merge ref frozen again' c1 $umbrella/bank)"
check "a new line still comes"                ca228379-self-pulls.md  "$(lines 'and 228379' c1 $umbrella/bank)"
check "a scope with no catalog adds nothing"  0                       "$(ask 'merge ref frozen' c2 $umbrella/plain | wc -c | tr -d ' ')"
check "above the repos, an unnamed scope is silent" 0                 "$(ask 'merge ref frozen' c3 $umbrella | wc -c | tr -d ' ')"
check "naming the repo opens its catalog"     merge-ref-frozen.md     "$(lines 'in bank, merge ref frozen' c3 $umbrella)"
check "and it stays open"                     ca228379-self-pulls.md  "$(lines '228379' c3 $umbrella)"
check "a scope with no catalog leaves no mark" 0                      "$(ask 'plain' c4 $umbrella >/dev/null; ls $TMPDIR | grep -c 'c4\..*\.catalog')"
q='merge ref frozen 228379 scoring repair manual return'
check "the block stays in its budget"         yes                     "$(o=$(MEMORY_CATALOG_LIMIT=350 ask $q c5 $umbrella/bank | ctx); n=$(grep -c '^- ' <<<$o); (( ${#o} <= 350 && n >= 1 && n < 4 )) && print yes || print "no(${#o},$n)")"
check "and what it left out comes later"      yes                     "$(n=$(MEMORY_CATALOG_LIMIT=350 ask $q c5 $umbrella/bank | ctx | grep -c '^- '); (( n >= 1 )) && print yes || print no)"
check "a line too long to fit is skipped, not the rest" wn-short.md "$(MEMORY_CATALOG_LIMIT=300 lines 'walrus narwhal' c6 $umbrella/bank)"
check "a [system] line is ignored"            ""                      "$(lines '[system] merge ref frozen' c6 $umbrella/bank)"

other="$scopes/$(slug $umbrella/other)"; mkdir -p $umbrella/other "$other"
print -r -- "- [o](o.md)" > "$other/MEMORY.md"
print -r -- "- [kumquat lemur](kumquat-lemur.md) — in the other scope" > "$other/CATALOG.md"; : > "$other/o.md"; : > "$other/kumquat-lemur.md"
check "two scopes' catalogs in one prompt"    merge-ref-frozen.md,ca228379-self-pulls.md,kumquat-lemur.md "$(lines 'bank and other: merge ref frozen, 228379, kumquat lemur' c7 $umbrella)"
check "each under its own heading"            2                       "$(ask 'bank and other: merge ref frozen, kumquat lemur' c8 $umbrella | ctx | grep -c 'memory catalog that match')"
check "one heading per scope"                 "1,2"                   "$(o=$(ask 'merge ref frozen 228379' c10 $umbrella/bank | ctx); print -r -- "$(grep -c 'memory catalog that match' <<<$o),$(grep -c '^- ' <<<$o)")"
for i in {1..9}; do print -r -- "- [frozen thing $i](frozen-$i.md)" >> "$other/CATALOG.md"; : > "$other/frozen-$i.md"; done
check "rarity is counted per scope"           merge-ref-frozen.md     "$(lines 'bank and other: merge frozen' c11 $umbrella)"
cutrepo="$scopes/$(slug $umbrella/cutrepo)"; mkdir -p $umbrella/cutrepo "$cutrepo"
{ for i in {1..250}; do print -r -- "- [hot note $i](h$i.md) — a line of hot index text"; done; print -r -- "- [late zebrafinch lesson](late-lesson.md) — past the cut"; } > "$cutrepo/MEMORY.md"
print -r -- "- [late zebrafinch lesson](late-lesson.md) — past the cut" > "$cutrepo/CATALOG.md"; : > "$cutrepo/late-lesson.md"; for i in {1..250}; do : > "$cutrepo/h$i.md"; done
check "a cut hot index leaves its lines to the catalog" late-lesson.md "$(lines 'cutrepo: the late zebrafinch lesson' c12 $umbrella)"
check "a whole one does not"                  ""                      "$(lines 'bank: hot wire cutoff' c13 $umbrella)"
check "the hook ceiling bounds the block"     yes                     "$(o=$(MEMORY_SCOPE_LIMIT=-1150 ask 'merge ref frozen 228379 scoring repair' c9 $umbrella/bank | ctx); (( ${#o} <= 350 )) && print yes || print "no(${#o})")"

tg() { env -u GIT_DIR -u GIT_WORK_TREE -u GIT_COMMON_DIR GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git "$@" }
tg -C $umbrella/bank init -q && tg -C $umbrella/bank worktree add -q --orphan -b wt $tmp/bankwt
start() { jq -nc --arg s "$1" --arg src "${2:-startup}" '{session_id:$s,source:$src}' \
            | (cd $tmp/bankwt && MEMORY_SCOPES_DIR=$scopes CLAUDE_PROJECT_DIR=$tmp/bankwt zsh "$hook") }
start w1 >/dev/null
check "a worktree searches its parent's catalog" merge-ref-frozen.md  "$(lines 'merge ref frozen' w1 $tmp/bankwt)"
check "compaction forgets what was injected"  merge-ref-frozen.md     "$(start w1 compact >/dev/null; lines 'merge ref frozen' w1 $tmp/bankwt)"
check "a worktree session with no SessionStart is silent" ""          "$(lines 'merge ref frozen' w2 $tmp/bankwt)"
check "a whole parent index marks the catalog 0" 0             "$(cat $TMPDIR/memory-scope-w1.$(slug $umbrella/bank).catalog)"
check "a cut one marks it 1"                  1                      "$(MEMORY_SCOPE_LIMIT=50 start w5 >/dev/null; cat $TMPDIR/memory-scope-w5.$(slug $umbrella/bank).catalog)"
check "so its hot lines can come back"        hot-wire-cutoff.md     "$(lines 'hot wire cutoff' w5 $tmp/bankwt)"
check "the listing counts catalog links"      "$(slug $umbrella/bank) — 52 indexed of 52" "$(start w3 | ctx | grep -o "$(slug $umbrella/bank) — .*")"
: > "${TMPDIR}memory-scope-keep1.x.catalog"
jq -nc '{source:"compact"}' | (cd $tmp/bankwt && MEMORY_SCOPES_DIR=$scopes CLAUDE_PROJECT_DIR=$tmp/bankwt zsh "$hook") >/dev/null
check "a compact with no session clears nothing" 1                    "$(ls $TMPDIR | grep -c '^memory-scope-keep1\.x\.catalog$')"

recon() { bash $repo/hooks/reconcile-index.sh "$1" >/dev/null }
r=$tmp/recon; cp -R $scopes $r
recon $r
check "catalog links count as indexed"        "" "$(diff -r $scopes $r)"
print -r -- $'---\ndescription: a brand new lesson\n---' > $r/$(slug $umbrella/bank)/brand-new.md
recon $r
check "a new pointer goes to the catalog"     1  "$(grep -c '(brand-new.md) — a brand new lesson' $r/$(slug $umbrella/bank)/CATALOG.md)"
print -r -- $'---\ndescription: another new lesson\n---' > $r/$(slug $umbrella/bank)/another-new.md
recon $r
check "under one Unfiled heading in the catalog" 1 "$(grep -c '^## Unfiled$' $r/$(slug $umbrella/bank)/CATALOG.md)"
check "and leaves the hot index alone"        "" "$(diff $bank/MEMORY.md $r/$(slug $umbrella/bank)/MEMORY.md)"
check "the catalog is not a memory"           0  "$(cat $r/$(slug $umbrella/bank)/*.md | grep -c '(CATALOG.md)')"
rm $r/$(slug $umbrella/bank)/merge-ref-frozen.md
recon $r
check "a dead catalog pointer is dropped"     0  "$(grep -c 'Frozen Merge Ref' $r/$(slug $umbrella/bank)/CATALOG.md)"
rm $r/$(slug $umbrella/bank)/wire-stale-sub.md
recon $r
check "a grouped line keeps its live links"   1  "$(grep -cxF -- '- **Returns:** [manual return](wire-manual-return.md) · stale sub' $r/$(slug $umbrella/bank)/CATALOG.md)"
rm $r/$(slug $umbrella/bank)/{birch-two,dogwood-x,fir-x,gum-x,ivy-x}.md
recon $r
check "a dead link becomes plain text"       1  "$(grep -cxF -- '- [alder one](alder-one.md) · birch two — shared note' $r/$(slug $umbrella/bank)/CATALOG.md)"
check "and no prose is dropped"              1  "$(grep -cxF -- '- [cedar](cedar-x.md) — own note · loose prose · dogwood — its note' $r/$(slug $umbrella/bank)/CATALOG.md)"
check "an indented bullet keeps its prefix"  1  "$(grep -cxF -- '  - gum · [hazel](hazel-x.md)' $r/$(slug $umbrella/bank)/CATALOG.md)"
check "a bracket in link text still unwraps" 1  "$(grep -cxF -- '- ivy [beta] · [juniper](juniper-x.md)' $r/$(slug $umbrella/bank)/CATALOG.md)"
rm $r/$(slug $umbrella/bank)/{kelp-a,kelp-dead}.md
recon $r
check "a line keeps a live web link"         1  "$(grep -cxF -- '- kelp anchor · kelp dead · [web](https://example.com/x)' $r/$(slug $umbrella/bank)/CATALOG.md)"
print -r -- '- [upstream readme](https://example.com/README.md) — a web doc' >> $r/$(slug $umbrella/bank)/CATALOG.md
recon $r
check "a web link ending in .md is not a memory" 1 "$(grep -cxF -- '- [upstream readme](https://example.com/README.md) — a web doc' $r/$(slug $umbrella/bank)/CATALOG.md)"
check "a link inside prose is unwrapped"     1  "$(grep -cxF -- '- [elm](elm-x.md) — see also fir' $r/$(slug $umbrella/bank)/CATALOG.md)"
print -r -- $'---\ndescription: plain lesson\n---' > $r/$(slug $umbrella/plain)/q.md
recon $r
check "a scope with no catalog still files in MEMORY.md" 1 "$(grep -c '(q.md)' $r/$(slug $umbrella/plain)/MEMORY.md)"

print "$pass passed, $fail failed"
(( fail == 0 ))
