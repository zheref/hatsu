#!/usr/bin/env node
// prose_diet_names.ts: which SKILL.md a diet-list entry is measured under while it is being renamed
// (zheref/hatsu#354; step one of the two-step landing in docs/GATE-CONFIGURATION.md section 6).
//
// scripts/prose_size_check.sh hands this the measured root, its DIETED_SKILLS words and its
// DIET_NEXT_NAMES `<listed>:<next>` pairs. The validation of a pair row and the four-state route over
// (listed on disk, next on disk) are predicates and a verdict, so they are TypeScript's (BC-11); the
// shell keeps only what it already owned: admitting a path under the root and measuring it.
//
// It prints a plan, one tab-separated line per step, in diet-list order:
//   M <name>   measure claude/skills/<name>/SKILL.md under the skill ceiling
//   N <text>   say <text> (a renamed entry is never silent)
//   O <text>   an offence, counted by the guard
//   E <n>      the last line: how many listed skills the plan accounted for, which the guard holds
//              against its own list so an empty or truncated plan is never read as a clean run
// "On disk" is the guard's own reading: the entry exists, or is a symlink even to nothing, so a
// dangling link reaches `admit` and is named there instead of reading as absent.
//
// Exit 0: the plan is on stdout. Exit 2: wiring, the sentence on stderr and nothing on stdout: a
// usage error, or a pair row that is not <listed>:<next> in skill-name characters, renames a skill
// the list does not hold, names a listed skill twice, or gives a next name the list or another
// pair already holds (one file must never answer for two skills).
//
// Deleted, with the pair and its fixture cases, by the rename's own pull request (step two).
import { lstatSync } from 'node:fs';
import { join } from 'node:path';

const NAME = /^[a-z][a-z0-9-]*$/;
const PAIR = /^[a-z][a-z0-9-]*:[a-z][a-z0-9-]*$/;

class Wiring extends Error {}

function onDisk(root: string, name: string): boolean {
  try {
    lstatSync(join(root, 'claude', 'skills', name, 'SKILL.md'));
    return true;
  } catch {
    return false;
  }
}

function readPairs(listed: readonly string[], rows: readonly string[]): Map<string, string> {
  const pairs = new Map<string, string>();
  const taken = new Set<string>(listed);
  for (const row of rows) {
    if (!PAIR.test(row)) throw new Wiring(`DIET_NEXT_NAMES holds '${row}', not <listed>:<next> in skill-name characters`);
    const [from, to] = row.split(':') as [string, string];
    if (!listed.includes(from)) throw new Wiring(`DIET_NEXT_NAMES renames '${from}', which is not on the diet list`);
    if (pairs.has(from)) throw new Wiring(`DIET_NEXT_NAMES names '${from}' twice; one next name per listed skill`);
    if (taken.has(to)) {
      throw new Wiring(`DIET_NEXT_NAMES gives '${from}' the next name '${to}', which the diet list or another pair already holds`);
    }
    pairs.set(from, to);
    taken.add(to);
  }
  return pairs;
}

function plan(root: string, listed: readonly string[], pairs: ReadonlyMap<string, string>): string[] {
  const lines: string[] = [];
  for (const skill of listed) {
    const next = pairs.get(skill);
    const path = `claude/skills/${skill}/SKILL.md`;
    const here = onDisk(root, skill);
    const there = next !== undefined && onDisk(root, next);
    if (here) lines.push(`M\t${skill}`);
    if (there) {
      if (!here) lines.push(`N\tNEXT-NAME  ${path} is absent; its next name claude/skills/${next}/SKILL.md holds its ceiling (DIET_NEXT_NAMES)`);
      lines.push(`M\t${next}`);
    }
    if (!here && !there) {
      const tail = next === undefined ? '' : ` (nor is its next name, claude/skills/${next}/SKILL.md)`;
      lines.push(`O\tMISSING  ${path} -- named on the diet list and not on disk${tail}`);
    }
  }
  return lines;
}

function main(args: readonly string[]): number {
  const cut = args.indexOf('--');
  if (args.length < 3 || cut < 2) throw new Wiring('prose_diet_names.ts takes <root> <dieted skill>... -- <listed>:<next>...');
  const root = args[0] as string;
  const listed = args.slice(1, cut);
  for (const skill of listed) {
    if (!NAME.test(skill)) throw new Wiring(`DIETED_SKILLS holds '${skill}', not a skill name`);
  }
  const lines = plan(root, listed, readPairs(listed, args.slice(cut + 1)));
  lines.push(`E\t${listed.length}`);
  process.stdout.write(`${lines.join('\n')}\n`);
  return 0;
}

try {
  process.exitCode = main(process.argv.slice(2));
} catch (error) {
  if (!(error instanceof Wiring)) throw error;
  console.error(`prose_size_check.sh: ${error.message}`);
  process.exitCode = 2;
}
