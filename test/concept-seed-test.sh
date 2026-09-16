#!/bin/zsh
set -uo pipefail
here=${0:A:h}
seed_rb=${here:h}/bin/seed-concepts.rb
load_sh=${here:h}/bin/load-concepts.sh
theme_sh=${here:h}/bin/theme.sh
index_sh=${here:h}/bin/index.sh

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT INT TERM HUP
repo=$tmp/conceptseed
db=$tmp/graph.db
pass=0 fail=0

check() {
  local what=$1 want=$2 got=$3
  if [[ $want == "$got" ]]; then
    print "ok    $what"
    pass=$(( pass + 1 ))
  else
    print "FAIL  $what"
    print "        want: $want"
    print "        got:  $got"
    fail=$(( fail + 1 ))
  fi
}

abort() {
  print -u2 "fixture failure: $1"
  [[ -f ${2:-} ]] && cat -- "$2" >&2
  exit 1
}

tgit() {
  env -u GIT_DIR -u GIT_WORK_TREE GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
    git -C "$repo" "$@"
}

commit_all() {
  tgit add -A || return 1
  tgit diff --cached --quiet && return 0
  tgit commit -qm "$1"
}

sqlq() { sqlite3 "$db" "$1" }
seed() { SEEDS_DIR=$tmp/seeds CONCEPTS_DIR=$tmp/concepts "$seed_rb" "$repo" "$db" }
load() { CONCEPTS_DIR=$tmp/concepts "$load_sh" "$db" "$repo" }
reindex() { "$index_sh" "$repo" "$db" > $tmp/index.log 2>&1 || abort "bin/index.sh" $tmp/index.log }
field() { sed -n "s/^$2:[[:space:]]*//p" "$1" | head -1 }
tail_bytes() { tail -c "$(wc -c < "$2" | tr -d ' ')" "$1" }
states() { "$theme_sh" status "$db" "$repo" | awk -F'\t' 'NR > 1 { print $2 "=" $3 }' | paste -sd' ' - }
snapshot() {
  sqlq "SELECT (SELECT group_concat(slug || '@' || COALESCE(last_indexed_sha, '')) FROM (SELECT * FROM theme ORDER BY slug)),
               (SELECT group_concat(p) FROM (SELECT t.slug || ':' || f.path AS p FROM theme_file f JOIN theme t ON t.id = f.theme_id ORDER BY 1)),
               (SELECT group_concat(n) FROM (SELECT t.slug || ':' || d.name AS n FROM theme_node d JOIN theme t ON t.id = d.theme_id ORDER BY 1))"
}

mkdir -p $repo/app/ach_pulls $tmp/seeds $tmp/concepts
cat > $repo/app/ach_pull.rb <<'RB'
class AchPull
end
RB
cat > $repo/app/ach_pulls/create_service.rb <<'RB'
module AchPulls
  class CreateService
    def call
      AchPull
    end
  end
end
RB
cat > $repo/app/ach_push.rb <<'RB'
class AchPush
  def call
    AchPull
  end
end
RB
printf 'concept\tsymbols\tin_degree\tfiles\ttop_symbols\trelated\n' > $tmp/seeds/conceptseed-concepts.tsv
printf 'ach_pull\t3\t2\t2\tAchPull AchPulls::CreateService\tach_push(1)\n' >> $tmp/seeds/conceptseed-concepts.tsv
printf 'ach_push\t1\t0\t1\tAchPush\t\n' >> $tmp/seeds/conceptseed-concepts.tsv

tgit -c init.defaultBranch=main init -q || abort "git init"
tgit config user.email concept-seed-test@example.invalid
tgit config user.name "Concept Seed Test"
commit_all "fixture" || abort "initial commit"
reindex

pull=$tmp/concepts/conceptseed/ach_pull.md
push=$tmp/concepts/conceptseed/ach_push.md

