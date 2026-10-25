#!/usr/bin/env node
/** HA#351 catalogue resolver/checker, executed by Node 24's native type stripper. */
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
import { dirname, isAbsolute, join, relative, resolve as resolvePath, sep } from "node:path";
import { fileURLToPath } from "node:url";

export type RepositoryKind = "product" | "library" | "process" | "unknown";
export interface SectionRow {
  readonly id: string;
  readonly glyph: string;
  readonly title: string | Readonly<Record<RepositoryKind, string>>;
  readonly level: 1 | 2;
  readonly template: string;
  readonly $comment: string;
  readonly when?: "evidence" | "economics" | "policy-hit" | "spec" | "decisions";
  readonly reserved?: boolean;
  /**
   * A whole-body requirement another plane owns, quoted whole (the spec row's `spec-rows`, nen's
   * `src/spec/coverage.ts`): emitted after the heading's own row, linked to it by `heading`.
   */
  readonly rows?: { readonly name: string; readonly pattern: string };
  /** HR-11: the heading must carry content; derives a second, whole-body requirement `<id>-content`. */
  readonly content?: boolean;
}
export interface Catalogue {
  readonly contract: "hatsu.pr-sections/v1";
  readonly max: number;
  readonly proseBudget: number;
  readonly preamble: readonly SectionRow[];
  readonly sections: readonly SectionRow[];
  readonly footer: readonly SectionRow[];
  readonly families: Readonly<Record<string, readonly string[]>>;
  readonly precedence: readonly string[];
  readonly variants: Readonly<Record<string, readonly string[]>>;
}
/**
 * `content: true` marks a whole-body pattern (the heading followed by content); `heading` names the
 * heading row a content row belongs to when its name is not `<heading>-content`. nen ignores both keys.
 */
export interface Requirement { readonly name: string; readonly pattern: string; readonly content?: true; readonly heading?: string }
export interface Resolution {
  readonly cell: string;
  readonly max: number;
  readonly preamble: readonly string[];
  readonly ids: readonly string[];
  readonly footer: readonly string[];
  readonly requirements: readonly Requirement[];
}

type JsonObject = Record<string, unknown>;
const ROOT = resolvePath(dirname(fileURLToPath(import.meta.url)), "..");
const KINDS: readonly RepositoryKind[] = ["product", "library", "process", "unknown"];
const FACTS = new Set(["evidence", "economics", "policy-hit", "spec", "decisions"]);
/** Run facts a caller may pass: `idle` is an input only, and implies `decisions` (HA#474). */
const INPUT_FACTS = new Set([...FACTS, "idle"]);
const CONTROL = /[\u0000-\u001F\u007F-\u009F]/g;
const INVISIBLE = /[\u200B-\u200F\u202A-\u202E\u2066-\u2069\uFEFF]/g;

function plainLine(value: unknown): string {
  return String(value).replace(CONTROL, "").replace(INVISIBLE, "");
}
function human(stream: NodeJS.WriteStream, value: unknown): void {
  const rows = String(value).replace(/\r\n?/g, "\n").split("\n");
  if (rows.at(-1) === "") rows.pop();
  for (const row of rows) stream.write(`${plainLine(row)}\n`);
}
function out(value: unknown): void { human(process.stdout, value); }
function err(value: unknown): void { human(process.stderr, value); }
function object(value: unknown, message: string): JsonObject {
  if (value === null || typeof value !== "object" || Array.isArray(value)) throw new Error(message);
  return value as JsonObject;
}
function load(path: string): unknown {
  let text: string;
  try {
    text = readFileSync(path, "utf8");
  } catch (error) {
    // HA#474: a filesystem error keeps its errno code; it carries no file bytes.
    const code = (error as NodeJS.ErrnoException).code ?? "unknown";
    throw new Error(`${path}: ${code === "ENOENT" ? "missing" : "unreadable"} (${code})`);
  }
  try {
    return JSON.parse(text) as unknown;
  } catch (error) {
    // SEC-12 (HA#474): never echo the parser's excerpt of the file's bytes; keep the class and position only.
    const message = error instanceof Error ? error.message : "";
    const position = /position (\d+)/.exec(message)?.[1];
    const kind = error instanceof Error ? error.name : "Error";
    throw new Error(`${path}: unreadable JSON (${kind}${position === undefined ? "" : ` at position ${position}`})`);
  }
}
function stat(path: string): ReturnType<typeof lstatSync> | null {
  try { return lstatSync(path); }
  catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") return null;
    throw error;
  }
}
function inside(root: string, candidate: string): boolean {
  const rel = relative(root, candidate);
  return rel === "" || (!rel.startsWith(`..${sep}`) && rel !== ".." && !isAbsolute(rel));
}
/** Refuse every symlink component, including a dangling final link, before testing existence. */
function declaredPath(root: string, rel: string, kind: "file" | "directory", optional = false): string | null {
  let cursor = root;
  for (const part of rel.split(/[\\/]/).filter(Boolean)) {
    cursor = join(cursor, part);
    const info = stat(cursor);
    if (info === null) {
      if (optional) return null;
      throw new Error(`${rel}: missing ${kind}`);
    }
    if (info.isSymbolicLink()) throw new Error(`${rel}: declaration escapes checkout or is a symlink`);
  }
  const info = stat(cursor);
  if (info === null) {
    if (optional) return null;
    throw new Error(`${rel}: missing ${kind}`);
  }
  if ((kind === "file" && !info.isFile()) || (kind === "directory" && !info.isDirectory())) throw new Error(`${rel}: missing ${kind}`);
  const realRoot = realpathSync(root);
  const realCandidate = realpathSync(cursor);
  if (!inside(realRoot, realCandidate)) throw new Error(`${rel}: declaration escapes checkout or is a symlink`);
  return cursor;
}
function strings(value: unknown, message: string): string[] {
  if (!Array.isArray(value) || value.some((item): boolean => typeof item !== "string" || item.length === 0)) throw new Error(message);
  return value as string[];
}
function sameSet(left: readonly string[], right: readonly string[]): boolean {
  return left.length === right.length && new Set(left).size === left.length && left.every((value): boolean => right.includes(value));
}
function validateCell(cat: Catalogue, cell: string, raw: unknown, maximum: number): string[] {
  const items = strings(raw, `${cell}: unknown or missing reader id`);
  const known = new Set(cat.sections.map((row): string => row.id));
  if (items.some((id): boolean => !known.has(id))) throw new Error(`${cell}: unknown or missing reader id`);
  if (new Set(items).size !== items.length) throw new Error(`${cell}: repeated section id`);
  if (items.length > maximum) throw new Error(`${cell}: ${items.length} readers exceed max ${maximum}`);
  return items;
}

