#!/bin/zsh
set -uo pipefail
here=${0:A:h}
theme_sh=${here:h}/bin/theme.sh
index_sh=${here:h}/bin/index.sh
schema_sql=${here:h}/bin/schema.sql
migration=db/migrate/20250429153118_add_dibs_columns_to_ach_pull_push_and_external_ach_account.rb

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
repo=$tmp/themetest
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
theme_id() { sqlq "SELECT id FROM theme WHERE slug = '$1'" }
theme_symbols() { sqlq "SELECT group_concat(name) FROM (SELECT name FROM theme_node WHERE theme_id = $(theme_id "$1") ORDER BY name)" }
theme_files() { sqlq "SELECT count(*) FROM theme_file WHERE theme_id = $(theme_id "$1")" }
stamped_sha() { sqlq "SELECT last_indexed_sha FROM theme WHERE slug = '$1'" }
snapshot() {
  sqlq "SELECT (SELECT count(*) FROM theme_file), (SELECT count(*) FROM theme_node),
               (SELECT count(*) FROM node), (SELECT count(*) FROM edge),
               (SELECT group_concat(name) FROM (SELECT name FROM theme_node ORDER BY name)),
               (SELECT group_concat(COALESCE(last_indexed_sha,'NULL')) FROM (SELECT last_indexed_sha FROM theme ORDER BY slug))"
}

status_row() { "$theme_sh" status "$db" "$repo" "$1" | sed -n 2p }
field() { print -r -- "$1" | cut -f"$2" }
theme() { "$theme_sh" "$@" }

mkdir -p $repo/app $repo/db/migrate
cat > $repo/app/alpha.rb <<'RB'
class Alpha
end
RB
cat > $repo/app/beta.rb <<'RB'
class Beta
  def ping
    Alpha
  end
end
RB
cat > $repo/app/gamma.rb <<'RB'
class Gamma
end
RB
cat > $repo/app/aaa_shared.rb <<'RB'
module Shared
end
RB
cat > $repo/app/aaa_orphan.rb <<'RB'
module Orphan
end
RB
cat > $repo/app/zzz_orphan.rb <<'RB'
module Orphan
  def self.second_site; end
end
RB
cat > $repo/app/zzz_shared.rb <<'RB'
module Shared
  def self.late; end
end
module Lifted
end
RB

tgit -c init.defaultBranch=main init -q || abort "git init"
tgit config user.email theme-ledger-test@example.invalid
tgit config user.name "Theme Ledger Test"
commit_all "fixture" || abort "initial commit"

"$index_sh" "$repo" "$db" > $tmp/index.log 2>&1 || abort "bin/index.sh" $tmp/index.log
edges_at_index=$(sqlq "SELECT count(*) FROM edge")

print -r -- "-- 1. seed a theme over two of three files"
theme seed "$db" "$repo" ledger app/alpha.rb app/beta.rb > $tmp/seed.log 2>&1 || abort "seed" $tmp/seed.log
check "seed records both files"                 2                      "$(theme_files ledger)"
check "seed derives symbols from those files"   "Alpha,Beta"           "$(theme_symbols ledger)"
check "seed stamps the worktree HEAD"           "$(tgit rev-parse HEAD)" "$(stamped_sha ledger)"

print -r -- "-- 2. a freshly seeded theme is fresh"
row=$(status_row ledger)
check "status reports fresh"                    fresh                  "$(field "$row" 3)"
check "status gives no reason when fresh"       ""                     "$(field "$row" 7)"

print -r -- "-- 3. a committed edit to a seeded file goes stale"
cat > $repo/app/beta.rb <<'RB'
class BetaRenamed
  def ping
    Alpha
  end
end
RB
commit_all "rename Beta" || abort "commit rename"
row=$(status_row ledger)
check "status reports stale"                    stale                  "$(field "$row" 3)"
check "status blames changed files"             changed-files          "$(field "$row" 7)"
check "status counts one changed file"          1                      "$(field "$row" 5)"

print -r -- "-- 4. reseed re-reads only the changed file"
theme reseed "$db" "$repo" ledger > $tmp/reseed.log 2> $tmp/reseed.err
check "a rename drops the old name and exits 3" 3 "$?"
check "reseed reparses 1 of 2"  "reparsed 1 of 2 files in indexer scope (2 tracked)" "$(sed -n 1p $tmp/reseed.log)"
check "reseed names only the changed file"      app/beta.rb            "$(sed -n '2,$p' $tmp/reseed.log)"
check "stdout carries only the machine-readable report" 2 "$(wc -l < $tmp/reseed.log | tr -d ' ')"
check "reseed picks up the rename"              "Alpha,BetaRenamed"    "$(theme_symbols ledger)"
check "reseed writes no edges"                  "$edges_at_index"      "$(sqlq 'SELECT count(*) FROM edge')"

print -r -- "-- 5. a drop marks the repo incomplete until a full index, then the theme is fresh"
check "the drop outlives the exit code"         graph-incomplete       "$(field "$(status_row ledger)" 7)"
"$index_sh" "$repo" "$db" > /dev/null 2>&1 || abort "recovery reindex"
theme seed "$db" "$repo" ledger app/alpha.rb app/beta.rb > /dev/null 2>&1 || abort "re-seed after recovery"
check "a full index clears it"                  fresh                  "$(field "$(status_row ledger)" 3)"

print -r -- "-- 6. an unrelated file moving does not go stale"
print 'class Gamma; def tick; end; end' > $repo/app/gamma.rb
commit_all "touch gamma" || abort "commit gamma"
check "status stays fresh for unseeded churn"   fresh                  "$(field "$(status_row ledger)" 3)"

print -r -- "-- 7. an uncommitted edit to a seeded file goes stale"
print '# touched, not committed' >> $repo/app/alpha.rb
row=$(status_row ledger)
check "status reports stale on a dirty file"    stale                  "$(field "$row" 3)"
check "status counts the uncommitted file"      1                      "$(field "$row" 5)"

