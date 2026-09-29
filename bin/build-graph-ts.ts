// TypeScript half of the indexer. Reads a file list on argv (paths relative to cwd,
// which must be the repo root) and writes the same two TSVs build-graph.rb does:
// $GRAPH_OUT/graph-nodes.tsv and $GRAPH_OUT/graph-edges.tsv.
//
// A node is a MODULE, not a declaration. TypeScript has no global namespace, and 13
// export names in hydra are carried by 32 declarations -- buildWorktreePromptAppend is
// declared outright in both daemon/session-lifecycle.ts and daemon/engines/claude-engine.ts.
// node's key is (repo, name), so bare export names would have collapsed 32 declarations
// into 13 rows via INSERT OR REPLACE. Module paths are unique by construction.
//
// Parsing is Bun.Transpiler, not a regex: a regex cannot tell `import type {A}` from
// `import {a}`, and hydra has 128 type-only imports that must not become runtime edges.
// The globally installed typescript is 7.0.2, the native port, which ships no
// createSourceFile -- and a module node needs no declaration positions anyway.

const EXTS = ['.ts', '.tsx', '.mts', '.cts'];
const stripExt = (f: string): string => {
  for (const e of EXTS) if (f.endsWith(e)) return f.slice(0, -e.length);
  return f;
};

const pascal = (s: string): string => {
  // index.sh pins core.quotePath=true, so a non-ASCII path never reaches here through it.
  // This guards a direct invocation and any future widening of that listing.
  // Encode non-ASCII RUNS in place. Splitting on non-alphanumerics deletes them, so
  // 日本語-ui and 한국어-ui both reduce to Ui and the collision check refuses the whole
  // repo. Six hex digits per codepoint, so no two non-ASCII runs encode alike; a file
  // literally named U0065e5Z.ts would still collide, and the guard below catches it.
  const encoded = s.replace(/[^\x00-\x7F]+/gu, m =>
    'U' + [...m].map(c => c.codePointAt(0)!.toString(16).padStart(6, '0')).join('') + 'Z');
  const w = encoded.split(/[^A-Za-z0-9]+/).filter(Boolean)
    .map(x => x[0].toUpperCase() + x.slice(1)).join('');
  if (!w) return '_';
  return /^[0-9]/.test(w) ? '_' + w : w;
};

// Every segment, not just the basename: daemon/commands/review.ts and
// protocols/review.ts both end in Review, and a basename key loses one of them.
const moduleName = (file: string): string =>
  stripExt(file).split('/').map(pascal).join('::');

// hydra writes the runtime specifier in TS source -- 431 of the 431 relative imports it
// indexes say './config.js' for a config.ts on disk -- so the extension is swapped back.
// Resolution only ever answers with a file already in the index; an unresolvable
// specifier is dropped, never guessed at, the same way the Ruby half drops its 11,917
// unresolvable references.
function resolveSpecifier(
  fromFile: string, spec: string, indexed: ReadonlySet<string>,
): string | null {
  const dir = fromFile.includes('/') ? fromFile.slice(0, fromFile.lastIndexOf('/')) : '';
  const stack: string[] = [];
  for (const p of (dir ? dir + '/' + spec : spec).split('/')) {
    if (p === '.' || p === '') continue;
    if (p === '..') { if (!stack.length) return null; stack.pop(); continue; }
    stack.push(p);
  }
  const base = stack.join('/');
  const swap: Record<string, string[]> = {
    '.js': ['.ts', '.tsx'], '.jsx': ['.tsx'], '.mjs': ['.mts'], '.cjs': ['.cts'],
  };
  // '.', '..', or a trailing '/', '/.' or '/..' names a DIRECTORY, so only its index can
  // answer. Without this the normalisation drops the trailing segment and base+ext wins,
  // pointing './dir/' at a sibling src/dir.ts -- a wrong edge, not a missing one.
  const dirOnly = /^\.\.?$/.test(spec) || /\/(\.\.?)?$/.test(spec);
  const candidates: string[] = [];
  if (!dirOnly) {
    candidates.push(base);
    const m = base.match(/\.(js|jsx|mjs|cjs)$/);
    if (m) {
      const stem = base.slice(0, -m[0].length);
      for (const e of swap[m[0]] ?? []) candidates.push(stem + e);
    }
    for (const e of EXTS) candidates.push(base + e);
  }
  // base is '' for a specifier that resolves to the repo root, and '/index.ts' is
  // absolute -- it can never match a repo-relative key. `import '..'` from a top-level
  // directory is the reachable case.
  for (const e of EXTS) candidates.push(base ? base + '/index' + e : 'index' + e);
  for (const c of candidates) if (indexed.has(c)) return c;
  return null;
}

const files = process.argv.slice(2);
if (!files.length) { console.error('build-graph-ts: no files given'); process.exit(1); }

