#!/usr/bin/env node
// zheref/hatsu#247 item 1: hermetic fixture for scripts/dependency_audit_resolve.mts.
// Throwaway trees, the LIVE contracts/scans.json for resolution, and copies of it
// whose OSV endpoints point at a loopback stub this process serves (one route per
// stub mode), so a pnpm tree is proved SCANNED -- parsed, queried, its result
// reported (AC-e) -- with no network. The canary cases prove no package manager or
// tree hook runs and no caller environment or tree-chosen token reaches anything.
import assert from 'node:assert/strict';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { createServer, type IncomingMessage } from 'node:http';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const resolver = fileURLToPath(new URL('./dependency_audit_resolve.mts', import.meta.url));
const liveScans = fileURLToPath(new URL('../contracts/scans.json', import.meta.url));
const hatsuRoot = realpathSync(fileURLToPath(new URL('../', import.meta.url)));
const scratch = realpathSync(mkdtempSync(join(tmpdir(), 'hatsu-dependency-audit-')));
const CANARY = `feitan-canary-${process.pid}-${Date.now()}`;
const marker = join(scratch, 'HOOK-RAN');
let cases = 0;

// --- the stub OSV: /m/<mode>/querybatch and /m/<mode>/vulns/<id> ---------------------
const VULNS: Record<string, string[]> = {
  'lodash@4.17.15': ['GHSA-test-high', 'GHSA-test-moderate'],
  'left-pad@1.0.0': ['MAL-test-unrated'],
  'minimist@0.0.8': ['GHSA-test-severe'],
  'ms@0.0.1': ['GHSA-test-unknown'],
};
const SEVERITY: Record<string, string | undefined> = {
  'GHSA-test-high': 'HIGH', 'GHSA-test-moderate': 'MODERATE', 'MAL-test-unrated': undefined, 'GHSA-test-severe': 'SEVERE', 'GHSA-test-unknown': 'UNKNOWN',
};
const seen: Array<{ url: string; headers: IncomingMessage['headers']; body: string }> = [];
const server = createServer((req, res) => {
  let body = '';
  req.on('data', (chunk) => { body += chunk; });
  req.on('end', () => {
    seen.push({ url: req.url ?? '', headers: req.headers, body });
    const route = /^\/m\/([a-z-]+)\/(querybatch|vulns\/(.+))$/.exec(req.url ?? '');
    const mode = route?.[1] ?? 'missing';
    if (mode === 'hang') return; // never answers
    if (!route || mode === 'down') { res.writeHead(503).end(); return; }
    if (mode === 'big') { res.writeHead(200, { 'content-type': 'application/json' }).end(`{"results":[${'{},'.repeat(200)}{}]}`); return; }
    if (route[2] === 'querybatch') {
      const { queries } = JSON.parse(body) as { queries: Array<{ package: { name: string; ecosystem: string }; version: string }> };
      const results = queries.map((qy) => {
        assert.equal(qy.package.ecosystem, 'npm');
        if (mode === 'null-result') return null;
        if (mode === 'string-result') return 'x';
        if (mode === 'null-vulns') return { vulns: null };
        const key = `${qy.package.name}@${qy.version}`;
        const ids = VULNS[key] ?? (qy.package.name.startsWith('bulk') ? [`GHSA-${qy.package.name}`] : undefined);
        return ids ? { vulns: ids.map((id) => ({ id, modified: '2026-10-22T00:00:00Z' })) } : {};
      });
      res.writeHead(200, { 'content-type': 'application/json' }).end(JSON.stringify({ results }));
      return;
    }
    const id = decodeURIComponent(route[3]);
    const sev = id.startsWith('GHSA-bulk') ? 'HIGH' : SEVERITY[id];
    res.writeHead(200, { 'content-type': 'application/json' }).end(JSON.stringify({ id, ...(sev ? { database_specific: { severity: sev } } : {}) }));
  });
});
await new Promise<void>((done) => server.listen(0, '127.0.0.1', () => done()));
const port = (server.address() as { port: number }).port;

function contract(name: string, edit: (node: Record<string, unknown>) => void, mode = 'ok'): string {
  const data = JSON.parse(readFileSync(liveScans, 'utf8'));
  data.dependencyAudit.node.endpoint = `http://127.0.0.1:${port}/m/${mode}/querybatch`;
  data.dependencyAudit.node.vulnEndpoint = `http://127.0.0.1:${port}/m/${mode}/vulns/`;
  edit(data.dependencyAudit.node);
  const path = join(scratch, `${name}.json`);
  writeFileSync(path, JSON.stringify(data));
  return path;
}
const stub = contract('stub', () => undefined);
const modeContract = (mode: string, edit: (n: Record<string, unknown>) => void = () => undefined): string => contract(`mode-${mode}`, edit, mode);

// --- trees ----------------------------------------------------------------------------
function tree(name: string, files: Record<string, string>): string {
  const dir = join(scratch, name);
  mkdirSync(dir);
  for (const [file, body] of Object.entries(files)) writeFileSync(join(dir, file), body);
  return dir;
}
const pkg = (packageManager?: string, extra: Record<string, unknown> = {}): string => JSON.stringify({ name: 'fixture', ...(packageManager ? { packageManager } : {}), ...extra });
const pnpm = (entries: string, version = "'9.0'"): string => `lockfileVersion: ${version}\n\npackages:\n\n${entries}`;
const PNPM9 = pnpm("  lodash@4.17.15:\n    resolution: {integrity: sha512-a}\n\n  '@scope/ok@2.0.0':\n    resolution: {integrity: sha512-b}\n\n") + 'snapshots:\n\n  lodash@4.17.15: {}\n';
const PNPM6 = pnpm('  /lodash@4.17.15:\n    resolution: {integrity: sha512-a}\n\n  /react-dom@18.2.0(react@18.2.0):\n    resolution: {integrity: sha512-b}\n', "'6.0'");
const PNPM5 = pnpm('  /lodash/4.17.15:\n    resolution: {integrity: sha512-a}\n\n  /@scope/ok/2.0.0_react@18.2.0:\n    resolution: {integrity: sha512-b}\n', '5.4');
const BERRY = '__metadata:\n  version: 8\n  cacheKey: 10c0\n\n"lodash@npm:^4.17.15":\n  version: 4.17.15\n  resolution: "lodash@npm:4.17.15"\n\n"app@workspace:.":\n  version: 0.0.0-use.local\n  resolution: "app@workspace:."\n';
const CLASSIC_HEAD = '# THIS IS AN AUTOGENERATED FILE.\n# yarn lockfile v1\n\n\n';
const REG = 'https://registry.yarnpkg.com';
const CLASSIC = `${CLASSIC_HEAD}"lodash@^4.17.15", lodash@^4.17.21:\n  version "4.17.15"\n  resolved "${REG}/lodash/-/lodash-4.17.15.tgz#abc"\n\nleft-pad@^1.0.0:\n  version "1.0.0"\n  resolved "${REG}/left-pad/-/left-pad-1.0.0.tgz#def"\n`;
const NPM3 = JSON.stringify({ lockfileVersion: 3, packages: { '': { name: 'fixture' }, 'node_modules/lodash': { version: '4.17.15', resolved: 'https://registry.npmjs.org/lodash/-/lodash-4.17.15.tgz' }, 'node_modules/a/node_modules/left-pad': { version: '1.0.0' }, 'node_modules/linked': { link: true }, 'packages/ws': { version: '1.0.0' } } });
// zheref/hatsu#507: bun.lock in the shape bun writes it (trailing commas, nested and aliased keys).
const bunLock = (packages: string, version = 2): string => `{\n  "lockfileVersion": ${version},\n  "configVersion": 1,\n  "workspaces": {\n    "": {\n      "name": "fixture",\n      "dependencies": {\n        "lodash": "4.17.15",\n      },\n    },\n  },\n  "packages": {\n${packages}  }\n}\n`;
const BUN = bunLock('    "lodash": ["lodash@4.17.15", "", {}, "sha512-a"],\n\n    "@scope/ok": ["@scope/ok@2.0.0", "", { "dependencies": { "lodash": "^4.17.0", }, }, "sha512-b"],\n\n    "@scope/ok/lodash": ["lodash@4.17.15", "", {}, "sha512-a"],\n');
const NPM1 = JSON.stringify({ lockfileVersion: 1, dependencies: { lodash: { version: '4.17.15', dependencies: { 'left-pad': { version: '1.0.0' } } } } });

