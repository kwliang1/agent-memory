import { existsSync, readFileSync } from 'node:fs';

export const EXTS = ['.ts', '.tsx', '.mts', '.cts'];

export function normalize(path: string): string | null {
  const stack: string[] = [];
  for (const p of path.split('/')) {
    if (p === '.' || p === '') continue;
    if (p === '..') { if (!stack.length) return null; stack.pop(); continue; }
    stack.push(p);
  }
  return stack.join('/');
}

const dirOf = (f: string): string => (f.includes('/') ? f.slice(0, f.lastIndexOf('/')) : '');
const join = (dir: string, rest: string): string => (dir ? dir + '/' + rest : rest);

function probe(spec: string, base: string, indexed: ReadonlySet<string>): string | null {
  const swap: Record<string, string[]> = {
    '.js': ['.ts', '.tsx'], '.jsx': ['.tsx'], '.mjs': ['.mts'], '.cjs': ['.cts'],
  };
  // A trailing slash or dot segment names a directory: only its index may answer.
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
  for (const e of EXTS) candidates.push(base ? base + '/index' + e : 'index' + e);
  for (const c of candidates) if (indexed.has(c)) return c;
  return null;
}

export function resolveRelative(
  fromFile: string, spec: string, indexed: ReadonlySet<string>,
): string | null {
  const base = normalize(join(dirOf(fromFile), spec));
  return base === null ? null : probe(spec, base, indexed);
}

type Aliases = { baseUrl: string | null; paths: [string, string[]][] };
const NO_ALIASES: Aliases = { baseUrl: null, paths: [] };

// Not Bun.JSONC: index.sh runs the indexed repo's pinned bun, and 1.2.x has none.
export function stripJsonc(text: string): string {
  const tokens = text.replace(/^\uFEFF/, '').match(/"(?:[^"\\]|\\.)*"|\/\/[^\n]*|\/\*[\s\S]*?\*\/|[\s\S]/g) ?? [];
  const kept = tokens.filter(t => !t.startsWith('//') && !t.startsWith('/*'));
  return kept.filter((t, i) => {
    if (t !== ',') return true;
    let j = i + 1;
    while (j < kept.length && /^\s$/.test(kept[j])) j++;
    const next = kept[j];
    return next !== '}' && next !== ']';
  }).join('');
}

function readJsonc(file: string): any {
  try { return JSON.parse(stripJsonc(readFileSync(file, 'utf8'))); } catch (e) {
    throw new Error(`could not parse ${file}: ${(e as Error).message}`);
  }
}

// Only a relative extends: a clean index tree has no node_modules to resolve a package one.
function loadTsconfig(file: string, seen: ReadonlySet<string> = new Set()): Aliases {
  const cfg = readJsonc(file);
  if (!cfg || seen.has(file)) return NO_ALIASES;
  const dir = dirOf(file);
  const opts = cfg.compilerOptions ?? {};
  const ext = typeof cfg.extends === 'string' && cfg.extends.startsWith('.')
    ? normalize(join(dir, cfg.extends.endsWith('.json') ? cfg.extends : cfg.extends + '.json'))
    : null;
  const parent = ext !== null && existsSync(ext) ? loadTsconfig(ext, new Set([...seen, file])) : NO_ALIASES;
  const baseUrl = typeof opts.baseUrl === 'string' ? normalize(join(dir, opts.baseUrl)) : parent.baseUrl;
  const paths: [string, string[]][] = opts.paths && typeof opts.paths === 'object'
    ? Object.entries(opts.paths as Record<string, unknown>)
        .filter((e): e is [string, string[]] => Array.isArray(e[1]))
        .map(([k, v]) => [k, v.filter(t => typeof t === 'string').map(t => join(baseUrl ?? dir, t))])
    : parent.paths;
  return { baseUrl, paths };
}

const aliasesByDir = new Map<string, Aliases>();
function aliasesFor(dir: string): Aliases {
  const hit = aliasesByDir.get(dir);
  if (hit) return hit;
  const cfg = join(dir, 'tsconfig.json');
  const found = existsSync(cfg) ? loadTsconfig(cfg) : dir ? aliasesFor(dirOf(dir)) : NO_ALIASES;
  aliasesByDir.set(dir, found);
  return found;
}