print -r -- "-- 8. a sha this repo cannot resolve is stale, not an error"
sqlq "UPDATE theme SET last_indexed_sha = 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeef' WHERE slug = 'ledger'"
theme status "$db" "$repo" ledger > $tmp/status.log 2>&1
rc=$?
row=$(sed -n 2p $tmp/status.log)
check "status exits 0 on an unknown sha"        0                      "$rc"
check "status reports stale"                    stale                  "$(field "$row" 3)"
check "status blames the unknown sha"           unknown-sha            "$(field "$row" 7)"

print -r -- "-- 9. seed and reseed are idempotent"
commit_all "commit the uncommitted edit" || abort "commit before idempotence"
theme seed "$db" "$repo" ledger app/alpha.rb app/beta.rb > /dev/null 2>&1 || abort "seed (idempotence)"
before=$(snapshot)
theme seed "$db" "$repo" ledger app/alpha.rb app/beta.rb > /dev/null 2>&1 || abort "re-seed (idempotence)"
check "seeding twice changes nothing"           "$before"              "$(snapshot)"
theme reseed "$db" "$repo" ledger > /dev/null 2>&1 || abort "reseed (idempotence)"
before=$(snapshot)
theme reseed "$db" "$repo" ledger > /dev/null 2>&1 || abort "re-reseed (idempotence)"
check "reseeding twice changes nothing"         "$before"              "$(snapshot)"

print -r -- "-- 10. a theme file outside the indexer scope is tracked but never parsed"
commit_all "settle the working tree" || abort "commit before scope test"
cat > $repo/$migration <<'RB'
class AddDibsColumnsToAchPullPushAndExternalAchAccount
  def change
  end
end
RB
commit_all "add migration" || abort "commit migration"
theme seed "$db" "$repo" mixed app/alpha.rb app/beta.rb $migration > /dev/null 2>&1 || abort "seed mixed"
check "seed tracks the out-of-scope file"       3                      "$(theme_files mixed)"
check "the migration contributes no symbols"    "Alpha,BetaRenamed"    "$(theme_symbols mixed)"
check "mixed theme starts fresh"                fresh                  "$(field "$(status_row mixed)" 3)"

cat > $repo/$migration <<'RB'
class AddDibsColumnsToAchPullPushAndExternalAchAccount
  def change
    add_column :ach_pulls, :dibs, :string
  end
end
RB
commit_all "change the migration" || abort "commit migration change"
row=$(status_row mixed)
check "an out-of-scope change still goes stale" stale                  "$(field "$row" 3)"
check "status counts the out-of-scope file"     1                      "$(field "$row" 5)"
theme reseed "$db" "$repo" mixed > $tmp/reseed-mixed.log 2>&1 || abort "reseed mixed" $tmp/reseed-mixed.log
check "reseed reparses 0 of 2"  "reparsed 0 of 2 files in indexer scope (3 tracked)" "$(sed -n 1p $tmp/reseed-mixed.log)"
check "reseed re-stamps anyway"                 "$(tgit rev-parse HEAD)" "$(stamped_sha mixed)"
check "mixed theme is fresh again"              fresh                  "$(field "$(status_row mixed)" 3)"
check "no migration class reached node"         0                      "$(sqlq "SELECT count(*) FROM node WHERE name LIKE 'AddDibs%'")"

print -r -- "-- 11. reseed never raises the citation of a symbol declared in several files"
check "the full index cites the lowest path" app/aaa_shared.rb "$(sqlq "SELECT path FROM node WHERE name = 'Shared'")"
theme seed "$db" "$repo" shared app/zzz_shared.rb > /dev/null 2>&1 || abort "seed shared"
cat > $repo/app/zzz_shared.rb <<'RB'
module Shared
  def self.late; end
  def self.later; end
end
module Lifted
end
RB
commit_all "extend the second declaration" || abort "commit shared"
theme reseed "$db" "$repo" shared > $tmp/reseed-shared.log 2>&1 || abort "reseed shared" $tmp/reseed-shared.log
check "reseed reparses the seeded file"  "reparsed 1 of 1 files in indexer scope (1 tracked)" "$(sed -n 1p $tmp/reseed-shared.log)"
check "reseed leaves the citation lowest" app/aaa_shared.rb "$(sqlq "SELECT path FROM node WHERE name = 'Shared'")"

print -r -- "-- 12. reseed still lowers a citation when the reparsed file sorts first"
check "the citation starts at the later file" app/zzz_shared.rb "$(sqlq "SELECT path FROM node WHERE name = 'Lifted'")"
theme seed "$db" "$repo" lifted app/aaa_shared.rb > /dev/null 2>&1 || abort "seed lifted"
cat >> $repo/app/aaa_shared.rb <<'RB'
module Lifted
end
RB
commit_all "declare Lifted earlier" || abort "commit lifted"
theme reseed "$db" "$repo" lifted > $tmp/reseed-lifted.log 2>&1 || abort "reseed lifted" $tmp/reseed-lifted.log
check "reseed lowers the citation"        app/aaa_shared.rb "$(sqlq "SELECT path FROM node WHERE name = 'Lifted'")"

print -r -- "-- 13. seed refuses paths git does not track"
print 'class Wip; end' > $repo/app/wip.rb
theme seed "$db" "$repo" wip app/wip.rb > $tmp/seed-wip.log 2>&1
check "seed rejects an untracked file"    1 "$?"
check "seed says why"                     1 "$(grep -c 'not tracked in themetest: app/wip.rb' $tmp/seed-wip.log; true)"
theme seed "$db" "$repo" typo app/alhpa.rb > $tmp/seed-typo.log 2>&1
check "seed rejects a phantom path"       1 "$?"
check "no theme was created"              "" "$(sqlq "SELECT slug FROM theme WHERE slug IN ('wip','typo')")"
rm -f $repo/app/wip.rb

