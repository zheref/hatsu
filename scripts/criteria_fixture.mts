#!/usr/bin/env node
// Fixture for lane criteria (HR-11, HR-10): acceptance-criterion coverage is `nen pr converge`'s
// verdict, and Hatsu's body shape satisfies it.
//
// From nen 0.26.0 the readiness conjunct en §§ 4-5, rikugan § 3 and shibari § 4 read is
// `nen pr converge --target <owner/name> --pr <n> --requirements-from contracts/issue-sections.json`
// (zheref/nen#483, #498); Hatsu's interim guard, scripts/pr_criteria_check.mts, retired with it
// (zheref/hatsu#413). This lane holds the verb to the rows Hatsu's templates write and reproduces the
// guard's cases against the verb (hatsu#413, SC-2): the closing issues GitHub lists (or the body's
// closing keywords off the default branch), the `- AC-{n}:` rows of each, the one verify-row grammar
// of templates/pr-body/verify.md, every row that blocks -- a missing, malformed or duplicated row, the
// words `missing` and `contradicts`, `unrequested` on a criterion, a `none` row with a problem, a row
// without evidence, an unmatched or ambiguous criterion, a closing issue stating no criterion (never a
// pass) or an unrecognised AC row, a non-default base whose body names no closing issue -- and the two
// shapes a careless body trips: a table outside the verify section whose first cell mentions `AC-`
// reads as a malformed verify row (seen live on HA-PR-#433), and the brief's `contracts/pr-sections.json`
// is not the catalogue this verb reads (exit 2). Also holds contracts/hanten-findings.schema.json's
// structural invariants (HR-10) and the verify template / requirements wiring, as the guard's lane did.
// Offline: gh is a stub on PATH answering `pr view`, `repo view` and `api repos/<slug>/issues/<n>` from
// files; bodies carry placeholder slugs only. nen is real -- CI's verified NEN, else PATH's; none is
// exit 5, never a pass.
import assert from "node:assert/strict";
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const root = join(import.meta.dirname, "..");
const cataloguePath = join(root, "contracts", "issue-sections.json");
const dir = mkdtempSync(join(tmpdir(), "hatsu-criteria-"));
const nen = process.env.NEN ?? "nen";
const probe = spawnSync(nen, ["--version"], { encoding: "utf8" });
if (probe.error || probe.status !== 0) {
  console.error(`criteria: nen is not reachable as '${nen}' -- a missing tool is exit 5, never a pass`);
  process.exit(5);
}

const slug = "placeholder-owner/placeholder-repo";
const bin = join(dir, "bin");
const answers = join(dir, "answers");
mkdirSync(bin);
mkdirSync(answers);
writeFileSync(join(bin, "gh"), `#!/bin/sh
if [ "$1" = auth ]; then echo stub-token; exit 0; fi
case "$1 $2" in
  "pr view") f='${answers}/pr-'"$3" ;;
  "repo view") f='${answers}/repo' ;;
  "api "*) f='${answers}/'$(printf '%s' "$2" | tr '/' '_') ;;
  *) f=/nonexistent ;;
esac
if [ -f "$f" ]; then cat "$f"; exit 0; fi
echo "gh: Not Found (HTTP 404)" >&2; exit 1
`);
chmodSync(join(bin, "gh"), 0o755);
const env = { ...process.env, PATH: `${bin}:${process.env.PATH ?? ""}` };
writeFileSync(join(answers, "repo"), JSON.stringify({ defaultBranchRef: { name: "main" } }));
const issueBody = (rows: string) => `## Problem\n\nA placeholder.\n\n## Acceptance criteria\n\n${rows}\n\n<!-- - AC-9: Given a commented row When read Then it is ignored -->\n\`\`\`\n- AC-8: Given a fenced row When read Then it is ignored\n\`\`\`\n`;
const twoAc = issueBody("- AC-1: Given a body When checked Then it passes\n- AC-2: Given a gap When checked Then it fails");
const issue = (n: number, body: string, pullRequest = false) =>
  writeFileSync(join(answers, `repos_${slug.replace("/", "_")}_issues_${n}`), JSON.stringify(pullRequest ? { number: n, body, pull_request: { url: "x" } } : { number: n, body }));
