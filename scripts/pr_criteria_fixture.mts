#!/usr/bin/env node
// Hermetic fixture for the criteria lane (HR-11, HR-10; zheref/hatsu#413). Criterion coverage is
// `nen pr converge`'s verdict and Hatsu computes none of it: this lane holds what Hatsu still owns
// around that verb -- every reader citing it with Hatsu's catalogue, no Hatsu file restating its
// blocking rules, the verify template's criteria table and the verify-content requirement, and
// contracts/hanten-findings.schema.json's disposition invariants -- and reads Hatsu's catalogue
// through `nen issue criteria` (offline, --body-file), the verb `pr converge` reads criteria with.
// Needs the pinned nen (NEN=<path> overrides `nen`); absent, the lane fails, never passes.
import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, readdirSync, statSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, relative } from "node:path";
import { spawnSync } from "node:child_process";

const root = join(import.meta.dirname, "..");
const read = (path: string) => readFileSync(join(root, path), "utf8");
const catalogue = join(root, "contracts/issue-sections.json");
const dir = mkdtempSync(join(tmpdir(), "hatsu-criteria-"));

// 1. Every reader runs the verb with Hatsu's catalogue (shibari § 4, en §§ 4-5, rikugan § 3).
const verb = 'nen pr converge --target <owner/name> --pr <';
const from = '--requirements-from "$hatsu_root/contracts/issue-sections.json"';
for (const [skill, count] of [["shibari", 1], ["en", 2], ["rikugan", 1]] as const) {
  const text = read(`claude/skills/${skill}/SKILL.md`);
  const lines = text.split("\n").filter((line) => line.includes(verb));
  assert.equal(lines.length, count, `${skill}: ${lines.length} converge call(s)`);
  for (const line of lines) assert.ok(line.includes(from), `${skill}: converge without Hatsu's catalogue: ${line}`);
}

// 2. One owner (AC-2, SC-1): no Hatsu script computes coverage and no canon file restates the
// verb's blocking words or evidence rule. CHANGELOG history is a record and is not read.
const banned = [/pr_criteria_check/, /refuses a missing row/i, /blocking words?/i, /evidence (is )?required/i];
const walk = (path: string): string[] => statSync(join(root, path)).isDirectory()
  ? readdirSync(join(root, path)).flatMap((name) => walk(join(path, name))) : [path];
const own = relative(root, join(import.meta.dirname, "pr_criteria_fixture.mts"));
for (const path of ["claude", "docs", "templates", "contracts", "scripts", "nen", "CONTRIBUTING.md"].flatMap(walk)) {
  if (path === own || !/\.(md|json|mts|ts|sh|yml)$/.test(path)) continue;
  const text = read(path);
  for (const re of banned) assert.ok(!re.test(text), `${path} restates the coverage rule (${re})`);
}
assert.equal("coverage" in JSON.parse(readFileSync(catalogue, "utf8")), false, "Hatsu keeps nen's coverage defaults (AS-1)");

