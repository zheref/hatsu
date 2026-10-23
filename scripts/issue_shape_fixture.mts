#!/usr/bin/env node
// Fixture for lane issue-shape (HR-4): nen's verdict and Hatsu's catalogue agree.
//
// From nen 0.26.0 the issue shape is read by `nen issue body-check --requirements-from
// contracts/issue-sections.json` and the open questions by `nen issue questions` (zheref/nen#476,
// #477); Hatsu's interim reader, scripts/issue_body_check.mts, retired with the adoption
// (zheref/hatsu#423, criterion 4). What this lane proves is the seam the skills rest on:
//   - every kind in the catalogue has its template under templates/issue-body/, each template carries
//     exactly its kind's headings, and the verb refuses it unfilled (every section EMPTY);
//   - a filled body passes with its AC/SC/AS/OQ rows numbered, and the verb's misses are the
//     catalogue's own (a missing section, a row out of shape or order, an unmeasured SC row);
//   - a vague adjective is an advisory, never a miss; no --kind reads the `common` list;
//   - an open `OQ-{n}` row is NOT a body-check miss -- it is `nen issue questions`' count, the one the
//     skills read (an open row is build § 2's G1 and futon § 2's skip); a resolved row needs the
//     catalogue's dated shape with the typographic arrow, an ASCII `->` is unrecognised;
//   - the exits the skills branch on: 0 clean, 1 with the verdict line on stdout for misses, 1 with
//     EMPTY stdout and `could not read` on stderr when --ref's issue is unreadable (never a pass), 2
//     for a pull-request number, an undeclared kind or a malformed catalogue.
// Offline: --ref runs against a stub gh on PATH; bodies carry placeholder slugs only. nen itself is
// real -- the verified binary CI hands this runner as NEN (scripts/unit_tests_ci.mts), else PATH's;
// none at all is exit 5 (docs/PROCESS.md § Exit codes and refusals), never a pass.
import assert from "node:assert/strict";
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const root = join(import.meta.dirname, "..");
const cataloguePath = join(root, "contracts", "issue-sections.json");
const catalogue = JSON.parse(readFileSync(cataloguePath, "utf8")) as {
  sections: Record<string, { heading: string }>;
  common: string[];
  kinds: Record<string, { template: string; required: string[]; optional: string[] }>;
};
const dir = mkdtempSync(join(tmpdir(), "hatsu-issue-shape-"));
const nen = process.env.NEN ?? "nen";
const probe = spawnSync(nen, ["--version"], { encoding: "utf8" });
if (probe.error || probe.status !== 0) {
  console.error(`issue-shape: nen is not reachable as '${nen}' -- a missing tool is exit 5, never a pass`);
  process.exit(5);
}

const bin = join(dir, "bin");
mkdirSync(bin);
const answers = join(dir, "answers");
mkdirSync(answers);
// The stub answers `gh api repos/<slug>/issues/<n>` from a file per path and nothing else: an absent
// file is gh's 404, the read failure nen reports at exit 1 with no verdict.
writeFileSync(join(bin, "gh"), `#!/bin/sh
if [ "$1" = auth ]; then echo stub-token; exit 0; fi
f='${answers}/'$(printf '%s' "$2" | tr '/' '_')
if [ "$1" = api ] && [ -f "$f" ]; then cat "$f"; exit 0; fi
echo "gh: Not Found (HTTP 404)" >&2; exit 1
`);
chmodSync(join(bin, "gh"), 0o755);
const env = { ...process.env, PATH: `${bin}:${process.env.PATH ?? ""}` };
const run = (verb: "body-check" | "questions", args: string[]) =>
  spawnSync(nen, ["issue", verb, ...args, "--requirements-from", cataloguePath, "--repo", dir, "--json"], { encoding: "utf8", env });
const file = (name: string, text: string) => { const p = join(dir, name); writeFileSync(p, text); return p; };
const check = (text: string, kind: string | null, name = "body.md") => {
  const r = run("body-check", ["--body-file", file(name, text), ...(kind === null ? [] : ["--kind", kind])]);
  assert.ok(r.status === 0 || r.status === 1, `${name}: exit ${r.status}: ${r.stderr}`);
  const report = JSON.parse(r.stdout) as { ok: boolean; kind: string; misses: { section: string | null; kind: string; line: number | null }[]; rows: { id: string; number: number }[]; advisories: { kind: string; word: string }[] };
  assert.equal(report.ok, r.status === 0, `${name}: ok disagrees with the exit`);
  return report;
};
const missKinds = (text: string, kind: string | null = "machinery") => check(text, kind).misses.map((m) => m.kind);
const questions = (text: string) => {
  const r = run("questions", ["--body-file", file("q.md", text)]);
  assert.equal(r.status, 0, `questions never decides: ${r.stderr}`);
  return JSON.parse(r.stdout) as { counts: { open: number; resolved: number; needsMarkers: number; unrecognised: number }; open: { number: number; gate: string }[] };
};

