// Shared behavior & guard cases for scripts/amaterasu_preview.mts (zheref/hatsu#617).
// Executed by both scripts/amaterasu_preview_fixture.test.mts (Vitest) and
// scripts/amaterasu_preview_coverage.test.mts (Node --test --experimental-test-coverage).
import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  realpathSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from 'node:fs';
import { createServer, type Server } from 'node:http';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { formatCommand, formatShellArg, parseCliArgs, renderHuman, runAmaterasuPreview } from './amaterasu_preview.mts';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const PREVIEW = join(ROOT, 'scripts', 'amaterasu_preview.mts');
const NEN = process.env.NEN || 'nen';

function mustGit(cwd: string, args: string[]): string {
  const res = spawnSync('git', ['-C', cwd, ...args], { encoding: 'utf8' });
  assert.equal(res.status, 0, `git ${args.join(' ')} failed: ${res.stderr}`);
  return res.stdout.trim();
}

function writeJson(path: string, value: unknown): void {
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`, 'utf8');
}

async function assertServerIntact(srv: Server, host: string, port: number): Promise<void> {
  assert.equal(srv.listening, true, 'existing session server stopped listening');
  const urlHost = host === '::1' ? '[::1]' : host;
  try {
    const res = await fetch(`http://${urlHost}:${port}/health`);
    assert.equal(res.status, 200, `expected 200 from session server, got ${res.status}`);
    assert.equal(await res.text(), 'existing-session-alive');
  } catch (err) {
    const cause = (err as { cause?: NodeJS.ErrnoException })?.cause ?? (err as NodeJS.ErrnoException);
    if (cause?.code !== 'EPERM' && cause?.code !== 'EACCES') throw err;
    await new Promise<void>((resolveCheck, rejectCheck) => {
      const probe = createServer();
      probe.once('error', (probeErr) => {
        const code = (probeErr as NodeJS.ErrnoException).code;
        if (code === 'EADDRINUSE' || code === 'EACCES') resolveCheck();
        else rejectCheck(probeErr);
      });
      probe.listen({ port, host, exclusive: true }, () => {
        probe.close(() => rejectCheck(new Error(`port ${port} on ${host} unexpectedly became free`)));
      });
    });
  }
}

function setupSampleWorkspace() {
  const rootTmp = realpathSync(mkdtempSync(join(tmpdir(), 'amaterasu-preview-')));
  const coreDir = join(rootTmp, 'core-app');
  const wtDir = join(rootTmp, 'wt-feature');
  const browserLog = join(rootTmp, 'browser-displays.jsonl');
  mkdirSync(coreDir, { recursive: true });
  mustGit(coreDir, ['init', '-b', 'main']);
  mustGit(coreDir, ['config', 'user.email', 'test@example.com']);
  mustGit(coreDir, ['config', 'user.name', 'Test User']);

  mkdirSync(join(coreDir, 'scripts'), { recursive: true });
  mkdirSync(join(coreDir, 'nen'), { recursive: true });
  writeFileSync(
    join(coreDir, 'scripts', 'open_preview.mjs'),
    `import { appendFileSync, readFileSync } from 'node:fs';
const [logFile, htmlPath, label] = process.argv.slice(2);
const html = readFileSync(htmlPath, 'utf8');
appendFileSync(logFile, JSON.stringify({ cwd: process.cwd(), label, htmlPath, html }) + '\\n');
`,
    'utf8',
  );
  writeFileSync(
    join(coreDir, 'scripts', 'hold_device.mjs'),
    `import { writeFileSync } from 'node:fs';
const [markerFile, msArg] = process.argv.slice(2);
writeFileSync(markerFile, String(process.pid), 'utf8');
setTimeout(() => {}, Number(msArg || 1500));
`,
    'utf8',
  );
  writeFileSync(join(coreDir, 'index.html'), '<h1>Main Checkout</h1>\n', 'utf8');
  writeJson(join(coreDir, 'nen', 'workflow.json'), {
    $schema: 'nen.workflow/v0.1',
    branch: { base: 'main', template: '{model}/{persona}/{descriptor}' },
    launch: { default: 'browser', fallback: null },
  });
  writeJson(join(coreDir, 'nen', 'contract.json'), {
    $schema: 'nen.contract/v0.1',
    project: {
      lanes: { web: { stack: 'static-html', cwd: '.' } },
      defaultLane: 'web',
      verbs: {
        web: {
          run: { exe: 'node', argv: ['scripts/open_preview.mjs', browserLog, 'index.html', 'core-index'] },
        },
      },
      launch: {
        browser: { lane: 'web', verb: 'run' },
      },
    },
  });
  mustGit(coreDir, ['add', '.']);
  mustGit(coreDir, ['commit', '-m', 'init core']);
  const coreHeadBefore = mustGit(coreDir, ['rev-parse', 'HEAD']);

  // Core keeps dirty uncommitted human edits intact throughout.
  writeFileSync(join(coreDir, 'index.html'), '<h1>Main Checkout (Dirty Human Edit)</h1>\n', 'utf8');
  writeFileSync(join(coreDir, 'core-notes.txt'), 'keep core dirty edits intact\n', 'utf8');

  mustGit(coreDir, ['worktree', 'add', '-b', 'feature/panel-preview', wtDir, 'main']);
  writeFileSync(join(wtDir, 'feature-page.html'), '<main>Worktree Page Committed v1</main>\n', 'utf8');

  return { rootTmp, coreDir, wtDir, browserLog, coreHeadBefore };
}

