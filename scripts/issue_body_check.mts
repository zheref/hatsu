#!/usr/bin/env node
// issue_body_check.mts — read one issue body against contracts/issue-sections.json
// (HR-4; SDD plan piece P6). Read-only: it decides nothing, files nothing and
// answers no question; it reports every miss and the open and resolved OQ rows.
//
// USAGE
//   node scripts/issue_body_check.mts (--body-file <path> | --ref <CODE>#<N>)
//        [--kind product|defect|machinery|canon-gap|epic] [--repo <checkout>] [--json]
//
//   --body-file <path>  a body on disk (a brief before filing).
//   --ref <CODE>#<N>    an issue on GitHub: <CODE> is resolved by
//                       `nen repo resolve <CODE> --repo <checkout> --json`, never
//                       guessed; the body is read through scripts/gh_token_env.sh.
//   --kind <kind>       the catalogue kind; absent, only the `common` sections
//                       are required (an issue filed before the catalogue).
//   --repo <checkout>   where <CODE> resolves; default the working directory.
//   --json              one JSON document on stdout instead of lines.
//
// WHAT IS A MISS: a required heading absent or empty; a heading twice; an
// optional heading present but empty; a list item in a rows section that is
// not that section's row shape; row numbers not 1..n in order; a success row
// carrying no number or percentage; a vague adjective or a technology term in
// an acceptance row; and every OPEN question row (HR-4: a build refuses an
// issue with an open row, a batch skips it).
//
// EXIT CODES (docs/PROCESS.md § Exit codes and refusals)
//   0  no miss
//   1  one or more misses, every one listed
//   2  usage, or an unreadable catalogue or body file
//   3  the ref could not be read: unresolved code, failed read, or a pull
//      request rather than an issue (could not look is never found nothing)
//   5  a missing tool: nen or gh absent, or gh unauthenticated
//
// Owed to nen as `nen issue body-check` (zheref/nen#476) and `nen issue
// questions` (zheref/nen#477); retired for them once released and repinned.
// Fixture: scripts/issue_body_check_fixture.mts (lane issue-shape).
import { readFileSync, realpathSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

export type Miss = { id: string; section: string | null; line: number | null; detail: string };
export type Report = {
  contract: "hatsu.issue-body-check/v1";
  kind: string;
  ok: boolean;
  misses: Miss[];
  questions: { open: number; resolved: number; openRows: { n: number; gate: string; line: number }[] };
  rows: { acceptance: number; success: number; assumptions: number };
};
type Section = { heading: string; rows?: string; none?: boolean };
type RowSpec = { pattern: string; prefix: string; measure?: string; resolvedPattern?: string };
type Catalogue = {
  sections: Record<string, Section>;
  common: string[];
  kinds: Record<string, { required: string[]; optional: string[] }>;
  rows: Record<string, RowSpec>;
  noneText: string;
  vagueAdjectives: string[];
  technologyTerms: { words: string[]; patterns: { id: string; pattern: string }[] };
};
type Block = { title: string; line: number; lines: { text: string; line: number }[] };

const HERE = dirname(fileURLToPath(import.meta.url));
const USAGE = "usage: node scripts/issue_body_check.mts (--body-file <path> | --ref <CODE>#<N>) [--kind <kind>] [--repo <checkout>] [--json]";

class Stop extends Error {
  code: number;
  constructor(code: number, message: string) { super(message); this.code = code; }
}

export function loadCatalogue(path = join(HERE, "..", "contracts", "issue-sections.json")): Catalogue {
  let parsed: Catalogue;
  try { parsed = JSON.parse(readFileSync(path, "utf8")); } catch { throw new Stop(2, `cannot read the catalogue ${path}`); }
  if (!parsed || typeof parsed.sections !== "object" || !Array.isArray(parsed.common) || typeof parsed.kinds !== "object") {
    throw new Stop(2, `the catalogue ${path} lacks sections, common or kinds`);
  }
  return parsed;
}

const clean = (text: string): string => text.replace(/[\x00-\x08\x0b-\x1f\x7f]/g, "?").slice(0, 160);

function blocks(body: string): Block[] {
  // Comments become blank lines so line numbers still name the body's own lines.
  const text = body.replace(/\r\n?/g, "\n").replace(/<!--[\s\S]*?(-->|$)/g, (m) => m.replace(/[^\n]/g, ""));
  const out: Block[] = [];
  let fenced = false;
  text.split("\n").forEach((raw, index) => {
    const line = index + 1;
    if (/^\s*(```|~~~)/.test(raw)) fenced = !fenced;
    const heading = fenced ? null : /^##\s+(.+?)\s*#*\s*$/.exec(raw);
    if (heading && !raw.startsWith("###")) { out.push({ title: heading[1].trim(), line, lines: [] }); return; }
    if (out.length) out[out.length - 1].lines.push({ text: raw, line });
  });
  return out;
}

function words(text: string, list: string[]): string[] {
  return list.filter((word) => new RegExp(`(^|[^A-Za-z0-9-])${word.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}($|[^A-Za-z0-9-])`, "i").test(text));
}

export function checkBody(body: string, kind: string | null, catalogue: Catalogue): Report {
  const misses: Miss[] = [];
  const miss = (id: string, section: string | null, line: number | null, detail: string) =>
    misses.push({ id, section, line, detail: clean(detail) });
  const spec = kind ? catalogue.kinds[kind] : { required: catalogue.common, optional: [] as string[] };
  if (!spec) throw new Stop(2, `unknown kind '${kind}'; the catalogue names ${Object.keys(catalogue.kinds).join(", ")}`);
  const found = new Map<string, Block>();
  for (const block of blocks(body)) {
    const key = block.title.toLowerCase();
    if (found.has(key)) miss("duplicate-section", block.title, block.line, `'## ${block.title}' appears more than once`);
    else found.set(key, block);
  }
  const none = new RegExp(catalogue.noneText, "i");
  const report: Report = { contract: "hatsu.issue-body-check/v1", kind: kind ?? "common", ok: true, misses,
    questions: { open: 0, resolved: 0, openRows: [] }, rows: { acceptance: 0, success: 0, assumptions: 0 } };
  const wanted = [...spec.required.map((id) => [id, true] as const), ...spec.optional.map((id) => [id, false] as const)];
  for (const [id, required] of wanted) {
    const section = catalogue.sections[id];
    if (!section) throw new Stop(2, `the catalogue's kind lists '${id}', which sections does not define`);
    const block = found.get(section.heading.toLowerCase());
    if (!block) { if (required) miss("missing-section", section.heading, null, `'## ${section.heading}' is required`); continue; }
    const content = block.lines.filter((entry) => entry.text.trim() !== "");
    if (content.length === 0) { miss("empty-section", section.heading, block.line, `'## ${section.heading}' is present and empty`); continue; }
    if (section.none && content.length === 1 && none.test(content[0].text.trim())) continue;
    if (!section.rows) continue;
    const rows = catalogue.rows[section.rows];
    const numbers: number[] = [];
    for (const entry of content) {
      const text = entry.text.trim();
      if (!text.startsWith("- ") && !text.startsWith("* ")) continue;
      if (!new RegExp(rows.prefix).test(text)) { miss("row-shape", section.heading, entry.line, `a list item that is not a row: '${text}'`); continue; }
      const open = new RegExp(rows.pattern).exec(text);
      const closed = rows.resolvedPattern ? new RegExp(rows.resolvedPattern).exec(text) : null;
      const match = open ?? closed;
      if (!match) { miss("row-shape", section.heading, entry.line, `not the row shape: '${text}'`); continue; }
      numbers.push(Number(match[1]));
      if (section.rows === "question") {
        if (open) {
          report.questions.open += 1;
          report.questions.openRows.push({ n: Number(open[1]), gate: clean(open[2]), line: entry.line });
          miss("open-question", section.heading, entry.line, `OQ-${open[1]} (${open[2]}) is open`);
        } else report.questions.resolved += 1;
      }
      if (section.rows === "success" && rows.measure && !new RegExp(rows.measure).test(match[2])) {
        miss("sc-measure", section.heading, entry.line, `SC-${match[1]} carries no number or percentage`);
      }
      if (section.rows === "acceptance") {
        for (const word of words(text, catalogue.vagueAdjectives)) miss("ac-vague", section.heading, entry.line, `AC-${match[1]}: vague '${word}'`);
        for (const word of words(text, catalogue.technologyTerms.words)) miss("ac-technology", section.heading, entry.line, `AC-${match[1]}: technology term '${word}'`);
        for (const pattern of catalogue.technologyTerms.patterns) {
          const hit = new RegExp(pattern.pattern).exec(text.replace(/^- AC-[0-9]+: /, ""));
          if (hit) miss("ac-technology", section.heading, entry.line, `AC-${match[1]}: ${pattern.id} '${hit[0].trim()}'`);
        }
      }
    }
    const tally = section.rows === "acceptance" ? "acceptance" : section.rows === "success" ? "success" : section.rows === "assumption" ? "assumptions" : null;
    if (tally) report.rows[tally] = numbers.length;
    if (numbers.length === 0 && (section.rows === "acceptance" || section.rows === "success")) {
      miss("no-rows", section.heading, block.line, `'## ${section.heading}' holds no ${section.rows === "acceptance" ? "AC" : "SC"} row`);
    }
    const expected = numbers.map((_, index) => index + 1);
    if (numbers.some((n, index) => n !== expected[index])) {
      miss("numbering", section.heading, block.line, `rows numbered ${numbers.join(",")}; expected 1..${numbers.length} in order`);
    }
  }
  report.ok = misses.length === 0;
  return report;
}

function parseArgs(argv: string[]) {
  const options: { bodyFile?: string; ref?: string; kind?: string; repo: string; json: boolean } = { repo: process.cwd(), json: false };
  for (let index = 0; index < argv.length; index += 1) {
    const flag = argv[index];
    const value = () => {
      const next = argv[index + 1];
      if (next === undefined || next.startsWith("--")) throw new Stop(2, `${flag} requires a value`);
      index += 1;
      return next;
    };
    if (flag === "--body-file") options.bodyFile = value();
    else if (flag === "--ref") options.ref = value();
    else if (flag === "--kind") options.kind = value();
    else if (flag === "--repo") options.repo = value();
    else if (flag === "--json") options.json = true;
    else throw new Stop(2, `unknown argument '${clean(flag)}'`);
  }
  if ((options.bodyFile === undefined) === (options.ref === undefined)) throw new Stop(2, "exactly one of --body-file and --ref");
  return options;
}

function readRef(ref: string, repo: string): string {
  const parsed = /^([A-Za-z][A-Za-z0-9]*)#([1-9][0-9]{0,8})$/.exec(ref);
  if (!parsed) throw new Stop(2, `--ref '${clean(ref)}' is not <CODE>#<N>`);
  const nen = process.env.NEN || "nen";
  const resolved = spawnSync(nen, ["repo", "resolve", parsed[1], "--repo", repo, "--json"], { encoding: "utf8", timeout: 30_000 });
  if (resolved.error) throw new Stop(5, `nen could not be run (${(resolved.error as NodeJS.ErrnoException).code ?? "error"})`);
  let slug: string | undefined;
  try {
    const repos = JSON.parse(resolved.stdout).repos;
    if (resolved.status === 0 && Array.isArray(repos) && repos.length === 1) slug = repos[0].repo;
  } catch { /* reported below */ }
  if (!slug || !/^[A-Za-z0-9][A-Za-z0-9_.-]*\/[A-Za-z0-9][A-Za-z0-9_.-]*$/.test(slug)) {
    throw new Stop(3, `code '${parsed[1]}' does not resolve to exactly one repository (nen repo resolve exit ${resolved.status})`);
  }
  const read = spawnSync("bash", [join(HERE, "gh_token_env.sh"), "--", "gh", "api", "--method", "GET", `repos/${slug}/issues/${parsed[2]}`],
    { encoding: "utf8", timeout: 60_000, maxBuffer: 8 * 1024 * 1024 });
  if (read.status === 125 || read.status === 127) throw new Stop(5, "gh is absent or unauthenticated; 'gh auth status' names the fix");
  if (read.status !== 0) throw new Stop(3, `${slug}#${parsed[2]} could not be read (exit ${read.status})`);
  let issue: { body?: unknown; pull_request?: unknown };
  try { issue = JSON.parse(read.stdout); } catch { throw new Stop(3, `${slug}#${parsed[2]} read back as no JSON`); }
  if (issue.pull_request) throw new Stop(3, `${slug}#${parsed[2]} is a pull request, not an issue`);
  return typeof issue.body === "string" ? issue.body : "";
}

function main(): number {
  let json = process.argv.includes("--json");
  try {
    const options = parseArgs(process.argv.slice(2));
    json = options.json;
    const catalogue = loadCatalogue();
    let body: string;
    if (options.bodyFile !== undefined) {
      try { body = readFileSync(resolve(options.bodyFile), "utf8"); } catch { throw new Stop(2, `cannot read --body-file '${clean(options.bodyFile)}'`); }
    } else body = readRef(options.ref as string, resolve(options.repo));
    const report = checkBody(body, options.kind ?? null, catalogue);
    if (json) process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
    else {
      for (const m of report.misses) process.stdout.write(`issue-shape: ${m.id} · ${m.section ?? "-"}${m.line ? ` · line ${m.line}` : ""}: ${m.detail}\n`);
      process.stdout.write(`issue-shape: ${report.ok ? "ok" : "FAIL"} · kind ${report.kind} · ${report.misses.length} miss(es) · OQ open ${report.questions.open}, resolved ${report.questions.resolved}\n`);
    }
    return report.ok ? 0 : 1;
  } catch (error) {
    const code = error instanceof Stop ? error.code : 2;
    const message = error instanceof Error ? error.message : String(error);
    if (json) process.stdout.write(`${JSON.stringify({ contract: "hatsu.issue-body-check/v1", ok: false, error: clean(message), exit: code })}\n`);
    process.stderr.write(`issue-shape: ${clean(message)}\n${code === 2 ? `${USAGE}\n` : ""}`);
    return code;
  }
}

function isEntryScript(): boolean {
  if (!process.argv[1]) return false;
  try { return import.meta.url === pathToFileURL(realpathSync(resolve(process.argv[1]))).href; } catch { return false; }
}

if (isEntryScript()) process.exitCode = main();