// 1. Every kind has its template, each carries exactly its catalogue headings, and unfilled it is refused
// with every section read EMPTY (a comment-only section is no content).
const kinds = Object.keys(catalogue.kinds);
assert.deepEqual(readdirSync(join(root, "templates", "issue-body")).sort(), kinds.map((k) => `${k}.md`).sort());
for (const kind of kinds) {
  const spec = catalogue.kinds[kind];
  assert.equal(spec.template, `templates/issue-body/${kind}.md`, `${kind}: template path`);
  const template = readFileSync(join(root, spec.template), "utf8");
  const headings = [...template.matchAll(/^## (.+)$/gm)].map((m) => m[1]).sort();
  const expected = [...spec.required, ...spec.optional].map((id) => catalogue.sections[id].heading).sort();
  assert.deepEqual(headings, expected, `${kind}: the template's headings are the catalogue's`);
  const report = check(template, kind, `${kind}-template.md`);
  assert.equal(report.ok, false, `${kind}: an unfilled template is refused`);
  assert.deepEqual([...new Set(report.misses.map((m) => m.kind))], ["empty"], `${kind}: every miss is an empty section`);
  assert.deepEqual(report.misses.map((m) => m.section).sort(), [...spec.required, ...spec.optional].sort(), `${kind}: every section of the template is read`);
}

// 2. A filled machinery body passes: rows numbered per section, the resolved question counted, the
// vague word an advisory.
const oqLine = "- ~~OQ-1~~ → A: the build stops (2026-10-21, HR-4)";
const good = `## Problem

A placeholder guard lets an unshaped issue through.

## Audience and why

The maintainer, who reads the register.

## Failing run

<run link placeholder>; the guard should have refused.

## Acceptance criteria

- AC-1: Given an issue with an open question When a build is asked for Then the build stops before authoring
- AC-2: Given an issue without open questions When a build is asked for Then the build proceeds

## Success criteria

- SC-1: 100% of open-question issues are listed as needs-clarification
- SC-2: 0 issues authored while a question is open

## Assumptions

- AS-1: one maintainer answers questions — derived from the roster

## Open questions

${oqLine}

## Scope boundaries

In scope: the check. Out of scope: answering questions.

## Cross-references

<placeholder-owner>/<placeholder-repo>#1

## Plan notes

Run the check with --ref before the plan; contracts/issue-sections.json owns the shape.
`;
let report = check(good, "machinery");
assert.equal(report.ok, true, JSON.stringify(report.misses));
assert.deepEqual(report.rows.map((r) => [r.id, r.number]), [["AC-1", 1], ["AC-2", 2], ["SC-1", 1], ["SC-2", 2], ["AS-1", 1], ["OQ-1", 1]]);
assert.deepEqual(questions(good).counts, { open: 0, resolved: 1, needsMarkers: 0, unrecognised: 0 });

// 3. Sections: a required heading renamed is `missing`; an optional heading present and empty is `empty`;
// `None.` is admitted only where the catalogue says `none`; a heading inside a fence is no heading;
// no --kind reads the `common` list, so a kind-only section may be absent there.
assert.deepEqual(missKinds(good.replace("## Scope boundaries", "## Scope")), ["missing"]);
assert.deepEqual(missKinds(`${good}\n## Key entities\n\n`), ["empty"]);
assert.deepEqual(missKinds(good.replace("- AS-1: one maintainer answers questions — derived from the roster", "None.")), []);
assert.deepEqual(missKinds(good.replace("In scope: the check. Out of scope: answering questions.", "None.")), []);
assert.deepEqual(missKinds(good.replace("## Scope boundaries", "```\n## Scope boundaries\n```")), ["missing"]);
assert.deepEqual(missKinds(good.replace("## Failing run", "## Evidence"), null), [], "no --kind reads common only");
assert.equal(check(good.replace("## Failing run", "## Evidence"), null).kind, "common");
assert.deepEqual(missKinds(good.replace("## Failing run", "## Evidence")), ["missing"]);
assert.ok(!check(good, "product").ok, "product requires its own sections");

// 4. Rows: shape, order and measure are the catalogue's patterns; a vague adjective is an advisory.
assert.deepEqual(missKinds(good.replace("- AC-2:", "- AC-3:")), ["row-order"]);
assert.deepEqual(missKinds(good.replace("- AC-2: Given", "- AC-2: When")), ["row-shape"]);
assert.deepEqual(missKinds(good.replace("- AC-2:", "- a stray item\n- AC-2:")), ["row-shape"]);
assert.deepEqual(missKinds(good.replace(/- AC-1.*\n- AC-2.*\n/, "Prose only.\n")), ["no-rows"]);
assert.deepEqual(missKinds(good.replace("- SC-2: 0 issues", "- SC-2: no issues")), ["row-unmeasurable"]);
assert.deepEqual(missKinds(good.replace(" — derived from the roster", "")), ["row-shape"]);
report = check(good.replace("Then the build proceeds", "Then the build proceeds quickly"), "machinery");
assert.equal(report.ok, true, "a vague adjective is an advisory, never a miss");
assert.deepEqual(report.advisories.map((a) => `${a.kind}:${a.word}`).filter((a) => a.endsWith(":quickly")), ["vague:quickly"]);

// 5. Questions: an open row is counted by `questions` and is no body-check miss (the skills read the
// count); a malformed row is a row-shape miss and unrecognised; an ASCII arrow is not resolved.
const open = good.replace(oqLine, "- OQ-1 (G1): does the build stop?\n- ~~OQ-2~~ → A: yes (2026-10-21, HR-4)");
assert.deepEqual(missKinds(open), [], "an open question is not the body-check's miss");
const counted = questions(open);
assert.deepEqual(counted.counts, { open: 1, resolved: 1, needsMarkers: 0, unrecognised: 0 });
assert.deepEqual(counted.open.map((q) => [q.number, q.gate]), [[1, "G1"]]);
assert.deepEqual(missKinds(good.replace(oqLine, "- OQ-1: no gate named?")), ["row-shape"]);
assert.equal(questions(good.replace(oqLine, "- OQ-1: no gate named?")).counts.unrecognised, 1);
assert.deepEqual(missKinds(good.replace(oqLine, "- ~~OQ-1~~ → A: undated (HR-4)")), ["row-shape"]);
assert.deepEqual(questions(good.replace("→", "->")).counts, { open: 0, resolved: 0, needsMarkers: 0, unrecognised: 1 });
assert.equal(questions(good.replace(oqLine, "None.\n\n[NEEDS CLARIFICATION: which gate?]")).counts.needsMarkers, 1);

// 6. Exits: an undeclared kind and a malformed catalogue are 2; --ref reads through gh, a 404 is exit 1
// with no verdict on stdout (could not look is never found nothing), and a pull request is exit 2.
let r = run("body-check", ["--body-file", file("k.md", good), "--kind", "feature"]);
assert.equal(r.status, 2, `an undeclared kind: ${r.stderr}`);
r = spawnSync(nen, ["issue", "body-check", "--body-file", file("k.md", good), "--requirements-from", file("bad.json", "{"), "--repo", dir], { encoding: "utf8", env });
assert.equal(r.status, 2, `a malformed catalogue: ${r.stderr}`);
writeFileSync(join(answers, "repos_placeholder-owner_placeholder-repo_issues_7"), JSON.stringify({ number: 7, body: good }));
writeFileSync(join(answers, "repos_placeholder-owner_placeholder-repo_issues_8"), JSON.stringify({ number: 8, body: "x", pull_request: { url: "x" } }));
const ref = (verb: "body-check" | "questions", n: number, kind?: string) =>
  run(verb, ["--ref", `EX#${n}`, "--target", "placeholder-owner/placeholder-repo", ...(kind ? ["--kind", kind] : [])]);
r = ref("body-check", 7, "machinery");
assert.equal(r.status, 0, `--ref through the stub: ${r.stderr}`);
assert.equal((JSON.parse(r.stdout) as { source: { kind: string; number: number } }).source.number, 7);
assert.equal(ref("questions", 7).status, 0);
r = ref("body-check", 9);
assert.equal(r.status, 1, "an unreadable issue is exit 1");
assert.equal(r.stdout, "", "an unreadable issue prints no verdict");
assert.match(r.stderr, /could not read/);
r = ref("questions", 9);
assert.equal(r.status, 1);
assert.equal(r.stdout, "", "questions prints no counts for an unread issue");
assert.equal(ref("body-check", 8).status, 2, "a pull request is not an issue");
assert.equal(ref("questions", 8).status, 2);

console.log(`issue-shape: nen ${probe.stdout.trim()} -- templates per kind, required and optional headings, AC/SC/AS/OQ rows, advisories, question counts, and the exits 0/1/2 with the no-verdict read failure passed`);
