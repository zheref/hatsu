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
// to try first. SimpleCov and Bashcov are activated at the exact versions project.toolchain pins, and
// each installed .gem is checked against the row's gemSha256 before anything runs under it: a
// mismatch is exit 2 (nen's gem-user installer pins by version only). A capture writes
// coverage/<lane>/provenance.json, the sha256 of the report and of every file it names.
// --verify is the lane's `coverage` row: it runs no fixture (byakugan § 3-4: the coverage row
// extracts, it never reruns tests) and refuses a report whose provenance no longer matches the tree.
// --bash-version is `nen shu tools`'s probe for the bash row.
//
// EXIT CODES
//   0  the fixture passed (instrumented or not) · --verify found a current report · a Bash 5+ was found
//   1  the fixture failed (a trace Bashcov could not parse is re-run plain, and that run decides)
//   2  usage, an undeclared invocation, a missing or stale report, a required tool absent, a pin
//      that is not exact, or a gem whose checksum differs from its pin
import { existsSync, lstatSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
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
const provenance = join(dir, 'provenance.json');
const sha256 = (path: string) => createHash('sha256').update(readFileSync(path)).digest('hex');
const sources = (text: string) => [...text.matchAll(/^SF:(.+)$/gm)].map((m) => m[1]);
if (mode === '--verify') {
  const rerun = `run \`nen shu test --lane ${lane}\` with Bashcov installed`;
  if (!existsSync(report) || !readFileSync(report, 'utf8').includes('SF:scripts/')) {
    fail(`${shown} holds no shell coverage; ${rerun} first`);
  }
  let recorded: any;
  try { recorded = JSON.parse(readFileSync(provenance, 'utf8')); }
  catch { fail(`${shown} has no readable ${relative(root, provenance)}, so its tree is unknown; ${rerun}`); }
  if (recorded?.lane !== lane || recorded?.report !== sha256(report)) {
    fail(`${shown} is not the report ${relative(root, provenance)} recorded; ${rerun}`);
  }
  const files: Record<string, string> = recorded?.files ?? {};
  const named = sources(readFileSync(report, 'utf8'));
  const stale = named.filter((path) => !files[path] || !existsSync(join(root, path)) || sha256(join(root, path)) !== files[path]);
  if (stale.length) fail(`${shown} is stale: ${stale.join(', ')} changed since the capture; ${rerun}`);
  console.log(`shell-coverage: read ${shown}, current for its ${named.length} files; no fixture ran`);
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
// SimpleCov is activated at its pin BEFORE Bashcov, so Bashcov's own '~> 1.1' never resolves to a
// newer installed release; a user gem home off PATH still resolves.
const pins = contract?.project?.toolchain ?? {};
const gems = ['simplecov', 'bashcov', 'simplecov-lcov'].map((name) => ({
  name, version: String(pins[name]?.version ?? ''), digest: String(pins[name]?.gemSha256 ?? ''),
}));
for (const gem of gems) {
  if (!/^\d+\.\d+\.\d+$/.test(gem.version) || !/^[0-9a-f]{64}$/.test(gem.digest)) {
    fail(`nen/contract.json must pin project.toolchain.${gem.name} to an exact version and a gemSha256`);
  }
}
const [simplecovPin, bashcovPin, lcovPin] = gems.map((gem) => gem.version);
const launcher = ['-e', "gem 'simplecov', ARGV.shift; gem 'bashcov', ARGV.shift; load Gem.bin_path('bashcov', 'bashcov')", simplecovPin, bashcovPin];
const bashcov = spawnSync('ruby', [...launcher, '--version'], { encoding: 'utf8' });
const bash = findBash();
const missing = bashcov.error || bashcov.status !== 0
  ? `bashcov ${bashcovPin} with simplecov ${simplecovPin} is not installed (nen shu tools --repo . --install)`
  : !bash ? 'no Bash 5+ is installed' : '';
const scratch = ['.resultset.json', '.resultset.json.lock', '.last_run.json'].map((name) => join(dir, name));
for (const stale of [report, provenance, ...scratch]) rmSync(stale, { force: true });

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
// Each gem's cached .gem must match its pinned digest before any code from it runs here.
const where = spawnSync('ruby', ['-e', 'ARGV.each_slice(2) { |n, v| puts Gem::Specification.find_by_name(n, v).cache_file }',
  ...gems.flatMap((gem) => [gem.name, gem.version])], { encoding: 'utf8' });
const caches = where.status === 0 ? (where.stdout ?? '').split('\n').filter(Boolean) : [];
if (caches.length !== gems.length) fail(`${lane}: cannot locate the installed .gem files to verify their checksums`);
gems.forEach((gem, i) => {
  if (!existsSync(caches[i]) || sha256(caches[i]) !== gem.digest) {
    fail(`${lane}: ${gem.name} ${gem.version} at ${caches[i]} does not match its pinned gemSha256; reinstall it (gem uninstall --user-install ${gem.name} -v ${gem.version}, then nen shu tools --repo . --install)`);
  }
});
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
// A trace Bashcov could not parse (children interleaving on the trace fd) is a measurement that did
// not happen. No report is kept, so nothing reads a partial one; a passing run stays green, and a
// failing one is re-run plain, because the abort cannot be told apart from the fixture's own failure.
const aborted = /Aborting early; coverage report will be incomplete|XtraceError|terminated with exception/i.test(run.stderr ?? '');
if (aborted) {
  rmSync(report, { force: true });
  if (run.status !== 0) {
    console.error(`shell-coverage: ${lane}: Bashcov's trace is incomplete and the run exited ${run.status}; re-running it uninstrumented`);
    const status = plain(interp);
    console.error(`shell-coverage: ${lane} ran uninstrumented after an incomplete trace; no coverage captured`);
    process.exit(status);
  }
  console.error(`shell-coverage: ${lane} passed, but Bashcov's trace is incomplete; no coverage captured`);
  process.exit(0);
}
if (run.error || run.status !== 0) {
  rmSync(report, { force: true });
  fail(`${lane} fixture failed under Bashcov (${run.error?.message ?? `exit ${run.status}`})`, 1);
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
const recorded: Record<string, string> = {};
for (const path of sources(normalized)) {
  if (existsSync(join(root, path))) recorded[path] = sha256(join(root, path));
}
writeFileSync(provenance, `${JSON.stringify({ lane, report: sha256(report), files: recorded }, null, 2)}\n`);
for (const leftover of scratch) rmSync(leftover, { force: true });
console.log(`shell-coverage: ${lane} wrote ${shown} for ${files} script files`);
