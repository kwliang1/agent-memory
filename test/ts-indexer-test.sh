#!/bin/zsh
# The TypeScript half of the indexer, against a fixture tree whose every edge is known.
#
# Asserting on hydra alone cannot prove a NEGATIVE: "no edge for `import type`" is also
# what a parser that silently dropped the file produces, and six of hydra's files did
# exactly that before the shebang fix. So the fixture states both halves of every rule --
# the shape that must produce an edge sits next to the shape that must not, and the
# positive case is what proves the suite can tell them apart.
set -uo pipefail
here=${0:A:h}
repo=${here:h}
for need in bun sqlite3 git; do
  whence -p $need >/dev/null 2>&1 \
    || { print -u2 "$need is required for this suite and is not on PATH"; exit 1 }
done

pass=0; fail=0
check() {
  local what=$1 want=$2 got=$3
  if [[ $want == "$got" ]]; then print "ok    $what"; pass=$((pass+1))
  else print "FAIL  $what"; print "        want: $want"; print "        got:  $got"; fail=$((fail+1)); fi
}

# Eight fixture repos need the same preamble. GIT_CONFIG_GLOBAL=/dev/null keeps them off
# Kevin's signing key -- it never disables signing for a real repo -- and unsetting
# GIT_DIR stops an inherited one redirecting the fixture, the same hazard bin/index.sh:9
# and bin/graph-lib.zsh:11 already wrap git for.
gitinit() {
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
  # A failed `cd` leaves cwd in the checkout running this suite, where `git init .`
  # reinitialises it and the writes below land in its shared worktree config.
  if git rev-parse --git-dir >/dev/null 2>&1; then
    print -u2 "gitinit: refusing to init inside an existing repo: $PWD"
    exit 1
  fi
  git init -q "$@" . && git config user.email t@t && git config user.name t
}

# How many nodes in this repo match a name pattern. Written out four times before.
nodes_like() {
  sqlite3 -cmd '.timeout 2000' "$1" \
    "SELECT count(*) FROM node WHERE repo = '$2'${3:+ AND name LIKE '$3'}" 2>/dev/null
}

fx=$(mktemp -d) || exit 1
cleanup() { rm -rf "$fx" }
trap cleanup EXIT
trap 'cleanup; trap - INT;  kill -INT  $$' INT
trap 'cleanup; trap - TERM; kill -TERM $$' TERM

mkdir -p "$fx/src/deep" "$fx/src/pkg" "$fx/out"
: > "$fx/src/val.ts"
: > "$fx/src/types.ts"
printf "import { up } from '../..'\n" > "$fx/src/mixed.ts"
: > "$fx/src/dyn.ts"
: > "$fx/src/reexp.ts"
: > "$fx/src/retype.ts"
: > "$fx/src/deep/nested.ts"
: > "$fx/src/pkg/index.ts"
# Without a resolvable react.ts the synthesised require-calls are dropped as
# unresolvable, and the assertion below passes whether or not the dot filter exists.
: > "$fx/src/react.ts"
: > "$fx/index.ts"
: > "$fx/src/plain.ts"
printf "import { dbl } from './/val.js'\n" > "$fx/src/2fa.ts"
: > "$fx/src/_.ts"
mkdir -p "$fx/sub" "$fx/src/dir"
: > "$fx/src/dir.ts"
: > "$fx/src/dir/index.ts"
printf "import { q } from './dir/'\n" > "$fx/src/trail.ts"
: > "$fx/sub/m.mts"
: > "$fx/sub/c.cts"
: > "$fx/src/w2.tsx"

cat > "$fx/src/main.ts" <<'EOF'
import { a } from './val.js'
import { a2 } from './val.js'
import type { T } from './types.js'
import { type X, b } from './mixed.js'
import fs from 'fs'
import { z } from 'zod'
import './missing-entirely.js'
export { r } from './reexp.js'
export type { RT } from './retype.js'
const d = await import('./dyn.js')
import { n } from './deep/nested.js'
import { p } from './pkg'
import { rr } from '..'
import { ex } from './plain'
import { mm } from '../sub/m.mjs'
import { cc } from '../sub/c.cjs'
import { w2 } from './w2.jsx'
EOF

cat > "$fx/src/shebang.ts" <<'EOF'
#!/usr/bin/env bun
import { a } from './val.js'
EOF

cat > "$fx/src/self.ts" <<'EOF'
import { s } from './self.js'
EOF

cat > "$fx/src/session-lifecycle.ts" <<'EOF'
export * from './val.js'
export type * from './types.js'
const r = require('./reexp.js')
EOF

# The loader has to follow the extension. In tsx mode a generic arrow is an unclosed
# JSX tag; in ts mode JSX is a syntax error. Neither dialect parses both, and hydra has
# no .tsx at all, so only a fixture can hold this.
cat > "$fx/src/generic.ts" <<'EOF'
import { g } from './val.js'
export const chunk = <T>(xs: T[]): T[][] => [xs]
EOF