print -r -- "-- 14. status and reseed agree that an unknown theme is an error"
theme status "$db" "$repo" nosuchtheme > /dev/null 2>&1
check "status fails on an unknown slug"   1 "$?"
theme reseed "$db" "$repo" nosuchtheme > /dev/null 2>&1
check "reseed fails on an unknown slug"   1 "$?"

print -r -- "-- 15. a symbol losing its only cited declaration is reported, not silently dropped"
check "the full index cites the first site" app/aaa_orphan.rb "$(sqlq "SELECT path FROM node WHERE name = 'Orphan'")"
theme seed "$db" "$repo" orphan app/aaa_orphan.rb > /dev/null 2>&1 || abort "seed orphan"
cat > $repo/app/aaa_orphan.rb <<'RB'
module NotOrphan
end
RB
commit_all "drop the first declaration" || abort "commit orphan"
theme reseed "$db" "$repo" orphan > $tmp/reseed-orphan.log 2> $tmp/reseed-orphan.err
check "reseed signals the drop with exit 3" 3 "$?"
check "reseed names the dropped symbol"   1 "$(grep -c 'dropped 1 symbol(s).*Orphan' $tmp/reseed-orphan.err; true)"
check "reseed names the single clearing condition" 1 "$(grep -c 'until bin/index.sh rebuilds the graph' $tmp/reseed-orphan.err; true)"
check "reseed says the work was committed" 1 "$(grep -c 'the reseed committed' $tmp/reseed-orphan.err; true)"
check "the warning stays off stdout"      0 "$(grep -c dropped $tmp/reseed-orphan.log; true)"
check "stdout still carries the whole report" 2 "$(wc -l < $tmp/reseed-orphan.log | tr -d ' ')"
check "stdout line 1 is still the summary" "reparsed 1 of 1 files in indexer scope (1 tracked)" "$(sed -n 1p $tmp/reseed-orphan.log)"
check "the dropped symbol really left node" 0 "$(sqlq "SELECT count(*) FROM node WHERE name = 'Orphan'")"
"$index_sh" "$repo" "$tmp/verify.db" > /dev/null 2>&1 || abort "verification reindex"
check "a full index proves it still exists" app/zzz_orphan.rb "$(sqlite3 "$tmp/verify.db" "SELECT path FROM node WHERE name = 'Orphan'")"
check "until then the repo reads incomplete" graph-incomplete "$(field "$(status_row orphan)" 7)"
"$index_sh" "$repo" "$db" > /dev/null 2>&1 || abort "restore reindex"
check "the symbol returning clears the flag by itself" "" "$(field "$(status_row orphan)" 7)"

print -r -- "-- 16. a linked worktree keeps the repo name but follows its own tree"
linked=$tmp/linked
tgit worktree add -q -b probe "$linked" HEAD > /dev/null 2>&1 || abort "git worktree add"
theme seed "$db" "$repo" probe app/gamma.rb > /dev/null 2>&1 || abort "seed probe"
check "repo column comes from the main worktree" themetest "$(field "$("$theme_sh" status "$db" "$linked" probe | sed -n 2p)" 1)"
check "the linked worktree agrees it is fresh"   fresh     "$(field "$("$theme_sh" status "$db" "$linked" probe | sed -n 2p)" 3)"
print 'class Gamma; def only_here; end; end' > $linked/app/gamma.rb
check "an edit in the linked worktree is stale"  stale     "$(field "$("$theme_sh" status "$db" "$linked" probe | sed -n 2p)" 3)"
check "the main worktree is unaffected"          fresh     "$(field "$(status_row probe)" 3)"

env -u GIT_DIR -u GIT_WORK_TREE GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
  git -C "$linked" commit -qam "diverge the linked worktree" || abort "commit in linked worktree"
linked_head=$(env -u GIT_DIR -u GIT_WORK_TREE git -C "$linked" rev-parse HEAD)
check "the two HEADs really differ"              1 "$([[ $linked_head != $(tgit rev-parse HEAD) ]] && print 1 || print 0)"
theme reseed "$db" "$repo" probe > /dev/null 2>&1 || abort "reseed probe from main"
check "reseed from main stamps main HEAD"        "$(tgit rev-parse HEAD)" "$(stamped_sha probe)"

nodes_before=$(sqlq "SELECT count(*) FROM node")
theme reseed "$db" "$linked" probe > /dev/null 2> $tmp/linked-reseed.err
check "reseed from a linked worktree is refused" 1 "$?"
check "it says which worktree and why"           1 "$(grep -c 'is a linked worktree of' $tmp/linked-reseed.err; true)"
check "it wrote nothing to the graph"            "$nodes_before" "$(sqlq 'SELECT count(*) FROM node')"
check "the stamp still points at main HEAD"      "$(tgit rev-parse HEAD)" "$(stamped_sha probe)"
theme seed "$db" "$linked" wtseed app/gamma.rb > /dev/null 2> $tmp/linked-seed.err
check "seed from a linked worktree is refused"   1 "$?"
check "and created no theme"                     "" "$(sqlq "SELECT slug FROM theme WHERE slug = 'wtseed'")"

print -r -- "-- 17. slugless status covers every theme, including distinct shas"
rows=$("$theme_sh" status "$db" "$repo" | sed -n '2,$p')
check "one row per theme"                 "$(sqlq 'SELECT count(*) FROM theme')" "$(print -r -- "$rows" | wc -l | tr -d ' ')"
check "distinct shas are all reported"    "$(sqlq 'SELECT count(DISTINCT last_indexed_sha) FROM theme')" "$(print -r -- "$rows" | cut -f6 | sort -u | wc -l | tr -d ' ')"
print -r -- "$rows" > $tmp/slugless.tsv
mismatch=0
while IFS=$'\t' read -r r_repo r_slug r_state r_files r_changed r_sha r_reason; do
  one=$(field "$(status_row "$r_slug")" 3)
  if [[ $one != $r_state ]]; then
    mismatch=$(( mismatch + 1 ))
    print "        $r_slug: slugless=$r_state individually=$one"
  fi
