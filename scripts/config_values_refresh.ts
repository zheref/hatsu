/** HA#370: validate and stage the opt-in refresh before replacing any consumer declaration. */
import { chmodSync, closeSync, existsSync, lstatSync, mkdirSync, mkdtempSync, openSync, readFileSync, realpathSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, isAbsolute, join, relative } from 'node:path';
import { tmpdir } from 'node:os';
import { spawnSync } from 'node:child_process';
import { defaults, options, type Catalogue } from './pr_sections.ts';
import { history, object, refreshed } from './pr_sections_history.ts';

interface Node { start: number; end: number; members?: Map<string, Node> }
/** Strict JSON plus duplicate-key refusal; spans keep unrelated consumer text and line endings. */
function scan(text: string): Node {
  JSON.parse(text);
  let at = 0;
  const space = () => { while (/\s/.test(text[at] ?? '') && at < text.length) at++; };
  const string = () => { const start = at++; while (at < text.length) { if (text[at++] === '\\') at++; else if (text[at - 1] === '"') break; } return JSON.parse(text.slice(start, at)) as string; };
  const node = (): Node => {
    space(); const start = at;
    if (text[at] === '{') {
      at++; space(); const members = new Map<string, Node>();
      while (text[at] !== '}') {
        const key = string(); space(); at++;
        if (members.has(key)) throw new Error('declaration contains duplicate JSON keys; nothing written');
        members.set(key, node()); space();
        if (text[at] !== ',') break;
        at++; space();
      }
      at++; return { start, end: at, members };
    }
    if (text[at] === '[') { at++; space(); while (text[at] !== ']') { node(); space(); if (text[at] !== ',') break; at++; } at++; }
    else if (text[at] === '"') string();
    else { while (at < text.length && !/[\s,\]}]/.test(text[at])) at++; }
    return { start, end: at };
  };
  return node();
}
export function strictJson(text: string): any {
  try { scan(text); return JSON.parse(text); }
  catch (error) {
    if (error instanceof Error && error.message.includes('duplicate JSON keys')) throw error;
    throw new Error('declaration is not strict JSON; nothing written');
  }
}
export function declarationText(repo: string, rel: string): string | undefined {
  let path = repo;
  for (const part of rel.split('/')) {
    path = join(path, part);
    try { const info = lstatSync(path); if (info.isSymbolicLink()) throw new Error(`${rel}: symlink refused; nothing written`); }
    catch (error) { if ((error as NodeJS.ErrnoException).code === 'ENOENT') return undefined; throw error; }
  }
  const sub = relative(realpathSync(repo), realpathSync(path));
  if (isAbsolute(sub) || sub === '..' || sub.startsWith('../')) throw new Error(`${rel}: outside --repo; nothing written`);
  if (!lstatSync(path).isFile()) throw new Error(`${rel}: expected a regular file; nothing written`);
  let text: string;
  try { text = new TextDecoder('utf-8', { fatal: true }).decode(readFileSync(path)); }
  catch { throw new Error(`${rel}: unreadable UTF-8 declaration; nothing written`); }
  strictJson(text); return text;
}
export function replaceMember(text: string, parentKeys: string[], key: string, value: unknown): string {
  let parent = scan(text);
  for (const part of parentKeys) {
    const child = parent.members?.get(part);
    if (!child) {
      let nested: any = { [key]: value };
      for (const k of [...parentKeys.slice(parentKeys.indexOf(part) + 1)].reverse()) nested = { [k]: nested };
      return replaceMember(text, parentKeys.slice(0, parentKeys.indexOf(part)), part, nested);
    }
    parent = child;
  }
  if (!parent.members) throw new Error(`${parentKeys.join('.') || 'document'} must be an object; nothing written`);
  const nl = text.includes('\r\n') ? '\r\n' : '\n';
  const indent = /^[ \t]*/.exec(text.slice(text.lastIndexOf('\n', parent.start) + 1))![0];
  const rendered = JSON.stringify(value, null, 2).replaceAll('\n', nl + indent + '  ');
  const found = parent.members.get(key);
  if (found) return text.slice(0, found.start) + rendered + text.slice(found.end);
  const last = [...parent.members.values()].at(-1);
  const insertion = last?.end ?? parent.start + 1;
  return text.slice(0, insertion) + (last ? ',' : '') + nl + indent + '  ' + JSON.stringify(key) + ': ' + rendered + text.slice(insertion);
}
export const sectionOptions = (cat: Catalogue) => 'available sections: ' + Object.entries(options(cat)).map(([id, purpose]) => `${id} — ${purpose}`).join(' | ');

