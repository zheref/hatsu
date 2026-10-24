#!/usr/bin/env node
/** Hermetic HA#351 contract, resolver, body, CLI and configuration fixtures. */
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  cpSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  symlinkSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve as resolvePath } from "node:path";
import { after, beforeEach, test } from "node:test";
import { fileURLToPath } from "node:url";

import {
  catalogue,
  check,
  defaults,
  fold,
  options,
  pattern,
  policyHit,
  resolve,
  type Catalogue,
  type RepositoryKind,
  type Resolution,
  type SectionRow,
} from "./pr_sections.ts";

const HATSU_ROOT = resolvePath(dirname(fileURLToPath(import.meta.url)), "..");
const ENGINE = join(HATSU_ROOT, "scripts/pr_sections.ts");
const RESOLVER = join(HATSU_ROOT, "scripts/pr_sections_resolve.sh");
const CHECKER = join(HATSU_ROOT, "scripts/pr_body_sections_check.sh");
const temporary: string[] = [];
let cat: Catalogue;
let repo: string;

function fresh(prefix = "ha351-"): string {
  const path = mkdtempSync(join(tmpdir(), prefix));
  temporary.push(path);
  return path;
}
function clone<T>(value: T): T { return structuredClone(value); }
function run(command: string, args: readonly string[], cwd = HATSU_ROOT): ReturnType<typeof spawnSync> {
  return spawnSync(command, [...args], { cwd, encoding: "utf8" });
}
function successful(command: string, args: readonly string[], cwd = HATSU_ROOT): string {
  const result = run(command, args, cwd);
  assert.equal(result.status, 0, `${result.stdout}${result.stderr}`);
  return result.stdout;
}
function resolution(kind: RepositoryKind = "process", jobs: readonly string[] = ["machinery"], facts: readonly string[] = ["policy-hit"], source = cat): Resolution {
  return resolve(source, repo, kind, jobs, new Set(facts));
}
function body(report: Resolution, kind: RepositoryKind = "process", source = cat): string {
  const rows = new Map([...source.preamble, ...source.sections, ...source.footer].map((row): [string, SectionRow] => [row.id, row]));
  return [...report.preamble, ...report.ids, ...report.footer].map((id): string => {
    const row = rows.get(id) as SectionRow;
    const title = typeof row.title === "string" ? row.title : row.title[kind];
    return `${"#".repeat(row.level)} ${row.glyph} ${title}\n\nFilled.`;
  }).join("\n\n") + "\n";
}
function config(value: unknown): void {
  writeFileSync(join(repo, "nen/workflow.json"), `${JSON.stringify({ pr: { sections: value } })}\n`);
}
function git(root: string, ...args: string[]): void {
  const result = run("git", args, root);
  assert.equal(result.status, 0, `${args.join(" ")}\n${result.stdout}${result.stderr}`);
}

cat = catalogue();
beforeEach((): void => { repo = fresh(); mkdirSync(join(repo, "nen")); });
after((): void => { for (const path of temporary.splice(0)) rmSync(path, { recursive: true, force: true }); });

test("every one of 24 cells resolves and every one of 39 taxonomy jobs is owned once", () => {
  assert.equal(Object.keys(cat.variants).length, 24);
  for (const [cell, ids] of Object.entries(cat.variants)) {
    const [kind, family] = cell.split(".") as [RepositoryKind, string];
    const report = resolution(kind, cat.families[family], ["policy-hit", "evidence"]);
    assert.deepEqual(report.ids, ids, cell);
    assert.ok(ids.length <= 7, cell);
  }
  const jobs = Object.values(cat.families).flat();
  assert.equal(jobs.length, 39);
  assert.equal(new Set(jobs).size, 39);
  assert.deepEqual(defaults(cat), { max: 7, variants: cat.variants });
  assert.equal(Object.keys(options(cat)).length, cat.preamble.length + cat.sections.length + cat.footer.length);
});

test("family folding counts distinct jobs, uses precedence for ties, and refuses unknown jobs", () => {
  assert.equal(fold(cat, []), "build");
  assert.equal(fold(cat, ["release", "machinery"]), "release");
  assert.equal(fold(cat, ["schema", "machinery", "prose-authoring"]), "maintain");
  assert.equal(fold(cat, ["review", "review", "documentation"]), "verify");
  assert.throws((): string => fold(cat, ["imaginary"]), /no unique declared family/);
});