cat > "$fx/src/widget.tsx" <<'EOF'
import { v } from './val.js'
export const W = () => <div className="x">hi</div>
EOF

# scanImports throws on WARNINGS, not only syntax errors. This shape raises
# '"key" prop after a {...spread} is deprecated', which the catch cannot tell from a
# file that will not parse -- and a parse failure is now fatal.
cat > "$fx/src/spread.tsx" <<'EOF'
import { sp } from './val.js'
export const S = (p: any) => <div {...p} key={p.k}>x</div>
EOF

# A bare specifier is resolved against the IMPORTER's directory, so from a file at the
# repo root 'src/val.js' lands on src/val.ts -- a real indexed file. hydra reaches the
# same shape four times: daemon/factory.ts and three others import { promisify } from
# 'util' next to a real daemon/util.ts, so without the dot filter hydra itself gains
# four wrong edges. nova has 32 more ('zod', 'uuid', 'typesense').
cat > "$fx/root.ts" <<'EOF'
import { w } from 'src/val.js'
EOF

build() {
  # Clear first: a build that exits before writing would otherwise leave the previous
  # run's TSVs in place, and a stale read is indistinguishable from a pass.
  rm -f "$fx/out/graph-nodes.tsv" "$fx/out/graph-edges.tsv"
  ( cd "$fx" && GRAPH_OUT="$fx/out" bun run "$repo/bin/build-graph-ts.ts" "$@" >/dev/null 2>"$fx/err" )
}
files=(src/main.ts src/val.ts src/types.ts src/mixed.ts src/dyn.ts src/reexp.ts
       src/retype.ts src/deep/nested.ts src/pkg/index.ts src/shebang.ts src/self.ts
       src/generic.ts src/widget.tsx src/spread.tsx src/react.ts
       src/session-lifecycle.ts root.ts index.ts src/plain.ts src/2fa.ts src/_.ts
       sub/m.mts sub/c.cts src/w2.tsx src/dir.ts src/dir/index.ts src/trail.ts)
build $files || { print -u2 "ts-indexer-test: fixture build failed:"; cat "$fx/err"; exit 1 }

edges=$(<"$fx/out/graph-edges.tsv")
nodes=$(<"$fx/out/graph-nodes.tsv")
# One predicate. It was two helpers differing only in their source module, plus four
# copies inlined further down.
# The same two shapes, 21 and 6 times over. edge() above states the principle;
# this is the larger class it did not cover.
says()   { print -r -- "$1" | grep -q "$2" && print yes || print no }
counts() { print -r -- "$1" | grep -c "$2" || true }
edge() { print -r -- "$edges" | grep -qx "$1	$2	references" && print yes || print no }
has() { edge 'Src::Main' "$1" }

print -r -- "-- an import that exists at runtime is an edge"
check "value import"                   yes "$(has 'Src::Val')"
check "mixed type+value import"        yes "$(has 'Src::Mixed')"
check "re-export with a value"         yes "$(has 'Src::Reexp')"
check "dynamic import"                 yes "$(has 'Src::Dyn')"
check "nested relative path"           yes "$(has 'Src::Deep::Nested')"
check "directory resolving to index"   yes "$(has 'Src::Pkg::Index')"
# base is '' for a specifier that lands on the repo root, and '/index.ts' is absolute --
# it can never match a repo-relative key.
check "'..' resolving to the root"     yes "$(has 'Index')"
check "an extensionless relative path"  yes "$(has 'Src::Plain')"
# index.sh feeds .mts and .cts, so the swap table and EXTS must carry them.
check ".mjs resolves to .mts"           yes "$(has 'Sub::M')"
check ".cjs resolves to .cts"           yes "$(has 'Sub::C')"
check ".jsx resolves to .tsx"           yes "$(has 'Src::W2')"
# An empty segment from a doubled slash must be skipped, not treated as a directory.
check "a doubled slash still resolves"  yes "$(edge 'Src::_2fa' 'Src::Val')"
# './dir/' names a DIRECTORY. Resolving it to the sibling src/dir.ts is a wrong edge,
# not a missing one, which the header promises never happens.
check "a trailing slash means the dir"  yes "$(edge 'Src::Trail' 'Src::Dir::Index')"
check "and not the sibling file"        no  "$(edge 'Src::Trail' 'Src::Dir')"
# '../..' from src/ escapes ABOVE the repo root. Without the null return it normalises
# to '' and lands on the root module -- a wrong edge, not a missing one.
check "'../..' escapes, so no edge"     no  "$(edge 'Src::Mixed' 'Index')"

