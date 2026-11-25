// Compose published Nen decisions for a mixed-gate run. Never manufacture readiness or prompt facts.
import { execFileSync, spawnSync } from 'node:child_process';
import { readFileSync, lstatSync, mkdirSync, mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { join, resolve, dirname } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
const hatsu = resolve(dirname(fileURLToPath(import.meta.url)), '..');
type Gate = 'G2' | 'G4';
type Holding = { id: string; why: string };
type Plane = { plane: string; cap: number; occupied: number; free: number; holding: Holding[]; binding: boolean };
type Effort = { id: string; pr: number | null; plane: 'ci' | 'local'; [key: string]: unknown };
type Report = { ci: Plane; local: Plane; done: string[]; localSlotFrees: unknown;
  fromRun: { run: string; efforts: Effort[]; notEfforts: number[]; closedUnmerged: number[];
    unread: { pr: number; reason: string }[]; claims: string; parkedClaims: string[]; claimsUnread: string | null } };
function fail(message: string): never { throw new Error(`slots: ${message}`); }
function call(exe: string, args: string[], root: string): string {
  return execFileSync(exe, args, { cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], maxBuffer: 16 * 1024 * 1024 }).trim();
}
function json(exe: string, args: string[], root: string): any { return JSON.parse(call(exe, args, root)); }
const equal = (a: unknown, b: unknown): boolean => JSON.stringify(a) === JSON.stringify(b);
function safeRead(path: string): string {
  if (lstatSync(path).isSymbolicLink() || !lstatSync(path).isFile()) fail(`unsafe manifest ${path}`);
  return readFileSync(path, 'utf8');
}
// Both documented 0.31 homes are read-only here. Nen still validates the selected run itself.
function manifestSnapshot(common: string, id: string): { path: string; text: string } {
  const present = (path: string): boolean => {
    try { lstatSync(path); return true; }
    catch (error) { if ((error as NodeJS.ErrnoException).code === 'ENOENT') return false; throw error; }
  };
  const homes = [join(common, '.nen', 'runs'), join(common, 'hatsu', 'runs')];
  for (const home of homes) for (const path of [dirname(home), home])
    if (present(path) && (lstatSync(path).isSymbolicLink() || !lstatSync(path).isDirectory())) fail('unsafe manifest directory');
  const candidates = homes.map(home => join(home, `${id}.json`)).filter(present);
  if (candidates.length !== 1) fail('manifest missing or present in multiple homes');
  return { path: candidates[0]!, text: safeRead(candidates[0]!) };
}
export function slots(root: string, runId: string, target: string, common: string): number {
  const authority = json('gh', ['repo', 'view', '--json', 'nameWithOwner'], root).nameWithOwner;
  if (typeof authority !== 'string' || authority.toLowerCase() !== target.toLowerCase()) fail('run belongs to another repository');
  const scratch = mkdtempSync(join(tmpdir(), 'hatsu-prompt-gates-'));
  try {
  // Installed Hatsu supplies roles and canonical path declarations, never the consumer PR tree.
  let classified = json('nen', ['repo', 'classify', '--target', authority, '--repo', hatsu, '--json'], hatsu);
  let registryRef: string | null = null;
  if (classified.target?.toLowerCase() !== authority.toLowerCase()) fail('classified repository mismatch');
  if (classified.role === 'unregistered') {
    // A consumer's declaration is absent from the installed registry. Read its immutable default
    // commit, never its PR checkout; known installed canon roles cannot be downgraded here.
    const metadata = json('gh', ['api', `repos/${authority}`], root);
    if (typeof metadata.default_branch !== 'string' || !metadata.default_branch) fail('default branch unread');
    registryRef = call('gh', ['api', `repos/${authority}/commits/${encodeURIComponent(metadata.default_branch)}`, '--jq', '.sha'], root);
    if (!/^[a-f0-9]{40}$/i.test(registryRef)) fail('default commit unread');
    const registry = call('gh', ['api', `repos/${authority}/contents/nen/repos.json?ref=${registryRef}`,
      '--header', 'Accept: application/vnd.github.raw+json'], root);
    mkdirSync(join(scratch, 'nen'));
    writeFileSync(join(scratch, 'nen/repos.json'), registry);
    classified = json('nen', ['repo', 'classify', '--target', authority, '--repo', scratch, '--json'], scratch);
  }
  if (classified.target?.toLowerCase() !== authority.toLowerCase() || !['canon', 'consumer', 'spec'].includes(classified.role)) fail('repository role unread');
  const { path: manifestPath, text: manifestText } = manifestSnapshot(common, runId);
  const manifest = JSON.parse(manifestText);
  if (manifest.id !== runId || manifest.repo?.toLowerCase() !== authority.toLowerCase() || !Array.isArray(manifest.prs)) fail('manifest identity unread');
  const rows = manifest.prs.filter((row: any) => row.kind === 'delivery');
  const ids = rows.map((row: any) => row.pr);
  if (ids.some((id: unknown) => !Number.isSafeInteger(id) || Number(id) < 1) || new Set(ids).size !== ids.length) fail('delivery identities unread');
  const declarations = JSON.parse(readFileSync(join(hatsu, 'contracts/pr-composition.json'), 'utf8')).gateDerive;
  const paths = declarations[authority.toLowerCase()];
  const snapshots = new Map<number, unknown>();
  const gates = new Map<number, Gate>();
  const snapshot = (pr: number) => {
    const value = json('gh', ['pr', 'view', String(pr), '--repo', authority, '--json', 'headRefOid,baseRefOid,baseRefName,headRefName,state,changedFiles'], root);
    if (!/^[a-f0-9]{40}$/i.test(value.headRefOid) || !/^[a-f0-9]{40}$/i.test(value.baseRefOid) ||
        !['OPEN', 'CLOSED', 'MERGED'].includes(value.state) || !Number.isSafeInteger(value.changedFiles) || value.changedFiles < 0) fail(`PR #${pr} snapshot unread`);
    return value;
  };
    for (const pr of ids) {
      const before = snapshot(pr);
      snapshots.set(pr, before);
      if (before.state !== 'OPEN') continue; // Terminal decisions never consult a prompt receipt.
      let gate: Gate = 'G2';
      if (classified.role === 'canon') {
        if (!paths || !Array.isArray(paths.policyPaths) || !Array.isArray(paths.processPaths)) fail('canon has no declared gate paths');
        if (before.changedFiles < 1) fail(`PR #${pr} changed paths empty`);
        const pages = json('gh', ['api', `repos/${authority}/pulls/${pr}/files`, '--paginate', '--slurp'], root);
        if (!Array.isArray(pages) || pages.some((page: unknown) => !Array.isArray(page))) fail(`PR #${pr} changed paths unread`);
        const files = pages.flat();
        if (files.length !== before.changedFiles) fail(`PR #${pr} changed paths incomplete`);
        const names = files.flatMap((file: any) => [file.filename, ...(file.previous_filename ? [file.previous_filename] : [])]);
        if (names.some((name: unknown) => typeof name !== 'string' || !name || /[\r\n]/.test(name))) fail(`PR #${pr} ambiguous changed path`);
        // WORKFLOW's explicit fail-closed rule for new Nen top-level entries.
        if (authority.toLowerCase() === 'zheref/nen' && names.some((name: string) =>
          !['LICENSE', '.gitignore'].includes(name) && ![...paths.policyPaths, ...paths.processPaths].some((path: string) => path.endsWith('/') ? name.startsWith(path) : name === path))) fail('Nen changed path has no declared gate ruling');
        const input = join(scratch, `${pr}.txt`);
        writeFileSync(input, names.join('\n') + '\n');
        const derived = json('nen', ['gate', 'derive', '--policy-paths', paths.policyPaths.join(','), '--process-paths', paths.processPaths.join(','), '--files-from', input, '--json'], hatsu);
        if (!['G2', 'G4'].includes(derived.gate)) fail(`PR #${pr} gate unread`);
        gate = derived.gate;
      }
      if (!equal(before, snapshot(pr))) fail(`PR #${pr} moved while deriving its gate`);
      gates.set(pr, gate);
    }
    // An empty delivery set still needs Nen's claim count, once, at G2 (no PR receipt is selected).
    const groups = [...new Set(gates.values())];
    if (!groups.length) groups.push('G2');
    const reports: { gate: Gate; report: Report }[] = [];
    for (const gate of groups) {
      const result = spawnSync('nen', ['loop', 'slots', '--from-run', runId, '--target', authority,
        '--prompt-gate', gate, '--ci-cap', '2', '--local-cap', '7', '--repo', root, '--json'],
      { cwd: root, encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 });
      if (result.stderr) process.stderr.write(result.stderr);
      if (result.error || result.signal || result.status === null) fail('Nen slot read did not complete');
      if (![0, 1].includes(result.status)) return result.status;
      // Exit 1 with no report is a refusal, never a full budget to recompute.
      const report: Report = JSON.parse(result.stdout);
      if (report.fromRun?.run !== runId || !Array.isArray(report.fromRun.efforts) || !Array.isArray(report.done) ||
          !Array.isArray(report.fromRun.closedUnmerged) || !Array.isArray(report.fromRun.notEfforts) ||
          !Array.isArray(report.fromRun.unread) || !Array.isArray(report.fromRun.parkedClaims) ||
          !['read', 'not-recorded', 'unread'].includes(report.fromRun.claims) ||
          !(report.fromRun.claimsUnread === null || typeof report.fromRun.claimsUnread === 'string')) fail('Nen report incomplete');
      if ((report.localSlotFrees as { rule?: string })?.rule !== 'ready+prompted') fail('Futon requires ready+prompted');
      const effortIds = report.fromRun.efforts.map(e => e.id);
      const decisions = [...report.ci.holding, ...report.local.holding].map(h => h.id).concat(report.done);
      if (new Set(effortIds).size !== effortIds.length || new Set(decisions).size !== decisions.length ||
          !equal([...effortIds].sort(), [...decisions].sort())) fail('Nen decisions do not cover efforts exactly');
      for (const [plane, cap] of [['ci', 2], ['local', 7]] as const) {
        const value = report[plane];
        if (value.plane !== plane || value.cap !== cap || value.occupied !== value.holding.length ||
            value.holding.some(h => typeof h.why !== 'string' || report.fromRun.efforts.find(e => e.id === h.id)?.plane !== plane)) fail('Nen plane inconsistent');
      }
      const deliveryIds = report.fromRun.efforts.filter(e => e.pr !== null).map(e => e.pr).concat(report.fromRun.closedUnmerged);
      if (!equal([...deliveryIds].sort(), [...ids].sort())) fail('Nen delivery coverage changed');
      reports.push({ gate, report });
    }
    for (const pr of ids) if (!equal(snapshots.get(pr), snapshot(pr))) fail(`PR #${pr} moved during slot reads`);
    // Last authoritative read: final network snapshots may have taken long enough for a new claim.
    if (!equal(manifestSnapshot(common, runId), { path: manifestPath, text: manifestText })) fail('run manifest changed during slot reads');
    const first = reports[0]!.report;
    // Claims and non-delivery classifications must agree; otherwise restart from a fresh read.
    for (const { report } of reports) {
      for (const key of ['claims', 'claimsUnread', 'parkedClaims', 'notEfforts', 'closedUnmerged'] as const)
        if (!equal(first.fromRun[key], report.fromRun[key])) fail(`${key} changed between groups`);
      if (!equal(first.localSlotFrees, report.localSlotFrees) ||
          !equal(first.fromRun.efforts.filter(e => e.pr === null), report.fromRun.efforts.filter(e => e.pr === null))) fail('claim or slot rule changed between groups');
    }
    const chosen: { report: Report; effort: Effort }[] = [];
    for (const { gate, report } of reports) for (const effort of report.fromRun.efforts)
      if (effort.pr === null || !gates.has(effort.pr) ? report === first : gates.get(effort.pr) === gate) chosen.push({ report, effort });
    const plane = (name: 'ci' | 'local'): Plane => {
      const holding = chosen.flatMap(({ report, effort }) => report[name].holding.filter(h => h.id === effort.id));
      const cap = first[name].cap;
      const free = name === 'local' && first.fromRun.claimsUnread !== null ? 0 : Math.max(0, cap - holding.length);
      return { plane: name, cap, occupied: holding.length, free, holding, binding: free === 0 };
    };
    const ci = plane('ci'), local = plane('local');
    console.log(JSON.stringify({ ci, local,
      done: chosen.flatMap(({ report, effort }) => report.done.filter(id => id === effort.id)),
      localSlotFrees: first.localSlotFrees,
      fromRun: { ...first.fromRun, efforts: chosen.map(({ effort }) => effort),
        unread: reports.flatMap(({ gate, report }) => report.fromRun.unread.filter(row => gates.get(row.pr) === gate)) },
      promptGates: [...gates].map(([pr, gate]) => ({ pr, gate, snapshot: snapshots.get(pr) })),
      // Preserve full Nen reports as provenance; none of their fact fields are rewritten.
      role: classified.role, registryRef, nenReports: reports }, null, 2));
    return ci.binding || local.binding ? 1 : 0;
  } finally { rmSync(scratch, { recursive: true, force: true }); }
}