export function refreshFill(repo: string, cat: Catalogue, root: string, engine: string, catalogueRoot: string, argv: string[]): { stdout: string; stderr: string; status: number; error?: Error } {
  const entries = history(root, cat);
  const snapshots = new Map<string, { text: string; mode: number }>();
  const staged = mkdtempSync(join(tmpdir(), 'hatsu-config-refresh-'));
  const pending: Array<{ rel: string; path: string }> = [];
  try {
    mkdirSync(join(staged, 'nen'));
    for (const rel of ['nen/workflow.json', 'nen/contract.json', 'nen/gates.json']) {
      const text = declarationText(repo, rel);
      if (text === undefined) continue;
      const mode = lstatSync(join(repo, rel)).mode;
      snapshots.set(rel, { text, mode });
      writeFileSync(join(staged, rel), text);
    }
    const workflow = snapshots.get('nen/workflow.json');
    let kept: string[] = [];
    let provenanceUnknown = false;
    let refreshedValue: unknown;
    if (workflow) {
      const parsed = object(strictJson(workflow.text), 'nen/workflow.json');
      const pr = parsed.pr === undefined ? {} : object(parsed.pr, 'pr');
      if (Object.hasOwn(pr, 'sections')) {
        const result = refreshed(pr.sections, cat, entries); kept = result.kept; refreshedValue = result.value; provenanceUnknown = result.reading.status === 'unstamped';
      } else refreshedValue = defaults(cat);
    }
    const forwarded: string[] = [];
    for (let i = 0; i < argv.length; i++) {
      if (argv[i] === '--repo') { forwarded.push(argv[i], staged); i++; }
      else forwarded.push(argv[i]);
    }
    const run = spawnSync('bash', [engine, ...forwarded, '--hatsu-root', catalogueRoot, '--json'], { encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 });
    if (run.error) throw run.error;
    if (run.status !== 0 && run.status !== 1) throw new Error(`staged fill failed (${run.status}); nothing written`);
    const output = JSON.parse(run.stdout);
    if (output.values.some((row: any) => ['blocked', 'invalid'].includes(row.state))) throw new Error('staged fill contains an invalid or blocked declaration; nothing written');
    if (workflow) {
      const path = join(staged, 'nen/workflow.json');
      let text = readFileSync(path, 'utf8');
      text = replaceMember(text, ['pr'], 'sections', refreshedValue);
      text = replaceMember(text, ['pr'], '$sections', sectionOptions(cat));
      strictJson(text); writeFileSync(path, text);
    }
    // All source declarations and every planned result are checked before the first real replacement.
    for (const [rel, before] of snapshots) {
      const next = readFileSync(join(staged, rel), 'utf8'); strictJson(next);
      if (next === before.text) continue;
      const path = join(dirname(join(repo, rel)), `.config-refresh-${process.pid}-${pending.length}`);
      const descriptor = openSync(path, 'wx', 0o600);
      pending.push({ rel, path });
      try { writeFileSync(descriptor, next); } finally { closeSync(descriptor); }
      chmodSync(path, before.mode);
    }
    for (const [rel, before] of snapshots) if (declarationText(repo, rel) !== before.text) throw new Error(`${rel}: changed during refresh; nothing written`);
    for (const plan of pending) {
      const before = snapshots.get(plan.rel)!;
      if (declarationText(repo, plan.rel) !== before.text) throw new Error(`${plan.rel}: changed during refresh; replacement refused`);
      renameSync(plan.path, join(repo, plan.rel));
    }
    const changedWorkflow = pending.some(plan => plan.rel === 'nen/workflow.json');
    if (changedWorkflow) output.wrote.push({ id: 'workflow.pr.sections', file: 'nen/workflow.json', path: 'pr.sections', wrote: 'refreshed defaults, options and catalogue stamp' });
    output.prSections = { refreshed: changedWorkflow, kept, catalogueSha: cat.documentSha256, provenanceUnknown,
      detail: provenanceUnknown ? 'provenance unknown; every existing cell retained as consumer-owned' : 'stamped provenance; consumer-owned cells retained' };
    return { stdout: JSON.stringify(output, null, 2) + '\n', stderr: run.stderr, status: run.status ?? 2 };
  } finally {
    for (const plan of pending) rmSync(plan.path, { force: true });
    rmSync(staged, { recursive: true, force: true });
  }
}