hasx() { edge 'Src::SessionLifecycle' "$1" }
check "export * from"                  yes "$(hasx 'Src::Val')"
check "relative require()"             yes "$(hasx 'Src::Reexp')"

print -r -- "-- an import that does not exist at runtime is not an edge"
# The whole point of parsing rather than grepping: './types.js' appears in the source
# exactly as './val.js' does, and only the `type` keyword separates them.
check "import type produces no edge"   no  "$(has 'Src::Types')"
check "export type from: no edge"      no  "$(has 'Src::Retype')"
check "export type * from: no edge"    no  "$(hasx 'Src::Types')"

print -r -- "-- external and unresolvable are dropped, never guessed"
check "unresolvable relative: no edge" 0 "$(print -r -- "$edges" | grep -ci 'missing' || true)"
check "bare spec hitting a real path"  no "$(edge 'Root' 'Src::Val')"
check "a file does not import itself"  no "$(edge 'Src::Self' 'Src::Self')"

# These four confirm each dialect yields its edge. The revert DETECTOR for this section
# is the build guard above: a parse failure is fatal, so a wrong loader aborts the whole
# fixture build naming the offending file, before any assertion here runs.
print -r -- "-- the loader follows the extension"
check ".ts with a generic arrow"       yes "$(edge 'Src::Generic' 'Src::Val')"
check ".tsx with JSX"                  yes "$(edge 'Src::Widget' 'Src::Val')"
check "a JSX warning is not a failure" yes "$(edge 'Src::Spread' 'Src::Val')"
# tsx mode synthesises `react` require-calls for JSX; they are bare, so the dot filter
# is what stops them becoming edges.
check "JSX does not import react"      0 "$(print -r -- "$edges" | grep -ci 'react' || true)"

print -r -- "-- shebang files still parse"
# hydra's daemon.ts, bridge.ts and cli/hydra.ts all start with one, and the transpiler
# rejects `#!`. Losing them silently cost 41 edges.
check "shebang file yields its edge"   yes "$(edge 'Src::Shebang' 'Src::Val')"

print -r -- "-- node naming"
check "named by full path, not base"   yes "$(print -r -- "$nodes" | grep -qx 'Src::Deep::Nested	src/deep/nested.ts	1' && print yes || print no)"
check "kebab-case becomes PascalCase"  Src::SessionLifecycle "$(print -r -- "$nodes" | awk -F'\t' '$2=="src/session-lifecycle.ts"{print $1}')"
# A leading digit would fail rank.sh's own constant regex, making the node unqueryable.
check "a leading digit is prefixed"     Src::_2fa "$(print -r -- "$nodes" | awk -F'\t' '$2=="src/2fa.ts"{print $1}')"
check "a segment with no alnum"         Src::_ "$(print -r -- "$nodes" | awk -F'\t' '$2=="src/_.ts"{print $1}')"

# (repo, name) is node's key, so two files answering to one name would lose a row to
# INSERT OR REPLACE and still report success.
mkdir -p "$fx/other"
cp "$fx/src/val.ts" "$fx/other/val.ts"
build src/val.ts other/val.ts >/dev/null 2>&1
check "distinct dirs do not collide"   0 "$?"
mkdir -p "$fx/dup"
cp "$fx/src/val.ts" "$fx/dup/va-l.ts"
cp "$fx/src/val.ts" "$fx/dup/va_l.ts"
build dup/va-l.ts dup/va_l.ts >/dev/null 2>&1
check "a real collision is refused"    1 "$?"
check "and it names both files"        yes "$(grep -q 'claimed by both' "$fx/err" && print yes || print no)"

# Folding a segment with no ASCII alphanumeric onto a constant makes every such file
# collide, which aborts the whole repo as unindexable. These call the parser directly:
# index.sh does not feed it a quoted path (see its comment), so the encoding guards a
# direct invocation and any future widening of that listing, not today's driver.
mkdir -p "$fx/locales"
: > "$fx/locales/日本語.ts"
: > "$fx/locales/한국어.ts"
: > "$fx/locales/日本語-ui.ts"
: > "$fx/locales/한국어-ui.ts"
build "locales/日本語.ts" "locales/한국어.ts" "locales/日本語-ui.ts" "locales/한국어-ui.ts" >/dev/null 2>&1; nacode=$?
check "non-ascii build succeeds"      0 "$nacode"
check "non-ascii names stay distinct" 4 "$(grep -c . "$fx/out/graph-nodes.tsv" 2>/dev/null || true)"

