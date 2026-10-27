#!/usr/bin/env node
// zheref/hatsu#247 item 1: the Node dependency audit, as contracts/scans.json ->
// dependencyAudit.node (hatsu.scans/v0.2) declares it. hanten section 2a runs it.
// zheref/hatsu#507 adds the bun text lockfile (bun.lock) and bunfig.toml evidence.
//
// NO PACKAGE MANAGER IS EVER EXECUTED, and nothing of this process's environment
// reaches anything: running pnpm, yarn, npm or bun inside the tree under review runs
// that tree's hooks, honours its registry and expands its tokens. Instead:
//
//   1. `packageManager` selects the manager (only where it is absent does the one
//      lockfile present select it); the manager names the lockfile and its format.
//   2. The lockfile is PARSED STRICTLY: a line the parser does not read, a truncated
//      file or entry, or a registry-shaped entry that does not parse is NOT SCANNED,
//      never skipped. Each entry is a registry package (no URL, or one on the
//      contract's `registryHosts`), local (workspace, link, directory), or unqueried
//      (git, a tarball elsewhere, file:).
//   3. Every registry package@version is posted to the contract's OSV querybatch
//      endpoint and each returned id is read at its vuln endpoint for its severity;
//      a severity outside `severityLevels` is UNRATED, which counts.
//   4. Redirect and suppression keys, and another manager's lockfile beside the
//      selected one, are printed as `audit-config:` evidence, never honoured.
//
// Output: `resolved:` first, then `audit-config:`, `local:`, `unqueried:`, and with
// --query `finding:` / `below-floor:` per id and one `audit:` line. Tree-derived
// strings are JSON-quoted. THE EXIT CODE DECIDES:
//   0  resolved (no --query); or queried with no finding at or above the floor and
//      no unqueried entry
//   1  --query: a finding at or above the floor, an UNRATED id, or any unqueried
//      entry -- evidence for Feitan, never clean
//   2  wiring: arguments, the contract, or an internal error; stderr only, nothing
//      on stdout
//   3  NOT SCANNED, ending on one `not scanned: <reason>` line
//
// Usage: node scripts/dependency_audit_resolve.mts <path> [--stack <id>] [--scans <file>] [--query]
import { lstatSync, readFileSync, statSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

type Format = 'pnpm-lock' | 'yarn-lock' | 'npm-lock' | 'bun-lock';
const FORMATS: readonly string[] = ['pnpm-lock', 'yarn-lock', 'npm-lock', 'bun-lock'];
interface Manager { readonly lockfiles: readonly string[]; readonly format: Format; readonly markers?: { readonly berry: RegExp; readonly classic: RegExp } }
interface NodeRow {
  readonly stacks: readonly string[];
  readonly endpoint: URL;
  readonly vulnEndpoint: URL;
  readonly ecosystem: string;
  readonly severityLevels: readonly string[];
  readonly severityFloor: readonly string[];
  readonly timeoutSeconds: number;
  readonly maxResponseBytes: number;
  readonly maxEntries: number;
  readonly maxDepth: number;
  readonly registryHosts: readonly string[];
  readonly managers: Record<string, Manager>;
  readonly unsupportedLockfiles: Record<string, string>;
  readonly auditConfigKeys: Record<string, readonly string[]>;
}
interface Pkg { readonly name: string; readonly version: string }
type Entry = { readonly kind: 'registry'; readonly pkg: Pkg } | { readonly kind: 'local' } | { readonly kind: 'unqueried' };

class NotScanned extends Error {}
class Tooling extends Error {}
const q = (value: string): string => JSON.stringify(value);
const out = (line: string): void => { process.stdout.write(`${line}\n`); };
function tooling(message: string): never { throw new Tooling(message); }
function notScanned(reason: string): never { throw new NotScanned(reason); }

function parseArgs(argv: readonly string[]): { repo: string; scans: string; stack?: string; query: boolean } {
  let repo: string | undefined;
  let stack: string | undefined;
  let scans = fileURLToPath(new URL('../contracts/scans.json', import.meta.url));
  let query = false;
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--query') query = true;
    else if (arg === '--scans' || arg === '--stack') {
      const value = argv[i + 1];
      if (!value || value.startsWith('--')) tooling(`${arg} needs a value`);
      if (arg === '--scans') scans = value;
      else if (!/^[a-z0-9][a-z0-9._-]{0,63}$/.test(value)) tooling('--stack takes a stack id ([a-z0-9._-])');
      else stack = value;
      i += 1;
    } else if (arg.startsWith('--')) tooling(`unknown flag ${arg}`);
    else if (repo === undefined) repo = arg;
    else tooling('expected exactly one <path>');
  }
  if (repo === undefined) tooling('usage: dependency_audit_resolve.mts <path> [--stack <id>] [--scans <file>] [--query]');
  return { repo: resolve(repo), scans: resolve(scans), stack, query };
}

// --- the contract: required keys checked, optional keys defaulted when absent and
// refused when malformed, unknown keys refused (exit 2) ----------------------------
const ROW_KEYS = new Set(['stacks', 'run', 'runSemantics', 'endpoint', 'vulnEndpoint', 'ecosystem', 'severityLevels', 'severityFloor',
  'timeoutSeconds', 'maxResponseBytes', 'maxEntries', 'maxDepth', 'registryHosts', 'resolution', 'managers', 'unsupportedLockfiles',
  'auditConfigKeys', 'failure']);