// 3. The catalogue as the verb reads it: list rows in the acceptance section, comments and fences
// ignored, a body with no AC row not verifiable (never all verified).
const nen = process.env.NEN || "nen";
const criteria = (body: string) => {
  const file = join(dir, `body-${Math.random().toString(36).slice(2)}.md`);
  writeFileSync(file, body);
  const r = spawnSync(nen, ["issue", "criteria", "--body-file", file, "--requirements-from", catalogue, "--json"], { encoding: "utf8" });
  assert.equal(r.status, 0, `nen issue criteria: ${r.error?.message ?? r.stderr}`);
  return JSON.parse(r.stdout) as { contract: string; verifiable: boolean; criteria: { id: string }[]; unrecognised: { text: string }[] };
};
const section = (rows: string) => `## Problem\n\nA placeholder.\n\n## Acceptance criteria\n\n${rows}\n\n<!-- - AC-9: Given a comment When read Then ignored -->\n\`\`\`\n- AC-8: Given a fence When read Then ignored\n\`\`\`\n`;
let report = criteria(section("- AC-1: Given a body When checked Then it passes\n- AC-2: Given a gap When checked Then it fails"));
assert.equal(report.contract, "nen.issue.criteria/v0.1");
assert.equal(report.verifiable, true);
assert.deepEqual(report.criteria.map((c) => c.id), ["AC-1", "AC-2"]);
report = criteria("## Problem\n\nNo criteria here.\n");
assert.equal(report.verifiable, false);
// Akatsuki's AC-{epic}-{nnn} rows (zheref/hatsu#411) are unrecognised at this pin: a documented
// miss owed to nen, pinned so the repin that admits them updates this case.
report = criteria(section("- AC-12-001 (P1): Given a When b Then c"));
assert.equal(report.verifiable, false);
assert.deepEqual(report.unrecognised.map((u) => u.text), ["- AC-12-001 (P1): Given a When b Then c"]);

// 4. The verify template carries the criteria table; the requirements array carries verify-content.
const template = read("templates/pr-body/verify.md");
assert.ok(template.includes("| Criterion | Coverage | Evidence |") && template.includes("satisfied · partial · missing · contradicts · unrequested"));
assert.ok(template.includes("nen pr converge"), "the template names the verb that judges the table");
const requirements = JSON.parse(read("contracts/pr-body.requirements.json")) as { name: string; pattern: string; content?: true }[];
const content = requirements.find((row) => row.name === "verify-content");
assert.ok(content?.content === true);
const contentRe = new RegExp(content.pattern, "im");
assert.ok(contentRe.test("## ✅ What the guards prove\n\n<!-- c -->\n| a |"));
assert.ok(!contentRe.test("## ✅ What the guards prove\n\n<!-- c\nd -->\n\n## 🔗 Associated issues\n"));

// 5. contracts/hanten-findings.schema.json: the disposition contract (HR-10).
const schema = JSON.parse(read("contracts/hanten-findings.schema.json"));
assert.equal(schema.$id, "hatsu.hanten.findings/v0.1");
const disposition = schema.$defs.disposition;
assert.deepEqual(disposition.properties.state.enum, ["fixed", "pushed-back", "deferred"]);
assert.deepEqual(disposition.allOf[0].if.properties.state.enum, ["pushed-back", "deferred"]);
assert.deepEqual(disposition.allOf[0].then.required, ["detail"]);
assert.equal(disposition.allOf[0].then.properties.detail.minLength, 1);
assert.equal(disposition.allOf[1].if.properties.state.const, "deferred");
assert.deepEqual(disposition.allOf[1].then.required, ["tracked"]);
const tracked = new RegExp(schema.$defs.trackedRef.pattern);
for (const ok of ["HA#12", "zheref/hatsu#12"]) assert.ok(tracked.test(ok), ok);
for (const bad of ["HA#0", "pending", "#12", ""]) assert.ok(!tracked.test(bad), bad);
const finding = schema.$defs.finding;
assert.deepEqual(finding.required, ["id", "scope", "persona", "rule", "severity", "path", "line", "evidence", "proposedFix", "disposition"]);
const constitutional = new RegExp(finding.if.properties.rule.pattern);
for (const ok of ["CON-47", "HR-10"]) assert.ok(constitutional.test(ok), ok);
for (const no of ["UX-3", "HA#7/AC-1", "HR-0", "CON-"]) assert.ok(!constitutional.test(no), no);
assert.equal(finding.then.properties.severity.const, "critical");
assert.deepEqual(finding.then.properties.disposition.properties.state.enum, ["fixed", "deferred"]);

console.log("criteria: readers cite nen pr converge with Hatsu's catalogue, no restated coverage rule, the catalogue read through nen issue criteria, template and requirements wiring, and the findings schema passed");