print -r -- "-- 1. the seeder writes the template"
seed > $tmp/seed.log 2> $tmp/seed.err
check "seeding exits clean"                     0 "$?"
check "it reports what it wrote"                "2 concepts in $tmp/concepts/conceptseed (2 created, 0 updated): 4 symbols, 3 files at $(tgit rev-parse --short=9 HEAD)" "$(cat $tmp/seed.log)"
check "a concept file appears per seed row"     "ach_pull.md ach_push.md" "$(print -r -- $tmp/concepts/conceptseed/*.md(:t) | tr '\n' ' ' | sed 's/ $//')"
check "frontmatter names the repo and slug"     "concept: [conceptseed, ach_pull]" "$(sed -n 2p $pull)"
check "frontmatter carries the related concept" "  - [conceptseed, ach_push]" "$(sed -n 4p $pull)"
check "a concept with no relations omits the key" "---|concept: [conceptseed, ach_push]|---|<!-- machine-owned: regenerated every run, never hand-edit -->" "$(sed -n '1,4p' $push | paste -sd'|' -)"
check "the machine block opens with its marker" "<!-- machine-owned: regenerated every run, never hand-edit -->" "$(sed -n 6p $pull)"
check "symbols come from the graph, not the seed row" "AchPull, AchPulls, AchPulls::CreateService" "$(field $pull symbols)"
check "files come from the graph"               "app/ach_pull.rb, app/ach_pulls/create_service.rb" "$(field $pull files)"
check "indexed stamps the repo HEAD"            "$(tgit rev-parse HEAD)" "$(field $pull indexed)"
check "the block closes with the end marker"    "<!-- end machine-owned -->" "$(awk '/^indexed:/ { getline; print; exit }' $pull)"
check "the prose section is opened for a human" "## Judgment" "$(tail -1 $pull)"

print -r -- "-- 2. hand-written prose survives a regenerate byte for byte"
cat > $tmp/prose.bin <<'PROSE'

## Judgment
BANK-1764 blocks submission while the pull is unsettled.   

---

The machine block above ends with this line, which must not be read as a boundary:	

```
<!-- end machine-owned -->
```

Inline, the text <!-- end machine-owned --> appears mid-sentence and is not a boundary.
	provenance: bank-1764-ach-pull-block-submission.md
PROSE
ruby -e 'f = ARGV[0]; File.binwrite(f, File.binread(f).sub(/\n\z/, ""))' $tmp/prose.bin
printf '%s' "$(sed -n '1,/^<!-- end machine-owned -->$/p' $pull)" > $tmp/handwritten.md
cat $tmp/prose.bin >> $tmp/handwritten.md
cp $tmp/handwritten.md $pull
seed > $tmp/seed2.log 2> $tmp/seed2.err
check "regenerating over prose exits clean"     0 "$?"
check "it reports the file as updated"          "(0 created, 2 updated)" "$(grep -o '([0-9]* created, [0-9]* updated)' $tmp/seed2.log)"
tail_bytes $pull $tmp/prose.bin > $tmp/got.bin
check "prose survives byte for byte"            same "$(cmp -s $tmp/prose.bin $tmp/got.bin && print same || print differs)"
check "the fenced marker is left in the prose"  1 "$(grep -c '^<!-- end machine-owned -->$' $tmp/got.bin)"
check "the real marker is still the only boundary" 2 "$(grep -c '^<!-- end machine-owned -->$' $pull)"
check "the machine block is still above it"     "$(tgit rev-parse HEAD)" "$(field $pull indexed)"

print -r -- "-- 3. a second regenerate tracks the graph and still spares the prose"
cat > $repo/app/ach_pulls/state_service.rb <<'RB'
module AchPulls
  class StateService
    def call
      AchPull
    end
  end