const MANAGER_KEYS = new Set(['lockfiles', 'format', 'lockfileMarkers']);
const DEFAULTS = { maxResponseBytes: 33554432, maxEntries: 500000, maxDepth: 1000 };
const isRecord = (v: unknown): v is Record<string, unknown> => !!v && typeof v === 'object' && !Array.isArray(v);
const isStrings = (v: unknown): v is string[] => Array.isArray(v) && v.length > 0 && v.every((s) => typeof s === 'string' && s !== '');
const own = (v: Record<string, unknown>): Array<[string, unknown]> => Object.entries(v).filter(([k]) => !k.startsWith('$'));

function endpointUrl(value: unknown, key: string): URL {
  let url: URL;
  try {
    url = new URL(String(value));
  } catch {
    tooling(`dependencyAudit.node.${key} is not a URL`);
  }
  const loopback = ['127.0.0.1', 'localhost', '[::1]'].includes(url.hostname);
  if (url.protocol !== 'https:' && !(url.protocol === 'http:' && loopback)) tooling(`dependencyAudit.node.${key} must be https (http only on loopback, for a fixture)`);
  return url;
}
function positive(row: Record<string, unknown>, key: keyof typeof DEFAULTS): number {
  if (!(key in row)) return DEFAULTS[key];
  const v = row[key];
  if (!Number.isSafeInteger(v) || (v as number) < 1) tooling(`dependencyAudit.node.${key} must be an integer >= 1`);
  return v as number;
}
function compile(source: unknown, where: string): RegExp {
  if (typeof source !== 'string' || source === '') tooling(`${where} must be a non-empty regular expression string`);
  try {
    return new RegExp(source, 'm');
  } catch {
    tooling(`${where} is not a valid regular expression`);
  }
}

function loadRow(path: string): NodeRow {
  let data: unknown;
  try {
    data = JSON.parse(readFileSync(path, 'utf8'));
  } catch {
    tooling(`cannot read the scans contract ${path}`);
  }
  const row = (data as { dependencyAudit?: { node?: unknown } } | null)?.dependencyAudit?.node;
  if (!isRecord(row)) tooling(`${path} has no dependencyAudit.node object`);
  for (const [key] of own(row)) if (!ROW_KEYS.has(key)) tooling(`dependencyAudit.node.${key} is not a key this resolver reads`);
  if (!isStrings(row.stacks)) tooling('dependencyAudit.node.stacks must be a non-empty string array');
  if (typeof row.ecosystem !== 'string' || row.ecosystem === '') tooling('dependencyAudit.node.ecosystem must be a string');
  if (!isStrings(row.severityLevels)) tooling('dependencyAudit.node.severityLevels must be a non-empty string array');
  if (!isStrings(row.severityFloor)) tooling('dependencyAudit.node.severityFloor must be a non-empty string array');
  const levels = row.severityLevels.map((s) => s.toUpperCase());
  const floor = row.severityFloor.map((s) => s.toUpperCase());
  if (!floor.every((s) => levels.includes(s))) tooling('dependencyAudit.node.severityFloor must be drawn from severityLevels');
  if (!Number.isSafeInteger(row.timeoutSeconds) || (row.timeoutSeconds as number) < 1) tooling('dependencyAudit.node.timeoutSeconds must be an integer >= 1');
  if (!isStrings(row.registryHosts) || !row.registryHosts.every((h) => /^[a-z0-9.-]+$/.test(h))) tooling('dependencyAudit.node.registryHosts must be a non-empty array of host names');
  if (!isRecord(row.managers) || own(row.managers).length === 0) tooling('dependencyAudit.node.managers must be a non-empty object');
  const managers: Record<string, Manager> = {};
  for (const [name, value] of own(row.managers)) {
    const where = `dependencyAudit.node.managers.${name}`;
    if (!isRecord(value)) tooling(`${where} must be an object`);
    for (const [key] of own(value)) if (!MANAGER_KEYS.has(key)) tooling(`${where}.${key} is not a key this resolver reads`);
    if (!isStrings(value.lockfiles) || !FORMATS.includes(String(value.format))) {
      tooling(`${where} needs lockfiles and a format of ${FORMATS.join(', ')}`);
    }
    let markers: Manager['markers'];
    if (value.format === 'yarn-lock') {
      if (!isRecord(value.lockfileMarkers)) tooling(`${where}.lockfileMarkers must be an object`);
      markers = { berry: compile(value.lockfileMarkers.berry, `${where}.lockfileMarkers.berry`), classic: compile(value.lockfileMarkers.classic, `${where}.lockfileMarkers.classic`) };
    } else if ('lockfileMarkers' in value) tooling(`${where}.lockfileMarkers belongs to a yarn-lock manager only`);
    managers[name] = { lockfiles: value.lockfiles, format: value.format as Format, markers };
  }
  let unsupported: Record<string, string> = {};
  if ('unsupportedLockfiles' in row) {
    if (!isRecord(row.unsupportedLockfiles) || !own(row.unsupportedLockfiles).every(([, v]) => typeof v === 'string' && v !== '')) {
      tooling('dependencyAudit.node.unsupportedLockfiles must be an object of lockfile -> manager name strings');
    }
    unsupported = Object.fromEntries(own(row.unsupportedLockfiles)) as Record<string, string>;
  }
  let config: Record<string, string[]> = {};
  if ('auditConfigKeys' in row) {
    if (!isRecord(row.auditConfigKeys) || !own(row.auditConfigKeys).every(([, v]) => isStrings(v))) {
      tooling('dependencyAudit.node.auditConfigKeys must be an object of file -> non-empty string arrays');
    }
    config = Object.fromEntries(own(row.auditConfigKeys)) as Record<string, string[]>;
  }
  return {
    stacks: row.stacks,
    endpoint: endpointUrl(row.endpoint, 'endpoint'),
    vulnEndpoint: endpointUrl(row.vulnEndpoint, 'vulnEndpoint'),
    ecosystem: row.ecosystem,
    severityLevels: levels,
    severityFloor: floor,
    timeoutSeconds: row.timeoutSeconds as number,
    maxResponseBytes: positive(row, 'maxResponseBytes'),
    maxEntries: positive(row, 'maxEntries'),
    maxDepth: positive(row, 'maxDepth'),
    registryHosts: row.registryHosts,
    managers,
    unsupportedLockfiles: unsupported,
    auditConfigKeys: config,
  };
}

