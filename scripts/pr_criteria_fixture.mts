#!/usr/bin/env node
// Hermetic fixture for the criteria lane (HR-11, HR-10; zheref/hatsu#413). Criterion coverage is
// `nen pr converge`'s verdict and Hatsu computes none of it: this lane holds what Hatsu still owns
// around that verb -- every reader citing it with Hatsu's catalogue, no Hatsu file restating its
// blocking rules, the verify template's criteria table and the verify-content requirement, and
// contracts/hanten-findings.schema.json's disposition invariants -- and reads Hatsu's catalogue
// through `nen issue criteria` (offline, --body-file), the verb `pr converge` reads criteria with.
// Needs the pinned nen (NEN=<path> overrides `nen`); absent, the lane fails, never passes.
import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, relative } from "node:path";
import { spawnSync } from "node:child_process";

const root = join(import.meta.dirname, "..");
const read = (path: string) => readFileSync(join(root, path), "utf8");
const catalogue = join(root, "contracts/issue-sections.json");
const dir = mkdtempSync(join(tmpdir(), "hatsu-criteria-"));
process.on("exit", () => rmSync(dir, { recursive: true, force: true }));

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
// verb's blocking words, none-word or evidence rule. CHANGELOG history is a record and is not read;
// docs/ROSTER.md's HR-11 row is the ruling itself, the rule's source, and is exempt by name. A ruling
// record (docs/ruling-records/*.json) and the question, options and answer cells of a ROSTER row
// rendered from one are the maintainer's question as asked, never retyped (ROSTER § The ruling
// template, step 3), so they are not read; the row's own status and settles cells still are.
const banned = [/pr_criteria_check/, /refuses a missing row/i, /blocking words?/i, /evidence (is )?required/i,
  /missing`?\s*(or|and|,)\s*`?contradicts/i, /\bno criteria\b/i, /unrequested only/i, /whose criterion is none/i];
// The ROSTER row is cut out of the text by its own id, then the rest is scanned joined, so a
// restatement hard-wrapped across lines is still caught.
const hr11 = /^\| <a id="hr-11"><\/a>\*\*HR-11\*\*.*$/m;
const rendered = /^(\| <a id="hr-\d+"><\/a>\*\*HR-\d+\*\* · \[[^\]]*\]\(ruling-records\/[^)]*\.json\) \|)(?:(?:\\\||[^|\n])*\|){3}(.*)$/gm;
const roster = (text: string) => text.replace(hr11, "").replace(rendered, "$1$2");
const scanned = (path: string, text: string) => (path === "docs/ROSTER.md" ? roster(text) : text).replace(/\s+/g, " ");
const walk = (path: string): string[] => statSync(join(root, path)).isDirectory()
  ? readdirSync(join(root, path)).flatMap((name) => walk(join(path, name))) : [path];
const own = relative(root, join(import.meta.dirname, "pr_criteria_fixture.mts"));
for (const path of ["claude", "docs", "templates", "contracts", "scripts", "nen", "surfaces", "CONTRIBUTING.md"].flatMap(walk)) {
  if (path === own || path.startsWith("docs/ruling-records/") || !/\.(md|json|mts|ts|sh|yml)$/.test(path)) continue;
  const text = scanned(path, read(path));
  for (const re of banned) assert.ok(!re.test(text), `${path} restates the coverage rule (${re})`);
}
// A rendered row's record cells are cut, and its settles cell is still read.
const renderedRow = (settles: string) => `| <a id="hr-9"></a>**HR-9** · [e--R-2026-10-23-01](ruling-records/e--R-2026-10-23-01.json) | missing or contradicts? | (A) Yes — *missing or contradicts blocks* | picked (A): \`Yes\` | ruled | ${settles} |`;
assert.ok(!banned.some((re) => re.test(scanned("docs/ROSTER.md", renderedRow("one rule, one verb")))), "a rendered row's record cells are not read");
assert.ok(banned.some((re) => re.test(scanned("docs/ROSTER.md", renderedRow("a missing or contradicts row blocks")))), "a rendered row's settles cell is read");
// The restatement this PR retired from en § 4 is caught, and the ROSTER exemption is that row alone.
assert.ok(banned.some((re) => re.test(scanned("x.md", "a `missing` or `contradicts` verify row, an acceptance criterion with no row"))));
assert.ok(banned.some((re) => re.test(scanned("x.md", "a `missing` or\n  `contradicts` verify row"))), "a wrapped restatement is caught");
assert.ok(hr11.test(read("docs/ROSTER.md")) && banned.some((re) => re.test(read("docs/ROSTER.md").match(hr11)![0])), "the exemption cuts the HR-11 row, which does state the rule");
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

// Hostile text (SEC-15): the plain output neutralises ESC and U+202E. --json escapes ESC but carries
// U+202E raw at nen 0.26.0 -- a documented miss owed to nen, pinned so the fix updates this case.
{
  const file = join(dir, "hostile.md");
  writeFileSync(file, "## Acceptance criteria\n\n- AC-1: Given a\u202e When \u001b[2J b Then c\n- AC-12-001 (P1): Given \u202e x \u001b[31m When b Then c\n");
  const plain = spawnSync(nen, ["issue", "criteria", "--body-file", file], { encoding: "utf8" });
  assert.equal(plain.status, 0, plain.stderr);
  assert.ok(!/[\u001b\u202e]/.test(plain.stdout), "plain output carries a raw control or bidi character");
  const json = spawnSync(nen, ["issue", "criteria", "--body-file", file, "--json"], { encoding: "utf8" });
  assert.ok(!json.stdout.includes("\u001b"), "--json carries a raw ESC");
  assert.ok(json.stdout.includes("\u202e"), "nen now neutralises U+202E in --json: drop this pinned miss");
}

