/** HA#351: section predicates in TypeScript; the old path-set guard only shrinks (BC-11). */
import { readFileSync, existsSync, realpathSync } from 'node:fs';
import { join, dirname, resolve, relative, isAbsolute } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { isDeepStrictEqual } from 'node:util';
import { catalogue, requirementsFor } from './pr_sections.ts';
import { history } from './pr_sections_history.ts';
const here=dirname(fileURLToPath(import.meta.url));
const DECL='contracts/pr-composition.json';
const findings:string[]=[];
const plain=(x:unknown)=>String(x).replace(/[\p{Cc}\p{Cf}]/gu,'');
const safeOutput=(x:string)=>x.replace(/\r\n?/g,'\n').split('\n').map(plain).join('\n');
let root=dirname(here);
function fail(message:string):never { throw new Error(message); }
function confined(rel:any,where:string):boolean {
  if (typeof rel!=='string' || !rel) { findings.push(`${DECL}: ${where} is missing`); return false; }
  let real=resolve(root,rel);
  if (existsSync(real)) real=realpathSync(real);
  const sub=relative(realpathSync(root),real);
  if(isAbsolute(rel)||rel.replaceAll('\\','/').split('/').includes('..')||sub==='..'||sub.startsWith('../')||isAbsolute(sub)) {
    findings.push(`${DECL}: ${where} '${rel}' escapes the root (absolute, \`..\` or a link out); refused`);return false;
  }
  return true;
}
function text(rel:string):string {return new TextDecoder('utf-8',{fatal:true}).decode(readFileSync(join(root,rel)));}
function load(rel:string):any {if(!existsSync(join(root,rel)))fail(`${rel} is missing`);try{return JSON.parse(text(rel));}catch(error){fail(`${rel} is not readable JSON (${String(error)})`);}}
try {
 const args=process.argv.slice(2);
 for(let i=0;i<args.length;i++) {
   if(args[i]==='--root'&&args[i+1])root=resolve(args[++i]);
   else if(['-h','--help'].includes(args[i])){console.log('pr_composition_check.sh [--root <hatsu checkout>]');process.exit(0);}
   else fail(`unknown argument '${args[i]}'`);
 }
 if(!existsSync(join(root,'.claude-plugin/plugin.json')))fail(`'${root}' is not a Hatsu checkout (no .claude-plugin/plugin.json)`);
 const decl=load(DECL), body=decl.bodyRequirements??{};
 if(body.catalogue!==undefined) {
   if(body.catalogue!=='contracts/pr-sections.json')findings.push(`${DECL}: bodyRequirements.catalogue must name contracts/pr-sections.json`);
   if(confined(body.catalogue,'bodyRequirements.catalogue')&&confined(body.file,'bodyRequirements.file')) {
    try {
     const cat=catalogue(root);
     history(root,cat);
     const ids=cat.variants[`${body.defaultKind}.${body.defaultFamily}`];
     if(!ids)throw new Error('unknown default kind/family');
     const rows=[...cat.preamble,...ids.map((id:string)=>cat.sections.find((r:any)=>r.id===id)),...cat.footer.filter((r:any)=>!r.reserved&&r.when===undefined)];
     const expected=requirementsFor(rows,body.defaultKind);
     if(!isDeepStrictEqual(load(body.file),expected))findings.push(`${body.file}: drifts from catalogue default ${body.defaultKind}.${body.defaultFamily}`);
     for(const row of [...cat.preamble,...cat.sections,...cat.footer]) {
       const source=text(row.template);
       if(!source.includes(`<!-- block: ${row.id};`))findings.push(`${row.template}: missing block marker`);
       if(/no CHANGELOG entry:/i.test(source))findings.push(`${row.template}: carries the fragment opt-out phrase`);
     }
    } catch(error) {findings.push('PR sections catalogue: '+(error instanceof Error?error.message:String(error)));}
   }
 } else {
   const optional=body.optionalHeadings??[];
   if(!Array.isArray(optional)||optional.some((x:any)=>typeof x!=='string'))findings.push(`${DECL}: bodyRequirements.optionalHeadings is not an array of strings`);
   if(confined(body.file,'bodyRequirements.file')&&confined(body.template,'bodyRequirements.template')) {
    const requirements=load(body.file);
    let template:string|undefined;
    try{template=text(body.template);}catch{findings.push(`${body.template}: missing, unreadable or not UTF-8 (bodyRequirements.template)`);}
    if(template!==undefined) {
      for(const hit of template.matchAll(/no CHANGELOG entry:/gi))findings.push(`${body.template}:${template.slice(0,hit.index).split('\n').length}: carries the fragment opt-out phrase, which nen honours anywhere in a body, a kept comment or fence included`);
      if(!Array.isArray(requirements)||!requirements.length)findings.push(`${body.file}: not a non-empty JSON array of {name, pattern}`);
      else {
        const headings:string[]=[];let fence:string|undefined;
        for(const line of template.replace(/<!--[\s\S]*?-->/g,'').split(/\r?\n/)) {
          const marker=/^\s*(`{3,}|~{3,})/.exec(line);
          if(marker){if(!fence)fence=marker[1];else if(marker[1][0]===fence[0]&&marker[1].length>=fence.length)fence=undefined;continue;}
          const match=/^## (.+?)\s*$/.exec(line);if(!fence&&match)headings.push(match[1]);
        }
        if(Array.isArray(optional))for(const name of optional)if(!headings.includes(name))findings.push(`${DECL}: optional heading '${name}' is not a heading of ${body.template}`);
        const expected=headings.filter(h=>!Array.isArray(optional)||!optional.includes(h));
        const names:string[]=[], compiled:{name:string,regex:RegExp}[]=[];
        for(const [index,row] of requirements.entries()) {
          if(!row||typeof row.name!=='string'||typeof row.pattern!=='string'){findings.push(`${body.file}: entry ${index} is not {name, pattern}`);continue;}
          names.push(row.name);try{compiled.push({name:row.name,regex:new RegExp(row.pattern,'im')});}catch{findings.push(`${body.file}: '${row.name}' has an unparseable pattern`);}
        }
        if(!isDeepStrictEqual(names,expected))findings.push(`${body.file}: names ${JSON.stringify(names)} are not ${body.template}'s required headings ${JSON.stringify(expected)}, in order`);
        const filled=(ids:string[])=>ids.map(h=>`## ${h}\n\nfilled.\n\n`).join('');
        for(const {name,regex} of compiled) {
          if(!regex.test(filled(expected)))findings.push(`${body.file}: '${name}' does not match a body that carries \`## ${name}\``);
          if(regex.test(filled(expected.filter(h=>h!==name))))findings.push(`${body.file}: '${name}' matches a body without \`## ${name}\`, so it checks nothing`);
        }
      }
    }
   }
 }
 for(const finding of findings)console.log(plain(finding));
 const run=spawnSync('bash',[join(here,'pr_composition_paths_check.sh'),'--root',root],{encoding:'utf8',maxBuffer:16*1024*1024});
 if(run.error)throw run.error;
 if(run.signal || run.status === null)throw new Error(`path-set guard did not complete (${run.signal ?? "no exit status"})`);
 const stdout=(run.stdout||'').split('\n').filter(line=>!findings.length||!line.startsWith('pr-composition ok:')).join('\n');
 process.stdout.write(safeOutput(stdout));process.stderr.write(safeOutput(run.stderr||''));
 process.exitCode=run.status !== 0 ? run.status : findings.length ? 1 : 0;
} catch(error) {console.error('pr_composition_check.sh: '+plain(error instanceof Error?error.message:error));process.exitCode=2;}