done < $tmp/slugless.tsv
check "no verdict changes between a slugless and a single-slug run" 0 "$mismatch"

print -r -- "-- 18. a seeded file deleted and committed leaves no phantom symbol behind"
cat > $repo/app/doomed.rb <<'RB'
class Doomed
end
RB
commit_all "add a file that will be deleted" || abort "commit doomed"
"$index_sh" "$repo" "$db" > /dev/null 2>&1 || abort "reindex for the deletion case"
theme seed "$db" "$repo" doomed app/gamma.rb app/doomed.rb > /dev/null 2>&1 || abort "seed doomed"
check "the theme starts with both symbols" "Doomed,Gamma" "$(theme_symbols doomed)"
tgit rm -q app/doomed.rb && commit_all "delete the file" || abort "git rm doomed"
check "deleting a seeded file goes stale"  stale "$(field "$(status_row doomed)" 3)"
theme reseed "$db" "$repo" doomed > $tmp/reseed-doomed.log 2> $tmp/reseed-doomed.err
check "a deletion also signals exit 3"     3 "$?"
check "the deleted file leaves no node row" "" "$(sqlq "SELECT group_concat(name) FROM node WHERE path = 'app/doomed.rb'")"
check "the deleted symbol leaves theme_node" Gamma "$(theme_symbols doomed)"
check "reseed reports the vanished symbol" 1 "$(grep -c 'Doomed' $tmp/reseed-doomed.err; true)"
"$index_sh" "$repo" "$db" > /dev/null 2>&1 || abort "reindex after deletion"
check "a theme still listing a deleted file stays stale" stale "$(field "$(status_row doomed)" 3)"
theme seed "$db" "$repo" doomed app/gamma.rb > /dev/null 2>&1 || abort "re-seed doomed"
check "re-seeding without it returns fresh" fresh "$(field "$(status_row doomed)" 3)"

print -r -- "-- 19. a git mv of a seeded file is seen (renames off, and untracked-is-changed)"
commit_all "settle before rename tests" || abort "settle 19"
theme seed "$db" "$repo" moved app/gamma.rb > /dev/null 2>&1 || abort "seed moved"
check "starts fresh"                      fresh "$(field "$(status_row moved)" 3)"
tgit mv app/gamma.rb app/delta.rb && commit_all "git mv gamma" || abort "git mv"
row=$(status_row moved)
check "a clean git mv goes stale"         stale "$(field "$row" 3)"
check "and names one changed file"        1     "$(field "$row" 5)"
theme reseed "$db" "$repo" moved > $tmp/reseed-moved.log 2>/dev/null
check "reseed clears the moved-away path" "" "$(sqlq "SELECT group_concat(name) FROM node WHERE path = 'app/gamma.rb'")"
"$index_sh" "$repo" "$db" > /dev/null 2>&1 || abort "reindex after git mv"

print -r -- "-- 20. a case-only rename is seen too"
theme seed "$db" "$repo" cased app/delta.rb > /dev/null 2>&1 || abort "seed cased"
tgit mv app/delta.rb app/Delta.rb && commit_all "case-only rename" || abort "case rename"
check "a case-only rename goes stale"     stale "$(field "$(status_row cased)" 3)"

print -r -- "-- 21. a theme file that stops being tracked is re-checked"
commit_all "settle before untrack" || abort "settle 21"
theme seed "$db" "$repo" untrack app/alpha.rb > /dev/null 2>&1 || abort "seed untrack"
check "starts fresh"                      fresh "$(field "$(status_row untrack)" 3)"
tgit rm -q --cached app/alpha.rb > /dev/null && tgit commit -qm "untrack alpha" || abort "rm --cached"
check "untracking a seeded file goes stale" stale "$(field "$(status_row untrack)" 3)"
tgit add -f app/alpha.rb && commit_all "re-track alpha" || abort "re-add alpha"

print -r -- "-- 22. reseed refuses a dirty file set, so no worktree-only symbol is stamped"
commit_all "settle before dirty test" || abort "settle 22"
theme seed "$db" "$repo" dirty app/alpha.rb > /dev/null 2>&1 || abort "seed dirty"
print 'class AlphaGhost; end' >> $repo/app/alpha.rb
theme reseed "$db" "$repo" dirty > /dev/null 2> $tmp/dirty.err
check "reseed refuses uncommitted changes" 1 "$(print $?)"
check "it names the dirty file"            1 "$(grep -c 'uncommitted changes in: app/alpha.rb' $tmp/dirty.err; true)"
check "no ghost symbol entered the graph"  "" "$(sqlq "SELECT name FROM node WHERE name = 'AlphaGhost'")"
tgit checkout -- app/alpha.rb || abort "revert dirty"
check "after reverting, the theme is fresh and clean" fresh "$(field "$(status_row dirty)" 3)"

print -r -- "-- 23. an apostrophe in a path is escaped, not backslashed; in a slug it is refused"
printf "class Quoted\nend\n" > "$repo/app/it's_here.rb"
commit_all "add an apostrophe path" || abort "commit apostrophe"
"$index_sh" "$repo" "$db" > /dev/null 2>&1 || abort "reindex for apostrophe"
theme seed "$db" "$repo" quoted "app/it's_here.rb" > $tmp/quote.log 2>&1
check "seed survives an apostrophe in a path" 0 "$(print $?)"
check "and picked up its symbol"           Quoted "$(theme_symbols quoted)"
theme reseed "$db" "$repo" quoted > /dev/null 2>&1
check "reseed survives it too"             0 "$(print $?)"
theme seed "$db" "$repo" "it's" "app/it's_here.rb" > /dev/null 2> $tmp/oddslug.err
check "an apostrophe in a slug is refused"  1 "$(print $?)"
check "and no such theme was created"      0 "$(sqlq "SELECT count(*) FROM theme WHERE slug = \"it's\"")"