const indexed = new Set(files);
const nodes = new Map<string, string>();
for (const f of files) {
  const n = moduleName(f);
  const prior = nodes.get(n);
  if (prior !== undefined) {
    console.error(`build-graph-ts: '${n}' is claimed by both ${prior} and ${f}`);
    process.exit(1);
  }
  nodes.set(n, f);
}

// One transpiler per dialect, chosen by extension. In tsx mode `<T>(x: T) => x` is an
// unclosed JSX tag, so a single tsx transpiler fails every .ts file carrying a generic
// arrow -- 59 files in nova. In ts mode JSX is a syntax error. Neither parses both, and
// hydra has no .tsx at all, so nothing there would have shown it.
//
// jsx:react because scanImports throws on WARNINGS too, not only syntax errors: four
// nova files raise `"key" prop after a {...spread} is deprecated`, and the catch below
// cannot tell that from a file that genuinely will not parse.
const tsx = new Bun.Transpiler({
  loader: 'tsx', tsconfig: '{"compilerOptions":{"jsx":"react"}}',
});
const ts = new Bun.Transpiler({ loader: 'ts' });

const edges = new Set<string>();
let relative = 0, external = 0, unresolved = 0, selfref = 0, duplicate = 0;
let failed = 0, missing = 0;

for (const f of files) {
  let text;
  try {
    // The transpiler rejects `#!`, and the six hydra files carrying one are its entry
    // points -- daemon.ts, bridge.ts, cli/hydra.ts. Dropping them silently cost 41 edges.
    text = (await Bun.file(f).text()).replace(/^#![^\n]*/, '');
  } catch (e) {
    // git ls-files reports INDEX entries, so a cone sparse checkout or a file removed
    // without git rm names a path that is not on disk. That one is safe to skip, and
    // refusing the repo for it makes a sparse monorepo unindexable.
    if ((e as { code?: string }).code === 'ENOENT') {
      console.error(`build-graph-ts: not on disk, skipped: ${f}`);
      missing++;
      continue;
    }
    // Anything else -- a permission denied, a path that is a directory -- is a file that
    // IS there and whose edges we cannot see. That is the case the fatal rule is for.
    console.error(`build-graph-ts: could not read ${f}: ${(e as Error).message}`);
    failed++;
    continue;
  }
  let imports;
  try {
    imports = (f.endsWith('.tsx') ? tsx : ts).scanImports(text);
  } catch (e) {
    console.error(`build-graph-ts: could not parse ${f}: ${(e as Error).message}`);
    failed++;
    continue;
  }
  const src = moduleName(f);
  for (const imp of imports) {
    // Bare specifiers never become edges. Resolution alone is not enough: it runs
    // against the IMPORTER's directory, so 'src/val.js' from a root-level file lands on
    // a real src/val.ts. JSX also makes the transpiler synthesise `react` require-calls,
    // which would become edges in any repo that happens to contain a react.ts.
    if (!imp.path.startsWith('.')) { external++; continue; }
    relative++;
    const target = resolveSpecifier(f, imp.path, indexed);
    if (target === null) { unresolved++; continue; }
    if (target === f) { selfref++; continue; }
    const edge = `${src}\t${moduleName(target)}\treferences`;
    // Set.add is idempotent, so this branch is a counter rather than a guard -- it is
    // what makes the reconciliation below add up.
    if (edges.has(edge)) { duplicate++; continue; }
    edges.add(edge);
  }
}

// A file that did not parse contributes no edges, and the graph cannot tell that from a
// file that has none. Reverting the shebang strip cost hydra 41 edges and still exited
// 0; index.sh discards this stdout, so only a non-zero status is actually read.
// A file that was never on disk is reported and skipped instead -- see above.
if (failed) {
  console.error(`build-graph-ts: ${failed} file(s) could not be parsed or read — refusing ` +
                `to write a graph that is silently missing their edges`);
  process.exit(1);
}

const out = process.env.GRAPH_OUT ?? '/tmp';
// Sorted and deduped, so the output is a function of the file SET and not the order it
// arrived in. Resolution reads `indexed` as a set, so nothing else carries order.
const nodeLines = [...nodes.entries()].map(([n, f]) => `${n}\t${f}\t1`).sort();
const edgeLines = [...edges].sort();
await Bun.write(`${out}/graph-nodes.tsv`, nodeLines.map(l => l + '\n').join(''));
await Bun.write(`${out}/graph-edges.tsv`, edgeLines.map(l => l + '\n').join(''));

console.log(`nodes (modules):  ${nodeLines.length}`);
console.log(`edges (resolved): ${edgeLines.length}`);
console.log(`relative imports: ${relative} = ${edgeLines.length} edges + ${unresolved} ` +
            `unresolvable + ${selfref} self + ${duplicate} duplicate`);
console.log(`external (dropped): ${external}`);
// stderr: index.sh discards this child's stdout, and the per-file lines above already
// go there. On stdout the count was the one thing the operator could not see.
if (missing) console.error(`build-graph-ts: ${missing} file(s) not on disk, skipped`);
