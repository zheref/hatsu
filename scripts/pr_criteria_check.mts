#!/usr/bin/env node
// pr_criteria_check.mts — acceptance-criterion coverage as a readiness conjunct (HR-11; SDD plan
// piece P7). Read-only: it decides nothing, writes nothing and answers no question.
//
// USAGE
//   node scripts/pr_criteria_check.mts (--body <path> | --pr <owner/name#N>) [--repo <checkout>] [--json]
//
//   --body <path>        a PR body on disk (shibari § 4, before each write).
//   --pr <owner/name#N>  the live PR body, read through scripts/gh_token_env.sh (en §§ 4–5, rikugan § 3).
//   --repo <checkout>    where `nen repo resolve` reads nen/repos.json; default the working directory.
//   --json               one hatsu.pr-criteria-check/v1 document on stdout instead of lines.
//
// THE EXPECTED SET IS DERIVED, never restated. The body's one `## Associated issues` section names
// the closing issues: each table row whose *Merging this* cell opens with the bold closing verdict
// (`**completes it**` or `**closes it**`, templates/pr-body/issues.md) and whose *Issue* cell holds
// the canonical URL https://github.com/<owner>/<name>/issues/<N>, alone or as [text](url). Each
// closing issue's code is `nen repo resolve <owner>/<name> --repo <checkout> --json`'s, never guessed;
// its body is read through gh_token_env.sh. Its acceptance criteria are the `- AC-{n}:` rows
// (contracts/issue-sections.json → rows.acceptance, P6's catalogue), outside comments and fences.
// An issue with no AC row yields one `not-verifiable` row: never a pass (HR-11).
//
// THE VERIFY SECTION (templates/pr-body/verify.md) holds ONE table headed exactly
// `| Criterion | Coverage | Evidence |`. Criterion is `<CODE>#<N>/AC-<k>`, or `none` for a change no
// criterion asked for; Coverage is exactly one of the closed vocabulary
//   satisfied · partial · missing · contradicts · unrequested
// (`unrequested` only on a `none` row, and a `none` row only `unrequested`); Evidence a test name,
// path:line or scenario, never empty or a `<placeholder>`.
//
// REFUSED (exit 1), every one listed: no or a second Associated issues section; a closing row whose
// Issue cell is not one canonical URL; a closing issue with no AC row (not-verifiable); a criterion
// with no row; a row coverage `missing` or `contradicts`; a row naming a criterion outside the derived
// set; a criterion twice; a malformed row, coverage outside the vocabulary or empty evidence; closing
// issues with no verify section or no criteria table. `partial` passes and is listed. A body with no
// closing issue passes with zero criteria: there is nothing to cover.
//
// EXIT CODES (docs/PROCESS.md § Exit codes and refusals)
//   0  every criterion covered: no missing row, no missing, no contradicts, nothing not-verifiable
//   1  one or more refusals, every one listed
//   2  usage, or an unreadable body file or catalogue
//   3  a read failed: an unresolved code, a failed GitHub read, a pull request named as an issue or
//      an issue as a pull request (could not look is never found nothing)
//   5  a missing tool: nen or gh absent, or gh unauthenticated
//
// Owed to nen as part of `nen pr converge` (zheref/nen#483), the readiness verb; retired for it
// once released and repinned. Fixture: scripts/pr_criteria_check_fixture.mts (lane criteria).
import { readFileSync, realpathSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

export const COVERAGE = ["satisfied", "partial", "missing", "contradicts", "unrequested"] as const;
export type Coverage = (typeof COVERAGE)[number] | "no-row" | "not-verifiable";
export type Row = { criterion: string; coverage: Coverage; evidence: string; line: number | null };
export type Refusal = { id: string; criterion: string | null; line: number | null; detail: string };
export type Report = {
  contract: "hatsu.pr-criteria-check/v1";
  ok: boolean;
  closing: string[];
  rows: Row[];
  refusals: Refusal[];
  counts: { criteria: number; satisfied: number; partial: number; missing: number; contradicts: number; unrequested: number; noRow: number; notVerifiable: number };
};
export type ClosingIssue = { slug: string; number: number; line: number };
export type IssueReader = (issue: ClosingIssue) => { code: string; body: string };

const HERE = dirname(fileURLToPath(import.meta.url));
const USAGE = "usage: node scripts/pr_criteria_check.mts (--body <path> | --pr <owner/name#N>) [--repo <checkout>] [--json]";
const CLOSING = new Set(["completes it", "closes it"]);
const CRITERION = /^([A-Za-z][A-Za-z0-9]*)#([1-9][0-9]{0,8})\/AC-([1-9][0-9]{0,8})$/;
const SLUG = /^[A-Za-z0-9][A-Za-z0-9_.-]*\/[A-Za-z0-9][A-Za-z0-9_.-]*$/;

export class Stop extends Error {
  code: number;
  constructor(code: number, message: string) { super(message); this.code = code; }
}

export const clean = (text: string): string => text.replace(/[\x00-\x08\x0b-\x1f\x7f\u200b-\u200f\u202a-\u202e\u2066-\u2069\uFEFF]/g, "?").slice(0, 160);

/** Comments and fenced lines become blank lines, so line numbers still name the body's own lines. */
export function visible(body: string): string[] {
  const text = body.replace(/^\uFEFF/, "").replace(/\r\n?/g, "\n").replace(/<!--[\s\S]*?(-->|$)/g, (m) => m.replace(/[^\n]/g, ""));
  let fence: string | null = null;
  return text.split("\n").map((line) => {
    const marker = /^ {0,3}(`{3,}|~{3,})/.exec(line);
    if (fence !== null) {
      if (marker && marker[1][0] === fence[0] && marker[1].length >= fence.length && line.trim() === marker[1]) fence = null;
      return "";
    }
    if (marker) { fence = marker[1]; return ""; }
    return line;
  });
}

function titles(path = join(HERE, "..", "contracts", "pr-sections.json")): string[] {
  let catalogue: { sections?: { id: string; title: string | Record<string, string> }[] };
  try { catalogue = JSON.parse(readFileSync(path, "utf8")); } catch { throw new Stop(2, `cannot read the catalogue ${path}`); }
  const row = catalogue.sections?.find((entry) => entry.id === "verify");
  if (!row) throw new Stop(2, `the catalogue ${path} has no verify section`);
  return [...new Set(typeof row.title === "string" ? [row.title] : Object.values(row.title))];
}

export function acceptancePrefix(path = join(HERE, "..", "contracts", "issue-sections.json")): RegExp {
  let catalogue: { rows?: { acceptance?: { prefix?: string } } };
  try { catalogue = JSON.parse(readFileSync(path, "utf8")); } catch { throw new Stop(2, `cannot read the catalogue ${path}`); }
  const prefix = catalogue.rows?.acceptance?.prefix;
  if (prefix !== "^- AC-") throw new Stop(2, `the catalogue ${path} declares no '^- AC-' acceptance prefix`);
  return /^- AC-([1-9][0-9]{0,8}):/;
}

type Section = { start: number; lines: { text: string; line: number }[] };
function sections(lines: string[], title: (heading: string) => boolean): Section[] {
  const out: Section[] = [];
  let current: Section | null = null;
  lines.forEach((text, index) => {
    const heading = /^ {0,3}(#{1,2})[ \t]+(.*?)[ \t]*$/.exec(text);
    if (heading) {
      const name = heading[2].replace(/^[^A-Za-z0-9#]+[ \t]*/, "");
      current = heading[1] === "##" && title(name) ? { start: index + 1, lines: [] } : null;
      if (current) out.push(current);
      return;
    }
    if (current) current.lines.push({ text, line: index + 1 });
  });
  return out;
}

const cells = (line: string): string[] => line.trim().replace(/^\|/, "").replace(/(?<!\\)\|$/, "").split(/(?<!\\)\|/).map((cell) => cell.trim());
const delimiter = (line: string): boolean => cells(line).every((cell) => /^:?-+:?$/.test(cell));

/** Every table in a section: header cells, then data rows with their body line numbers. */
function tables(section: Section): { header: string[]; rows: { cells: string[]; line: number }[] }[] {
  const out: { header: string[]; rows: { cells: string[]; line: number }[] }[] = [];
  const lines = section.lines;
  for (let at = 0; at + 1 < lines.length; at++) {
    if (!lines[at].text.trim().startsWith("|") || !lines[at + 1].text.trim().startsWith("|") || !delimiter(lines[at + 1].text)) continue;
    const table = { header: cells(lines[at].text), rows: [] as { cells: string[]; line: number }[] };
    let next = at + 2;
    for (; next < lines.length && lines[next].text.trim().startsWith("|"); next++) table.rows.push({ cells: cells(lines[next].text), line: lines[next].line });
    out.push(table);
    at = next - 1;
  }
  return out;
}

/** The closing issues of a body's one Associated issues section; refusals are appended. */
export function closingIssues(lines: string[], refusals: Refusal[]): ClosingIssue[] {
  const found = sections(lines, (name) => name === "Associated issues");
  if (found.length !== 1) {
    refusals.push({ id: "issues-section", criterion: null, line: found[1]?.start ?? null, detail: found.length ? "a second '## Associated issues' section" : "no '## Associated issues' section" });
    return [];
  }
  const out: ClosingIssue[] = [];
  for (const table of tables(found[0])) {
    const issue = table.header.indexOf("Issue");
    const merging = table.header.indexOf("Merging this");
    if (issue === -1 || merging === -1) continue;
    for (const row of table.rows) {
      const verdict = /^\*\*([^*]+)\*\*/.exec(row.cells[merging] ?? "");
      if (!verdict || !CLOSING.has(verdict[1])) continue;
      const cell = row.cells[issue] ?? "";
      const url = /^(?:\[[^\]]*\]\((\S+)\)|(\S+))$/.exec(cell);
      const parsed = url ? /^https:\/\/github\.com\/([A-Za-z0-9][A-Za-z0-9-]*)\/([A-Za-z0-9][A-Za-z0-9_.-]*)\/issues\/([1-9][0-9]{0,8})$/.exec(url[1] ?? url[2]) : null;
      if (!parsed || parsed[2] === "." || parsed[2] === "..") {
        refusals.push({ id: "issue-cell", criterion: null, line: row.line, detail: `a closing row whose Issue cell is not one canonical issue URL: '${cell}'` });
        continue;
      }
      if (!out.some((seen) => seen.slug.toLowerCase() === `${parsed[1]}/${parsed[2]}`.toLowerCase() && seen.number === Number(parsed[3]))) {
        out.push({ slug: `${parsed[1]}/${parsed[2]}`, number: Number(parsed[3]), line: row.line });
      }
    }
  }
  return out;
}

/** The AC ids of one issue body, in first-seen order. */
export function criteriaOf(body: string, prefix = acceptancePrefix()): number[] {
  const ids: number[] = [];
  for (const line of visible(body)) {
    const hit = prefix.exec(line.trim());
    if (hit && !ids.includes(Number(hit[1]))) ids.push(Number(hit[1]));
  }
  return ids;
}

export function checkBody(body: string, read: IssueReader, verifyTitles = titles(), prefix = acceptancePrefix()): Report {
  const refusals: Refusal[] = [];
  const refuse = (id: string, criterion: string | null, line: number | null, detail: string) =>
    refusals.push({ id, criterion: criterion === null ? null : clean(criterion), line, detail: clean(detail) });
  const lines = visible(body);
  const closing = closingIssues(lines, refusals);
  const expected: { criterion: string; line: number }[] = [];
  const rows: Row[] = [];
  const closingRefs: string[] = [];
  for (const issue of closing) {
    const { code, body: issueBody } = read(issue);
    const ref = `${code.toUpperCase()}#${issue.number}`;
    closingRefs.push(ref);
    const ids = criteriaOf(issueBody, prefix);
    if (ids.length === 0) {
      rows.push({ criterion: ref, coverage: "not-verifiable", evidence: "the issue carries no '- AC-{n}:' row", line: issue.line });
      refuse("not-verifiable", ref, issue.line, `${ref} carries no acceptance-criterion row; nothing can be verified, never a pass`);
    }
    for (const id of ids) expected.push({ criterion: `${ref}/AC-${id}`, line: issue.line });
  }
  const seen = new Map<string, Row>();
  const unrequested: Row[] = [];
  {
    // Rows are read whenever the table is there: a criterion row on a body with no closing issue is
    // an unknown criterion, never silently ignored. The section and table are owed only with closing issues.
    const verify = sections(lines, (name) => verifyTitles.includes(name));
    const table = verify.length === 1 ? tables(verify[0]).filter((t) => t.header.join("|") === "Criterion|Coverage|Evidence") : [];
    if (verify.length > 1) refuse("verify-section", null, verify[1]?.start ?? null, "a second verify section");
    else if (verify.length === 0 && closing.length > 0) refuse("verify-section", null, null, "no verify section, with closing issues to cover");
    else if (table.length > 1) refuse("criteria-table", null, verify[0].start, "a second '| Criterion | Coverage | Evidence |' table");
    else if (table.length === 0 && closing.length > 0) refuse("criteria-table", null, verify[0].start, "no '| Criterion | Coverage | Evidence |' table, with closing issues to cover");
    for (const row of table.length === 1 ? table[0].rows : []) {
      const [criterion = "", coverage = "", evidence = "", ...extra] = row.cells;
      const shaped = CRITERION.exec(criterion);
      const key = shaped ? `${shaped[1].toUpperCase()}#${shaped[2]}/AC-${shaped[3]}` : criterion;
      if (extra.length) { refuse("row-shape", criterion, row.line, "a criteria row with more than three cells"); continue; }
      if (!shaped && criterion !== "none") { refuse("row-shape", criterion, row.line, `Criterion '${criterion}' is not <CODE>#<N>/AC-<k> or none`); continue; }
      if (!(COVERAGE as readonly string[]).includes(coverage)) { refuse("coverage", key, row.line, `Coverage '${coverage}' is not one of ${COVERAGE.join(" · ")}`); continue; }
      if (evidence === "" || /^<[^>]*>$/.test(evidence)) { refuse("evidence", key, row.line, "Evidence is empty or a placeholder: name a test, a path:line or a scenario"); continue; }
      if ((criterion === "none") !== (coverage === "unrequested")) { refuse("row-shape", key, row.line, "unrequested belongs only on a 'none' row, and a 'none' row is only unrequested"); continue; }
      const entry: Row = { criterion: key, coverage: coverage as Coverage, evidence: clean(evidence), line: row.line };
      if (criterion === "none") { unrequested.push(entry); continue; }
      if (seen.has(key)) { refuse("duplicate", key, row.line, `${key} has a second row`); continue; }
      if (!expected.some((want) => want.criterion === key)) { refuse("unknown-criterion", key, row.line, `${key} is not an acceptance criterion of a closing issue`); continue; }
      seen.set(key, entry);
      if (coverage === "missing" || coverage === "contradicts") refuse(coverage, key, row.line, `${key} reads ${coverage}: not ready whatever the gate verdict (HR-11)`);
    }
  }
  for (const want of expected) {
    const row = seen.get(want.criterion);
    if (row) rows.push(row);
    else {
      rows.push({ criterion: want.criterion, coverage: "no-row", evidence: "", line: null });
      refuse("no-row", want.criterion, null, `${want.criterion} has no verify row`);
    }
  }
  rows.push(...unrequested);
  const count = (coverage: Coverage) => rows.filter((row) => row.coverage === coverage).length;
  return {
    contract: "hatsu.pr-criteria-check/v1",
    ok: refusals.length === 0,
    closing: closingRefs,
    rows,
    refusals,
    counts: { criteria: expected.length, satisfied: count("satisfied"), partial: count("partial"), missing: count("missing"), contradicts: count("contradicts"), unrequested: count("unrequested"), noRow: count("no-row"), notVerifiable: count("not-verifiable") },
  };
}

function ghRead(path: string, what: string): Record<string, unknown> {
  const read = spawnSync("bash", [join(HERE, "gh_token_env.sh"), "--", "gh", "api", "--method", "GET", path],
    { encoding: "utf8", timeout: 60_000, maxBuffer: 8 * 1024 * 1024 });
  if (read.error) throw new Stop(5, `bash could not be run (${(read.error as NodeJS.ErrnoException).code ?? "error"})`);
  if (read.status === 125 || read.status === 127) throw new Stop(5, "gh is absent or unauthenticated; 'gh auth status' names the fix");
  if (read.status !== 0) throw new Stop(3, `${what} could not be read (exit ${read.status})`);
  try { return JSON.parse(read.stdout); } catch { throw new Stop(3, `${what} read back as no JSON`); }
}

export function liveReader(repo: string): IssueReader {
  return (issue) => {
    const nen = process.env.NEN || "nen";
    const resolved = spawnSync(nen, ["repo", "resolve", issue.slug, "--repo", repo, "--json"], { encoding: "utf8", timeout: 30_000 });
    if (resolved.error) throw new Stop(5, `nen could not be run (${(resolved.error as NodeJS.ErrnoException).code ?? "error"})`);
    let code: string | undefined;
    try {
      const repos = JSON.parse(resolved.stdout).repos;
      if (resolved.status === 0 && Array.isArray(repos) && repos.length === 1 && typeof repos[0].code === "string") code = repos[0].code;
    } catch { /* reported below */ }
    if (!code || !/^[A-Za-z][A-Za-z0-9]*$/.test(code)) throw new Stop(3, `'${clean(issue.slug)}' does not resolve to exactly one coded repository (nen repo resolve exit ${resolved.status})`);
    const read = ghRead(`repos/${issue.slug}/issues/${issue.number}`, `${issue.slug}#${issue.number}`);
    if (read.pull_request) throw new Stop(3, `${clean(issue.slug)}#${issue.number} is a pull request, not an issue`);
    return { code, body: typeof read.body === "string" ? read.body : "" };
  };
}

function parseArgs(argv: string[]) {
  const options: { body?: string; pr?: string; repo: string; json: boolean } = { repo: process.cwd(), json: false };
  for (let index = 0; index < argv.length; index += 1) {
    const flag = argv[index];
    const value = () => {
      const next = argv[index + 1];
      if (next === undefined || next.startsWith("--")) throw new Stop(2, `${flag} requires a value`);
      index += 1;
      return next;
    };
    if (flag === "--body") options.body = value();
    else if (flag === "--pr") options.pr = value();
    else if (flag === "--repo") options.repo = value();
    else if (flag === "--json") options.json = true;
    else throw new Stop(2, `unknown argument '${clean(flag)}'`);
  }
  if ((options.body === undefined) === (options.pr === undefined)) throw new Stop(2, "exactly one of --body and --pr");
  return options;
}

function main(): number {
  let json = process.argv.includes("--json");
  try {
    const options = parseArgs(process.argv.slice(2));
    json = options.json;
    const verifyTitles = titles();
    const prefix = acceptancePrefix();
    let body: string;
    if (options.body !== undefined) {
      let bytes: Buffer;
      try { bytes = readFileSync(resolve(options.body)); } catch { throw new Stop(2, `cannot read --body '${clean(options.body)}'`); }
      // QA-16: an invalid byte is refused, never replaced with U+FFFD and read as clean.
      try { body = new TextDecoder("utf-8", { fatal: true }).decode(bytes); } catch { throw new Stop(2, `--body '${clean(options.body)}' is not valid UTF-8`); }
    } else {
      const pr = /^([A-Za-z0-9][A-Za-z0-9_.-]*\/[A-Za-z0-9][A-Za-z0-9_.-]*)#([1-9][0-9]{0,8})$/.exec(options.pr as string);
      if (!pr || !SLUG.test(pr[1])) throw new Stop(2, `--pr '${clean(options.pr as string)}' is not <owner/name#N>`);
      const read = ghRead(`repos/${pr[1]}/pulls/${pr[2]}`, `${pr[1]}#${pr[2]}`);
      if (typeof read.number !== "number") throw new Stop(3, `${pr[1]}#${pr[2]} is not a pull request`);
      body = typeof read.body === "string" ? read.body : "";
    }
    const report = checkBody(body, liveReader(resolve(options.repo)), verifyTitles, prefix);
    if (json) process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
    else {
      for (const row of report.rows) process.stdout.write(`criteria: ${clean(row.criterion)} · ${row.coverage}${row.evidence ? ` · ${row.evidence}` : ""}\n`);
      for (const r of report.refusals) process.stdout.write(`criteria: REFUSED ${r.id}${r.line ? ` · line ${r.line}` : ""}: ${r.detail}\n`);
      const c = report.counts;
      process.stdout.write(`criteria: ${report.ok ? "ok" : "FAIL"} · ${c.criteria} criteria from ${report.closing.length} closing issue(s) · satisfied ${c.satisfied}, partial ${c.partial}, missing ${c.missing}, contradicts ${c.contradicts}, no row ${c.noRow}, not-verifiable ${c.notVerifiable}, unrequested ${c.unrequested}\n`);
    }
    return report.ok ? 0 : 1;
  } catch (error) {
    const code = error instanceof Stop ? error.code : 2;
    const message = error instanceof Error ? error.message : String(error);
    if (json) process.stdout.write(`${JSON.stringify({ contract: "hatsu.pr-criteria-check/v1", ok: false, error: clean(message), exit: code })}\n`);
    process.stderr.write(`criteria: ${clean(message)}\n${code === 2 ? `${USAGE}\n` : ""}`);
    return code;
  }
}

function isEntryScript(): boolean {
  if (!process.argv[1]) return false;
  try { return import.meta.url === pathToFileURL(realpathSync(resolve(process.argv[1]))).href; } catch { return false; }
}

if (isEntryScript()) process.exitCode = main();
