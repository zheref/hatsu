#!/usr/bin/env node
// HR-10 as amended by HR-337: findings on ruled HR rows are critical and
// fixed or deferred; findings on reading, reversed or superseded rows may be
// pushed back only with a reason. The status vocabulary and row parser belong
// to clause_id_guard.mts and are imported rather than repeated here.
import { readFileSync, realpathSync } from 'node:fs';
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
const SCHEMA_KEYS = new Set([
  '$schema', '$id', '$comment', '$defs', '$ref', 'type', 'required', 'properties', 'items',
  'enum', 'const', 'pattern', 'minimum', 'minLength', 'allOf', 'if', 'then',
]);
const SCHEMA_TYPES = new Set(['object', 'array', 'string', 'integer']);

function safe(value: unknown, fallback: string): string {
  if (typeof value !== 'string' || value.trim() === '') return fallback;
  return value.replace(/[\u0000-\u001f\u007f-\u009f\u202a-\u202e\u2066-\u2069]/g, '?').slice(0, 120);
}

function object(value: unknown): value is Readonly<Record<string, unknown>> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function own(value: Readonly<Record<string, unknown>>, key: string): boolean {
  return Object.hasOwn(value, key);
}

function schemaAt(root: Schema, reference: string): Schema {
  if (!reference.startsWith('#/')) throw new Error(`unsupported findings-schema reference ${reference}`);
  let current: unknown = root;
  for (const encoded of reference.slice(2).split('/')) {
    const key = encoded.replace(/~1/g, '/').replace(/~0/g, '~');
    if (!object(current) || !own(current, key)) throw new Error(`unresolved findings-schema reference ${reference}`);
    current = current[key];
  }
  if (!object(current)) throw new Error(`findings-schema reference ${reference} is not an object`);
  return current;
}

function scalar(value: unknown): boolean {
  return value === null || ['string', 'number', 'boolean'].includes(typeof value);
}