export interface AmaterasuCase {
  name: string;
  run: () => Promise<void> | void;
}

export const amaterasuPreviewCases: AmaterasuCase[] = [
  {
    name: 'AC-1, AC-2, SC-1, AC-4, AS-1: worktree preview renders committed + uncommitted edits with 0 core swaps & preserves automatic deferral',
    run: async () => {
      const { rootTmp, coreDir, wtDir, browserLog, coreHeadBefore } = setupSampleWorkspace();
      try {
        writeJson(join(wtDir, 'nen', 'contract.json'), {
          $schema: 'nen.contract/v0.1',
          project: {
            lanes: { web: { stack: 'static-html', cwd: '.' } },
            defaultLane: 'web',
            verbs: {
              web: {
                run: { exe: 'node', argv: ['scripts/open_preview.mjs', browserLog, 'feature-page.html', 'wt-preview'] },
              },
            },
            launch: { browser: { lane: 'web', verb: 'run' } },
          },
        });
        mustGit(wtDir, ['add', 'feature-page.html', 'nen/contract.json']);
        mustGit(wtDir, ['commit', '-m', 'add feature page']);
        const wtHeadBefore = mustGit(wtDir, ['rev-parse', 'HEAD']);
        assert(!existsSync(join(coreDir, 'feature-page.html')));

        // AC-1 + AC-4 (via workflow.launch.default omission too!)
        const ac1 = await runAmaterasuPreview({
          repo: wtDir,
          automatic: false,
          dryRun: false,
          json: true,
          nen: NEN,
          quiet: true,
        });
        assert.equal(ac1.exitCode, 0, ac1.output.error);
        assert.equal(ac1.output.status, 'preview launched');
        assert.equal(ac1.output.coreSwaps, 0);
        assert.equal(ac1.output.checkout, wtDir);
        assert.equal(ac1.output.target, 'browser');
        assert(ac1.output.command?.includes(`--repo ${wtDir}`) && ac1.output.command.includes('--target browser'));
        assert.equal(ac1.output.steps.length, 1);

        let displays = readFileSync(browserLog, 'utf8').trim().split('\n').map((l) => JSON.parse(l));
        assert.equal(displays.length, 1);
        assert(displays[0].html.includes('Worktree Page Committed v1'));

        // AC-2 + SC-1: uncommitted edit shows on 2nd preview while core & worktree retain branches and edits
        writeFileSync(join(wtDir, 'feature-page.html'), '<main>Worktree Page Uncommitted Edit v2</main>\n', 'utf8');
        const ac2 = await runAmaterasuPreview({
          repo: wtDir,
          target: 'browser',
          automatic: false,
          dryRun: false,
          json: true,
          nen: NEN,
          quiet: true,
        });
        assert.equal(ac2.exitCode, 0, ac2.output.error);
        assert(ac2.output.uncommittedPaths.includes('feature-page.html'));
        assert.equal(ac2.output.coreSwaps, 0);

        displays = readFileSync(browserLog, 'utf8').trim().split('\n').map((l) => JSON.parse(l));
        assert.equal(displays.length, 2);
        assert(displays[1].html.includes('Worktree Page Uncommitted Edit v2'));

        assert.equal(mustGit(coreDir, ['symbolic-ref', '--short', 'HEAD']), 'main');
        assert.equal(mustGit(coreDir, ['rev-parse', 'HEAD']), coreHeadBefore);
        assert.equal(readFileSync(join(coreDir, 'core-notes.txt'), 'utf8'), 'keep core dirty edits intact\n');
        assert(readFileSync(join(coreDir, 'index.html'), 'utf8').includes('Dirty Human Edit'));
        assert.equal(mustGit(wtDir, ['symbolic-ref', '--short', 'HEAD']), 'feature/panel-preview');
        assert.equal(mustGit(wtDir, ['rev-parse', 'HEAD']), wtHeadBefore);
        assert(readFileSync(join(wtDir, 'feature-page.html'), 'utf8').includes('Uncommitted Edit v2'));

        // AS-1: --automatic in a worktree retains core deferral
        const autoRes = await runAmaterasuPreview({
          repo: wtDir,
          target: 'browser',
          automatic: true,
          dryRun: false,
          json: true,
          nen: NEN,
          quiet: true,
        });
        assert.equal(autoRes.exitCode, 0);
        assert.equal(autoRes.output.status, 'core launch deferred; explicit maintainer call required');
        assert.equal(autoRes.output.deferred, true);
        assert.equal(autoRes.output.executed, false);
        assert.equal(autoRes.output.checkout, coreDir);
        assert.equal(readFileSync(browserLog, 'utf8').trim().split('\n').length, 2);

        // Launching core explicitly checks `nen wc swap --status` cleanly
        const coreRun = await runAmaterasuPreview({
          repo: coreDir,
          target: 'browser',
          automatic: false,
          dryRun: false,
          json: true,
          nen: NEN,
          quiet: true,
        });
        assert.equal(coreRun.exitCode, 0, coreRun.output.error);
        assert.equal(coreRun.output.checkout, coreDir);

        // Human formatter sanitizes ANSI escapes
        const sanitized = renderHuman({ ...ac2.output, branch: 'feat\x1b[31mred' });
        assert(!sanitized.includes('\x1b'));
      } finally {
        rmSync(rootTmp, { recursive: true, force: true });
      }
    },
  },
  {
    name: 'AC-3 & SC-2: occupied IPv4 127.0.0.1 and IPv6 ::1 ports refuse cleanly, keep listeners alive, and --dry-run stays non-blocking',
    run: async () => {
      const { rootTmp, wtDir, browserLog } = setupSampleWorkspace();
      const srv4 = createServer((_req, res) => { res.writeHead(200); res.end('existing-session-alive'); });
      let srv6: Server | null = createServer((_req, res) => { res.writeHead(200); res.end('existing-session-alive'); });
      try {
        await new Promise<void>((resolve4) => srv4.listen(0, '127.0.0.1', () => resolve4()));
        const port4 = (srv4.address() as { port: number }).port;

        let port6: number | null = null;
        try {
          await new Promise<void>((resolve6, reject6) => {
            srv6!.once('error', reject6);
            srv6!.listen(0, '::1', () => resolve6());
          });
          port6 = (srv6.address() as { port: number }).port;
        } catch {
          srv6 = null;
        }

        const preconditions: Record<string, unknown> = {
          p4: [{ kind: 'port', value: port4, expect: 'free' }],
        };
        const lanes: Record<string, unknown> = {
          p4: { stack: 'static-html', cwd: '.' },
          missingfile: { stack: 'static-html', cwd: '.' },
          seated: { stack: 'static-html', cwd: '.' },
        };
        const verbs: Record<string, unknown> = {
          p4: { run: { exe: 'node', argv: ['scripts/open_preview.mjs', browserLog, 'feature-page.html', 'p4'] } },
          missingfile: { run: { exe: 'node', argv: ['scripts/open_preview.mjs', browserLog, 'feature-page.html', 'mf'] } },
          seated: { run: { unsupported: 'no runtime launch on seated lane' } },
        };
        const launch: Record<string, unknown> = {
          p4: { lane: 'p4', verb: 'run' },
          missingfile: { lane: 'missingfile', verb: 'run' },
          seated: { lane: 'seated', verb: 'run' },
        };
        preconditions.missingfile = [{ kind: 'path', value: 'missing-secret.txt', why: 'required config' }];

        if (port6 !== null) {
          lanes.p6 = { stack: 'static-html', cwd: '.' };
          preconditions.p6 = [{ kind: 'port', value: port6, expect: 'free' }];
          verbs.p6 = { run: { exe: 'node', argv: ['scripts/open_preview.mjs', browserLog, 'feature-page.html', 'p6'] } };
          launch.p6 = { lane: 'p6', verb: 'run' };
        }

        writeJson(join(wtDir, 'nen', 'contract.json'), {
          $schema: 'nen.contract/v0.1',
          project: { lanes, defaultLane: 'p4', preconditions, verbs, launch },
        });
        mustGit(wtDir, ['add', 'feature-page.html', 'nen/contract.json']);
        mustGit(wtDir, ['commit', '-m', 'conflict targets']);

        // Occupied IPv4 port -> exit 2 resource conflict, listener intact
        const res4 = await runAmaterasuPreview({
          repo: wtDir,
          target: 'p4',
          automatic: false,
          dryRun: false,
          json: true,
          nen: NEN,
          quiet: true,
        });
        assert.equal(res4.exitCode, 2);
        assert.equal(res4.output.status, 'resource conflict');
        assert.equal(res4.output.executed, false);
        assert(res4.output.conflicts.some((c) => c.resource === `port ${port4}`));
        await assertServerIntact(srv4, '127.0.0.1', port4);

        // --dry-run on occupied port prints plan at exit 0 without refusing or locking
        const dryBusy = await runAmaterasuPreview({
          repo: wtDir,
          target: 'p4',
          automatic: false,
          dryRun: true,
          json: true,
          nen: NEN,
          quiet: true,
        });
        assert.equal(dryBusy.exitCode, 0);
        assert.equal(dryBusy.output.status, 'dry-run plan ready');
        assert.equal(dryBusy.output.dryRun, true);
        assert.equal(dryBusy.output.steps.length, 1);

        // Occupied IPv6 ::1 port -> exit 2 resource conflict
        if (port6 !== null && srv6) {
          const res6 = await runAmaterasuPreview({
            repo: wtDir,
            target: 'p6',
            automatic: false,
            dryRun: false,
            json: true,
            nen: NEN,
            quiet: true,
          });
          assert.equal(res6.exitCode, 2);
          assert.equal(res6.output.status, 'resource conflict');
          assert(res6.output.conflicts.some((c) => c.resource === `port ${port6}`));
          await assertServerIntact(srv6, '::1', port6);
        }

        // Missing path precondition is NOT misclassified as resource conflict
        const missingRes = await runAmaterasuPreview({
          repo: wtDir,
          target: 'missingfile',
          automatic: false,
          dryRun: false,
          json: true,
          nen: NEN,
          quiet: true,
        });
        assert.equal(missingRes.exitCode, 2);
        assert.equal(missingRes.output.status, 'error');
        assert.equal(missingRes.output.conflicts.length, 0);

        // Unsupported verb seat preserves exit 4; target unsupported returns exit 4
        const seatVerbRes = await runAmaterasuPreview({
          repo: wtDir,
          target: 'seated',
          automatic: false,
          dryRun: false,
          json: true,
          nen: NEN,
          quiet: true,
        });
        assert.equal(seatVerbRes.exitCode, 4);
        assert.equal(seatVerbRes.output.status, 'error');

        assert(!existsSync(browserLog), 'no opener should run on refused targets');
      } finally {
        await new Promise<void>((r) => srv4.close(() => r()));
        if (srv6) await new Promise<void>((r) => srv6!.close(() => r()));
        rmSync(rootTmp, { recursive: true, force: true });
      }
    },
  },
  {
    name: 'Sessions lock: concurrent device/dev-session conflicts, dead-PID lease pruning, stale dead-owner lock reclaim, and symlink/corrupt fail-closed',
    run: async () => {
      const { rootTmp, coreDir, wtDir } = setupSampleWorkspace();
      try {
        const holderPidFile = join(rootTmp, 'sim-holder.pid');
        writeJson(join(wtDir, 'nen', 'contract.json'), {
          $schema: 'nen.contract/v0.1',
          project: {
            lanes: {
              sim: { stack: 'ios', cwd: '.' },
              appdev: { stack: 'static-html', cwd: '.' },
            },
            defaultLane: 'sim',
            verbs: {
              sim: { dev: { exe: 'node', argv: ['scripts/hold_device.mjs', holderPidFile, '1500'] } },
              appdev: { dev: { exe: 'node', argv: ['-e', 'console.log("STDOUT_FAIL"); process.exit(1)'] } },
            },
            launch: {
              'sim-device': { lane: 'sim', verb: 'dev', device: { name: 'Preview Phone 16', kind: 'simulator' } },
              'dev-only': { lane: 'appdev', verb: 'dev' },
            },
          },
        });
        mustGit(wtDir, ['add', 'feature-page.html', 'nen/contract.json']);
        mustGit(wtDir, ['commit', '-m', 'device & dev targets']);

        // Create stale lock <60s old with DEAD pid 999999 + stale ledger entry with dead pid 999998
        const amaDir = join(coreDir, '.git', '.nen', 'amaterasu');
        const lockDir = join(amaDir, 'sessions.json.lock');
        mkdirSync(lockDir, { recursive: true });
        writeJson(join(lockDir, 'owner.json'), { token: 'dead-lock', pid: 999999, createdAt: Date.now() });
        writeJson(join(amaDir, 'sessions.json'), [
          {
            id: 'dead-entry',
            pid: 999998,
            checkout: wtDir,
            branch: 'feature/panel-preview',
            target: 'sim-device',
            verb: 'dev',
            lane: 'sim',
            resources: ['device:Preview Phone 16'],
            startedAt: '2026-01-01T00:00:00Z',
          },
        ]);

        // Start concurrent live device session -> should reclaim dead lock & dead ledger entry cleanly!
        const firstSession = spawn('node', [PREVIEW, '--nen', NEN, '--json', '--repo', wtDir, '--target', 'sim-device'], {
          cwd: ROOT,
          stdio: ['ignore', 'pipe', 'pipe'],
        });
        let firstStdout = '';
        let firstStderr = '';
        let firstClosed: number | null = null;
        firstSession.stdout.on('data', (c: Buffer) => { firstStdout += c.toString('utf8'); });
        firstSession.stderr.on('data', (c: Buffer) => { firstStderr += c.toString('utf8'); });
        firstSession.once('close', (code) => { firstClosed = code ?? 1; });

        const sessionsLedger = join(amaDir, 'sessions.json');
        const waitDeadline = Date.now() + 5_000;
        while (!existsSync(holderPidFile) || !existsSync(sessionsLedger) || !readFileSync(sessionsLedger, 'utf8').includes('Preview Phone 16')) {
          if (firstClosed !== null) throw new Error(`first session exited early: ${firstStdout}\n${firstStderr}`);
          if (Date.now() > waitDeadline) throw new Error('timed out waiting for live device lease');
          await new Promise((r) => setTimeout(r, 30));
        }
        const holderPid = Number(readFileSync(holderPidFile, 'utf8').trim());
        assert(Number.isInteger(holderPid) && holderPid > 0);

        const conflict = await runAmaterasuPreview({
          repo: wtDir,
          target: 'sim-device',
          automatic: false,
          dryRun: false,
          json: true,
          nen: NEN,
          quiet: true,
        });
        assert.equal(conflict.exitCode, 2);
        assert.equal(conflict.output.status, 'resource conflict');
        assert(conflict.output.conflicts.some((c) => c.resource === 'device Preview Phone 16'));
        process.kill(holderPid, 0);

        const firstExit = firstClosed ?? await new Promise<number>((r) => firstSession.once('close', (c) => r(c ?? 1)));
        assert.equal(firstExit, 0, firstStdout);

        // Live dev-session lock + stdout-only child exit 1 failure surfaced
        const failRes = await runAmaterasuPreview({
          repo: wtDir,
          target: 'dev-only',
          automatic: false,
          dryRun: false,
          json: true,
          nen: NEN,
          quiet: true,
        });
        assert.equal(failRes.exitCode, 1);
        assert.equal(failRes.output.status, 'launch failed');
        assert(failRes.output.error?.includes('STDOUT_FAIL'));

        // Corrupt sessions.json must fail closed and NOT overwrite existing file
        writeFileSync(sessionsLedger, '{corrupt', 'utf8');
        const corruptRes = await runAmaterasuPreview({
          repo: wtDir,
          target: 'sim-device',
          automatic: false,
          dryRun: false,
          json: true,
          nen: NEN,
          quiet: true,
        });
        assert.equal(corruptRes.exitCode, 2);
        assert.equal(corruptRes.output.status, 'error');
        assert.equal(readFileSync(sessionsLedger, 'utf8'), '{corrupt');

        // Symlinked sessions.json must refuse fail-closed
        rmSync(sessionsLedger, { force: true });
        symlinkSync(join(rootTmp, 'outside.json'), sessionsLedger);
        const symRes = await runAmaterasuPreview({
          repo: wtDir,
          target: 'sim-device',
          automatic: false,
          dryRun: false,
          json: true,
          nen: NEN,
          quiet: true,
        });
        assert.equal(symRes.exitCode, 2);
        assert.equal(symRes.output.status, 'error');
      } finally {
        rmSync(rootTmp, { recursive: true, force: true });
      }
    },
  },
  {
    name: 'Config, fallback, skip, corrupt JSON, out-of-range port, prunable sibling, and CLI edges',
    run: async () => {
      const { rootTmp, coreDir, wtDir, browserLog } = setupSampleWorkspace();
      try {
        // Prunable sibling worktree missing on disk does not crash safeRealpath
        const deadWt = join(rootTmp, 'wt-prunable');
        mustGit(coreDir, ['worktree', 'add', '-b', 'feature/gone', deadWt, 'main']);
        rmSync(deadWt, { recursive: true, force: true });

        // --dry-run preserves non-zero nen exits (4 unsupported seat, 3 excluded host, 2 path precondition)
        const hostExcluded = process.platform === 'linux' ? 'win32' : 'linux';
        writeJson(join(wtDir, 'nen', 'contract.json'), {
          $schema: 'nen.contract/v0.1',
          project: {
            lanes: {
              seated: { stack: 'static-html', cwd: '.' },
              otherhost: { stack: 'static-html', cwd: '.' },
              missingf: { stack: 'static-html', cwd: '.' },
              iosmiss: { stack: 'ios', cwd: '.' },
              web: { stack: 'static-html', cwd: '.' },
            },
            defaultLane: 'web',
            hosts: { '*': ['darwin', 'linux', 'win32'], dev: [hostExcluded] },
            preconditions: { missingf: [{ kind: 'path', value: 'absent.txt', why: 'needed' }] },
            verbs: {
              seated: { run: { unsupported: 'seat' } },
              otherhost: { dev: { exe: 'node', argv: ['-e', 'console.log(1)'] } },
              missingf: { run: { exe: 'node', argv: ['-e', 'console.log(1)'] } },
              iosmiss: { run: { exe: 'definitely-nonexistent-binary-ha617', argv: ['--version'] } },
              web: { run: { exe: 'node', argv: ['-e', 'console.log(1)'] } },
            },
            launch: {
              seated: { lane: 'seated', verb: 'run' },
              otherhost: { lane: 'otherhost', verb: 'dev' },
              missingf: { lane: 'missingf', verb: 'run' },
              iosmiss: { lane: 'iosmiss', verb: 'run', device: { name: 'Preview Phone 16', kind: 'simulator' } },
              web: { lane: 'web', verb: 'run' },
            },
          },
        });
        assert.equal((await runAmaterasuPreview({ repo: wtDir, target: 'seated', automatic: false, dryRun: true, json: true, nen: NEN, quiet: true })).exitCode, 4);
        assert.equal((await runAmaterasuPreview({ repo: wtDir, target: 'otherhost', automatic: false, dryRun: true, json: true, nen: NEN, quiet: true })).exitCode, 3);
        assert.equal((await runAmaterasuPreview({ repo: wtDir, target: 'missingf', automatic: false, dryRun: true, json: true, nen: NEN, quiet: true })).exitCode, 2);

        // Missing CLI tool (exit 5) must NOT trigger device fallback to workflow.launch.fallback
        writeJson(join(wtDir, 'nen', 'workflow.json'), {
          $schema: 'nen.workflow/v0.1',
          branch: { base: 'main', template: '{model}/{persona}/{descriptor}' },
          launch: { default: 'iosmiss', fallback: 'web' },
        });
        const missBinRes = await runAmaterasuPreview({
          repo: wtDir,
          automatic: false,
          dryRun: false,
          json: true,
          nen: NEN,
          quiet: true,
        });
        assert.equal(missBinRes.exitCode, 5);
        assert.equal(missBinRes.output.fallbackFrom, undefined);

        // Dangling symlink in nen/workflow.json and core/nen/contract.json must fail closed at exit 2
        const wfPath = join(wtDir, 'nen', 'workflow.json');
        rmSync(wfPath, { force: true });
        symlinkSync(join(rootTmp, 'does-not-exist-wf.json'), wfPath);
        assert.equal((await runAmaterasuPreview({ repo: wtDir, target: 'web', automatic: false, dryRun: true, json: true, nen: NEN, quiet: true })).exitCode, 2);
        rmSync(wfPath, { force: true });
        writeJson(wfPath, { $schema: 'nen.workflow/v0.1', launch: { default: null } });

        const coreContractPath = join(coreDir, 'nen', 'contract.json');
        const coreContractBackup = readFileSync(coreContractPath, 'utf8');
        rmSync(coreContractPath, { force: true });
        symlinkSync(join(rootTmp, 'does-not-exist-core.json'), coreContractPath);
        assert.equal((await runAmaterasuPreview({ repo: wtDir, target: 'web', automatic: true, dryRun: false, json: true, nen: NEN, quiet: true })).exitCode, 2);
        rmSync(coreContractPath, { force: true });
        writeFileSync(coreContractPath, coreContractBackup, 'utf8');

        // Out-of-range port precondition returns structured exit 1 from nen schema check without uncaught throw
        writeJson(join(wtDir, 'nen', 'contract.json'), {
          $schema: 'nen.contract/v0.1',
          project: {
            lanes: { badp: { stack: 'static-html', cwd: '.' } },
            defaultLane: 'badp',
            preconditions: { badp: [{ kind: 'port', value: 70000, expect: 'free' }] },
            verbs: { badp: { run: { exe: 'node', argv: ['-e', 'console.log(1)'] } } },
            launch: { badp: { lane: 'badp', verb: 'run' } },
          },
        });
        const badPortRes = await runAmaterasuPreview({
          repo: wtDir,
          target: 'badp',
          automatic: false,
          dryRun: false,
          json: true,
          nen: NEN,
          quiet: true,
        });
        assert.equal(badPortRes.exitCode, 1);
        assert.equal(badPortRes.output.status, 'error');
        assert(badPortRes.output.error?.includes('port'), 'error must describe invalid port');

        // Target-level unsupported entry exits 4 before dry-run
        writeJson(join(wtDir, 'nen', 'contract.json'), {
          $schema: 'nen.contract/v0.1',
          project: {
            lanes: { web: { stack: 'static-html', cwd: '.' } },
            defaultLane: 'web',
            verbs: { web: { run: { exe: 'node', argv: ['-e', 'console.log(1)'] } } },
            launch: { disabled: { lane: 'web', unsupported: 'disabled target' } },
          },
        });
        const disabledTargetRes = await runAmaterasuPreview({
          repo: wtDir,
          target: 'disabled',
          automatic: false,
          dryRun: false,
          json: true,
          nen: NEN,
          quiet: true,
        });
        assert.equal(disabledTargetRes.exitCode, 4);
        assert(disabledTargetRes.output.error?.includes('disabled target'));

        // Absent default device falls back to workflow.launch.fallback
        writeJson(join(wtDir, 'nen', 'workflow.json'), {
          $schema: 'nen.workflow/v0.1',
          branch: { base: 'main', template: '{model}/{persona}/{descriptor}' },
          launch: { default: 'missing-phone', fallback: 'browser' },
        });
        writeJson(join(wtDir, 'nen', 'contract.json'), {
          $schema: 'nen.contract/v0.1',
          project: {
            lanes: {
              ios: { stack: 'ios', cwd: '.' },
              web: { stack: 'static-html', cwd: '.' },
            },
            defaultLane: 'web',
            verbs: {
              ios: { dev: { exe: 'node', argv: ['-e', 'console.log("ios")'] } },
              web: { run: { exe: 'node', argv: ['scripts/open_preview.mjs', browserLog, 'feature-page.html', 'fb'] } },
            },
            launch: {
              'missing-phone': {
                lane: 'ios',
                verb: 'dev',
                device: { name: 'Missing Phone', resolve: { exe: 'node', argv: ['-e', 'console.log("no-devices")'] } },
              },
              browser: { lane: 'web', verb: 'run' },
            },
          },
        });
        const fbRes = await runAmaterasuPreview({
          repo: wtDir,
          automatic: false,
          dryRun: false,
          json: true,
          nen: NEN,
          quiet: true,
        });
        assert.equal(fbRes.exitCode, 0, fbRes.output.error);
        assert.equal(fbRes.output.fallbackFrom, 'missing-phone');
        assert.equal(fbRes.output.target, 'browser');

        // Null default without --target refuses cleanly; undeclared --target refuses
        writeJson(join(wtDir, 'nen', 'workflow.json'), {
          $schema: 'nen.workflow/v0.1',
          branch: { base: 'main', template: '{model}/{persona}/{descriptor}' },
          launch: { default: null, fallback: null },
        });
        const nullRes = await runAmaterasuPreview({
          repo: wtDir,
          automatic: false,
          dryRun: false,
          json: true,
          nen: NEN,
          quiet: true,
        });
        assert.equal(nullRes.exitCode, 2);
        const badTargetRes = await runAmaterasuPreview({
          repo: wtDir,
          target: 'nope',
          automatic: false,
          dryRun: false,
          json: true,
          nen: NEN,
          quiet: true,
        });
        assert.equal(badTargetRes.exitCode, 2);

        // Corrupt workflow.json fails closed at exit 2
        writeFileSync(join(wtDir, 'nen', 'workflow.json'), '{bad json', 'utf8');
        const corruptWf = await runAmaterasuPreview({
          repo: wtDir,
          target: 'browser',
          automatic: false,
          dryRun: false,
          json: true,
          nen: NEN,
          quiet: true,
        });
        assert.equal(corruptWf.exitCode, 2);
        assert.equal(corruptWf.output.status, 'error');

        // Empty project.launch -> no launch target declared; skipped
        writeJson(join(wtDir, 'nen', 'workflow.json'), { $schema: 'nen.workflow/v0.1', launch: { default: null } });
        writeJson(join(wtDir, 'nen', 'contract.json'), {
          $schema: 'nen.contract/v0.1',
          project: { lanes: { web: { stack: 'static-html', cwd: '.' } }, verbs: { web: {} }, launch: {} },
        });
        const skipRes = await runAmaterasuPreview({
          repo: wtDir,
          automatic: false,
          dryRun: false,
          json: true,
          nen: NEN,
          quiet: true,
        });
        assert.equal(skipRes.exitCode, 0);
        assert.equal(skipRes.output.status, 'no launch target declared; skipped');

        // parseCliArgs + formatCommand + CLI subprocess test
        const parsed = parseCliArgs(['--repo', wtDir, '--target', 'x', '--dry-run', '--json', '--automatic']);
        assert.equal(parsed.target, 'x');
        assert.equal(parsed.dryRun, true);
        assert.equal(parsed.automatic, true);
        assert.equal(formatShellArg('hello world'), "'hello world'");
        assert.equal(formatCommand('nen', ['shu', 'run']), 'nen shu run');

        const cliRes = spawnSync('node', [PREVIEW, '--nen', NEN, '--repo', wtDir], { cwd: ROOT, encoding: 'utf8' });
        assert.equal(cliRes.status, 0, cliRes.stderr);
        assert(cliRes.stdout.includes('no launch target declared; skipped'));
      } finally {
        rmSync(rootTmp, { recursive: true, force: true });
      }
    },
  },
];