print -r -- "-- 24. one theme's reseed cannot silently gut another"
commit_all "settle before cross-theme test" || abort "settle 24"
"$index_sh" "$repo" "$db" > /dev/null 2>&1 || abort "reindex for cross-theme"
theme seed "$db" "$repo" owner_a app/aaa_shared.rb > /dev/null 2>&1 || abort "seed owner_a"
theme seed "$db" "$repo" owner_b app/zzz_shared.rb > /dev/null 2>&1 || abort "seed owner_b"
check "the symbol is in the graph to start" 1 "$(sqlq "SELECT count(*) FROM node WHERE name = 'Shared'")"
cat > $repo/app/aaa_shared.rb <<'RB'
module NotSharedAnyMore
end
RB
commit_all "drop the canonical declaration" || abort "commit cross-theme"
theme reseed "$db" "$repo" owner_a > /dev/null 2> $tmp/cross.err
check "reseeding owner_a empties the symbol from the graph" 0 "$(sqlq "SELECT count(*) FROM node WHERE name = 'Shared'")"
rm -f "$tmp/verify2.db" "$tmp/verify2.db-wal" "$tmp/verify2.db-shm"
"$index_sh" "$repo" "$tmp/verify2.db" > /dev/null 2>&1 || abort "cross-theme verification index"
check "even though a full parse still finds it" app/zzz_shared.rb "$(sqlite3 "$tmp/verify2.db" "SELECT path FROM node WHERE name = 'Shared'")"
check "the reseed says the whole repo is affected" 1 "$(grep -c 'every theme in themetest reads graph-incomplete' $tmp/cross.err; true)"
check "the untouched victim stops reading fresh" graph-incomplete "$(field "$(status_row owner_b)" 7)"
check "and so does an unrelated theme"    graph-incomplete "$(field "$(status_row ledger)" 7)"
"$index_sh" "$repo" "$db" > /dev/null 2>&1 || abort "repair reindex"
theme seed "$db" "$repo" owner_b app/zzz_shared.rb > /dev/null 2>&1 || abort "re-seed owner_b"
check "a full index restores the symbol"  app/zzz_shared.rb "$(sqlq "SELECT path FROM node WHERE name = 'Shared'")"
check "and clears the flag"               "" "$(field "$(status_row owner_b)" 7)"

print -r -- "-- 25. a repo with no commits is refused, not stamped with the string HEAD"
empty=$tmp/emptyrepo
mkdir -p $empty/app
printf 'class Unborn\nend\n' > $empty/app/unborn.rb
env -u GIT_DIR -u GIT_WORK_TREE GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
  git -C "$empty" init -q . && env -u GIT_DIR GIT_CONFIG_GLOBAL=/dev/null git -C "$empty" add -A
theme seed "$db" "$empty" unborn app/unborn.rb > /dev/null 2> $tmp/unborn.err
check "seed refuses a repo with no commits" 1 "$(print $?)"
check "it says there is nothing to stamp"   1 "$(grep -c 'no commits' $tmp/unborn.err; true)"
check "no literal HEAD was stamped"         "" "$(sqlq "SELECT slug FROM theme WHERE last_indexed_sha = 'HEAD'")"

print -r -- "-- 26. a hostile GIT_DIR cannot redirect the answer"
other=$tmp/otherrepo
mkdir -p $other/app
printf 'class Intruder\nend\n' > $other/app/intruder.rb
env -u GIT_DIR -u GIT_WORK_TREE GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
  git -C "$other" init -q . || abort "init other"
env -u GIT_DIR GIT_CONFIG_GLOBAL=/dev/null git -C "$other" config user.email a@b.c
env -u GIT_DIR GIT_CONFIG_GLOBAL=/dev/null git -C "$other" config user.name t
env -u GIT_DIR GIT_CONFIG_GLOBAL=/dev/null git -C "$other" add -A
env -u GIT_DIR GIT_CONFIG_GLOBAL=/dev/null git -C "$other" commit -qm other > /dev/null
hijacked=$(GIT_DIR=$other/.git GIT_WORK_TREE=$other "$theme_sh" status "$db" "$repo" ledger | sed -n 2p | cut -f1)
check "GIT_DIR does not change the repo column" themetest "$hijacked"

print -r -- "-- 27. the theme_node join is partitioned by repo"
sqlq "INSERT OR REPLACE INTO node(repo, name, path, line) VALUES ('otherrepo', 'IntruderSymbol', 'app/alpha.rb', 1)"
theme seed "$db" "$repo" partition app/alpha.rb > /dev/null 2>&1 || abort "seed partition"
check "a same-path row from another repo is excluded" "" "$(sqlq "SELECT group_concat(name) FROM theme_node tn JOIN theme t ON t.id=tn.theme_id WHERE t.slug='partition' AND tn.name='IntruderSymbol'")"
sqlq "DELETE FROM node WHERE repo = 'otherrepo'"

print -r -- "-- 28. re-seeding narrower drops the files it no longer covers"
theme seed "$db" "$repo" narrow app/alpha.rb app/beta.rb > /dev/null 2>&1 || abort "seed narrow wide"
check "starts with two files"             2 "$(theme_files narrow)"
theme seed "$db" "$repo" narrow app/alpha.rb > /dev/null 2>&1 || abort "seed narrow narrow"
check "re-seeding narrower drops the file" 1 "$(theme_files narrow)"
check "and drops its symbols"              Alpha "$(theme_symbols narrow)"