print -r -- "-- determinism (acceptance 2)"
# Unchecked, a build that CRASHES leaves the previous output in place and cmp compares
# a file to a copy of itself -- both determinism checks then pass on a broken indexer.
build $files || { print -u2 "determinism: forward build failed"; cat "$fx/err"; exit 1 }
cp "$fx/out/graph-edges.tsv" "$fx/fwd.tsv"; cp "$fx/out/graph-nodes.tsv" "$fx/fwdn.tsv"
build ${(Oa)files} || { print -u2 "determinism: reversed build failed"; cat "$fx/err"; exit 1 }
check "reversed input: same edges"     yes "$(cmp -s "$fx/fwd.tsv" "$fx/out/graph-edges.tsv" && print yes || print no)"
check "reversed input: same nodes"     yes "$(cmp -s "$fx/fwdn.tsv" "$fx/out/graph-nodes.tsv" && print yes || print no)"

print -r -- "-- every relative import is accounted for"
# relative = edges + unresolvable + self + duplicate. Nothing asserted the identity, so
# the duplicate counter could be deleted with the suite still green.
( cd "$fx" && GRAPH_OUT="$fx/out" bun run "$repo/bin/build-graph-ts.ts" $files >"$fx/stats.txt" 2>/dev/null )
statline=$(grep '^relative imports:' "$fx/stats.txt")
check "the reconciliation adds up"      yes "$(print -r -- "$statline" | awk -F'[:=+]' '{gsub(/[^0-9]/,"",$2); t=$2; s=0; for(i=3;i<=NF;i++){gsub(/[^0-9]/,"",$i); s+=$i} print (t==s)?"yes":"no"}')"
check "and counts a duplicate import"   yes "$(print -r -- "$statline" | grep -qE '[1-9][0-9]* duplicate' && print yes || print no)"

print -r -- "-- the fixture helper cannot reach a real repo"
# It already did: one `git init .` with cwd still in the checkout wrote core.worktree and
# user.email=t@t into /Users/kevin/agent-memory/.git/config, which every worktree shares.
escfx=$fx/escaperepo
mkdir -p "$escfx/inner"
( cd "$escfx" && gitinit ) >/dev/null 2>&1
escout=$( cd "$escfx/inner" && gitinit 2>&1 )
check "gitinit refuses inside a repo"   1 "$(counts "$escout" 'refusing to init inside an existing repo')"
check "and inits nothing where it ran"  0 "$( [[ -d "$escfx/inner/.git" ]] && print 1 || print 0 )"

print -r -- "-- index.sh dispatches on language"
# GIT_CONFIG_GLOBAL=/dev/null so the fixture commits without reaching for Kevin's
# signing key; this never turns signing off for a real repo.
gitfx=$fx/tsrepo
mkdir -p "$gitfx"
(
  cd "$gitfx"
  gitinit
  mkdir -p lib alt
  print 'import { q } from "./other.js"' > lib/thing.ts
  : > lib/other.ts
  : > alt/other.ts
  mkdir -p lib/__tests__ pkg/test node_modules
  : > node_modules/dep.ts
  print 'import { q } from "../thing.js"' > lib/__tests__/probe.ts
  print 'import { q } from "./thing.js"' > lib/thing.test.ts
  : > lib/types.d.ts
  : > pkg/test/helper.ts
  git add -A && git commit -qm fixture
) >/dev/null 2>&1 || { print -u2 "git fixture failed"; exit 1 }
out=$("$repo/bin/index.sh" "$gitfx" "$fx/ts.db" 2>&1)
check "a TS repo reports typescript"   yes "$(says "$out" 'typescript files')"
# 7 files on disk, 3 nodes: the __tests__ file, the .test.ts, the nested test/ one and
# the .d.ts are all excluded, the way spec/ is on the Ruby side. With them in they are
# extra nodes AND undirected bridges.
check "and loads its nodes"            3 "$(nodes_like "$fx/ts.db" tsrepo)"
check "__tests__ dir is excluded"      0 "$(nodes_like "$fx/ts.db" tsrepo '%Probe%')"
check "a .test.ts file is excluded"    0 "$(nodes_like "$fx/ts.db" tsrepo '%ThingTest%')"
# <pkg>/test/ is the monorepo shape; ^tests?/ anchored at the repo root missed 323
# nova files. .d.ts states types and no runtime dependency.
check "nested test/ dir is excluded"   0 "$(nodes_like "$fx/ts.db" tsrepo '%Helper%')"
check ".d.ts is excluded"              0 "$(nodes_like "$fx/ts.db" tsrepo '%Types%')"
# A vendored node_modules can be tracked; it is not this repo's code.
check "node_modules is excluded"       0 "$(nodes_like "$fx/ts.db" tsrepo '%Dep%')"
check "and its one edge"               1 "$(sqlite3 "$fx/ts.db" "select count(*) from edge where repo='tsrepo';" 2>/dev/null)"

