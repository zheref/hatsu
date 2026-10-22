#!/usr/bin/env node
// Hermetic fixture for scripts/issue_body_check.mts (lane issue-shape; HR-4).
// Offline: --ref runs against a stub nen (NEN) and a stub gh on PATH. Bodies
// carry placeholder slugs only.
import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import { checkBody, loadCatalogue } from "./issue_body_check.mts";

const here = import.meta.dirname;
const root = join(here, "..");
const script = join(here, "issue_body_check.mts");
const catalogue = loadCatalogue();
const dir = mkdtempSync(join(tmpdir(), "hatsu-issue-shape-"));
const ids = (body: string, kind: string | null = "machinery") => checkBody(body, kind, catalogue).misses.map((m) => m.id);

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

- ~~OQ-1~~ → A: the build stops (2026-10-21, HR-4)

## Scope boundaries

In scope: the check. Out of scope: answering questions.

## Cross-references

<placeholder-owner>/<placeholder-repo>#1

## Plan notes

Run the check with --ref before the plan; contracts/issue-sections.json owns the shape.
`;

// 1. A filled body passes, its rows and questions counted.
const pass = checkBody(good, "machinery", catalogue);
assert.equal(pass.ok, true, JSON.stringify(pass.misses));
assert.deepEqual(pass.rows, { acceptance: 2, success: 2, assumptions: 1 });
assert.deepEqual([pass.questions.open, pass.questions.resolved], [0, 1]);

// 2. Every template exists for every kind, carries exactly its kind's headings, and fails unfilled.
assert.deepEqual(readdirSync(join(root, "templates", "issue-body")).sort(), Object.keys(catalogue.kinds).map((k) => `${k}.md`).sort());
for (const [kind, spec] of Object.entries(catalogue.kinds)) {
  const template = readFileSync(join(root, "templates", "issue-body", `${kind}.md`), "utf8");
  const headings = [...template.matchAll(/^## (.+)$/gm)].map((m) => m[1]).sort();
  assert.deepEqual(headings, [...spec.required, ...spec.optional].map((id) => catalogue.sections[id].heading).sort(), kind);
  const unfilled = checkBody(template, kind, catalogue);
  assert.equal(unfilled.ok, false);
  assert.equal(unfilled.misses.filter((m) => m.id === "empty-section").length, spec.required.length + spec.optional.length, kind);
  assert.equal((spec as { template?: string }).template, `templates/issue-body/${kind}.md`);
}

// 3. Required headings: missing, duplicated, empty; optional present-and-empty; None. admitted only where declared.
assert.deepEqual(ids(good.replace("## Scope boundaries", "## Scope")), ["missing-section"]);
assert.deepEqual(ids(`${good}\n## Problem\n\nagain\n`), ["duplicate-section"]);
assert.deepEqual(ids(good.replace("In scope: the check. Out of scope: answering questions.", "<!-- only a comment -->")), ["empty-section"]);
assert.deepEqual(ids(`${good}\n## Key entities\n\n`), ["empty-section"]);
assert.deepEqual(ids(good.replace("- AS-1: one maintainer answers questions — derived from the roster", "None.")), []);
assert.deepEqual(ids(good.replace("In scope: the check. Out of scope: answering questions.", "None.")), []);
assert.deepEqual(ids(good.replace("## Scope boundaries", "```\n## Scope boundaries\n```")), ["missing-section"]);
assert.deepEqual(ids(good.replace("## Failing run", "## Evidence"), null), [], "no --kind reads common only");
assert.deepEqual(ids(good.replace("## Failing run", "## Evidence")), ["missing-section"]);

// 4. AC rows: shape, numbering, vague adjectives, technology terms.
assert.deepEqual(ids(good.replace("- AC-2:", "- AC-3:")), ["numbering"]);
assert.deepEqual(ids(good.replace("- AC-2: Given", "- AC-2: When")), ["row-shape"]);
assert.deepEqual(ids(good.replace("Then the build proceeds", "Then the build proceeds quickly")), ["ac-vague"]);
assert.deepEqual(ids(good.replace("Then the build proceeds", "Then the JSON report proceeds")), ["ac-technology"]);
assert.deepEqual(ids(good.replace("Then the build proceeds", "Then it runs with --ref")), ["ac-technology"]);
assert.deepEqual(ids(good.replace("Then the build proceeds", "Then claude/skills/build is read")), ["ac-technology"]);
assert.deepEqual(ids(good.replace("Then the build proceeds", "Then `the build` proceeds")), ["ac-technology"]);
assert.deepEqual(ids(good.replace("Then the build proceeds", "Then the Given/When/Then shape holds")), [], "a capitalised slash list is not a path");
assert.deepEqual(ids(good.replace(/- AC-1.*\n- AC-2.*\n/, "Prose only.\n")), ["no-rows"]);
assert.deepEqual(ids(good.replace("- AC-2:", "- a stray item\n- AC-2:")), ["row-shape"]);