issue(7, twoAc);
issue(8, issueBody("- AC-1: Given one When checked Then it passes"));
issue(5, "## Problem\n\nNo criteria here.\n");
issue(6, issueBody("- AC-1: Given a row When read Then it counts\n- AC-2 no colon, so unrecognised"));
issue(9, "x", true);
const reference = (n: number) => ({ number: n, repository: { owner: { login: "placeholder-owner" }, name: "placeholder-repo" }, url: `https://github.com/${slug}/issues/${n}` });
const verify = (rows: string) => `## ✅ What the guards prove\n\n| Behaviour changed | Lane or verb run | Refuses on | Passes on |\n|---|---|---|---|\n| a guard | nen shu test --lane criteria | a gap | a cover |\n\n| Criterion | Coverage | Evidence |\n|---|---|---|\n${rows}\n`;
const associated = (rows: string, closes = `Closes ${slug}#7`) => `## 🔗 Associated issues\n\n| Issue | Scope this PR implements | Merging this |\n|---|---|---|\n${rows}\n\n${closes}\n`;
const closing7 = `| https://github.com/${slug}/issues/7 | the guard | **completes it** |`;
const body = (verifyRows: string, issueRows = closing7, closes?: string) => `## 📬 Delivery\n\nx\n\n# What this changes for you\n\nx\n\n${verify(verifyRows)}\n${associated(issueRows, closes)}\n## 🤖 Agent attribution\n\nx\n`;
const good = body("| EX#7/AC-1 | satisfied | scripts/x_fixture.mts: passes |\n| EX#7/AC-2 | partial | scripts/x.mts:12 |\n| none | unrequested | a renamed helper |");

type Report = { verifiable: boolean; closingSource: string; criteria: { id: string | null; coverage: string; word: string | null }[]; unrequested: { problem: string | null }[]; unmatched: { reason: string }[]; malformed: { cell: string }[]; blocking: string[]; counts: Record<string, number> & { words: Record<string, number> } };
let pr = 0;
const converge = (prBody: string, closing: unknown[] = [reference(7)], base = "main", extra: string[] = []) => {
  pr += 1;
  writeFileSync(join(answers, `pr-${pr}`), JSON.stringify({ number: pr, url: `https://github.com/${slug}/pull/${pr}`, headRefOid: "a".repeat(40), baseRefName: base, body: prBody, closingIssuesReferences: closing }));
  const r = spawnSync(nen, ["pr", "converge", "--target", slug, "--pr", String(pr), "--requirements-from", cataloguePath, "--repo", dir, "--json", ...extra], { encoding: "utf8", env });
  assert.ok(r.status === 0 || r.status === 1, `pr ${pr}: exit ${r.status}: ${r.stderr}`);
  return { status: r.status, stdout: r.stdout, stderr: r.stderr, report: r.stdout ? (JSON.parse(r.stdout) as Report) : null };
};
const blocking = (prBody: string, closing: unknown[] = [reference(7)], base = "main") => {
  const r = converge(prBody, closing, base);
  assert.equal(r.status, 1, `expected a blocking row: ${r.stdout}`);
  assert.ok(r.report && r.report.blocking.length > 0, "exit 1 names what blocks");
  return r.report as Report;
};

// 1. A covered body passes: satisfied and partial with evidence, the none row listed, nothing blocking.
let r = converge(good);
assert.equal(r.status, 0, r.stdout + r.stderr);
assert.deepEqual(r.report?.criteria.map((c) => `${c.id}:${c.coverage}:${c.word}`), ["AC-1:covered-with-evidence:satisfied", "AC-2:covered-with-evidence:partial"]);
assert.equal(r.report?.unrequested.length, 1);
assert.equal(r.report?.closingSource, "github");