# A TypeScript repo carrying one Ruby tooling script must not index as Ruby. "Ruby
# unless there is no Ruby" indexed that single file, emitted 0 edges and exited 0.
mixfx=$fx/mixrepo
mkdir -p "$mixfx"
(
  cd "$mixfx"
  gitinit
  mkdir -p lib
  print 'module Tooling; class Helper; end; end' > lib/tooling.rb
  print 'import { b } from "./b.js"' > a.ts
  : > b.ts
  git add -A && git commit -qm fixture
) >/dev/null 2>&1 || { print -u2 "mixed git fixture failed"; exit 1 }
mixout=$("$repo/bin/index.sh" "$mixfx" "$fx/mix.db" 2>&1)
# An exact tie has to go somewhere; it goes to Ruby.
tiefx=$fx/tierepo
mkdir -p "$tiefx"
(
  cd "$tiefx"
  gitinit
  mkdir -p lib
  print 'class One; end' > lib/one.rb
  print 'class Two; end' > lib/two.rb
  : > a.ts
  : > b.ts
  git add -A && git commit -qm fixture
) >/dev/null 2>&1 || { print -u2 "tie git fixture failed"; exit 1 }
tieout=$("$repo/bin/index.sh" "$tiefx" "$fx/tie.db" 2>&1)
check "a 2-2 tie goes to ruby"         yes "$(says "$tieout" '2 ruby files')"
check "one .rb does not win a TS repo" yes "$(says "$mixout" 'typescript files')"
check "and it says what it skipped"    yes "$(says "$mixout" 'skipped 1 file of')"
check "the TS edge is indexed"         1 "$(sqlite3 "$fx/mix.db" "select count(*) from edge where repo='mixrepo';" 2>/dev/null)"

# A file that does not parse contributes no edges, and the graph cannot tell that from
# a file that has none. Reverting the shebang strip cost hydra 41 edges and exited 0.
brokefx=$fx/brokerepo
mkdir -p "$brokefx"
(
  cd "$brokefx"
  gitinit
  print 'import {a} from "./b.js"' > a.ts; print 'function ((( {' >> a.ts
  : > b.ts
  git add -A && git commit -qm fixture
) >/dev/null 2>&1 || { print -u2 "broken git fixture failed"; exit 1 }
brokeout=$("$repo/bin/index.sh" "$brokefx" "$fx/broke.db" 2>&1); brokecode=$?
check "an unparseable file is fatal"    1 "$brokecode"
check "and nothing is loaded"          0 "$(sqlite3 "$fx/broke.db" "select count(*) from node where repo='brokerepo';" 2>/dev/null || print 0)"

# Counting .rb only under app/lib/backend against .ts anywhere sent a Rails engines
# layout to the TypeScript parser. venture has 4,842 .rb outside those three dirs.
engfx=$fx/engrepo
mkdir -p "$engfx"
(
  cd "$engfx"
  gitinit
  mkdir -p engines/billing/app/models
  print 'class Invoice; end' > engines/billing/app/models/invoice.rb
  print 'class Charge; end' > engines/billing/app/models/charge.rb
  : > tool.ts
  git add -A && git commit -qm fixture
) >/dev/null 2>&1 || { print -u2 "engines git fixture failed"; exit 1 }
engout=$("$repo/bin/index.sh" "$engfx" "$fx/eng.db" 2>&1); engcode=$?
check "engines layout is not TS"       no "$(says "$engout" 'typescript files')"
check "and it refuses, explaining"     yes "$(says "$engout" 'none are under app/lib/backend')"
check "and exits non-zero"             1 "$engcode"
# Deleting only this guard's `exit 1` left all three checks green: index.sh ran Prism
# with no files and died later on "no nodes produced". Assert it stops HERE.
check "engines guard stops there"      0 "$(print -r -- "$engout" | grep -cE 'no nodes produced|parameter not set' || true)"

# An exact node name beats a ::suffix match elsewhere. Losing that preference sent the
# seed to the wrong repo, which is what the deny guard used to get wrong.
sqlite3 "$fx/pref.db" < "$repo/bin/schema.sql" >/dev/null 2>&1
sqlite3 "$fx/pref.db" "insert into node(repo,name,path,line) values
  ('zzz','Widget','w.ts',1),('zzz','Gadget','g.ts',1),('aaa','Ns::Widget','n.ts',1);
  insert into edge(src,dst,repo,kind) values('Widget','Gadget','zzz','references');" 2>/dev/null
# With two exacts the verdict is ambiguous either way, so what the narrowing changes is
# the candidate LIST: the suffix match must not be offered alongside them.
sqlite3 "$fx/pref.db" "insert into node(repo,name,path,line) values('aaa','Widget','w2.ts',1);" 2>/dev/null
prefamb=$("$repo/bin/rank.sh" "$fx/pref.db" Widget 2 3 2>&1)
check "two exacts are ambiguous"        1 "$("$repo/bin/rank.sh" "$fx/pref.db" Widget 2 3 >/dev/null 2>&1; print $?)"
check "and only exacts are listed"     0 "$(counts "$prefamb" 'Ns::Widget')"