/** Load and fully validate Hatsu's PR-section catalogue and job taxonomy. */
export function catalogue(root = ROOT): Catalogue {
  const absoluteRoot = resolvePath(root);
  declaredPath(absoluteRoot, "contracts", "directory");
  const cataloguePath = declaredPath(absoluteRoot, "contracts/pr-sections.json", "file") as string;
  const taxonomyPath = declaredPath(absoluteRoot, "contracts/classify.taxonomy.json", "file") as string;
  const raw = object(load(cataloguePath), "catalogue must be an object");
  const taxonomy = object(load(taxonomyPath), "taxonomy must be an object");
  if (raw.contract !== "hatsu.pr-sections/v1") throw new Error("expected hatsu.pr-sections/v1");
  if (!Array.isArray(raw.preamble) || !Array.isArray(raw.sections) || !Array.isArray(raw.footer)) throw new Error("preamble, sections and footer must be arrays");
  const parseRow = (value: unknown, place: "preamble" | "section" | "footer"): SectionRow => {
    const row = object(value, "every section must be an object");
    const id = row.id;
    if (typeof id !== "string" || id.length === 0) throw new Error("section ids must be nonempty and unique");
    if (!Number.isInteger(row.level) || (row.level !== 1 && row.level !== 2) || typeof row.glyph !== "string"
      || (row.glyph.length === 0 && (place !== "footer" || id !== "hanten"))) throw new Error(`${id}: invalid level/glyph`);
    const title = row.title;
    if (typeof title === "string") {
      if (title.length === 0) throw new Error(`${id}: missing title`);
    } else {
      const titles = object(title, `${id}: missing title`);
      if (!sameSet(Object.keys(titles), [...KINDS]) || Object.values(titles).some((entry): boolean => typeof entry !== "string" || entry.length === 0)) throw new Error(`${id}: kind titles must cover every repository kind`);
    }
    if (row.level !== (id === "changes" ? 1 : 2)) throw new Error(`${id}: changes alone is H1; every other block is H2`);
    if (row.when !== undefined && (typeof row.when !== "string" || !FACTS.has(row.when))) throw new Error(`${id}: unknown run fact`);
    if (place === "footer") {
      if (typeof row.reserved !== "boolean") throw new Error(`${id}: footer reserved must be boolean`);
    } else if (row.reserved !== undefined) {
      throw new Error(`${id}: reader sections cannot be reserved`);
    }
    if (row.content !== undefined && row.content !== true) throw new Error(`${id}: content must be true or absent`);
    if (row.rows !== undefined) {
      const rows = object(row.rows, `${id}: rows must be a name/pattern object`);
      if (typeof rows.name !== "string" || rows.name.length === 0 || typeof rows.pattern !== "string" || rows.pattern.length === 0) throw new Error(`${id}: rows must be a name/pattern object`);
      try { new RegExp(rows.pattern, "im"); }
      catch (error) { throw new Error(`${id}: rows pattern is invalid: ${error instanceof Error ? error.message : String(error)}`); }
      if (row.when === undefined) throw new Error(`${id}: a rows requirement belongs to a conditional section`);
    }
    if (typeof row.template !== "string" || row.template.length === 0) throw new Error(`${id}: missing template`);
    declaredPath(absoluteRoot, row.template, "file");
    if (typeof row.$comment !== "string" || row.$comment.length === 0) throw new Error(`${id}: missing section description`);
    return row as unknown as SectionRow;
  };
  const preamble = raw.preamble.map((row): SectionRow => parseRow(row, "preamble"));
  const sections = raw.sections.map((row): SectionRow => parseRow(row, "section"));
  const footer = raw.footer.map((row): SectionRow => parseRow(row, "footer"));
  const rows = [...preamble, ...sections, ...footer];
  const ids = rows.map((row): string => row.id);
  if (rows.length === 0 || new Set(ids).size !== ids.length) throw new Error("section ids must be nonempty and unique");
  if (!Number.isInteger(raw.max) || typeof raw.max !== "number" || raw.max < 1 || raw.max > 7) throw new Error("catalogue max must be an integer from 1 through 7");
  if (!Number.isInteger(raw.proseBudget) || typeof raw.proseBudget !== "number" || raw.proseBudget < 1) throw new Error("proseBudget must be positive");
  const familiesRaw = object(raw.families, "families must be an object");
  const families = Object.fromEntries(Object.entries(familiesRaw).map(([family, jobs]): [string, string[]] => {
    const parsed = strings(jobs, `${family}: jobs must be nonempty strings`);
    if (new Set(parsed).size !== parsed.length) throw new Error(`${family}: repeated job`);
    return [family, parsed];
  }));
  const precedence = strings(raw.precedence, "precedence must list every family exactly once");
  if (!sameSet(precedence, Object.keys(families))) throw new Error("precedence must list every family exactly once");
  const jobs = Object.values(families).flat();
  const axes = object(taxonomy.axes, "taxonomy axes must be an object");
  const jobAxis = object(axes.job, "taxonomy job axis must be an object");
  if (!Array.isArray(jobAxis.keys)) throw new Error("taxonomy job keys must be an array");
  const known = jobAxis.keys.map((value): string => {
    const row = object(value, "taxonomy job must be an object");
    if (typeof row.key !== "string" || row.key.length === 0) throw new Error("taxonomy job key must be nonempty");
    return row.key;
  });
  if (jobs.length !== 39 || new Set(jobs).size !== jobs.length || !sameSet(jobs, known)) {
    const missing = known.filter((job): boolean => !jobs.includes(job)).sort();
    const unknown = jobs.filter((job): boolean => !known.includes(job)).sort();
    throw new Error(`every one of the 39 taxonomy jobs must belong to exactly one family; missing ${JSON.stringify(missing)}; unknown ${JSON.stringify(unknown)}`);
  }
  const variantsRaw = object(raw.variants, "variants must declare exactly every kind/family cell");
  const cells = KINDS.flatMap((kind): string[] => Object.keys(families).map((family): string => `${kind}.${family}`));
  if (cells.length !== 24 || !sameSet(Object.keys(variantsRaw), cells)) throw new Error("variants must declare exactly every one of the 24 kind/family cells");
  const provisional = { ...raw, preamble, sections, footer, families, precedence, variants: variantsRaw, max: raw.max, proseBudget: raw.proseBudget } as unknown as Catalogue;
  const required = new Set(["changes", "why", "verify"]);
  const variants: Record<string, string[]> = {};
  for (const kind of KINDS) for (const family of Object.keys(families)) {
    const cell = `${kind}.${family}`;
    const items = validateCell(provisional, cell, variantsRaw[cell], raw.max);
    const owed = new Set([...required, ...(family === "release" ? [] : ["improves"])]);
    if (items[0] !== "changes" || [...owed].some((id): boolean => !items.includes(id))) throw new Error(`${cell}: changes first and all always-required readers are owed`);
    variants[cell] = items;
  }
  if (preamble.length !== 1 || preamble[0]?.id !== "delivery") throw new Error("delivery must be the sole preamble block");
  if (footer.length === 0 || footer.at(-1)?.id !== "attribution") throw new Error("attribution must be the final footer");
  return { contract: "hatsu.pr-sections/v1", max: raw.max, proseBudget: raw.proseBudget, preamble, sections, footer, families, precedence, variants };
}