// 5. SC rows carry a number or a percentage.
assert.deepEqual(ids(good.replace("- SC-2: 0 issues", "- SC-2: no issues")), ["sc-measure"]);
assert.deepEqual(ids(good.replace("- SC-2:", "- SC-4:")), ["numbering"]);

// 6. AS rows name their source.
assert.deepEqual(ids(good.replace(" — derived from the roster", "")), ["row-shape"]);

// 7. Open questions: counted, a miss each; resolved rows counted; malformed rows refused.
const open = checkBody(good.replace("- ~~OQ-1~~ → A: the build stops (2026-10-21, HR-4)", "- OQ-1 (G1): does the build stop?\n- ~~OQ-2~~ → A: yes (2026-10-21, HR-4)"), "machinery", catalogue);
assert.deepEqual(open.misses.map((m) => m.id), ["open-question"]);
assert.deepEqual([open.questions.open, open.questions.resolved], [1, 1]);
assert.deepEqual(open.questions.openRows.map((r) => [r.n, r.gate]), [[1, "G1"]]);
assert.deepEqual(ids(good.replace("- ~~OQ-1~~ → A: the build stops (2026-10-21, HR-4)", "- OQ-1: no gate named?")), ["row-shape"]);
assert.deepEqual(ids(good.replace("- ~~OQ-1~~ → A: the build stops (2026-10-21, HR-4)", "- ~~OQ-1~~ → A: undated (HR-4)")), ["row-shape"]);
assert.deepEqual(ids(good.replace("- ~~OQ-1~~ → A: the build stops (2026-10-21, HR-4)", "- what about later?")), ["row-shape"]);
assert.deepEqual(ids(good.replace("- ~~OQ-1~~", "- ~~OQ-2~~")), ["numbering"]);
assert.equal(checkBody(good.replace("does", "x"), "product", catalogue).ok, false, "product requires its own sections");
const oqLine = "- ~~OQ-1~~ → A: the build stops (2026-10-21, HR-4)";
assert.deepEqual(ids(good.replace(oqLine, "OQ-1 (G1): written as prose?")), ["row-shape"], "a row id outside a list item fails closed");
assert.deepEqual(ids(good.replace(oqLine, "1. OQ-1 (G1): a numbered item?")), ["row-shape"]);
assert.deepEqual(ids(good.replace(oqLine, "* OQ-1 (G1): a starred item?")), ["row-shape"]);
assert.deepEqual(ids(good.replace("- AC-2: Given", "AC-2: Given")), ["row-shape"]);
assert.deepEqual(ids(good.replace(oqLine, "None.").replace("Run the check", "- OQ-1 (G1): hidden in plan notes?\n\nRun the check")), ["misplaced-row"]);
assert.deepEqual(ids(`- OQ-1 (G1): above every heading?\n\n${good}`), ["misplaced-row"]);
assert.deepEqual(ids(good.replace("Then the build proceeds", `Then ${"When ".repeat(1000)}`)), ["line-too-long"], "an over-long row is refused before any pattern runs");
const started = Date.now();
checkBody(good.replace("Then the build proceeds", `the ${"When x ".repeat(560)}`), "machinery", catalogue);
assert.ok(Date.now() - started < 2000, "a long row without Then settles in under two seconds");

// 8. Hostile text never reaches the report raw.
const hostile = checkBody(good.replace("- AC-2: Given", "- AC-2: \u001b[31mGiven"), "machinery", catalogue);
assert.equal(JSON.stringify(hostile).includes("\u001b"), false);