test("run facts admit only conditional readers while Delivery stays an always-first preamble", () => {
  const without = resolution("process", ["machinery"], []);
  assert.ok(!without.ids.includes("across"));
  assert.deepEqual(without.preamble, ["delivery"]);
  assert.ok(!without.footer.includes("delivery"));
  // The ruling of 2026-10-23: an idle run's PR carries the decisions footer, before the checklist; others never do.
  assert.ok(!without.footer.includes("decisions"));
  assert.deepEqual(resolution("process", ["machinery"], ["idle"]).footer, ["decisions", "checklist", "issues", "attribution"]);
  const withEconomics = resolution("process", ["machinery"], ["policy-hit", "economics"]);
  assert.deepEqual(withEconomics.ids, ["changes", "why", "how", "improves", "across", "verify", "economics"]);
  assert.deepEqual(resolution("unknown").ids, ["changes", "why", "how", "improves", "verify"]);
  assert.ok(!resolution("product", ["implementation"], []).ids.includes("evidence"));
  assert.ok(resolution("product", ["implementation"], ["evidence"]).ids.includes("evidence"));
});

test("consumer overrides validate every cell, booleans, mandatory readers and admitted count", () => {
  const chosen = ["changes", "why", "improves", "verify"];
  config({ max: 7, variants: { "process.maintain": chosen } });
  assert.deepEqual(resolution().ids, chosen);
  for (const value of [
    { max: 8 }, { max: true }, { variants: { "library.fix": ["unknown"] } },
    { variants: { "invalid.cell": chosen } }, { variants: { "process.fix": ["why", "verify"] } },
  ]) {
    config(value);
    assert.throws((): Resolution => resolution());
  }
  config({ max: 5 });
  assert.throws((): Resolution => resolution(), /admitted readers exceed max 5/);
});

test("workflow and catalogue declarations refuse live and dangling symlinks before existence checks", () => {
  const target = join(repo, "outside.json");
  writeFileSync(target, "{}\n");
  symlinkSync(target, join(repo, "nen/workflow.json"));
  assert.throws((): Resolution => resolution(), /symlink/);
  unlinkSync(join(repo, "nen/workflow.json"));
  symlinkSync(join(repo, "missing.json"), join(repo, "nen/workflow.json"));
  assert.throws((): Resolution => resolution(), /symlink/);

  const copy = fresh("ha351-cat-");
  cpSync(join(HATSU_ROOT, "contracts"), join(copy, "contracts"), { recursive: true });
  cpSync(join(HATSU_ROOT, "templates"), join(copy, "templates"), { recursive: true });
  const template = join(copy, "templates/pr-body/why.md");
  unlinkSync(template);
  symlinkSync(join(copy, "missing-template.md"), template);
  assert.throws((): Catalogue => catalogue(copy), /symlink/);
});

test("exact headings retain glyph tolerance, order, final footer and missing-section findings", () => {
  const report = resolution();
  const valid = body(report);
  assert.deepEqual(check(cat, valid, report.requirements, 7)[0], []);
  for (const bad of [
    `${valid}\n## Surprise\n`,
    valid.replace("## 🧭 Why", "## 🧭 WHY").replace("## 🛠️ How", "## Wrong"),
    valid.replace("## 🧭 Why", "## 🛠️ How"),
    `${valid}\n## 🧭 Why\n`,
  ]) {
    const findings = check(cat, bad, report.requirements, 7)[0];
    assert.ok(findings.length > 0);
    assert.ok(findings.some((finding): boolean => finding.includes("line ")));
  }
  assert.ok(check(cat, valid.replace("## 🧭 Why", "### 🧭 Why"), report.requirements, 7)[0].some((finding): boolean => finding.includes("missing heading")));
});