export function defaults(cat: Catalogue): { max: number; variants: Catalogue["variants"] } {
  return { max: cat.max, variants: cat.variants };
}
export function options(cat: Catalogue): Record<string, string> {
  return Object.fromEntries([...cat.preamble, ...cat.sections, ...cat.footer].map((row): [string, string] => [row.id, row.$comment]));
}
export function fold(cat: Catalogue, jobs: readonly string[]): string {
  if (jobs.length === 0) return "build";
  const counts = Object.fromEntries(cat.precedence.map((family): [string, number] => [family, 0]));
  for (const job of new Set(jobs)) {
    const matches = Object.entries(cat.families).filter(([, entries]): boolean => entries.includes(job)).map(([family]): string => family);
    if (matches.length !== 1) throw new Error(`job ${JSON.stringify(job)} has no unique declared family`);
    const family = matches[0] as string;
    counts[family] = (counts[family] ?? 0) + 1;
  }
  return cat.precedence.reduce((winner, family): string => (counts[family] as number) > (counts[winner] as number) ? family : winner);
}
function escapePythonRegex(value: string): string { return value.replace(/[^A-Za-z0-9_]/g, "\\$&"); }
export function pattern(row: SectionRow, kind: RepositoryKind): Requirement {
  const title = typeof row.title === "string" ? row.title : row.title[kind];
  const glyph = row.glyph.length === 0 ? "" : "(?:[^A-Za-z0-9#\\r\\n]+[ \\t]*)?";
  return { name: row.id, pattern: `^ {0,3}${"#".repeat(row.level)}[ \\t]+${glyph}${escapePythonRegex(title)}[ \\t]*$` };
}
/**
 * HR-11: a row declaring `content` also requires its heading to be followed, past blank lines and
 * HTML comments, by something that is not the next heading -- so an empty heading fails in both
 * nen pr body-check (whole body) and check() below. Python- and JS-compatible.
 */
