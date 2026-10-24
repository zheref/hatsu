#!/usr/bin/env node
// resume_proof.mts — the crash-and-resume proof's ledger half (zheref/hatsu#444, HR-5; D6, D16).
//
//   node scripts/resume_proof.mts [--nen <path>] [--json]
//
// WHAT IT PROVES. Every composite whose resume rests on a nen ledger is driven, in a throwaway git
// repository, once uninterrupted and once interrupted at every point a session can die: after each
// `nen phase end` (between phases) and after each `nen phase begin` (inside a phase). Each interrupted
// run is then re-invoked under the resume rule WORKFLOW § *The effort's ledgers* states (read the
// ledger; a phase ended at exit 0 is skipped and named; an OPEN phase is continued with
// `nen phase begin --resume`; the rest begin fresh), and its end state is compared with the
// uninterrupted run's:
//   * the ledger's projection with the clock elided (phase order, names, exits, steps) is equal;
//   * one entry per phase, never two (AC-3), the interrupted phase carrying exactly one `resumedAt`;
//   * a re-invocation after the run finished writes nothing: the ledger file is byte-identical (AC-1);
//   * `begin --resume` on a phase while ANOTHER is open is refused at exit 2 (the plan's "a refusal is
//     a finding, not a skip": the proof asserts the refusal holds);
//   * a phase that ended non-zero is refused by name on resume, never begun a second time (one entry).
// The futon run manifest (futon and kazaana, which composes it) is proved the same way: a re-`start`
// with the same idle answers is `existing`, a re-`park` is `unchanged`, and the manifest's bytes do not
// move. Instants are the only thing two runs cannot share, so they are the only thing elided.
//
// WHAT IT DOES NOT PROVE. The publishing steps (a PR, a comment, a label) need GitHub: they are proved
// live in the docs/ab sections against a real pull request (`nen pr open` → `existing`, `nen pr ledger
// post` → `unchanged`). A composite that writes no ledger of its own (getsuga, kamui, hiraishin) has
// nothing here to resume from; its section records that as the finding it is.
//
// exit 0  every case converged · exit 1  a case diverged, each named · exit 2  wiring (no nen, bad flag)
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

type Entry = { phase: string; endedAt: string | null; exitCode: number | null; steps: unknown[]; resumedAt?: string[] };
type Ledger = { phases: Entry[] };

const args = process.argv.slice(2);
let nen = 'nen';
let json = false;
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--nen' && args[i + 1]) { nen = args[++i] as string; continue; }
  if (args[i] === '--json') { json = true; continue; }
  console.error(`resume-proof: unknown argument '${args[i]}'`);
  process.exit(2);
}

// The phase vocabulary each composite records, read from its own skill: ren § 2a (one entry per step of
// § 2's table), build § 4 (its four phases; mukai runs inside build's `pr` phase and records none of its
// own). A composite not listed here writes no phase ledger (the docs/ab sections say which).
const COMPOSITES: Record<string, { source: string; phases: string[] }> = {
  ren: { source: 'claude/skills/ren/SKILL.md § 2a', phases: ['breath', 'rasengan', 'kokusen', 'amaterasu', 'spiritual-message', 'jutaisho'] },
  build: { source: 'claude/skills/build/SKILL.md § 4', phases: ['author', 'publish', 'pr', 'readiness'] },
};

function call(repo: string, argv: string[]): { status: number; out: string } {
  const result = spawnSync(nen, argv, { encoding: 'utf8' }); // --repo names the repository; cwd stays the caller's
  if (result.error) { console.error(`resume-proof: could not run '${nen}': ${result.error.message}`); process.exit(2); }
  return { status: result.status ?? 1, out: `${result.stdout}${result.stderr}` };
}
function must(repo: string, argv: string[]): string {
  const { status, out } = call(repo, argv);
  if (status !== 0) throw new Error(`nen ${argv.join(' ')} exited ${status}: ${out.trim()}`);
  return out;
}
function freshRepo(): string {
  const repo = mkdtempSync(join(tmpdir(), 'resume-proof-'));
  const init = spawnSync('git', ['init', '-q', repo], { encoding: 'utf8' });
  if (init.status !== 0) { console.error('resume-proof: git init failed'); process.exit(2); }
  return repo;
}
// Hatsu keys the phase ledger by the branch (WORKFLOW § The effort's ledgers).
const EFFORT = 'opus/kurapika/resume-proof';
function show(repo: string): Ledger {
  return JSON.parse(must(repo, ['phase', 'show', '--effort', EFFORT, '--repo', repo, '--json'])) as Ledger;
}
function ledgerBytes(repo: string): string {
  const path = join(repo, '.git/.nen/phases', `${encodeURIComponent(EFFORT)}.json`);
  try { return readFileSync(path, 'utf8'); } catch { return readFileSync(join(repo, '.nen/phases', `${encodeURIComponent(EFFORT)}.json`), 'utf8'); }
}
function project(ledger: Ledger): string {
  return JSON.stringify(ledger.phases.map((e) => ({ phase: e.phase, ended: e.endedAt !== null, exit: e.exitCode, steps: e.steps })));
}
const begin = (repo: string, phase: string, resume = false): string[] => ['phase', 'begin', '--effort', EFFORT, '--phase', phase, ...(resume ? ['--resume'] : []), '--surface', 'claude-code', '--dial', 'medium', '--repo', repo];
const end = (repo: string, phase: string): string[] => ['phase', 'end', '--effort', EFFORT, '--phase', phase, '--exit', '0', '--repo', repo];