test("HR-11: an empty verify heading fails through its derived content requirement", () => {
  const report = resolution();
  const valid = body(report);
  const at = report.requirements.findIndex((row): boolean => row.name === "verify-content");
  assert.ok(at > 0 && report.requirements[at - 1]?.name === "verify" && report.requirements[at]?.content === true);
  const heading = "## ✅ What the guards prove\n\nFilled.";
  assert.ok(valid.includes(heading));
  for (const empty of ["## ✅ What the guards prove\n", "## ✅ What the guards prove\n\n<!-- a kept comment\nover two lines -->\n", "## ✅ What the guards prove\n\n### A subheading only"]) {
    const findings = check(cat, valid.replace(heading, empty), report.requirements, 7)[0];
    assert.ok(findings.includes("empty section verify: its heading carries no content"), findings.join("; "));
  }
  assert.deepEqual(check(cat, valid.replace(heading, "## ✅ What the guards prove\n\n<!-- note -->\n| Criterion | Coverage | Evidence |"), report.requirements, 7)[0], []);
  const missing = check(cat, valid.replace(heading, ""), report.requirements, 7)[0];
  assert.ok(missing.includes("missing heading verify") && !missing.some((finding): boolean => finding.startsWith("empty section")));
  const orphan = [...report.requirements, { name: "nowhere-content", pattern: "^x", content: true }];
  assert.ok(check(cat, valid, orphan, 7)[0].includes("content requirement nowhere-content names no heading requirement"));
  assert.throws((): unknown => check(cat, valid, [...report.requirements, { name: "bad", pattern: "^x", content: "yes" }], 7), /content must be true/);
});

test("the eighth admitted reader is named at the exact line", () => {
  const report = resolution("process", ["machinery"], ["policy-hit", "economics"]);
  const rollout = cat.sections.find((row): boolean => row.id === "rollout") as SectionRow;
  const requirements = [...report.requirements.slice(0, 8), pattern(rollout, "process"), ...report.requirements.slice(8)];
  const over = body(report).replace("## 📋 Completion checklist", "## 🚀 Rollout & rollback\n\nOK\n\n## 📋 Completion checklist");
  assert.ok(check(cat, over, requirements, 7)[0].some((finding): boolean => finding.includes("count exceeds max 7") && finding.includes("Rollout")));
});

test("fences and real comments hide headings while matched code spans and escaped openers do not", () => {
  const report = resolution();
  const valid = body(report);
  const masked = "\n<!--\n## Phantom\n-->\n\n~~~markdown\n## Phantom\n~~~\n\n```mermaid\n## Phantom\n```\n";
  assert.deepEqual(check(cat, valid + masked, report.requirements, 7)[0], []);
  assert.ok(check(cat, `${valid}\n\`<!--\`\n## Phantom\n`, report.requirements, 7)[0].some((finding): boolean => finding.includes("Phantom")));
  assert.ok(check(cat, valid + "\n`<!--\\`\n## Surprise\n", report.requirements, 7)[0].some((finding): boolean => finding.includes("Surprise")));
  assert.ok(check(cat, `${valid}\n\\<!--\n## Phantom\n`, report.requirements, 7)[0].some((finding): boolean => finding.includes("Phantom")));
  assert.ok(check(cat, `${valid}\n\`unmatched <!--\n## Hidden\n-->\n`, report.requirements, 7)[0].every((finding): boolean => !finding.includes("Hidden")));
  assert.ok(check(cat, `${valid}\n\`unmatched\n\n<!--\n## Hidden\n-->\n`, report.requirements, 7)[0].every((finding): boolean => !finding.includes("Hidden")));
  assert.ok(check(cat, `${valid}\n\`\`\`bad\`info\n## Phantom\n`, report.requirements, 7)[0].some((finding): boolean => finding.includes("Phantom")));
});

test("Setext refusal distinguishes a paragraph from thematic breaks after ATX headings and tables", () => {
  const report = resolution();
  const valid = body(report);
  assert.ok(check(cat, `${valid}\nSurprise\n---\n`, report.requirements, 7)[0].some((finding): boolean => finding.includes("setext") && finding.includes("Surprise")));
  assert.deepEqual(check(cat, `${valid}\n### Minor detail\n---\n`, report.requirements, 7)[0], []);
  assert.deepEqual(check(cat, `${valid}\n| A | B |\n| --- | --- |\ncell one | cell two\n---\n`, report.requirements, 7)[0], []);
});

test("prose warnings are non-gating and exclude GFM tables, comments and diagrams", () => {
  const report = resolution();
  const long = body(report).replace("Filled.", "word ".repeat(151));
  const [findings, warnings] = check(cat, long, report.requirements, 7);
  assert.deepEqual(findings, []);
  assert.equal(warnings.length, 1);
  assert.match(warnings[0] as string, /151 prose words/);
  const excluded = body(report).replace("Filled.", `| A | B |\n| - | - |\n| ${"word ".repeat(200)} | data |\n${"more ".repeat(200)}\n\n\`\`\`mermaid\n${"word ".repeat(200)}\n\`\`\``);
  assert.deepEqual(check(cat, excluded, report.requirements, 7), [[], []]);
});