print -r -- "-- 29. reseed from an unknown or NULL stamp reparses everything"
theme seed "$db" "$repo" nullstamp app/beta.rb > /dev/null 2>&1 || abort "seed nullstamp"
sqlq "UPDATE theme SET last_indexed_sha = NULL WHERE slug = 'nullstamp'"
check "a NULL stamp reads never-indexed"  never-indexed "$(field "$(status_row nullstamp)" 7)"
theme reseed "$db" "$repo" nullstamp > $tmp/nullstamp.log 2>/dev/null
check "reseed reparses the whole theme"   "reparsed 1 of 1 files in indexer scope (1 tracked)" "$(sed -n 1p $tmp/nullstamp.log)"
check "and re-stamps it"                  "$(tgit rev-parse HEAD)" "$(stamped_sha nullstamp)"
check "so it reads fresh"                 fresh "$(field "$(status_row nullstamp)" 3)"

print -r -- "-- 30. an uncommitted deletion is refused like an uncommitted edit"
commit_all "settle before deletion refusal" || abort "settle 30"
"$index_sh" "$repo" "$db" > /dev/null 2>&1 || abort "reindex before 30"
theme seed "$db" "$repo" delguard app/beta.rb > /dev/null 2>&1 || abort "seed delguard"
nodes_before=$(sqlq "SELECT count(*) FROM node")
rm $repo/app/beta.rb
theme reseed "$db" "$repo" delguard > /dev/null 2> $tmp/delguard.err
check "an uncommitted rm is refused"       1 "$(print $?)"
check "it names the deleted file"          1 "$(grep -c 'uncommitted changes in: app/beta.rb' $tmp/delguard.err; true)"
check "and wrote nothing to the graph"     "$nodes_before" "$(sqlq 'SELECT count(*) FROM node')"
tgit checkout -- app/beta.rb || abort "restore beta"

print -r -- "-- 31. an unresolvable stamp drives reseed, not just status"
theme seed "$db" "$repo" badstamp app/beta.rb > /dev/null 2>&1 || abort "seed badstamp"
sqlq "UPDATE theme SET last_indexed_sha = 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeef' WHERE slug = 'badstamp'"
check "status blames the unknown sha"      unknown-sha "$(field "$(status_row badstamp)" 7)"
theme reseed "$db" "$repo" badstamp > $tmp/badstamp.log 2>/dev/null
check "reseed falls back to the whole theme" "reparsed 1 of 1 files in indexer scope (1 tracked)" "$(sed -n 1p $tmp/badstamp.log)"
check "and re-stamps to a real commit"     "$(tgit rev-parse HEAD)" "$(stamped_sha badstamp)"
check "so it reads fresh"                  fresh "$(field "$(status_row badstamp)" 3)"

print -r -- "-- 32. odd filenames survive the TSV and the indexer-scope gate"
printf 'class Cafe\nend\n' > "$repo/app/café.rb"
printf 'class Tabbed\nend\n' > "$repo/app/tab"$'\t'"name.rb"
commit_all "add odd filenames" || abort "commit odd names"
"$index_sh" "$repo" "$db" > /dev/null 2>&1 || abort "reindex odd names"
theme seed "$db" "$repo" oddnames "app/café.rb" > $tmp/odd.log 2>&1
check "a non-ASCII path is refused"        1 "$(print $?)"
check "because the indexer cannot read it" 1 "$(grep -c 'bin/index.sh cannot read' $tmp/odd.log; true)"
check "and no such theme was created"      0 "$(sqlq "SELECT count(*) FROM theme WHERE slug = 'oddnames'")"
theme seed "$db" "$repo" tabnames "app/tab"$'\t'"name.rb" > $tmp/tab.log 2>&1
check "a tab in a filename is refused, not silently mangled" 1 "$(print $?)"
check "and created no theme"               "" "$(sqlq "SELECT slug FROM theme WHERE slug = 'tabnames'")"
check "status still emits one row per theme" "$(sqlq 'SELECT count(*) FROM theme')" "$("$theme_sh" status "$db" "$repo" 2>/dev/null | sed -n '2,$p' | wc -l | tr -d ' ')"

print -r -- "-- 33. only a full rebuild clears graph-incomplete — seeding cannot"
commit_all "settle before escape test" || abort "settle 33"
"$index_sh" "$repo" "$db" > /dev/null 2>&1 || abort "reindex before 33"
cat > $repo/app/aaa_escape.rb <<'RB'
module Escapee
end
RB
cat > $repo/app/zzz_escape.rb <<'RB'
module Escapee
  def self.other_site; end
end
RB
commit_all "add a two-site symbol" || abort "commit escape files"
"$index_sh" "$repo" "$db" > /dev/null 2>&1 || abort "reindex escape"
theme seed "$db" "$repo" culprit app/aaa_escape.rb > /dev/null 2>&1 || abort "seed culprit"
theme seed "$db" "$repo" victim app/zzz_escape.rb > /dev/null 2>&1 || abort "seed victim"
cat > $repo/app/aaa_escape.rb <<'RB'
module NotEscapee
end
RB
commit_all "drop the canonical site" || abort "commit escape drop"
theme reseed "$db" "$repo" culprit > /dev/null 2>&1
theme reseed "$db" "$repo" culprit > /dev/null 2>&1
check "the flag is live before the seed"   graph-incomplete "$(field "$(status_row victim)" 7)"
check "and the symbol is really absent"    0 "$(sqlq "SELECT count(*) FROM node WHERE name = 'Escapee'")"
theme seed "$db" "$repo" culprit app/aaa_escape.rb > /dev/null 2>&1 || abort "seed culprit again"
check "seeding the culprit does not clear it" graph-incomplete "$(field "$(status_row victim)" 7)"
check "the symbol is still absent after it" 0 "$(sqlq "SELECT count(*) FROM node WHERE name = 'Escapee'")"
theme seed "$db" "$repo" victim app/zzz_escape.rb > /dev/null 2>&1 || abort "seed victim again"
check "nor does seeding the victim"        graph-incomplete "$(field "$(status_row victim)" 7)"
cat > $repo/app/zzz_escape.rb <<'RB'
module Escapee
  def self.other_site; end
  def self.third_site; end