// The resume rule, as a composite re-invoked with the same line applies it.
function resume(repo: string, phases: string[]): string[] {
  const said: string[] = [];
  // Read once, as the composite does at its entry; what it then writes is its own.
  const recorded = (() => { try { return show(repo).phases; } catch { return []; } })();
  for (const phase of phases) {
    const entries = recorded.filter((e) => e.phase === phase);
    if (entries.some((e) => e.endedAt !== null && e.exitCode === 0)) { said.push(`skipped ${phase}`); continue; }
    const open = entries.some((e) => e.endedAt === null);
    // A phase that ended non-zero was a refused step: the resume neither re-begins it (a second entry) nor
    // passes it; it refuses by name and writes nothing, so the stop that step raised is answered first.
    const failed = entries.find((e) => e.endedAt !== null && e.exitCode !== 0);
    if (!open && failed !== undefined) { said.push(`refused ${phase}: ended at exit ${failed.exitCode}`); return said; }
    must(repo, begin(repo, phase, open));
    said.push(open ? `resumed ${phase}` : `began ${phase}`);
    must(repo, end(repo, phase));
  }
  return said;
}

const results: Array<{ composite: string; case: string; verdict: 'converged' | 'diverged'; detail: string }> = [];
for (const [name, { phases }] of Object.entries(COMPOSITES)) {
  const clean = freshRepo();
  for (const phase of phases) { must(clean, begin(clean, phase)); must(clean, end(clean, phase)); }
  const reference = project(show(clean));
  const before = ledgerBytes(clean);
  const rerun = resume(clean, phases);
  const rerunOk = ledgerBytes(clean) === before && rerun.every((s) => s.startsWith('skipped'));
  results.push({ composite: name, case: 'finished, re-invoked', verdict: rerunOk ? 'converged' : 'diverged', detail: rerunOk ? `ledger bytes unchanged; ${rerun.length} skipped` : 'the re-invocation wrote to a finished ledger' });
  rmSync(clean, { recursive: true, force: true });

  for (let k = 0; k < phases.length; k++) {
    for (const where of ['after-end', 'mid-phase'] as const) {
      const repo = freshRepo();
      let detail = '';
      let ok = true;
      try {
        for (let i = 0; i < k; i++) { must(repo, begin(repo, phases[i] as string)); must(repo, end(repo, phases[i] as string)); }
        must(repo, begin(repo, phases[k] as string));
        if (where === 'after-end') must(repo, end(repo, phases[k] as string));
        // ← the session dies here; the same line is invoked again.
        const said = resume(repo, phases);
        const ledger = show(repo);
        const counts = phases.map((p) => ledger.phases.filter((e) => e.phase === p).length);
        const resumed = ledger.phases.map((e) => e.resumedAt?.length ?? 0);
        const wantResumed = phases.map((_, i) => (where === 'mid-phase' && i === k ? 1 : 0));
        if (project(ledger) !== reference) { ok = false; detail = 'projection differs from the uninterrupted run'; }
        else if (counts.some((c) => c !== 1)) { ok = false; detail = `entries per phase ${counts.join(',')}`; }
        else if (JSON.stringify(resumed) !== JSON.stringify(wantResumed)) { ok = false; detail = `resumedAt counts ${resumed.join(',')}`; }
        else detail = said.filter((s) => !s.startsWith('skipped')).length === phases.length - k - (where === 'after-end' ? 1 : 0) ? `${said.filter((s) => s.startsWith('skipped')).length} skipped, ${where === 'mid-phase' ? `${phases[k]} resumed` : k === phases.length - 1 ? 'nothing left to run' : `${phases[k + 1]} begun`}` : `unexpected resume path: ${said.join('; ')}`;
        if (detail.startsWith('unexpected')) ok = false;
      } catch (error) { ok = false; detail = (error as Error).message; }
      results.push({ composite: name, case: `killed ${where} ${phases[k]}`, verdict: ok ? 'converged' : 'diverged', detail });
      rmSync(repo, { recursive: true, force: true });
    }
  }
}