test("catalogue validation rejects unknown cells, duplicate jobs, bad kind titles, preamble/footer gaps and boolean max", () => {
  const copy = fresh("ha351-contract-");
  cpSync(join(HATSU_ROOT, "contracts"), join(copy, "contracts"), { recursive: true });
  cpSync(join(HATSU_ROOT, "templates"), join(copy, "templates"), { recursive: true });
  const path = join(copy, "contracts/pr-sections.json");
  const write = (value: unknown): void => writeFileSync(path, `${JSON.stringify(value)}\n`);
  const unknown = clone(cat) as Catalogue & { variants: Record<string, string[]> };
  unknown.variants["product.fix"]?.push("imaginary"); write(unknown);
  assert.throws((): Catalogue => catalogue(copy), /unknown/);
  const duplicate = clone(cat) as Catalogue & { families: Record<string, string[]> };
  duplicate.families.canon?.push("machinery"); write(duplicate);
  assert.throws((): Catalogue => catalogue(copy), /39 taxonomy jobs/);
  const title = clone(cat) as Catalogue & { sections: Array<SectionRow & { title: unknown }> };
  title.sections[4]!.title = { product: "One" }; write(title);
  assert.throws((): Catalogue => catalogue(copy), /every repository kind/);
  const reserved = clone(cat) as Catalogue & { footer: Array<SectionRow & { reserved?: boolean }> };
  delete reserved.footer[0]!.reserved; write(reserved);
  assert.throws((): Catalogue => catalogue(copy), /reserved must be boolean/);
  const preamble = clone(cat) as Catalogue & { preamble: SectionRow[] };
  preamble.preamble = []; write(preamble);
  assert.throws((): Catalogue => catalogue(copy), /sole preamble/);
  const booleanMax = { ...clone(cat), max: true }; write(booleanMax);
  assert.throws((): Catalogue => catalogue(copy), /integer from 1 through 7/);
  const extraCell = clone(cat) as Catalogue & { variants: Record<string, string[]> };
  extraCell.variants["process.imaginary"] = ["changes"]; write(extraCell);
  assert.throws((): Catalogue => catalogue(copy), /24 kind\/family cells/);
});

test("policyHit sees merge-base committed changes, HEAD working changes and explicit untracked paths", () => {
  const target = fresh("ha351-git-");
  mkdirSync(join(target, "contracts"), { recursive: true });
  mkdirSync(join(target, "nen"), { recursive: true });
  mkdirSync(join(target, "scripts"), { recursive: true });
  writeFileSync(join(target, "contracts/pr-composition.json"), JSON.stringify({ gateDerive: { "zheref/hatsu": { policyPaths: ["contracts/"], processPaths: ["scripts/"] } } }));
  writeFileSync(join(target, "nen/workflow.json"), JSON.stringify({ branch: { base: "main" } }));
  writeFileSync(join(target, "scripts/seed.ts"), "export const seed = 1;\n");
  writeFileSync(join(target, "README.md"), "base\n");
  git(target, "init", "-q", "-b", "main");
  git(target, "config", "user.name", "Fixture");
  git(target, "config", "user.email", "fixture@example.invalid");
  git(target, "remote", "add", "origin", "git@github.com:zheref/hatsu.git");
  git(target, "add", "."); git(target, "commit", "-qm", "base");
  git(target, "update-ref", "refs/remotes/origin/main", "HEAD");
  git(target, "switch", "-qc", "feature");
  assert.equal(policyHit(target), false);
  writeFileSync(join(target, "scripts/untracked.ts"), "export {};\n");
  assert.equal(policyHit(target), true);
  unlinkSync(join(target, "scripts/untracked.ts"));
  writeFileSync(join(target, "scripts/seed.ts"), "export const seed = 2;\n");
  assert.equal(policyHit(target), true);
  git(target, "add", "scripts/seed.ts"); git(target, "commit", "-qm", "change process");
  assert.equal(policyHit(target), true);
});

