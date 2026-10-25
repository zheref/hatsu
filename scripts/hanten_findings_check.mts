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
const HR_LIKE = /^\s*HR-/i;
type Schema = Readonly<Record<string, unknown>>;

function safe(value: unknown, fallback: string): string {
  if (typeof value !== 'string' || value.trim() === '') return fallback;
  return value.replace(/[\u0000-\u001f\u007f-\u009f\u202a-\u202e\u2066-\u2069]/g, '?').slice(0, 120);
}

function object(value: unknown): value is Readonly<Record<string, unknown>> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function schemaAt(root: Schema, reference: string): Schema {
  if (!reference.startsWith('#/')) throw new Error(`unsupported findings-schema reference ${reference}`);
  let current: unknown = root;
  for (const encoded of reference.slice(2).split('/')) {
    const key = encoded.replace(/~1/g, '/').replace(/~0/g, '~');
    if (!object(current) || !(key in current)) throw new Error(`unresolved findings-schema reference ${reference}`);
    current = current[key];
  }
  if (!object(current)) throw new Error(`findings-schema reference ${reference} is not an object`);
  return current;
}

function schemaErrors(value: unknown, schema: Schema, root: Schema, path: string): string[] {
  if (typeof schema.$ref === 'string') return schemaErrors(value, schemaAt(root, schema.$ref), root, path);
  const errors: string[] = [];
  const type = schema.type;
  const validType = type === undefined
    || (type === 'object' && object(value))
    || (type === 'array' && Array.isArray(value))
    || (type === 'string' && typeof value === 'string')
    || (type === 'integer' && typeof value === 'number' && Number.isInteger(value));
  if (!validType) return [`${path} must be ${String(type)}`];
  if (Array.isArray(schema.enum) && !schema.enum.some((candidate) => Object.is(candidate, value))) {
    errors.push(`${path} is not an admitted value`);
  }
  if ('const' in schema && !Object.is(schema.const, value)) errors.push(`${path} must equal its schema constant`);
  if (typeof value === 'string') {
    if (typeof schema.minLength === 'number' && value.length < schema.minLength) errors.push(`${path} is too short`);
    if (typeof schema.pattern === 'string' && !new RegExp(schema.pattern).test(value)) errors.push(`${path} has an invalid format`);
  }
  if (typeof value === 'number' && typeof schema.minimum === 'number' && value < schema.minimum) {
    errors.push(`${path} is below its minimum`);
  }
  if (object(value)) {
    if (Array.isArray(schema.required)) {
      for (const key of schema.required) {
        if (typeof key === 'string' && !(key in value)) errors.push(`${path}.${key} is required`);
      }
    }
    if (object(schema.properties)) {
      for (const [key, propertySchema] of Object.entries(schema.properties)) {
        if (key in value && object(propertySchema)) errors.push(...schemaErrors(value[key], propertySchema, root, `${path}.${key}`));
      }
    }
  }
  if (Array.isArray(value) && object(schema.items)) {
    for (const [index, item] of value.entries()) errors.push(...schemaErrors(item, schema.items, root, `${path}[${index}]`));
  }
  if (Array.isArray(schema.allOf)) {
    for (const member of schema.allOf) if (object(member)) errors.push(...schemaErrors(value, member, root, path));
  }
  if (object(schema.if) && schemaErrors(value, schema.if, root, path).length === 0 && object(schema.then)) {
    errors.push(...schemaErrors(value, schema.then, root, path));
  }
  return errors;
}

export function validateFindingsDocument(document: unknown, schema: Schema): readonly string[] {
  const errors = schemaErrors(document, schema, schema, '$');
  if (!object(document) || !Array.isArray(document.findings)) return errors;
  for (const [index, raw] of document.findings.entries()) {
    if (!object(raw) || typeof raw.rule !== 'string') continue;
    if (HR_LIKE.test(raw.rule) && !HR.test(raw.rule)) errors.push(`$.findings[${index}].rule must use canonical HR-N form`);
  }
  return errors;
}

export function checkFindings(document: unknown, rosterContents: string, schema: Schema): readonly string[] {
  const errors = [...validateFindingsDocument(document, schema)];
  if (errors.length) return errors;
  if (!object(document) || !Array.isArray(document.findings)) {
    throw new Error('validated findings document lost its findings array');
  }
  const statuses = new Map(parseRosterStatuses(rosterContents).map((row) => [row.id, row]));
  for (const [index, raw] of document.findings.entries()) {
    const finding = raw as Finding;
    if (typeof finding.rule !== 'string') throw new Error('validated finding lost its string rule');
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

export function main(argv: string[]): number {
  if (argv.length < 1 || argv.length > 2) {
    console.error('hanten-findings-check: usage: hanten_findings_check.mts <findings.json> [<roster.md>]');
    return 2;
  }
  const findingsPath = argv[0] ?? '';
  const rosterPath = argv[1] ?? 'docs/ROSTER.md';
  const schemaPath = fileURLToPath(new URL('../contracts/hanten-findings.schema.json', import.meta.url));
  if (/[,\r\n]/.test(findingsPath)) {
    console.error('hanten-findings-check: refusing a findings path holding a comma or line break; an annotation cannot name it');
    return 2;
  }
  let document: unknown;
  let schema: Schema;
  let roster: string;
  try {
    document = JSON.parse(readFileSync(findingsPath, 'utf8'));
  } catch (error) {
    console.error(`hanten-findings-check: cannot read ${findingsPath} as JSON: ${(error as Error).message}`);
    return 2;
  }
  try {
    schema = JSON.parse(readFileSync(schemaPath, 'utf8')) as Schema;
  } catch (error) {
    console.error(`hanten-findings-check: cannot read findings schema ${schemaPath}: ${(error as Error).message}`);
    return 2;
  }
  let findings = validateFindingsDocument(document, schema);
  if (findings.length) {
    for (const finding of findings) console.log(`::error file=${findingsPath}::invalid findings record: ${finding}`);
    return 1;
  }
  try {
    roster = readFileSync(rosterPath, 'utf8');
  } catch (error) {
    console.error(`hanten-findings-check: cannot read roster ${rosterPath}: ${(error as Error).message}`);
    return 2;
  }
  try {
    findings = checkFindings(document, roster, schema);
  } catch (error) {
    if (!(error instanceof RosterStatusFailure)) throw error;
    console.error(`hanten-findings-check: cannot read roster statuses: ${error.message}`);
    return 2;
  }
  for (const finding of findings) console.log(`::error file=${findingsPath}::${finding}`);
  if (findings.length) return 1;
  console.log(`hanten-findings-check: every HR-cited finding in ${findingsPath} agrees with ${rosterPath}`);
  return 0;
}

const invoked = process.argv[1] !== undefined && resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (invoked) process.exit(main(process.argv.slice(2)));