export function contentPattern(row: SectionRow, kind: RepositoryKind): Requirement {
  return { name: `${row.id}-content`, pattern: `${pattern(row, kind).pattern}(?=(?:\\s|<!--[\\s\\S]*?-->)*(?!#{1,6}[ \\t]|<!--)\\S)`, content: true };
}
/** The requirement rows for a resolved section list, in order: each heading, then its content row. */
export function requirementsFor(rows: readonly SectionRow[], kind: RepositoryKind): Requirement[] {
  return rows.flatMap((row): Requirement[] => [
    pattern(row, kind),
    ...(row.content === true ? [contentPattern(row, kind)] : []),
    ...(row.rows === undefined ? [] : [{ name: row.rows.name, pattern: row.rows.pattern, content: true as const, heading: row.id }]),
  ]);
}

function optionalWorkflow(repo: string): JsonObject {
  const path = declaredPath(repo, "nen/workflow.json", "file", true);
  if (path === null) return {};
  return object(load(path), "workflow must be an object");
}
const DECISION_ROW = /^[a-z0-9-]+$/;
const RESOLUTIONS = new Set(["default", "hold", "refuse"]);
/**
 * HA#474: whether a nen.run manifest shows decisions taken for the maintainer. One-directional: a
 * non-empty `idleAnswers` (row id → default|hold|refuse, validated as nen 0.26 validates it) means the
 * run pre-answered rows, so it took decisions. The manifest records only the pre-answers a run was
 * launched with (nen never updates it, and it is null on an attended run), so a null or empty map
 * cannot show that no decision was taken: beside a positive flag (`--decisions`, `--idle`) it adds
 * nothing and the flag wins; alone it refuses. A malformed manifest refuses whatever else is passed.
 */
export function decisionsTaken(manifest: unknown, positive = false): boolean {
  const record = object(manifest, "--decisions-from must be a nen.run manifest object");
  if (!Object.hasOwn(record, "idleAnswers")) throw new Error("--decisions-from manifest carries no idleAnswers");
  const answers = record.idleAnswers === null ? {} : object(record.idleAnswers, "idleAnswers must be null or an object");
  for (const [row, resolution] of Object.entries(answers)) {
    if (!DECISION_ROW.test(row)) throw new Error("idleAnswers row ids must be [a-z0-9-]+");
    if (typeof resolution !== "string" || !RESOLUTIONS.has(resolution)) throw new Error("idleAnswers values must be default, hold or refuse");
  }
  if (Object.keys(answers).length > 0) return true;
  if (positive) return false;
  throw new Error("a nen.run manifest records only idle pre-answers and cannot show that no decision was taken: omit --decisions-from; pass --decisions if a decision was taken");
}
export function resolve(cat: Catalogue, repo: string, kind: RepositoryKind, jobs: readonly string[], facts: ReadonlySet<string>): Resolution {
  const family = fold(cat, jobs);
  if (!KINDS.includes(kind)) throw new Error(`unknown repository kind ${JSON.stringify(kind)}`);
  for (const fact of facts) if (!INPUT_FACTS.has(fact)) throw new Error(`unknown run fact ${JSON.stringify(fact)}`);
  // HA#474: an idle run always pre-answers its ask-once rows (WORKFLOW § Idle batches rule 8), so it took decisions.
  if (facts.has("idle") && !facts.has("decisions")) facts = new Set([...facts, "decisions"]);
  const workflow = optionalWorkflow(resolvePath(repo));
  const pr = workflow.pr === undefined ? {} : object(workflow.pr, "workflow and pr must be objects");
  const config = pr.sections === undefined ? {} : object(pr.sections, "pr.sections must be an object");
  const maximum = config.max === undefined ? cat.max : config.max;
  if (!Number.isInteger(maximum) || typeof maximum !== "number" || maximum < 1 || maximum > cat.max) throw new Error(`pr.sections.max must be from 1 through ${cat.max}`);
  const overrides = config.variants === undefined ? {} : object(config.variants, "pr.sections.variants must be a cell map");
  const parsedOverrides: Record<string, string[]> = {};
  for (const [cell, value] of Object.entries(overrides)) {
    if (!Object.hasOwn(cat.variants, cell)) throw new Error(`unknown override cell ${JSON.stringify(cell)}`);
    const items = validateCell(cat, cell, value, maximum);
    const release = cell.endsWith(".release");
    if (items[0] !== "changes" || ["why", "verify", ...(release ? [] : ["improves"])].some((id): boolean => !items.includes(id))) throw new Error(`${cell}: overrides retain changes first and mandatory readers`);
    parsedOverrides[cell] = items;
  }
  const cell = `${kind}.${family}`;
  const selected = parsedOverrides[cell] ?? cat.variants[cell];
  if (selected === undefined) throw new Error(`${cell}: no declared cell`);
  const byId = new Map(cat.sections.map((row): [string, SectionRow] => [row.id, row]));
  const readers = selected.map((id): SectionRow => byId.get(id) as SectionRow).filter((row): boolean => row.when === undefined || facts.has(row.when));
  const economics = byId.get("economics");
  if (facts.has("economics") && economics !== undefined && !readers.includes(economics)) readers.push(economics);
  if (readers.length > maximum) throw new Error(`${cell}: ${readers.length} admitted readers exceed max ${maximum}`);
  const footer = cat.footer.filter((row): boolean => row.reserved !== true && (row.when === undefined || facts.has(row.when)));
  const preamble = cat.preamble.filter((row): boolean => row.when === undefined || facts.has(row.when));
  return { cell, max: maximum, preamble: preamble.map((row): string => row.id), ids: readers.map((row): string => row.id), footer: footer.map((row): string => row.id), requirements: requirementsFor([...preamble, ...readers, ...footer], kind) };
}

