#!/usr/bin/env node
// zheref/hatsu#473 AC-3: hermetic fixture for scripts/delegate_brief_check.mts. Each case writes a
// throwaway brief (and, for the wiring cases, a throwaway canon) and asserts the exit code and the
// stream split; the last cases read the live docs/WORKFLOW.md and the skills that raise a delegate.
import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const guard = fileURLToPath(new URL('./delegate_brief_check.mts', import.meta.url));
const root = fileURLToPath(new URL('..', import.meta.url));
const scratch = mkdtempSync(join(tmpdir(), 'hatsu-delegate-brief-'));
let cases = 0;

function run(args: string[]): ReturnType<typeof spawnSync> {
  return spawnSync(process.execPath, [guard, ...args], { cwd: scratch, encoding: 'utf8' });
}
function file(name: string, text: string): string {
  const path = join(scratch, name);
  writeFileSync(path, text);
  return path;
}
function expect(name: string, args: string[], status: number, stdout: RegExp | null, stderr: RegExp | null): void {
  const result = run(args);
  const detail = `${name}: exit ${result.status}\nstdout: ${result.stdout}\nstderr: ${result.stderr}`;
  assert.equal(result.status, status, detail);
  if (stdout) assert.match(String(result.stdout), stdout, detail);
  if (stderr) assert.match(String(result.stderr), stderr, detail);
  if (status !== 2) assert.equal(String(result.stderr), '', `${name}: findings go to stdout only\n${detail}`);
  if (status === 2) assert.equal(String(result.stdout), '', `${name}: a tooling failure prints no annotation\n${detail}`);
  cases += 1;
  console.log(`ok ${cases} - ${name}`);
}

