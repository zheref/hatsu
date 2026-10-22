#!/usr/bin/env node
// Hermetic fixture for scripts/pr_criteria_check.mts (lane criteria; HR-11, HR-10).
// Offline: --body and --pr run against a stub nen (NEN) and a stub gh on PATH. Bodies carry
// placeholder slugs only. Also holds contracts/hanten-findings.schema.json's structural invariants
// and the verify template / requirements wiring the guard rests on.
import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import { checkBody, criteriaOf, type ClosingIssue, type IssueReader } from "./pr_criteria_check.mts";

const here = import.meta.dirname;
const root = join(here, "..");
const script = join(here, "pr_criteria_check.mts");
const dir = mkdtempSync(join(tmpdir(), "hatsu-criteria-"));

const issueBody = (rows: string) => `## Problem

A placeholder.

## Acceptance criteria

${rows}

<!-- - AC-9: Given a commented row When read Then it is ignored -->
\`\`\`
- AC-8: Given a fenced row When read Then it is ignored
\`\`\`
`;
const twoAc = issueBody("- AC-1: Given a body When checked Then it passes\n- AC-2: Given a gap When checked Then it fails");
const issues: Record<string, string> = { "example-owner/example-repo#7": twoAc, "example-owner/example-repo#8": issueBody("- AC-1: Given one When checked Then it passes") };
const reader: IssueReader = (issue: ClosingIssue) => {
  const body = issues[`${issue.slug}#${issue.number}`];
  if (body === undefined) throw new Error(`unexpected read ${issue.slug}#${issue.number}`);
  return { code: "ex", body };
};

const associated = (rows: string) => `## 🔗 Associated issues

| Issue | Scope this PR implements | Merging this |
|---|---|---|
${rows}

Closes example-owner/example-repo#7
`;
const closing7 = "| https://github.com/example-owner/example-repo/issues/7 | the guard | **completes it** |";
const verify = (rows: string) => `## ✅ What the guards prove

| Behaviour changed | Lane or verb run | Refuses on | Passes on |
|---|---|---|---|
| a guard | nen shu test --lane criteria | a gap | a cover |

| Criterion | Coverage | Evidence |
|---|---|---|
${rows}
`;
const body = (verifyRows: string, issueRows = closing7) => `## 📬 Delivery

x

# What this changes for you

x

${verify(verifyRows)}
${associated(issueRows)}
## 🤖 Agent attribution

x
`;
const good = body("| EX#7/AC-1 | satisfied | scripts/x_fixture.mts: passes |\n| EX#7/AC-2 | partial | scripts/x.mts:12 |\n| none | unrequested | a renamed helper |");
const ids = (text: string, read = reader) => checkBody(text, read).refusals.map((r) => r.id);

// 1. A covered body passes; partial and unrequested are listed, never refused.
let report = checkBody(good, reader);
assert.equal(report.ok, true, JSON.stringify(report.refusals));
assert.deepEqual(report.closing, ["EX#7"]);
assert.deepEqual(report.counts, { criteria: 2, satisfied: 1, partial: 1, missing: 0, contradicts: 0, unrequested: 1, noRow: 0, notVerifiable: 0 });

// 2. AC ids: list rows only, comments and fences ignored, first-seen order, no duplicates.
assert.deepEqual(criteriaOf(twoAc), [1, 2]);
assert.deepEqual(criteriaOf("- AC-3: x\n  - AC-1: y\n- AC-3: again\nAC-4: not a row\n- AC-0: zero"), [3, 1]);

// 3. Refusals: a missing row, missing, contradicts, an unknown or twice-named criterion.
assert.deepEqual(ids(body("| EX#7/AC-1 | satisfied | t |")), ["no-row"]);
assert.deepEqual(ids(body("| EX#7/AC-1 | satisfied | t |\n| EX#7/AC-2 | missing | not built |")), ["missing"]);
assert.deepEqual(ids(body("| EX#7/AC-1 | contradicts | t |\n| EX#7/AC-2 | satisfied | t |")), ["contradicts"]);
assert.deepEqual(ids(body("| EX#7/AC-1 | satisfied | t |\n| EX#7/AC-2 | satisfied | t |\n| EX#7/AC-3 | satisfied | t |")), ["unknown-criterion"]);
assert.deepEqual(ids(body("| EX#7/AC-1 | satisfied | t |\n| ex#7/AC-1 | partial | t |\n| EX#7/AC-2 | satisfied | t |")), ["duplicate"]);
assert.deepEqual(ids(body("| EX#9/AC-1 | satisfied | t |\n| EX#7/AC-1 | satisfied | t |\n| EX#7/AC-2 | satisfied | t |")), ["unknown-criterion"]);