// 9. The command line: --body-file, --json, exit codes, usage refusals.
const run = (args: string[], env: NodeJS.ProcessEnv = process.env) => spawnSync(process.execPath, [script, ...args], { encoding: "utf8", env, cwd: dir });
const goodFile = join(dir, "good.md");
writeFileSync(goodFile, good);
let r = run(["--body-file", goodFile, "--kind", "machinery"]);
assert.equal(r.status, 0, r.stderr);
assert.match(r.stdout, /^issue-shape: ok · kind machinery · 0 miss\(es\) · OQ open 0, resolved 1\n$/);
const openFile = join(dir, "open.md");
writeFileSync(openFile, good.replace("- ~~OQ-1~~ → A: the build stops (2026-10-21, HR-4)", "- OQ-1 (G1): open?"));
r = run(["--body-file", openFile, "--json"]);
assert.equal(r.status, 1);
const parsed = JSON.parse(r.stdout);
assert.equal(parsed.contract, "hatsu.issue-body-check/v1");
assert.equal(parsed.kind, "common");
assert.equal(parsed.questions.open, 1);
// QA-16: a body with an invalid UTF-8 byte is refused at exit 2, never read as clean.
const binFile = join(dir, "good-bin.md");
writeFileSync(binFile, Buffer.concat([Buffer.from(good.replace("- SC-1", "- SC-1\u0000")), Buffer.from([0xff, 0xfe])]));
r = run(["--body-file", binFile, "--kind", "machinery"]);
assert.equal(r.status, 2, `a non-UTF-8 body: ${r.stdout}${r.stderr}`);
assert.match(r.stderr, /not valid UTF-8/);
for (const args of [[], ["--body-file", goodFile, "--ref", "HA#1"], ["--bogus"], ["--body-file"], ["--ref", "HA-1"], ["--ref", "HA#0"],
  ["--body-file", join(dir, "absent.md")], ["--body-file", goodFile, "--kind", "nope"]]) {
  r = run(args);
  assert.equal(r.status, 2, `${args.join(" ")}: ${r.stderr}`);
}

// 10. --ref: the code resolved by nen, the body read through gh_token_env.sh, never guessed.
const bin = join(dir, "bin");
spawnSync("mkdir", ["-p", bin]);
const argvLog = join(dir, "gh-argv");
const issueJson = join(dir, "issue.json");
writeFileSync(join(bin, "gh"), `#!/bin/sh\nif [ "$1" = auth ]; then echo stub-token; exit 0; fi\nprintf '%s\\n' "$@" > '${argvLog}'\n[ -f '${dir}/gh-fail' ] && exit 1\ncat '${issueJson}'\n`, { mode: 0o755 });
const nen = join(dir, "nen");
writeFileSync(nen, `#!/bin/sh\n[ "$3" = ZZ ] && { echo '{"repos":[]}'; exit 1; }\necho '{"token":"'"$3"'","repos":[{"repo":"example-owner/example-repo","code":"'"$3"'"}]}'\n`, { mode: 0o755 });
const env = { ...process.env, PATH: `${bin}:${process.env.PATH}`, NEN: nen };
writeFileSync(issueJson, JSON.stringify({ number: 7, body: good }));
r = run(["--ref", "EX#7", "--kind", "machinery"], env);
assert.equal(r.status, 0, r.stderr);
assert.deepEqual(readFileSync(argvLog, "utf8").trim().split("\n"), ["api", "--method", "GET", "repos/example-owner/example-repo/issues/7"]);
writeFileSync(issueJson, JSON.stringify({ number: 7, body: readFileSync(openFile, "utf8") }));
r = run(["--ref", "EX#7", "--json"], env);
assert.equal(r.status, 1);
assert.equal(JSON.parse(r.stdout).questions.open, 1);
writeFileSync(issueJson, JSON.stringify({ number: 7, body: good, pull_request: { url: "x" } }));
assert.equal(run(["--ref", "EX#7"], env).status, 3, "a pull request is not an issue");
assert.equal(run(["--ref", "ZZ#7"], env).status, 3, "an unresolved code");
writeFileSync(join(dir, "gh-fail"), "");
assert.equal(run(["--ref", "EX#7"], env).status, 3, "a failed read is never a pass");
r = run(["--ref", "EX#7", "--json"], env);
assert.equal(JSON.parse(r.stdout).exit, 3);
assert.equal(run(["--ref", "EX#7"], { ...env, NEN: join(dir, "no-such-nen") }).status, 5, "absent nen is a missing tool");
const bashOnly = join(dir, "bash-only");
spawnSync("mkdir", ["-p", bashOnly]);
spawnSync("ln", ["-s", spawnSync("sh", ["-c", "command -v bash"], { encoding: "utf8" }).stdout.trim(), join(bashOnly, "bash")]);
assert.equal(run(["--ref", "EX#7"], { ...process.env, NEN: nen, PATH: bashOnly }).status, 5, "absent gh is a missing tool");

console.log("issue-shape: templates per kind, required and optional headings, AC/SC/AS/OQ rows, vague and technology terms, hostile text, exit codes and the --ref read passed");