interface Run { status: number | null; stdout: string; stderr: string }
function run(args: string[], env: Record<string, string> = {}): Promise<Run> {
  return new Promise((done) => {
    const child = spawn(process.execPath, [resolver, ...args], { cwd: scratch, env: { ...process.env, FEITAN_CANARY: CANARY, ...env } });
    let stdout = '';
    let stderr = '';
    child.stdout.on('data', (c) => { stdout += c; });
    child.stderr.on('data', (c) => { stderr += c; });
    child.on('close', (status) => done({ status, stdout, stderr }));
  });
}
async function expect(name: string, args: string[], status: number, stdout: RegExp, env: Record<string, string> = {}): Promise<string> {
  const result = await run(args, env);
  const detail = `${name}: exit ${result.status}\nstdout: ${result.stdout.slice(0, 4000)}\nstderr: ${result.stderr}`;
  assert.equal(result.status, status, detail);
  assert.match(result.stdout, stdout, detail);
  if (status === 2) {
    assert.equal(result.stdout, '', `${name}: a wiring stop prints nothing on stdout\n${detail}`);
    assert.match(result.stderr, /^dependency-audit-resolve: /, `${name}: a wiring stop is named on stderr\n${detail}`);
  } else assert.equal(result.stderr, '', `${name}: verdicts go to stdout only\n${detail}`);
  if (status === 3) assert.match(result.stdout, /(^|\n)not scanned: [^\n]+\n$/, `${name}: ends on one named not-scanned line\n${detail}`);
  if (status === 0 || status === 1) assert.match(result.stdout, /^resolved: osv npm for /, `${name}: the resolution line comes first\n${detail}`);
  cases += 1;
  console.log(`ok ${cases} - ${name}`);
  return result.stdout;
}
const pass = (name: string): void => { cases += 1; console.log(`ok ${cases} - ${name}`); };