print -r -- "-- the file list index.sh feeds the parser"
# index.sh PINS core.quotePath=true rather than inheriting it. bin/theme.sh pins it too
# and refuses to seed a concept over a path outside that listing, so a repo config
# setting it false widened one layer and not the other -- a theme that can never be
# stamped fresh, reached through configuration rather than code.
hostfx=$fx/hostilerepo
mkdir -p "$hostfx/src"
(
  cd "$hostfx"
  gitinit
  git config core.quotePath false
  : > "src/café.ts"
  : > src/plain.ts
  : > src/other.ts
  git add -A && git commit -qm fixture
) >/dev/null 2>&1 || { print -u2 "hostile git fixture failed"; exit 1 }
"$repo/bin/index.sh" "$hostfx" "$fx/host.db" >/dev/null 2>&1
check "a hostile config is ignored"    2 "$(nodes_like "$fx/host.db" hostilerepo)"


# An unresolved merge lists a conflicted path once per stage, which inflated the count
# and read as a module claiming its own name twice.
conffx=$fx/confrepo
mkdir -p "$conffx"
(
  cd "$conffx"
  gitinit -b main
  : > b.ts
  print 'import { z } from "./b.js"' > a.ts
  git add -A && git commit -qm base
  git checkout -q -b side && print 'import { z } from "./b.js" // side' > a.ts
  git commit -qam side
  git checkout -q main && print 'import { z } from "./b.js" // main' > a.ts
  git commit -qam main
  git merge -q side
) >/dev/null 2>&1
# This git runs outside the fixture subshell, so an inherited GIT_DIR would point it
# at the wrong repo -- the same reason bin/index.sh:9 wraps every git call.
check "a conflicted path is listed 3x"  3 "$(cd "$conffx" && env -u GIT_DIR -u GIT_WORK_TREE git ls-files | grep -c '^a.ts$')"
confout=$("$repo/bin/index.sh" "$conffx" "$fx/conf.db" 2>&1)
# It still fails -- a conflicted file carries <<<<<<< markers and does not parse --
# but on the honest reason. Without --deduplicate the error was "'A' is claimed by
# both a.ts and a.ts", which sends you looking for a naming bug that isn't there.
check "the error is not a self-collision" 0 "$(counts "$confout" 'claimed by both')"
check "it names the unparseable file"    yes "$(says "$confout" 'could not parse a.ts')"

# git ls-files reports INDEX entries. A cone sparse checkout, or a file removed without
# git rm, names a path that is not on disk -- that is not a parse failure, and treating
# it as one made a sparse monorepo unindexable.
gonefx=$fx/gonerepo
mkdir -p "$gonefx"
(
  cd "$gonefx"
  gitinit
  print 'import { k } from "./k.js"' > a.ts
  : > k.ts
  : > spare.ts
  git add -A && git commit -qm fixture
  rm spare.ts
) >/dev/null 2>&1 || { print -u2 "gone git fixture failed"; exit 1 }
goneout=$("$repo/bin/index.sh" "$gonefx" "$fx/gone.db" 2>&1); gonecode=$?
# Unreadable is not the same as absent: the file is there and its edges are invisible,
# which is exactly what the fatal rule is for.
noperm=$fx/npermrepo
mkdir -p "$noperm"
(
  cd "$noperm"
  gitinit
  print 'import { k } from "./k.js"' > a.ts
  : > k.ts
  git add -A && git commit -qm fixture
  chmod 000 k.ts
) >/dev/null 2>&1 || { print -u2 "noperm fixture failed"; exit 1 }
npout=$("$repo/bin/index.sh" "$noperm" "$fx/np.db" 2>&1); npcode=$?
chmod 644 "$noperm/k.ts" 2>/dev/null
check "an unreadable file is fatal"     1 "$npcode"
check "and is not called not-on-disk"   0 "$(counts "$npout" 'not on disk')"
check "a missing file is not fatal"    0 "$gonecode"
check "and names the file it skipped"  yes "$(says "$goneout" 'not on disk, skipped: spare.ts')"
# index.sh discards the child's stdout, so the aggregate count has to be on stderr.
check "and the count is reported"      yes "$(says "$goneout" '1 file(s) not on disk')"
check "and the rest still indexes"     1 "$(sqlite3 "$fx/gone.db" "select count(*) from edge where repo='gonerepo';" 2>/dev/null)"

