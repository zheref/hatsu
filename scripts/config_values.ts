/** HA#351: TypeScript catalogue adapter around the unchanged, frozen configuration engine (BC-11). */
import { readFileSync, writeFileSync, mkdirSync, mkdtempSync, symlinkSync, rmSync, lstatSync, realpathSync, existsSync } from 'node:fs';
import { dirname, join, resolve, relative, isAbsolute } from 'node:path';
import { fileURLToPath } from 'node:url';
import { tmpdir } from 'node:os';
import { spawnSync } from 'node:child_process';
import { isDeepStrictEqual } from 'node:util';
import { catalogue, defaults, options } from './pr_sections.ts';
import { history, readSections, summary, RefreshRefusal } from './pr_sections_history.ts';
import { strictJson, refreshFill } from './config_values_refresh.ts';

const here = dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
let mode = args[0];
let scratch: string | undefined;
function plain(value: unknown): string { return String(value).replace(/[\p{Cc}\p{Cf}]/gu, ''); }
/** Match the frozen engine's token walk: option-looking values are consumed, and the last option wins. */
function legacyArgumentValues(argv: string[]): Record<string, string> | undefined {
  const values: Record<string, string> = {};
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--json') continue;
    if (argv[i] === '--refresh') { values['--refresh'] = 'true'; continue; }
    if (['--repo', '--skill', '--id', '--value', '--domain'].includes(argv[i]) && i + 1 < argv.length) {
      values[argv[i]] = argv[++i];
      continue;
    }
    return undefined; // the frozen engine owns the matching invocation refusal
  }
  return values;
}
/** Read one repository declaration without following a symlink or leaving --repo; unread stays unread. */
function confinedJson(repo: string, rel: string): any | undefined {
  try {
    let cursor = repo;
    for (const part of rel.split('/')) {
      cursor = join(cursor, part);
      if (lstatSync(cursor).isSymbolicLink()) return undefined;
    }
    const root = realpathSync(repo);
    const file = realpathSync(join(repo, rel));
    const fromRoot = relative(root, file);
    if (isAbsolute(fromRoot) || fromRoot === '..' || fromRoot.startsWith('../')) return undefined;
    return strictJson(readFileSync(file, 'utf8'));
  } catch { return undefined; }
}
/** HA#246/NN#300: diagnose must agree with set and nen schema check on a standing deploy default. */
function defaultTargetFinding(repo: string): string | undefined {
  const workflow = confinedJson(repo, 'nen/workflow.json');
  const contract = confinedJson(repo, 'nen/contract.json');
  if (!workflow || typeof workflow !== 'object' || Array.isArray(workflow) ||
      !contract || typeof contract !== 'object' || Array.isArray(contract)) return undefined;
  const target = workflow.deploy?.defaultTarget;
  if (target === undefined || target === null || typeof target !== 'string') return undefined;
  const targets = contract.project?.targets;
  if (!targets || typeof targets !== 'object' || Array.isArray(targets) || !Object.prototype.hasOwnProperty.call(targets, target)) return undefined;
  const declaration = targets[target];
  const shown = JSON.stringify(plain(target));
  const pointer = /^[A-Za-z0-9_-]+$/.test(target) ? `project.targets.${plain(target)}` : `project.targets[${shown}]`;
  if (!declaration || typeof declaration !== 'object' || Array.isArray(declaration) ||
      typeof declaration.why !== 'string' || !declaration.why.toLowerCase().includes('non-production')) {
    return `${shown} names ${pointer}, whose why does not clearly say non-production — repair ${pointer}.why in nen/contract.json before keeping deploy.defaultTarget`;
  }
  if (declaration.nonProduction !== true) {
    return `${shown} names ${pointer} without nonProduction: true — set ${pointer}.nonProduction to true in nen/contract.json before keeping deploy.defaultTarget (nen schema check; zheref/nen#300)`;
  }
  return undefined;
}
function applyDefaultTargetFinding(output: string, json: boolean, detail: string | undefined): { output: string; applied: boolean } {
  if (!detail) return { output, applied: false };
  if (json) {
    const document = JSON.parse(output);
    const row = (document.values ?? []).find((value: any) => value.id === 'workflow.deploy.defaultTarget');
    if (!row || row.state !== 'set') return { output, applied: false }; // blocked, null, absent and already-invalid readings stay the engine's.
    row.state = 'invalid';
    row.detail = detail;
    document.outstanding = Number(document.outstanding ?? 0) + 1;
    return { output: JSON.stringify(document, null, 2) + '\n', applied: true };
  }
  const row = /^  ok    (nen\/workflow\.json → deploy\.defaultTarget)\n        [^\n]*$/m;
  if (!row.test(output)) return { output, applied: false };
  output = output.replace(row, (_match, path) => `  BAD   ${path}\n        ${plain(detail)}`);
  const clear = 'every settable value is written out and every needed one is set.';
  const outstanding = '1 value(s) outstanding — `fill` writes the defaults and annotations; the ASK rows are the maintainer\'s answers (docs/WORKFLOW.md § 4).';
  if (output.includes(clear)) output = output.replace(clear, outstanding);
  else output = output.replace(/^(\d+) value\(s\) outstanding —/m, (_, count) => `${Number(count) + 1} value(s) outstanding —`);
  return { output, applied: true };
}
/** HR-23: an intake examiner challenges only at capture intake; machinery, not prose, keeps one out of review.scopes. */
function refuseExaminerReviewer(rows: any[], argv: string[]): void {
  const opts = legacyArgumentValues(argv);
  if (!opts) return;
  if (opts['--id'] !== 'workflow.review.scopes' || opts['--value'] === undefined) return;
  // The examiner set is the catalogue's intake.challenger options: one list, never a second copy here.
  // hanten § 3 resolves claude/agents/<persona>.md, so a path or a namespaced form still reaches the file.
  const fold = (name: string) => plain(name).normalize('NFKC').trim().toLowerCase().split(/[\\/]/).pop()!.replace(/^hatsu:/, '').replace(/\.md$/, '').trim();
  const examiners = new Set(rows.filter(row => String(row.path ?? '').startsWith('intake.challenger.')).flatMap(row => row.options ?? []).map(fold));
  if (examiners.size === 0) throw new Error('refusing workflow.review.scopes: the catalogue names no intake examiner (intake.challenger.* options) to refuse');
  let value: unknown;
  // Fail closed: the engine's json.loads accepts literals (NaN, Infinity) this check cannot read.
  try { value = JSON.parse(opts['--value']); } catch { throw new Error('refusing workflow.review.scopes: --value is not strict JSON, so no intake examiner check can read it (HR-23)'); }
  if (!value || typeof value !== 'object' || Array.isArray(value)) return;
  for (const [scope, entry] of Object.entries(value as Record<string, any>)) {
    const persona = typeof entry?.persona === 'string' ? fold(entry.persona) : '';
    if (examiners.has(persona)) throw new Error(`refusing review.scopes.${scope}.persona = ${JSON.stringify(entry.persona)}: an intake examiner (${[...examiners].join(' | ')}) challenges only at capture intake and is never a hanten reviewer (HR-23)`);
  }
}
/** HA#414: one catalogued value's effective reading, optionally at a git ref (getsuga § 3a reads release.proposalMerge at the re-check's <baseNow>). */
function getValue(rows: any[], argv: string[]): number {
  const opts: Record<string, string> = {};
  let json = false;
  for (let i=0; i<argv.length; i++) {
    if (argv[i] === '--json') { json = true; continue; }
    if (['--repo','--id','--ref'].includes(argv[i]) && i+1 < argv.length) { opts[argv[i]] = argv[++i]; continue; }
    throw new Error(`get: unknown or incomplete argument ${JSON.stringify(plain(argv[i]))} (usage: get --repo <path> --id <catalogue id> [--ref <git ref>] [--json])`);
  }
  if (!opts['--repo'] || !opts['--id']) throw new Error('get: --repo and --id are required');
  const row = rows.find(r => r.id === opts['--id']);
  if (!row) throw new Error(`get: no catalogue row ${JSON.stringify(plain(opts['--id']))}`);
  const repo = resolve(opts['--repo']);
  if (!existsSync(repo)) throw new Error(`get: no such repository ${plain(repo)}`);
  const ref = opts['--ref'];
  let text: string | undefined;
  let sha: string | undefined;
  const unreadable = (why: string) => new Error(`get: could not read ${plain(row.file)}${sha ? ' at '+sha : ''}: ${why}`);
  // Every component of the declaration's path, outermost first: nen, then nen/workflow.json.
  const parts = String(row.file).split('/');
  const prefixes = parts.map((_, i) => parts.slice(0, i+1).join('/'));
  if (ref !== undefined) {
    if (ref.startsWith('-')) throw new Error(`get: --ref ${JSON.stringify(plain(ref))} is not a ref`);
    const rev = spawnSync('git',['-C',repo,'rev-parse','--verify','-q',`${ref}^{commit}`],{encoding:'utf8'});
    if (rev.status !== 0) throw new Error(`get: could not read ${plain(row.file)}: ${JSON.stringify(plain(ref))} does not resolve to a commit in ${plain(repo)}`);
    sha = rev.stdout.trim();
    // SEC-7: git never follows a committed symlink (mode 120000) or a submodule (160000), so a path
    // through one would list nothing and read as absent; each component is checked by its own entry.
    let found = true;
    for (const [i, prefix] of prefixes.entries()) {
      const listed = spawnSync('git',['-C',repo,'ls-tree','--full-tree',sha,'--',prefix],{encoding:'utf8'});
      if (listed.status !== 0) throw unreadable('git ls-tree failed');
      const entry = listed.stdout.split('\n').find(line => line.endsWith(`\t${prefix}`));
      if (!entry) { found = false; break; }
      const [mode, type] = entry.split(/\s+/);
      if (mode === '120000') throw unreadable(`${plain(prefix)} is a symlink; a symlink is refused (SEC-7)`);
      if (type !== (i === prefixes.length-1 ? 'blob' : 'tree')) throw unreadable(`${plain(prefix)} is a ${plain(type)} (mode ${plain(mode)}), not a ${i === prefixes.length-1 ? 'file' : 'directory'}`);
    }
    if (found) {
      const shown = spawnSync('git',['-C',repo,'show',`${sha}:${row.file}`],{encoding:'utf8',maxBuffer:16*1024*1024});
      if (shown.status !== 0) throw unreadable('git show failed');
      text = shown.stdout;
    }
  } else {
    const linked = prefixes.find(prefix => { try { return lstatSync(join(repo,prefix)).isSymbolicLink(); } catch { return false; } });
    if (linked) throw unreadable(`${plain(linked)} is a symlink; a symlink is refused (SEC-7)`);
    const file = join(repo,row.file);
    if (existsSync(file)) {
      const rel = relative(realpathSync(repo),realpathSync(file));
      if (isAbsolute(rel) || rel === '..' || rel.startsWith('../')) throw unreadable('it resolves outside --repo');
      text = readFileSync(file,'utf8');
    }
  }
  let present = false;
  let value: unknown;
  let misshaped: string | undefined;
  if (text !== undefined) {
    let node: any;
    try { node = JSON.parse(text); } catch { throw unreadable('not valid JSON'); }
    present = true;
    const keys = String(row.path).split('.');
    for (const [i, key] of keys.entries()) {
      if (!node || typeof node !== 'object' || Array.isArray(node)) {
        // A component that is present but not an object is a mis-shaped declaration, never an absent one.
        misshaped = i === 0 ? '(the document)' : keys.slice(0, i).join('.');
        break;
      }
      if (!Object.prototype.hasOwnProperty.call(node,key)) { present = false; break; }
      node = node[key];
    }
    if (present) value = node;
  }
  let state: string;
  if (misshaped) state = 'invalid';
  else if (present) state = row.kind === 'enum' && !(row.options ?? []).some((option: unknown) => isDeepStrictEqual(option,value)) ? 'invalid' : 'declared';
  else if (row.default !== undefined) { state = 'default'; value = row.default; }
  else state = 'unset';
  const where = sha ? `at ${plain(ref!)} ${sha}` : 'in the working tree';
  if (json) process.stdout.write(JSON.stringify({id:row.id,file:row.file,path:row.path,state,value:value ?? null,misshaped:misshaped ?? null,options:row.options ?? null,ref:ref ?? null,sha:sha ?? null},null,2)+'\n');
  else {
    const told = misshaped ? `invalid (${misshaped} is declared but not an object)`
      : state === 'unset' ? 'unset, no default'
      : `${JSON.stringify(value)} (${state === 'default' ? 'absent, catalogue default' : state === 'invalid' ? 'declared, outside '+(row.options ?? []).join(' | ') : 'declared'})`;
    process.stdout.write(plain(`${row.id} = ${told} ${where}`)+'\n');
  }
  return state === 'declared' || state === 'default' ? 0 : 1;
}
const safeOutput=(value:string)=>value.replace(/\r\n?/g,'\n').split('\n').map(plain).join('\n');
try {
  let root = dirname(here);
  const forwarded: string[] = [];
  for (let i=0; i<args.length; i++) {
    if (args[i] === '--hatsu-root') {
      if (!args[i+1]) throw new Error('--hatsu-root needs a path');
      root = resolve(args[++i]);
    } else forwarded.push(args[i]);
  }
  // The engine's mode is the first forwarded token: --hatsu-root may come before it.
  mode = forwarded[0];
  const parsedArgs = legacyArgumentValues(forwarded.slice(1));
  const refresh = parsedArgs?.['--refresh'] === 'true';
  if (refresh && mode !== 'fill') throw new Error('--refresh is supported only with fill');
  // Strip only a parsed flag; an option-looking argument value is still consumed by its option.
  if (refresh) {
    for (let i = 1; i < forwarded.length; i++) {
      if (forwarded[i] === '--refresh') { forwarded.splice(i--, 1); continue; }
      if (forwarded[i] !== '--json') i++;
    }
  }
  const wantsJson = forwarded.includes('--json');
  const declaration = JSON.parse(readFileSync(join(root,'contracts/config-catalogue.json'),'utf8'));
  if (!Array.isArray(declaration.values)) throw new Error('configuration catalogue values must be an array');
  let cat: any;
  for (const row of declaration.values) {
    if (row.defaultFrom === undefined) continue;
    if (!['pr-sections','pr-sections.max'].includes(row.defaultFrom)) throw new Error(`unknown defaultFrom ${row.defaultFrom}`);
    cat ??= catalogue(root);
    row.default = row.defaultFrom === 'pr-sections' ? defaults(cat) : cat.max;
  }
  if (cat && mode === 'fill') {
    // Metadata is data passed through the existing fill transaction, not a second write outside its lock.
    // This private row is never part of the consumer-facing settable-value catalogue.
    declaration.values.push({id:'_pr.section-options',file:'nen/workflow.json',path:'pr.$sections',domain:'publishing',kind:'open',
      default:'available sections: '+Object.entries(options(cat)).map(([id,purpose])=>`${id} — ${purpose}`).join(' | '),
      readers:['shibari','tensho','jujisho'],requiredBy:[],describe:'Available PR section ids and purposes.'});
    // Plain fill treats a present sections block as one owned value, including a missing max.
    const repoArg = parsedArgs?.['--repo'];
    if (repoArg && Object.hasOwn(confinedJson(resolve(repoArg), 'nen/workflow.json')?.pr ?? {}, 'sections')) {
      declaration.values = declaration.values.filter((row: any) => row.id !== 'workflow.pr.sections.max');
    }
  }
  if (mode === 'set') refuseExaminerReviewer(declaration.values, forwarded.slice(1));
  // HA#331: a row `ownedBy` a skill (the ci block, kuchiyose's) is written only through that skill's `set`,
  // after its own human-gate ask; diagnose, fill and need never see it, so tenkai never asks or fills it.
  const owned = declaration.values.filter((row: any) => row.ownedBy !== undefined);
  for (const row of owned) if (typeof row.ownedBy !== 'string' || !existsSync(join(root,'claude/skills',row.ownedBy,'SKILL.md'))) throw new Error(`row ${row.id}: ownedBy must name a skill in claude/skills/`);
  if (['diagnose','fill','need'].includes(mode)) declaration.values = declaration.values.filter((row: any) => row.ownedBy === undefined);
  // get reads; it never reaches the frozen engine and creates no scratch.
  if (mode === 'get') process.exitCode = getValue(declaration.values, forwarded.slice(1));
  else {
    scratch = mkdtempSync(join(tmpdir(),'hatsu-config-catalogue-'));
    mkdirSync(join(scratch,'contracts'));
    writeFileSync(join(scratch,'contracts/config-catalogue.json'),JSON.stringify(declaration,null,2)+'\n');
    // Only source documentation and skill existence are consulted by the frozen engine.
    for (const entry of ['claude','docs']) if (existsSync(join(root,entry))) symlinkSync(join(root,entry),join(scratch,entry),'dir');
    if (refresh && (!parsedArgs || !parsedArgs['--repo'])) throw new Error('fill --refresh needs --repo <path> and valid arguments');
    const run = refresh ? refreshFill(resolve(parsedArgs!['--repo']), cat, root, join(here,'config_values_legacy.sh'), scratch, forwarded)
      : spawnSync('bash',[join(here,'config_values_legacy.sh'),...forwarded,'--hatsu-root',scratch],{encoding:'utf8',maxBuffer:16*1024*1024});
    if (run.error) throw run.error;
    let output = run.stdout || '';
    let defaultTargetInvalid = false;
    // Preserve machine-readable output; enrich only the relevant diagnostic row.
    if (mode === 'diagnose' && (run.status === 0 || run.status === 1)) {
      const repoArg = legacyArgumentValues(forwarded.slice(1))?.['--repo'];
      if (repoArg) {
        const repo = resolve(repoArg);
        // An unparseable or linked declaration keeps the engine's own blocked reading.
        const parsed = confinedJson(repo, 'nen/workflow.json') as { pr?: { sections?: any } } | undefined;
        if (parsed) {
          const value = parsed.pr?.sections;
          const sectionDomain = declaration.values.find((row: any) => row.id === 'workflow.pr.sections')?.domain;
          if (cat && value !== undefined && (!parsedArgs?.['--domain'] || parsedArgs['--domain'] === sectionDomain)) {
            const reading = readSections(value, cat, history(root, cat));
            const detail = summary(reading) + (reading.status === 'unstamped' ? '' : '; ' + reading.cells.map(cell => `${cell.cell}: ${cell.state}${cell.retiredIds.length ? ' (retired ids: '+cell.retiredIds.join(', ')+')' : ''}`).join('; '));
            if (wantsJson) {
              const document = JSON.parse(output);
              for (const row of document.values ?? []) if (row.id === 'workflow.pr.sections') { row.detail = detail; row.prSections = reading; }
              output = JSON.stringify(document,null,2)+'\n';
            } else output += plain(detail)+'\n';
          }
        }
        const applied = applyDefaultTargetFinding(output, wantsJson, defaultTargetFinding(repo));
        output = applied.output;
        defaultTargetInvalid = applied.applied;
      }
    }
    if (refresh && !wantsJson) {
      const result = JSON.parse(output);
      output = `pr.sections: refreshed to ${cat.documentSha256.slice(0,7)}; ${result.prSections.detail}; ${result.prSections.kept.length ? 'consumer-owned retained: '+result.prSections.kept.join(', ') : 'no consumer-owned cells'}\n`;
      output += `${result.wrote.length} write(s); ${run.status === 0 ? 'configured' : 'other configuration remains outstanding'}.\n`;
    }
    process.stdout.write(wantsJson ? output : safeOutput(output));
    process.stderr.write(safeOutput(run.stderr || ''));
    process.exitCode = defaultTargetInvalid && run.status === 0 ? 1 : run.status ?? 2;
  }
} catch (error) {
  process.stderr.write('config_values.sh: '+plain(error instanceof Error ? error.message : error)+'\n');
  process.exitCode = error instanceof RefreshRefusal ? 1 : 2;
} finally { if (scratch) rmSync(scratch,{recursive:true,force:true}); }