end
RB
commit_all "add a state service" || abort "commit state service"
reindex
seed > $tmp/seed3.log 2> $tmp/seed3.err
check "the third run exits clean"               0 "$?"
check "symbols pick up the new declaration"     "AchPull, AchPulls, AchPulls::CreateService, AchPulls::StateService" "$(field $pull symbols)"
check "files pick up the new path"              "app/ach_pull.rb, app/ach_pulls/create_service.rb, app/ach_pulls/state_service.rb" "$(field $pull files)"
check "indexed advances to the new HEAD"        "$(tgit rev-parse HEAD)" "$(field $pull indexed)"
tail_bytes $pull $tmp/prose.bin > $tmp/got3.bin
check "prose survives the second regenerate"    same "$(cmp -s $tmp/prose.bin $tmp/got3.bin && print same || print differs)"
check "nothing was created the second time"     "(0 created, 2 updated)" "$(grep -o '([0-9]* created, [0-9]* updated)' $tmp/seed3.log)"

print -r -- "-- 4. a file with no end marker is refused, not guessed at"
printf -- '---\nconcept: [conceptseed, ach_push]\n---\nhand-written, no machine block\n' > $push
cp $push $tmp/nomarker.md
seed > $tmp/seed4.log 2> $tmp/seed4.err
code=$?
verdict=refused-and-unmodified
(( code != 0 )) || verdict="exited $code"
grep -q 'no line outside a code fence is exactly `<!-- end machine-owned -->`' $tmp/seed4.err || verdict="no shaped message"
cmp -s $push $tmp/nomarker.md || verdict="overwrote the file"
check "a missing marker is refused, file untouched" refused-and-unmodified "$verdict"
check "the refusal names the file"              "$push" "$(grep -o "$push" $tmp/seed4.err | head -1)"
check "it says how many it refused"             "refused 1 concept(s)" "$(grep -o 'refused [0-9]* concept(s)' $tmp/seed4.err)"
check "the other concept still regenerated"     "(0 created, 1 updated)" "$(grep -o '([0-9]* created, [0-9]* updated)' $tmp/seed4.log)"

print -r -- "-- 5. two end markers outside a fence are refused the same way"
printf -- '---\nconcept: [conceptseed, ach_push]\n---\n<!-- end machine-owned -->\n\n## Judgment\n<!-- end machine-owned -->\n' > $push
cp $push $tmp/twomarkers.md
seed > $tmp/seed5.log 2> $tmp/seed5.err
code=$?
verdict=refused-and-unmodified
(( code != 0 )) || verdict="exited $code"
grep -q '2 lines outside a code fence are exactly `<!-- end machine-owned -->`' $tmp/seed5.err || verdict="no shaped message"
cmp -s $push $tmp/twomarkers.md || verdict="overwrote the file"
check "two markers are refused, file untouched" refused-and-unmodified "$verdict"
rm -f $push
seed > /dev/null 2>&1
check "removing the broken file lets it reseed" "AchPush" "$(field $push symbols)"

print -r -- "-- 6. load-concepts.sh rebuilds the theme tables from the markdown"
load > $tmp/load.log 2> $tmp/load.err
check "loading exits clean"                     0 "$?"
check "it reports what it loaded"               "loaded 2 concepts into $db: 5 symbols, 4 files (2 themes in conceptseed)" "$(cat $tmp/load.log)"
check "both themes exist"                       2 "$(sqlq 'SELECT count(*) FROM theme')"
check "theme_file carries every recorded path"  4 "$(sqlq 'SELECT count(*) FROM theme_file')"
check "theme_node carries every recorded symbol" 5 "$(sqlq 'SELECT count(*) FROM theme_node')"
check "the stamp comes from the markdown"       "$(tgit rev-parse HEAD)|$(tgit rev-parse HEAD)" "$(field $pull indexed)|$(sqlq "SELECT last_indexed_sha FROM theme WHERE slug = 'ach_pull'")"
check "theme.sh reports every concept fresh"    "ach_pull=fresh ach_push=fresh" "$(states)"

