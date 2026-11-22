#!/usr/bin/env node
// Hermetic fixture for scripts/amaterasu_preview.mts (zheref/hatsu#617):
// - AC-1: Preview a page present in a selected feature worktree and absent from main/core -> browser opens worktree page.
// - AC-2: Preview an uncommitted visible edit -> browser shows the edit while both checkouts keep branches & edits.
// - SC-1: 2 successful previews with 0 core checkout swaps.
// - AC-3 / SC-2: Real occupied port & concurrent device session conflict -> refuses naming occupied resource and leaves
//   existing listener/session alive & intact.
// - AC-4: Success result identifies checkout, target, and verbatim command that actually ran.
// - AS-1: Automatic --automatic ren mode in a worktree retains core launch deferral without executing worktree launch.
import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { createServer, type Server } from 'node:http';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

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

async function assertServerIntact(srv: Server, port: number): Promise<void> {
  assert.equal(srv.listening, true, 'existing session server stopped listening');
  try {
    const res = await fetch(`http://127.0.0.1:${port}/health`);
    assert.equal(res.status, 200, `expected 200 from session server, got ${res.status}`);
    assert.equal(await res.text(), 'existing-session-alive');
  } catch (err) {
    const cause = (err as { cause?: NodeJS.ErrnoException })?.cause ?? (err as NodeJS.ErrnoException);
    if (cause?.code !== 'EPERM' && cause?.code !== 'EACCES') throw err;
    // Restricted sandboxes block outbound connect(); confirm the bound socket still holds the port.
    await new Promise<void>((resolveCheck, rejectCheck) => {
      const probe = createServer();
      probe.once('error', (probeErr) => {
        const code = (probeErr as NodeJS.ErrnoException).code;
        if (code === 'EADDRINUSE' || code === 'EACCES') resolveCheck();
        else rejectCheck(probeErr);
      });
      probe.listen({ port, host: '127.0.0.1', exclusive: true }, () => {
        probe.close(() => rejectCheck(new Error(`port ${port} unexpectedly became free`)));
      });
    });
  }
}

const rootTmp = realpathSync(mkdtempSync(join(tmpdir(), 'amaterasu-preview-')));

const server = createServer((_req, res) => {
  res.writeHead(200, { 'content-type': 'text/plain' });
  res.end('existing-session-alive');
});

