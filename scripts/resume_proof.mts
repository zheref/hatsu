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
// move. A resumed session's spend is proved apart (HR-398): the session killed after its usage entry and
// before the reporting phase's end records an entry of its own on resume, the first one unchanged, while
// the phase projection still equals the uninterrupted run's — the usage ledger is never compared with an
// uninterrupted run's, only the steps are. Instants are the only thing two runs cannot share, so they are the only thing elided. That case
// reads the verb's `--json` ANSWER rather than its prose — `outcome` and `path` as fields — and how it
// reads it is proved too, on a payload: every other key is ignored, and an answer missing a field is
// refused by name with a bounded, path-free excerpt instead of read as a path that is then missing
// (zheref/hatsu#574).
//
// WHAT IT DOES NOT PROVE. The publishing steps (a PR, a comment, a label) need GitHub: they are proved
// live in the docs/ab sections against a real pull request (`nen pr open` → `existing`, `nen pr ledger
// post` → `unchanged`). getsuga keeps no ledger: its resume record is its GitHub state, the tag and the
// release-proposal PR, read before any write (HR-400), so it has no row here and its docs/ab section
// records what it reads.
//
// exit 0  every case converged · exit 1  a case diverged, each named · exit 2  wiring (no nen, a bad
// flag, no writable temp root)
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

type Entry = { phase: string; endedAt: string | null; exitCode: number | null; steps: unknown[]; resumedAt?: string[]; note?: string | null };
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
// own), kamui § 6 and hiraishin § 3 (one entry per top-level step, HR-400; kamui's §§ 2–4 run inside
// hiraishin's `spec` and record none of their own). The effort is the key each skill names: the branch
// for ren and build (WORKFLOW § The effort's ledgers), the run id for a port run, which has no branch
// (docs/config/ports.md § The run record's pattern). A composite not listed here writes no phase ledger
// (the docs/ab sections say which).
const BRANCH = 'opus/kurapika/resume-proof';
const COMPOSITES: Record<string, { source: string; effort: string; phases: string[] }> = {
  ren: { source: 'claude/skills/ren/SKILL.md § 2a', effort: BRANCH, phases: ['breath', 'rasengan', 'kokusen', 'amaterasu', 'spiritual-message', 'jutaisho'] },
  build: { source: 'claude/skills/build/SKILL.md § 4', effort: BRANCH, phases: ['author', 'publish', 'pr', 'readiness'] },
  kamui: { source: 'claude/skills/kamui/SKILL.md § 6', effort: 'kamui-fi-is-7-20261123', phases: ['setup', 'spec', 'wait', 'siblings', 'start', 'ending'] },
  hiraishin: { source: 'claude/skills/hiraishin/SKILL.md § 3', effort: 'hiraishin-fi-pr-42-20261123', phases: ['precondition', 'spec', 'brief', 'drift', 'issue', 'build'] },
};