// --- reading the tree -------------------------------------------------------------
// A file directly in the root, read only when it is a regular file and not a symlink.
function readRegular(repo: string, file: string): { text?: string; refused?: string } {
  let stat;
  try {
    stat = lstatSync(join(repo, file));
  } catch {
    return {};
  }
  if (stat.isSymbolicLink()) return { refused: `${file} is a symlink, never followed` };
  if (!stat.isFile()) return { refused: `${file} is not a regular file` };
  try {
    return { text: readFileSync(join(repo, file), 'utf8').replace(/^﻿/, '') };
  } catch {
    return { refused: `${file} is unreadable` };
  }
}
const exists = (repo: string, file: string): boolean => {
  try {
    lstatSync(join(repo, file));
    return true;
  } catch {
    return false;
  }
};

const NAME = /^(?:@[a-z0-9][a-z0-9._~-]*\/)?[a-z0-9._~-][a-z0-9._~-]*$/i;
const VERSION = /^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$/;
function splitAt(spec: string): [string, string] | undefined {
  const at = spec.lastIndexOf('@');
  return at > 0 ? [spec.slice(0, at), spec.slice(at + 1)] : undefined;
}
const unquote = (s: string): string => {
  const t = s.trim();
  if (t.startsWith("'") && t.endsWith("'") && t.length >= 2) return t.slice(1, -1).replace(/''/g, "'");
  if (t.startsWith('"') && t.endsWith('"') && t.length >= 2) return t.slice(1, -1).replace(/\\"/g, '"');
  return t;
};

interface Parser {
  readonly lockfile: string;
  readonly row: NodeRow;
  count: number;
}
function onRegistry(p: Parser, url: string | undefined): boolean {
  if (url === undefined) return true;
  try {
    const u = new URL(url);
    return u.protocol === 'https:' && p.row.registryHosts.includes(u.hostname);
  } catch {
    return false;
  }
}
function registry(p: Parser, name: string, version: string, what: string): Entry {
  if (!NAME.test(name) || !VERSION.test(version)) notScanned(`${p.lockfile} entry ${q(what)} is registry-shaped but its name or version does not parse`);
  return { kind: 'registry', pkg: { name, version } };
}
function counted(p: Parser): void {
  p.count += 1;
  if (p.count > p.row.maxEntries) notScanned(`${p.lockfile} has more than ${p.row.maxEntries} entries (maxEntries)`);
}
function requireNewline(p: Parser, text: string): void {
  if (text !== '' && !text.endsWith('\n')) notScanned(`${p.lockfile} does not end with a newline (truncated)`);
}

// pnpm: every line of the `packages:` section is read or refused.
const PNPM_KEY = /^ {2}('(?:[^']|'')*'|"(?:[^"\\]|\\.)*"|[^\s'"#?][^#]*?):(?:[ \t]+(\{.*\}))?[ \t]*(?:#.*)?$/;
function parsePnpm(p: Parser, text: string): Entry[] {
  requireNewline(p, text);
  const version = /^lockfileVersion:\s*['"]?(\d+)/m.exec(text)?.[1];
  if (!version || !['5', '6', '9'].includes(version)) notScanned(`pnpm-lock.yaml lockfileVersion ${version === undefined ? 'is missing' : q(version)} is not one this parser reads (5, 6, 9)`);
  const lines = text.split(/\r?\n/);
  const sections: Array<{ key: string; flow?: string; body: string[] }> = [];
  let inPackages = false;
  lines.forEach((line, i) => {
    if (line.trim() === '') return;
    if (/^\S/.test(line)) {
      if (line.startsWith('#')) return;
      if (/^packages:[ \t]*(?:\{\}[ \t]*)?(?:#.*)?$/.test(line)) { inPackages = true; return; }
      inPackages = false;
      return;
    }
    if (!inPackages) return;
    const indent = /^ */.exec(line)?.[0].length ?? 0;
    if (indent === 2) {
      if (line.startsWith('  ?')) notScanned(`pnpm-lock.yaml line ${i + 1} is an explicit ? key, which this parser does not read`);
      const m = PNPM_KEY.exec(line);
      if (!m) notScanned(`pnpm-lock.yaml line ${i + 1} is not a packages key this parser reads`);
      sections.push({ key: unquote(m[1]), flow: m[2], body: [] });
    } else if (indent >= 4 && sections.length > 0) {
      sections[sections.length - 1].body.push(line);
    } else {
      notScanned(`pnpm-lock.yaml line ${i + 1} is not indented as a packages entry`);
    }
  });
  return sections.map((s) => {
    counted(p);
    if (s.flow === undefined && s.body.length === 0) notScanned(`pnpm-lock.yaml entry ${q(s.key)} has no body (truncated)`);
    const body = s.flow ?? s.body.join('\n');
    if (/\bdirectory:|type:\s*directory/.test(body)) return { kind: 'local' };
    if (/\brepo:|\bcommit:|type:\s*git/.test(body)) return { kind: 'unqueried' };
    const tarball = /\btarball:\s*['"]?([^,}'"\s]+)/.exec(body)?.[1];
    if (!onRegistry(p, tarball)) return { kind: 'unqueried' };
    const key = s.key.replace(/^\//, '');
    let pair: [string, string] | undefined;
    if (version === '5') {
      const slash = key.lastIndexOf('/');
      pair = slash > 0 ? [key.slice(0, slash), key.slice(slash + 1).replace(/_.*$/, '')] : undefined;
    } else {
      const paren = key.indexOf('(');
      pair = splitAt(paren > 0 ? key.slice(0, paren) : key);
    }
    return registry(p, pair?.[0] ?? '', pair?.[1] ?? '', s.key);
  });
}

// yarn: entries are split on column-0 headers, never on blank lines.
function parseYarn(p: Parser, text: string, markers: NonNullable<Manager['markers']>): Entry[] {
  requireNewline(p, text);
  const berry = markers.berry.test(text);
  if (!berry && !markers.classic.test(text)) notScanned('yarn.lock matches neither declared lockfile marker (berry, classic)');
  const blocks: Array<{ header: string; body: string[] }> = [];
  text.split(/\r?\n/).forEach((line, i) => {
    if (line.trim() === '') return;
    if (/^\S/.test(line)) {
      if (line.startsWith('#')) return;
      const m = /^(\S.*):\s*$/.exec(line);
      if (!m) notScanned(`yarn.lock line ${i + 1} is not an entry header this parser reads`);
      blocks.push({ header: m[1], body: [] });
    } else if (blocks.length > 0) {
      blocks[blocks.length - 1].body.push(line);
    } else {
      notScanned(`yarn.lock line ${i + 1} is indented before any entry header`);
    }
  });
  const entries: Entry[] = [];
  for (const { header, body } of blocks) {
    if (berry && header === '__metadata') continue;
    counted(p);
    const text = body.join('\n');
    if (berry) {
      const resolution = /^ {2}resolution:\s*(.+?)\s*$/m.exec(text)?.[1];
      if (!resolution) notScanned(`yarn.lock entry ${q(header)} has no resolution (truncated)`);
      const spec = unquote(resolution);
      const npm = /^(.+?)@npm:(.+)$/.exec(spec);
      if (npm) { entries.push(registry(p, npm[1], npm[2], spec)); continue; }
      const patch = /^(.+?)@patch:([^#]+)#/.exec(spec);
      if (patch) {
        let inner = '';
        try { inner = decodeURIComponent(patch[2]); } catch { notScanned(`yarn.lock entry ${q(spec)} has an undecodable patch`); }
        const real = /^(.+?)@npm:(.+)$/.exec(inner);
        entries.push(real ? registry(p, real[1], real[2], spec) : { kind: 'unqueried' });
        continue;
      }
      entries.push(/^.+?@(?:workspace|link|portal):/.test(spec) ? { kind: 'local' } : { kind: 'unqueried' });
      continue;
    }
    const version = /^ {2}version:?\s+"?([^"\s]+)"?\s*$/m.exec(text)?.[1];
    if (!version) notScanned(`yarn.lock entry ${q(header)} has no version (truncated)`);
    const resolved = /^ {2}resolved:?\s+"?([^"\s]+)"?\s*$/m.exec(text)?.[1];
    const spec = unquote(header.split(/,\s*/)[0]);
    const alias = /^(.+?)@npm:(.+)@[^@]*$/.exec(spec);
    const pair = alias ? [alias[2], spec.slice(spec.lastIndexOf('@') + 1)] : splitAt(spec);
    const range = pair?.[1] ?? '';
    if (/^(?:link|portal|workspace):/.test(range)) { entries.push({ kind: 'local' }); continue; }
    if (/^(?:file:|git|https?:|github:)/.test(range) || !onRegistry(p, resolved)) { entries.push({ kind: 'unqueried' }); continue; }
    entries.push(registry(p, alias ? alias[2] : (pair?.[0] ?? ''), version, spec));
  }
  return entries;
}

// npm: v2/v3 `packages`, v1 nested `dependencies` walked iteratively under maxDepth.
function npmEntry(p: Parser, name: string, value: unknown, what: string): Entry {
  if (!isRecord(value)) notScanned(`${p.lockfile} entry ${q(what)} is not an object`);
  if (value.link === true) return { kind: 'local' };
  const resolved = typeof value.resolved === 'string' ? value.resolved : undefined;
  let version = typeof value.version === 'string' ? value.version : '';
  let real = typeof value.name === 'string' ? value.name : name;
  const alias = /^npm:(.+)@([^@]+)$/.exec(version);
  if (alias) { real = alias[1]; version = alias[2]; }
  if (/^(?:file:|git|https?:|github:)/.test(version) || !onRegistry(p, resolved)) return { kind: 'unqueried' };
  return registry(p, real, version, what);
}
function parseNpm(p: Parser, text: string): Entry[] {
  let lock: unknown;
  try {
    lock = JSON.parse(text);
  } catch {
    notScanned(`${p.lockfile} does not parse as JSON`);
  }
  if (!isRecord(lock)) notScanned(`${p.lockfile} is not a JSON object`);
  if (![1, 2, 3].includes(lock.lockfileVersion as number)) notScanned(`${p.lockfile} lockfileVersion is not one this parser reads (1, 2, 3)`);
  const entries: Entry[] = [];
  if (lock.lockfileVersion !== 1) {
    if (!isRecord(lock.packages)) notScanned(`${p.lockfile} has no packages object`);
    for (const [key, value] of Object.entries(lock.packages)) {
      if (key === '') continue;
      counted(p);
      const at = key.lastIndexOf('node_modules/');
      if (at < 0) { entries.push({ kind: 'local' }); continue; } // a workspace's own source directory
      entries.push(npmEntry(p, key.slice(at + 'node_modules/'.length), value, key));
    }
    return entries;
  }
  const stack: Array<{ deps: unknown; depth: number }> = [{ deps: lock.dependencies, depth: 1 }];
  while (stack.length > 0) {
    const { deps, depth } = stack.pop()!;
    if (deps === undefined) continue;
    if (!isRecord(deps)) notScanned(`${p.lockfile} has a dependencies value that is not an object`);
    if (depth > p.row.maxDepth) notScanned(`${p.lockfile} nests dependencies deeper than ${p.row.maxDepth} (maxDepth)`);
    for (const [name, value] of Object.entries(deps)) {
      counted(p);
      entries.push(npmEntry(p, name, value, name));
      if (isRecord(value)) stack.push({ deps: value.dependencies, depth: depth + 1 });
    }
  }
  return entries;
}

// bun: JSON whose only extension is a trailing comma closing an array or object. A
// comment, or any other comma out of place, survives the strip and fails JSON.parse.
// A key repeated in one object is reported: JSON.parse would keep only the last, so
// the audit would read a different set than the file states (Bun refuses it too).
const JSON_SPACE = ' \t\r\n';
function stripTrailingCommas(text: string): { json: string; duplicate?: string } {
  let result = '';
  let last = '';
  let duplicate: string | undefined;
  const objects: Array<Set<string> | undefined> = [];
  for (let i = 0; i < text.length; i += 1) {
    const c = text[i];
    if (c === '"') {
      let j = i + 1;
      while (j < text.length && text[j] !== '"') j += text[j] === '\\' ? 2 : 1;
      const raw = text.slice(i, j + 1);
      result += raw;
      let k = j + 1;
      while (k < text.length && JSON_SPACE.includes(text[k])) k += 1;
      const keys = objects[objects.length - 1];
      if (text[k] === ':' && keys && duplicate === undefined) {
        let key = raw;
        try { key = JSON.parse(raw) as string; } catch { /* JSON.parse of the whole file refuses it */ }
        if (keys.has(key)) duplicate = key;
        keys.add(key);
      }
      last = '"';
      i = j;
      continue;
    }
    if (c === '{') objects.push(new Set());
    else if (c === '[') objects.push(undefined);
    else if (c === '}' || c === ']') objects.pop();
    if (c === ',' && !'[{,'.includes(last)) {
      let j = i + 1;
      while (j < text.length && JSON_SPACE.includes(text[j])) j += 1;
      if (text[j] === '}' || text[j] === ']') continue;
    }
    result += c;
    if (!JSON_SPACE.includes(c)) last = c;
  }
  return { json: result, duplicate };
}
function bunEntry(p: Parser, key: string, value: unknown): Entry {
  if (!Array.isArray(value) || typeof value[0] !== 'string') notScanned(`bun.lock entry ${q(key)} is not a package tuple`);
  const spec = value[0];
  const at = spec.indexOf('@', spec.startsWith('@') ? 1 : 0);
  if (at <= 0) notScanned(`bun.lock entry ${q(key)} names no <name>@<spec>`);
  let name = spec.slice(0, at);
  let version = spec.slice(at + 1);
  // `link:` is a package `bun link` registered in the machine's global link folder, not
  // the tree; a workspace or root path that is absolute or climbs out is not the tree either.
  const path = /^(?:workspace|root):(.*)$/.exec(version)?.[1];
  if (path !== undefined) return /^(?:[\\/]|[A-Za-z]:)|(?:^|[\\/])\.\.(?:[\\/]|$)/.test(path) ? { kind: 'unqueried' } : { kind: 'local' };
  if (/^link:/.test(version)) return { kind: 'unqueried' };
  if (/^(?:file:|\.{0,2}\/|git|github:|gitlab:|bitbucket:|https?:)/.test(version) || version.includes('#')) return { kind: 'unqueried' };
  const alias = /^npm:(.+)@([^@]+)$/.exec(version);
  if (alias) { name = alias[1]; version = alias[2]; }
  if (value.length !== 4 || typeof value[1] !== 'string' || !isRecord(value[2]) || typeof value[3] !== 'string') {
    notScanned(`bun.lock entry ${q(key)} is registry-shaped but not a [spec, registry, metadata, integrity] tuple`);
  }
  if (!onRegistry(p, value[1] === '' ? undefined : value[1])) return { kind: 'unqueried' };
  return registry(p, name, version, spec);
}
function parseBun(p: Parser, text: string): Entry[] {
  requireNewline(p, text);
  let lock: unknown;
  const stripped = stripTrailingCommas(text);
  try {
    lock = JSON.parse(stripped.json);
  } catch {
    notScanned(`${p.lockfile} does not parse as JSON with trailing commas`);
  }
  if (stripped.duplicate !== undefined) notScanned(`${p.lockfile} repeats the key ${q(stripped.duplicate)} in one object (duplicate)`);
  if (!isRecord(lock)) notScanned(`${p.lockfile} is not a JSON object`);
  if (![0, 1, 2].includes(lock.lockfileVersion as number)) notScanned(`${p.lockfile} lockfileVersion is not one this parser reads (0, 1, 2)`);
  if (!isRecord(lock.packages)) notScanned(`${p.lockfile} has no packages object`);
  return Object.entries(lock.packages).map(([key, value]) => {
    counted(p);
    return bunEntry(p, key, value);
  });
}

interface Resolution { readonly manager: string; readonly lockfile: string; readonly source: string; readonly packages: Pkg[]; readonly local: number; readonly unqueried: number; readonly others: string[] }

function resolveTree(repo: string, row: NodeRow): Resolution {
  const manifest = readRegular(repo, 'package.json');
  if (manifest.refused) notScanned(manifest.refused);
  if (manifest.text === undefined) notScanned('no package.json at the root of the path');
  let pkg: unknown;
  try {
    pkg = JSON.parse(manifest.text);
  } catch {
    notScanned('package.json does not parse as JSON');
  }
  if (!isRecord(pkg)) notScanned('package.json is not a JSON object');
  const field = pkg.packageManager;
  const lockfilesOf = (name: string): string[] => row.managers[name].lockfiles.filter((f) => exists(repo, f));
  let manager: string;
  let source: string;
  if (field !== undefined) {
    if (typeof field !== 'string') notScanned('packageManager is not a string');
    if (/[\u0000-\u001f\u007f-\u009f\u2028\u2029]/.test(field)) notScanned('packageManager carries control characters');
    const pair = splitAt(field.trim());
    if (!pair || !/^[a-z0-9][a-z0-9._-]*$/i.test(pair[0]) || pair[1] === '') notScanned(`packageManager ${q(field)} is not <name>@<version>`);
    manager = pair[0].toLowerCase();
    if (!Object.hasOwn(row.managers, manager)) notScanned(`packageManager names ${q(manager)}, which has no dependencyAudit.node manager`);
    source = `packageManager ${q(field)}`;
  } else {
    const found = Object.keys(row.managers).filter((name) => lockfilesOf(name).length > 0);
    if (found.length > 1) notScanned(`no packageManager field and ${found.flatMap(lockfilesOf).join(', ')} are all present (ambiguous)`);
    if (found.length === 0) {
      const foreign = Object.keys(row.unsupportedLockfiles).find((f) => exists(repo, f));
      if (foreign) notScanned(`${foreign} is a ${row.unsupportedLockfiles[foreign]} lockfile, which has no dependencyAudit.node parser`);
      notScanned('no packageManager field and no lockfile to audit');
    }
    manager = found[0];
    source = 'no packageManager field';
  }
  const m = row.managers[manager];
  const lockfile = m.lockfiles.find((f) => exists(repo, f));
  if (!lockfile) {
    const foreign = Object.keys(row.unsupportedLockfiles).find((f) => row.unsupportedLockfiles[f] === manager && exists(repo, f));
    if (foreign) notScanned(`${source} but its only lockfile is ${foreign}, which has no dependencyAudit.node parser`);
    notScanned(`${source} but no ${m.lockfiles.join(' or ')} to audit`);
  }
  const others = [
    ...Object.keys(row.managers).filter((name) => name !== manager).flatMap(lockfilesOf),
    ...Object.keys(row.unsupportedLockfiles).filter((f) => exists(repo, f)),
    ...m.lockfiles.filter((f) => f !== lockfile && exists(repo, f)),
  ];
  const lock = readRegular(repo, lockfile);
  if (lock.refused) notScanned(lock.refused);
  const p: Parser = { lockfile, row, count: 0 };
  const text = lock.text ?? '';
  const entries = m.format === 'pnpm-lock' ? parsePnpm(p, text) : m.format === 'yarn-lock' ? parseYarn(p, text, m.markers!) : m.format === 'bun-lock' ? parseBun(p, text) : parseNpm(p, text);
  const seen = new Map<string, Pkg>();
  let local = 0;
  let unqueried = 0;
  for (const e of entries) {
    if (e.kind === 'registry') seen.set(`${e.pkg.name}@${e.pkg.version}`, e.pkg);
    else if (e.kind === 'local') local += 1;
    else unqueried += 1;
  }
  if (seen.size === 0 && unqueried === 0) notScanned(`no packages parsed from ${lockfile}`);
  return { manager, lockfile, source, packages: [...seen.values()], local, unqueried, others };
}

function auditConfig(repo: string, row: NodeRow, others: readonly string[]): string[] {
  const hits: string[] = others.map((file) => `audit-config: ${q(file)} "other-lockfile" -- not audited; evidence for Feitan`);
  for (const [file, keys] of Object.entries(row.auditConfigKeys)) {
    const read = readRegular(repo, file);
    if (read.refused) { hits.push(`audit-config: ${q(file)} ${q(read.refused)}`); continue; }
    if (read.text === undefined) continue;
    const present = new Set<string>();
    const extra: string[] = [];
    if (file === 'package.json') {
      let pkg: unknown;
      try { pkg = JSON.parse(read.text); } catch { continue; }
      for (const key of keys) {
        let node: unknown = pkg;
        for (const part of key.split('.')) node = isRecord(node) ? node[part] : undefined;
        if (node !== undefined) present.add(key);
      }
    } else if (file === '.npmrc') {
      // ini lines; a `*<suffix>` key matches any key ending in it (a scoped `@x:registry`).
      for (const line of read.text.split(/\r?\n/)) {
        const key = /^\s*([^=;#\s][^=]*?)\s*=/.exec(line)?.[1]?.toLowerCase();
        if (!key) continue;
        for (const k of keys) if (k.startsWith('*') ? key.endsWith(k.slice(1).toLowerCase()) : key === k.toLowerCase()) present.add(k);
      }
    } else if (file.endsWith('.toml')) {
      // Evidence, not a TOML parser. A key is `<table>.<key>` under its header; a header
      // alone, a dotted key, an unescaped quoted key and a one-line inline table's keys
      // count. It FAILS TOWARD EVIDENCE: a line it cannot place (a multi-line string or
      // inline table, an escaped key, anything else) is one `unread` line, and a key whose
      // leaf token appears anywhere in the file, its \u, \U and \x escapes decoded, is printed as mentioned.
      const norm = (k: string): string => k.replace(/["']/g, '').replace(/\s*\.\s*/g, '.');
      const hit = (k: string): void => { for (const want of keys) if (k === want || k.startsWith(`${want}.`)) present.add(want); };
      const code = (s: string): string => s.replace(/"(?:[^"\\]|\\.)*"|'[^']*'/g, '""').replace(/#.*$/, '');
      const net = (s: string, open: string, close: string): number => s.split(open).length - s.split(close).length;
      const unread: number[] = [];
      let table = '';
      let array = 0;
      read.text.split(/\r?\n/).forEach((line, i) => {
        if (/"""|'''/.test(line)) { unread.push(i + 1); return; }
        const bare = code(line);
        if (array > 0) { array += net(bare, '[', ']'); return; }
        if (bare.trim() === '') return;
        const header = /^\s*\[\[?([^\]\\]+)\]\]?\s*$/.exec(bare) && /^\s*\[\[?([^\]\\]+)\]\]?/.exec(line)?.[1];
        if (header) { table = norm(header.trim()); hit(table); return; }
        const m = /^\s*([A-Za-z0-9_"'. -]+?)\s*=\s*(.*)$/.exec(line);
        if (!m) { unread.push(i + 1); return; }
        const full = table ? `${table}.${norm(m[1])}` : norm(m[1]);
        hit(full);
        const value = code(m[2]).trim();
        if (value.startsWith('{')) {
          if (net(value, '{', '}') !== 0) { unread.push(i + 1); return; }
          for (const inner of m[2].matchAll(/([A-Za-z0-9_"'-]+)\s*=/g)) hit(`${full}.${norm(inner[1])}`);
        } else if (value.startsWith('[')) array = Math.max(net(value, '[', ']'), 0);
      });
      if (unread.length > 0) extra.push(`audit-config: ${q(file)} "unread" -- ${unread.length} line(s) this scanner cannot place, first line ${unread[0]}; evidence for Feitan`);
      const decoded = read.text.replace(/\\u([0-9A-Fa-f]{4})|\\U([0-9A-Fa-f]{8})|\\x([0-9A-Fa-f]{2})/g, (raw, a?: string, b?: string, c?: string) => {
        try { return String.fromCodePoint(parseInt(a ?? b ?? c ?? '', 16)); } catch { return raw; }
      });
      for (const want of keys) {
        const leaf = want.slice(want.lastIndexOf('.') + 1);
        if (!present.has(want) && new RegExp(`(?<![A-Za-z0-9_-])${leaf}(?![A-Za-z0-9_-])`, 'i').test(decoded)) {
          extra.push(`audit-config: ${q(file)} ${q(want)} -- its token ${q(leaf)} appears outside a key this scanner read; not honoured; evidence for Feitan`);
        }
      }
    } else {
      for (const line of read.text.split(/\r?\n/)) {
        const key = /^([A-Za-z][A-Za-z0-9_-]*)\s*:/.exec(line)?.[1];
        if (key && keys.includes(key)) present.add(key);
      }
    }
    for (const key of present) hits.push(`audit-config: ${q(file)} ${q(key)} -- not honoured; evidence for Feitan`);
    hits.push(...extra);
  }
  return hits;
}

// --- OSV ----------------------------------------------------------------------------
async function fetchRetry(url: URL, init: RequestInit): Promise<Response> {
  try {
    return await fetch(url, init);
  } catch (error) {
    if ((error as Error)?.name !== 'TypeError' || init.signal?.aborted) throw error;
    return fetch(url, init);
  }
}
async function readJson(response: Response, row: NodeRow, url: URL): Promise<unknown> {
  if (!response.ok) notScanned(`OSV answered HTTP ${response.status} at ${url.host}`);
  const reader = response.body?.getReader();
  if (!reader) notScanned('OSV returned no body');
  const chunks: Uint8Array[] = [];
  let size = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > row.maxResponseBytes) {
      await reader.cancel().catch(() => undefined);
      notScanned(`OSV response exceeded ${row.maxResponseBytes} bytes (maxResponseBytes)`);
    }
    chunks.push(value);
  }
  return JSON.parse(Buffer.concat(chunks).toString('utf8'));
}

const ID = /^[A-Za-z0-9][A-Za-z0-9._:-]{0,99}$/;
const MALFORMED = 'OSV returned a malformed querybatch response';
async function query(row: NodeRow, packages: readonly Pkg[]): Promise<number> {
  const signal = AbortSignal.timeout(row.timeoutSeconds * 1000);
  const hits = new Map<string, Pkg[]>();
  for (let i = 0; i < packages.length; i += 1000) {
    let pending = packages.slice(i, i + 1000).map((p) => ({ p, token: undefined as string | undefined }));
    for (let page = 0; pending.length > 0; page += 1) {
      if (page > 20) notScanned('OSV kept paging past 20 pages');
      const body = { queries: pending.map(({ p, token }) => ({ package: { name: p.name, ecosystem: row.ecosystem }, version: p.version, ...(token ? { page_token: token } : {}) })) };
      const response = await fetchRetry(row.endpoint, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body), signal, redirect: 'error' });
      const answer = await readJson(response, row, row.endpoint);
      const results = isRecord(answer) ? answer.results : undefined;
      if (!Array.isArray(results) || results.length !== pending.length) notScanned(MALFORMED);
      const next: typeof pending = [];
      results.forEach((result: unknown, k: number) => {
        if (!isRecord(result)) notScanned(MALFORMED);
        if (result.vulns !== undefined && !Array.isArray(result.vulns)) notScanned(MALFORMED);
        for (const v of (result.vulns ?? []) as unknown[]) {
          const id = isRecord(v) ? v.id : undefined;
          if (typeof id !== 'string' || !ID.test(id)) notScanned('OSV returned a malformed vulnerability id');
          hits.set(id, [...(hits.get(id) ?? []), pending[k].p]);
        }
        if (result.next_page_token !== undefined) {
          if (typeof result.next_page_token !== 'string' || result.next_page_token === '') notScanned(MALFORMED);
          next.push({ p: pending[k].p, token: result.next_page_token });
        }
      });
      pending = next;
    }
  }
  const ids = [...hits.keys()].sort();
  const severities = new Map<string, string>();
  for (let i = 0; i < ids.length; i += 10) {
    await Promise.all(ids.slice(i, i + 10).map(async (id) => {
      const url = new URL(encodeURIComponent(id), row.vulnEndpoint);
      const vuln = await readJson(await fetchRetry(url, { signal, redirect: 'error' }), row, url);
      const raw = isRecord(vuln) && isRecord(vuln.database_specific) ? vuln.database_specific.severity : undefined;
      const severity = typeof raw === 'string' ? raw.toUpperCase() : '';
      severities.set(id, row.severityLevels.includes(severity) ? severity : 'UNRATED');
    }));
  }
  let findings = 0;
  for (const id of ids) {
    const severity = severities.get(id) ?? 'UNRATED';
    const atFloor = severity === 'UNRATED' || row.severityFloor.includes(severity);
    if (atFloor) findings += 1;
    out(`${atFloor ? 'finding' : 'below-floor'}: ${id} ${severity} ${(hits.get(id) ?? []).map((p) => q(`${p.name}@${p.version}`)).join(' ')}`);
  }
  return findings;
}

async function main(): Promise<number> {
  const args = parseArgs(process.argv.slice(2));
  let isDir = false;
  try {
    isDir = statSync(args.repo).isDirectory();
  } catch {
    isDir = false;
  }
  if (!isDir) tooling(`${args.repo} is not a directory`);
  const row = loadRow(args.scans);
  try {
    if (args.stack !== undefined && !row.stacks.includes(args.stack)) notScanned(`stack ${q(args.stack)} is not on dependencyAudit.node.stacks`);
    const tree = resolveTree(args.repo, row);
    out(`resolved: osv ${row.ecosystem} for ${tree.manager} (${tree.source}, ${tree.lockfile}, ${tree.packages.length} packages)`);
    for (const line of auditConfig(args.repo, row, tree.others)) out(line);
    if (tree.local > 0) out(`local: ${tree.local} ${tree.lockfile} entries are workspace, link or directory packages, not queried`);
    if (tree.unqueried > 0) out(`unqueried: ${tree.unqueried} ${tree.lockfile} entries come from git, file: or a host off registryHosts -- never clean`);
    if (!args.query) return 0;
    let findings: number;
    try {
      findings = tree.packages.length > 0 ? await query(row, tree.packages) : 0;
    } catch (error) {
      if (error instanceof NotScanned) throw error;
      const name = (error as Error)?.name;
      if (name === 'TimeoutError' || name === 'AbortError') notScanned(`OSV query timed out after ${row.timeoutSeconds}s`);
      notScanned(name === 'SyntaxError' ? 'OSV returned a response that is not JSON' : `OSV unreachable at ${row.endpoint.host}`);
    }
    out(`audit: ${findings} finding(s) at or above ${row.severityFloor.join('/')} or unrated, ${tree.unqueried} unqueried, across ${tree.packages.length} packages`);
    return findings > 0 || tree.unqueried > 0 ? 1 : 0;
  } catch (error) {
    if (!(error instanceof NotScanned)) throw error;
    out(`not scanned: ${error.message}`);
    return 3;
  }
}

// Exit by exitCode, never process.exit(): a piped stdout drains before the process ends.
try {
  process.exitCode = await main();
} catch (error) {
  process.stderr.write(error instanceof Tooling ? `dependency-audit-resolve: ${error.message}\n` : `dependency-audit-resolve: internal error (${(error as Error)?.name ?? 'unknown'}); a wiring stop, never a verdict\n`);
  process.exitCode = 2;
}