end
RB
commit_all "re-declare the symbol elsewhere" || abort "commit re-declare"
theme reseed "$db" "$repo" victim > /dev/null 2>&1
check "a reseed puts the symbol back in the graph" 1 "$(sqlq "SELECT count(*) FROM node WHERE name = 'Escapee'")"
check "but a reseed still cannot clear the flag" graph-incomplete "$(field "$(status_row victim)" 7)"
"$index_sh" "$repo" "$db" > /dev/null 2>&1 || abort "repair escape"
check "a full index restores the symbol"   1 "$(sqlq "SELECT count(*) FROM node WHERE name = 'Escapee'")"
check "and that is what clears the flag"   "" "$(field "$(status_row victim)" 7)"

print -r -- "-- 34. a graph_health shape theme.sh did not write is refused, not misread"
check "the shape from schema.sql is accepted" 0 "$("$theme_sh" status "$db" "$repo" ledger > /dev/null 2>&1; print $?)"
sqlq "DROP TABLE IF EXISTS graph_health"
sqlq "CREATE TABLE graph_health (repo TEXT NOT NULL, reason TEXT NOT NULL, detail TEXT, PRIMARY KEY (repo, reason))"
sqlq "INSERT INTO graph_health VALUES ('themetest', 'drifted', 'a shape theme.sh never writes')"
theme status "$db" "$repo" ledger > /dev/null 2> $tmp/drift.err
check "a drifted shape is refused"         1 "$(print $?)"
check "it names the column it needs"       1 "$(grep -c 'expected column: symbol' $tmp/drift.err; true)"
check "and points at the schema's owner"   1 "$(grep -c 'check bin/schema.sql' $tmp/drift.err; true)"
check "it refused before printing a row"   0 "$("$theme_sh" status "$db" "$repo" ledger 2>/dev/null | wc -l | tr -d ' ')"
theme reseed "$db" "$repo" ledger > /dev/null 2> $tmp/drift-reseed.err
check "reseed refuses it the way status does" 1 "$(print $?)"
check "with the shaped message, not raw SQL"  1 "$(grep -c 'expected column: symbol' $tmp/drift-reseed.err; true)"
sqlq "DROP TABLE graph_health"
sqlite3 "$db" < "$schema_sql" > /dev/null 2>&1 || abort "restore schema"
check "the table really came back"          1 "$(sqlq "SELECT count(*) FROM pragma_table_info('graph_health') WHERE name = 'symbol'")"
check "restoring the schema's shape recovers" 0 "$("$theme_sh" status "$db" "$repo" ledger > /dev/null 2>&1; print $?)"

print -r -- "-- 35. a subdirectory is not a repo — it would seed a theme that can never go stale"
commit_all "settle before subdir test" || abort "settle 35"
for sub in app db; do
  theme status "$db" "$repo/$sub" > /dev/null 2> $tmp/sub-$sub.err
  check "status refuses the $sub/ subdirectory" 1 "$(print $?)"
  check "and says why"                      1 "$(grep -c 'not a worktree root' $tmp/sub-$sub.err; true)"
done
theme seed "$db" "$repo/app" subtheme alpha.rb > /dev/null 2>&1
check "seed refuses it too"                1 "$(print $?)"
check "no subdirectory theme was created"  0 "$(sqlq "SELECT count(*) FROM theme WHERE slug = 'subtheme'")"
check "the repo root still works"          0 "$("$theme_sh" status "$db" "$repo" ledger > /dev/null 2>&1; print $?)"

print -r -- "-- 36. a slug cannot forge a row in the TSV a hook parses"
rows_before=$("$theme_sh" status "$db" "$repo" 2>/dev/null | sed -n '2,$p' | wc -l | tr -d ' ')
theme seed "$db" "$repo" $'evil\nfresh\tfake' app/alpha.rb > /dev/null 2> $tmp/slug.err
check "a newline in a slug is refused"     1 "$(print $?)"
theme seed "$db" "$repo" $'ach\tpull' app/alpha.rb > /dev/null 2>&1
check "a tab in a slug is refused"         1 "$(print $?)"
check "it names the reason"                1 "$(grep -c 'unsafe slug' $tmp/slug.err; true)"
check "no extra theme rows exist"          "$rows_before" "$("$theme_sh" status "$db" "$repo" 2>/dev/null | sed -n '2,$p' | wc -l | tr -d ' ')"
check "every emitted row still has 7 fields" "" "$("$theme_sh" status "$db" "$repo" 2>/dev/null | awk -F'\t' 'NF != 7 { print "line " NR " has " NF }')"

print -r -- "-- 37. a resolvable non-hex stamp is unknown, not fresh"
commit_all "settle before non-hex stamp" || abort "settle 37"
theme seed "$db" "$repo" hexguard app/alpha.rb > /dev/null 2>&1 || abort "seed hexguard"
for rev in main HEAD; do
  sqlq "UPDATE theme SET last_indexed_sha = '$rev' WHERE slug = 'hexguard'"
  row=$(status_row hexguard)
  check "a stamp of '$rev' is stale"       stale       "$(field "$row" 3)"
  check "and reads unknown-sha"            unknown-sha "$(field "$row" 7)"
done

print -r -- "-- 38. a refused seed leaves no phantom theme row"
commit_all "settle before phantom test" || abort "settle 38"
rows_before=$(sqlq "SELECT count(*) FROM theme")
print '# dirty, uncommitted' >> $repo/app/beta.rb
theme seed "$db" "$repo" phantom app/beta.rb > /dev/null 2>&1
check "a refused seed exits 1"            1 "$(print $?)"
check "and creates no theme row"          "$rows_before" "$(sqlq 'SELECT count(*) FROM theme')"
check "so it cannot appear in status"     0 "$("$theme_sh" status "$db" "$repo" 2>/dev/null | grep -c 'phantom'; true)"
tgit checkout -- app/beta.rb || abort "restore beta"