function git(repo: string, args: readonly string[]): string[] {
  const result = spawnSync("git", ["-C", repo, ...args], { encoding: "utf8" });
  if (result.error !== undefined || result.status !== 0) throw new Error("cannot derive policy-hit from the target diff; pass --policy-hit with Mukai's result");
  return result.stdout.split("\0").filter((path): boolean => path.length !== 0);
}
/** Hatsu's own declared policy/process paths against committed, working and untracked changes. */
export function policyHit(repo: string): boolean {
  const root = resolvePath(repo);
  const declarationPath = declaredPath(root, "contracts/pr-composition.json", "file", true);
  if (declarationPath === null) return false;
  const declaration = object(load(declarationPath), "pr composition declaration must be an object");
  const sets = object(declaration.gateDerive, "gateDerive must be an object");
  const origin = spawnSync("git", ["-C", root, "remote", "get-url", "origin"], { encoding: "utf8" });
  if (origin.error !== undefined || origin.status !== 0) return false;
  const slug = origin.stdout.trim().replace(/\.git$/, "").replace(/^.*github\.com[:/]/, "");
  const rowValue = sets[slug];
  if (rowValue === undefined) return false;
  const row = object(rowValue, `${slug}: gateDerive row must be an object`);
  const prefixes = [...strings(row.policyPaths ?? [], `${slug}: policyPaths must be an array`), ...strings(row.processPaths ?? [], `${slug}: processPaths must be an array`)];
  const workflow = optionalWorkflow(root);
  const branch = workflow.branch === undefined ? {} : object(workflow.branch, "workflow and branch must be objects");
  const base = branch.base ?? "main";
  if (typeof base !== "string" || base.length === 0 || base.startsWith("-")) throw new Error("branch.base must name a branch");
  const changed = [
    ...git(root, ["diff", "--name-only", "-z", `origin/${base}...HEAD`, "--"]),
    ...git(root, ["diff", "--name-only", "-z", "HEAD", "--"]),
    ...git(root, ["ls-files", "--others", "--exclude-standard", "-z", "--"]),
  ];
  return changed.some((path): boolean => prefixes.some((prefix): boolean => path === prefix.replace(/\/$/, "") || path.startsWith(`${prefix.replace(/\/$/, "")}/`)));
}