// 2. Every row that blocks, one case each; the guard's refusals reproduced against the verb.
let report = blocking(body("| EX#7/AC-1 | satisfied | t |"));
assert.equal(report.counts["missing-row"], 1);
report = blocking(body("| EX#7/AC-1 | satisfied | t |\n| EX#7/AC-2 | missing | not built |"));
assert.equal(report.counts.words.missing, 1);
report = blocking(body("| EX#7/AC-1 | contradicts | t |\n| EX#7/AC-2 | satisfied | t |"));
assert.equal(report.counts.words.contradicts, 1);
report = blocking(body("| EX#7/AC-1 | satisfied | t |\n| EX#7/AC-2 | satisfied | t |\n| EX#7/AC-3 | satisfied | t |"));
assert.equal(report.unmatched.length, 1, "a criterion no closing issue states is unmatched");
report = blocking(body("| EX#7/AC-1 | satisfied | t |\n| ex#7/AC-1 | partial | t |\n| EX#7/AC-2 | satisfied | t |"));
assert.equal(report.counts["duplicate-rows"], 1);
report = blocking(body("| EX#7/AC-1 | satisfied | t |\n| EX#7/AC-2 | satisfied |  |"));
assert.equal(report.counts["covered-without-evidence"], 1, "evidence is required");
report = blocking(body("| EX#7/AC-1 | satisfied | t |\n| EX#7/AC-2 | satisfied | <test name> |"));
assert.equal(report.counts["covered-without-evidence"], 1, "a template placeholder is no evidence");
for (const row of ["| EX#7/AC-2 | done | t |", "| EX#7/AC-2 | Satisfied | t | extra |"]) {
  report = blocking(body(`| EX#7/AC-1 | satisfied | t |\n${row}`));
  assert.equal(report.counts["malformed-row"], 1, row);
}
report = blocking(body("| EX#7/AC-1 | satisfied | t |\n| EX#7/AC-2 | unrequested | t |"));
assert.equal(report.counts.words.unrequested, 1, "unrequested on a criterion blocks");
report = blocking(body("| EX#7/AC-1 | satisfied | t |\n| EX#7/AC-2 | satisfied | t |\n| none | satisfied | t |"));
assert.ok(report.unrequested[0]?.problem, "a none row must say unrequested");
report = blocking(body("| EX#7/AC-1 | satisfied | t |\n| EX#7/AC-2 | satisfied | t |\n| none | unrequested |  |"));
assert.ok(report.unrequested[0]?.problem, "a none row without evidence is a problem");
report = blocking(body("| EX-7/AC-2 | satisfied | t |\n| EX#7/AC-1 | satisfied | t |\n| EX#7/AC-2 | satisfied | t |"));
assert.equal(report.malformed.length, 1, "a first cell mentioning AC- in no admitted spelling is malformed, never skipped");

// 3. Not verifiable: a closing issue with no AC row is never a pass; an unrecognised AC row blocks;
// a closing number naming a pull request is a read failure (exit 1, no verdict).
report = blocking(body("| EX#7/AC-1 | satisfied | t |\n| EX#7/AC-2 | satisfied | t |", `${closing7}\n| https://github.com/${slug}/issues/5 | more | **closes it** |`), [reference(7), reference(5)]);
assert.equal(report.verifiable, false);
assert.equal(report.counts["not-verifiable"], 1);
report = blocking(body("| EX#6/AC-1 | satisfied | t |", `| https://github.com/${slug}/issues/6 | x | **closes it** |`, `Closes ${slug}#6`), [reference(6)]);
assert.ok(report.blocking.some((b) => /unrecognised/i.test(b)), report.blocking.join(" | "));
r = converge(good, [reference(9)]);
assert.equal(r.status, 1);
assert.equal(r.stdout, "", "a closing number naming a pull request prints no verdict");