try {
  // The live canon's block, as --print gives it to a brief author.
  const printed = run(['--print']);
  assert.equal(printed.status, 0, String(printed.stderr));
  const block = String(printed.stdout).trimEnd().split('\n');
  assert.equal(block.length, 4, `the live block has four lines: ${printed.stdout}`);
  assert.match(block[0], /gh pr checks --watch/);
  assert.match(block[0], /`sleep`/);
  assert.match(block[0], /background job/);
  assert.match(block[1], /--max-iterations <n> --interval-ms <ms>/);
  assert.match(block[1], /9 minutes unless this brief names another/);
  assert.match(block[2], /host call .* sets its own timeout above the wait's \(e\.g\. Bash timeout 600000 for a wait of 9 minutes or less\)/);
  assert.match(block[3], /hand back: the head SHA/);
  cases += 1;
  console.log(`ok ${cases} - --print gives the live block: no watch, both flags and a 9-minute ceiling, the host timeout above it, a hand-back`);

  const brief = (lines: string[]): string => ['# A delegate brief', '', 'You are a builder delegate.', '', ...lines, '', '## Report back'].join('\n');
  expect('a brief built from the canon passes', [file('built.md', `${brief(block)}\n`)], 0, /carries all 4 wait-block lines/, null);
  expect('an indented copy and CRLF still pass', [file('crlf.md', brief(block.map((l) => `   ${l}  `)).replace(/\n/g, '\r\n'))], 0, /carries all 4/, null);
  expect('a brief naming another ceiling on its own line passes', [file('other.md', brief([...block, '- This brief\'s ceiling: 5 minutes.']))], 0, /carries all 4/, null);
  expect('a brief without the block fails on every line', [file('none.md', brief(['Wait as long as you need.']))], 1, /line 1 of 4[\s\S]*line 2 of 4[\s\S]*line 3 of 4[\s\S]*line 4 of 4/, null);
  const dropped = run([file('dropped.md', brief([block[0], block[2], block[3]]))]);
  assert.equal(dropped.status, 1, String(dropped.stdout));
  assert.match(String(dropped.stdout), /::error file=.*::delegate brief lacks wait-block line 2 of 4/);
  assert.doesNotMatch(String(dropped.stdout), /line [134] of 4/);
  cases += 1;
  console.log(`ok ${cases} - a dropped line fails naming only that line`);
  expect('a reworded ceiling fails', [file('ceiling.md', brief([block[0], block[1].replace('9 minutes', '30 minutes'), block[2], block[3]]))], 1, /line 2 of 4/, null);
  expect('a paraphrase fails', [file('paraphrase.md', brief(['- Do not use gh pr checks --watch or sleep loops.', block[1], block[2], block[3]]))], 1, /line 1 of 4/, null);
  expect('a dropped host-timeout line fails', [file('no-timeout.md', brief([block[0], block[1], block[3]]))], 1, /line 3 of 4/, null);
  expect('a line split across two fails', [file('split.md', brief([block[0], ...block[1].split(', both flags'), block[2], block[3]]))], 1, /line 2 of 4/, null);
  expect('the block inside a longer line fails', [file('inline.md', brief([`Note: ${block[0]}`, block[1], block[2], block[3]]))], 1, /line 1 of 4/, null);

  // A synthetic canon: the block is read, never copied into the guard.
  const canon = (body: string): string => file(`canon-${cases}.md`, body);
  const custom = canon('# W\n\n<!-- delegate-wait:begin -->\n- one\n\n- two\n<!-- delegate-wait:end -->\n');
  expect('another canon\'s block is the one checked', ['--canon', custom, file('two.md', '- one\n- two\n')], 0, /carries all 2/, null);
  expect('the live block is not the synthetic canon\'s', ['--canon', custom, file('live.md', `${block.join('\n')}\n`)], 1, /line 1 of 2[\s\S]*line 2 of 2/, null);
  const commaDir = join(scratch, 'Code, work');
  mkdirSync(commaDir);
  const commaCanon = join(commaDir, 'WORKFLOW.md');
  writeFileSync(commaCanon, '<!-- delegate-wait:begin -->\n- one\n<!-- delegate-wait:end -->\n');
  expect('a canon under a directory with a comma is read', ['--canon', commaCanon, file('comma-ok.md', '- one\n')], 0, /carries all 1/, null);
  expect('the annotation names the canon actually read', ['--canon', custom, file('names.md', '- one\n')], 1, new RegExp(`line 2 of 2 word for word \\(${custom.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')} § Delegate briefs\\)`), null);
  expect('a canon with no block exits 2', ['--canon', canon('# nothing\n'), file('b1.md', 'x\n')], 2, null, /exactly one/);
  expect('a canon with two blocks exits 2', ['--canon', canon('<!-- delegate-wait:begin -->\na\n<!-- delegate-wait:end -->\n<!-- delegate-wait:begin -->\nb\n<!-- delegate-wait:end -->\n'), file('b2.md', 'a\n')], 2, null, /found 2 begin, 2 end/);
  expect('a canon with no end marker exits 2', ['--canon', canon('<!-- delegate-wait:begin -->\na\n'), file('b3.md', 'a\n')], 2, null, /found 1 begin, 0 end/);
  expect('markers out of order exit 2', ['--canon', canon('<!-- delegate-wait:end -->\na\n<!-- delegate-wait:begin -->\n'), file('b4.md', 'a\n')], 2, null, /exactly one/);
  expect('an empty block exits 2', ['--canon', canon('<!-- delegate-wait:begin -->\n\n<!-- delegate-wait:end -->\n'), file('b5.md', 'a\n')], 2, null, /is empty/);
  expect('an unreadable canon exits 2', ['--canon', join(scratch, 'absent.md'), file('b6.md', 'a\n')], 2, null, /cannot read the canon/);
  expect('an unreadable brief exits 2', [join(scratch, 'absent-brief.md')], 2, null, /cannot read the brief/);
  const dir = join(scratch, 'a-directory');
  mkdirSync(dir);
  expect('a directory as the brief exits 2', [dir], 2, null, /cannot read the brief/);
  expect('a brief path with a colon exits 2', [join(scratch, 'x::y.md')], 2, null, /comma, colon or line break/);
  expect('a brief path with a comma exits 2', [join(scratch, 'a,line=1.md')], 2, null, /comma, colon or line break/);
  const forgedDir = join(scratch, 'x\n::warning file=forged.md::forged');
  expect('a canon path with a line break exits 2 with nothing on stdout', ['--canon', join(forgedDir, 'WORKFLOW.md'), file('forge.md', '- one\n')], 2, null, /canon path holds a line break/);
  expect('a brief path with a newline exits 2', [join(scratch, 'x\n::error::forged.md')], 2, null, /comma, colon or line break/);
  expect('no argument exits 2', [], 2, null, /usage/);
  expect('two briefs exit 2', ['a.md', 'b.md'], 2, null, /usage/);
  expect('--print beside a brief exits 2', ['--print', 'a.md'], 2, null, /usage/);
  expect('--canon with no path exits 2', ['--canon'], 2, null, /--canon needs a path/);
  expect('an unknown flag exits 2', ['--watch', 'a.md'], 2, null, /unknown flag --watch/);

  // AC-1: the skills that raise a delegate cite the section the block lives in.
  for (const skill of ['kazaana', 'futon']) {
    const text = readFileSync(join(root, 'claude', 'skills', skill, 'SKILL.md'), 'utf8');
    assert.match(text, /WORKFLOW[^\n]*§ \*Delegate briefs\*/, `${skill} does not cite WORKFLOW § Delegate briefs`);
    cases += 1;
    console.log(`ok ${cases} - ${skill} cites WORKFLOW § Delegate briefs`);
  }
  console.log(`delegate-brief-check fixture: ${cases} cases passed`);
} finally {
  rmSync(scratch, { recursive: true, force: true });
}