print -r -- "-- 7. deleting the db loses every theme; index.sh + load-concepts.sh restores them"
before=$(snapshot)
before_themes=$(sqlq 'SELECT count(*) FROM theme')
rm -f $db $db-wal $db-shm
reindex
after_index=$(sqlq 'SELECT count(*) FROM theme')
load > $tmp/load7.log 2> $tmp/load7.err
check "the restore exits clean"                 0 "$?"
check "themes are lost by a rebuild and restored from markdown" "seeded=2 lost=0 restored=2 $before" "seeded=$before_themes lost=$after_index restored=$(sqlq 'SELECT count(*) FROM theme') $(snapshot)"
check "the restored themes read fresh"          "ach_pull=fresh ach_push=fresh" "$(states)"
load > /dev/null 2>&1
check "loading twice is idempotent"             "2|$before" "$(sqlq 'SELECT count(*) FROM theme')|$(snapshot)"

print -r -- "-- 8. a concept whose files are uncommitted is not stamped at HEAD"
cp $pull $tmp/pull-before-dirty.md
printf '\n' >> $repo/app/ach_pull.rb
seed > $tmp/seedD.log 2> $tmp/seedD.err
code=$?
verdict=refused-and-unmodified
(( code != 0 )) || verdict="exited $code"
grep -q 'refusing to stamp at HEAD' $tmp/seedD.err || verdict="no shaped message"
cmp -s $pull $tmp/pull-before-dirty.md || verdict="overwrote the file"
check "an uncommitted concept file is not stamped"  refused-and-unmodified "$verdict"
check "the clean concept is still regenerated"      "(0 created, 1 updated)" "$(grep -o '([0-9]* created, [0-9]* updated)' $tmp/seedD.log)"
tgit show HEAD:app/ach_pull.rb > $repo/app/ach_pull.rb

print -r -- "-- 9. names that fail validation are refused before anything is written"
mkdir -p $tmp/badseeds $tmp/badconcepts
printf 'concept\tsymbols\tin_degree\tfiles\ttop_symbols\trelated\n../escape\t1\t0\t1\tAchPull\t\n' > $tmp/badseeds/conceptseed-concepts.tsv
SEEDS_DIR=$tmp/badseeds CONCEPTS_DIR=$tmp/badconcepts "$seed_rb" "$repo" "$db" > /dev/null 2> $tmp/seed8.err
code=$?
verdict=refused-and-nothing-written
(( code != 0 )) || verdict="exited $code"
grep -q 'unsafe slug' $tmp/seed8.err || verdict="no shaped message"
[[ -z $(print -rn -- $tmp/badconcepts/**/*(N)) ]] || verdict="wrote something"
check "an unsafe slug is refused, nothing written" refused-and-nothing-written "$verdict"

badrepo="$tmp/bad;name"
mkdir -p "$badrepo"
env -u GIT_DIR -u GIT_WORK_TREE GIT_CONFIG_GLOBAL=/dev/null git -C "$badrepo" -c init.defaultBranch=main init -q || abort "git init badrepo"
SEEDS_DIR=$tmp/seeds CONCEPTS_DIR=$tmp/concepts "$seed_rb" "$badrepo" "$db" > /dev/null 2> $tmp/seed9.err
check "an unsafe repo name is refused"          "unsafe repo name: bad?name" "$(sed 's/^[^:]*: //' $tmp/seed9.err)"

before8=$(snapshot)
printf -- '---\nconcept: [conceptseed, bad slug]\n---\n<!-- machine-owned: regenerated every run, never hand-edit -->\nsymbols:  AchPull\nfiles:    app/ach_pull.rb\nindexed:  %s\n<!-- end machine-owned -->\n' "$(tgit rev-parse HEAD)" > "$tmp/concepts/conceptseed/bad slug.md"
load > /dev/null 2> $tmp/load8.err
code=$?
verdict=refused-and-nothing-written
(( code != 0 )) || verdict="exited $code"
grep -q 'unsafe slug' $tmp/load8.err || verdict="no shaped message"
[[ $before8 == $(snapshot) ]] || verdict="wrote to the db"
check "a bad concept file name is refused by the loader" refused-and-nothing-written "$verdict"
rm -f "$tmp/concepts/conceptseed/bad slug.md"