// 4. Row shape: vocabulary exact, evidence real, unrequested only on none.
for (const [row, id] of [
  ["| EX#7/AC-2 | Satisfied | t |", "coverage"], ["| EX#7/AC-2 | done | t |", "coverage"], ["| EX#7/AC-2 | satisfied |  |", "evidence"],
  ["| EX#7/AC-2 | satisfied | <test name> |", "evidence"], ["| EX#7/AC-2 | unrequested | t |", "row-shape"], ["| none | satisfied | t |", "row-shape"],
  ["| EX-7/AC-2 | satisfied | t |", "row-shape"], ["| EX#7/AC-2 | satisfied | t | extra |", "row-shape"],
] as const) {
  const refused = ids(body(`| EX#7/AC-1 | satisfied | t |\n${row}`));
  assert.ok(refused.includes(id), `${row}: ${refused.join(",")}`);
}

// 5. Not verifiable: a closing issue with no AC row is never a pass.
issues["example-owner/example-repo#5"] = "## Problem\n\nNo criteria here.\n";
report = checkBody(body("| EX#7/AC-1 | satisfied | t |\n| EX#7/AC-2 | satisfied | t |", `${closing7}\n| https://github.com/example-owner/example-repo/issues/5 | more | **closes it** |`), reader);
assert.equal(report.ok, false);
assert.deepEqual(report.refusals.map((r) => r.id), ["not-verifiable"]);
assert.equal(report.rows.find((r) => r.criterion === "EX#5")?.coverage, "not-verifiable");

// 6. The expected set is the closing rows only; non-closing rows are not read.
const nonClosing = "| https://github.com/example-owner/example-repo/issues/99 | context | **relates to it** |";
assert.deepEqual(ids(body("| EX#7/AC-1 | satisfied | t |\n| EX#7/AC-2 | satisfied | t |", `${closing7}\n${nonClosing}`)), []);
report = checkBody(body("| EX#8/AC-1 | satisfied | t |", "| [#8](https://github.com/example-owner/example-repo/issues/8) | x | **closes it** — a remark |"), reader);
assert.equal(report.ok, true, JSON.stringify(report.refusals));
assert.deepEqual(ids(body("", "| example-owner/example-repo#7 | x | **completes it** |")), ["issue-cell"]);
assert.deepEqual(ids(body("", "| https://github.com/example-owner/example-repo/pull/7 | x | **completes it** |")), ["issue-cell"]);

// 7. No closing issue: zero criteria, a pass; the table may be dropped.
report = checkBody(body("", nonClosing).replace(/\| Criterion[\s\S]*?\n\n/, ""), reader);
assert.equal(report.ok, true);
assert.equal(report.counts.criteria, 0);
assert.ok(ids(good.replace("## 🔗 Associated issues", "## Unrelated")).includes("issues-section"));
assert.deepEqual(ids(body("| EX#7/AC-1 | satisfied | t |", nonClosing)), ["unknown-criterion"], "a criterion row with no closing issue is never ignored");
assert.deepEqual(ids(body("| none | unrequested | a helper |", nonClosing)), []);
assert.ok(ids(`${good}\n## 🔗 Associated issues\n\nNo associated issue.\n`), ["issues-section"]);

// 8. The verify section and its one criteria table, with closing issues to cover.
assert.ok(ids(good.replace("## ✅ What the guards prove", "## Elsewhere")).includes("verify-section"));
assert.ok(ids(good.replace("| Criterion | Coverage | Evidence |", "| Criterion | Status | Evidence |")).includes("criteria-table"));
assert.ok(ids(good.replace("## ✅ What the guards prove", "## ✅ How to verify")).length === 0, "every kind's verify title is read");
assert.ok(ids(`<!--\n${good}\n-->`).includes("issues-section"), "a commented body is no body");
assert.ok(ids(good.replace("| Criterion | Coverage | Evidence |", "```\n| Criterion | Coverage | Evidence |").replace("| none | unrequested | a renamed helper |", "| none | unrequested | a renamed helper |\n```")).includes("criteria-table"), "a fenced table is no table");