print -r -- "-- 39. every indexer directory is exercised, not just app/"
mkdir -p $repo/lib $repo/backend
printf 'class LibSym\nend\n' > $repo/lib/lib_sym.rb
printf 'class BackendSym\nend\n' > $repo/backend/backend_sym.rb
commit_all "add lib and backend files" || abort "commit lib/backend"
"$index_sh" "$repo" "$db" > /dev/null 2>&1 || abort "reindex for scope breadth"
check "the indexer reaches lib/"          1 "$(sqlq "SELECT count(*) FROM node WHERE name = 'LibSym'")"
check "the indexer reaches backend/"      1 "$(sqlq "SELECT count(*) FROM node WHERE name = 'BackendSym'")"
theme seed "$db" "$repo" breadth lib/lib_sym.rb backend/backend_sym.rb > /dev/null 2>&1 || abort "seed breadth"
check "a theme spanning both is seeded"   "BackendSym,LibSym" "$(theme_symbols breadth)"
printf 'class LibSymRenamed\nend\n' > $repo/lib/lib_sym.rb
printf 'class BackendSymRenamed\nend\n' > $repo/backend/backend_sym.rb
commit_all "rename both" || abort "commit renames"
theme reseed "$db" "$repo" breadth > $tmp/breadth.log 2>/dev/null
check "reseed reparses both directories"  "reparsed 2 of 2 files in indexer scope (2 tracked)" "$(sed -n 1p $tmp/breadth.log)"
check "and picks up both renames"         "BackendSymRenamed,LibSymRenamed" "$(theme_symbols breadth)"
"$index_sh" "$repo" "$db" > /dev/null 2>&1 || abort "reindex after breadth"
theme seed "$db" "$repo" breadth lib/lib_sym.rb backend/backend_sym.rb > /dev/null 2>&1 || abort "clear breadth flag"

print -r -- "-- 40. an uncommitted rename is seen through the source path"
commit_all "settle before rename guard" || abort "settle 40"
theme seed "$db" "$repo" renameguard app/alpha.rb > /dev/null 2>&1 || abort "seed renameguard"
tgit mv app/alpha.rb app/alpha_moved.rb || abort "git mv"
row=$(status_row renameguard)
check "an uncommitted git mv reads stale" stale "$(field "$row" 3)"
theme reseed "$db" "$repo" renameguard > /dev/null 2> $tmp/mv.err
check "and reseed refuses to stamp it"    1 "$(print $?)"
check "naming the source path"            1 "$(grep -c 'app/alpha.rb' $tmp/mv.err; true)"
tgit mv app/alpha_moved.rb app/alpha.rb || abort "restore gamma"

print -r -- "-- 41. seed reads what it stamps, rather than trusting a stale graph"
commit_all "settle before stale-graph test" || abort "settle 41"
printf 'class StaleSym\nend\n' > $repo/app/stale.rb
commit_all "add stale.rb" || abort "commit stale.rb"
"$index_sh" "$repo" "$db" > /dev/null 2>&1 || abort "index at C0"
printf 'class StaleSymRenamed\nend\n' > $repo/app/stale.rb
commit_all "rename it without reindexing" || abort "commit C1"
check "the graph is behind the code"      StaleSym "$(sqlq "SELECT group_concat(name) FROM node WHERE path = 'app/stale.rb'")"
theme seed "$db" "$repo" staleseed app/stale.rb > /dev/null 2>&1 || abort "seed staleseed"
check "seed refreshed the graph itself"   StaleSymRenamed "$(sqlq "SELECT group_concat(name) FROM node WHERE path = 'app/stale.rb'")"
check "so the theme names what the code declares" StaleSymRenamed "$(theme_symbols staleseed)"

print -r -- "-- 42. a repo whose graph is empty is not fresh"
"$index_sh" "$repo" "$db" > /dev/null 2>&1 || abort "reindex before empty test"
theme seed "$db" "$repo" emptygraph app/stale.rb > /dev/null 2>&1 || abort "seed emptygraph"
check "it starts fresh"                   fresh "$(field "$(status_row emptygraph)" 3)"
sqlq "DELETE FROM node WHERE repo = 'themetest'"
row=$(status_row emptygraph)
check "an empty graph is not fresh"       stale "$(field "$row" 3)"
check "and says the graph is incomplete"  graph-incomplete "$(field "$row" 7)"
"$index_sh" "$repo" "$db" > /dev/null 2>&1 || abort "restore graph"

print -r -- "-- 43. a quoted path already in the db reads stale, not fresh"
commit_all "settle before db-borne test" || abort "settle 43"
printf 'class Cafe\nend\n' > "$repo/app/café.rb"
commit_all "add a non-ASCII path" || abort "commit café"
"$index_sh" "$repo" "$db" > /dev/null 2>&1 || abort "reindex for db-borne"
theme seed "$db" "$repo" dbborne app/alpha.rb > /dev/null 2>&1 || abort "seed dbborne"
sqlq "INSERT OR IGNORE INTO theme_file(theme_id, path) SELECT id, 'app/café.rb' FROM theme WHERE slug = 'dbborne'"
row=$(status_row dbborne)
check "a path the indexer cannot read is stale" stale "$(field "$row" 3)"
check "and is counted as changed"          1 "$(field "$row" 5)"
theme reseed "$db" "$repo" dbborne > /dev/null 2>&1
check "reseed cannot stamp it fresh"       stale "$(field "$(status_row dbborne)" 3)"

print ""
print "$pass passed, $fail failed"
(( fail == 0 ))
