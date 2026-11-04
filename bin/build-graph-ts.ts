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

import { readFileSync } from 'node:fs';
import { EXTS, loadWorkspaces, resolveAlias, resolveRelative, resolveWorkspace } from './ts-resolve';
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

const files = process.argv.slice(2);
if (!files.length) { console.error('build-graph-ts: no files given'); process.exit(1); }

const indexed = new Set(files);
const workspaces = loadWorkspaces(
  (process.env.GRAPH_MANIFESTS ?? '').split('\n').filter(Boolean).sort());
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
const parser = (file: string) => file.endsWith('.tsx') ? tsx : ts;

const edges = new Set<string>();

const resolveSpec = (from: string, spec: string): string | null => spec.startsWith('.')
  ? resolveRelative(from, spec, indexed)
  : resolveAlias(from, spec, indexed) ?? resolveWorkspace(spec, workspaces, indexed);

// A barrel re-exports its siblings by name (services/index.ts: `export * as transfer from
// './transfer'`). Callers import the barrel, so the module they use gets an edge too.
type Reexport = { spec: string; name: string | null };
const reexports = new Map<string, Map<string, Reexport>>();
const declared = new Map<string, Set<string>>();
function barrel(file: string): Map<string, Reexport> {
  let names = reexports.get(file);
  if (names) return names;
  names = new Map();
  reexports.set(file, names);
  const text = source(file);
  let own: string[] = [];
  try { own = parser(file).scan(text).exports; } catch { /* a parse failure is reported by the main loop */ }
  const mine = new Set(own);
  declared.set(file, mine);
  for (const [local, entry] of bindings(text, 'export')) names.set(local, entry);
  const imported = bindings(text, 'import');
  for (const m of text.matchAll(/^export\s*\{([^}]*)\}(?!\s*from)/gm)) {
    for (const [local, exported] of specifiers(m[1])) {
      const entry = imported.get(local);
      if (entry) names.set(exported, entry);
    }
  }
  for (const m of text.matchAll(/^export\s*\*\s*from\s+['"]([^'"]+)['"]/gm)) {
    const inner = resolveSpec(file, m[1]);
    if (inner === null) continue;
    for (const name of exportsOf(inner)) {
      if (name !== 'default' && !mine.has(name)) names.set(name, { spec: m[1], name });
    }
  }
  return names;
}

function source(file: string): string {
  try { return readFileSync(file, 'utf8'); } catch { return ''; /* not on disk: reported by the main loop */ }
}

function exportsOf(file: string): string[] {
  const names = barrel(file);
  return [...declared.get(file)!, ...names.keys()];
}

function specifiers(list: string): [string, string][] {
  return list.replace(/\/\*[\s\S]*?\*\/|\/\/[^\n]*/g, '').split(',')
    .map(part => part.trim().split(/\s+as\s+/))
    .filter(([name, local = name]) => /^\w+$/.test(name) && /^\w+$/.test(local))
    .map(([name, local = name]) => [name, local]);
}

function bindings(text: string, kw: 'import' | 'export'): Map<string, Reexport> {
  const found = new Map<string, Reexport>();
  for (const m of text.matchAll(new RegExp(String.raw`^${kw}\s*\*\s*as\s+(\w+)\s+from\s+['"]([^'"]+)['"]`, 'gm'))) found.set(m[1], { spec: m[2], name: null });
  for (const m of text.matchAll(new RegExp(String.raw`^${kw}\s*\{([^}]*)\}\s*from\s+['"]([^'"]+)['"]`, 'gm'))) {
    for (const [name, local] of specifiers(m[1])) found.set(local, { spec: m[2], name });
  }
  return found;
}

function usedThrough(text: string, spec: string): string[][] {
  const used = new Set<string>();
  for (const [local, { spec: from, name }] of bindings(text, 'import')) {
    if (from !== spec) continue;
    if (name !== null) used.add(name);
    for (const u of text.matchAll(new RegExp(String.raw`\b${local}((?:\s*\.\s*\w+)+)`, 'g'))) {
      const chain = u[1].replace(/\s+/g, '');
      used.add(name === null ? chain.slice(1) : name + chain);
    }
  }
  return [...used].sort().map(chain => chain.split('.'));
}
let relative = 0, aliased = 0, barrelled = 0, external = 0, unresolved = 0, selfref = 0, duplicate = 0;
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
    imports = parser(f).scanImports(text);
  } catch (e) {
    console.error(`build-graph-ts: could not parse ${f}: ${(e as Error).message}`);
    failed++;
    continue;
  }
  const src = moduleName(f);
  for (const imp of imports) {
    const target = resolveSpec(f, imp.path);
    if (imp.path.startsWith('.')) relative++;
    else if (target === null) { external++; continue; }
    else aliased++;
    if (target === null) { unresolved++; continue; }
    if (target === f) { selfref++; continue; }
    const edge = `${src}\t${moduleName(target)}\treferences`;
    // Set.add is idempotent, so this branch is a counter rather than a guard -- it is
    // what makes the reconciliation below add up.
    if (edges.has(edge)) { duplicate++; } else { edges.add(edge); }
    const names = barrel(target);
    if (!names.size) continue;
    for (const chain of usedThrough(text, imp.path)) {
      let at = target, i = 0, name = chain[0];
      const visited = new Set<string>();
      while (!visited.has(`${at}\t${name}`)) {
        visited.add(`${at}\t${name}`);
        const entry = barrel(at).get(name);
        if (entry === undefined) break;
        const inner = resolveSpec(at, entry.spec);
        if (inner === null || inner === f) break;
        const via = `${src}\t${moduleName(inner)}\treferences`;
        if (!edges.has(via)) { edges.add(via); barrelled++; }
        at = inner;
        // A named re-export lands on the symbol, not a namespace: chase the symbol itself.
        if (entry.name !== null) { name = entry.name; continue; }
        if (++i === chain.length) break;
        name = chain[i];
      }
    }
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
// arrived in. Resolution reads `indexed` as a set, so nothing else carries order, except
// an `export *` cycle, whose names depend on which barrel is read first.
const nodeLines = [...nodes.entries()].map(([n, f]) => `${n}\t${f}\t1`).sort();
const edgeLines = [...edges].sort();
await Bun.write(`${out}/graph-nodes.tsv`, nodeLines.map(l => l + '\n').join(''));
await Bun.write(`${out}/graph-edges.tsv`, edgeLines.map(l => l + '\n').join(''));

console.log(`nodes (modules):  ${nodeLines.length}`);
console.log(`edges (resolved): ${edgeLines.length}`);
console.log(`local imports: ${relative} relative + ${aliased} aliased + ${barrelled} through barrels = ${edgeLines.length} edges + ${unresolved} ` +
            `unresolvable + ${selfref} self + ${duplicate} duplicate`);
console.log(`external (dropped): ${external}`);
// stderr: index.sh discards this child's stdout, and the per-file lines above already
// go there. On stdout the count was the one thing the operator could not see.
if (missing) console.error(`build-graph-ts: ${missing} file(s) not on disk, skipped`);