function starMatch(pattern: string, s: string): string | null {
  const star = pattern.indexOf('*');
  if (star < 0) return s === pattern ? '' : null;
  const pre = pattern.slice(0, star), post = pattern.slice(star + 1);
  return s.length >= pre.length + post.length && s.startsWith(pre) && s.endsWith(post)
    ? s.slice(pre.length, s.length - post.length)
    : null;
}

export function resolveAlias(
  fromFile: string, spec: string, indexed: ReadonlySet<string>,
): string | null {
  const { baseUrl, paths } = aliasesFor(dirOf(fromFile));
  let best: { prefix: number; targets: string[] } | null = null;
  for (const [pattern, targets] of paths) {
    const hole = starMatch(pattern, spec);
    if (hole === null) continue;
    const prefix = pattern.includes('*') ? pattern.indexOf('*') : pattern.length;
    if (!best || prefix > best.prefix) best = { prefix, targets: targets.map(t => t.replace('*', hole)) };
  }
  const bases = [...(best?.targets ?? []), ...(baseUrl === null ? [] : [join(baseUrl, spec)])];
  for (const t of bases) {
    const base = normalize(t);
    const r = base === null ? null : probe(spec, base, indexed);
    if (r) return r;
  }
  return null;
}

export type Workspace = { name: string; dir: string; manifest: any };

// A name claimed twice (nova has five packages named cdk8s) resolves to neither.
export function loadWorkspaces(manifests: readonly string[]): Workspace[] {
  const all = manifests
    .filter(m => existsSync(m))
    .map(m => ({ m, manifest: readJsonc(m) }))
    .filter(({ manifest }) => typeof manifest?.name === 'string')
    .map(({ m, manifest }) => ({ name: manifest.name as string, dir: dirOf(m), manifest }));
  const claims = new Map<string, number>();
  for (const w of all) claims.set(w.name, (claims.get(w.name) ?? 0) + 1);
  return all
    .filter(w => claims.get(w.name) === 1)
    .sort((a, b) => b.name.length - a.name.length || (a.name < b.name ? -1 : a.name > b.name ? 1 : 0));
}

function exportTarget(value: unknown): string | null {
  if (typeof value === 'string') return value;
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  for (const cond of ['import', 'default', 'require', 'types']) {
    const t = exportTarget((value as Record<string, unknown>)[cond]);
    if (t) return t;
  }
  return null;
}

// exports name build output: dist/{esm,cjs,types}/x.js is tried as src/x.ts, then x.ts.
function sourceCandidates(target: string): string[] {
  const rel = normalize(target.replace(/\.d\.(ts|mts|cts)$/, '.js'));
  if (!rel) return [];
  const m = rel.match(/^(?:dist|build|cjs|esm)\/(?:(?:esm|cjs|types)\/)?(.*)$/);
  return m ? [join('src', m[1]), m[1]] : [rel];
}

function exportTargets(exp: Record<string, unknown>, sub: string): string[] {
  const direct = exportTarget(exp[sub]);
  if (direct) return [direct];
  const wild = Object.keys(exp)
    .filter(k => k.includes('*') && starMatch(k, sub) !== null)
    .sort((a, b) => b.indexOf('*') - a.indexOf('*') || (a < b ? -1 : 1))[0];
  const t = wild === undefined ? null : exportTarget(exp[wild]);
  return t === null ? [] : [t.replace('*', starMatch(wild!, sub)!)];
}

export function resolveWorkspace(
  spec: string, workspaces: readonly Workspace[], indexed: ReadonlySet<string>,
): string | null {
  const ws = workspaces.find(w => spec === w.name || spec.startsWith(w.name + '/'));
  if (!ws) return null;
  const sub = spec === ws.name ? '.' : '.' + spec.slice(ws.name.length);
  const exp = ws.manifest.exports;
  let targets: string[];
  if (exp && typeof exp === 'object' && !Array.isArray(exp) && Object.keys(exp).some(k => k.startsWith('.'))) {
    targets = exportTargets(exp, sub);
  } else if (sub === '.') {
    const main = exportTarget(exp) ?? exportTarget(ws.manifest.main) ?? exportTarget(ws.manifest.types);
    targets = [...(main === null ? [] : [main]), './src/index', './index'];
  } else {
    targets = [sub, './src/' + sub.slice(2)];
  }
  for (const t of targets) {
    for (const c of sourceCandidates(t)) {
      const r = probe(c, join(ws.dir, c), indexed);
      if (r) return r;
    }
  }
  return null;
}