function escapedAt(text: string, index: number): boolean {
  let slashes = 0;
  for (let at = index - 1; at >= 0 && text[at] === "\\"; at--) slashes++;
  return slashes % 2 === 1;
}
/** Character offsets belonging to matched CommonMark-style backtick code spans. */
function codeSpanMask(source: string): Uint8Array {
  const mask = new Uint8Array(source.length);
  for (let at = 0; at < source.length;) {
    if (source[at] !== "`" || escapedAt(source, at)) { at++; continue; }
    let end = at + 1;
    while (source[end] === "`") end++;
    const width = end - at;
    let close = end;
    let found = -1;
    while (close < source.length) {
      close = source.indexOf("`", close);
      if (close < 0) break;
      let runEnd = close + 1;
      while (source[runEnd] === "`") runEnd++;
      // Backslashes are literal inside a code span: one immediately before a
      // closing run does not escape that run (CommonMark § 6.1).
      if (runEnd - close === width) { found = close; end = runEnd; break; }
      close = runEnd;
    }
    if (found < 0) { at += width; continue; }
    mask.fill(1, at, end);
    at = end;
  }
  return mask;
}
function codeMasks(lines: readonly string[]): Uint8Array[] {
  const masks = lines.map((line): Uint8Array => new Uint8Array(line.length));
  const interrupts = /^ {0,3}(?:#{1,6}(?:[ \t]+|$)|`{3,}|~{3,}|>|[-+*][ \t]|\d{1,9}[.)][ \t]|<!--|([-*_])(?:[ \t]*\1){2,}[ \t]*$)/;
  for (let first = 0; first < lines.length;) {
    if ((lines[first] as string).trim() === "" || interrupts.test(lines[first] as string)) {
      masks[first] = codeSpanMask(lines[first] as string);
      first++;
      continue;
    }
    let last = first + 1;
    while (last < lines.length && (lines[last] as string).trim() !== "" && !interrupts.test(lines[last] as string)) last++;
    const block = lines.slice(first, last).join("\n");
    const mask = codeSpanMask(block);
    let offset = 0;
    for (let line = first; line < last; line++) {
      const width = (lines[line] as string).length;
      masks[line] = mask.slice(offset, offset + width);
      offset += width + 1;
    }
    first = last;
  }
  return masks;
}
function validFence(line: string): string | null {
  const match = /^ {0,3}(`{3,}|~{3,})(.*)$/.exec(line);
  if (match === null) return null;
  const fence = match[1] as string;
  return fence[0] === "`" && (match[2] as string).includes("`") ? null : fence;
}
function visibleLines(body: string): string[] {
  const source = body.replace(/^\uFEFF/, "").replace(/\r\n?/g, "\n");
  const rawLines = source.split("\n");
  const spans = codeMasks(rawLines);
  const visible: string[] = [];
  let fence: string | null = null;
  let comment = false;
  for (let lineNumber = 0; lineNumber < rawLines.length; lineNumber++) {
    const raw = rawLines[lineNumber] as string;
    const lineSpans = spans[lineNumber] as Uint8Array;
    if (fence !== null) {
      if (new RegExp(`^ {0,3}${fence[0]}{${fence.length},}[ \\t]*$`).test(raw)) fence = null;
      visible.push("");
      continue;
    }
    const startedInComment = comment;
    let text = "";
    for (let at = 0; at < raw.length;) {
      if (comment) {
        const close = raw.indexOf("-->", at);
        if (close < 0) { at = raw.length; continue; }
        comment = false;
        at = close + 3;
        continue;
      }
      const start = raw.indexOf("<!--", at);
      if (start < 0) { text += raw.slice(at); break; }
      if (lineSpans[start] === 1 || escapedAt(raw, start)) {
        text += raw.slice(at, start + 4);
        at = start + 4;
        continue;
      }
      text += raw.slice(at, start);
      comment = true;
      at = start + 4;
    }
    const opener = raw.indexOf("<!--");
    const htmlBlock = opener >= 0 && /^ {0,3}<!--/.test(raw) && lineSpans[opener] !== 1 && !escapedAt(raw, opener);
    if (startedInComment || htmlBlock) {
      visible.push("");
    } else {
      const open = validFence(text);
      if (open === null) visible.push(text);
      else { fence = open; visible.push(""); }
    }
  }
  return visible;
}
function tableRows(lines: readonly string[]): Set<number> {
  const table = new Set<number>();
  const cells = (line: string): string[] => line.trim().replace(/\\\|/g, "escaped-pipe").replace(/^\||\|$/g, "").split("|");
  for (let at = 1; at < lines.length; at++) {
    const line = lines[at] as string;
    const header = lines[at - 1] as string;
    if ((!line.includes("|") && !header.includes("|")) || header.trim() === "" || cells(line).length !== cells(header).length || !cells(line).every((cell): boolean => /^\s*:?-+:?\s*$/.test(cell))) continue;
    table.add(at - 1); table.add(at);
    for (let next = at + 1; next < lines.length; next++) {
      const following = lines[next] as string;
      if (following.trim() === "" || /^ {0,3}(?:#{1,6}(?:[ \t]+|$)|>|[-+*][ \t]|\d{1,9}[.)][ \t]|<(?:div|table|details|pre|script|style|section|p)(?:[\s>])|([-*_])(?:[ \t]*\1){2,}[ \t]*$)/i.test(following) || validFence(following) !== null) break;
      table.add(next);
    }
  }
  return table;
}
function validateRequirements(requirements: unknown): Requirement[] {
  if (!Array.isArray(requirements) || requirements.length === 0) throw new Error("requirements must be a nonempty array");
  return requirements.map((value): Requirement => {
    const row = object(value, "requirements must contain name/pattern objects");
    if (typeof row.name !== "string" || row.name.length === 0 || typeof row.pattern !== "string" || row.pattern.length === 0) throw new Error("requirements must contain name/pattern objects");
    try { new RegExp(row.pattern, "im"); }
    catch (error) { throw new Error(`requirement ${JSON.stringify(row.name)} has an invalid pattern: ${error instanceof Error ? error.message : String(error)}`); }
    if (row.content !== undefined && row.content !== true) throw new Error(`requirement ${JSON.stringify(row.name)}: content must be true or absent`);
    if (row.heading !== undefined && (row.content !== true || typeof row.heading !== "string" || row.heading.length === 0)) throw new Error(`requirement ${JSON.stringify(row.name)}: heading names a heading row and needs content`);
    if (row.content !== true) return { name: row.name, pattern: row.pattern };
    return typeof row.heading === "string" ? { name: row.name, pattern: row.pattern, content: true, heading: row.heading } : { name: row.name, pattern: row.pattern, content: true };
  });
}

export function check(cat: Catalogue, body: string, rawRequirements: unknown, maximum: number): [string[], string[]] {
  if (!Number.isInteger(maximum) || typeof maximum !== "number" || maximum < 1 || maximum > cat.max) throw new Error("--max must be positive and within the catalogue cap");
  const requirements = validateRequirements(rawRequirements);
  const compiled = requirements.map((row): RegExp => new RegExp(row.pattern, "im"));
  const lines = visibleLines(body);
  const tables = tableRows(lines);
  const headingPattern = /^ {0,3}#{1,2}(?:[ \t]+|$)/;
  const headings = lines.flatMap((line, index): [number, string][] => headingPattern.test(line) ? [[index + 1, line]] : []);
  const findings: string[] = [];
  const setext = /^ {0,3}(?:=+|-+)[ \t]*$/;
  const block = /^ {0,3}(?:#{1,6}(?:[ \t]+|$)|>|[-+*][ \t]|\d{1,9}[.)][ \t]|<(?:div|table|details|pre|script|style|section|p)(?:[\s>]))/i;
  const thematic = /^ {0,3}([-*_])(?:[ \t]*\1){2,}[ \t]*$/;
  for (let index = 1; index < lines.length; index++) {
    const previous = lines[index - 1] as string;
    const eligible = previous.trim() !== "" && !tables.has(index - 1) && !headingPattern.test(previous) && !/^ {4}|^\t/.test(previous) && !block.test(previous) && !thematic.test(previous);
    if (eligible && !tables.has(index) && setext.test(lines[index] as string)) findings.push(`line ${index + 1}: undeclared setext heading: ${previous}`);
  }
  const first = lines.find((line): boolean => line.trim() !== "") ?? "";
  if (requirements[0]?.name !== "delivery" || !compiled[0]?.test(first)) findings.push("body must open with the Delivery heading");
  if (requirements[1]?.name !== "changes" || headings[1] === undefined || !compiled[1]?.test(headings[1][1])) findings.push("changes H1 must immediately follow the Delivery block");
  const footers = new Set(cat.footer.map((row): string => row.id));
  const metadata = new Set(cat.preamble.map((row): string => row.id));
  const seen = new Set<number>();
  let previous = -1;
  let readers = 0;
  for (const [number, text] of headings) {
    const matches = compiled.flatMap((regex, index): number[] => requirements[index]?.content !== true && regex.test(text) ? [index] : []);
    if (matches.length !== 1) { findings.push(`line ${number}: ${matches.length === 0 ? "undeclared" : "ambiguous"} heading ${text}`); continue; }
    const at = matches[0] as number;
    if (at <= previous) findings.push(`line ${number}: out-of-order or repeated heading ${text}`);
    previous = Math.max(at, previous);
    seen.add(at);
    if (!footers.has(requirements[at]?.name as string) && !metadata.has(requirements[at]?.name as string)) {
      readers++;
      if (readers === maximum + 1) findings.push(`line ${number}: reader count exceeds max ${maximum}: ${text}`);
    }
  }
  const visible = lines.join("\n");
  requirements.forEach((row, index): void => {
    if (row.content !== true) { if (!seen.has(index)) findings.push(`missing heading ${row.name}`); return; }
    // HR-11: a content row reads the whole visible body; its heading's own absence is already named.
    const heading = requirements.findIndex((other): boolean => other.content !== true && (row.heading === undefined ? `${other.name}-content` === row.name : other.name === row.heading));
    if (heading === -1) findings.push(`content requirement ${row.name} names no heading requirement`);
    else if (seen.has(heading) && !(compiled[index] as RegExp).test(visible)) findings.push(row.heading === undefined ? `empty section ${requirements[heading]?.name}: its heading carries no content` : `section ${row.heading}: requirement ${row.name} is unmet`);
  });
  const warnings: string[] = [];
  let title = "preamble";
  let words = 0;
  const flush = (): void => { if (words > cat.proseBudget) warnings.push(`WARN ${title}: ${words} prose words (budget ${cat.proseBudget})`); };
  [...lines, "## end"].forEach((line, index): void => {
    const heading = /^ {0,3}#{1,2}(?:[ \t]+|$)(.*)/.exec(line);
    if (heading !== null) { flush(); title = heading[1] as string; words = 0; }
    else if (!tables.has(index) && !/^ {4}|^\t|^ {0,3}#{3,6}(?:\s|$)/.test(line)) words += (line.replace(/<[^>]*>/g, " ").match(/[\p{L}\p{N}]+(?:['’][\p{L}\p{N}]+)*/gu) ?? []).length;
  });
  return [findings, warnings];
}

function writeJson(path: string, value: unknown): void {
  const absolute = resolvePath(path);
  const info = stat(absolute);
  if (info?.isSymbolicLink()) throw new Error(`output ${path} is a symlink`);
  mkdirSync(dirname(absolute), { recursive: true });
  let temporary = "";
  let descriptor: number | null = null;
  try {
    for (let attempt = 0; attempt < 100; attempt++) {
      temporary = join(dirname(absolute), `.pr-sections-${process.pid}-${Date.now()}-${attempt}`);
      try { descriptor = openSync(temporary, "wx", 0o600); break; }
      catch (error) { if ((error as NodeJS.ErrnoException).code !== "EEXIST") throw error; }
    }
    if (descriptor === null) throw new Error(`cannot create atomic output beside ${path}`);
    writeFileSync(descriptor, `${JSON.stringify(value, null, 2)}\n`, "utf8");
    closeSync(descriptor); descriptor = null;
    renameSync(temporary, absolute); temporary = "";
  } finally {
    if (descriptor !== null) closeSync(descriptor);
    if (temporary !== "" && existsSync(temporary)) unlinkSync(temporary);
  }
}
function usage(): never {
  throw new Error("usage: pr_sections.ts validate | resolve --repo <path> --kind <kind> [--jobs <csv>] [--evidence] [--economics] [--policy-hit] [--spec] [--decisions] [--decisions-from <nen.run manifest>] [--idle] --out <path> | check --body <path> --requirements <path> --max <n>");
}
function argumentsFor(action: string, argv: readonly string[]): Record<string, string | boolean> {
  const boolean = new Set(action === "resolve" ? ["evidence", "economics", "policy-hit", "spec", "decisions", "idle"] : []);
  const valued = new Set(action === "resolve" ? ["repo", "kind", "jobs", "decisions-from", "out"] : action === "check" ? ["body", "requirements", "max"] : []);
  const result: Record<string, string | boolean> = {};
  for (let at = 0; at < argv.length; at++) {
    const token = argv[at] as string;
    if (!token.startsWith("--")) usage();
    const key = token.slice(2);
    if (boolean.has(key)) { result[key] = true; continue; }
    if (!valued.has(key) || at + 1 >= argv.length || (argv[at + 1] as string).startsWith("--")) usage();
    // HA#474 PH-2: a second manifest would silently replace the first, dropping a recorded decision.
    if (key === "decisions-from" && Object.hasOwn(result, key)) throw new Error("--decisions-from given twice: pass one manifest");
    result[key] = argv[++at] as string;
  }
  return result;
}
function required(args: Record<string, string | boolean>, key: string): string {
  const value = args[key];
  if (typeof value !== "string") usage();
  return value;
}
function main(argv = process.argv.slice(2)): number {
  try {
    const action = argv[0];
    if (action !== "validate" && action !== "resolve" && action !== "check") usage();
    const args = argumentsFor(action, argv.slice(1));
    const cat = catalogue();
    if (action === "validate") {
      if (argv.length !== 1) usage();
      out(`pr sections: ${Object.keys(cat.variants).length} cells, every job owned once; catalogue valid`);
      return 0;
    }
    if (action === "resolve") {
      const repo = required(args, "repo");
      const kind = required(args, "kind") as RepositoryKind;
      const jobsValue = typeof args.jobs === "string" ? args.jobs : "";
      const jobs = jobsValue === "" ? [] : jobsValue.split(",");
      const facts = new Set(["evidence", "economics", "policy-hit", "spec", "decisions", "idle"].filter((fact): boolean => args[fact] === true));
      if (typeof args["decisions-from"] === "string" && decisionsTaken(load(args["decisions-from"]), facts.has("decisions") || facts.has("idle"))) facts.add("decisions");
      if (kind === "process" && !facts.has("policy-hit") && policyHit(repo)) facts.add("policy-hit");
      const report = resolve(cat, repo, kind, jobs, facts);
      writeJson(required(args, "out"), report.requirements);
      out(report.ids.join(" · "));
      return 0;
    }
    const bodyPath = required(args, "body");
    const requirementsPath = required(args, "requirements");
    const maximumText = required(args, "max");
    if (!/^[+-]?\d+$/.test(maximumText)) throw new Error(`invalid integer for --max: ${maximumText}`);
    const [findings, warnings] = check(cat, readFileSync(bodyPath, "utf8"), load(requirementsPath), Number(maximumText));
    for (const message of [...findings, ...warnings]) out(message);
    if (findings.length > 0) return 1;
    out("pr sections: exact order and reader cap satisfied");
    return 0;
  } catch (error) {
    err(`pr sections: ${error instanceof Error ? error.message : String(error)}`);
    return 1;
  }
}

if (process.argv[1] !== undefined && resolvePath(process.argv[1]) === fileURLToPath(import.meta.url)) process.exitCode = main();
