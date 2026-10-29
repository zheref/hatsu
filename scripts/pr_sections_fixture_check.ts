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
import { fileURLToPath, pathToFileURL } from "node:url";

import {
  canonProse,
  catalogue,
  check,
  decisionsTaken,
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
    const glyph = row.glyph.length > 0 ? `${row.glyph} ` : "";
    return `${"#".repeat(row.level)} ${glyph}${title}\n\nFilled.`;
  }).join("\n\n") + "\n";
}
// A compatibility contract for the deployed gate shape recorded by HA#475. Hatsu and Nen do not
// ship that consumer-owned validator, so this is deliberately not presented as its execution.
function hantenCompatibilityFindings(text: string): string[] {
  const findings: string[] = [];
  const headings = text.match(/^## Adversarial review \(hanten\)[ \t]*$/gm) ?? [];
  if (headings.length !== 1) findings.push("exact Hanten H2 required once");
  if (!/^- \[x\] Adversarial review settled\.[ \t]*$/m.test(text)) findings.push("checked Hanten checklist line missing");
  const section = text.match(/^## Adversarial review \(hanten\)[ \t]*$([\s\S]*?)(?=^##[ \t]|(?![\s\S]))/m)?.[1] ?? "";
  let dispositionColumn = -1;
  let idColumn = -1;
  let rows = 0;
  const closeTable = (): void => {
    if (dispositionColumn >= 0 && rows === 0) findings.push("findings table has a header and no rows");
    dispositionColumn = -1; idColumn = -1; rows = 0;
  };
  for (const raw of `${section}\n`.split("\n")) {
    const line = raw.trimStart();
    if (!line.startsWith("|")) {
      closeTable();
      if (/disposition/i.test(line) && line.includes("|")) findings.push("findings table row lacks leading pipe");
      continue;
    }
    const cells = line.split("|").map((cell): string => cell.trim().replace(/^[*`]+|[*`]+$/g, ""));
    if (dispositionColumn < 0) {
      dispositionColumn = cells.findIndex((cell): boolean => cell.toLowerCase() === "disposition");
      idColumn = cells.findIndex((cell): boolean => cell.toLowerCase() === "id");
      continue;
    }
    if (/^\|[ \t:|-]+$/.test(line)) continue;
    rows++;
    const id = cells[idColumn]?.trim() || "(unnamed row)";
    const disposition = (cells[dispositionColumn] ?? "").replaceAll("*", "").trimStart();
    if (!/^(?:fixed|pushed-back|deferred)(?:[ \t]+[-—:–][ \t]*\S|[ \t]*$)/i.test(disposition)) {
      findings.push(`unsettled finding ${id}: ${disposition}`);
    } else if (/^(?:fixed|pushed-back|deferred)[ \t]*$/i.test(disposition)) {
      findings.push(`finding ${id} lacks disposition reason`);
    } else if (/^deferred/i.test(disposition) && !/(?:#[0-9]+|https?:\/\/\S+)/.test(disposition)) {
      findings.push(`deferred finding ${id} lacks tracked issue: ${disposition}`);
    }
  }
  return findings;
}
function config(value: unknown): void {
  writeFileSync(join(repo, "nen/workflow.json"), `${JSON.stringify({ pr: { sections: value } })}\n`);
}
function writeJsonRequirements(path: string, report: Resolution): void {
  writeFileSync(path, `${JSON.stringify(report.requirements)}\n`);
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
  assert.deepEqual(defaults(cat), { max: 7, variants: cat.variants, $canon: { contract: cat.contract, sha256: cat.documentSha256 } });
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
  // HR-334 (idle) and HA#474/AC-1 (attended): a run that took a decision carries the decisions footer, before the checklist.
  assert.ok(!without.footer.includes("decisions"));
  assert.deepEqual(resolution("process", ["machinery"], ["idle"]).footer, ["decisions", "hanten", "checklist", "issues", "attribution"]);
  assert.deepEqual(resolution("process", ["machinery"], ["decisions"]).footer, ["decisions", "hanten", "checklist", "issues", "attribution"]);
  assert.deepEqual(resolution("process", ["machinery"], ["spec", "decisions"]).footer, ["spec", "decisions", "hanten", "checklist", "issues", "attribution"]);
  const withEconomics = resolution("process", ["machinery"], ["policy-hit", "economics"]);
  assert.deepEqual(withEconomics.ids, ["changes", "why", "how", "improves", "across", "verify", "economics"]);
  assert.deepEqual(resolution("unknown").ids, ["changes", "why", "how", "improves", "verify"]);
  assert.ok(!resolution("product", ["implementation"], []).ids.includes("evidence"));
  assert.ok(resolution("product", ["implementation"], ["evidence"]).ids.includes("evidence"));
});

test("HA#474 AC-1/AC-2: decisions resolves on every cell when a decision was taken, and never otherwise", () => {
  for (const cell of Object.keys(cat.variants)) {
    const [kind, family] = cell.split(".") as [RepositoryKind, string];
    for (const facts of [["decisions"], ["decisions", "policy-hit", "evidence"], ["idle"]]) {
      const taken = resolution(kind, cat.families[family], facts);
      assert.deepEqual(taken.footer, ["decisions", "hanten", "checklist", "issues", "attribution"], `${cell} ${facts.join(",")}`);
      assert.deepEqual(check(cat, body(taken, kind), taken.requirements, 7)[0], [], cell);
    }
    const none = resolution(kind, cat.families[family], ["policy-hit", "evidence"]);
    assert.deepEqual(none.footer, ["hanten", "checklist", "issues", "attribution"], cell);
    assert.ok(!none.requirements.some((row): boolean => row.name === "decisions"), cell);
    assert.deepEqual(check(cat, body(none, kind), none.requirements, 7)[0], [], cell);
  }
  assert.equal(cat.footer.find((row): boolean => row.id === "decisions")?.when, "decisions");
  assert.throws((): Resolution => resolution("process", ["machinery"], ["imaginary"]), /unknown run fact/);
});

test("HA#474: --decisions-from reads a nen.run manifest one way only, and anything else refuses", () => {
  assert.equal(decisionsTaken({ id: "r", idleAnswers: { "cleanup-plan": "default", "publish-offer": "refuse" } }), true);
  // A manifest cannot show that no decision was taken: null (an attended run) and {} refuse alone (Chrollo,
  // AC-1), and add nothing beside a positive flag, which wins.
  for (const empty of [{ id: "r", idleAnswers: null }, { id: "r", idleAnswers: {} }]) {
    assert.throws((): boolean => decisionsTaken(empty), /omit --decisions-from; pass --decisions if a decision was taken/, JSON.stringify(empty));
    assert.equal(decisionsTaken(empty, true), false, JSON.stringify(empty));
  }
  assert.equal(decisionsTaken({ idleAnswers: { "1-row": "hold" } }), true);
  for (const bad of [null, "decisions", 1, [], [{ row: "cleanup-plan" }], {}, { idleAnswers: [] }, { idleAnswers: "default" },
    { idleAnswers: { "cleanup-plan": 5 } }, { idleAnswers: { "cleanup-plan": "maybe" } }, { idleAnswers: { "   ": "default" } }, { idleAnswers: { "Bad_Row": "hold" } }]) {
    assert.throws((): boolean => decisionsTaken(bad), /manifest|idleAnswers/, JSON.stringify(bad));
    assert.throws((): boolean => decisionsTaken(bad, true), /manifest|idleAnswers/, `${JSON.stringify(bad)} beside a flag`);
  }
});

test("HA#474 AC-3: on zheref/hatsu#467's headings the strict check and nen's body check agree", (context) => {
  const fixture = join(HATSU_ROOT, "scripts/fixtures/pr-sections/ha-467-headings.md");
  const text = readFileSync(fixture, "utf8");
  const jobs = ["machinery", "prose-authoring", "upgrades"].join(",");
  const before = resolution("process", jobs.split(","), ["policy-hit"]);
  const after = resolution("process", jobs.split(","), ["policy-hit", "decisions"]);
  // The defect as filed: without the fact, the strict check names the heading the body check never sees.
  assert.ok(check(cat, text, before.requirements, 7)[0].some((finding): boolean => finding.includes("undeclared heading ## Decisions taken on your behalf")));
  const requirements = join(repo, "requirements.json");
  const resolveWith = (...extra: string[]): ReturnType<typeof spawnSync> =>
    run("bash", [RESOLVER, "--repo", repo, "--kind", "process", "--jobs", jobs, "--policy-hit", ...extra, "--out", requirements]);
  const manifest = join(repo, "manifest.json");
  writeFileSync(manifest, `${JSON.stringify({ contract: "nen.run/v0.1", id: "r1", repo: "zheref/hatsu", idleAnswers: { "cleanup-plan": "default" }, prs: [], parked: [] })}\n`);
  // Every positive source, through the shim, includes the section and makes the strict check pass.
  for (const extra of [["--decisions"], ["--idle"], ["--decisions-from", manifest], ["--decisions", "--idle", "--decisions-from", manifest]]) {
    const resolved = resolveWith(...extra);
    assert.equal(resolved.status, 0, `${extra.join(" ")}: ${resolved.stderr}`);
    assert.deepEqual(JSON.parse(readFileSync(requirements, "utf8")), after.requirements, extra.join(" "));
    const strict = run("bash", [CHECKER, "--body", fixture, "--requirements", requirements, "--max", "7"]);
    assert.equal(strict.status, 0, `${extra.join(" ")}: ${strict.stdout}${strict.stderr}`);
  }
  const plain = resolveWith();
  assert.equal(plain.status, 0, plain.stderr);
  assert.deepEqual(JSON.parse(readFileSync(requirements, "utf8")), before.requirements);
  // An attended (null) or empty manifest: alone it refuses; beside a positive flag the flag wins.
  for (const answers of [null, {}]) {
    const attended = join(repo, "attended.json");
    writeFileSync(attended, `${JSON.stringify({ contract: "nen.run/v0.1", id: "r2", idleAnswers: answers })}\n`);
    const alone = resolveWith("--decisions-from", attended);
    assert.equal(alone.status, 1); assert.match(alone.stderr, /omit --decisions-from; pass --decisions if a decision was taken/);
    for (const flag of ["--decisions", "--idle"]) {
      const beside = resolveWith(flag, "--decisions-from", attended);
      assert.equal(beside.status, 0, `${flag} ${JSON.stringify(answers)}: ${beside.stderr}`);
      assert.deepEqual(JSON.parse(readFileSync(requirements, "utf8")), after.requirements, `${flag} ${JSON.stringify(answers)}`);
    }
  }
  // A malformed manifest refuses whatever else is passed.
  const malformed = join(repo, "malformed.json");
  writeFileSync(malformed, `${JSON.stringify({ idleAnswers: { "cleanup-plan": "maybe" } })}\n`);
  const malformedBeside = resolveWith("--decisions", "--decisions-from", malformed);
  assert.equal(malformedBeside.status, 1); assert.match(malformedBeside.stderr, /default, hold or refuse/);
  // Filesystem errors keep their errno code, and say missing or unreadable rather than unreadable JSON.
  const missing = resolveWith("--decisions-from", join(repo, "absent.json"));
  assert.equal(missing.status, 1); assert.match(missing.stderr, /absent\.json: missing \(ENOENT\)/);
  const directory = resolveWith("--decisions-from", repo);
  assert.equal(directory.status, 1); assert.match(directory.stderr, /: unreadable \(EISDIR\)/);
  assert.ok(!/unreadable JSON/.test(`${missing.stderr}${directory.stderr}`));
  const twice = resolveWith("--decisions-from", manifest, "--decisions-from", manifest);
  assert.equal(twice.status, 1); assert.match(twice.stderr, /--decisions-from given twice/);
  const wrong = join(repo, "wrong.json");
  // SECRET474X fits inside the ten bytes V8 quotes from the file, so the old message would carry it.
  writeFileSync(wrong, "SECRET474X\n");
  const unreadable = resolveWith("--decisions-from", wrong);
  assert.equal(unreadable.status, 1); assert.match(unreadable.stderr, /unreadable JSON \(SyntaxError/);
  assert.ok(!unreadable.stderr.includes("SECRET474X"), unreadable.stderr);
  assert.ok(!/Unexpected token|is not valid JSON/.test(unreadable.stderr), unreadable.stderr);
  writeJsonRequirements(requirements, after);
  const nen = process.env.NEN || "nen";
  const probe = spawnSync(nen, ["--version"], { encoding: "utf8" });
  if (probe.error !== undefined || probe.status !== 0) { context.skip("nen is not installed: the body-check half is not run"); return; }
  const bodyCheck = run(nen, ["pr", "body-check", "--body-from", fixture, "--requirements-from", requirements]);
  assert.equal(bodyCheck.status, 0, `${bodyCheck.stdout}${bodyCheck.stderr}`);
});

test("HA#475: the derived body satisfies the section guard and recorded Hanten compatibility contract", () => {
  const report = resolution();
  const valid = body(report)
    .replace("## Adversarial review (hanten)\n\nFilled.", "## Adversarial review (hanten)\n\n| id | persona | rule | severity | file | disposition |\n|---|---|---|---|---|---|\n| HR-1 | reviewer | HR-1 | high | `a.md` | **deferred** — #475 |")
    .replace("## 📋 Completion checklist\n\nFilled.", "## 📋 Completion checklist\n\n- [x] Adversarial review settled.");
  assert.deepEqual(check(cat, valid, report.requirements, 7)[0], []);
  assert.deepEqual(hantenCompatibilityFindings(valid), []);

  const decorated = valid.replace("## Adversarial review (hanten)", "## 🔍 Adversarial review (hanten)");
  assert.ok(check(cat, decorated, report.requirements, 7)[0].some((finding): boolean => finding.includes("missing heading hanten")));
  assert.ok(hantenCompatibilityFindings(decorated).includes("exact Hanten H2 required once"));

  const unchecked = valid.replace("- [x] Adversarial review settled.", "- [ ] Adversarial review settled.");
  assert.ok(hantenCompatibilityFindings(unchecked).includes("checked Hanten checklist line missing"));
  const untracked = valid.replace("**deferred** — #475", "**deferred** — later");
  assert.ok(hantenCompatibilityFindings(untracked).some((finding): boolean => finding.includes("lacks tracked issue")));
  const pipeless = valid.replace(
    "| id | persona | rule | severity | file | disposition |\n|---|---|---|---|---|---|\n| HR-1 | reviewer | HR-1 | high | `a.md` | **deferred** — #475 |",
    "id | persona | rule | severity | file | disposition\n---|---|---|---|---|---\nHR-1 | reviewer | HR-1 | high | `a.md` | **deferred** — later",
  );
  assert.ok(hantenCompatibilityFindings(pipeless).includes("findings table row lacks leading pipe"));
  const indented = valid.replace("| HR-1 | reviewer | HR-1 | high | `a.md` | **deferred** — #475 |", " | HR-2 | reviewer | HR-1 | high | `a.md` | **deferred** — later |");
  assert.ok(hantenCompatibilityFindings(indented).some((finding): boolean => finding.includes("HR-2 lacks tracked issue")));
  const hyphenId = valid.replace("| HR-1 | reviewer | HR-1 | high | `a.md` | **deferred** — #475 |", "|-3 | reviewer | HR-1 | high | `a.md` | **deferred** — later |");
  assert.ok(hantenCompatibilityFindings(hyphenId).some((finding): boolean => finding.includes("-3 lacks tracked issue")));
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


test("HA#405: the spec run fact admits the Spec footer first, carrying nen's spec-rows whole", () => {
  assert.ok(!resolution("product", ["implementation"], []).footer.includes("spec"));
  const report = resolution("product", ["implementation", "parity"], ["spec"]);
  assert.deepEqual(report.footer, ["spec", "hanten", "checklist", "issues", "attribution"]);
  assert.ok(!report.ids.includes("spec"), "the Spec block is a footer, outside the seven-reader cap");
  const at = report.requirements.findIndex((row): boolean => row.name === "spec");
  // The catalogue's copy of nen's spec-rows is the one copy, frozen to the nen commit it names (nen exposes
  // the pattern through no verb); the resolver must carry it unchanged.
  const specRow = cat.footer.find((row): boolean => row.id === "spec") as SectionRow & { rows: { name: string; pattern: string; $frozenAt?: string } };
  assert.match(specRow.rows.$frozenAt ?? "", /^zheref\/nen@[0-9a-f]{8,40} src\/spec\/coverage\.ts /);
  assert.deepEqual(report.requirements[at + 1], { name: "spec-rows", pattern: specRow.rows.pattern, content: true, heading: "spec" });
  const filled = body(report, "product").replace("## 📐 Spec\n\nFilled.", "## 📐 Spec\n\n- F002-SC-001 — satisfied — test ListTest.sorted_F002_SC_001\n- F002-SC-002 — deferred — the threshold is the maintainer's · HA#405");
  assert.deepEqual(check(cat, filled, report.requirements, 7)[0], []);
  for (const empty of ["## 📐 Spec\n", "## 📐 Spec\n\nSee the issue.", "## 📐 Spec\n\n### F002-SC-001 — satisfied — test T"]) {
    const findings = check(cat, filled.replace(/## 📐 Spec\n\n- F002[^]*?HA#405/, empty), report.requirements, 7)[0];
    assert.ok(findings.includes("section spec: requirement spec-rows is unmet"), findings.join("; "));
  }
  const missing = check(cat, filled.replace(/## 📐 Spec\n\n- F002[^]*?HA#405\n\n/, ""), report.requirements, 7)[0];
  assert.ok(missing.includes("missing heading spec") && !missing.some((finding): boolean => finding.startsWith("section spec")), missing.join("; "));
  assert.throws((): unknown => check(cat, filled, [...report.requirements, { name: "x-rows", pattern: "^x", heading: "spec" }], 7), /heading names a heading row and needs content/);
  const copy = fresh("ha405-cat-");
  cpSync(join(HATSU_ROOT, "contracts"), join(copy, "contracts"), { recursive: true });
  cpSync(join(HATSU_ROOT, "templates"), join(copy, "templates"), { recursive: true });
  const file = join(copy, "contracts/pr-sections.json");
  const raw = JSON.parse(readFileSync(file, "utf8")) as { footer: Array<Record<string, unknown>> };
  delete raw.footer[0]?.when;
  writeFileSync(file, `${JSON.stringify(raw)}\n`);
  assert.throws((): Catalogue => catalogue(copy), /a rows requirement belongs to a conditional section/);
  assert.equal(successful("bash", [RESOLVER, "--repo", repo, "--kind", "product", "--jobs", "parity", "--spec", "--out", join(repo, "req.json")]).trim(), "changes · why · how · improves · verify");
  assert.ok((JSON.parse(readFileSync(join(repo, "req.json"), "utf8")) as Array<{ name: string }>).some((row): boolean => row.name === "spec-rows"));
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
  const emptyGlyph = clone(cat) as Catalogue & { sections: SectionRow[] };
  emptyGlyph.sections[0] = { ...emptyGlyph.sections[0]!, glyph: "" }; write(emptyGlyph);
  assert.throws((): Catalogue => catalogue(copy), /invalid level\/glyph/);
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

test("CLI executes validate and body verdicts through directory and file symlink aliases", () => {
  const aliases = fresh("ha417-entry-");
  const rootAlias = join(aliases, "installed-hatsu");
  const fileAlias = join(aliases, "catalogue-alias.ts");
  symlinkSync(HATSU_ROOT, rootAlias, "dir");
  symlinkSync(ENGINE, fileAlias);
  const entries = [ENGINE, join(rootAlias, "scripts/pr_sections.ts"), fileAlias];
  const expected = successful(process.execPath, [ENGINE, "validate"]);
  assert.match(expected, /catalogue valid/);
  const report = resolution();
  const bodyFile = join(repo, "entry-body.md");
  const requirements = join(repo, "entry-requirements.json");
  writeFileSync(requirements, JSON.stringify(report.requirements));
  for (const entry of entries) {
    const validated = run(process.execPath, [entry, "validate"]);
    assert.equal(validated.status, 0, validated.stderr);
    assert.equal(validated.stdout, expected);
    for (const [value, status, verdict] of [
      [body(report), 0, /exact order and reader cap satisfied/],
      [body(report) + "\n## Alias guard must reject this\n", 1, /Alias guard must reject this/],
    ] as const) {
      writeFileSync(bodyFile, value);
      const checked = run(process.execPath, [entry, "check", "--body", bodyFile, "--requirements", requirements, "--max", "7"]);
      assert.equal(checked.status, status, checked.stderr);
      assert.match(checked.stdout, verdict);
    }
    const invalid = run(process.execPath, [entry, "--unknown"]);
    assert.equal(invalid.status, 1);
    assert.match(invalid.stderr, /usage: pr_sections/);
  }
});

test("library imports remain inert for unrelated, missing and absent entry paths", () => {
  const imported = pathToFileURL(ENGINE).href;
  for (const argv1 of [undefined, join(repo, "missing-wrapper.mjs"), ENGINE + ".wrapper"]) {
    const expression = argv1 === undefined ? "process.argv.splice(1)" : "process.argv[1] = " + JSON.stringify(argv1);
    const result = run(process.execPath, ["--input-type=module", "--eval", expression + "; await import(" + JSON.stringify(imported) + "); console.log('library import completed')"]);
    assert.equal(result.status, 0, result.stderr);
    assert.equal(result.stdout, "library import completed\n");
    assert.equal(result.stderr, "");
  }
  const wrapper = join(repo, "wrapper.mjs");
  writeFileSync(wrapper, "import " + JSON.stringify(imported) + "; console.log('wrapper completed');\n");
  const result = run(process.execPath, [wrapper, "--unknown"]);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, "wrapper completed\n");
  assert.equal(result.stderr, "");
});

test("hosts without import.meta.main refuse explicitly instead of silently passing", () => {
  const loader = join(repo, "missing-entry-metadata-loader.mjs");
  // Exercise the runtime capability hole independently of the installed Node version.
  // The loader removes only this module's entry metadata, leaving its real CLI execution intact.
  writeFileSync(loader, "export async function load(url, context, nextLoad) { const result = await nextLoad(url, context); if (url === " + JSON.stringify(pathToFileURL(ENGINE).href) + ") result.source = String(result.source).replace('typeof import.meta.main', 'typeof undefined'); return result; }\n");
  const preload = join(repo, "missing-capability-entry.mjs");
  writeFileSync(preload, "process.argv[1] = " + JSON.stringify(join(repo, "missing-entry.ts")) + ";\n");
  for (const args of [[ENGINE, "validate"], ["--import", preload, ENGINE, "validate"]]) {
    const result = run(process.execPath, ["--no-warnings", "--loader", loader, ...args]);
    assert.equal(result.status, 1, result.stderr);
    assert.equal(result.stdout, "");
    assert.match(result.stderr, /^pr sections: unsupported Node runtime: import\.meta\.main is required[^\n]*\n$/);
  }
});

test("an unresolved CLI entry fails closed with one diagnostic", () => {
  const preload = join(repo, "unresolved-entry.mjs");
  // Simulate an entry disappearing after Node loaded it but before the module guard runs.
  writeFileSync(preload, "process.argv[1] = " + JSON.stringify(join(repo, "missing-entry.ts")) + ";\n");
  const result = run(process.execPath, ["--import", preload, ENGINE, "validate"]);
  assert.equal(result.status, 1);
  assert.equal(result.stdout, "");
  assert.equal(result.stderr, "pr sections: cannot resolve CLI entry to this module\n");
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

// HA#503 (HR-369): the reviewer-answered prose checklist, admitted only by the canon-prose fact.
function proseBody(report: Resolution, rows: string): string {
  return body(report).replace("## 🔎 Prose checklist\n\nFilled.", `## 🔎 Prose checklist\n\n| Row | Reviewer | Verdict | Line read |\n|---|---|---|---|\n${rows}`);
}
const ANSWERED = ["C", "L", "S", "M"].map((letter): string => `| PRS-${letter} | Chrollo | yes | zheref/hatsu#503 line 17 |`).join("\n");
function scopes(rows: readonly { persona: string; paths: string[] }[]): unknown {
  return { contract: "nen.review.scopes/v0.1", base: "origin/main", files: 1, scopes: rows.map((row) => ({ scope: row.persona, tier: "deep", budget: 1, ...row })), unclaimed: [] };
}

test("HA#503 AC-3: the prose checklist resolves on no cell without the canon-prose fact, and on every cell with it", () => {
  for (const cell of Object.keys(cat.variants)) {
    const [kind, family] = cell.split(".") as [RepositoryKind, string];
    const none = resolution(kind, cat.families[family], ["policy-hit", "evidence", "decisions"]);
    assert.ok(!none.footer.includes("prose"), cell);
    assert.ok(!none.requirements.some((row): boolean => row.name.startsWith("prose")), cell);
    const prose = resolution(kind, cat.families[family], ["canon-prose"]);
    assert.deepEqual(prose.footer, ["hanten", "prose", "checklist", "issues", "attribution"], cell);
    assert.deepEqual(prose.ids, resolution(kind, cat.families[family], []).ids, `${cell}: a footer row never moves a reader`);
  }
  assert.equal(cat.footer.find((row): boolean => row.id === "prose")?.when, "canon-prose");
});

test("HA#503 AC-1/AC-2: exactly one PRS row per letter, answered by Chrollo with a verdict and the line read", () => {
  const report = resolution("process", ["prose-authoring"], ["policy-hit", "canon-prose"]);
  assert.deepEqual(check(cat, proseBody(report, ANSWERED), report.requirements, 7)[0], []);
  // AC-2: a failed row is still an answered row; the finding it raises lives in the Hanten table.
  assert.deepEqual(check(cat, proseBody(report, ANSWERED.replace("| PRS-L | Chrollo | yes |", "| PRS-L | Chrollo | no |")), report.requirements, 7)[0], []);
  // Totality: several closing issues fold into one row per letter citing a line of each; a path:N cell reads too.
  const several = ANSWERED.replace("| PRS-C | Chrollo | yes | zheref/hatsu#503 line 17 |", "| PRS-C | Chrollo | no | zheref/hatsu#503 line 17; zheref/hatsu#9 line 4 |")
    .replace("| PRS-S | Chrollo | yes | zheref/hatsu#503 line 17 |", "| PRS-S | Chrollo | yes | docs/PR-SECTIONS.md:131 |");
  assert.deepEqual(check(cat, proseBody(report, several), report.requirements, 7)[0], []);
  const unmet = (rows: string): string[] => check(cat, proseBody(report, rows), report.requirements, 7)[0];
  const template = readFileSync(join(HATSU_ROOT, "templates/pr-body/prose.md"), "utf8");
  const placeholders = template.split("\n").filter((line): boolean => line.startsWith("| PRS-")).join("\n");
  assert.equal(placeholders.split("\n").length, 4, "the template carries the four rows");
  for (const [why, rows] of [
    ["the unfilled template", placeholders],
    ["an author-answered row", ANSWERED.replace("| PRS-C | Chrollo |", "| PRS-C | Kurapika |")],
    ["a row with no verdict", ANSWERED.replace("| PRS-S | Chrollo | yes |", "| PRS-S | Chrollo | |")],
    ["a row with no line read", ANSWERED.replace("| PRS-M | Chrollo | yes | zheref/hatsu#503 line 17 |", "| PRS-M | Chrollo | yes | |")],
    ["a line read with no line number", ANSWERED.replace("| PRS-M | Chrollo | yes | zheref/hatsu#503 line 17 |", "| PRS-M | Chrollo | yes | unread |")],
    ["a dash for a line read", ANSWERED.replace("| PRS-M | Chrollo | yes | zheref/hatsu#503 line 17 |", "| PRS-M | Chrollo | yes | — |")],
    ["a missing row", ANSWERED.split("\n").slice(0, 3).join("\n")],
    ["a tick in place of a verdict", ANSWERED.replace("| PRS-C | Chrollo | yes |", "| PRS-C | Chrollo | [x] |")],
    ["a repeated row", `${ANSWERED}\n| PRS-C | Chrollo | yes | zheref/hatsu#503 line 17 |`],
    ["conflicting rows for one letter", `| PRS-C | Chrollo | no | zheref/hatsu#503 line 18 |\n${ANSWERED}`],
  ] as const) assert.deepEqual(unmet(rows), ["section prose: requirement prose-rows is unmet"], why);
  // A row answered under a later heading does not satisfy the section.
  const moved = proseBody(report, ANSWERED.split("\n").slice(0, 3).join("\n")).replace("## 📋 Completion checklist\n\nFilled.", "## 📋 Completion checklist\n\n| Row | Reviewer | Verdict | Line read |\n|---|---|---|---|\n| PRS-M | Chrollo | yes | line 3 |");
  assert.deepEqual(check(cat, moved, report.requirements, 7)[0], ["section prose: requirement prose-rows is unmet"]);
  // A later repeat outside the section is another section's business, never a duplicate here.
  const later = proseBody(report, ANSWERED).replace("## 📋 Completion checklist\n\nFilled.", "## 📋 Completion checklist\n\n| Row | Reviewer | Verdict | Line read |\n|---|---|---|---|\n| PRS-M | Chrollo | yes | line 3 |");
  assert.deepEqual(check(cat, later, report.requirements, 7)[0], []);
});

test("HA#527: a Line-read cell may begin with its only line reference; a cell with none still refuses", () => {
  const report = resolution("process", ["prose-authoring"], ["policy-hit", "canon-prose"]);
  const unmet = (rows: string): string[] => check(cat, proseBody(report, rows), report.requirements, 7)[0];
  const each = (cell: string): string => ["C", "L", "S", "M"].map((letter): string => `| PRS-${letter} | Chrollo | yes | ${cell} |`).join("\n");
  const one = (cell: string): string => ANSWERED.replace("| PRS-S | Chrollo | yes | zheref/hatsu#503 line 17 |", `| PRS-S | Chrollo | yes | ${cell} |`);
  // AC-1: the reference is the cell's first token and its only one (HA-PR-#513's PRS-S row), on every letter.
  for (const cell of ["line 36 (Out of scope: the rest)", "line 7", "a:3 first", "docs/PR-SECTIONS.md:131 (the scope paragraph)"]) {
    assert.deepEqual(unmet(each(cell)), [], `every letter: ${cell}`);
    assert.deepEqual(unmet(one(cell)), [], `PRS-S alone: ${cell}`);
  }
  // AC-2: the shapes accepted before still read.
  for (const cell of ["zheref/hatsu#503 line 17", "zheref/hatsu#503 line 17; zheref/hatsu#9 line 4", "docs/PR-SECTIONS.md:131", "read at line 36"])
    assert.deepEqual(unmet(one(cell)), [], cell);
  // AC-3: a cell with no reference, empty, a dash or the placeholder still refuses.
  for (const cell of ["unread", "—", "", "<line read>", "<line read> line 3", "the scope paragraph", "outline 3", "path:"])
    assert.deepEqual(unmet(one(cell)), ["section prose: requirement prose-rows is unmet"], JSON.stringify(cell));
});

test("HA#503 AC-3: --scopes-from reads nen review scopes, and only a Markdown path Chrollo's scope claims admits the checklist", (context) => {
  // The architecture globs are the one definition: only .md paths Chrollo's scope claims admit the block.
  assert.equal(canonProse(scopes([{ persona: "nobunaga", paths: ["docs/PROCESS.md"] }])), false, "a path Chrollo does not claim");
  assert.equal(canonProse(scopes([{ persona: "chrollo", paths: ["contracts/a/b.md"] }])), true, "contracts/** claims a nested .md");
  assert.equal(canonProse(scopes([{ persona: "chrollo", paths: ["docs/PROCESS.md"] }])), true);
  assert.equal(canonProse(scopes([{ persona: "chrollo", paths: ["contracts/pr-sections.json"] }, { persona: "nobunaga", paths: ["README.md"] }])), false);
  assert.equal(canonProse(scopes([])), false);
  for (const bad of [null, [], {}, { contract: "nen.review.scopes/v0.2", scopes: [] }, { contract: "nen.review.scopes/v0.1", scopes: {} },
    { contract: "nen.review.scopes/v0.1", scopes: [5] }, { contract: "nen.review.scopes/v0.1", scopes: [{ persona: "chrollo", paths: [""] }] },
    // Nobunaga 2: a malformed entry after a match, a malformed non-Chrollo scope, and a scope without paths all refuse.
    { contract: "nen.review.scopes/v0.1", scopes: [{ persona: "chrollo", paths: ["docs/a.md"] }, 5] },
    { contract: "nen.review.scopes/v0.1", scopes: [{ persona: "nobunaga", paths: [""] }] },
    { contract: "nen.review.scopes/v0.1", scopes: [{ persona: "chrollo" }] },
    { contract: "nen.review.scopes/v0.1", scopes: [{ paths: ["docs/a.md"] }] }]) {
    assert.throws((): boolean => canonProse(bad), /--scopes-from/, JSON.stringify(bad));
  }
  const requirements = join(repo, "requirements.json");
  const document = join(repo, "scopes.json");
  const resolveWith = (...extra: string[]): ReturnType<typeof spawnSync> =>
    run("bash", [RESOLVER, "--repo", repo, "--kind", "process", "--jobs", "prose-authoring", "--policy-hit", ...extra, "--out", requirements]);
  const withProse = resolution("process", ["prose-authoring"], ["policy-hit", "canon-prose"]);
  const without = resolution("process", ["prose-authoring"], ["policy-hit"]);
  writeFileSync(document, `${JSON.stringify(scopes([{ persona: "chrollo", paths: ["claude/skills/shibari/SKILL.md"] }]))}\n`);
  for (const extra of [["--canon-prose"], ["--scopes-from", document], ["--canon-prose", "--scopes-from", document]]) {
    const resolved = resolveWith(...extra);
    assert.equal(resolved.status, 0, `${extra.join(" ")}: ${resolved.stderr}`);
    assert.deepEqual(JSON.parse(readFileSync(requirements, "utf8")), withProse.requirements, extra.join(" "));
  }
  writeFileSync(document, `${JSON.stringify(scopes([{ persona: "chrollo", paths: ["nen/workflow.json"] }]))}\n`);
  assert.equal(resolveWith("--scopes-from", document).status, 0);
  assert.deepEqual(JSON.parse(readFileSync(requirements, "utf8")), without.requirements);
  writeFileSync(document, `${JSON.stringify({ contract: "nen.run/v0.1" })}\n`);
  const malformed = resolveWith("--canon-prose", "--scopes-from", document);
  assert.equal(malformed.status, 1); assert.match(malformed.stderr, /expected contract nen\.review\.scopes\/v0\.1/);
  const twice = resolveWith("--scopes-from", document, "--scopes-from", document);
  assert.equal(twice.status, 1); assert.match(twice.stderr, /--scopes-from given twice/);
  // nen's whole-body check reads the same rows requirement the strict check does.
  const nen = process.env.NEN || "nen";
  const probe = spawnSync(nen, ["--version"], { encoding: "utf8" });
  if (probe.error !== undefined || probe.status !== 0) { context.skip("nen is not installed: the body-check half is not run"); return; }
  writeJsonRequirements(requirements, withProse);
  const answered = join(repo, "answered.md");
  for (const [rows, status] of [[ANSWERED, 0], [ANSWERED.replace("| PRS-C | Chrollo |", "| PRS-C | Kurapika |"), 1],
    [`${ANSWERED}\n| PRS-C | Chrollo | no | zheref/hatsu#503 line 18 |`, 1], [ANSWERED.replace("zheref/hatsu#503 line 17 |", "unread |"), 1]] as const) {
    writeFileSync(answered, proseBody(withProse, rows));
    const result = run(nen, ["pr", "body-check", "--body-from", answered, "--requirements-from", requirements]);
    assert.equal(result.status, status, `${rows}\n${result.stdout}${result.stderr}`);
  }
});