cp $push $tmp/push-backup.md
printf -- '---\nconcept: [conceptseed, ach_pull]\n---\n<!-- machine-owned: regenerated every run, never hand-edit -->\nsymbols:  AchPush\nfiles:    app/ach_push.rb\nindexed:  %s\n<!-- end machine-owned -->\n' "$(tgit rev-parse HEAD)" > $push
load > /dev/null 2> $tmp/load9.err
code=$?
verdict=refused-and-nothing-written
(( code != 0 )) || verdict="exited $code"
grep -q 'refusing to load a file that disagrees with itself' $tmp/load9.err || verdict="no shaped message"
[[ $before8 == $(snapshot) ]] || verdict="wrote to the db"
check "a file whose frontmatter contradicts its name is refused" refused-and-nothing-written "$verdict"
cp $tmp/push-backup.md $push

print -r -- "-- 10. a path the machine block could not be read back from is refused"
cp $pull $tmp/pull-before-comma.md
cat > "$repo/app/ach_pulls/odd,name.rb" <<'RB'
module AchPulls
  class Odd
  end
end
RB
commit_all "add a path with a comma" || abort "commit comma path"
reindex
seed > $tmp/seedC.log 2> $tmp/seedC.err
code=$?
verdict=refused-and-unmodified
(( code != 0 )) || verdict="exited $code"
grep -q 'the machine block separates on commas and could not be read back' $tmp/seedC.err || verdict="no shaped message"
cmp -s $pull $tmp/pull-before-comma.md || verdict="overwrote the file"
check "a comma in a recorded path is refused"   refused-and-unmodified "$verdict"

print -r -- "-- 11. a marker that only ever appears mid-line is prose, not a boundary"
printf -- '---\nconcept: [conceptseed, ach_push]\n---\n\n## Judgment\nHAND ONE must survive\nHAND TWO: the block ends at <!-- end machine-owned --> which the job rewrites.\nHAND THREE\n' > $push
cp $push $tmp/midline.md
seed > $tmp/seedM.log 2> $tmp/seedM.err
code=$?
verdict=refused-and-unmodified
(( code != 0 )) || verdict="exited $code"
grep -q 'no line outside a code fence is exactly' $tmp/seedM.err || verdict="no shaped message"
cmp -s $push $tmp/midline.md || verdict="overwrote the file"
check "a mid-line marker is never taken as a boundary" refused-and-unmodified "$verdict"
check "the hand-written heading is still there"     1 "$(grep -c '^## Judgment$' $push)"
check "every hand-written line is still there"      3 "$(grep -c '^HAND ' $push)"

print -r -- "-- 12. the seeder and the loader agree on what a valid file is"
printf -- '---\nconcept: [conceptseed, ach_push]\n---\n\n## Judgment\nExample of the format:\n\n```\n<!-- machine-owned: regenerated every run, never hand-edit -->\nsymbols:  TotallyFakeSymbol\nfiles:    app/totally/fake.rb\nindexed:  %s\n<!-- end machine-owned -->\n```\n' "$(tgit rev-parse HEAD)" > $push
seed > /dev/null 2> $tmp/seedF.err
seed_code=$?
before12=$(snapshot)
load > /dev/null 2> $tmp/loadF.err
load_code=$?
verdict="both-refuse"
(( seed_code != 0 )) || verdict="seeder accepted it"
(( load_code != 0 )) || verdict="loader accepted it"
grep -q 'no line outside a code fence is exactly' $tmp/seedF.err || verdict="seeder gave no shaped message"
grep -q 'no line outside a code fence is exactly' $tmp/loadF.err || verdict="loader gave no shaped message"
[[ $before12 == $(snapshot) ]] || verdict="loader wrote to the db"
check "a fenced machine block is refused by both"   both-refuse "$verdict"
check "the fenced example never reaches theme_node" "real=5 fake=0" "real=$(sqlq 'SELECT count(*) FROM theme_node') fake=$(sqlq "SELECT count(*) FROM theme_node WHERE name = 'TotallyFakeSymbol'")"
cp $tmp/push-backup.md $push