print -r -- "-- rank.sh resolves the name a person would type"
# A module node is named for its whole path, so the bare name has to resolve or nothing
# a person types ever matches. Ambiguity is refused rather than guessed at: alt/other.ts
# and lib/other.ts both answer to a bare `Other`.
check "a unique bare suffix resolves"  Lib::Other "$(RANK_FORMAT=tsv "$repo/bin/rank.sh" "$fx/ts.db" Thing 2 5 2>/dev/null | awk -F'\t' 'NR==1{print $1}')"
check "the full name resolves too"     Lib::Other "$(RANK_FORMAT=tsv "$repo/bin/rank.sh" "$fx/ts.db" Lib::Thing 2 5 2>/dev/null | awk -F'\t' 'NR==1{print $1}')"
amb=$("$repo/bin/rank.sh" "$fx/ts.db" Other 2 5 2>&1); ambcode=$?
check "an ambiguous bare name fails"   1 "$ambcode"
check "and it lists the candidates"    2 "$(counts "$amb" 'Other  (tsrepo)')"
# The exit code alone is also what 'no seed resolved' produces, so assert the advice.
# Same repo, so naming it in full is what helps.
check "and says to name it in full"     yes "$(says "$amb" 'give the full name')"
# Without the exit here the run continues to 'no seed resolved', which exits 1 too -- so
# the exit-code check above passes on the wrong guard.
check "and ambiguity stops there"       0 "$(counts "$amb" 'no seed resolved')"
# ${#seeds} counts occurrences, so a repeated ambiguous seed read as "not the whole
# question" and gave no advice at all.
dup=$("$repo/bin/rank.sh" "$fx/ts.db" 'Other,Other' 2 5 tsrepo 2>&1)
check "a repeated seed still advises" yes "$(says "$dup" 'give the full name')"
nomatch=$("$repo/bin/rank.sh" "$fx/ts.db" NoSuchModule 2 5 2>&1); nomatchcode=$?
# One bad seed must not abort a multi-seed call: match.sh hands over a whole concept's
# symbols, and an "ambiguous" abort collapsed the ach_pull block from 8 rows to 2.
multi=$(RANK_FORMAT=tsv "$repo/bin/rank.sh" "$fx/ts.db" 'Thing,Other' 2 5 tsrepo 2>/dev/null); multicode=$?
check "one bad seed does not abort"    0 "$multicode"
check "and the good seed still answers" Lib::Other "$(print -r -- "$multi" | awk -F'\t' 'NR==1{print $1}')"
check "a missing qualified seed drops"  0 "$("$repo/bin/rank.sh" "$fx/ts.db" 'Lib::Thing,Lib::Gone' 2 5 tsrepo >/dev/null 2>&1; print $?)"
check "a name that matches nothing"    1 "$nomatchcode"
# Without the guard, zsh's own "parameter not set" also exits 1 — assert the message.
check "and says no seed resolved"      yes "$(says "$nomatch" 'no seed resolved')"
# Both fixtures in one db: answering a cross-repo seed set out of whichever repo came
# first is the bug this whole resolution pass exists to stop.
"$repo/bin/index.sh" "$mixfx" "$fx/ts.db" >/dev/null 2>&1
spanned=$("$repo/bin/rank.sh" "$fx/ts.db" 'Thing,A' 2 5 2>&1); spancode=$?
check "seeds spanning repos refused"   1 "$spancode"
check "and it names both repos"        yes "$(says "$spanned" 'span repos')"
# One name in two repos. The batched exact pass must not answer from whichever came
# first, and an explicit repo must filter it rather than being skipped in the fast path.
sqlite3 "$fx/ts.db" "insert into node(repo,name,path,line) values('mixrepo','Lib::Other','x.ts',1);" 2>/dev/null
dupname=$("$repo/bin/rank.sh" "$fx/ts.db" 'Lib::Other' 2 5 2>&1); dupcode=$?
check "one name in two repos: refused"  1 "$dupcode"
check "and says to pass the repo"       yes "$(says "$dupname" 'pass the repo')"
check "an explicit repo filters it"     0 "$("$repo/bin/rank.sh" "$fx/ts.db" 'Lib::Other' 2 5 mixrepo >/dev/null 2>&1; print $?)"
# A name present in only ONE repo, asked for in another: the batched fast path must
# apply the filter, not resolve it and then traverse the wrong repo to silence.
check "the fast path filters too"      1 "$("$repo/bin/rank.sh" "$fx/ts.db" 'Lib::Thing' 2 5 mixrepo >/dev/null 2>&1; print $?)"
# $repo now comes from the db and reaches rank.sql's sed substitution, where '|' is
# the delimiter and '&' expands to the match. index.sh validates repo names it writes;
# a db written by anything else has not been through that.
cp "$fx/ts.db" "$fx/evil.db"
sqlite3 "$fx/evil.db" "insert into node(repo,name,path,line) values('a&b','Evil','x.ts',1);" 2>/dev/null
check "an unsafe db repo is refused"   1 "$("$repo/bin/rank.sh" "$fx/evil.db" Evil 2 5 >/dev/null 2>&1; print $?)"
argout=$("$repo/bin/rank.sh" "$fx/ts.db" Thing 2 5 'a&b' 2>&1); argcode=$?
check "an unsafe repo ARGUMENT too"    1 "$argcode"
# The exit code alone is also what an unresolvable repo filter produces downstream, so
# the message is the assertion that does the work.
check "and names the repo unsafe"      yes "$(says "$argout" 'unsafe repo name')"
# Without the exit the value reached the SQL filter and then rank.sql's sed, where '&'
# expands to the match. The downstream guard still exits 1, so only this discriminates.
check "and stops before the db"        0 "$(counts "$argout" 'no node named')"

