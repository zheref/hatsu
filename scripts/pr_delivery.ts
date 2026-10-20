#!/usr/bin/env node
/** HA#321 Delivery normalizer and ledger/body guard. Markdown remains Nen-rendered. */
import { spawnSync } from "node:child_process";
import {
  closeSync,
  existsSync,
  lstatSync,
  mkdirSync,
  openSync,
  readFileSync,
  realpathSync,
  renameSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import { basename, dirname, isAbsolute, join, relative, resolve as resolvePath, sep } from "node:path";

type JsonObject = Record<string, unknown>;
type DeliveryKind = "phase" | "usage" | "session";

interface Evidence {
  readonly kind: DeliveryKind;
  readonly index: number;
  readonly effort: string;
  readonly at: string;
  readonly phase: string | null;
  readonly surface: string | null;
  readonly model: string | null;
  readonly dial: string | null;
  readonly source: string | null;
  readonly session: SessionEvidence | null;
  readonly sessionAmbiguous: boolean;
}

interface SessionEvidence {
  readonly index: number;
  readonly effort: string;
  readonly recordedAt: string;
  readonly surface: string;
  readonly model: string | null;
  readonly dial: string | null;
  readonly title: string | null;
  readonly id: string | null;
  readonly source: string | null;
}

export interface DeliveryRow {
  readonly key: string;
  readonly role: string;
  readonly surface: string;
  readonly model: string;
  readonly dial: string;
  readonly session: string;
  readonly source: string;
}

export interface DeliveryDocument {
  readonly contract: "hatsu.pr-delivery/v1";
  readonly effort: string;
  readonly deliveryRows: readonly DeliveryRow[];
  readonly drive: string;
}

const CONTROL = /[\u0000-\u001F\u007F-\u009F]/g;
const BIDI = /[\u200B-\u200F\u202A-\u202E\u2066-\u2069\uFEFF]/g;
const PERSONA = /^[a-z][a-z0-9-]{0,63}$/;
const AUTHOR_PHASES = new Set(["author", "breath", "rasengan", "kokusen", "amaterasu", "launch", "report"]);
const LANDING_PHASES = new Set(["publish", "pr", "murasaki", "hanten", "kotoamatsukami", "byakugan", "shibari", "landing"]);
const READINESS_PHASES = new Set(["readiness", "en"]);

function clean(value: unknown): string {
  return String(value).replace(/\r\n?/g, "\n").replace(CONTROL, " ").replace(BIDI, "").replace(/\s+/g, " ").trim();
}
function human(stream: NodeJS.WriteStream, value: unknown): void {
  for (const line of String(value).replace(/\r\n?/g, "\n").split("\n")) stream.write(`${clean(line)}\n`);
}
function fail(message: string): never { throw new Error(message); }
function object(value: unknown, message: string): JsonObject {
  if (value === null || typeof value !== "object" || Array.isArray(value)) fail(message);
  return value as JsonObject;
}
function stringOrNull(value: unknown, where: string): string | null {
  if (value === null || value === undefined) return null;
  if (typeof value !== "string") fail(`${where} must be a string or null`);
  const safe = clean(value);
  return safe === "" ? null : safe;
}
function requiredString(value: unknown, where: string): string {
  const parsed = stringOrNull(value, where);
  if (parsed === null) fail(`${where} must be a nonempty string`);
  return parsed;
}
function array(value: unknown, where: string): unknown[] {
  if (!Array.isArray(value)) fail(`${where} must be an array`);
  return value;
}
function stat(path: string): ReturnType<typeof lstatSync> | null {
  try { return lstatSync(path); }
  catch (error) { if ((error as NodeJS.ErrnoException).code === "ENOENT") return null; throw error; }
}
function inside(root: string, candidate: string): boolean {
  const rel = relative(root, candidate);
  return rel === "" || (rel !== ".." && !rel.startsWith(`..${sep}`) && !isAbsolute(rel));
}
function noSymlinkPath(root: string, absolute: string, allowMissingFinal: boolean): void {
  if (!inside(root, absolute)) fail(`${absolute}: path escapes the repository`);
  const rel = relative(root, absolute);
  let cursor = root;
  const parts = rel === "" ? [] : rel.split(sep);
  for (let index = 0; index < parts.length; index++) {
    cursor = join(cursor, parts[index] as string);
    const info = stat(cursor);
    if (info === null && allowMissingFinal && index === parts.length - 1) return;
    if (info === null) fail(`${cursor}: path component is missing`);
    if (info.isSymbolicLink()) fail(`${cursor}: symlink paths are refused`);
  }
}
function repository(path: string): string {
  const absolute = resolvePath(path);
  const info = stat(absolute);
  if (info === null || !info.isDirectory() || info.isSymbolicLink()) fail(`${path}: --repo must name a real directory`);
  const root = realpathSync(absolute);
  const result = spawnSync("git", ["-C", root, "rev-parse", "--show-toplevel"], { encoding: "utf8" });
  if (result.error !== undefined || result.status !== 0 || realpathSync(result.stdout.trim()) !== root) fail(`${path}: --repo must name a git working-tree root`);
  return root;
}
function inputFile(root: string, path: string): string {
  if (!isAbsolute(path)) fail(`${path}: input paths must be absolute`);
  const requested = resolvePath(path);
  const requestedInfo = stat(requested);
  if (requestedInfo?.isSymbolicLink()) fail(`${path}: input symlinks are refused`);
  const absolute = join(realpathSync(dirname(requested)), basename(requested));
  const info = stat(absolute);
  if (info === null || !info.isFile()) fail(`${path}: input must be a regular file`);
  return absolute;
}
function outputFile(root: string, path: string): string {
  if (!isAbsolute(path)) fail(`${path}: output paths must be absolute`);
  const requested = resolvePath(path);
  const requestedInfo = stat(requested);
  if (requestedInfo?.isSymbolicLink()) fail(`${path}: output symlinks are refused`);
  const absolute = join(realpathSync(dirname(requested)), basename(requested));
  noSymlinkPath(root, dirname(absolute), false);
  noSymlinkPath(root, absolute, true);
  const info = stat(absolute);
  if (info !== null && !info.isFile()) fail(`${path}: output must be a regular file`);
  return absolute;
}
function readUtf8(path: string): string {
  try { return new TextDecoder("utf-8", { fatal: true }).decode(readFileSync(path)); }
  catch (error) { fail(`${path}: unreadable UTF-8 (${error instanceof Error ? error.message : String(error)})`); }
}
function loadJson(path: string): unknown {
  try { return JSON.parse(readUtf8(path)) as unknown; }
  catch (error) { fail(`${path}: unreadable JSON (${error instanceof Error ? error.message : String(error)})`); }
}
function writePrivate(path: string, value: unknown): void {
  mkdirSync(dirname(path), { recursive: true, mode: 0o700 });
  let temp = "";
  let descriptor: number | null = null;
  try {
    for (let attempt = 0; attempt < 100; attempt++) {
      temp = join(dirname(path), `.pr-delivery-${process.pid}-${Date.now()}-${attempt}`);
      try { descriptor = openSync(temp, "wx", 0o600); break; }
      catch (error) { if ((error as NodeJS.ErrnoException).code !== "EEXIST") throw error; }
    }
    if (descriptor === null) fail(`cannot allocate a private output beside ${path}`);
    writeFileSync(descriptor, `${JSON.stringify(value, null, 2)}\n`, "utf8");
    closeSync(descriptor); descriptor = null;
    renameSync(temp, path);
  } finally {
    if (descriptor !== null) closeSync(descriptor);
    if (temp !== "" && existsSync(temp)) unlinkSync(temp);
  }
}
function branch(root: string): string {
  const result = spawnSync("git", ["-C", root, "symbolic-ref", "--quiet", "--short", "HEAD"], { encoding: "utf8" });
  if (result.error !== undefined || result.status !== 0) fail("current branch is unread; Delivery never mixes ledgers by guessing an effort");
  return requiredString(result.stdout, "current branch");
}
function markdown(value: string): string {
  return clean(value)
    .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    .replace(/([\\|`*_\[\]])/g, "\\$1");
}
function models(root: string): JsonObject {
  const path = join(root, "nen/workflow.json");
  noSymlinkPath(root, path, false);
  const workflow = object(loadJson(path), "nen/workflow.json must be an object");
  return object(workflow.models, "nen/workflow.json models must be an object");
}
function modelSurface(surface: string): string { return surface === "claude-code" ? "claude" : surface; }
function surfaceAliases(config: JsonObject, surface: string): Set<string> {
  const key = modelSurface(surface);
  const row = object(config[key], `models.${key} must be an object`);
  const aliases = new Set<string>();
  for (const tier of ["frontier", "deep", "fast", "economy"]) {
    const value = stringOrNull(row[tier], `models.${key}.${tier}`);
    if (value !== null) aliases.add(value);
  }
  return aliases;
}
function sourceAlias(source: string | null, knownAliases: ReadonlySet<string>): string | null {
  if (source === null) return null;
  const match = /(?:^|; )registry alias ([A-Za-z0-9._-]+)(?:[ (;]|$)/.exec(source);
  if (match === null) return null;
  const alias = match[1] as string;
  return knownAliases.has(alias) ? alias : null;
}
function directSessionAlias(root: string, effort: string, surface: string): string | null {
  const path = join(root, ".nen/direct", `${encodeURIComponent(effort)}.json`);
  if (!existsSync(path)) return null;
  noSymlinkPath(root, path, false);
  const direct = object(loadJson(path), `${path}: direct record must be an object`);
  if (direct.session !== null && direct.session !== undefined) {
    const session = object(direct.session, `${path}: session must be an object or null`);
    const recordedSurface = stringOrNull(session.surface, `${path}: session.surface`);
    if (recordedSurface === null || recordedSurface === surface) return stringOrNull(session.model, `${path}: session.model`);
  }
  if (direct.mismatch === null || direct.mismatch === undefined) return null;
  const mismatch = object(direct.mismatch, `${path}: mismatch must be an object or null`);
  const compares = array(mismatch.compares, `${path}: mismatch.compares`);
  const surfaceRow = compares.map((value, index): JsonObject => object(value, `${path}: mismatch.compares[${index}]`)).find((row): boolean => row.field === "surface");
  const modelRow = compares.map((value, index): JsonObject => object(value, `${path}: mismatch.compares[${index}]`)).find((row): boolean => row.field === "model");
  if (stringOrNull(surfaceRow?.session, `${path}: surface compare session`) !== surface) return null;
  return stringOrNull(modelRow?.session, `${path}: model compare session`);
}

function roleFor(kind: DeliveryKind, phase: string | null, source: string | null): string {
  if (phase !== null) {
    if (AUTHOR_PHASES.has(phase)) return "author";
    if (LANDING_PHASES.has(phase)) return "landing";
    if (READINESS_PHASES.has(phase)) return "readiness";
    const delegate = /^delegate-author:([a-z][a-z0-9-]{0,63})$/.exec(phase);
    if (delegate !== null) return `delegate author · ${delegate[1]}`;
  }
  if (source !== null) {
    const reviewer = /^hanten § 4: ([a-z][a-z0-9-]{0,63}),/.exec(source);
    if (reviewer !== null && PERSONA.test(reviewer[1] as string)) return `reviewer · ${reviewer[1]}`;
    const delegate = /^delegate author(?:: | )([a-z][a-z0-9-]{0,63})(?:[,;]|$)/.exec(source);
    if (delegate !== null && PERSONA.test(delegate[1] as string)) return `delegate author · ${delegate[1]}`;
    if (/^(?:ren|build|spiritual-message)(?: §|:|$)/.test(source)) return "author";
    if (/^(?:mukai|shibari|landing)(?: §|:|$)/.test(source)) return "landing";
    if (/^(?:en|readiness)(?: §|:|$)/.test(source)) return "readiness";
  }
  return `unread — ${kind} records no supported role`;
}
function parseSessions(raw: unknown[], effort: string): SessionEvidence[] {
  return raw.flatMap((value, index): SessionEvidence[] => {
    const row = object(value, `sessions[${index}] must be an object`);
    if (requiredString(row.effort, `sessions[${index}].effort`) !== effort) return [];
    const title = stringOrNull(row.title, `sessions[${index}].title`);
    const id = stringOrNull(row.id, `sessions[${index}].id`);
    if (title === null && id === null) fail(`sessions[${index}] has neither title nor id`);
    return [{
      index, effort, recordedAt: requiredString(row.recordedAt, `sessions[${index}].recordedAt`),
      surface: requiredString(row.surface, `sessions[${index}].surface`),
      model: stringOrNull(row.model, `sessions[${index}].model`), dial: stringOrNull(row.dial, `sessions[${index}].dial`),
      title, id, source: stringOrNull(row.source, `sessions[${index}].source`),
    }];
  });
}
function matchingSessions(row: Evidence, sessions: readonly SessionEvidence[]): readonly SessionEvidence[] {
  if (row.surface === null) return [];
  return sessions.filter((entry): boolean => entry.effort === row.effort && entry.surface === row.surface && entry.model === row.model && entry.dial === row.dial);
}
function chooseSession(matches: readonly SessionEvidence[]): { session: SessionEvidence | null; ambiguous: boolean } {
  const identities = new Set(matches.map((entry): string => `${entry.title ?? ""}\u0000${entry.id ?? ""}`));
  return identities.size === 1 ? { session: matches[0] ?? null, ambiguous: false } : { session: null, ambiguous: identities.size > 1 };
}
function sessionCell(session: SessionEvidence | null, surface: string, ambiguous: boolean): string {
  if (ambiguous) return "unread — multiple matching sessions";
  if (session === null) return `unread — ${surface} exposes none`;
  if (session.title !== null && session.id !== null) return `${session.title} · ${session.id}`;
  return session.title ?? session.id ?? `unread — ${surface} exposes none`;
}
function rowSource(row: Evidence): string {
  const base = `${row.kind}[${row.index}] · ${row.at}`;
  return row.kind === "phase" && row.phase !== null ? `${base} · ${row.phase}` : base;
}
function deliveryRow(root: string, config: JsonObject, evidence: Evidence): DeliveryRow {
  const role = roleFor(evidence.kind, evidence.phase, evidence.source);
  const surface = evidence.surface ?? "unread — ledger records no surface";
  const knownAliases = evidence.surface === null ? new Set<string>() : surfaceAliases(config, evidence.surface);
  const directAlias = evidence.surface === null || role !== "author" ? null : directSessionAlias(root, evidence.effort, evidence.surface);
  const recordedAlias = evidence.model !== null && knownAliases.has(evidence.model) ? evidence.model : null;
  const alias = recordedAlias ?? sourceAlias(evidence.source, knownAliases) ?? sourceAlias(evidence.session?.source ?? null, knownAliases) ?? (role === "author" ? directAlias : null);
  const provenance = [evidence.source, evidence.session?.source].filter((value): value is string => value !== null).join("; ");
  const served = /(?:^|; )(?:model-kind=served(?:;|$)|exact served model from [^;]+(?:;|$))/.test(provenance);
  const exact = evidence.model !== null && recordedAlias === null && served ? evidence.model : null;
  const recorded = evidence.model !== null && recordedAlias === null && !served ? ` (recorded token: ${evidence.model}; classification unread)` : "";
  const model = `exact: ${exact ?? `unread${recorded}`} · alias: ${alias ?? "unread"}`;
  const key = `${evidence.kind}:${evidence.index}:${evidence.effort}:${evidence.at}`;
  return {
    key: markdown(key), role: markdown(role), surface: markdown(surface), model: markdown(model),
    dial: markdown(evidence.dial ?? "unread"), session: markdown(sessionCell(evidence.session, surface, evidence.sessionAmbiguous)), source: markdown(rowSource(evidence)),
  };
}

function head(root: string): string {
  const result = spawnSync("git", ["-C", root, "rev-parse", "HEAD"], { encoding: "utf8" });
  if (result.error !== undefined || result.status !== 0) fail("cannot read current HEAD for Delivery PR binding");
  return requiredString(result.stdout, "current HEAD");
}
function prReference(root: string, row: JsonObject): string | null {
  const notation = stringOrNull(row.notation, "PR notation");
  if (notation !== null) return notation;
  const url = stringOrNull(row.url, "PR url");
  if (url === null) return null;
  const parsed = spawnSync("nen", ["ref", "parse", url, "--repo", root, "--json"], { encoding: "utf8" });
  if (parsed.error !== undefined || parsed.status !== 0) fail("nen ref parse could not bind the report PR to a declared repository code");
  const document = object(JSON.parse(parsed.stdout) as unknown, "nen ref parse returned no JSON object");
  const code = requiredString(document.code, "nen ref parse code");
  const number = row.number;
  if (!Number.isInteger(number) || typeof number !== "number" || number < 1) fail("report PR number must be a positive integer");
  const formatted = spawnSync("nen", ["ref", "format", "--code", code, "--kind", "PR", "--number", String(number), "--no-glyphs", "--repo", root], { encoding: "utf8" });
  if (formatted.error !== undefined || formatted.status !== 0) fail("nen ref format could not render the report PR reference");
  return requiredString(formatted.stdout, "nen ref format output");
}

export function normalize(root: string, raw: unknown, gateForecast: "G2" | "G4" | null = null): DeliveryDocument {
  const report = object(raw, "report data must be an object");
  if (report.contract !== "nen.report.data/v0.1") fail("report data must carry nen.report.data/v0.1");
  const effort = branch(root);
  const reportedBranch = stringOrNull(report.branch, "report data branch");
  if (reportedBranch !== null && reportedBranch !== effort) fail(`report data branch ${JSON.stringify(reportedBranch)} is not current branch ${JSON.stringify(effort)}`);
  const config = models(root);
  const sessions = parseSessions(array(report.sessions, "report data sessions"), effort);
  const usedSessions = new Set<number>();
  const evidence: Evidence[] = [];
  array(report.phases, "report data phases").forEach((value, index): void => {
    const row = object(value, `phases[${index}] must be an object`);
    if (requiredString(row.effort, `phases[${index}].effort`) !== effort) return;
    const base: Evidence = {
      kind: "phase", index, effort, at: requiredString(row.startedAt, `phases[${index}].startedAt`),
      phase: requiredString(row.phase, `phases[${index}].phase`), surface: stringOrNull(row.surface, `phases[${index}].surface`),
      model: stringOrNull(row.model, `phases[${index}].model`), dial: stringOrNull(row.dial, `phases[${index}].dial`), source: stringOrNull(row.note, `phases[${index}].note`), session: null, sessionAmbiguous: false,
    };
    const matches = matchingSessions(base, sessions); const { session, ambiguous } = chooseSession(matches);
    if (session !== null) usedSessions.add(session.index);
    evidence.push({ ...base, session, sessionAmbiguous: ambiguous });
  });
  array(report.usage, "report data usage").forEach((value, index): void => {
    const row = object(value, `usage[${index}] must be an object`);
    if (requiredString(row.effort, `usage[${index}].effort`) !== effort) return;
    const base: Evidence = {
      kind: "usage", index, effort, at: requiredString(row.recordedAt, `usage[${index}].recordedAt`), phase: null,
      surface: requiredString(row.surface, `usage[${index}].surface`), model: stringOrNull(row.model, `usage[${index}].model`),
      dial: stringOrNull(row.dial, `usage[${index}].dial`), source: stringOrNull(row.source, `usage[${index}].source`), session: null, sessionAmbiguous: false,
    };
    const matches = matchingSessions(base, sessions); const { session, ambiguous } = chooseSession(matches);
    if (session !== null) usedSessions.add(session.index);
    evidence.push({ ...base, session, sessionAmbiguous: ambiguous });
  });
  for (const session of sessions) if (!usedSessions.has(session.index)) {
    evidence.push({
      kind: "session", index: session.index, effort, at: session.recordedAt, phase: null,
      surface: session.surface, model: session.model, dial: session.dial, source: session.source, session, sessionAmbiguous: false,
    });
  }
  if (evidence.length === 0) fail(`report data has no phase, usage or session rows for exact current branch ${JSON.stringify(effort)}`);
  evidence.sort((left, right): number => left.at.localeCompare(right.at) || left.kind.localeCompare(right.kind) || left.index - right.index);
  const objects = Array.isArray(report.objects) ? report.objects : [];
  const pullRequests = objects.flatMap((value): JsonObject[] => {
    if (value === null || typeof value !== "object" || Array.isArray(value)) return [];
    const row = value as JsonObject;
    return row.kind === "pr" ? [row] : [];
  });
  if (pullRequests.length > 1) fail("report data carries more than one PR; Delivery requires the exact current-branch PR");
  if (pullRequests.length === 1) {
    const reportedHead = requiredString(pullRequests[0]?.head, "report PR head");
    if (reportedHead !== head(root)) fail(`report PR head ${reportedHead} is not current HEAD`);
  }
  const reference = pullRequests.length === 1 ? prReference(root, pullRequests[0] as JsonObject) : null;
  const gate = gateForecast ?? "unread — no nen gate derive forecast supplied";
  const next = reference === null ? "unread — report data carries no unique PR" : `hatsu:en on ${reference}`;
  return {
    contract: "hatsu.pr-delivery/v1", effort,
    deliveryRows: evidence.map((row): DeliveryRow => deliveryRow(root, config, row)),
    drive: markdown(`gate forecast: ${gate}; next: ${next}; readiness is nen pr ready's verdict`),
  };
}

function deliveryBlock(markdownBody: string): string {
  const normalized = markdownBody.replace(/^\uFEFF/, "").replace(/\r\n?/g, "\n");
  const lines = normalized.split("\n");
  const first = lines.findIndex((line): boolean => line.trim() !== "");
  if (first < 0 || !/^ {0,3}##[ \t]+(?:[^A-Za-z0-9#\r\n]+[ \t]*)?Delivery[ \t]*$/.test(lines[first] as string)) fail("body must open with the Delivery heading");
  let end = lines.length;
  for (let index = first + 1; index < lines.length; index++) if (/^ {0,3}#{1,2}(?:[ \t]+|$)/.test(lines[index] as string)) { end = index; break; }
  return lines.slice(first, end).join("\n").trimEnd();
}
function renderedRows(block: string): string[] {
  return block.split("\n").filter((line): boolean => /^\| .* \|$/.test(line) && !/^\| Role \|/.test(line) && !/^\|---/.test(line));
}
function driveLines(block: string): string[] {
  return block.split("\n").filter((line): boolean => line.startsWith("*Drive:*"));
}
function shapeFindings(block: string): string[] {
  const lines = block.split("\n");
  const findings: string[] = [];
  if (lines[0] !== "## 📬 Delivery") findings.push("Delivery heading must use the canonical rendered form");
  if (lines[2] !== "| Role | Surface | Model | Dial | Session | Source |" || lines[3] !== "|---|---|---|---|---|---|") findings.push("Delivery table header differs from the canonical six-column form");
  const driveIndexes = lines.flatMap((line, index): number[] => line.startsWith("*Drive:*") ? [index] : []);
  if (driveIndexes.length !== 1) findings.push("Delivery must carry exactly one Drive line");
  else {
    const at = driveIndexes[0] as number;
    if (!/^\*Drive:\* gate forecast: (?:G2|G4|unread — [^;]+); next: (?:hatsu:en on [A-Z]{2,3}-PR-#\d+|unread — [^;]+); readiness is nen pr ready's verdict$/.test(lines[at] as string)) findings.push("Drive must name a Nen-derived gate or explicit unread, an exact PR ref or explicit unread, and nen pr ready's verdict");
    if (lines.slice(at + 1).some((line): boolean => line.trim() !== "")) findings.push("Delivery carries content after Drive");
    if (lines.slice(4, at).some((line): boolean => line.trim() !== "" && !/^\| .* \|$/.test(line))) findings.push("Delivery carries non-row content inside its table");
  }
  return findings;
}
export function compareBody(body: string, expected: string): string[] {
  const findings: string[] = [];
  let actualBlock: string;
  let expectedBlock: string;
  try { actualBlock = deliveryBlock(body); }
  catch (error) { return [error instanceof Error ? error.message : String(error)]; }
  try { expectedBlock = deliveryBlock(expected); }
  catch (error) { return [`rendered expectation is invalid: ${error instanceof Error ? error.message : String(error)}`]; }
  findings.push(...shapeFindings(actualBlock));
  const expectedDrive = driveLines(expectedBlock);
  if (expectedDrive.length !== 1) findings.push("rendered expectation is invalid: expected exactly one Drive line");
  else if (driveLines(actualBlock)[0] !== expectedDrive[0]) findings.push(`Drive differs from rendered current-effort expectation: expected ${expectedDrive[0]}`);
  const actualRows = renderedRows(actualBlock);
  const expectedRows = renderedRows(expectedBlock);
  const remaining = [...actualRows];
  for (const row of expectedRows) {
    const index = remaining.indexOf(row);
    if (index < 0) findings.push(`missing ledger row: ${row}`);
    else remaining.splice(index, 1);
  }
  for (const row of remaining) findings.push(`extra or duplicate body row: ${row}`);
  return findings.map(clean);
}

interface Arguments { readonly command: "normalize" | "check"; readonly repo: string; readonly data: string | null; readonly out: string | null; readonly body: string | null; readonly expected: string | null; readonly gateForecast: "G2" | "G4" | null }
function argumentsOf(argv: readonly string[]): Arguments {
  const command = argv[0];
  if (command !== "normalize" && command !== "check") fail("usage: pr_delivery.ts normalize --data <abs> --out <abs> --repo <path> [--gate-forecast G2|G4] | check --body <abs> --expected <abs> --repo <path>");
  let repo: string | null = null, data: string | null = null, out: string | null = null, body: string | null = null, expected: string | null = null, gateForecast: "G2" | "G4" | null = null;
  for (let index = 1; index < argv.length; index++) {
    const flag = argv[index] as string;
    if (!["--repo", "--data", "--out", "--body", "--expected", "--gate-forecast"].includes(flag) || argv[index + 1] === undefined) fail(`unknown or incomplete argument ${JSON.stringify(flag)}`);
    const value = argv[++index] as string;
    if (flag === "--repo") repo = value; else if (flag === "--data") data = value; else if (flag === "--out") out = value; else if (flag === "--body") body = value; else if (flag === "--expected") expected = value;
    else if (value === "G2" || value === "G4") gateForecast = value; else fail("--gate-forecast must be G2 or G4");
  }
  if (repo === null) fail("--repo is required");
  if (command === "normalize" && (data === null || out === null || body !== null || expected !== null)) fail("normalize requires --data, --out and --repo, with optional --gate-forecast");
  if (command === "check" && (body === null || expected === null || data !== null || out !== null || gateForecast !== null)) fail("check requires only --body, --expected and --repo");
  return { command, repo, data, out, body, expected, gateForecast };
}

function main(): void {
  try {
    const args = argumentsOf(process.argv.slice(2));
    const root = repository(args.repo);
    if (args.command === "normalize") {
      const data = inputFile(root, args.data as string);
      const output = outputFile(root, args.out as string);
      const document = normalize(root, loadJson(data), args.gateForecast);
      writePrivate(output, document);
      human(process.stdout, `pr-delivery normalized: ${document.deliveryRows.length} row(s) for ${document.effort}`);
      return;
    }
    const body = inputFile(root, args.body as string);
    const expected = inputFile(root, args.expected as string);
    const findings = compareBody(readUtf8(body), readUtf8(expected));
    for (const finding of findings) human(process.stdout, finding);
    if (findings.length > 0) process.exitCode = 1;
    else human(process.stdout, "pr-delivery guard: every current-effort ledger row is present exactly once");
  } catch (error) {
    human(process.stderr, `pr_delivery.ts: ${error instanceof Error ? error.message : String(error)}`);
    process.exitCode = 2;
  }
}

if (process.argv[1] !== undefined && resolvePath(process.argv[1]) === resolvePath(import.meta.filename)) main();
