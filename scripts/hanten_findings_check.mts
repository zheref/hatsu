#!/usr/bin/env node
// HR-10 as amended by HR-337: findings on ruled HR rows are critical and
// fixed or deferred; findings on reading, reversed or superseded rows may be
// pushed back only with a reason. The status vocabulary and row parser belong
// to clause_id_guard.mts and are imported rather than repeated here.
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseRosterStatuses, RosterStatusFailure } from './clause_id_guard.mts';

interface Finding {
  readonly id?: unknown;
  readonly rule?: unknown;
  readonly severity?: unknown;
  readonly disposition?: { readonly state?: unknown; readonly detail?: unknown };
}

const HR = /^HR-([1-9][0-9]*)$/;

function safe(value: unknown, fallback: string): string {
  if (typeof value !== 'string' || value.trim() === '') return fallback;
  return value.replace(/[\u0000-\u001f\u007f-\u009f\u202a-\u202e\u2066-\u2069]/g, '?').slice(0, 120);
}

export function checkFindings(document: unknown, rosterContents: string): readonly string[] {
  if (typeof document !== 'object' || document === null || !Array.isArray((document as { findings?: unknown }).findings)) {
    throw new RosterStatusFailure('the findings document has no findings array');
  }
  const statuses = new Map(parseRosterStatuses(rosterContents).map((row) => [row.id, row]));
  const errors: string[] = [];
  for (const [index, raw] of (document as { findings: unknown[] }).findings.entries()) {
    if (typeof raw !== 'object' || raw === null) throw new RosterStatusFailure(`findings[${index}] is not an object`);
    const finding = raw as Finding;
    if (typeof finding.rule !== 'string') continue;
    const match = HR.exec(finding.rule);
    if (!match) continue;
    const name = safe(finding.id, `findings[${index}]`);
    const row = statuses.get(String(Number(match[1])));
    if (!row) {
      errors.push(`${name} cites ${finding.rule}, which no ROSTER row defines`);
      continue;
    }
    const where = `${finding.rule} (ROSTER line ${row.line}, ${row.status})`;
    const state = finding.disposition?.state;
    if (row.status === 'ruled') {
      if (finding.severity !== 'critical') errors.push(`${name} cites ruled ${where}: severity must be critical`);
      if (state !== 'fixed' && state !== 'deferred') errors.push(`${name} cites ruled ${where}: disposition must be fixed or deferred, not ${safe(state, 'missing')}`);
    } else if (state === 'pushed-back' && (typeof finding.disposition?.detail !== 'string' || !/\S/.test(finding.disposition.detail))) {
      errors.push(`${name} cites ${where}: a pushed-back disposition needs a non-empty reason`);
    }
  }
  return errors;
}

function main(argv: string[]): number {
  if (argv.length < 1 || argv.length > 2) {
    console.error('hanten-findings-check: usage: hanten_findings_check.mts <findings.json> [<roster.md>]');
    return 2;
  }
  const findingsPath = argv[0] ?? '';
  const rosterPath = argv[1] ?? 'docs/ROSTER.md';
  if (/[,\r\n]/.test(findingsPath)) {
    console.error('hanten-findings-check: refusing a findings path holding a comma or line break; an annotation cannot name it');
    return 2;
  }
  let document: unknown;
  let roster: string;
  try {
    document = JSON.parse(readFileSync(findingsPath, 'utf8'));
  } catch (error) {
    console.error(`hanten-findings-check: cannot read ${findingsPath} as JSON: ${(error as Error).message}`);
    return 2;
  }
  try {
    roster = readFileSync(rosterPath, 'utf8');
  } catch (error) {
    console.error(`hanten-findings-check: cannot read roster ${rosterPath}: ${(error as Error).message}`);
    return 2;
  }
  let findings: readonly string[];
  try {
    findings = checkFindings(document, roster);
  } catch (error) {
    if (!(error instanceof RosterStatusFailure)) throw error;
    console.error(`hanten-findings-check: cannot read roster statuses or findings shape: ${error.message}`);
    return 2;
  }
  for (const finding of findings) console.log(`::error file=${findingsPath}::${finding}`);
  if (findings.length) return 1;
  console.log(`hanten-findings-check: every HR-cited finding in ${findingsPath} agrees with ${rosterPath}`);
  return 0;
}

const invoked = process.argv[1] !== undefined && resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (invoked) process.exit(main(process.argv.slice(2)));