try {
  // AC-e / AC-a: the pnpm tree the old npm-only row reported NOT SCANNED.
  const pnpmTree = tree('pnpm', { 'package.json': pkg('pnpm@9.15.9'), 'pnpm-lock.yaml': PNPM9 });
  await expect('a pnpm tree resolves, never not-scanned', [pnpmTree], 0, /^resolved: osv npm for pnpm \(packageManager "pnpm@9\.15\.9", pnpm-lock\.yaml, 2 packages\)\n$/);
  seen.length = 0;
  await expect('a pnpm tree is SCANNED: queried and its finding reported', [pnpmTree, '--query', '--scans', stub], 1,
    /finding: GHSA-test-high HIGH "lodash@4\.17\.15"\nbelow-floor: GHSA-test-moderate MODERATE "lodash@4\.17\.15"\naudit: 1 finding\(s\) at or above HIGH\/CRITICAL or unrated, 0 unqueried, across 2 packages\n$/);
  const batch = JSON.parse(seen.find((r) => r.url.endsWith('/querybatch'))?.body ?? '{}');
  assert.deepEqual(batch.queries.map((qy: { package: { name: string }; version: string }) => `${qy.package.name}@${qy.version}`).sort(), ['@scope/ok@2.0.0', 'lodash@4.17.15']);
  pass('the querybatch carried exactly the lockfile\'s registry packages');
  const clean = tree('pnpm-clean', { 'package.json': pkg('pnpm@11.25.0+sha512.abc'), 'pnpm-lock.yaml': pnpm('  ok@1.0.0:\n    resolution: {integrity: x}\n') });
  await expect('a clean pnpm tree is exit 0', [clean, '--query', '--scans', stub], 0, /audit: 0 finding\(s\) .*, 0 unqueried, across 1 packages\n$/);
  await expect('pnpm lockfile v6 with a peer suffix', [tree('pnpm6', { 'package.json': pkg('pnpm@8.15.0'), 'pnpm-lock.yaml': PNPM6 })], 0, /pnpm-lock\.yaml, 2 packages\)\n$/);
  await expect('pnpm lockfile v5 slash keys', [tree('pnpm5', { 'package.json': pkg('pnpm@7.0.0'), 'pnpm-lock.yaml': PNPM5 })], 0, /pnpm-lock\.yaml, 2 packages\)\n$/);
  await expect('an unknown pnpm lockfileVersion is not scanned', [tree('pnpm-future', { 'package.json': pkg('pnpm@99.0.0'), 'pnpm-lock.yaml': "lockfileVersion: '12.0'\n" })], 3, /lockfileVersion "12" is not one this parser reads/);

  // 4: pnpm lines are read or refused, never dropped.
  const pnpmCase = (name: string, lock: string): string => tree(name, { 'package.json': pkg('pnpm@9.15.9'), 'pnpm-lock.yaml': lock });
  await expect('a flow-style pnpm entry is read', [pnpmCase('pnpm-flow', pnpm('  lodash@4.17.15: {resolution: {integrity: sha512-a}}\n  ok@1.0.0:\n    resolution: {integrity: x}\n')), '--query', '--scans', stub], 1, /2 packages\)\n[\s\S]*finding: GHSA-test-high/);
  await expect('a trailing comment on a pnpm key is read', [pnpmCase('pnpm-comment', pnpm('  lodash@4.17.15: # pinned\n    resolution: {integrity: sha512-a}\n')), '--query', '--scans', stub], 1, /1 packages\)\n[\s\S]*finding: GHSA-test-high/);
  await expect('a commented packages: header is read', [pnpmCase('pnpm-header', "lockfileVersion: '9.0'\n\npackages: # all\n\n  lodash@4.17.15:\n    resolution: {integrity: sha512-a}\n"), '--query', '--scans', stub], 1, /finding: GHSA-test-high/);
  await expect('an explicit ? key is refused', [pnpmCase('pnpm-explicit', pnpm('  ? lodash@4.17.15\n  : resolution: {integrity: sha512-a}\n'))], 3, /line 5 is an explicit \? key/);
  await expect('an unreadable packages line is refused', [pnpmCase('pnpm-odd', pnpm('  lodash@4.17.15 = 1\n'))], 3, /line 5 is not a packages key this parser reads/);
  await expect('a pnpm file cut mid-key is refused', [pnpmCase('pnpm-cut', pnpm('  ok@1.0.0:\n    resolution: {integrity: x}\n\n  loda'))], 3, /does not end with a newline \(truncated\)/);
  await expect('a last pnpm key with no body is refused', [pnpmCase('pnpm-nobody', pnpm('  ok@1.0.0:\n    resolution: {integrity: x}\n\n  lodash@4.17.15:\n'))], 3, /entry "lodash@4\.17\.15" has no body \(truncated\)/);
  await expect('a registry-shaped pnpm key that does not parse is refused', [pnpmCase('pnpm-badkey', pnpm('  lodash@latest:\n    resolution: {integrity: sha512-a}\n'))], 3, /entry "lodash@latest" is registry-shaped but its name or version does not parse/);
  await expect('a BOM-prefixed pnpm lockfile parses', [pnpmCase('pnpm-bom', `\uFEFF${PNPM9}`)], 0, /2 packages\)\n$/);

  // 6/7: only registry-hosted entries are queried; anything else is unqueried and never clean.
  await expect('a pnpm tarball off registryHosts is unqueried, never clean', [pnpmCase('pnpm-foreign', pnpm('  ok@1.0.0:\n    resolution: {integrity: x}\n  evil@1.0.0:\n    resolution: {tarball: https://evil.invalid/evil-1.0.0.tgz}\n')), '--query', '--scans', stub], 1,
    /1 packages\)\nunqueried: 1 pnpm-lock\.yaml entries come from git, file: or a host off registryHosts -- never clean\naudit: 0 finding\(s\) .*, 1 unqueried, across 1 packages\n$/);
  await expect('a pnpm tarball on the registry host is queried', [pnpmCase('pnpm-reg-tarball', pnpm('  lodash@4.17.15:\n    resolution: {integrity: x, tarball: https://registry.npmjs.org/lodash/-/lodash-4.17.15.tgz}\n')), '--query', '--scans', stub], 1, /1 packages\)\n[\s\S]*finding: GHSA-test-high/);
  await expect('a pnpm http tarball on the registry host is unqueried', [pnpmCase('pnpm-http', pnpm('  ok@1.0.0:\n    resolution: {integrity: x}\n  lodash@4.17.15:\n    resolution: {tarball: http://registry.npmjs.org/lodash/-/lodash-4.17.15.tgz}\n'))], 0, /unqueried: 1 /);
  await expect('pnpm git and directory entries: unqueried and local', [pnpmCase('pnpm-git', pnpm("  ok@1.0.0:\n    resolution: {integrity: x}\n  dep@https://codeload.github.com/x/y/tar.gz/abc:\n    resolution: {commit: abc, repo: https://github.com/x/y, type: git}\n  'local@file:pkgs/local':\n    resolution: {directory: pkgs/local, type: directory}\n"))], 0,
    /1 packages\)\nlocal: 1 pnpm-lock\.yaml entries are workspace, link or directory packages, not queried\nunqueried: 1 /);

  // N1/C1, 11: the stack reaches the node row; the row union covers nen's stack catalogue.
  for (const stack of ['nextjs', 'gatsby', 'expo', 'react', 'electron', 'node', 'claude-code-plugin', 'bun-cli']) await expect(`stack ${stack} reaches the node row`, [pnpmTree, '--stack', stack], 0, /^resolved: osv npm for pnpm/);
  const hatsuPackage = JSON.parse(readFileSync(join(hatsuRoot, 'package.json'), 'utf8'));
  const hatsuLock = JSON.parse(readFileSync(join(hatsuRoot, 'package-lock.json'), 'utf8'));
  const locked = Object.keys(hatsuLock.packages ?? {}).filter(Boolean);
  assert.deepEqual(Object.keys(hatsuPackage.devDependencies ?? {}), ['vitest'], 'Hatsu must keep a real declared npm development root');
  assert.equal(locked.length, 60, 'Hatsu package-lock non-root entry count changed; keep the scan evidence factual');
  assert.ok(locked.every(path => hatsuLock.packages[path]?.dev === true), 'every current non-root lock entry is a development dependency');
  await expect('Hatsu claude-code-plugin queries its real npm lock, never a scanned-empty declaration',
    [hatsuRoot, '--stack', 'claude-code-plugin', '--query', '--scans', stub], 0,
    /^resolved: osv npm for npm \(no packageManager field, package-lock\.json, 60 packages\)\naudit: 0 finding\(s\) at or above HIGH\/CRITICAL or unrated, 0 unqueried, across 60 packages\n$/);
  await expect('a stack on no node row is not scanned', [pnpmTree, '--stack', 'dotnet-winui'], 3, /stack "dotnet-winui" is not on dependencyAudit\.node\.stacks/);
  // AC-4 (zheref/hatsu#507): every catalogue stack AND every alias is on exactly one row or
  // unrouted; an alias on no row used to pass unread. Proved red on drifted copies first.
  type Audit = Record<string, { stacks?: string[] }> & { stackCatalogue: { stacks: string[]; unrouted: string[]; aliases: string[] } };
  const catalogueCheck = (audit: Audit): { findings: string[]; owners: Map<string, string> } => {
    const catalogue = audit.stackCatalogue;
    const findings: string[] = [];
    const owners = new Map<string, string>();
    for (const [row, value] of Object.entries(audit)) {
      if (row.startsWith('$') || row === 'stackCatalogue') continue;
      if (!Array.isArray(value.stacks) || value.stacks.length === 0) { findings.push(`row ${row} declares no stacks`); continue; }
      for (const s of value.stacks) {
        if (owners.has(s)) findings.push(`stack ${s} is on rows ${owners.get(s)} and ${row}`);
        if (!catalogue.stacks.includes(s) && !catalogue.aliases.includes(s)) findings.push(`row ${row} lists ${s}, which is neither in the catalogue nor a declared alias`);
        owners.set(s, row);
      }
    }
    for (const s of [...catalogue.stacks, ...catalogue.aliases]) {
      if (owners.has(s) === catalogue.unrouted.includes(s)) findings.push(`stack ${s} must be on exactly one row or unrouted, not both or neither`);
    }
    return { findings, owners };
  };
  const liveAudit = (): Audit => JSON.parse(readFileSync(liveScans, 'utf8')).dependencyAudit as Audit;
  const drift = (edit: (a: Audit) => void): string[] => { const a = liveAudit(); edit(a); return catalogueCheck(a).findings; };
  assert.deepEqual(drift((a) => { a.node.stacks = a.node.stacks!.filter((s) => s !== 'bun-cli'); }), ['stack bun-cli must be on exactly one row or unrouted, not both or neither'], 'an alias on no row must fail naming it');
  assert.deepEqual(drift((a) => { a.node.stacks = a.node.stacks!.filter((s) => s !== 'electron'); }), ['stack electron must be on exactly one row or unrouted, not both or neither'], 'a catalogue stack on no row must fail naming it');
  assert.deepEqual(drift((a) => { a.stackCatalogue.stacks.push('bun-tui'); }), ['stack bun-tui must be on exactly one row or unrouted, not both or neither'], 'a new catalogue stack on no row must fail naming it');
  assert.deepEqual(drift((a) => { a.stackCatalogue.unrouted.push('bun-cli'); }), ['stack bun-cli must be on exactly one row or unrouted, not both or neither'], 'a routed stack also marked unrouted must fail naming it');
  pass('AC-4: a stack or alias on no row and not unrouted fails the catalogue check, named');
  const { findings: catalogueFindings, owners } = catalogueCheck(liveAudit());
  assert.deepEqual(catalogueFindings, [], `the live catalogue:\n${catalogueFindings.join('\n')}`);
  for (const s of ['nextjs', 'gatsby', 'expo', 'react', 'electron', 'claude-code-plugin', 'bun-cli']) assert.equal(owners.get(s), 'node', `${s} must route to the node row`);
  pass('every catalogue stack and alias is on exactly one row or named unrouted; every row stack is catalogued or an alias');

  // AC-b: yarn (Berry and classic) and npm each audit their own lockfile.
  await expect('yarn berry', [tree('yarn', { 'package.json': pkg('yarn@4.5.0'), 'yarn.lock': BERRY }), '--query', '--scans', stub], 1,
    /^resolved: osv npm for yarn \(packageManager "yarn@4\.5\.0", yarn\.lock, 1 packages\)\nlocal: 1 yarn\.lock entries[^\n]*\nfinding: GHSA-test-high HIGH "lodash@4\.17\.15"/);
  await expect('a berry patch of a registry package is queried as that package', [tree('yarn-patch', { 'package.json': pkg('yarn@4.5.0'), 'yarn.lock': `${BERRY.split('\n\n"app')[0]}\n\n"resolve@patch:resolve@npm%3A^1.0.0#~builtin<compat/resolve>":\n  version: 1.22.8\n  resolution: "resolve@patch:resolve@npm%3A1.22.8#~builtin<compat/resolve>::version=1.22.8&hash=c3c19d"\n` })], 0, /yarn\.lock, 2 packages\)\n$/);
  await expect('a berry entry with no resolution is refused', [tree('yarn-cut', { 'package.json': pkg('yarn@4.5.0'), 'yarn.lock': '__metadata:\n  version: 8\n\n"lodash@npm:^4.17.15":\n  version: 4.17.15\n' })], 3, /entry "\\"lodash@npm:\^4\.17\.15\\"" has no resolution \(truncated\)/);
  await expect('yarn classic is read by its marker, not its version', [tree('yarn-classic', { 'package.json': pkg('yarn@1.22.22'), 'yarn.lock': CLASSIC }), '--query', '--scans', stub], 1,
    /yarn\.lock, 2 packages\)\nfinding: GHSA-test-high HIGH "lodash@4\.17\.15"\nbelow-floor: GHSA-test-moderate[^\n]*\nfinding: MAL-test-unrated UNRATED "left-pad@1\.0\.0"/);
  await expect('1: a classic npm alias as the only vulnerable entry is queried as the real package', [tree('yarn-alias', { 'package.json': pkg('yarn@1.22.22'), 'yarn.lock': `${CLASSIC_HEAD}"lodash-cjs@npm:lodash@^4.17.15":\n  version "4.17.15"\n  resolved "${REG}/lodash/-/lodash-4.17.15.tgz#abc"\n` }), '--query', '--scans', stub], 1,
    /yarn\.lock, 1 packages\)\nfinding: GHSA-test-high HIGH "lodash@4\.17\.15"/);
  await expect('classic entries with no blank line between them are both read', [tree('yarn-tight', { 'package.json': pkg('yarn@1.22.22'), 'yarn.lock': `${CLASSIC_HEAD}lodash@^4.17.15:\n  version "4.17.15"\nleft-pad@^1.0.0:\n  version "1.0.0"\n` })], 0, /yarn\.lock, 2 packages\)\n$/);
  await expect('a truncated classic block is refused', [tree('yarn-classic-cut', { 'package.json': pkg('yarn@1.22.22'), 'yarn.lock': `${CLASSIC_HEAD}lodash@^4.17.15:\n  version "4.17.15"\n\nleft-pad@^1.0.0:\n` })], 3, /entry "left-pad@\^1\.0\.0" has no version \(truncated\)/);
  await expect('a classic file cut mid-line is refused', [tree('yarn-classic-nl', { 'package.json': pkg('yarn@1.22.22'), 'yarn.lock': `${CLASSIC_HEAD}lodash@^4.17.15:\n  version "4.17` })], 3, /does not end with a newline \(truncated\)/);
  await expect('a classic resolved off registryHosts is unqueried', [tree('yarn-classic-foreign', { 'package.json': pkg('yarn@1.22.22'), 'yarn.lock': `${CLASSIC_HEAD}ok@^1.0.0:\n  version "1.0.0"\nevil@^1.0.0:\n  version "1.0.0"\n  resolved "https://evil.invalid/evil-1.0.0.tgz"\n` })], 0, /1 packages\)\nunqueried: 1 yarn\.lock/);
  await expect('a non-numeric yarn version is never read as classic', [tree('yarn-berry-tag', { 'package.json': pkg('yarn@berry'), 'yarn.lock': BERRY })], 0, /packageManager "yarn@berry", yarn\.lock, 1 packages/);
  await expect('a yarn.lock with neither marker', [tree('yarn-odd', { 'package.json': pkg('yarn@4.0.0'), 'yarn.lock': 'lodash: 1\n' })], 3, /matches neither declared lockfile marker/);
  await expect('npm lockfile v3', [tree('npm3', { 'package.json': pkg('npm@10.9.0'), 'package-lock.json': NPM3 }), '--query', '--scans', stub], 1,
    /package-lock\.json, 2 packages\)\nlocal: 2 package-lock\.json entries[^\n]*\nfinding: GHSA-test-high/);
  await expect('an npm git resolved entry is unqueried', [tree('npm-git', { 'package.json': pkg('npm@10.9.0'), 'package-lock.json': JSON.stringify({ lockfileVersion: 3, packages: { '': {}, 'node_modules/ok': { version: '1.0.0' }, 'node_modules/dep': { version: '1.0.0', resolved: 'git+ssh://git@github.com/x/y.git#abc' } } }) })], 0, /1 packages\)\nunqueried: 1 package-lock\.json/);
  await expect('npm lockfile v1, no field', [tree('npm1', { 'package.json': pkg(), 'package-lock.json': NPM1 })], 0, /for npm \(no packageManager field, package-lock\.json, 2 packages\)/);
  await expect('an npm v1 alias version is queried as the real package', [tree('npm1-alias', { 'package.json': pkg(), 'package-lock.json': JSON.stringify({ lockfileVersion: 1, dependencies: { 'lodash-cjs': { version: 'npm:lodash@4.17.15' } } }) }), '--query', '--scans', stub], 1, /finding: GHSA-test-high HIGH "lodash@4\.17\.15"/);
  await expect('npm-shrinkwrap.json, no field', [tree('shrinkwrap', { 'package.json': pkg(), 'npm-shrinkwrap.json': NPM3 })], 0, /npm-shrinkwrap\.json, 2 packages/);
  await expect('a null npm lockfile', [tree('npm-null', { 'package.json': pkg('npm@10.9.0'), 'package-lock.json': 'null' })], 3, /package-lock\.json is not a JSON object/);
  await expect('an array npm lockfile', [tree('npm-array', { 'package.json': pkg('npm@10.9.0'), 'package-lock.json': '[]' })], 3, /package-lock\.json is not a JSON object/);
  await expect('a BOM-prefixed npm lockfile parses', [tree('npm-bom', { 'package.json': pkg('npm@10.9.0'), 'package-lock.json': `\uFEFF${NPM3}` })], 0, /2 packages\)/);
  await expect('no field and a pnpm-lock.yaml', [tree('pnpm-lock-only', { 'package.json': pkg(), 'pnpm-lock.yaml': PNPM9 })], 0, /for pnpm \(no packageManager field, pnpm-lock\.yaml/);

  // AC-1/AC-2 (zheref/hatsu#507): a bun-cli tree's text bun.lock is parsed strictly and queried.
  const bunTree = tree('bun', { 'package.json': pkg(), 'bun.lock': BUN });
  await expect('AC-1: a bun-cli tree resolves its bun.lock, never not-scanned', [bunTree, '--stack', 'bun-cli'], 0, /^resolved: osv npm for bun \(no packageManager field, bun\.lock, 2 packages\)\n$/);
  seen.length = 0;
  await expect('AC-1: a bun-cli tree is SCANNED: queried and its finding reported', [bunTree, '--stack', 'bun-cli', '--query', '--scans', stub], 1,
    /2 packages\)\nfinding: GHSA-test-high HIGH "lodash@4\.17\.15"\nbelow-floor: GHSA-test-moderate MODERATE "lodash@4\.17\.15"\naudit: 1 finding\(s\) at or above HIGH\/CRITICAL or unrated, 0 unqueried, across 2 packages\n$/);
  const bunBatch = JSON.parse(seen.find((r) => r.url.endsWith('/querybatch'))?.body ?? '{}');
  assert.deepEqual(bunBatch.queries.map((qy: { package: { name: string }; version: string }) => `${qy.package.name}@${qy.version}`).sort(), ['@scope/ok@2.0.0', 'lodash@4.17.15']);
  pass('the bun querybatch carried exactly the lockfile\'s registry packages, the nested key deduplicated');
  const bunCase = (name: string, lock: string, extra: Record<string, string> = {}): string => tree(name, { 'package.json': pkg('bun@1.3.0'), 'bun.lock': lock, ...extra });
  await expect('packageManager bun selects bun.lock', [bunCase('bun-field', BUN)], 0, /^resolved: osv npm for bun \(packageManager "bun@1\.3\.0", bun\.lock, 2 packages\)\n$/);
  for (const v of [0, 1]) await expect(`bun.lock lockfileVersion ${v} is read`, [bunCase(`bun-v${v}`, bunLock('    "ok": ["ok@1.0.0", "", {}, "sha512-c"],\n', v))], 0, /bun\.lock, 1 packages\)\n$/);
  await expect('an unknown bun.lock lockfileVersion is not scanned', [bunCase('bun-future', bunLock('    "ok": ["ok@1.0.0", "", {}, "sha512-c"],\n', 3))], 3, /bun\.lock lockfileVersion is not one this parser reads \(0, 1, 2\)/);
  await expect('a bun alias key is queried as the real package', [bunCase('bun-alias', bunLock('    "lodash-cjs": ["lodash@4.17.15", "", {}, "sha512-a"],\n    "ms-old": ["ms-old@npm:ms@0.0.1", "", {}, "sha512-d"],\n')), '--query', '--scans', stub], 1,
    /2 packages\)\nfinding: GHSA-test-high HIGH "lodash@4\.17\.15"\nbelow-floor: GHSA-test-moderate[^\n]*\nfinding: GHSA-test-unknown UNRATED "ms@0\.0\.1"/);
  await expect('a comma inside a bun string is data, not a trailing comma', [bunCase('bun-string', bunLock('    "ok": ["ok@1.0.0", "", { "bin": "a,}\\\",]" }, "sha512-,]"],\n'))], 0, /bun\.lock, 1 packages\)\n$/);
  await expect('bun workspace and root entries are local; link, git, github, tarball and file entries are unqueried', [bunCase('bun-kinds', bunLock([
    '    "ok": ["ok@1.0.0", "", {}, "sha512-c"],',
    '    "ws": ["ws@workspace:packages/ws"],',
    '    "lk": ["lk@link:lk", {}],',
    '    "rt": ["rt@root:", {}],',
    '    "g": ["g@git+https://github.com/x/g.git#abc", {}, "x-g-abc"],',
    '    "gh": ["gh@github:x/gh#abc", {}, "x-gh-abc"],',
    '    "tb": ["tb@https://evil.invalid/tb-1.0.0.tgz", {}],',
    '    "fl": ["fl@file:../fl", {}],',
  ].join('\n') + '\n')), '--query', '--scans', stub], 1,
    /1 packages\)\nlocal: 2 bun\.lock entries are workspace, link or directory packages, not queried\nunqueried: 5 bun\.lock entries come from git, file: or a host off registryHosts -- never clean\naudit: 0 finding\(s\) .*, 5 unqueried, across 1 packages\n$/);
  await expect('a bun registry slot on registryHosts is queried; off it, or over http, is unqueried', [bunCase('bun-registry', bunLock([
    '    "lodash": ["lodash@4.17.15", "https://registry.npmjs.org/", {}, "sha512-a"],',
    '    "evil": ["evil@1.0.0", "https://evil.invalid/", {}, "sha512-e"],',
    '    "plain": ["plain@1.0.0", "http://registry.npmjs.org/", {}, "sha512-f"],',
  ].join('\n') + '\n')), '--query', '--scans', stub], 1, /1 packages\)\nunqueried: 2 bun\.lock[^\n]*\nfinding: GHSA-test-high HIGH "lodash@4\.17\.15"/);
  // AC-2: a lock the row cannot parse is NOT SCANNED, named, never a pass.
  await expect('AC-2: a comment in bun.lock is not scanned', [bunCase('bun-comment', BUN.replace('"packages": {', '"packages": { // pinned'))], 3, /^not scanned: bun\.lock does not parse as JSON with trailing commas\n$/);
  await expect('AC-2: a doubled comma in bun.lock is not scanned', [bunCase('bun-double', BUN.replace('"sha512-b"],', '"sha512-b"],,'))], 3, /bun\.lock does not parse as JSON with trailing commas\n$/);
  await expect('AC-2: a leading comma in a bun object is not scanned', [bunCase('bun-leading', BUN.replace('"packages": {', '"packages": {,'))], 3, /bun\.lock does not parse as JSON with trailing commas\n$/);
  await expect('AC-2: a bun.lock cut mid-entry is not scanned', [bunCase('bun-cut', BUN.slice(0, BUN.indexOf('"@scope/ok":') + 8))], 3, /bun\.lock does not end with a newline \(truncated\)/);
  await expect('AC-2: a bun entry that is not a tuple is not scanned', [bunCase('bun-object', bunLock('    "ok": { "version": "1.0.0" },\n'))], 3, /bun\.lock entry "ok" is not a package tuple/);
  await expect('AC-2: a bun spec with no name is not scanned', [bunCase('bun-noname', bunLock('    "ok": ["@1.0.0", "", {}, "sha512-c"],\n'))], 3, /bun\.lock entry "ok" names no <name>@<spec>/);
  await expect('AC-2: a registry-shaped bun tuple of the wrong shape is not scanned', [bunCase('bun-short', bunLock('    "ok": ["ok@1.0.0", {}],\n'))], 3, /entry "ok" is registry-shaped but not a \[spec, registry, metadata, integrity\] tuple/);
  await expect('AC-2: a registry-shaped bun version that does not parse is not scanned', [bunCase('bun-badver', bunLock('    "lodash": ["lodash@latest", "", {}, "sha512-a"],\n'))], 3, /entry "lodash@latest" is registry-shaped but its name or version does not parse/);
  await expect('AC-2: a bun.lock with no packages object is not scanned', [bunCase('bun-nopackages', '{\n  "lockfileVersion": 1,\n}\n')], 3, /bun\.lock has no packages object/);
  await expect('AC-2: a bun.lock with only workspace packages parses to nothing', [bunCase('bun-empty', bunLock('    "ws": ["ws@workspace:packages/ws"],\n'))], 3, /no packages parsed from bun\.lock/);
  await expect('AC-2: an array bun.lock is not scanned', [bunCase('bun-array', '[]\n')], 3, /bun\.lock is not a JSON object/);
  await expect('AC-2: the binary bun.lockb under a bun field is not scanned, named', [tree('bun-lockb-field', { 'package.json': pkg('bun@1.1.0'), 'bun.lockb': '\u0000bun-lockfile-format-v0\n' })], 3, /^not scanned: packageManager "bun@1\.1\.0" but its only lockfile is bun\.lockb, which has no dependencyAudit\.node parser\n$/);
  await expect('bun.lock beside bun.lockb: the text lock is audited, the binary named', [tree('bun-both', { 'package.json': pkg(), 'bun.lock': BUN, 'bun.lockb': '\u0000' })], 0, /bun\.lock, 2 packages\)\naudit-config: "bun\.lockb" "other-lockfile" -- not audited; evidence for Feitan\n$/);
  await expect('more bun entries than maxEntries is not scanned', [bunTree, '--scans', contract('few-bun', (n) => { n.maxEntries = 2; })], 3, /bun\.lock has more than 2 entries \(maxEntries\)/);
  // zheref/hatsu#507 round 1 (Feitan F2, Nobunaga N1): link: and out-of-tree paths are not the tree's own code.
  await expect('a bun workspace or root path that is absolute or climbs out is unqueried; link: is unqueried', [bunCase('bun-outside', bunLock([
    '    "ok": ["ok@1.0.0", "", {}, "sha512-c"],',
    '    "in": ["in@workspace:packages/in"],',
    '    "up": ["up@workspace:../../../outside"],',
    '    "abs": ["abs@workspace:/opt/abs"],',
    '    "win": ["win@workspace:C:\\\\abs"],',
    '    "deep": ["deep@root:packages/../../x", {}],',
    '    "lk": ["lk@link:evil", {}],',
  ].join('\n') + '\n')), '--query', '--scans', stub], 1,
    /1 packages\)\nlocal: 1 bun\.lock entries [^\n]*\nunqueried: 5 bun\.lock entries [^\n]*\naudit: 0 finding\(s\) .*, 5 unqueried, across 1 packages\n$/);
  // Feitan F3: a key repeated in one object is not scanned, never the last one audited.
  await expect('AC-2: a duplicate bun.lock packages key is not scanned', [bunCase('bun-dup', bunLock('    "lodash": ["lodash@4.17.20", "", {}, "sha512-a"],\n    "lodash": ["lodash@4.17.21", "", {}, "sha512-b"],\n'))], 3, /^not scanned: bun\.lock repeats the key "lodash" in one object \(duplicate\)\n$/);
  await expect('AC-2: a duplicate key spelled with an escape is still a duplicate', [bunCase('bun-dup-escape', bunLock('    "ok": ["ok@1.0.0", "", {}, "sha512-a"],\n    "\\u006fk": ["ok@1.0.1", "", {}, "sha512-b"],\n'))], 3, /repeats the key "ok" in one object \(duplicate\)/);
  await expect('the same key in two different objects is not a duplicate', [bunCase('bun-dup-nested', bunLock('    "a": ["a@1.0.0", "", { "dependencies": { "x": "1" } }, "sha512-a"],\n    "b": ["b@1.0.0", "", { "dependencies": { "x": "1" } }, "sha512-b"],\n'))], 0, /bun\.lock, 2 packages\)\n$/);
  // Feitan's behaviour note: no field with npm's and bun's lockfiles is now ambiguous, never npm alone.
  await expect('no field with package-lock.json and bun.lock is ambiguous, not scanned', [tree('npm-and-bun', { 'package.json': pkg(), 'package-lock.json': NPM3, 'bun.lock': BUN })], 3, /package-lock\.json, bun\.lock are all present \(ambiguous\)/);
  await expect('a symlinked bun.lock is never followed', [(() => { const d = tree('bun-symlink', { 'package.json': pkg() }); symlinkSync(join(bunTree, 'bun.lock'), join(d, 'bun.lock')); return d; })()], 3, /bun\.lock is a symlink, never followed/);

  // 8: a deep or huge lockfile is not scanned, never an uncaught exit 1.
  let deep = '{"version":"1.0.0"}';
  for (let i = 0; i < 20000; i += 1) deep = `{"version":"1.0.0","dependencies":{"d${i}":${deep}}}`;
  await expect('a 20,000-deep npm v1 nest is not scanned (maxDepth)', [tree('npm-deep', { 'package.json': pkg('npm@6.0.0'), 'package-lock.json': `{"lockfileVersion":1,"dependencies":{"top":${deep}}}` })], 3, /nests dependencies deeper than 1000 \(maxDepth\)/);
  await expect('more entries than maxEntries is not scanned', [pnpmTree, '--scans', contract('few', (n) => { n.maxEntries = 1; })], 3, /has more than 1 entries \(maxEntries\)/);

  // 5: another manager's lockfile beside the selected one is evidence.
  await expect('a decoy lockfile beside the selected one is named', [tree('decoy', { 'package.json': pkg('pnpm@9.15.9'), 'pnpm-lock.yaml': PNPM9, 'package-lock.json': NPM3, 'bun.lock': '{}' })], 0,
    /audit-config: "package-lock\.json" "other-lockfile" -- not audited; evidence for Feitan\naudit-config: "bun\.lock" "other-lockfile"/);

  // F1-F3/F6: nothing in the tree runs and nothing of the caller's environment leaves.
  const hostile = tree('hostile', {
    'package.json': pkg('pnpm@https://evil.invalid/pnpm.tgz', { scripts: { preinstall: `touch ${marker}` }, pnpm: { auditConfig: { ignoreCves: ['CVE-1'] } } }),
    'pnpm-lock.yaml': PNPM9,
    '.pnpmfile.cjs': `require('fs').writeFileSync(${JSON.stringify(marker)}, process.env.FEITAN_CANARY || '')\n`,
    '.yarnrc.yml': `yarnPath: ./evil.cjs\nnpmRegistryServer: "http://127.0.0.1:${port}"\nnpmAuditIgnoreAdvisories: ["*"]\n`,
    'evil.cjs': `require('fs').writeFileSync(${JSON.stringify(marker)}, 'yarn')\n`,
    '.corepack.env': 'COREPACK_ENABLE_UNSAFE_CUSTOM_URLS=1\nCOREPACK_NPM_REGISTRY=http://127.0.0.1:1\nCOREPACK_INTEGRITY_KEYS=0\n',
    '.npmrc': `registry=http://127.0.0.1:${port}/\n@corp:registry=http://127.0.0.1:${port}/\n//127.0.0.1:${port}/:_authToken=\${FEITAN_CANARY}\naudit=false\n`,
    'pnpm-workspace.yaml': 'auditConfig:\n  ignoreGhsas: ["GHSA-test-high"]\n',
  });
  seen.length = 0;
  const hostileOut = await expect('a hostile tree: redirect and suppression keys are evidence, the finding stands', [hostile, '--query', '--scans', stub], 1, /finding: GHSA-test-high HIGH "lodash@4\.17\.15"/);
  for (const line of ['".npmrc" "registry"', '".npmrc" "*:registry"', '".npmrc" "audit"', '"package.json" "pnpm.auditConfig"', '"pnpm-workspace.yaml" "auditConfig"', '".yarnrc.yml" "npmRegistryServer"', '".yarnrc.yml" "npmAuditIgnoreAdvisories"']) {
    assert.ok(hostileOut.includes(`audit-config: ${line} -- not honoured`), `missing audit-config ${line}\n${hostileOut}`);
  }
  assert.ok(!hostileOut.includes(CANARY), 'the canary value was printed');
  assert.equal(existsSync(marker), false, 'a tree hook (.pnpmfile.cjs, yarnPath, a lifecycle script) ran');
  assert.ok(seen.length > 0 && seen.every((r) => r.url.startsWith('/m/ok/')), 'only the contract endpoints were contacted');
  for (const r of seen) {
    assert.equal(r.headers.authorization, undefined, 'an Authorization header reached the endpoint');
    assert.ok(!JSON.stringify(r).includes(CANARY), 'the caller environment reached the endpoint');
  }
  assert.doesNotMatch(readFileSync(resolver, 'utf8'), /child_process|process\.env|\bexec(File)?Sync\b|\bspawn\b/, 'the resolver must execute nothing and read no environment');
  pass('no hook ran, no token or canary was sent, the resolver executes nothing');

  // AC-3 (zheref/hatsu#507): a hostile bun tree -- bunfig.toml preload, install scanner,
  // registry and scoped token -- runs nothing; its redirect keys are evidence only.
  const hostileBun = tree('hostile-bun', {
    'package.json': pkg('bun@1.3.0', { scripts: { preinstall: `touch ${marker}`, postinstall: `touch ${marker}` } }),
    'bun.lock': BUN,
    'bunfig.toml': `preload = ["./evil.ts"]\n\n[install]\nregistry = "http://127.0.0.1:${port}/"\n\n[install.scopes]\ncorp = { url = "http://127.0.0.1:${port}/", token = "$FEITAN_CANARY" }\n\n[install.security]\nscanner = "./evil.ts"\n`,
    'evil.ts': `require('fs').writeFileSync(${JSON.stringify(marker)}, process.env.FEITAN_CANARY || 'bun')\n`,
    '.npmrc': `registry=http://127.0.0.1:${port}/\n//127.0.0.1:${port}/:_authToken=\${FEITAN_CANARY}\n`,
  });
  seen.length = 0;
  const hostileBunOut = await expect('AC-3: a hostile bun tree: bunfig and npmrc keys are evidence, the finding stands', [hostileBun, '--stack', 'bun-cli', '--query', '--scans', stub], 1, /finding: GHSA-test-high HIGH "lodash@4\.17\.15"/);
  for (const line of ['".npmrc" "registry"', '"bunfig.toml" "install.registry"', '"bunfig.toml" "install.scopes"', '"bunfig.toml" "install.security.scanner"']) {
    assert.ok(hostileBunOut.includes(`audit-config: ${line} -- not honoured`), `missing audit-config ${line}\n${hostileBunOut}`);
  }
  assert.ok(!hostileBunOut.includes(CANARY), 'the canary value was printed');
  assert.equal(existsSync(marker), false, 'a bun tree hook (bunfig preload, install scanner, a lifecycle script) ran');
  assert.ok(seen.length > 0 && seen.every((r) => r.url.startsWith('/m/ok/') && r.headers.authorization === undefined && !JSON.stringify(r).includes(CANARY)), 'only the contract endpoints were contacted, with no token or canary');
  pass('AC-3: no bun hook ran, no token or canary was sent');
  const quotedBun = await expect('an unescaped quoted or dotted bunfig key is read', [tree('bunfig-quoted', { 'package.json': pkg(), 'bun.lock': BUN, 'bunfig.toml': `"install" . 'registry' = "https://evil.invalid/"\ninstall.scopes.corp = "https://evil.invalid/"\n` })], 0, /bun\.lock, 2 packages\)\n/);
  for (const key of ['install.registry', 'install.scopes']) assert.ok(quotedBun.includes(`audit-config: "bunfig.toml" "${key}" -- not honoured`), `missing ${key}\n${quotedBun}`);
  const inlineBun = await expect('an inline install table in bunfig is read', [tree('bunfig-inline', { 'package.json': pkg(), 'bun.lock': BUN, 'bunfig.toml': `install = { registry = "https://evil.invalid/" }\n` })], 0, /bun\.lock, 2 packages\)\n/);
  assert.ok(inlineBun.includes('audit-config: "bunfig.toml" "install.registry" -- not honoured'), inlineBun);
  const bunfigOut = (name: string, toml: string): Promise<string> => expect(name, [tree(`bunfig-${cases}`, { 'package.json': pkg(), 'bun.lock': BUN, 'bunfig.toml': toml })], 0, /bun\.lock, 2 packages\)\n/);
  const READ = 'audit-config: "bunfig.toml" "install.registry" -- not honoured';
  const MENTIONED = 'audit-config: "bunfig.toml" "install.registry" -- its token "registry" appears outside a key this scanner read';
  for (const [name, toml] of [['a quoted header', '["install"]\nregistry = "https://evil.invalid/"\n'], ['a quoted table, dotted', '"install".registry = "https://evil.invalid/"\n'], ['a quoted key', '[install]\n"registry" = "https://evil.invalid/"\n'], ['a multi-line array before the table', 'preload = [\n  "./a.ts",\n  "./b.ts",\n]\n[install]\nregistry = "https://evil.invalid/"\n']]) {
    const read = await bunfigOut(`an unescaped bunfig spelling is read: ${name}`, toml);
    assert.ok(read.includes(READ) && !read.includes('"unread"'), `${name}\n${read}`);
  }
  // Feitan F1, Nobunaga N2: spellings the line scanner cannot place fail toward evidence.
  const lost: Array<[string, string, number]> = [
    ['a multi-line inline table', 'install = {\n  registry = "https://evil.invalid/"\n}\n', 1],
    ['a """ string holding a [other] line', '[install]\nnote = """\n[other]\n"""\nregistry = "https://evil.invalid/"\n', 2],
    ["a ''' string", "x = '''\n'''\n[install]\nregistry = \"https://evil.invalid/\"\n", 1],
    ['an escaped key', '[install]\n"re\\u0067istry" = "https://evil.invalid/"\n', 2],
    ['an escaped header', '["\\u0069nstall"]\nregistry = "https://evil.invalid/"\n', 1],
  ];
  for (const [name, toml, line] of lost) {
    const out = await bunfigOut(`a bunfig ${name} prints unread and the registry token`, toml);
    assert.match(out, new RegExp(`audit-config: "bunfig\\.toml" "unread" -- \\d+ line\\(s\\) this scanner cannot place, first line ${line}; evidence for Feitan`), `${name}\n${out}`);
    assert.ok(out.includes(READ) || out.includes(MENTIONED), `${name}: install.registry must be evidence\n${out}`);
  }
  const tokenOnly = await bunfigOut('a registry token in a value is mentioned, never silent', '[install.scopes]\ncorp = "https://registry.example.invalid/"\n');
  assert.ok(tokenOnly.includes(MENTIONED) && tokenOnly.includes('"install.scopes" -- not honoured'), tokenOnly);
  const plainBun = await bunfigOut('a bunfig with no redirect key prints no audit-config line', 'preload = ["./a.ts"]\n\n[test]\ncoverage = true\n');
  assert.ok(!plainBun.includes('audit-config:'), plainBun);
  pass('bunfig.toml: keys the scanner reads are evidence; a line it cannot place is unread, and a leaf token anywhere is mentioned');

  // AC-c and the hardening: nothing usable is NOT SCANNED, named.
  await expect('the pnpm field without its lockfile', [tree('pnpm-no-lock', { 'package.json': pkg('pnpm@9.15.9'), 'package-lock.json': NPM3 })], 3, /packageManager "pnpm@9\.15\.9" but no pnpm-lock\.yaml to audit/);
  await expect('no package.json', [tree('empty', {})], 3, /no package\.json at the root of the path/);
  const dirManifest = tree('dir-manifest', { 'pnpm-lock.yaml': PNPM9 });
  mkdirSync(join(dirManifest, 'package.json'));
  await expect('a package.json that is a directory', [dirManifest], 3, /package\.json is not a regular file/);
  await expect('an unparseable package.json names no content', [tree('bad-json', { 'package.json': '{"secret-ish' })], 3, /^not scanned: package\.json does not parse as JSON\n$/);
  await expect('a BOM-prefixed package.json parses', [tree('bom', { 'package.json': `\uFEFF${pkg('pnpm@9.15.9')}`, 'pnpm-lock.yaml': PNPM9 })], 0, /^resolved: osv npm for pnpm/);
  await expect('a null package.json', [tree('null-json', { 'package.json': 'null' })], 3, /package\.json is not a JSON object/);
  await expect('an array package.json', [tree('array-json', { 'package.json': '[]', 'pnpm-lock.yaml': PNPM9 })], 3, /package\.json is not a JSON object/);
  await expect('a non-string packageManager', [tree('non-string', { 'package.json': '{"packageManager":9}' })], 3, /packageManager is not a string/);
  await expect('a malformed packageManager', [tree('malformed', { 'package.json': pkg('pnpm'), 'pnpm-lock.yaml': PNPM9 })], 3, /packageManager "pnpm" is not <name>@<version>/);
  const forged = await expect('a packageManager carrying a newline cannot forge lines', [tree('forged', { 'package.json': pkg('pnpm@9\naudit: 0 finding(s)\nscanned: x'), 'pnpm-lock.yaml': PNPM9 })], 3, /^not scanned: packageManager carries control characters\n$/);
  assert.equal(forged.split('\n').length, 2);
  await expect('a manager with no row', [tree('cnpm', { 'package.json': pkg('cnpm@9.0.0'), 'package-lock.json': NPM3 })], 3, /packageManager names "cnpm", which has no dependencyAudit\.node manager/);
  await expect('a binary bun.lockb with no field gets its own reason', [tree('bun-lockb', { 'package.json': pkg(), 'bun.lockb': '\u0000' })], 3, /bun\.lockb is a bun lockfile, which has no dependencyAudit\.node parser/);
  await expect('a prototype key is not a row', [tree('proto', { 'package.json': pkg('constructor@1.0.0') })], 3, /names "constructor", which has no dependencyAudit\.node manager/);
  await expect('no field and two lockfiles is ambiguous', [tree('ambiguous', { 'package.json': pkg(), 'pnpm-lock.yaml': PNPM9, 'package-lock.json': NPM3 })], 3, /are all present \(ambiguous\)/);
  await expect('no field and no lockfile', [tree('lockless', { 'package.json': pkg() })], 3, /no packageManager field and no lockfile to audit/);
  await expect('a lockfile that parses to no package', [tree('pnpm-empty', { 'package.json': pkg('pnpm@9.15.9'), 'pnpm-lock.yaml': "lockfileVersion: '9.0'\n" })], 3, /no packages parsed from pnpm-lock\.yaml/);
  const outside = join(scratch, 'outside-secret.json');
  writeFileSync(outside, '{"packageManager":"pnpm@9.15.9", "token": "OUTSIDE-SECRET"');
  const linkPkg = tree('symlink-pkg', { 'pnpm-lock.yaml': PNPM9 });
  symlinkSync(outside, join(linkPkg, 'package.json'));
  assert.ok(!(await expect('a symlinked package.json is never followed', [linkPkg], 3, /package\.json is a symlink, never followed/)).includes('OUTSIDE'), 'outside content leaked');
  const linkLock = tree('symlink-lock', { 'package.json': pkg('pnpm@9.15.9') });
  symlinkSync(outside, join(linkLock, 'pnpm-lock.yaml'));
  await expect('a symlinked lockfile is never followed', [linkLock], 3, /pnpm-lock\.yaml is a symlink, never followed/);
  const dirLock = tree('dir-lock', { 'package.json': pkg('pnpm@9.15.9') });
  mkdirSync(join(dirLock, 'pnpm-lock.yaml'));
  await expect('a lockfile that is a directory', [dirLock], 3, /pnpm-lock\.yaml is not a regular file/);

  // 2, 3, 10, P1: OSV answers that are malformed, oversized, slow or failing are never clean.
  for (const mode of ['null-result', 'string-result', 'null-vulns']) await expect(`2: a querybatch result that is ${mode} is not scanned`, [pnpmTree, '--query', '--scans', modeContract(mode)], 3, /not scanned: OSV returned a malformed querybatch response\n$/);
  await expect('3: severities outside severityLevels are UNRATED and count', [tree('odd-severity', { 'package.json': pkg('pnpm@9.15.9'), 'pnpm-lock.yaml': pnpm('  minimist@0.0.8:\n    resolution: {integrity: a}\n  ms@0.0.1:\n    resolution: {integrity: b}\n') }), '--query', '--scans', stub], 1,
    /finding: GHSA-test-severe UNRATED "minimist@0\.0\.8"\nfinding: GHSA-test-unknown UNRATED "ms@0\.0\.1"\naudit: 2 finding/);
  await expect('10: a response over maxResponseBytes is not scanned', [pnpmTree, '--query', '--scans', modeContract('big', (n) => { n.maxResponseBytes = 64; })], 3, /OSV response exceeded 64 bytes \(maxResponseBytes\)\n$/);
  await expect('a hanging OSV times out, not scanned', [pnpmTree, '--query', '--scans', modeContract('hang', (n) => { n.timeoutSeconds = 1; })], 3, /not scanned: OSV query timed out after 1s\n$/);
  await expect('an OSV error answer is not scanned', [pnpmTree, '--query', '--scans', modeContract('down')], 3, /not scanned: OSV answered HTTP 503 at 127\.0\.0\.1:\d+\n$/);
  await expect('an unreachable OSV is not scanned', [pnpmTree, '--query', '--scans', contract('closed', (n) => { n.endpoint = 'http://127.0.0.1:1/v1/querybatch'; })], 3, /not scanned: OSV unreachable at 127\.0\.0\.1:1\n$/);

  // 9: a long verdict reaches a piped reader whole.
  const bulk = Array.from({ length: 2500 }, (_, i) => `  bulk${i}@1.0.0:\n    resolution: {integrity: x}\n`).join('');
  const bulkOut = await expect('9: 2,500 findings reach the pipe with the audit line last', [tree('bulk', { 'package.json': pkg('pnpm@9.15.9'), 'pnpm-lock.yaml': pnpm(bulk) }), '--query', '--scans', stub], 1, /\naudit: 2500 finding\(s\) [^\n]*across 2500 packages\n$/);
  assert.equal(bulkOut.split('\n').filter((l) => l.startsWith('finding: ')).length, 2500);
  pass('every one of the 2,500 finding lines arrived');

  // Wiring stops are exit 2 on stderr, never a verdict.
  await expect('no path argument', [], 2, /^$/);
  await expect('two path arguments', [pnpmTree, pnpmTree], 2, /^$/);
  await expect('an unknown flag', [pnpmTree, '--run'], 2, /^$/);
  await expect('a malformed --stack', [pnpmTree, '--stack', 'Next JS'], 2, /^$/);
  await expect('an empty --stack is refused, never passed through', [pnpmTree, '--stack', ''], 2, /^$/);
  await expect('a path that is not a directory', [join(pnpmTree, 'package.json')], 2, /^$/);
  await expect('an unreadable scans contract', [pnpmTree, '--scans', join(scratch, 'missing.json')], 2, /^$/);
  const malformed: Array<[string, (n: Record<string, unknown>) => void]> = [
    ['the retired run-row manager shape', (n) => { n.managers = { pnpm: { run: 'pnpm audit --audit-level=high', lockfiles: ['pnpm-lock.yaml'], format: 'pnpm-lock' } }; }],
    ['a non-https endpoint off loopback', (n) => { n.endpoint = 'http://osv.example/v1/querybatch'; }],
    ['a zero timeout', (n) => { n.timeoutSeconds = 0; }],
    ['8: a lockfileMarkers regex that does not compile', (n) => { (n.managers as Record<string, { lockfileMarkers: Record<string, string> }>).yarn.lockfileMarkers.berry = '(['; }],
    ['14: unsupportedLockfiles that is an array', (n) => { n.unsupportedLockfiles = ['bun.lock']; }],
    ['14: unsupportedLockfiles with a non-string value', (n) => { n.unsupportedLockfiles = { 'bun.lock': 1 }; }],
    ['14: auditConfigKeys that is not an object', (n) => { n.auditConfigKeys = 'npmrc'; }],
    ['14: auditConfigKeys with a non-string entry', (n) => { n.auditConfigKeys = { '.npmrc': ['registry', 7] }; }],
    ['14: maxResponseBytes of 0', (n) => { n.maxResponseBytes = 0; }],
    ['14: maxDepth that is not an integer', (n) => { n.maxDepth = '1000'; }],
    ['14: an unknown row key', (n) => { n.registry = 'https://evil.invalid'; }],
    ['14: an unknown manager key', (n) => { (n.managers as Record<string, Record<string, unknown>>).pnpm.run = 'pnpm audit'; }],
    ['14: lockfileMarkers on a non-yarn manager', (n) => { (n.managers as Record<string, Record<string, unknown>>).npm.lockfileMarkers = { berry: 'x', classic: 'y' }; }],
    ['an unknown lockfile format', (n) => { (n.managers as Record<string, Record<string, unknown>>).bun.format = 'bun-lockb'; }],
    ['a severityFloor outside severityLevels', (n) => { n.severityFloor = ['SEVERE']; }],
    ['registryHosts that is empty', (n) => { n.registryHosts = []; }],
  ];
  for (const [name, edit] of malformed) await expect(`${name} is refused`, [pnpmTree, '--scans', contract(`bad-${cases}`, edit)], 2, /^$/);
  const defaults = contract('defaults', (n) => { delete n.unsupportedLockfiles; delete n.auditConfigKeys; delete n.maxResponseBytes; delete n.maxEntries; delete n.maxDepth; });
  await expect('14: absent optional keys take their documented defaults', [pnpmTree, '--query', '--scans', defaults], 1, /finding: GHSA-test-high/);

  console.log(`1..${cases}`);
} finally {
  server.closeAllConnections();
  server.close();
  rmSync(scratch, { recursive: true, force: true });
}
