#!/usr/bin/env node
// zheref/hatsu#502 (SDD plan wave 4, assessment finding B6): every touched skill carries the shape
// canon asks for -- a Residue, an Authority and a Hard limits section -- or a reasoned exemption.
//
//   1. THE SHAPE IS DATA. contracts/skill-shape.json holds the requirement set ({name, pattern}, the
//      form `nen pr body-check --requirements-from` reads) and the exemption list. The heading match
//      is nen's: each checked SKILL.md is handed to `nen pr body-check --body-from <file>
//      --requirements-from <set> --json` and nen's verdict is read. Nothing here restates a pattern.
//   2. ENFORCED AS TOUCHED. Exactly one selector says which skills are checked: --base <ref> (every
//      skill whose SKILL.md differs between the merge base of <ref> and HEAD and the working tree, or
//      is untracked), --base-root <dir> (every skill whose SKILL.md is absent from, or differs in
//      bytes from, the same path under <dir>: a base revision's checkout), --skills <a,b> or --all.
//      A skill no selector reaches is never failed for its shape. A deleted skill is not checked.
//   3. FINDINGS, exit 1, one line each on stdout: a checked skill missing a required section it is
//      not exempt from (named); an exemption with no reason, or naming an unknown skill or section;
//      and an exemption whose section the checked skill in fact carries (stale). The reason and name
//      rules bind every entry, checked or not.
//   4. A TOOLING FAILURE IS NOT A FINDING: wrong usage, an unreadable or malformed contract, a --base
//      git cannot resolve (or one starting with '-'), a missing --base-root, an unknown --skills name,
//      or nen exiting other than 0 or 1 or printing no verdict exits 2 on stderr, so "could not look"
//      never reads as "looked and found nothing".
//
// Usage: node scripts/skill_shape_check.mts [--root <hatsu>] [--contract <path>] [--nen <bin>]
//          (--base <ref> | --base-root <dir> | --skills <a,b> | --all)
import { existsSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const USAGE = 'usage: skill_shape_check.mts [--root <hatsu>] [--contract <path>] [--nen <bin>] (--base <ref> | --base-root <dir> | --skills <a,b> | --all)';

type Requirement = { name: string; pattern: string };
type Exemption = { skill?: unknown; sections?: unknown; reason?: unknown };

function refuse(message: string): never {
  console.error(`skill-shape-check: ${message}`);
  process.exit(2);
}

const args = process.argv.slice(2);
let root = fileURLToPath(new URL('..', import.meta.url));
let contractPath: string | null = null;
let nen = process.env.NEN || 'nen';
const selectors: Array<[string, string | null]> = [];
for (let i = 0; i < args.length; i += 1) {
  const flag = args[i];
  const value = (): string => {
    const next = args[i + 1];
    if (next === undefined) refuse(`${flag} needs a value\n${USAGE}`);
    i += 1;
    return next;
  };
  if (flag === '--root') root = resolve(value());
  else if (flag === '--contract') contractPath = resolve(value());
  else if (flag === '--nen') nen = value();
  else if (flag === '--base' || flag === '--base-root' || flag === '--skills') selectors.push([flag, value()]);
  else if (flag === '--all') selectors.push([flag, null]);
  else refuse(`unknown argument ${JSON.stringify(flag)}\n${USAGE}`);
}
if (selectors.length !== 1) refuse(`exactly one of --base, --base-root, --skills or --all is required\n${USAGE}`);
const skillsDir = join(root, 'claude', 'skills');
if (!existsSync(skillsDir) || !statSync(skillsDir).isDirectory()) refuse(`${root} has no claude/skills directory`);
contractPath ??= join(root, 'contracts', 'skill-shape.json');

let contract: { requirements?: unknown; exemptions?: unknown };
try {
  contract = JSON.parse(readFileSync(contractPath, 'utf8'));
} catch (error) {
  refuse(`cannot read the shape contract ${contractPath}: ${(error as Error).message}`);
}
if (contract === null || typeof contract !== 'object' || Array.isArray(contract)) refuse(`${contractPath} is not a JSON object`);
const requirements = contract.requirements;
if (!Array.isArray(requirements) || requirements.length === 0) refuse(`${contractPath}: requirements must be a non-empty array`);
const names = new Set<string>();
for (const [index, row] of requirements.entries()) {
  const r = row as Requirement;
  if (r === null || typeof r !== 'object' || typeof r.name !== 'string' || r.name === '' || typeof r.pattern !== 'string' || r.pattern === '') {
    refuse(`${contractPath}: requirements[${index}] must be {name, pattern}, both non-empty strings`);
  }
  if (names.has(r.name)) refuse(`${contractPath}: requirement ${r.name} is declared twice`);
  names.add(r.name);
}
if (!Array.isArray(contract.exemptions)) refuse(`${contractPath}: exemptions must be an array (an empty one is a decision)`);

const onDisk = readdirSync(skillsDir, { withFileTypes: true })
  .filter((entry) => entry.isDirectory() && existsSync(join(skillsDir, entry.name, 'SKILL.md')))
  .map((entry) => entry.name)
  .sort();
const known = new Set(onDisk);

const findings: string[] = [];
const exempt = new Map<string, Set<string>>();
for (const [index, row] of (contract.exemptions as unknown[]).entries()) {
  if (row === null || typeof row !== 'object' || Array.isArray(row)) refuse(`${contractPath}: exemptions[${index}] is not an object`);
  const e = row as Exemption;
  const skill = typeof e.skill === 'string' && e.skill !== '' ? e.skill : `exemptions[${index}]`;
  if (typeof e.skill !== 'string' || !known.has(e.skill)) findings.push(`skill-shape: exemption ${skill}: names no skill under claude/skills`);
  if (typeof e.reason !== 'string' || e.reason.trim() === '') findings.push(`skill-shape: exemption ${skill}: names no reason`);
  if (!Array.isArray(e.sections) || e.sections.length === 0) {
    findings.push(`skill-shape: exemption ${skill}: names no section`);
    continue;
  }
  const set = exempt.get(skill) ?? new Set<string>();
  for (const section of e.sections) {
    if (typeof section !== 'string' || !names.has(section)) findings.push(`skill-shape: exemption ${skill}: names unknown section ${JSON.stringify(section)}`);
    else set.add(section);
  }
  exempt.set(skill, set);
}

function git(argv: string[]): string {
  const result = spawnSync('git', ['-C', root, ...argv], { encoding: 'utf8' });
  if (result.error || result.status !== 0) refuse(`git ${argv.join(' ')} failed: ${result.error?.message ?? String(result.stderr).trim()}`);
  return String(result.stdout);
}
const SKILL_PATH = /^claude\/skills\/([^/]+)\/SKILL\.md$/;

const [selector, selected] = selectors[0];
let checked: string[];
let against: string;
if (selector === '--all') {
  checked = onDisk;
  against = 'every skill';
} else if (selector === '--skills') {
  checked = [...new Set(String(selected).split(',').map((s) => s.trim()).filter(Boolean))].sort();
  if (checked.length === 0) refuse('--skills names no skill');
  for (const s of checked) if (!known.has(s)) refuse(`--skills names ${JSON.stringify(s)}, which has no claude/skills/${s}/SKILL.md`);
  against = 'the named skills';
} else if (selector === '--base') {
  const ref = String(selected);
  if (ref.startsWith('-')) refuse(`--base ${JSON.stringify(ref)} starts with '-'`);
  const mergeBase = git(['merge-base', ref, 'HEAD']).trim();
  const changed = git(['diff', '--name-only', '-z', mergeBase, '--', 'claude/skills']).split('\0');
  const untracked = git(['ls-files', '-z', '--others', '--exclude-standard', '--', 'claude/skills']).split('\0');
  checked = [...new Set([...changed, ...untracked].map((p) => SKILL_PATH.exec(p)?.[1]).filter((s): s is string => !!s && known.has(s)))].sort();
  against = `the merge base of ${ref} (${mergeBase.slice(0, 12)})`;
} else {
  const baseRoot = resolve(String(selected));
  if (!existsSync(baseRoot) || !statSync(baseRoot).isDirectory()) refuse(`--base-root ${baseRoot} is not a directory`);
  checked = onDisk.filter((s) => {
    const before = join(baseRoot, 'claude', 'skills', s, 'SKILL.md');
    return !existsSync(before) || !readFileSync(before).equals(readFileSync(join(skillsDir, s, 'SKILL.md')));
  });
  against = `the base tree ${baseRoot}`;
}

const scratch = mkdtempSync(join(tmpdir(), 'hatsu-skill-shape-'));
const reqFile = join(scratch, 'requirements.json');
// The whole set is probed, exempt sections included, so an exemption the skill no longer needs is named.
writeFileSync(reqFile, JSON.stringify(requirements));
try {
  for (const skill of checked) {
    const skip = exempt.get(skill) ?? new Set<string>();
    const file = join(skillsDir, skill, 'SKILL.md');
    const result = spawnSync(nen, ['pr', 'body-check', '--body-from', file, '--requirements-from', reqFile, '--json'], { encoding: 'utf8' });
    if (result.error) refuse(`could not run ${nen}: ${result.error.message}`);
    if (result.status !== 0 && result.status !== 1) refuse(`nen pr body-check exited ${result.status} on ${skill}: ${String(result.stderr).trim()}`);
    let verdict: { results?: Array<{ name?: unknown; satisfied?: unknown }> };
    try {
      verdict = JSON.parse(String(result.stdout));
    } catch {
      refuse(`nen pr body-check printed no JSON verdict on ${skill}`);
    }
    const rows = Array.isArray(verdict?.results) ? verdict.results : null;
    if (!rows) refuse(`nen pr body-check's verdict on ${skill} has no results array`);
    for (const name of names) {
      const row = rows.find((r) => r.name === name);
      if (!row || typeof row.satisfied !== 'boolean') refuse(`nen pr body-check's verdict on ${skill} has no row for ${name}`);
      if (!row.satisfied && !skip.has(name)) findings.push(`skill-shape: ${skill}: missing the ${name} section (claude/skills/${skill}/SKILL.md)`);
      if (row.satisfied && skip.has(name)) findings.push(`skill-shape: exemption ${skill}: stale, the skill carries the ${name} section`);
    }
  }
} finally {
  rmSync(scratch, { recursive: true, force: true });
}

for (const line of findings) console.log(line);
console.log(`skill-shape: ${checked.length} skill(s) checked against ${against}${checked.length ? ` (${checked.join(', ')})` : ''}; ${findings.length} finding(s)`);
process.exit(findings.length ? 1 : 0);
