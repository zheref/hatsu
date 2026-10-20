#!/usr/bin/env node
// Trusted CI adapter: TypeScript owns the matrix verdict and workflow-command fence.
import { randomBytes } from 'node:crypto';
import { spawn } from 'node:child_process';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = process.argv[2];
if (!root) {
  console.error('direct-matrix-ci: expected PR checkout root');
  process.exit(2);
}
const guard = join(fileURLToPath(new URL('.', import.meta.url)), 'direct_matrix_doc.sh');
const token = `stop_${randomBytes(16).toString('hex')}`;
let outcome: { code: number | null; signal: NodeJS.Signals | null; error: string | null } =
  { code: null, signal: null, error: null };
process.stdout.write(`::stop-commands::${token}\n`);
try {
  const child = spawn('bash', [guard, '--check', root], { stdio: ['ignore', 'pipe', 'pipe'] });
  child.stdout.pipe(process.stdout, { end: false });
  child.stderr.pipe(process.stdout, { end: false });
  outcome = await new Promise((resolve) => {
    let error: string | null = null;
    child.on('error', (cause) => { error = cause.message; });
    child.on('close', (code, signal) => resolve({ code, signal, error }));
  });
} finally {
  process.stdout.write(`\n::${token}::\n`);
}
if (outcome.error || outcome.signal || outcome.code === null) {
  console.error(`::error::direct matrix guard could not run (${outcome.error ?? outcome.signal ?? 'unknown exit'}).`);
  process.exitCode = 2;
} else if (outcome.code === 0) {
  console.log('docs/DIRECT-MATRIX.md matches the registry, taxonomy and models.');
} else if (outcome.code === 1) {
  console.error('::error::docs/DIRECT-MATRIX.md is stale; regenerate it with the direct matrix renderer and commit the result.');
  process.exitCode = 1;
} else {
  console.error(`::error::direct matrix guard could not check the page (exit ${outcome.code}).`);
  process.exitCode = 2;
}