try {
  await new Promise<void>((resolvePromise) => {
    server.listen(0, '127.0.0.1', () => resolvePromise());
  });
  const addr = server.address();
  assert(addr && typeof addr === 'object', 'ephemeral server did not bind');
  const occupiedPort = addr.port;

  const coreDir = join(rootTmp, 'core-app');
  const wtDir = join(rootTmp, 'wt-feature');
  const browserLog = join(rootTmp, 'browser-displays.jsonl');
  mkdirSync(coreDir, { recursive: true });

  mustGit(coreDir, ['init', '-b', 'main']);
  mustGit(coreDir, ['config', 'user.email', 'test@example.com']);
  mustGit(coreDir, ['config', 'user.name', 'Test User']);

  // Core checkout has index.html only (lacks feature-page.html) and a simple opener script.
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
setTimeout(() => {}, Number(msArg || 3000));
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
          dev: { exe: 'node', argv: ['scripts/hold_device.mjs', join(rootTmp, 'core-dev.pid'), '2500'] },
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

  // Create dirty uncommitted edit on core that must stay untouched across all previews.
  writeFileSync(join(coreDir, 'index.html'), '<h1>Main Checkout (Dirty Human Edit)</h1>\n', 'utf8');
  writeFileSync(join(coreDir, 'core-notes.txt'), 'keep core dirty edits intact\n', 'utf8');

  // Create feature worktree adding feature-page.html (absent from main/core!) and preview targets.
  mustGit(coreDir, ['worktree', 'add', '-b', 'feature/panel-preview', wtDir, 'main']);
  assert(!existsSync(join(coreDir, 'feature-page.html')), 'core checkout must not contain feature-page.html');
  writeFileSync(join(wtDir, 'feature-page.html'), '<main>Worktree Page Committed v1</main>\n', 'utf8');
  writeJson(join(wtDir, 'nen', 'contract.json'), {
    $schema: 'nen.contract/v0.1',
    project: {
      lanes: {
        web: { stack: 'static-html', cwd: '.' },
        portweb: { stack: 'static-html', cwd: '.' },
        sim: { stack: 'ios', cwd: '.' },
      },
      defaultLane: 'web',
      preconditions: {
        portweb: [{ kind: 'port', value: occupiedPort, expect: 'free' }],
      },
      verbs: {
        web: {
          run: { exe: 'node', argv: ['scripts/open_preview.mjs', browserLog, 'feature-page.html', 'wt-preview'] },
        },
        portweb: {
          run: { exe: 'node', argv: ['scripts/open_preview.mjs', browserLog, 'feature-page.html', 'port-preview'] },
        },
        sim: {
          dev: { exe: 'node', argv: ['scripts/hold_device.mjs', join(rootTmp, 'sim-holder.pid'), '1500'] },
        },
      },
      launch: {
        browser: { lane: 'web', verb: 'run' },
        'occupied-port': { lane: 'portweb', verb: 'run' },
        'sim-device': { lane: 'sim', verb: 'dev', device: { name: 'Preview Phone 16', kind: 'simulator' } },
      },
    },
  });
  mustGit(wtDir, ['add', 'feature-page.html', 'nen/contract.json']);
  mustGit(wtDir, ['commit', '-m', 'add feature page and launch targets']);
  const wtHeadBefore = mustGit(wtDir, ['rev-parse', 'HEAD']);

  // Helper to run CLI
  const runPreview = (args: string[]) => {
    const res = spawnSync('node', [PREVIEW, '--nen', NEN, '--json', ...args], {
      cwd: ROOT,
      encoding: 'utf8',
    });
    const parsed = JSON.parse(res.stdout);
    return { status: res.status, parsed, stderr: res.stderr };
  };

  // AC-1 + AC-4: Explicit local preview from feature worktree displays feature-page.html missing from core.
  const ac1 = runPreview(['--repo', wtDir, '--target', 'browser']);
  assert.equal(ac1.status, 0, `AC-1 failed: ${ac1.parsed.error ?? ac1.stderr}`);
  assert.equal(ac1.parsed.status, 'preview launched');
  assert.equal(ac1.parsed.executed, true);
  assert.equal(ac1.parsed.coreSwaps, 0);
  assert.equal(ac1.parsed.checkout, wtDir);
  assert.equal(ac1.parsed.target, 'browser');
  assert(ac1.parsed.command.includes(`--repo ${wtDir}`) && ac1.parsed.command.includes('--target browser'), 'AC-4 command missing checkout/target');
  assert.equal(ac1.parsed.steps.length, 1);
  assert.equal(ac1.parsed.steps[0].cwd, wtDir);

  let displays = readFileSync(browserLog, 'utf8').trim().split('\n').map((line) => JSON.parse(line));
  assert.equal(displays.length, 1);
  assert.equal(displays[0].cwd, wtDir);
  assert(displays[0].html.includes('Worktree Page Committed v1'), 'AC-1 browser did not render worktree page');

  // AC-2 + SC-1: Uncommitted visible edit in feature worktree shows on second preview; both checkouts retain branches & edits; 0 core swaps.
  writeFileSync(join(wtDir, 'feature-page.html'), '<main>Worktree Page Uncommitted Edit v2</main>\n', 'utf8');
  const ac2 = runPreview(['--repo', wtDir, '--target', 'browser']);
  assert.equal(ac2.status, 0, `AC-2 failed: ${ac2.parsed.error ?? ac2.stderr}`);
  assert.equal(ac2.parsed.coreSwaps, 0);
  assert(ac2.parsed.uncommittedPaths.includes('feature-page.html'), 'uncommitted path should be reported');

  displays = readFileSync(browserLog, 'utf8').trim().split('\n').map((line) => JSON.parse(line));
  assert.equal(displays.length, 2, 'SC-1 expected 2 successful local previews');
  assert(displays[1].html.includes('Worktree Page Uncommitted Edit v2'), 'AC-2 second preview missed uncommitted edit');

  assert.equal(mustGit(coreDir, ['symbolic-ref', '--short', 'HEAD']), 'main', 'core branch changed');
  assert.equal(mustGit(coreDir, ['rev-parse', 'HEAD']), coreHeadBefore, 'core HEAD changed');
  assert.equal(readFileSync(join(coreDir, 'core-notes.txt'), 'utf8'), 'keep core dirty edits intact\n');
  assert(readFileSync(join(coreDir, 'index.html'), 'utf8').includes('Dirty Human Edit'));
  assert.equal(mustGit(wtDir, ['symbolic-ref', '--short', 'HEAD']), 'feature/panel-preview', 'worktree branch changed');
  assert.equal(mustGit(wtDir, ['rev-parse', 'HEAD']), wtHeadBefore, 'worktree HEAD changed');
  assert(readFileSync(join(wtDir, 'feature-page.html'), 'utf8').includes('Uncommitted Edit v2'));

  // AC-3 + SC-2 (Part 1): Real occupied port conflict reports occupied port, leaves opener unrun, leaves existing HTTP server alive.
  const ac3Port = runPreview(['--repo', wtDir, '--target', 'occupied-port']);
  assert.equal(ac3Port.status, 2, `AC-3 port conflict should exit 2, got ${ac3Port.status}`);
  assert.equal(ac3Port.parsed.status, 'resource conflict');
  assert.equal(ac3Port.parsed.executed, false);
  assert.equal(ac3Port.parsed.coreSwaps, 0);
  assert(
    ac3Port.parsed.conflicts.some((c: { resource: string }) => c.resource === `port ${occupiedPort}`),
    `expected occupied port ${occupiedPort} in conflicts`,
  );
  assert(ac3Port.parsed.error.includes(`port ${occupiedPort}`), 'error text must name occupied port');
  // Opener must NOT have run a 3rd time, and existing server must still answer 200 OK.
  assert.equal(readFileSync(browserLog, 'utf8').trim().split('\n').length, 2, 'conflicted launch must not execute');
  await assertServerIntact(server, occupiedPort);

  // AC-3 + SC-2 (Part 2): Concurrent active device session in sessions.json refuses cleanly and leaves running session intact.
  const holderPidFile = join(rootTmp, 'sim-holder.pid');
  const firstSession = spawn('node', [PREVIEW, '--nen', NEN, '--json', '--repo', wtDir, '--target', 'sim-device'], {
    cwd: ROOT,
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  let firstStdout = '';
  let firstStderr = '';
  let firstClosed: number | null = null;
  firstSession.stdout.on('data', (chunk: Buffer) => { firstStdout += chunk.toString('utf8'); });
  firstSession.stderr.on('data', (chunk: Buffer) => { firstStderr += chunk.toString('utf8'); });
  firstSession.once('close', (code) => { firstClosed = code ?? 1; });

  const waitDeadline = Date.now() + 5_000;
  const sessionsLedger = join(coreDir, '.git', '.nen', 'amaterasu', 'sessions.json');
  while (!existsSync(holderPidFile) || !existsSync(sessionsLedger) || !readFileSync(sessionsLedger, 'utf8').includes('Preview Phone 16')) {
    if (firstClosed !== null) {
      throw new Error(`first device preview session exited early (${firstClosed}): ${firstStdout}\n${firstStderr}`);
    }
    if (Date.now() > waitDeadline) throw new Error('timed out waiting for first device preview session lease');
    await new Promise((r) => setTimeout(r, 30));
  }
  const holderPid = Number(readFileSync(holderPidFile, 'utf8').trim());
  assert(Number.isInteger(holderPid) && holderPid > 0, 'first session process did not start');

  const ac3Device = runPreview(['--repo', wtDir, '--target', 'sim-device']);
  assert.equal(ac3Device.status, 2, 'concurrent device conflict should exit 2');
  assert.equal(ac3Device.parsed.status, 'resource conflict');
  assert.equal(ac3Device.parsed.executed, false);
  assert(ac3Device.parsed.conflicts.some((c: { resource: string }) => c.resource === 'device Preview Phone 16'));
  // First session process is still alive after conflict refusal.
  process.kill(holderPid, 0);

  const firstExit = firstClosed ?? await new Promise<number>((resolveExit) => {
    firstSession.once('close', (code) => resolveExit(code ?? 1));
  });
  assert.equal(firstExit, 0, `first device session should complete intact: ${firstStdout}`);

  // AS-1: --automatic in a worktree retains existing § 3 deferral and does not execute in worktree or core.
  const autoRes = runPreview(['--repo', wtDir, '--target', 'browser', '--automatic']);
  assert.equal(autoRes.status, 0);
  assert.equal(autoRes.parsed.status, 'core launch deferred; explicit maintainer call required');
  assert.equal(autoRes.parsed.deferred, true);
  assert.equal(autoRes.parsed.executed, false);
  assert.equal(autoRes.parsed.checkout, coreDir);
  assert.equal(readFileSync(browserLog, 'utf8').trim().split('\n').length, 2, 'automatic mode must defer without launching');

  // Non-JSON text mode prints checkout, target, and command clearly.
  const humanRes = spawnSync('node', [PREVIEW, '--nen', NEN, '--repo', wtDir, '--target', 'browser'], {
    cwd: ROOT,
    encoding: 'utf8',
  });
  assert.equal(humanRes.status, 0, humanRes.stderr);
  assert(humanRes.stdout.includes(`checkout: ${wtDir}`), 'human output missing checkout');
  assert(humanRes.stdout.includes('target: browser'), 'human output missing target');
  assert(humanRes.stdout.includes('command:'), 'human output missing verbatim command');

  console.log('amaterasu-preview-guard: ok (AC-1..AC-4, SC-1..SC-2, AS-1)');
} finally {
  await new Promise<void>((resolveClose) => server.close(() => resolveClose()));
  rmSync(rootTmp, { recursive: true, force: true });
}