// 4. en's not-applicable reading (HR-357, record R-2026-10-24-01 under zheref/hatsu#450): converge's closingSource
// none-on-non-default-base is not applicable only while the Development guard's --body form exits 0,
// which holds exactly when the Associated issues table has no closing row.
{
  const en = read("claude/skills/en/SKILL.md");
  const flat = en.replace(/\s+/g, " ");
  assert.ok(flat.includes("`none-on-non-default-base`, while the Development guard's `--body` form exits `0`") && flat.includes("**not applicable**"));
  assert.ok(flat.includes("**Ruled (HR-357, record R-2026-10-24-01, zheref/hatsu#450):**") && !flat.includes("[NEEDS missing-maintainer-choice: does not-applicable"), "the reading cites its ruling");
  assert.ok(flat.includes("or is not applicable as § 4 reads it (HR-357, record R-2026-10-24-01; quote converge's `closingSource` in the register row)"), "en § 5 step 3 merges on the ruled reading, closingSource quoted");
  const table = (verdict: string) => `## 🔗 Associated issues\n\n| Issue | Scope this PR implements | Merging this |\n|---|---|---|\n| https://github.com/example-owner/example-repo/issues/7 | x | **${verdict}** |\n`;
  const guard = (body: string) => {
    const file = join(dir, `issues-${Math.random().toString(36).slice(2)}.md`);
    writeFileSync(file, body);
    return spawnSync("bash", [join(root, "scripts/pr_development_link_check.sh"), "--body", file, "--target", "example-owner/example-repo"], { encoding: "utf8" }).status;
  };
  assert.equal(guard(table("delivers part")), 0, "a stacked delivers-part body: the reading applies");
  assert.equal(guard(table("completes it")), 1, "a closing row with no Closes line: the reading never applies");
}

// 5. The verify template carries the criteria table; the requirements array carries verify-content.
const template = read("templates/pr-body/verify.md");
assert.ok(template.includes("| Criterion | Coverage | Evidence |") && template.includes("satisfied · partial · missing · contradicts · unrequested"));
assert.ok(template.includes("nen pr converge"), "the template names the verb that judges the table");
const requirements = JSON.parse(read("contracts/pr-body.requirements.json")) as { name: string; pattern: string; content?: true }[];
const content = requirements.find((row) => row.name === "verify-content");
assert.ok(content?.content === true);
const contentRe = new RegExp(content.pattern, "im");
assert.ok(contentRe.test("## ✅ What the guards prove\n\n<!-- c -->\n| a |"));
assert.ok(!contentRe.test("## ✅ What the guards prove\n\n<!-- c\nd -->\n\n## 🔗 Associated issues\n"));

// 6. contracts/hanten-findings.schema.json (a deliberate tenant: the lane that runs in CI unconditionally): the disposition contract (HR-10).
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
// HR-10 as amended by HR-337: the schema forces the CON half; an HR id is critical only on a ruled row,
// which a schema cannot read, so it is not forced here (zheref/hatsu#466 owes the status-aware check).
for (const ok of ["CON-47", "CON-1"]) assert.ok(constitutional.test(ok), ok);
for (const no of ["UX-3", "HA#7/AC-1", "HR-10", "HR-0", "CON-"]) assert.ok(!constitutional.test(no), no);
assert.match(finding.then.$comment, /zheref\/hatsu#466/, "the HR half names its tracked check");
assert.equal(finding.then.properties.severity.const, "critical");
assert.deepEqual(finding.then.properties.disposition.properties.state.enum, ["fixed", "deferred"]);

// The schema cannot resolve an HR row's live status. The focused checker fixture
// owns that half of HR-10/HR-337 and remains wired into this always-run lane.
const findingFixture = spawnSync(process.execPath, [join(root, "scripts/hanten_findings_check_fixture.mts")], { encoding: "utf8" });
assert.equal(findingFixture.status, 0, `hanten findings fixture:\n${findingFixture.stdout}\n${findingFixture.stderr}`);
assert.match(findingFixture.stdout, /hanten-findings-check fixture: \d+ cases passed/);
const hanten = read("claude/skills/hanten/SKILL.md");
assert.ok(hanten.includes('node "$hatsu_root/scripts/hanten_findings_check.mts" "<findings-record>"')
  && hanten.includes('"$hatsu_root/docs/ROSTER.md"`; exit `1` returns, `2` stops unread.'),
  "hanten settlement invokes the status-aware checker and preserves its distinct exits");

console.log("criteria: readers cite nen pr converge with Hatsu's catalogue, no restated coverage rule, the catalogue read through nen issue criteria, hostile text, en's not-applicable reading, template and requirements wiring, and the findings schema and HR-status check passed");