// 9. CLI: --body, --pr and --json through a stub nen and a stub gh; exit codes 0, 1, 2, 3, 5.
const bin = join(dir, "bin");
mkdirSync(bin);
const argvLog = join(dir, "gh-argv");
const answers = join(dir, "answers");
mkdirSync(answers);
writeFileSync(join(bin, "gh"), `#!/bin/sh\nif [ "$1" = auth ]; then echo stub-token; exit 0; fi\nprintf '%s\\n' "$@" >> '${argvLog}'\n[ -f '${dir}/gh-fail' ] && exit 1\nf='${answers}/'$(printf '%s' "$4" | tr '/' '_')\n[ -f "$f" ] || exit 1\ncat "$f"\n`, { mode: 0o755 });
const nen = join(dir, "nen");
writeFileSync(nen, `#!/bin/sh\n[ "$3" = example-owner/unknown ] && { echo '{"repos":[]}'; exit 1; }\necho '{"token":"'"$3"'","repos":[{"repo":"'"$3"'","code":"EX"}]}'\n`, { mode: 0o755 });
const env = { ...process.env, PATH: `${bin}:${process.env.PATH}`, NEN: nen };
const run = (args: string[], e: NodeJS.ProcessEnv = env) => spawnSync(process.execPath, [script, ...args], { encoding: "utf8", env: e });
const answer = (path: string, value: unknown) => writeFileSync(join(answers, path.replace(/\//g, "_")), JSON.stringify(value));
answer("repos/example-owner/example-repo/issues/7", { number: 7, body: twoAc });
const goodFile = join(dir, "good.md");
writeFileSync(goodFile, good);
let r = run(["--body", goodFile]);
assert.equal(r.status, 0, r.stdout + r.stderr);
assert.match(r.stdout, /^criteria: EX#7\/AC-1 · satisfied · scripts\/x_fixture\.mts: passes\n/);
assert.match(r.stdout, /\ncriteria: ok · 2 criteria from 1 closing issue\(s\) · satisfied 1, partial 1, missing 0, contradicts 0, no row 0, not-verifiable 0, unrequested 1\n$/);
assert.ok(readFileSync(argvLog, "utf8").includes("repos/example-owner/example-repo/issues/7"));
const gapFile = join(dir, "gap.md");
writeFileSync(gapFile, body("| EX#7/AC-1 | satisfied | t |\n| EX#7/AC-2 | contradicts | AC-2 asks the opposite\u001b[2J\u202e |"));
r = run(["--body", gapFile, "--json"]);
assert.equal(r.status, 1);
const parsed = JSON.parse(r.stdout);
assert.equal(parsed.contract, "hatsu.pr-criteria-check/v1");
assert.equal(parsed.counts.contradicts, 1);
assert.ok(!r.stdout.includes("\u001b") && !r.stdout.includes("\u202e"), "hostile text is sanitised");
answer("repos/example-owner/example-repo/pulls/12", { number: 12, body: good });
r = run(["--pr", "example-owner/example-repo#12"]);
assert.equal(r.status, 0, r.stdout + r.stderr);
for (const args of [[], ["--body", goodFile, "--pr", "a/b#1"], ["--bogus"], ["--body"], ["--pr", "a/b-1"], ["--pr", "a/b#0"], ["--body", join(dir, "absent.md")]]) {
  r = run(args);
  assert.equal(r.status, 2, `${args.join(" ")}: ${r.stderr}`);
}
assert.equal(run(["--pr", "example-owner/example-repo#13"]).status, 3, "an unreadable PR is never a pass");
answer("repos/example-owner/example-repo/issues/7", { number: 7, body: twoAc, pull_request: { url: "x" } });
assert.equal(run(["--body", goodFile]).status, 3, "a pull request is not an issue");
answer("repos/example-owner/example-repo/issues/7", { number: 7, body: twoAc });
const unknownFile = join(dir, "unknown.md");
writeFileSync(unknownFile, good.replace(/example-repo\/issues\/7/, "unknown/issues/7").replace("example-owner/example-repo#7", "example-owner/unknown#7"));
assert.equal(run(["--body", unknownFile]).status, 3, "an unresolved code");
writeFileSync(join(dir, "gh-fail"), "");
assert.equal(run(["--body", goodFile]).status, 3, "a failed read is never a pass");
assert.equal(JSON.parse(run(["--body", goodFile, "--json"]).stdout).exit, 3);
assert.equal(run(["--body", goodFile], { ...env, NEN: join(dir, "no-such-nen") }).status, 5, "absent nen is a missing tool");
const bashOnly = join(dir, "bash-only");
mkdirSync(bashOnly);
spawnSync("ln", ["-s", spawnSync("sh", ["-c", "command -v bash"], { encoding: "utf8" }).stdout.trim(), join(bashOnly, "bash")]);
assert.equal(run(["--body", goodFile], { ...process.env, NEN: nen, PATH: bashOnly }).status, 5, "absent gh is a missing tool");

// 10. Wiring: the verify template carries the criteria table; the checked requirements array
// carries the verify-content row (an empty verify heading fails body-check).
const template = readFileSync(join(root, "templates/pr-body/verify.md"), "utf8");
assert.ok(template.includes("| Criterion | Coverage | Evidence |") && template.includes("satisfied · partial · missing · contradicts · unrequested"));
const requirements = JSON.parse(readFileSync(join(root, "contracts/pr-body.requirements.json"), "utf8")) as { name: string; pattern: string; content?: true }[];
const content = requirements.find((row) => row.name === "verify-content");
assert.ok(content?.content === true);
const contentRe = new RegExp(content.pattern, "im");
assert.ok(contentRe.test("## ✅ What the guards prove\n\n<!-- c -->\n| a |"));
assert.ok(!contentRe.test("## ✅ What the guards prove\n\n<!-- c\nd -->\n\n## 🔗 Associated issues\n"));

// 11. contracts/hanten-findings.schema.json: the disposition contract (HR-10).
const schema = JSON.parse(readFileSync(join(root, "contracts/hanten-findings.schema.json"), "utf8"));
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

console.log("criteria: closing-issue derivation, AC ids, every refusal, not-verifiable, the verify table, CLI exit codes 0/1/2/3/5, sanitising, template and requirements wiring, and the findings schema passed");