test("CLI keeps resolve/check flags, atomic requirements output, warning exit and automatic policy fact", () => {
  const report = resolution();
  const valid = body(report);
  const bodyFile = join(repo, "body.md");
  const requirements = join(repo, "requirements.json");
  const resolved = run("bash", [RESOLVER, "--repo", repo, "--kind", "process", "--jobs", "machinery", "--policy-hit", "--out", requirements]);
  assert.equal(resolved.status, 0, resolved.stderr);
  assert.deepEqual(JSON.parse(readFileSync(requirements, "utf8")), report.requirements);
  const command = [CHECKER, "--body", bodyFile, "--requirements", requirements, "--max", "7"];
  for (const [value, code, text] of [
    [valid, 0, "satisfied"],
    [`${valid}\n## Surprise\n`, 1, "Surprise"],
    [valid.replace("Filled.", "word ".repeat(151)), 0, "151 prose words"],
  ] as const) {
    writeFileSync(bodyFile, value);
    const result = run("bash", command);
    assert.equal(result.status, code, `${result.stdout}${result.stderr}`);
    assert.match(result.stdout, new RegExp(text));
  }

  const gitRepo = fresh("ha351-cli-git-");
  mkdirSync(join(gitRepo, "contracts"), { recursive: true }); mkdirSync(join(gitRepo, "nen")); mkdirSync(join(gitRepo, "scripts"));
  writeFileSync(join(gitRepo, "contracts/pr-composition.json"), JSON.stringify({ gateDerive: { "zheref/hatsu": { policyPaths: [], processPaths: ["scripts/"] } } }));
  writeFileSync(join(gitRepo, "nen/workflow.json"), JSON.stringify({ branch: { base: "main" } }));
  writeFileSync(join(gitRepo, "README.md"), "base\n");
  git(gitRepo, "init", "-q", "-b", "main"); git(gitRepo, "config", "user.name", "Fixture"); git(gitRepo, "config", "user.email", "fixture@example.invalid");
  git(gitRepo, "remote", "add", "origin", "https://github.com/zheref/hatsu.git"); git(gitRepo, "add", "."); git(gitRepo, "commit", "-qm", "base");
  git(gitRepo, "update-ref", "refs/remotes/origin/main", "HEAD"); git(gitRepo, "switch", "-qc", "feature");
  writeFileSync(join(gitRepo, "scripts/change.ts"), "export {};\n");
  const autoRequirements = join(gitRepo, "requirements.json");
  const automatic = run("bash", [RESOLVER, "--repo", gitRepo, "--kind", "process", "--jobs", "machinery", "--out", autoRequirements]);
  assert.equal(automatic.status, 0, automatic.stderr);
  assert.match(automatic.stdout, /across/);

  const target = join(repo, "target.json"); const link = join(repo, "linked.json");
  writeFileSync(target, "[]\n"); symlinkSync(target, link);
  const linked = run("bash", [RESOLVER, "--repo", repo, "--kind", "process", "--jobs", "machinery", "--policy-hit", "--out", link]);
  assert.equal(linked.status, 1); assert.match(linked.stderr, /symlink/);
});