print -r -- "-- 13. a fenced begin marker cannot supply fields the real block omits"
before13=$(snapshot)
{
  printf -- '---\nconcept: [conceptseed, ach_push]\n---\n'
  printf -- '```\n<!-- machine-owned: regenerated every run, never hand-edit -->\nfiles:    app/EVIL.rb\n```\n'
  printf -- '<!-- machine-owned: regenerated every run, never hand-edit -->\nsymbols:  AchPush\nindexed:  %s\n' "$(tgit rev-parse HEAD)"
  printf -- '<!-- end machine-owned -->\n\n## Judgment\n'
} > $push
load > /dev/null 2> $tmp/load13.err
code=$?
verdict=refused-and-nothing-written
(( code != 0 )) || verdict="exited $code"
grep -q 'the machine block lists no files' $tmp/load13.err || verdict="no shaped message"
[[ $before13 == $(snapshot) ]] || verdict="wrote to the db"
check "a fenced begin marker supplies nothing"  refused-and-nothing-written "$verdict"
check "app/EVIL.rb never reaches theme_file"    "real=4 evil=0" "real=$(sqlq 'SELECT count(*) FROM theme_file') evil=$(sqlq "SELECT count(*) FROM theme_file WHERE path = 'app/EVIL.rb'")"
cp $tmp/push-backup.md $push

print -r -- "-- 14. a field inside the machine block cannot be overridden or smuggled"
before14=$(snapshot)
block() { printf -- '---\nconcept: [conceptseed, ach_push]\n---\n<!-- machine-owned: regenerated every run, never hand-edit -->\n%bindexed:  %s\n<!-- end machine-owned -->\n\n## Judgment\n' "$1" "$(tgit rev-parse HEAD)" > $push }

block 'symbols:  AchPush\nfiles:    app/ach_push.rb\n```\nfiles:    app/EVIL.rb\n```\n'
load > /dev/null 2> $tmp/load14a.err
check "a fenced field does not override a real one" "0|app/ach_push.rb" "$?|$(sqlq "SELECT group_concat(f.path) FROM theme_file f JOIN theme t ON t.id = f.theme_id WHERE t.slug = 'ach_push'")"

block 'symbols:  AchPush\nfiles:    app/ach_push.rb\nfiles:    app/EVIL.rb\n'
snap14=$(snapshot)
load > /dev/null 2> $tmp/load14b.err
code=$?
verdict=refused-and-nothing-written
(( code != 0 )) || verdict="exited $code"
grep -q 'the machine block has 2 `files:` lines — refusing, the value is ambiguous' $tmp/load14b.err || verdict="no shaped message"
[[ $snap14 == $(snapshot) ]] || verdict="wrote to the db"
check "a duplicate field key is refused, not guessed"  refused-and-nothing-written "$verdict"

block 'symbols:  AchPush\n```\nfiles:    app/EVIL.rb\n```\n'
load > /dev/null 2> $tmp/load14c.err
code=$?
verdict=refused-and-nothing-written
(( code != 0 )) || verdict="exited $code"
grep -q 'the machine block lists no files' $tmp/load14c.err || verdict="no shaped message"
[[ $snap14 == $(snapshot) ]] || verdict="wrote to the db"
check "a fenced field cannot supply a missing one"     refused-and-nothing-written "$verdict"
check "app/EVIL.rb never reaches theme_file at all"    "real=4 evil=0" "real=$(sqlq 'SELECT count(*) FROM theme_file') evil=$(sqlq "SELECT count(*) FROM theme_file WHERE path = 'app/EVIL.rb'")"
cp $tmp/push-backup.md $push
load > /dev/null 2>&1

print ""
print "$pass passed, $fail failed"
(( fail == 0 ))