function assertSchemaNode(schema: Schema, root: Schema, path: string, visiting: Set<Schema>): void {
  if (visiting.has(schema)) throw new Error(`${path} forms a cyclic schema reference`);
  visiting.add(schema);
  try {
    for (const key of Object.keys(schema)) {
      if (!SCHEMA_KEYS.has(key)) throw new Error(`${path}.${key} is not supported by the findings-schema evaluator`);
    }
    for (const key of ['$schema', '$id', '$comment'] as const) {
      if (own(schema, key) && typeof schema[key] !== 'string') throw new Error(`${path}.${key} must be a string`);
    }
    if (own(schema, 'type') && (typeof schema.type !== 'string' || !SCHEMA_TYPES.has(schema.type))) {
      throw new Error(`${path}.type is not a supported schema type`);
    }
    if (own(schema, 'required')) {
      if (!Array.isArray(schema.required) || schema.required.some((key) => typeof key !== 'string')
        || new Set(schema.required).size !== schema.required.length) throw new Error(`${path}.required must be an array of unique strings`);
    }
    for (const key of ['$defs', 'properties'] as const) {
      if (!own(schema, key)) continue;
      if (!object(schema[key])) throw new Error(`${path}.${key} must be an object of schema nodes`);
      for (const [name, child] of Object.entries(schema[key])) {
        if (!object(child)) throw new Error(`${path}.${key}.${name} must be a schema object`);
        assertSchemaNode(child, root, `${path}.${key}.${name}`, visiting);
      }
    }
    if (own(schema, 'items')) {
      if (!object(schema.items)) throw new Error(`${path}.items must be a schema object`);
      assertSchemaNode(schema.items, root, `${path}.items`, visiting);
    }
    if (own(schema, 'enum') && (!Array.isArray(schema.enum) || schema.enum.length === 0 || !schema.enum.every(scalar))) {
      throw new Error(`${path}.enum must be a non-empty array of scalar values`);
    }
    if (own(schema, 'const') && !scalar(schema.const)) throw new Error(`${path}.const must be a scalar value`);
    if (own(schema, 'pattern')) {
      if (typeof schema.pattern !== 'string') throw new Error(`${path}.pattern must be a string`);
      try { new RegExp(schema.pattern); } catch { throw new Error(`${path}.pattern is not a valid regular expression`); }
    }
    if (own(schema, 'minimum') && (typeof schema.minimum !== 'number' || !Number.isFinite(schema.minimum))) {
      throw new Error(`${path}.minimum must be a finite number`);
    }
    if (own(schema, 'minLength') && (typeof schema.minLength !== 'number' || !Number.isInteger(schema.minLength) || schema.minLength < 0)) {
      throw new Error(`${path}.minLength must be a non-negative integer`);
    }
    if (own(schema, 'allOf')) {
      if (!Array.isArray(schema.allOf) || schema.allOf.length === 0) throw new Error(`${path}.allOf must be a non-empty array of schema nodes`);
      for (const [index, child] of schema.allOf.entries()) {
        if (!object(child)) throw new Error(`${path}.allOf[${index}] must be a schema object`);
        assertSchemaNode(child, root, `${path}.allOf[${index}]`, visiting);
      }
    }
    for (const key of ['if', 'then'] as const) {
      if (!own(schema, key)) continue;
      if (!object(schema[key])) throw new Error(`${path}.${key} must be a schema object`);
      assertSchemaNode(schema[key], root, `${path}.${key}`, visiting);
    }
    if (own(schema, 'if') !== own(schema, 'then')) throw new Error(`${path} must carry if and then together`);
    if (own(schema, '$ref')) {
      if (typeof schema.$ref !== 'string') throw new Error(`${path}.$ref must be a string`);
      const siblings = Object.keys(schema).filter((key) => !['$ref', '$comment'].includes(key));
      if (siblings.length) throw new Error(`${path}.$ref has unsupported sibling keywords: ${siblings.join(', ')}`);
      assertSchemaNode(schemaAt(root, schema.$ref), root, `${path}.$ref`, visiting);
    }
  } finally {
    visiting.delete(schema);
  }
}

export function validateFindingsSchema(schema: unknown): asserts schema is Schema {
  if (!object(schema)) throw new Error('the findings schema root must be an object');
  assertSchemaNode(schema, schema, '$schema', new Set());
}

function schemaErrors(value: unknown, schema: Schema, root: Schema, path: string): string[] {
  if (own(schema, '$ref') && typeof schema.$ref === 'string') return schemaErrors(value, schemaAt(root, schema.$ref), root, path);
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
  if (own(schema, 'const') && !Object.is(schema.const, value)) errors.push(`${path} must equal its schema constant`);
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
        if (typeof key === 'string' && !own(value, key)) errors.push(`${path}.${key} is required`);
      }
    }
    if (object(schema.properties)) {
      for (const [key, propertySchema] of Object.entries(schema.properties)) {
        if (own(value, key) && object(propertySchema)) errors.push(...schemaErrors(value[key], propertySchema, root, `${path}.${key}`));
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
  validateFindingsSchema(schema);
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

export function main(argv: string[], schemaOverride?: unknown): number {
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
    const candidate: unknown = schemaOverride === undefined ? JSON.parse(readFileSync(schemaPath, 'utf8')) : schemaOverride;
    validateFindingsSchema(candidate);
    schema = candidate;
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

// argv keeps the installed alias spelling; module URLs resolve to the real file.
let invoked = false;
try {
  invoked = process.argv[1] !== undefined && realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url));
  if (!invoked && import.meta.main === true) throw new Error('entry mismatch');
} catch {
  if (import.meta.main === true) {
    console.error('hanten-findings-check: cannot resolve CLI entry to this module');
    process.exitCode = 2;
  }
}
if (invoked) process.exitCode = main(process.argv.slice(2));
