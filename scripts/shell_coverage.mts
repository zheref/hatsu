#!/usr/bin/env node
// shell_coverage.mts — the focused shell lanes' line coverage (zheref/hatsu#148, UZF-19).
//
// USAGE
//   node scripts/shell_coverage.mts --capture <lane> <bash|sh> <fixture> [--target <script>]... [--trace-substitutions] [args...]
//   node scripts/shell_coverage.mts --verify <lane>
//   node scripts/shell_coverage.mts --bash-version
//
// --capture is a lane's declared `test` row: it runs the fixture and, where the pinned Bashcov
// and a Bash 5+ are on this host, runs it under Bashcov and writes coverage/<lane>/lcov.info with
// repository-relative SF: paths, naming only the scripts the run executed (a script another lane
// covers is unmatched here, never a false 0%). Repeated `--target` arguments name an exact set; every
// target must appear before provenance is written. Each gets a wrapper (EXEC, EXEC_2, ...) and keeps
// the fixture and its descendants off the shared trace descriptor, then traces only that script through
// a short-lived wrapper using an O_APPEND regular trace file drained sequentially after exit (zheref/hatsu#599).
// Root-shell records retain Bashcov's fields; nested command/process substitutions emit no Bashcov prefix
// or field delimiter, so the parser ignores them instead of interleaving them. A serial target can
// explicitly opt in with --trace-substitutions to retain its nested records. The report is filtered to
// the declared sources. A `sh` fixture runs under sh first, so its POSIX check is kept, then once more
// instrumented. Without Bashcov (or with HATSU_SHELL_COVERAGE=0) the fixture runs once, uninstrumented,
// the stale report is removed, and stderr says so: nen then records no capture, and
// `nen shu coverage --from-capture` refuses rather than reading an old number.
// HATSU_SHELL_COVERAGE=require turns a missing tool or an empty/unmeasured abort into exit 2;
// HATSU_COVERAGE_BASH names the Bash 5+ to try first. SimpleCov and Bashcov are activated at the exact
// versions project.toolchain pins, and each installed .gem is checked against the row's gemSha256 before
// anything runs under it: a mismatch is exit 2 (nen's gem-user installer pins by version only). A capture
// writes coverage/<lane>/provenance.json, the sha256 of the report and of every file it names.
// --verify is the lane's `coverage` row: it runs no fixture (byakugan § 3-4: the coverage row
// extracts, it never reruns tests) and refuses a report whose provenance no longer matches the tree.
// --bash-version is `nen shu tools`'s probe for the bash row.
//
//   EXIT CODES
//   0  the fixture passed (instrumented or not, or valid partial LCOV retained on trace abort) · --verify found a current report · a Bash 5+ was found
//   1  the fixture failed (a trace Bashcov could not parse is re-run plain, and that run decides)
//   2  usage, an undeclared invocation, a missing or stale report, a required tool absent, a pin
//      that is not exact, a gem whose checksum differs from its pin, or 0 coverage captured under HATSU_SHELL_COVERAGE=require
import { existsSync, lstatSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { delimiter, dirname, join, relative, resolve, sep } from 'node:path';
import { platform } from 'node:process';
import { tmpdir } from 'node:os';

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
    if (/[\r\n]/.test(path) || !existsSync(path)) continue;
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
  fail('expected --capture <lane> <bash|sh> <fixture> [--target <script>]... [--trace-substitutions] [args...] or --verify <lane>');
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
  if (!existsSync(report) || !lstatSync(report).isFile() || !readFileSync(report, 'utf8').includes('SF:scripts/')) {
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
  const stale = named.filter((path) => {
    const full = join(root, path);
    return !files[path] || !existsSync(full) || !lstatSync(full).isFile() || sha256(full) !== files[path];
  });
  if (stale.length) fail(`${shown} is stale: ${stale.join(', ')} changed since the capture; ${rerun}`);
  console.log(`shell-coverage: read ${shown}, current for its ${named.length} files${recorded?.partial ? ' (partial capture)' : ''}; no fixture ran`);
  process.exit(0);
}

if (interp !== 'bash' && interp !== 'sh') fail(`${lane}: the interpreter must be bash or sh, not ${interp ?? 'nothing'}`);
if (!fixture || !/^scripts\/[A-Za-z0-9_./-]+\.sh$/.test(fixture) || fixture.includes('..')) {
  fail(`${lane}: ${fixture ?? 'no fixture'} is not a repository shell script under scripts/`);
}
const fixturePath = resolve(root, fixture);
if (!existsSync(fixturePath) || !lstatSync(fixturePath).isFile()) fail(`${lane}: ${fixture} must be a regular file`);

let fixtureArgs = extra;
const targets: string[] = [];
while (fixtureArgs[0] === '--target') {
  const target = fixtureArgs[1];
  fixtureArgs = fixtureArgs.slice(2);
  if (!target || !/^scripts\/[A-Za-z0-9_./-]+\.sh$/.test(target) || target.includes('..')) {
    fail(`${lane}: ${target ?? 'no target'} is not a repository shell script under scripts/`);
  }
  if (targets.includes(target)) fail(`${lane}: duplicate coverage target ${target}`);
  targets.push(target);
  const targetPath = resolve(root, target);
  if (!existsSync(targetPath) || !lstatSync(targetPath).isFile()) fail(`${lane}: ${target} must be a regular file`);
}

// Serial targets can opt in to full command/process-substitution records. Complex concurrent
// fixtures keep the isolated root-only default; an opt-in belongs in the exact declared argv.
const traceSubstitutions = fixtureArgs[0] === '--trace-substitutions';
if (traceSubstitutions) {
  if (targets.length !== 1) fail(`${lane}: --trace-substitutions requires exactly one target`);
  fixtureArgs = fixtureArgs.slice(1);
}

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
const launcher = [
  '-e',
  "gem 'simplecov', ARGV.shift; gem 'bashcov', ARGV.shift; require 'fcntl'; require 'bashcov/xtrace'; Bashcov::Xtrace.prepend(Module.new { def initialize(...); super; if defined?(Fcntl::O_NONBLOCK) && @write; @write.fcntl(Fcntl::F_SETFL, @write.fcntl(Fcntl::F_GETFL) & ~Fcntl::O_NONBLOCK); end; end }); load Gem.bin_path('bashcov', 'bashcov')",
  simplecovPin,
  bashcovPin,
];
const scratch = ['.resultset.json', '.resultset.json.lock', '.last_run.json'].map((name) => join(dir, name));
for (const stale of [report, provenance, ...scratch]) rmSync(stale, { force: true });

function plain(exe: string): number {
  const run = spawnSync(exe, [fixture, ...fixtureArgs], { cwd: root, stdio: 'inherit' });
  if (run.error) fail(`${lane}: ${exe} could not start (${run.error.message})`);
  return run.status ?? 1;
}
function uninstrumented(why: string): never {
  if (setting === 'require') fail(`${lane}: HATSU_SHELL_COVERAGE=require and ${why}`);
  const status = plain(interp);
  console.error(`shell-coverage: ${lane} ran uninstrumented (${why}); no coverage captured`);
  process.exit(status);
}

if (setting === '0' || setting === 'off') uninstrumented(`HATSU_SHELL_COVERAGE=${setting}`);
// Each gem's cached .gem must match its pinned digest BEFORE any code from it runs: the lookup reads
// only installed specifications, and no gem is activated until every digest has matched.
const where = spawnSync('ruby', ['-e', 'ARGV.each_slice(2) { |n, v| puts Gem::Specification.find_by_name(n, v).cache_file }',
  ...gems.flatMap((gem) => [gem.name, gem.version])], { encoding: 'utf8' });
const caches = !where.error && where.status === 0 ? (where.stdout ?? '').split('\n').filter(Boolean) : [];
if (caches.length !== gems.length) {
  uninstrumented(`bashcov ${bashcovPin} with simplecov ${simplecovPin} and simplecov-lcov ${lcovPin} is not installed (nen shu tools --repo . --install)`);
}
// An absent cached .gem (an install with no cache, a cleaned cache) cannot be verified: that is a
// measurement that cannot happen, so the lane still runs, uninstrumented. A present one that differs
// fails closed.
const uncached = gems.filter((_gem, i) => !existsSync(caches[i]));
if (uncached.length) {
  uninstrumented(`gem cache absent for ${uncached.map((gem) => `${gem.name} ${gem.version}`).join(', ')}, so its checksum cannot be verified; reinstall through nen shu tools --repo . --install`);
}
gems.forEach((gem, i) => {
  if (sha256(caches[i]) !== gem.digest) {
    fail(`${lane}: ${gem.name} ${gem.version} at ${caches[i]} does not match its pinned gemSha256; reinstall it (gem uninstall --user-install ${gem.name} -v ${gem.version}, then nen shu tools --repo . --install)`);
  }
});
const bash = findBash();
if (!bash) uninstrumented('no Bash 5+ is installed');
const bash5 = bash!;
if (interp === 'sh') {
  const status = plain('sh');
  if (status !== 0) process.exit(status);
}
mkdirSync(dir, { recursive: true });
const shQuote = (value: string) => `'${value.replaceAll("'", "'\"'\"'")}'`;
let wrapperDir: string | undefined;
const targetEnvironment: Record<string, string> = {};
if (targets.length) {
  wrapperDir = mkdtempSync(join(tmpdir(), 'hatsu-shell-coverage-target-'));
  const traceDirLiteral = shQuote(wrapperDir);
  const bashLiteral = shQuote(bash5.path);
  for (const [index, target] of targets.entries()) {
    const wrapper = join(wrapperDir, `run-${index + 1}`);
    const suffix = index === 0 ? '' : `_${index + 1}`;
    targetEnvironment[`HATSU_SHELL_COVERAGE_EXEC${suffix}`] = wrapper;
    targetEnvironment[`HATSU_SHELL_COVERAGE_TARGET${suffix}`] = target;
    targetEnvironment[`HATSU_SHELL_COVERAGE_TARGET_PATH${suffix}`] = resolve(root, target);
    const targetLiteral = shQuote(resolve(root, target));
    const traceIndex = traceSubstitutions ? '0' : 'BASH_SUBSHELL>0';
    // The fixture moves Bashcov's exported PS4 and BASH_XTRACEFD into these dedicated transfer
    // variables before unexporting the originals. Enter via a /bin/sh trampoline that strips BASH_ENV/ENV
    // and supports spaces in the Bash 5 path, direct target xtrace via O_APPEND to a regular file so
    // macOS 512-byte pipe atomicity never splits or interleaves records, close parent_fd (>2) in the
    // child, and drain sequentially under a bounded lock with cleanup traps.
    const bashWrapperBody = `set -euo pipefail
set +x
coverage_bash=$1
target_path=$2
trace_dir=$3
shift 3
trace_ps4=\${HATSU_SHELL_COVERAGE_PS4}
parent_trace_fd=\${HATSU_SHELL_COVERAGE_TRACE_FD-}
if [[ ! "$parent_trace_fd" =~ ^[0-9]+$ ]]; then
  printf 'shell-coverage: invalid HATSU_SHELL_COVERAGE_TRACE_FD: %s\\n' "$parent_trace_fd" >&2
  exit 1
fi
export -n HATSU_SHELL_COVERAGE_PS4 HATSU_SHELL_COVERAGE_TRACE_FD PS4 BASH_XTRACEFD SHELLOPTS BASH_ENV ENV
unset BASH_ENV ENV
trace_file=''
drain_lock="\${trace_dir}/drain.lock"
lock_held=0
cleanup() {
  if [[ "$lock_held" -eq 1 ]]; then
    PATH="/usr/bin:/bin\${PATH:+:\$PATH}" rmdir "$drain_lock" 2>/dev/null || true
    lock_held=0
  fi
  if [[ -n "$trace_file" ]]; then
    PATH="/usr/bin:/bin\${PATH:+:\$PATH}" rm -f "$trace_file" 2>/dev/null || true
    trace_file=''
  fi
}
trap cleanup EXIT
child_pid=''
caught_signal=''
forward_signal() {
  caught_signal=$1
  if [[ -n "$child_pid" ]]; then
    kill -"$1" "$child_pid" 2>/dev/null || true
    return 0
  fi
  cleanup
  case "$1" in
    INT) exit 130 ;;
    TERM) exit 143 ;;
    HUP) exit 129 ;;
  esac
}
trap 'forward_signal INT' INT
trap 'forward_signal TERM' TERM
trap 'forward_signal HUP' HUP
trace_file="$(PATH="/usr/bin:/bin\${PATH:+:\$PATH}" mktemp "\${trace_dir}/trace.XXXXXX")"
exec {local_trace_fd}>>"$trace_file"
target_status=0
exec {saved_stdin}<&0
"$coverage_bash" -c '
  original_ps4=$1
  local_fd=$2
  parent_fd=$3
  saved_fd=$4
  shift 4
  if [[ "$saved_fd" =~ ^[0-9]+$ ]] && [[ "$saved_fd" -gt 2 ]] && [[ "$saved_fd" -ne "$local_fd" ]]; then
    eval "exec \${saved_fd}<&-"
  fi
  if [[ "$parent_fd" =~ ^[0-9]+$ ]] && [[ "$parent_fd" -gt 2 ]] && [[ "$parent_fd" -ne "$local_fd" ]]; then
    eval "exec \${parent_fd}>&-"
  fi
  BASH_XTRACEFD="$local_fd"
  export -n PS4 BASH_XTRACEFD SHELLOPTS BASH_ENV ENV
  delimiter=\${original_ps4#*BASHCOV>}
  delimiter=\${delimiter%%\\$\\{LINENO-\\}*}
  prefix=("+BASHCOV>\${delimiter}" "")
  field=("\${delimiter}" "")
  empty=
  lineno_name=(LINENO empty)
  source_name=(BASH_SOURCE empty)
  pwd_name=(PWD empty)
  oldpwd_name=(OLDPWD empty)
  PS4="\\\${prefix[${traceIndex}]}\\\${!lineno_name[${traceIndex}]-}\\\${field[${traceIndex}]}\\\${!source_name[${traceIndex}]-}\\\${field[${traceIndex}]}\\\${!pwd_name[${traceIndex}]-}\\\${field[${traceIndex}]}\\\${!oldpwd_name[${traceIndex}]-}\\\${field[${traceIndex}]}"
  set -x
  source "$0"
  target_status=$?
  exit "$target_status"
' "$target_path" "$trace_ps4" "$local_trace_fd" "$parent_trace_fd" "$saved_stdin" "$@" <&"$saved_stdin" &
child_pid=$!
exec {saved_stdin}<&-
while true; do
  caught_signal=''
  set +e
  wait "$child_pid"
  wait_status=$?
  set -e
  if [[ -z "$caught_signal" ]] || ! kill -0 "$child_pid" 2>/dev/null; then
    target_status=$wait_status
    break
  fi
done
child_pid=''
exec {local_trace_fd}>&-
spin=0
while ! PATH="/usr/bin:/bin\${PATH:+:\$PATH}" mkdir "$drain_lock" 2>/dev/null; do
  if [[ ! -d "$trace_dir" ]]; then
    printf 'shell-coverage: trace directory missing while awaiting drain lock\\n' >&2
    exit 1
  fi
  spin=$((spin + 1))
  if [[ "$spin" -ge 1500 ]]; then
    printf 'shell-coverage: timed out waiting for trace drain lock\\n' >&2
    exit 1
  fi
  PATH="/usr/bin:/bin\${PATH:+:\$PATH}" sleep 0.01
done
lock_held=1
PATH="/usr/bin:/bin\${PATH:+:\$PATH}" cat "$trace_file" >&"$parent_trace_fd" || exit 1
PATH="/usr/bin:/bin\${PATH:+:\$PATH}" rmdir "$drain_lock" 2>/dev/null || true
lock_held=0
PATH="/usr/bin:/bin\${PATH:+:\$PATH}" rm -f "$trace_file"
trace_file=''
exit "$target_status"
`;
    writeFileSync(wrapper, `#!/bin/sh
set -eu
unset BASH_ENV ENV
coverage_bash=\${HATSU_SHELL_COVERAGE_BASH:-}
[ -n "$coverage_bash" ] || coverage_bash=${bashLiteral}
exec "$coverage_bash" -c ${shQuote(bashWrapperBody)} _ "$coverage_bash" ${targetLiteral} ${traceDirLiteral} "$@"
`, { mode: 0o700 });
  }
}
const childEnv: Record<string, string | undefined> = { ...process.env };
delete childEnv.BASH_ENV;
delete childEnv.ENV;
let run: ReturnType<typeof spawnSync>;
try {
  run = spawnSync('ruby', [...launcher, '--skip-uncovered', '--bash-path', bash5.path, '--root', root, '--', fixture, ...fixtureArgs], {
    cwd: root, encoding: 'utf8', maxBuffer: 256 * 1024 * 1024,
    env: {
      ...childEnv,
      // A child `bash` resolves to the same Bash 5: an older one has no BASH_XTRACEFD and would print
      // the trace on stderr, where fixtures read their own output.
      PATH: [dirname(bash5.path), childEnv.PATH].filter(Boolean).join(delimiter),
      HATSU_COVERAGE_PATH: join('coverage', lane, 'lcov.info'),
      HATSU_COVERAGE_DIR: join('coverage', lane),
      HATSU_SIMPLECOV_LCOV_VERSION: lcovPin,
      ...targetEnvironment,
      ...(targets.length ? { HATSU_SHELL_COVERAGE_BASH: bash5.path } : {}),
    },
  });
} finally {
  if (wrapperDir) rmSync(wrapperDir, { recursive: true, force: true });
}
if (run.stdout) process.stdout.write(run.stdout);
// Bashcov can leak its trace prefix through children that re-enter a shell; drop only those lines.
const stderr = (run.stderr ?? '').replace(/^\+BASHCOV>[^\n]*\n/gm, '');
if (stderr) process.stderr.write(stderr);

function extractParseError(stderrText: string): string | undefined {
  const matches = stderrText
    .split('\n')
    .map((entry) => entry.trim())
    .filter((entry) => (
      /expected integer for LINENO,\s*got\b/i.test(entry)
      || /Encountered an error parsing Bash's output/i.test(entry)
      || /^bashcov:.*Aborting early; coverage report will be incomplete/i.test(entry)
      || /Bashcov::XtraceError/.test(entry)
      || /^#<Thread:[^>]+bashcov[^>]*> terminated with exception/i.test(entry)
    ));
  if (!matches.length) return undefined;
  return matches.join(' | ').slice(0, 240);
}

function finalizeReport(aborted: boolean, parseDetail?: string): never {
  if (!existsSync(report)) {
    if (aborted) {
      console.error(`shell-coverage: ${lane} passed, but Bashcov's trace was unparseable; unmeasured (no coverage captured): ${parseDetail}`);
      process.exit(setting === 'require' ? 2 : 0);
    }
    fail(`${lane}: Bashcov wrote no ${shown}`);
  }
  const normalizedAll = readFileSync(report, 'utf8').replace(/^SF:(.+)$/gm, (_line, raw: string) => {
    const path = relative(root, resolve(root, raw));
    if (!path || path === '..' || path.startsWith(`..${sep}`) || path.startsWith(sep)) {
      rmSync(report, { force: true });
      fail(`${lane}: Bashcov reported ${raw}, outside the repository`);
    }
    return `SF:${path}`;
  });
  const normalized = targets.length
    ? normalizedAll.split(/(?<=end_of_record\n)/).filter((record) => sources(record).some((path) => targets.includes(path))).join('')
    : normalizedAll;
  const namedSources = sources(normalized);
  const files = namedSources.filter((path) => path.startsWith('scripts/')).length;
  if (!files) {
    rmSync(report, { force: true });
    if (aborted) {
      console.error(`shell-coverage: ${lane} passed, but Bashcov's trace captured 0 files; unmeasured (no coverage captured): ${parseDetail}`);
      process.exit(setting === 'require' ? 2 : 0);
    }
    fail(`${lane}: Bashcov reported no ${targets.join(', ') || 'repository script'}`);
  }
  if (targets.length && (namedSources.some((path) => !targets.includes(path)) || (!aborted && targets.some((path) => !namedSources.includes(path))))) {
    rmSync(report, { force: true });
    fail(`${lane}: target capture did not report exactly its declared sources`);
  }
  writeFileSync(report, normalized);
  const recorded: Record<string, string> = {};
  for (const path of sources(normalized)) {
    const full = join(root, path);
    if (existsSync(full) && lstatSync(full).isFile()) recorded[path] = sha256(full);
  }
  writeFileSync(provenance, `${JSON.stringify({ lane, ...(aborted ? { partial: true } : {}), report: sha256(report), files: recorded }, null, 2)}\n`);
  for (const leftover of scratch) rmSync(leftover, { force: true });
  if (aborted) {
    console.error(`shell-coverage: ${lane} trace incomplete (${parseDetail}); retained partial coverage in ${shown} for ${files} script files`);
  } else {
    console.log(`shell-coverage: ${lane} wrote ${shown} for ${files} script files`);
  }
  process.exit(0);
}

// A trace Bashcov could not parse with a non-zero exit must be re-run plain, because the abort
// cannot be told apart from the fixture's own failure. When Bashcov exits 0 on a partial abort,
// retain whatever valid partial LCOV SimpleCov wrote, or report explicit unmeasured on 0 coverage.
const parseDetail = extractParseError(run.stderr ?? '');
const aborted = Boolean(parseDetail);
if (run.error || run.signal) {
  rmSync(report, { force: true });
  fail(`${lane} fixture failed under Bashcov (${run.error?.message ?? `signal ${run.signal}`})`, 1);
}
if (aborted && run.status !== 0) {
  rmSync(report, { force: true });
  console.error(`shell-coverage: ${lane}: Bashcov's trace is incomplete (${parseDetail}) and the run exited ${run.status}; re-running it uninstrumented`);
  const status = plain(interp);
  console.error(`shell-coverage: ${lane} ran uninstrumented after an incomplete trace; unmeasured (no coverage captured)`);
  if (status !== 0) process.exit(status);
  process.exit(setting === 'require' ? 2 : 0);
}
if (!aborted && run.status !== 0) {
  rmSync(report, { force: true });
  fail(`${lane} fixture failed under Bashcov (exit ${run.status})`, 1);
}
finalizeReport(aborted, parseDetail);