// A phase that ended non-zero: the resume refuses by name and the ledger does not move (one entry).
for (const [name, { phases }] of Object.entries(COMPOSITES)) {
  for (let k = 0; k < phases.length; k++) {
    const repo = freshRepo();
    let ok = true; let detail = '';
    try {
      for (let i = 0; i < k; i++) { must(repo, begin(repo, phases[i] as string)); must(repo, end(repo, phases[i] as string)); }
      must(repo, begin(repo, phases[k] as string));
      must(repo, ['phase', 'end', '--effort', EFFORT, '--phase', phases[k] as string, '--exit', '1', '--repo', repo]);
      const before = ledgerBytes(repo);
      // ← the session dies here; the same line is invoked again.
      const said = resume(repo, phases);
      const last = said[said.length - 1] ?? '';
      ok = last === `refused ${phases[k]}: ended at exit 1` && ledgerBytes(repo) === before && show(repo).phases.length === k + 1;
      detail = ok ? `${k} skipped, ${phases[k]} refused by name, ledger bytes unchanged` : `${said.join('; ')}`;
    } catch (error) { ok = false; detail = (error as Error).message; }
    results.push({ composite: name, case: `killed after failed ${phases[k]}`, verdict: ok ? 'converged' : 'diverged', detail });
    rmSync(repo, { recursive: true, force: true });
  }
}

// begin --resume while another phase is open: refused, exit 2.
{
  const repo = freshRepo();
  must(repo, begin(repo, 'author'));
  const refused = call(repo, begin(repo, 'publish', true));
  results.push({ composite: 'any', case: 'resume a phase while another is open', verdict: refused.status === 2 ? 'converged' : 'diverged', detail: refused.status === 2 ? 'refused at exit 2, naming the open phase' : `exit ${refused.status}` });
  rmSync(repo, { recursive: true, force: true });
}

// The futon run manifest (futon; kazaana composes it): re-start and re-park are idempotent, byte for byte.
{
  const repo = freshRepo();
  const id = '0123456789abcdef0123456789abcdef';
  const start = ['run', 'start', '--id', id, '--target', 'zheref/hatsu', '--repo', repo, '--idle-answers', '{"host-nen-link":"default"}'];
  const park = ['run', 'park', '--id', id, '--issue', 'zheref/hatsu#444', '--row', 'g5-harness-denied', '--repo', repo];
  let ok = true; let detail = '';
  try {
    const started = must(repo, start); must(repo, park);
    const path = started.trim().split(' -- ').pop() as string;
    const before = readFileSync(path, 'utf8');
    // ← killed after the park; the same line again.
    const again = must(repo, start); const repark = must(repo, park);
    ok = again.startsWith('existing') && repark.startsWith('unchanged') && readFileSync(path, 'utf8') === before;
    detail = ok ? 're-start existing, re-park unchanged, manifest bytes unchanged' : `${again.trim()} / ${repark.trim()}`;
  } catch (error) { ok = false; detail = (error as Error).message; }
  results.push({ composite: 'futon (and kazaana)', case: 'killed after a park, re-invoked', verdict: ok ? 'converged' : 'diverged', detail });
  rmSync(repo, { recursive: true, force: true });
}

const diverged = results.filter((r) => r.verdict === 'diverged');
if (json) console.log(JSON.stringify({ contract: 'hatsu.resume-proof/v0.1', nen: must(tmpdir(), ['--version']).trim(), results, diverged: diverged.length }, null, 2));
else {
  for (const r of results) console.log(`${r.verdict.padEnd(9)} ${r.composite.padEnd(20)} ${r.case.padEnd(36)} ${r.detail}`);
  console.log(`resume-proof: ${results.length - diverged.length}/${results.length} converged`);
}
process.exit(diverged.length === 0 ? 0 : 1);