function call(repo: string, argv: string[]): { status: number; out: string; stdout: string } {
  const result = spawnSync(nen, argv, { encoding: 'utf8' }); // --repo names the repository; cwd stays the caller's
  if (result.error) { console.error(`resume-proof: could not run '${nen}': ${result.error.message}`); process.exit(2); }
  // `out` is both streams, for a refusal's text; `stdout` is kept apart for the rows that parse a
  // --json payload, which a warning on stderr would otherwise make unparseable.
  return { status: result.status ?? 1, out: `${result.stdout}${result.stderr}`, stdout: result.stdout };
}
function must(repo: string, argv: string[]): string {
  const { status, out } = call(repo, argv);
  if (status !== 0) throw failure(argv, status, out);
  return out;
}
// What a refusal here is allowed to quote: ONE bounded excerpt with absolute paths elided. A row's
// detail is printed by this lane and transcribed into public prose, so it is held to the treatment
// `scripts/ledger_findings_prepare.mts` gives the findings copy it posts (SEC-12).
function elide(text: string): string {
  return text.replace(/\/(?:Users|home|private|var|tmp)\/[^\s"',}\]]*/g, '<path>');
}
function excerpt(printed: string, limit = 160): string {
  const flat = elide(printed.replace(/\s+/g, ' ').trim());
  return JSON.stringify(flat.length > limit ? `${flat.slice(0, limit)}...` : flat);
}
// A failing call's message, for both callers below. The ARGV echo carries absolute paths as surely as
// the output does — the throwaway repository is named in the arguments — so the elision covers the
// whole message and not only the quoted part.
function failure(argv: string[], status: number, out: string): Error {
  return new Error(`nen ${elide(argv.join(' '))} exited ${status}: ${excerpt(out, 400)}`);
}
// `nen run start|park --json` answers with a CONTRACT — `outcome` and `path` as fields — so this lane
// reads those and never the prose form. The prose carries a second line stating the permissions it
// wrote with, on a write and not on a no-op, and reading it as one string put that line inside the
// manifest's location: the row then reported ENOENT against text it had assembled itself, as a
// convergence divergence (zheref/hatsu#574). A payload missing either field is REFUSED by name, so a
// later change to the contract reads as a refusal naming the field rather than as a missing file.
type RunAnswer = { outcome: string; path: string };
function runAnswer(printed: string, verb: string): RunAnswer {
  let parsed: unknown;
  try { parsed = JSON.parse(printed); } catch { throw new Error(`${verb} --json did not print JSON: ${excerpt(printed)}`); }
  const answer = (parsed ?? {}) as Partial<RunAnswer>;
  if (typeof answer.outcome !== 'string' || !answer.outcome) throw new Error(`${verb} --json printed no 'outcome': ${excerpt(printed)}`);
  if (typeof answer.path !== 'string' || !answer.path) throw new Error(`${verb} --json printed no 'path': ${excerpt(printed)}`);
  return { outcome: answer.outcome, path: answer.path };
}
function mustJson(repo: string, argv: string[], verb: string): RunAnswer {
  const { status, out, stdout } = call(repo, argv);
  if (status !== 0) throw failure(argv, status, out);
  return runAnswer(stdout, verb);
}
// A temp root this process cannot write is the HOST's state, not a diverged case, so it leaves by the
// wiring exit this file's header declares rather than as an uncaught throw at exit 1 — which is the code
// reserved for "a case diverged", and would read as a resume regression with no case named.
function tempRoot(): string {
  try { return mkdtempSync(join(tmpdir(), 'resume-proof-')); }
  catch (error) {
    console.error(`resume-proof: could not create a temp repository under ${tmpdir()}: ${(error as Error).message}`);
    process.exit(2);
  }
}
function freshRepo(): string {
  const repo = tempRoot();
  const init = spawnSync('git', ['init', '-q', repo], { encoding: 'utf8' });
  if (init.status !== 0) { console.error('resume-proof: git init failed'); process.exit(2); }
  return repo;
}
// The effort in play: each composite's own key (COMPOSITES above), set before its cases run.
let EFFORT = BRANCH;
function show(repo: string): Ledger {
  return JSON.parse(must(repo, ['phase', 'show', '--effort', EFFORT, '--repo', repo, '--json'])) as Ledger;
}
function ledgerBytes(repo: string): string {
  const path = join(repo, '.git/.nen/phases', `${encodeURIComponent(EFFORT)}.json`);
  try { return readFileSync(path, 'utf8'); } catch { return readFileSync(join(repo, '.nen/phases', `${encodeURIComponent(EFFORT)}.json`), 'utf8'); }
}
function project(ledger: Ledger): string {
  // A recorded step carries its own durationMs, a clock value: elided with the instants (HR-398).
  const steps = (list: unknown[]): unknown[] => list.map((step) => {
    if (step === null || typeof step !== 'object') return step;
    const { durationMs: _clock, ...kept } = step as Record<string, unknown>;
    return kept;
  });
  return JSON.stringify(ledger.phases.map((e) => ({ phase: e.phase, ended: e.endedAt !== null, exit: e.exitCode, steps: steps(e.steps ?? []) })));
}
const begin = (repo: string, phase: string, resume = false): string[] => ['phase', 'begin', '--effort', EFFORT, '--phase', phase, ...(resume ? ['--resume'] : []), '--surface', 'claude-code', '--dial', 'medium', '--repo', repo];
const end = (repo: string, phase: string): string[] => ['phase', 'end', '--effort', EFFORT, '--phase', phase, '--exit', '0', '--repo', repo];

// The resume rule, as a composite re-invoked with the same line applies it. `during` is what the
// restarted session does inside a phase it runs (the usage case records its own entry there).
// `aliases` names an older entry name a step may carry (ren § 2a: `launch`, `report`, `bell` for steps 4–6).
function resume(repo: string, phases: string[], during?: (phase: string) => void, aliases: Record<string, string[]> = {}): string[] {
  const said: string[] = [];
  // Read once, as the composite does at its entry; what it then writes is its own.
  const recorded = (() => { try { return show(repo).phases; } catch { return []; } })();
  for (const phase of phases) {
    const entries = recorded.filter((e) => e.phase === phase || (aliases[phase] ?? []).includes(e.phase));
    // Every line names the entry as recorded (ren § 2a), so a reader finds it in the ledger.
    const done = entries.find((e) => e.endedAt !== null && e.exitCode === 0);
    if (done !== undefined) { said.push(`skipped ${done.phase}`); continue; }
    const open = entries.some((e) => e.endedAt === null);
    // A phase that ended non-zero was a refused step: the resume neither re-begins it (a second entry) nor
    // passes it; it refuses by name and writes nothing, so the stop that step raised is answered first.
    const failed = entries.find((e) => e.endedAt !== null && e.exitCode !== 0);
    if (!open && failed !== undefined) { said.push(`refused ${failed.phase}: ended at exit ${failed.exitCode}`); return said; }
    // An open entry is continued under the name it was begun with, never re-begun under the new one.
    const name = open ? (entries.find((e) => e.endedAt === null) as Entry).phase : phase;
    must(repo, begin(repo, name, open));
    said.push(open ? `resumed ${name}` : `began ${phase}`);
    during?.(phase);   // the step, whatever name its entry was begun under
    must(repo, end(repo, name));
  }
  return said;
}

const results: Array<{ composite: string; case: string; verdict: 'converged' | 'diverged'; detail: string }> = [];
for (const [name, { effort, phases }] of Object.entries(COMPOSITES)) {
  EFFORT = effort;
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
for (const [name, { effort, phases }] of Object.entries(COMPOSITES)) {
  EFFORT = effort;
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

// A resumed session's spend is an entry of its own (HR-398). ren records usage at its reporting step
// (§ 2a, step 5); the uninterrupted run leaves one entry. The interrupted run dies after that entry and
// before the step's end; the restarted session resumes the open step and records its own entry, marked
// `--note "resumed session"`. The first entry must be unchanged, the second the restarted session's, and
// the phase projection equal to the uninterrupted run's: the steps are compared, the spend is not.
type UsageEntry = { note: string | null; source: string | null };
type UsageLedger = { entries: UsageEntry[] };
{
  EFFORT = COMPOSITES.ren!.effort;
  const phases = COMPOSITES.ren!.phases;
  const reporting = 'spiritual-message';
  const usage = (repo: string, resumed: boolean): string[] => ['usage', 'record', '--effort', EFFORT, '--surface', 'claude-code', '--dial', 'medium', '--input', resumed ? '50' : '100', '--output', resumed ? '5' : '10', '--source', 'resume-proof: the reporting step', ...(resumed ? ['--note', 'resumed session'] : []), '--repo', repo];
  const ledger = (repo: string): UsageLedger => JSON.parse(must(repo, ['usage', 'show', '--effort', EFFORT, '--repo', repo, '--json'])) as UsageLedger;
  let ok = true; let detail = '';
  const clean = freshRepo();
  const repo = freshRepo();
  try {
    for (const phase of phases) { must(clean, begin(clean, phase)); if (phase === reporting) must(clean, usage(clean, false)); must(clean, end(clean, phase)); }
    const reference = project(show(clean));
    const uninterrupted = ledger(clean).entries;
    for (const phase of phases.slice(0, phases.indexOf(reporting))) { must(repo, begin(repo, phase)); must(repo, end(repo, phase)); }
    must(repo, begin(repo, reporting));
    must(repo, usage(repo, false));
    const first = JSON.stringify(ledger(repo).entries[0]);
    // ← the session dies here, after its usage entry and before the step's end; the same line again.
    const said = resume(repo, phases, (phase) => { if (phase === reporting) must(repo, usage(repo, true)); });
    const entries = ledger(repo).entries;
    const checks: Array<[string, boolean]> = [
      ['the uninterrupted run left one entry', uninterrupted.length === 1],
      [`${reporting} was resumed`, said.includes(`resumed ${reporting}`)],
      ['the resumed run left two entries', entries.length === 2],
      ['the first entry unchanged', JSON.stringify(entries[0]) === first],
      ['the second marked resumed session', entries[1]?.note === 'resumed session' && entries[0]?.note === null],
      ['the phase projection equals the uninterrupted run', project(show(repo)) === reference],
    ];
    const failed = checks.find((check) => !check[1]);
    ok = failed === undefined;
    detail = failed ? `${failed[0]} is FALSE (${entries.length} entries; ${said.join('; ')})` : 'uninterrupted 1 entry; resumed 2, the first unchanged, the second marked; projection equal';
  } catch (error) { ok = false; detail = (error as Error).message; }
  results.push({ composite: 'ren', case: 'a resumed session\'s own usage', verdict: ok ? 'converged' : 'diverged', detail });
  rmSync(clean, { recursive: true, force: true });
  rmSync(repo, { recursive: true, force: true });
}

// hiraishin's no-spec route (*spec step: none configured*): docs/config/ports.md § The phase ledger
// writes `spec` all the same, begun with a note and ended at exit 0, so the run keeps its six entries and
// a re-invocation skips it like any finished phase (HR-400).
{
  EFFORT = COMPOSITES.hiraishin!.effort;
  const phases = COMPOSITES.hiraishin!.phases;
  const repo = freshRepo();
  let ok = true; let detail = '';
  try {
    for (const phase of phases) {
      must(repo, [...begin(repo, phase), ...(phase === 'spec' ? ['--note', 'no spec repository'] : [])]);
      must(repo, end(repo, phase));
    }
    const ledger = show(repo).phases;
    const spec = ledger.find((e) => e.phase === 'spec');
    const before = ledgerBytes(repo);
    const said = resume(repo, phases);
    const checks: Array<[string, boolean]> = [
      ['six entries', ledger.length === phases.length],
      ['spec ended at exit 0', spec?.endedAt !== null && spec?.exitCode === 0],
      ['spec carries its note', spec?.note === 'no spec repository'],
      ['a re-invocation skips all six, bytes unchanged', said.every((x) => x.startsWith('skipped')) && said.length === phases.length && ledgerBytes(repo) === before],
    ];
    const failed = checks.find((check) => !check[1]);
    ok = failed === undefined;
    detail = failed ? `${failed[0]} is FALSE` : 'six entries, spec noted and ended at exit 0, re-invocation 6 skipped';
  } catch (error) { ok = false; detail = (error as Error).message; }
  results.push({ composite: 'hiraishin', case: 'the no-spec route', verdict: ok ? 'converged' : 'diverged', detail });
  rmSync(repo, { recursive: true, force: true });
}

// A ren ledger written before § 2a pinned the step names (zheref/hatsu#444, the live run of 2026-11-25):
// steps 4–6 named by their table labels. The resume reads each label as its row's step: `launch` ended is
// skipped, `report` open is continued under its own name, `jutaisho` begun; no step gets a second entry.
// Without the alias reading the same ledger gains a second launch entry, the defect the rule closes.
{
  EFFORT = COMPOSITES.ren!.effort;
  const phases = COMPOSITES.ren!.phases;
  const aliases = { amaterasu: ['launch'], 'spiritual-message': ['report'], jutaisho: ['bell'] };
  const written = ['breath', 'rasengan', 'kokusen', 'launch'];
  const seed = (repo: string): void => {
    for (const phase of written) { must(repo, begin(repo, phase)); must(repo, end(repo, phase)); }
    must(repo, begin(repo, 'report'));
  };
  let ok = true; let detail = '';
  const repo = freshRepo();
  const bare = freshRepo();
  const failedRepo = freshRepo();
  try {
    seed(repo);
    const inside: string[] = [];
    const said = resume(repo, phases, (phase) => { inside.push(phase); }, aliases);
    const ledger = show(repo);
    const names = ledger.phases.map((e) => e.phase);
    const report = ledger.phases.find((e) => e.phase === 'report');
    seed(bare);
    resume(bare, phases);
    const bareLaunch = show(bare).phases.filter((e) => e.phase === 'launch' || e.phase === 'amaterasu').length;
    // The refuse branch through a label: `launch` ended at exit 1 is refused by its recorded name, nothing written.
    for (const phase of ['breath', 'rasengan', 'kokusen']) { must(failedRepo, begin(failedRepo, phase)); must(failedRepo, end(failedRepo, phase)); }
    must(failedRepo, begin(failedRepo, 'launch'));
    must(failedRepo, ['phase', 'end', '--effort', EFFORT, '--phase', 'launch', '--exit', '1', '--repo', failedRepo]);
    const failedBefore = ledgerBytes(failedRepo);
    const refusedSaid = resume(failedRepo, phases, undefined, aliases);
    const checks: Array<[string, boolean]> = [
      ['six entries, named as written', JSON.stringify(names) === JSON.stringify([...written, 'report', 'jutaisho'])],
      ['every entry ended at exit 0', ledger.phases.every((e) => e.endedAt !== null && e.exitCode === 0)],
      ['report continued once', (report?.resumedAt?.length ?? 0) === 1],
      ['the work inside a step sees the step, not the label', JSON.stringify(inside) === JSON.stringify(['spiritual-message', 'jutaisho'])],
      ['the resume said it, naming each entry as recorded', JSON.stringify(said) === JSON.stringify(['skipped breath', 'skipped rasengan', 'skipped kokusen', 'skipped launch', 'resumed report', 'began jutaisho'])],
      ['the bare-name read doubles the launch step', bareLaunch === 2],
      ['a label ended non-zero is refused by name, ledger unchanged', refusedSaid[refusedSaid.length - 1] === 'refused launch: ended at exit 1' && ledgerBytes(failedRepo) === failedBefore],
    ];
    const failed = checks.find((check) => !check[1]);
    ok = failed === undefined;
    detail = failed ? `${failed[0]} is FALSE (${said.join('; ')})` : '4 skipped, report resumed under its own name, a failed launch refused by name; by bare name the launch step gets 2 entries';
  } catch (error) { ok = false; detail = (error as Error).message; }
  results.push({ composite: 'ren', case: 'a ledger naming steps 4-6 by label', verdict: ok ? 'converged' : 'diverged', detail });
  rmSync(repo, { recursive: true, force: true });
  rmSync(bare, { recursive: true, force: true });
  rmSync(failedRepo, { recursive: true, force: true });
}

// begin --resume while another phase is open: refused, exit 2.
{
  EFFORT = BRANCH;
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
  const start = ['run', 'start', '--id', id, '--target', 'zheref/hatsu', '--repo', repo, '--idle-answers', '{"host-nen-link":"default"}', '--json'];
  const park = ['run', 'park', '--id', id, '--issue', 'zheref/hatsu#444', '--row', 'g5-harness-denied', '--repo', repo, '--json'];
  let ok = true; let detail = '';
  try {
    const started = mustJson(repo, start, 'nen run start'); mustJson(repo, park, 'nen run park');
    const path = started.path;
    const before = readFileSync(path, 'utf8');
    // ← killed after the park; the same line again.
    const again = mustJson(repo, start, 'nen run start');
    const repark = mustJson(repo, park, 'nen run park');
    // Named one by one, so a divergence says WHICH of the three did not hold rather than printing two
    // outcomes that both read as correct.
    const checks: Array<[string, boolean]> = [
      ['re-start answered existing', again.outcome === 'existing'],
      ['re-park answered unchanged', repark.outcome === 'unchanged'],
      ['manifest bytes unchanged', readFileSync(path, 'utf8') === before],
    ];
    const failed = checks.find((check) => !check[1]);
    ok = failed === undefined;
    detail = failed
      ? `${failed[0]} is FALSE (re-start ${again.outcome}, re-park ${repark.outcome})`
      : 're-start existing, re-park unchanged, manifest bytes unchanged';
  } catch (error) { ok = false; detail = (error as Error).message; }
  results.push({ composite: 'futon (and kazaana)', case: 'killed after a park, re-invoked', verdict: ok ? 'converged' : 'diverged', detail });
  rmSync(repo, { recursive: true, force: true });
}

// A FAILING nen call's text reaches a row's `detail` too, and both call sites owe it the same excerpt
// — a duty one of them missed once, caught in review (zheref/hatsu#576). Live, because what a refusal
// prints is the dependency's to decide: `run park` on an unstarted id quotes the manifest's absolute
// path, so a raw interpolation would put a host path in the row.
{
  const repo = freshRepo();
  let message = '';
  try { mustJson(repo, ['run', 'park', '--id', 'not-a-run-id', '--issue', 'zheref/hatsu#444', '--row', 'g5-harness-denied', '--repo', repo, '--json'], 'nen run park'); }
  catch (error) { message = (error as Error).message; }
  const held = message !== '' && !/\/(?:Users|home|private|var|tmp)\//.test(message) && message.includes('<path>');
  results.push({
    composite: 'any',
    case: 'a failing nen call quoted into a row',
    verdict: held ? 'converged' : 'diverged',
    detail: held ? 'excerpted: the host path is elided before it reaches the row' : message || 'the call did not fail, so nothing was quoted',
  });
  rmSync(repo, { recursive: true, force: true });
}

// How the row above reads that answer. Proved on a payload rather than on a live run, because the
// shapes that break the read are the ones a healthy nen never prints (zheref/hatsu#574).
{
  const manifest = '/tmp/resume-proof-x/.git/.nen/runs/0123456789abcdef0123456789abcdef.json';
  const payload = JSON.stringify({ outcome: 'started', path: manifest, reason: null, manifest: { contract: 'nen.run/v0.1' }, mode: { verdict: 'set', file: '0600', directory: '0700' } }, null, 2);
  let read: RunAnswer | null = null; let refusal = '';
  try { read = runAnswer(payload, 'nen run start'); } catch (error) { refusal = (error as Error).message; }
  const got = read !== null && read.path === manifest && read.outcome === 'started';
  results.push({
    composite: 'any',
    case: 'an answer carrying a mode block',
    verdict: got ? 'converged' : 'diverged',
    detail: got ? 'outcome and path read as fields; every other key ignored' : refusal || `read ${JSON.stringify(read)}`,
  });
}
{
  // A refusal names the missing field, and its excerpt is bounded and carries no absolute path: a
  // row's detail is printed by this lane and transcribed into public prose (SEC-12).
  const payload = JSON.stringify({ outcome: 'started', reason: `could not write under /Users/someone/${'x'.repeat(400)}` });
  let refusal = '';
  try { runAnswer(payload, 'nen run start'); } catch (error) { refusal = (error as Error).message; }
  const named = refusal.includes("printed no 'path'");
  const safe = refusal.length <= 240 && !refusal.includes('/Users/') && refusal.includes('<path>');
  results.push({
    composite: 'any',
    case: 'an answer missing its path field',
    verdict: named && safe ? 'converged' : 'diverged',
    detail: named && safe ? "refused naming 'path', the excerpt bounded and path-free" : refusal || 'returned a path instead of refusing',
  });
}

const diverged = results.filter((r) => r.verdict === 'diverged');
if (json) console.log(JSON.stringify({ contract: 'hatsu.resume-proof/v0.1', nen: must(tmpdir(), ['--version']).trim(), results, diverged: diverged.length }, null, 2));
else {
  for (const r of results) console.log(`${r.verdict.padEnd(9)} ${r.composite.padEnd(20)} ${r.case.padEnd(36)} ${r.detail}`);
  console.log(`resume-proof: ${results.length - diverged.length}/${results.length} converged`);
}
process.exit(diverged.length === 0 ? 0 : 1);
