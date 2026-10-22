/** HA#351: TypeScript catalogue adapter around the unchanged, frozen configuration engine (BC-11). */
import { readFileSync, writeFileSync, mkdirSync, mkdtempSync, symlinkSync, rmSync, lstatSync, realpathSync, existsSync } from 'node:fs';
import { dirname, join, resolve, relative, isAbsolute } from 'node:path';
import { fileURLToPath } from 'node:url';
import { tmpdir } from 'node:os';
import { spawnSync } from 'node:child_process';
import { isDeepStrictEqual } from 'node:util';
import { catalogue, defaults, options } from './pr_sections.ts';

const here = dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const mode = args[0];
let scratch: string | undefined;
function plain(value: unknown): string { return String(value).replace(/[\p{Cc}\p{Cf}]/gu, ''); }
/** HR-23: an intake examiner challenges only at capture intake; machinery, not prose, keeps one out of review.scopes. */
function refuseExaminerReviewer(rows: any[], argv: string[]): void {
  const flag = (name: string) => { const at = argv.indexOf(name); return at >= 0 ? argv[at+1] : undefined; };
  const literal = flag('--value');
  if (flag('--id') !== 'workflow.review.scopes' || literal === undefined) return;
  // The examiner set is the catalogue's intake.challenger options: one list, never a second copy here.
  const examiners = new Set(rows.filter(row => String(row.path ?? '').startsWith('intake.challenger.')).flatMap(row => row.options ?? []).map(String));
  if (examiners.size === 0) throw new Error('refusing workflow.review.scopes: the catalogue names no intake examiner (intake.challenger.* options) to refuse');
  let value: unknown;
  try { value = JSON.parse(literal); } catch { return; } // the engine refuses a malformed literal itself
  if (!value || typeof value !== 'object' || Array.isArray(value)) return;
  for (const [scope, entry] of Object.entries(value as Record<string, any>)) {
    const persona = typeof entry?.persona === 'string' ? entry.persona.trim().toLowerCase() : '';
    if (examiners.has(persona)) throw new Error(`refusing review.scopes.${scope}.persona = ${JSON.stringify(entry.persona)}: an intake examiner (${[...examiners].join(' | ')}) challenges only at capture intake and is never a hanten reviewer (HR-23)`);
  }
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
  }
  if (mode === 'set') refuseExaminerReviewer(declaration.values, forwarded);
  scratch = mkdtempSync(join(tmpdir(),'hatsu-config-catalogue-'));
  mkdirSync(join(scratch,'contracts'));
  writeFileSync(join(scratch,'contracts/config-catalogue.json'),JSON.stringify(declaration,null,2)+'\n');
  // Only source documentation and skill existence are consulted by the frozen engine.
  for (const entry of ['claude','docs']) if (existsSync(join(root,entry))) symlinkSync(join(root,entry),join(scratch,entry),'dir');
  const run = spawnSync('bash',[join(here,'config_values_legacy.sh'),...forwarded,'--hatsu-root',scratch],{encoding:'utf8',maxBuffer:16*1024*1024});
  if (run.error) throw run.error;
  let output = run.stdout || '';
  // Preserve machine-readable output; enrich only the relevant diagnostic row.
  if (cat && mode === 'diagnose') {
    const repoAt = args.indexOf('--repo');
    if (repoAt >= 0 && args[repoAt+1]) {
      const repo = resolve(args[repoAt+1]);
      const workflow = join(repo,'nen/workflow.json');
      const safe = [join(repo,'nen'),workflow].every(path=>{try{return !lstatSync(path).isSymbolicLink();}catch{return false;}});
      const rel = safe ? relative(repo,realpathSync(workflow)) : '..';
      if (safe && !isAbsolute(rel) && rel !== '..' && !rel.startsWith('../')) {
        const value = JSON.parse(readFileSync(workflow,'utf8')).pr?.sections;
        if (value && !isDeepStrictEqual(value, defaults(cat))) {
          const changed = Object.entries(value.variants ?? {}).filter(([cell,ids])=>!isDeepStrictEqual(ids,cat.variants[cell])).map(([cell])=>cell);
          const detail = `consumer value — pr.sections${changed.length ? ': '+changed.join(', ') : ''}; retained`;
          if (args.includes('--json')) {
            const document = JSON.parse(output);
            for (const row of document.values ?? []) if (row.id === 'workflow.pr.sections') row.detail = detail;
            output = JSON.stringify(document,null,2)+'\n';
          } else output += plain(detail)+'\n';
        }
      }
    }
  }
  process.stdout.write(args.includes('--json') ? output : safeOutput(output));
  process.stderr.write(safeOutput(run.stderr || ''));
  process.exitCode = run.status ?? 2;
} catch (error) {
  process.stderr.write('config_values.sh: '+plain(error instanceof Error ? error.message : error)+'\n');
  process.exitCode = 2;
} finally { if (scratch) rmSync(scratch,{recursive:true,force:true}); }