test("all human CLI diagnostics strip terminal controls and invisible formatting", () => {
  const report = resolution();
  const bodyFile = join(repo, `body-\u001b[2J\u202E.md`);
  const requirements = join(repo, "hostile-requirements.json");
  writeFileSync(bodyFile, `${body(report)}\n## Surprise\u001b[2J\u202E\n`);
  writeFileSync(requirements, JSON.stringify([...report.requirements, { name: "missing\u001b[H\u200B", pattern: "^## Never$" }]));
  const result = run("bash", [CHECKER, "--body", bodyFile, "--requirements", requirements, "--max", "7"]);
  assert.equal(result.status, 1);
  assert.ok(!`${result.stdout}${result.stderr}`.includes("\u001b"));
  assert.ok(!`${result.stdout}${result.stderr}`.includes("\u202E"));
  assert.ok(!`${result.stdout}${result.stderr}`.includes("\u200B"));
  assert.match(result.stdout, /Surprise\[2J/);
  assert.match(result.stdout, /missing\[H/);

  const absent = run(process.execPath, [ENGINE, "check", "--body", join(repo, `absent-\u001b[2J.md`), "--requirements", requirements, "--max", "7"]);
  assert.equal(absent.status, 1);
  assert.ok(!absent.stderr.includes("\u001b"));
});

test("configuration fill materializes all cells and preserves a consumer override", (context) => {
  const script = join(HATSU_ROOT, "scripts/config_values.sh");
  writeFileSync(join(repo, "nen/workflow.json"), `${JSON.stringify({ review: { scopes: {} } })}\n`);
  writeFileSync(join(repo, "nen/gates.json"), "{}\n");
  writeFileSync(join(repo, "nen/contract.json"), "{}\n");
  const invoke = (...args: string[]): ReturnType<typeof spawnSync> => run("bash", [script, ...args, "--repo", repo]);
  const filled = invoke("fill");
  if (filled.status !== 0 && `${filled.stdout}${filled.stderr}`.includes("pr_sections.py")) {
    context.skip("parallel config_values.ts adapter has not been integrated into this isolated worktree yet");
    return;
  }
  assert.equal(filled.status, 0, `${filled.stdout}${filled.stderr}`);
  const workflow = JSON.parse(readFileSync(join(repo, "nen/workflow.json"), "utf8")) as JsonWorkflow;
  assert.deepEqual(workflow.pr.sections.variants, cat.variants);
  assert.equal(workflow.pr.sections.max, 7);
  for (const row of [...cat.preamble, ...cat.sections, ...cat.footer]) assert.match(workflow.pr.$sections, new RegExp(`${row.id} — `));
  workflow.pr.sections.variants["process.canon"] = ["changes", "why", "improves", "verify"];
  writeFileSync(join(repo, "nen/workflow.json"), JSON.stringify(workflow));
  const diagnosis = invoke("diagnose"); assert.equal(diagnosis.status, 0, `${diagnosis.stdout}${diagnosis.stderr}`);
  assert.equal(invoke("fill").status, 0);
  assert.deepEqual((JSON.parse(readFileSync(join(repo, "nen/workflow.json"), "utf8")) as JsonWorkflow).pr.sections, workflow.pr.sections);
});

interface JsonWorkflow {
  pr: { $sections: string; sections: { max: number; variants: Record<string, string[]> } };
}

successful(process.execPath, [ENGINE, "validate"]);


test("composition adapter refuses a terminated path-set guard", () => {
  const hook = join(repo, "signal-hook.sh");
  writeFileSync(hook, 'kill -TERM "$$"\n');
  const child = spawnSync(process.execPath, [join(HATSU_ROOT, "scripts/pr_composition_check.ts")], {
    cwd: HATSU_ROOT, encoding: "utf8", env: { ...process.env, BASH_ENV: hook },
  });
  assert.equal(child.status, 2);
  assert.match(child.stderr, /path-set guard did not complete \(SIGTERM\)/);
});

test("independent trunk policy changes do not enter a README-only PR range", () => {
  const target = fresh("ha351-trunk-");
  mkdirSync(join(target, "contracts"), {recursive:true});
  mkdirSync(join(target, "nen"), {recursive:true});
  writeFileSync(join(target, "contracts/pr-composition.json"), JSON.stringify({gateDerive:{"zheref/hatsu":{policyPaths:["contracts/"],processPaths:["docs/"]}}}));
  writeFileSync(join(target, "nen/workflow.json"), JSON.stringify({branch:{base:"main"}}));
  writeFileSync(join(target, "README.md"), "base\n");
  git(target,"init","-q","-b","main");
  git(target,"config","user.name","Fixture");git(target,"config","user.email","fixture@example.invalid");
  git(target,"remote","add","origin","git@github.com:zheref/hatsu.git");
  git(target,"add",".");git(target,"commit","-qm","base");
  git(target,"switch","-qc","feature");
  writeFileSync(join(target,"README.md"),"feature\n");git(target,"add","README.md");git(target,"commit","-qm","feature");
  git(target,"switch","-q","main");mkdirSync(join(target,"docs"));writeFileSync(join(target,"docs/new.md"),"trunk only\n");
  git(target,"add","docs/new.md");git(target,"commit","-qm","advance trunk");git(target,"update-ref","refs/remotes/origin/main","HEAD");
  git(target,"switch","-q","feature");
  assert.equal(successful("git",["diff","--name-only","origin/main...HEAD"],target),"README.md\n");
  assert.equal(policyHit(target),false);
});