print -r -- "-- rank-regression's own guards"
# The target is matched literally. As a BRE, 'Lib::Othe.' matches Lib::Other and the
# want passes on a symbol the case never named.
printf 'Lib::Thing\twant\tLib::Othe.\ta regex metachar must be literal\n' > "$fx/bogus5.tsv"
check "a metachar target is literal"   1 "$("$repo/test/rank-regression.sh" "$fx/ts.db" 10 "$fx/bogus5.tsv" >/dev/null 2>&1; print $?)"
# A `deny` naming a symbol that is no node anywhere passes without asserting anything:
# rename the target and the case silently stops discriminating. Same for a `want` whose
# seed resolves to nothing.
printf 'Lib::Thing\tdeny\tNoSuchNodeAnywhere\tbogus target\n' > "$fx/bogus.tsv"
bogus=$("$repo/test/rank-regression.sh" "$fx/ts.db" 10 "$fx/bogus.tsv" 2>&1); boguscode=$?
check "a deny on a non-node fails"     1 "$boguscode"
check "and says the target is no node" yes "$(says "$bogus" 'no node by that name')"
printf 'Alt::Other\twant\tWhatever\tresolves but has no neighbours\n' > "$fx/bogus3.tsv"
bogus3=$("$repo/test/rank-regression.sh" "$fx/ts.db" 10 "$fx/bogus3.tsv" 2>&1)
# Alt::Other is a real node with no edges, so rank.sh exits 0 with no rows. Reporting
# that as "did not resolve" sends you to re-index a repo that is already indexed.
check "a neighbourless seed says so"    yes "$(says "$bogus3" 'no neighbours')"
printf 'NoSuchSeed\twant\tWhatever\tbogus seed\n' > "$fx/bogus2.tsv"
bogus2b=$("$repo/test/rank-regression.sh" "$fx/ts.db" 10 "$fx/bogus2.tsv" 2>&1); bogus2code=$?
check "an unresolvable seed says why"   yes "$(says "$bogus2b" 'no node named')"
# The message was asserted and the verdict was not, so flipping the counter left every
# assertion green while the real corpus passed 25/0 with hydra absent.
check "and a dead seed fails the RUN"   1 "$bogus2code"
check "a want on a dead seed says so" yes "$(says "$bogus2b" 'asserts nothing')"
# A corpus that runs no cases at all must not score green.
: > "$fx/empty.tsv"
# mixrepo owns A; tsrepo owns Lib::Thing. An unscoped target count let the wrong repo's
# node satisfy the deny, re-arming the hole this guard closes.
printf 'Lib::Thing\tdeny\tA\ttarget lives in the other repo\n' > "$fx/bogus4.tsv"
bogus4=$("$repo/test/rank-regression.sh" "$fx/ts.db" 10 "$fx/bogus4.tsv" 2>&1)
check "a cross-repo deny target fails" yes "$(says "$bogus4" 'no node by that name')"
check "an empty corpus fails"           1 "$("$repo/test/rank-regression.sh" "$fx/ts.db" 10 "$fx/empty.tsv" >/dev/null 2>&1; print $?)"
check "a missing corpus fails"          1 "$("$repo/test/rank-regression.sh" "$fx/ts.db" 10 "$fx/nope.tsv" >/dev/null 2>&1; print $?)"
# A repo with neither must not report success, and must not report the wrong language.
emptyfx=$fx/emptyrepo
mkdir -p "$emptyfx"
(
  cd "$emptyfx"
  gitinit
  print hello > README.md && git add -A && git commit -qm fixture
) >/dev/null 2>&1 || { print -u2 "empty git fixture failed"; exit 1 }
emptyout=$("$repo/bin/index.sh" "$emptyfx" "$fx/empty.db" 2>&1); emptycode=$?
check "a repo with neither fails"      1 "$emptycode"
# The exit code alone is also what a downstream no-files error produces, so assert
# the message: naming which languages were looked for is the guard's whole value.
check "and says what it looked for"    yes "$(says "$emptyout" 'nothing to index')"
check "and stops at its own guard"     0 "$(print -r -- "$emptyout" | grep -cE 'no nodes produced|parameter not set' || true)"

print "\n$pass passed, $fail failed"
[ $fail -eq 0 ]