// 4. The closing set: GitHub's list on the default branch; a PR closing no issue passes as not
// verifiable (verifiable: false, exit 0); off the default branch the body's keywords name the issues,
// and a body naming none there is a blocking row.
r = converge(body("| none | unrequested | a helper |", `| https://github.com/${slug}/issues/99 | context | **relates to it** |`, ""), []);
assert.equal(r.status, 0, r.stdout + r.stderr);
assert.deepEqual([r.report?.verifiable, r.report?.closingSource, r.report?.criteria.length], [false, "none", 0]);
r = converge(good, [], "integration/sdd");
assert.equal(r.status, 0, `body keywords off the default branch: ${r.stdout}${r.stderr}`);
assert.equal(r.report?.closingSource, "body-keywords");
r = converge(body("| none | unrequested | a helper |", closing7, ""), [], "integration/sdd");
assert.equal(r.status, 1, "a non-default base with no closing keyword cannot tell what it closes");
assert.equal(r.report?.closingSource, "none-on-non-default-base");

// 5. A bare AC-{n} names the one closing issue stating it; two closing issues both stating it make the
// row ambiguous (unmatched), nen will not pick.
r = converge(body("| AC-1 | satisfied | t |\n| AC-2 | satisfied | t |"));
assert.equal(r.status, 0, `bare ids: ${r.stdout}${r.stderr}`);
report = blocking(body("| AC-1 | satisfied | t |\n| EX#7/AC-2 | satisfied | t |\n| EX#8/AC-1 | satisfied | t |", `${closing7}\n| https://github.com/${slug}/issues/8 | more | **closes it** |`), [reference(7), reference(8)]);
assert.ok(report.unmatched.some((u) => /ambiguous|two|both/i.test(u.reason)), JSON.stringify(report.unmatched));

// 6. The live HA-PR-#433 shape: a table OUTSIDE the verify section whose first cell mentions `AC-`
// is read as a malformed verify row. The body rule (docs/PR-SECTIONS.md) follows from this case.
report = blocking(`${good}\n## Notes\n\n| What | Where |\n|---|---|\n| The waiver (AC-2) | en § 5 |\n`);
assert.ok(report.malformed.some((m) => m.cell.includes("AC-2")), "a first cell naming AC- outside the verify table is malformed");

// 7. Exits 2: usage, and the catalogue is the issue-sections one -- pr-sections.json is refused.
for (const args of [["pr", "converge", "--pr", "1"], ["pr", "converge", "--target", slug], ["pr", "converge", "--target", slug, "--pr", "0"], ["pr", "converge", "--target", slug, "--pr", "1", "--requirements-from", join(root, "contracts", "pr-sections.json")]]) {
  const usage = spawnSync(nen, [...args, "--repo", dir], { encoding: "utf8", env });
  assert.equal(usage.status, 2, `${args.join(" ")}: exit ${usage.status} ${usage.stderr}`);
}
rmSync(join(answers, "pr-1"));
const unread = spawnSync(nen, ["pr", "converge", "--target", slug, "--pr", "1", "--requirements-from", cataloguePath, "--repo", dir], { encoding: "utf8", env });
assert.equal(unread.status, 1, "an unreadable pull request is exit 1");
assert.equal(unread.stdout, "", "could not read prints no verdict");

// 8. Wiring: the verify template carries the criteria table and the checked requirements carry the
// verify-content row (an empty verify heading fails body-check).
const template = readFileSync(join(root, "templates/pr-body/verify.md"), "utf8");
assert.ok(template.includes("| Criterion | Coverage | Evidence |") && template.includes("satisfied · partial · missing · contradicts · unrequested"));
const requirements = JSON.parse(readFileSync(join(root, "contracts/pr-body.requirements.json"), "utf8")) as { name: string; pattern: string; content?: true }[];
const content = requirements.find((row) => row.name === "verify-content");
assert.ok(content?.content === true);
const contentRe = new RegExp(content.pattern, "im");
assert.ok(contentRe.test("## ✅ What the guards prove\n\n<!-- c -->\n| a |"));
assert.ok(!contentRe.test("## ✅ What the guards prove\n\n<!-- c\nd -->\n\n## 🔗 Associated issues\n"));

// 9. contracts/hanten-findings.schema.json: the disposition contract (HR-10).
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

console.log(`criteria: nen ${probe.stdout.trim()} pr converge -- the covered body, every blocking row, not-verifiable, the closing set on and off the default branch, bare and ambiguous ids, the out-of-section AC- cell, exits 1/2, the verify wiring and the findings schema passed`);
