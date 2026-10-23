#!/usr/bin/env node
// shell_coverage.mts — the focused shell lanes' line coverage (zheref/hatsu#148, UZF-19).
//
// USAGE
//   node scripts/shell_coverage.mts --capture <lane> <bash|sh> <fixture> [args...]
//   node scripts/shell_coverage.mts --verify <lane>
//   node scripts/shell_coverage.mts --bash-version
//
// --capture is a lane's declared `test` row: it runs the fixture and, where the pinned Bashcov
// and a Bash 5+ are on this host, runs it under Bashcov and writes coverage/<lane>/lcov.info with
// repository-relative SF: paths, naming only the scripts the run executed (a script another lane
// covers is unmatched here, never a false 0%). A `sh` fixture runs under sh first, so its POSIX check is kept,
// then once more instrumented. Without Bashcov (or with HATSU_SHELL_COVERAGE=0) the fixture runs
// once, uninstrumented, the stale report is removed, and stderr says so: nen then records no
// capture, and `nen shu coverage --from-capture` refuses rather than reading an old number.
// HATSU_SHELL_COVERAGE=require turns a missing tool into exit 2; HATSU_COVERAGE_BASH names the Bash 5+
// to try first. --verify is the lane's `coverage`
// row: it reads the report already on disk and runs no fixture (byakugan § 3-4: the coverage row
// extracts, it never reruns tests). --bash-version is `nen shu tools`'s probe for the bash row.
//
// EXIT CODES
//   0  the fixture passed (instrumented or not) · --verify found a report · a Bash 5+ was found
//   1  the fixture failed (an incomplete Bashcov trace on a passing fixture is 0, no report)
//   2  usage, an undeclared invocation, a missing report, or a required tool absent
import { existsSync, lstatSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { delimiter, dirname, join, relative, resolve, sep } from 'node:path';
import { platform } from 'node:process';

function fail(message: string, code = 2): never {
  console.error(`shell-coverage: ${message}`);
  process.exit(code);
}

function findBash(): { path: string; version: string } | undefined {
  const fixed = platform === 'darwin'
    ? ['/opt/homebrew/bin/bash', '/usr/local/bin/bash']
    : platform === 'linux' ? ['/usr/bin/bash', '/bin/bash'] : [];
  const onPath = (process.env.PATH ?? '').split(delimiter).filter(Boolean).map((d) => join(d, 'bash'));
  const chosen = process.env.HATSU_COVERAGE_BASH ? [process.env.HATSU_COVERAGE_BASH] : [];
  for (const path of [...chosen, ...fixed, ...onPath]) {
    if (!existsSync(path)) continue;
    const probe = spawnSync(path, ['--version'], { encoding: 'utf8' });
    const version = probe.stdout?.match(/GNU bash, version (\d+\.\d+\.\d+)/)?.[1];
    if (probe.status === 0 && version && Number(version.split('.')[0]) >= 5) return { path, version };
  }
  return undefined;
}

const [mode, lane, interp, fixture, ...extra] = process.argv.slice(2);
if (mode === '--bash-version') {
  const bash = findBash();
  if (!bash) fail('no Bash 5+ found (Bashcov needs BASH_XTRACEFD); install one and rerun');
  console.log(bash.version);
  process.exit(0);
}
if (!['--capture', '--verify'].includes(mode ?? '') || !lane || !/^[a-z][a-z0-9-]*$/.test(lane) ||
    (mode === '--verify' && interp !== undefined)) {
  fail('expected --capture <lane> <bash|sh> <fixture> [args...] or --verify <lane>');
}
const root = process.cwd();
const dir = join(root, 'coverage', lane);
const report = join(dir, 'lcov.info');
const shown = relative(root, report);
if (mode === '--verify') {
  if (!existsSync(report) || !readFileSync(report, 'utf8').includes('SF:scripts/')) {
    fail(`${shown} holds no shell coverage; run \`nen shu test --lane ${lane}\` with Bashcov installed first`);
  }
  console.log(`shell-coverage: read ${shown}; no fixture ran`);
  process.exit(0);
}

if (interp !== 'bash' && interp !== 'sh') fail(`${lane}: the interpreter must be bash or sh, not ${interp ?? 'nothing'}`);
if (!fixture || !/^scripts\/[A-Za-z0-9_./-]+\.sh$/.test(fixture) || fixture.includes('..')) {
  fail(`${lane}: ${fixture ?? 'no fixture'} is not a repository shell script under scripts/`);
}
const fixturePath = resolve(root, fixture);
if (!existsSync(fixturePath) || !lstatSync(fixturePath).isFile()) fail(`${lane}: ${fixture} must be a regular file`);

// The helper runs only as the lane declares it: the argv after the script name must match exactly.
let contract: any;
try { contract = JSON.parse(readFileSync(join(root, 'nen', 'contract.json'), 'utf8')); }
catch { fail('cannot read nen/contract.json'); }
const declared: unknown = contract?.project?.verbs?.[lane]?.test?.argv;
const argv = Array.isArray(declared) ? declared : [];
const at = argv.indexOf('scripts/shell_coverage.mts');
const tail = ['--capture', lane, interp, fixture, ...extra];
if (at < 0 || JSON.stringify(argv.slice(at + 1)) !== JSON.stringify(tail)) {
  fail(`${lane} does not declare this exact invocation in nen/contract.json`);
}

const setting = (process.env.HATSU_SHELL_COVERAGE ?? 'auto').toLowerCase();
if (!['auto', '0', 'off', 'require'].includes(setting)) {
  fail(`HATSU_SHELL_COVERAGE=${setting} is not one of auto, 0, off, require`);
}
// Bashcov runs at the exact versions project.toolchain pins, activated through RubyGems, so a user
// gem home off PATH still resolves and a newer installed release is never picked up silently.
const pins = contract?.project?.toolchain ?? {};
const bashcovPin = String(pins.bashcov?.version ?? '');
const lcovPin = String(pins['simplecov-lcov']?.version ?? '');
if (!/^\d+\.\d+\.\d+$/.test(bashcovPin) || !/^\d+\.\d+\.\d+$/.test(lcovPin)) {
  fail('nen/contract.json must pin project.toolchain.bashcov and simplecov-lcov to exact versions');
}
const launcher = ['-e', "gem 'bashcov', ARGV.shift; load Gem.bin_path('bashcov', 'bashcov')", bashcovPin];
const bashcov = spawnSync('ruby', [...launcher, '--version'], { encoding: 'utf8' });
const bash = findBash();
const missing = bashcov.error || bashcov.status !== 0
  ? `bashcov ${bashcovPin} is not installed (nen shu tools --repo . --install)`
  : !bash ? 'no Bash 5+ is installed' : '';
const scratch = ['.resultset.json', '.resultset.json.lock', '.last_run.json'].map((name) => join(dir, name));
for (const stale of [report, ...scratch]) rmSync(stale, { force: true });

function plain(exe: string): number {
  const run = spawnSync(exe, [fixture, ...extra], { cwd: root, stdio: 'inherit' });
  if (run.error) fail(`${lane}: ${exe} could not start (${run.error.message})`);
  return run.status ?? 1;
}

if (setting === '0' || setting === 'off' || missing) {
  if (missing && setting === 'require') fail(`${lane}: HATSU_SHELL_COVERAGE=require and ${missing}`);
  const status = plain(interp);
  console.error(`shell-coverage: ${lane} ran uninstrumented (${missing || `HATSU_SHELL_COVERAGE=${setting}`}); no coverage captured`);
  process.exit(status);
}
const bash5 = bash!;
if (interp === 'sh') {
  const status = plain('sh');
  if (status !== 0) process.exit(status);
}
mkdirSync(dir, { recursive: true });
const run = spawnSync('ruby', [...launcher, '--skip-uncovered', '--bash-path', bash5.path, '--root', root, '--', fixture, ...extra], {
  cwd: root, encoding: 'utf8', maxBuffer: 256 * 1024 * 1024,
  env: {
    ...process.env,
    // A child `bash` resolves to the same Bash 5: an older one has no BASH_XTRACEFD and would print
    // the trace on stderr, where fixtures read their own output.
    PATH: [dirname(bash5.path), process.env.PATH].filter(Boolean).join(delimiter),
    HATSU_COVERAGE_PATH: join('coverage', lane, 'lcov.info'),
    HATSU_COVERAGE_DIR: join('coverage', lane),
    HATSU_SIMPLECOV_LCOV_VERSION: lcovPin,
  },
});
if (run.stdout) process.stdout.write(run.stdout);
// Bashcov can leak its trace prefix through children that re-enter a shell; drop only those lines.
const stderr = (run.stderr ?? '').replace(/^\+BASHCOV>[^\n]*\n/gm, '');
if (stderr) process.stderr.write(stderr);
if (run.error || run.status !== 0) {
  rmSync(report, { force: true });
  fail(`${lane} fixture failed under Bashcov (${run.error?.message ?? `exit ${run.status}`})`, 1);
}
// The fixture passed. A trace Bashcov could not parse (children interleaving on the trace fd) is a
// measurement that did not happen, not a red test: no report is kept, so nothing reads a partial one.
if (/Aborting early; coverage report will be incomplete|XtraceError|terminated with exception/i.test(run.stderr ?? '')) {
  rmSync(report, { force: true });
  console.error(`shell-coverage: ${lane} passed, but Bashcov's trace is incomplete; no coverage captured`);
  process.exit(0);
}
if (!existsSync(report)) fail(`${lane}: Bashcov wrote no ${shown}`);
let files = 0;
const normalized = readFileSync(report, 'utf8').replace(/^SF:(.+)$/gm, (_line, raw: string) => {
  const path = relative(root, resolve(root, raw));
  if (!path || path === '..' || path.startsWith(`..${sep}`) || path.startsWith(sep)) {
    rmSync(report, { force: true });
    fail(`${lane}: Bashcov reported ${raw}, outside the repository`);
  }
  if (path.startsWith('scripts/')) files++;
  return `SF:${path}`;
});
if (!files) {
  rmSync(report, { force: true });
  fail(`${lane}: Bashcov reported no repository script`);
}
writeFileSync(report, normalized);
for (const leftover of scratch) rmSync(leftover, { force: true });
console.log(`shell-coverage: ${lane} wrote ${shown} for ${files} script files`);
