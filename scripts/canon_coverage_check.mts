#!/usr/bin/env node
// zheref/hatsu#502 (SDD plan wave 4, assessment finding C6): every decision row is cited by the skills
// it lists, and every declared lane is named by canon prose.
//
//   1. DECISION ROWS. Each row of nen/decisions.json carries `citedBy`, an array of skill names
//      (claude/skills/<name>). A skill CITES a row when its SKILL.md carries the row id as a code
//      span, `<id>`. Findings, by row id: a row with no citedBy array; a listed name with no
//      SKILL.md; a listed skill that does not cite the row; a skill that cites the row and is not
//      listed; a row cited by no skill with no `uncitedReason` (a non-empty string naming where the
//      row is raised instead); and an `uncitedReason` on a row some skill cites (stale).
//   2. LANES. Each key of nen/contract.json's project.lanes must be NAMED by at least one canon
//      file: the paths contracts/prose.lint.json's paths.include lists (its own globs: `*` one path
//      segment, `**` any number), surfaces/** never. A lane is named by a code span, `<lane>`, or by
//      `--lane <lane>`. A lane no canon file names is a finding, by name; nen/contract.json's own
//      $comment never counts.
//   3. Findings are exit 1, one line each on stdout, then one summary line. A TOOLING FAILURE is exit
//      2 on stderr with nothing on stdout: wrong usage, an unreadable or malformed nen/decisions.json,
//      nen/contract.json or contracts/prose.lint.json, a decisions row with no string id, or a lint
//      contract with no include list.
//
// nen's decisions loader reads id, class, default and why and keeps other keys (verified against the
// v0.28.0 pin's `nen schema check`); the citing list is Hatsu's key, and a nen verb validating it is
// owed to Nen (assessment C6's cite-check verb, unfiled).
//
// Usage: node scripts/canon_coverage_check.mts [--root <hatsu>]
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

function refuse(message: string): never {
  console.error(`canon-coverage-check: ${message}`);
  process.exit(2);
}
const args = process.argv.slice(2);
let root = fileURLToPath(new URL('..', import.meta.url));
for (let i = 0; i < args.length; i += 1) {
  if (args[i] === '--root' && args[i + 1] !== undefined) {
    root = resolve(args[i + 1]);
    i += 1;
  } else refuse(`unknown or incomplete argument ${JSON.stringify(args[i])}\nusage: canon_coverage_check.mts [--root <hatsu>]`);
}
function json(path: string): any {
  try {
    return JSON.parse(readFileSync(join(root, path), 'utf8'));
  } catch (error) {
    refuse(`cannot read ${path}: ${(error as Error).message}`);
  }
}
const codeSpan = (text: string, id: string): boolean => text.includes('`' + id + '`');
const escape = (s: string): string => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

const findings: string[] = [];

// 1. Decision rows.
const decisions = json('nen/decisions.json');
if (!decisions || !Array.isArray(decisions.rows)) refuse('nen/decisions.json has no rows array');
const skillsDir = join(root, 'claude', 'skills');
const skills = new Map<string, string>();
if (existsSync(skillsDir)) {
  for (const entry of readdirSync(skillsDir, { withFileTypes: true })) {
    const file = join(skillsDir, entry.name, 'SKILL.md');
    if (entry.isDirectory() && existsSync(file)) skills.set(entry.name, readFileSync(file, 'utf8'));
  }
}
let cited = 0;
for (const [index, row] of decisions.rows.entries()) {
  if (!row || typeof row.id !== 'string' || row.id === '') refuse(`nen/decisions.json rows[${index}] has no string id`);
  const id: string = row.id;
  const citing = [...skills].filter(([, text]) => codeSpan(text, id)).map(([name]) => name).sort();
  if (citing.length) cited += 1;
  if (!Array.isArray(row.citedBy) || row.citedBy.some((s: unknown) => typeof s !== 'string')) {
    findings.push(`coverage: decision ${id}: no citedBy list of skill names (cited by ${citing.join(', ') || 'no skill'})`);
    continue;
  }
  const listed = new Set<string>(row.citedBy);
  for (const name of listed) {
    if (!skills.has(name)) findings.push(`coverage: decision ${id}: citedBy names ${name}, which has no claude/skills/${name}/SKILL.md`);
    else if (!citing.includes(name)) findings.push(`coverage: decision ${id}: citedBy lists ${name}, which does not cite it`);
  }
  for (const name of citing) if (!listed.has(name)) findings.push(`coverage: decision ${id}: cited by ${name}, which citedBy does not list`);
  const reason = typeof row.uncitedReason === 'string' && row.uncitedReason.trim() !== '';
  if (citing.length === 0 && !reason) findings.push(`coverage: decision ${id}: cited by no skill, and no uncitedReason says where it is raised`);
  if (citing.length > 0 && row.uncitedReason !== undefined) findings.push(`coverage: decision ${id}: uncitedReason on a row ${citing.join(', ')} cites (stale)`);
}

// 2. Lanes.
const contract = json('nen/contract.json');
const lanes = contract?.project?.lanes;
if (!lanes || typeof lanes !== 'object' || Array.isArray(lanes)) refuse('nen/contract.json has no project.lanes object');
const include = json('contracts/prose.lint.json')?.paths?.include;
if (!Array.isArray(include) || include.length === 0 || include.some((g: unknown) => typeof g !== 'string')) refuse('contracts/prose.lint.json has no paths.include list');
const globs = (include as string[]).map((g) => new RegExp('^' + g.split('/').map((seg) => seg === '**' ? '(?:[^/]+/)*' : escape(seg).replace(/\\\*/g, '[^/]*') + '/').join('').replace(/\/$/, '').replace(/\(\?:\[\^\/\]\+\/\)\*$/, '.*') + '$'));
const SKIP = new Set(['.git', 'node_modules', 'surfaces', '.nen', '.trusted', '.claude']);
const canon: string[] = [];
(function walk(dir: string): void {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      if (!SKIP.has(entry.name)) walk(join(dir, entry.name));
    } else if (entry.isFile()) {
      const rel = relative(root, join(dir, entry.name)).split(sep).join('/');
      if (globs.some((g) => g.test(rel))) canon.push(readFileSync(join(dir, entry.name), 'utf8'));
    }
  }
})(root);
const laneNames = Object.keys(lanes);
for (const lane of laneNames) {
  const flag = new RegExp(`--lane[ =]${escape(lane)}(?![\\w-])`);
  if (!canon.some((text) => codeSpan(text, lane) || flag.test(text))) {
    findings.push(`coverage: lane ${lane}: named by no canon file (no \`${lane}\` code span or --lane ${lane} under contracts/prose.lint.json paths.include)`);
  }
}

for (const line of findings) console.log(line);
console.log(`coverage: ${decisions.rows.length} decision row(s), ${cited} cited by a skill; ${laneNames.length} lane(s) over ${canon.length} canon file(s); ${findings.length} finding(s)`);
process.exit(findings.length ? 1 : 0);
