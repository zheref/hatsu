/** The public Tenkai CLI owns typed adoption and the aggregate report. */
import { spawnSync } from 'node:child_process';
import { existsSync, realpathSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { catalogue } from './pr_sections.ts';
import { history, readSections, summary } from './pr_sections_history.ts';
import { declarationText, strictJson } from './config_values_refresh.ts';
import { fixFor, fixRows, guide, OUTSTANDING, quote, resolveAction, type Fix, type Item } from './tenkai_fixes.ts';
import {
  adoptionRole, DEFER_READINESS, DEFERRED_READINESS, handlesPortableReadiness, LEGACY_READINESS,
  READINESS_CONTEXT_CHANGED, READINESS_WORKFLOW, readinessInputs, readReadinessTemplate, registryText,
  type AdoptionRunner, type LegacyReadiness, type ReadinessRole, type ReadinessRow, type ReadinessTemplate,
} from './tenkai_readiness_policy.mts';

type AdoptionItem = Item & { fix?: Fix };
type AdoptionReport = {
  mode: string;
  repo: string;
  slug: string | null;
  runner: AdoptionRunner;
  items: AdoptionItem[];
  outstanding: number;
  guide: ReturnType<typeof guide>;
};

const here = dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const mode = args[0];
const plain = (value: unknown) => String(value).replace(/[\p{Cc}\p{Cf}]/gu, '');
const options: Record<string, string> = {};
let json = false;
for (let at = 1; at < args.length; at++) {
  if (args[at] === '--json') { json = true; continue; }
  if (args[at].startsWith('--') && at + 1 < args.length) options[args[at]] = args[++at];
}
function legacy(argv: string[], repo = '', readiness?: LegacyReadiness) {
  return spawnSync('bash', [join(here, 'tenkai_adopt_legacy.sh'), ...argv], {
    encoding: 'utf8', maxBuffer: 16 * 1024 * 1024,
    env: { ...process.env, [DEFER_READINESS]: readiness ? '' : repo,
      [LEGACY_READINESS]: readiness ? JSON.stringify(readiness) : '' },
  });
}
function relay(result: ReturnType<typeof legacy>): number {
  process.stdout.write(result.stdout ?? '');
  process.stderr.write(result.stderr ?? '');
  return result.status ?? 2;
}
function refused(result: ReturnType<typeof legacy>) {
  return result.error || ![0, 1].includes(result.status ?? 2);
}
function readinessRow(document: AdoptionReport): AdoptionItem {
  const readiness = Array.isArray(document?.items) ? document.items.find(row => row?.id === READINESS_WORKFLOW) : undefined;
  if (!readiness || typeof readiness.detail !== 'string' || typeof readiness.state !== 'string') throw new Error('the frozen adopter did not report its readiness workflow item');
  return readiness;
}
function hasHandoff(item: AdoptionItem, role: ReadinessRole): boolean {
  return role
    ? item.state === 'staged' && item.detail === DEFERRED_READINESS
    : item.state === 'blocked' && item.detail === 'repository role is unknown; the trusted guard and pin policy cannot be rendered safely';
}
function applyPortable(
  document: AdoptionReport, root: string, role: ReadinessRole, registry: string | null, template: ReadinessTemplate | null,
  operation: 'apply' | 'diagnose',
): ReadinessRow {
  try {
    const input = readinessInputs(template, role, registry, document.slug, document.runner);
    const script = join(root, 'scripts', 'tenkai_readiness_guard.mts');
    const result = spawnSync(process.execPath, [script, operation + '-workflow', document.repo, root], {
      encoding: 'utf8', input: JSON.stringify(input), timeout: 60_000,
    });
    if (result.error || result.status !== 0) {
      throw new Error(plain((result.error?.message ?? result.stderr.trim()) || 'the readiness guard did not return a verdict'));
    }
    const verdict: ReadinessRow | null = JSON.parse(result.stdout);
    if (verdict === null) throw new Error('the portable workflow route changed during adoption');
    if (!['satisfied', 'missing', 'drift', 'blocked', 'repaired', 'staged'].includes(verdict?.state) ||
        typeof verdict.detail !== 'string' || (verdict.action !== null && typeof verdict.action !== 'string')) {
      throw new Error('the readiness guard returned a malformed verdict');
    }
    return verdict;
  } catch (error) {
    return { state: 'blocked', detail: plain(error instanceof Error ? error.message : error),
      action: 'review the portable readiness policy and re-run diagnose' };
  }
}
function updateWorkflowDetails(row: AdoptionItem, portableState?: string) {
  if (row.id === 'guard/registration' &&
      row.detail === 'no scripts/workflow_runner_policy_check.rb in this repository — no two-PR ordering applies') {
    row.detail = 'no scripts/workflow_runner_policy_check.rb in this repository. Ruby registration has no prerequisite PR';
  }
  if (row.id !== 'workflows/privileged' || !row.detail) return;
  row.detail = row.detail.replace(/^policy guard /, 'repository-owned Ruby policy guard ');
  if (portableState === undefined) return;
  row.detail = row.detail.replace(/\. Tenkai installs a privileged pull_request_target job and NO guard — this repository inherits no ongoing enforcement around it$/,
    '. Other privileged workflows remain under repository-owned policy.');
  if (!['satisfied', 'repaired'].includes(portableState)) row.detail += '. Portable readiness admission is outstanding.';
}

function run(): number {
  if (mode === '--self-test') {
    const original = legacy(args);
    process.stdout.write(original.stdout ?? '');
    process.stderr.write(original.stderr ?? '');
    if (original.status !== 0) return original.status ?? 2;
    const portable = spawnSync(process.execPath, [join(here, 'tenkai_readiness_policy_fixture.mts')], { stdio: 'inherit' });
    return portable.status ?? 2;
  }
  if (!['diagnose', 'apply'].includes(mode) || !options['--repo']) {
    return relay(legacy(args));
  }
  const root = realpathSync(resolve(options['--hatsu-root'] ?? dirname(here)));
  // The engine resolves symlinks (Path.resolve), so the report matches its path, the real one.
  const given = resolve(options['--repo']);
  const repo = existsSync(given) ? realpathSync(given) : given;
  // HA#535: the fix catalogue is read and checked before anything can write, from this script's own tree.
  const fixes = fixRows(dirname(here));
  // Refuse unsafe registry paths before the frozen adopter can follow them.
  const registry = registryText(repo);
  const parameters = [...args.slice(1), '--json'];
  const preview = legacy(['diagnose', ...parameters], repo);
  if (refused(preview)) return relay(preview);
  const observed: AdoptionReport = JSON.parse(preview.stdout);
  const observedReadiness = readinessRow(observed);
  let role: ReadinessRole = null;
  let digest: string | null = null;
  let routeFailure: ReadinessRow | undefined;
  try {
    ({ role, digest } = adoptionRole(registry, observed.slug));
    if (registryText(repo) !== registry || !hasHandoff(observedReadiness, role)) {
      throw new Error(READINESS_CONTEXT_CHANGED);
    }
  } catch (error) {
    routeFailure = { state: 'blocked', detail: plain(error instanceof Error ? error.message : error),
      action: 'verify the repository role in nen/repos.json and re-run diagnose' };
  }
  const portable = !routeFailure && handlesPortableReadiness(repo, role);
  // The frozen renderer refused a missing pinned template before any adoption writes.
  const template = observed.slug ? readReadinessTemplate(root) : null;
  const legacyReadiness = !routeFailure && !portable && observed.slug && role && digest
    ? { repo, slug: observed.slug, role, registry: digest } : undefined;
  // Use the same validated identity on subsequent frozen passes.
  const adoptedParameters = observed.slug ? [...parameters, '--slug', observed.slug] : parameters;
  let finding: any;
  let refreshed = false;
  try {
    const before = declarationText(repo, 'nen/workflow.json');
    const workflow = before === undefined ? undefined : strictJson(before);
    const value = workflow?.pr?.sections;
    const cat = catalogue(root);
    if (value !== undefined) {
      const reading = readSections(value, cat, history(root, cat));
      if (reading.status !== 'current') finding = { state: 'drift', detail: summary(reading), prSections: reading };
    }
    if (mode === 'apply' && !routeFailure) {
      const fill = spawnSync('bash', [join(here, 'config_values.sh'), 'fill', '--refresh', '--repo', repo, '--hatsu-root', root, '--json'], { encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 });
      if (fill.error || ![0, 1].includes(fill.status ?? 2) || !fill.stdout.trim()) throw new Error(plain(fill.stderr || fill.error?.message || 'PR-section refresh refused; nothing adopted'));
      JSON.parse(fill.stdout);
      refreshed = before !== declarationText(repo, 'nen/workflow.json');
      finding = undefined;
    }
  } catch (error) { finding = { state: 'blocked', detail: plain(error instanceof Error ? error.message : error) }; }
  // A refused refresh never falls through to the mutating frozen adopter.
  const applying = mode === 'apply' && finding?.state !== 'blocked' && !routeFailure;
  const result = applying ? legacy(['apply', ...adoptedParameters], repo, legacyReadiness)
    : legacyReadiness ? legacy(['diagnose', ...adoptedParameters], repo, legacyReadiness) : preview;
  if (refused(result)) return relay(result);
  const document: AdoptionReport = JSON.parse(result.stdout);
  document.mode = mode;
  const readiness = readinessRow(document);
  if (routeFailure) Object.assign(readiness, routeFailure);
  else if (portable) {
    // The frozen apply installs the reader before this operation can admit a workflow.
    const verdict = document.slug === observed.slug && hasHandoff(readiness, role)
      ? applyPortable(document, root, role, digest, template, applying ? 'apply' : 'diagnose')
      : { state: 'blocked', detail: 'the portable readiness workflow handoff could not be verified',
          action: 'verify the Hatsu installation and repository identity, then re-run diagnose' };
    Object.assign(readiness, verdict);
  }
  if (finding || refreshed) {
    document.items.push({ id: 'pr.sections', title: 'PR-section catalogue freshness', owner: 'hatsu', action: finding ? `config_values.sh fill --refresh --repo ${quote(plain(repo))}` : null,
      ...(finding ?? { state: 'repaired', detail: 'pr.sections: refreshed unedited defaults and options; consumer-owned cells retained' }) });
  }
  // HA#535: every outstanding row names its fix — run, edit, detect and who supplies the value.
  for (const row of document.items) {
    updateWorkflowDetails(row, portable ? readiness.state : undefined);
    row.action = resolveAction(row.action, repo);
    if (OUTSTANDING.includes(row.state)) row.fix = fixFor(row, fixes, { repo, root: dirname(here), slug: document.slug });
  }
  document.outstanding = document.items.filter(row => OUTSTANDING.includes(row.state)).length;
  document.guide = guide(document.items);
  if (json) process.stdout.write(JSON.stringify(document, null, 2) + '\n');
  else {
    process.stdout.write(`repository: ${plain(document.repo)}\nslug:       ${plain(document.slug ?? '(unreadable)')}\n`);
    const runner = document.runner;
    process.stdout.write(`runner:     ${plain(runner.runs_on)} (fallback ${plain(runner.fallback)}) — ${plain(runner.reason)}\n\n`);
    const glyph: Record<string, string> = { satisfied: 'ok  ', repaired: 'NEW ', missing: 'MISS', drift: 'DRIF', routed: 'ROUT', staged: 'STAG', blocked: 'BLOK' };
    for (const row of document.items) {
      process.stdout.write(`  ${glyph[row.state] ?? plain(row.state)}  ${plain(row.id)}\n        ${plain(row.detail)}\n`);
      if (row.action && !['satisfied', 'repaired'].includes(row.state)) process.stdout.write(`        → ${plain(row.action)}\n`);
      if (row.fix) {
        for (const command of row.fix.run) process.stdout.write(`          run:    ${plain(command)}\n`);
        if (row.fix.edit) process.stdout.write(`          edit:   ${plain(row.fix.edit)}${row.fix.guide ? ` (${plain(row.fix.guide)})` : ''}\n`);
        process.stdout.write(`          detect: ${plain(row.fix.detect)}\n`);
        process.stdout.write(`          fill:   ${plain(fillLine(row.fix))}\n`);
      }
    }
    if (document.outstanding) {
      const { defaults, owner, edits, routed, unmapped } = document.guide;
      const list = (ids: string[]) => ids.length ? ids.map(plain).join(', ') : 'none';
      process.stdout.write(`\n${document.outstanding} item(s) outstanding. Re-run \`apply\` after settling the routed and staged ones.\n`);
      process.stdout.write(`\nguided fill — Tenkai writes only catalogue defaults and values the owner answered, never an invented one:\n`);
      process.stdout.write(`  1. defaults (${defaults.length}), settling ${list(defaults)}:\n       bash ${plain(quote(join(dirname(here), 'scripts', 'tenkai_adopt.sh')))} apply --repo ${plain(quote(repo))}\n`);
      process.stdout.write(`  2. owner answers (${owner.length}): ${list(owner.map((row: any) => row.id))} — ask each, then run its line with the answer single-quoted in place of its <token>\n`);
      process.stdout.write(`  3. Tenkai's edits (${edits.length}): ${list(edits)} — the owner decides, Tenkai edits nen/contract.json or nen/workflow.json (§ 6c), then detect\n`);
      process.stdout.write(`  4. routed to their owner (${routed.length}): ${list(routed)} — the owner or the named tool makes the change; Tenkai never does\n`);
      if (unmapped.length) process.stdout.write(`  5. unmapped (${unmapped.length}): ${list(unmapped)} — no catalogue row names a fix: a defect to file\n`);
      process.stdout.write(`then re-run diagnose: the outstanding count goes down by every item that settled.\n`);
    } else process.stdout.write('\nevery item is satisfied — this repository is a working Hatsu consumer.\n');
  }
  process.stderr.write(result.stderr ?? '');
  return document.outstanding ? 1 : 0;
}
function fillLine(fix: any) {
  switch (fix.fill) {
    case 'default': return 'catalogue default or Hatsu seed — apply writes it';
    case 'owner': return `the owner answers ${fix.asks.join(', ')}, single-quoted in place of the token`;
    case 'edit': return 'the owner decides; Tenkai edits the file (§ 6c), then detect';
    case 'route': return 'routed to its owner; Tenkai never makes this change';
    default: return `unmapped — no catalogue row names a fix (${fix.defect ?? fix.rule}): a defect to file`;
  }
}
try { process.exitCode = run(); }
catch (error) { process.stderr.write(`tenkai_adopt.sh: ${plain(error instanceof Error ? error.message : error)}\n`); process.exitCode = 2; }
