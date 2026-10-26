/** HA#370: PR-section freshness in Tenkai's inbox; the frozen adoption engine keeps its own items. */
import { spawnSync } from 'node:child_process';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { catalogue } from './pr_sections.ts';
import { history, readSections, summary } from './pr_sections_history.ts';
import { declarationText, strictJson } from './config_values_refresh.ts';

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
function legacy(argv: string[]) { return spawnSync('bash', [join(here, 'tenkai_adopt_legacy.sh'), ...argv], { encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 }); }
function run(): number {
  if (!['diagnose', 'apply'].includes(mode) || !options['--repo']) {
    const result = legacy(args); process.stdout.write(result.stdout ?? ''); process.stderr.write(result.stderr ?? ''); return result.status ?? 2;
  }
  const root = resolve(options['--hatsu-root'] ?? dirname(here));
  const repo = resolve(options['--repo']);
  // Preserve the frozen adopter's invocation refusals before the explicit refresh can write.
  const validation = mode === 'apply' ? legacy(['diagnose', ...args.slice(1), '--json']) : undefined;
  if (validation && (validation.error || ![0, 1].includes(validation.status ?? 2))) {
    process.stdout.write(validation.stdout ?? ''); process.stderr.write(validation.stderr ?? ''); return validation.status ?? 2;
  }
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
    if (mode === 'apply') {
      const fill = spawnSync('bash', [join(here, 'config_values.sh'), 'fill', '--refresh', '--repo', repo, '--hatsu-root', root, '--json'], { encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 });
      if (fill.error || ![0, 1].includes(fill.status ?? 2) || !fill.stdout.trim()) throw new Error(plain(fill.stderr || fill.error?.message || 'PR-section refresh refused; nothing adopted'));
      JSON.parse(fill.stdout);
      refreshed = before !== declarationText(repo, 'nen/workflow.json');
      finding = undefined;
    }
  } catch (error) { finding = { state: 'blocked', detail: plain(error instanceof Error ? error.message : error) }; }
  // A refused refresh never falls through to the mutating frozen adopter.
  const blocked = mode === 'apply' && finding?.state === 'blocked';
  const invoked = [blocked ? 'diagnose' : mode, ...args.slice(1), '--json'];
  const result = blocked && validation ? validation : legacy(invoked);
  if (result.error || ![0, 1].includes(result.status ?? 2)) {
    process.stdout.write(result.stdout ?? ''); process.stderr.write(result.stderr ?? ''); return result.status ?? 2;
  }
  const document = JSON.parse(result.stdout);
  document.mode = mode;
  if (finding || refreshed) {
    document.items.push({ id: 'pr.sections', title: 'PR-section catalogue freshness', owner: 'hatsu', action: finding ? `config_values.sh fill --refresh --repo ${plain(repo)}` : null,
      ...(finding ?? { state: 'repaired', detail: 'pr.sections: refreshed unedited defaults and options; consumer-owned cells retained' }) });
  }
  document.outstanding = document.items.filter((row: any) => ['missing', 'drift', 'routed', 'staged', 'blocked'].includes(row.state)).length;
  if (json) process.stdout.write(JSON.stringify(document, null, 2) + '\n');
  else {
    process.stdout.write(`repository: ${plain(document.repo)}\nslug:       ${plain(document.slug ?? '(unreadable)')}\n`);
    const runner = document.runner;
    process.stdout.write(`runner:     ${plain(runner.runs_on)} (fallback ${plain(runner.fallback)}) — ${plain(runner.reason)}\n\n`);
    const glyph: Record<string, string> = { satisfied: 'ok  ', repaired: 'NEW ', missing: 'MISS', drift: 'DRIF', routed: 'ROUT', staged: 'STAG', blocked: 'BLOK' };
    for (const row of document.items) {
      process.stdout.write(`  ${glyph[row.state] ?? plain(row.state)}  ${plain(row.id)}\n        ${plain(row.detail)}\n`);
      if (row.action && !['satisfied', 'repaired'].includes(row.state)) process.stdout.write(`        → ${plain(row.action)}\n`);
    }
    process.stdout.write(document.outstanding ? `\n${document.outstanding} item(s) outstanding. Re-run \`apply\` after settling the routed and staged ones.\n` : '\nevery item is satisfied — this repository is a working Hatsu consumer.\n');
  }
  process.stderr.write(result.stderr ?? '');
  return document.outstanding ? 1 : 0;
}
try { process.exitCode = run(); }
catch (error) { process.stderr.write(`tenkai_adopt.sh: ${plain(error instanceof Error ? error.message : error)}\n`); process.exitCode = 2; }
