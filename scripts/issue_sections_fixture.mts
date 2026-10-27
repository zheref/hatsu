#!/usr/bin/env node
// Fixture for the issue section catalogue (lane issue-shape; HR-4): contracts/issue-sections.json and
// templates/issue-body/ agree, and nen's own readers -- `nen issue body-check --requirements-from` and
// `nen issue questions` (nen 0.28.0: an open question exits 1, the counts still read) -- read Hatsu's catalogue as the skills call them. The interim
// scripts/issue_body_check.mts is retired (zheref/hatsu#423); the shape is nen's to compute. Offline:
// every body is a --body-file, so no gh call is made. Runs the nen first on PATH, or NEN.
import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const root = join(import.meta.dirname, "..");
const cataloguePath = join(root, "contracts", "issue-sections.json");
const catalogue = JSON.parse(readFileSync(cataloguePath, "utf8")) as {
  sections: { [id: string]: { heading: string } };
  kinds: { [kind: string]: { template: string; required: string[]; optional: string[] } };
};
const nen = process.env.NEN || "nen";
// The pin crossed 0.28 in one PR while CI (unit-tests.yml) installs the BASE contract's pin until it merges, so the
// open-question exit is read off the binary: 1 from 0.28.0, 0 before (the HA#449 repin; drop the branch at the next repin).
const nenVersion = (() => {
  const r = spawnSync(nen, ["--version"], { encoding: "utf8" });
  const m = /^(\d+)\.(\d+)\./.exec((r.stdout || "").trim());
  return m ? [Number(m[1]), Number(m[2])] : null;
})();
if (!nenVersion) throw new Error(`issue-shape: could not read ${nen} --version`);
const openQuestionExit = nenVersion[0] > 0 || nenVersion[1] >= 28 ? 1 : 0;
const dir = mkdtempSync(join(tmpdir(), "hatsu-issue-shape-"));
type Check = { status: number | null; json: { ok?: boolean; sections?: Array<{ id: string; status: string }>;
  misses?: Array<{ section: string; kind: string }>; counts?: { open: number; resolved: number };
  open?: Array<{ number: number; gate: string }> } | null; stderr: string };
function call(verb: "body-check" | "questions", body: string, extra: string[] = [], cat = cataloguePath): Check {
  const file = join(dir, `body-${Math.random().toString(16).slice(2)}.md`);
  writeFileSync(file, body);
  const r = spawnSync(nen, ["issue", verb, "--body-file", file, "--requirements-from", cat, ...extra, "--json"], { encoding: "utf8" });
  if (r.error) throw new Error(`issue-shape: could not run ${nen}: ${r.error.message}`);
  let json = null;
  try { json = JSON.parse(r.stdout); } catch { /* a usage refusal prints no document */ }
  return { status: r.status, json, stderr: r.stderr };
}
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
try {
  // 1. Every kind has its template, at the declared path, carrying exactly its catalogue headings.
  assert.deepEqual(readdirSync(join(root, "templates", "issue-body")).sort(), Object.keys(catalogue.kinds).map((k) => `${k}.md`).sort());
  for (const [kind, spec] of Object.entries(catalogue.kinds)) {
    assert.equal(spec.template, `templates/issue-body/${kind}.md`);
    const template = readFileSync(join(root, spec.template), "utf8");
    const headings = [...template.matchAll(/^## (.+)$/gm)].map((m) => m[1]).sort();
    // `requirements` is Akatsuki's alternative to Acceptance criteria (zheref/hatsu#411): optional on epic so
    // body-check reads its rows, carried by no Hatsu template, which files Acceptance criteria.
    const templated = [...spec.required, ...spec.optional].filter((id) => id !== "requirements");
    assert.deepEqual(headings, templated.map((id) => catalogue.sections[id].heading).sort(), kind);
    // 2. nen reads the catalogue's own shape: an unfilled template is a miss, every section empty.
    const unfilled = call("body-check", template, ["--kind", kind]);
    assert.equal(unfilled.status, 1, `${kind} template: ${unfilled.stderr}`);
    assert.equal(unfilled.json?.ok, false);
    assert.equal(unfilled.json?.sections?.filter((s) => s.status === "empty").length, templated.length, kind);
  }
  assert.deepEqual(Object.entries(catalogue.kinds).filter(([, spec]) => [...spec.required, ...spec.optional].includes("requirements")).map(([kind]) => kind), ["epic"], "requirements is optional on epic alone and required by no kind");
  // 1b. Akatsuki's Requirements section (zheref/hatsu#411; HA-PR-#512 round 2, R2-1): allowed beside Acceptance
  // criteria on an epic only -- Acceptance rows AC-{n}, Requirements rows AC-{epic}-{nnn}, one id one criterion --
  // and absent on every other kind. body-check shape-checks its rows (numbering, vague words); at nen 0.28 it
  // neither refuses an id repeated across the two sections nor flags Requirements on another kind: pinned
  // misses owed to zheref/nen#553.
  const epicSpec = catalogue.kinds.epic;
  assert.ok(epicSpec.required.includes("acceptance") && epicSpec.optional.includes("requirements"), "an epic carries Acceptance criteria and may carry Requirements beside it");
  const epicBody = (acceptance: string) => `## Problem\n\nx\n\n## Audience and why\n\nme\n\n## Children\n\n- #1 a\n\n${acceptance}\n\n## Success criteria\n\n- SC-1: 100% of rows read\n\n## Assumptions\n\nNone.\n\n## Open questions\n\nNone.\n\n## Scope boundaries\n\nin\n\n## Cross-references\n\nnone\n`;
  type Shaped = { misses?: Array<{ section: string; kind: string }>; advisories?: Array<{ kind: string; word: string }> };
  const shaped = call("body-check", epicBody("## Acceptance criteria\n\n- AC-1: Given a When b Then c\n\n## Requirements\n\n- AC-1: Given a When quickly b Then c\n- AC-3: Given a When b Then c"), ["--kind", "epic"]);
  assert.equal(shaped.status, 1, shaped.stderr);
  assert.deepEqual(shaped.json?.misses?.map((m) => [m.section, m.kind]), [["requirements", "row-order"]], JSON.stringify(shaped.json?.misses));
  assert.ok((shaped.json as Shaped | null)?.advisories?.some((a) => a.kind === "vague" && a.word === "quickly"), "a Requirements row is read for vague words");
  const repeated = call("body-check", epicBody("## Acceptance criteria\n\n- AC-1: Given a When b Then c\n\n## Requirements\n\n- AC-1: Given d When e Then f"), ["--kind", "epic"]);
  assert.equal(repeated.status, 0, `an id repeated across the two sections passes body-check at nen 0.28 (pinned; zheref/nen#553 refuses it): ${JSON.stringify(repeated.json?.misses)}`);
  const elsewhere = call("body-check", good.replace("## Success criteria", "## Requirements\n\n- AC-12-001 (P1): Given a When b Then c\n\n## Success criteria"), ["--kind", "machinery"]);
  assert.equal(elsewhere.status, 0, `Requirements on a non-epic kind passes body-check at nen 0.28 (pinned; zheref/nen#553 flags it): ${JSON.stringify(elsewhere.json?.misses)}`);
  // 3. A filled body passes for its kind and against common; a missing required section is a miss.
  for (const extra of [["--kind", "machinery"], []]) {
    const pass = call("body-check", good, extra);
    assert.equal(pass.status, 0, `${extra.join(" ") || "common"}: ${JSON.stringify(pass.json?.misses)} ${pass.stderr}`);
  }
  const missing = call("body-check", good.replace("## Scope boundaries", "## Scope"), ["--kind", "machinery"]);
  assert.equal(missing.status, 1);
  assert.ok(missing.json?.misses?.some((m) => m.section === "scope"), JSON.stringify(missing.json?.misses));
  assert.equal(call("body-check", good, ["--kind", "product"]).status, 1, "product requires its own sections");
  // 4. Questions: the catalogue's row patterns count open and resolved rows, the gate read. From nen 0.28.0 an
  // open question exits 1 with the document on stdout ("read, and a question is open"; 0.26.0 exited 0 whatever
  // the counts): the verb counts and never decides, and the exit is the count made legible to a caller.
  const resolved = call("questions", good);
  assert.equal(resolved.status, 0, resolved.stderr);
  assert.deepEqual([resolved.json?.counts?.open, resolved.json?.counts?.resolved], [0, 1]);
  const open = call("questions", good.replace("- ~~OQ-1~~ → A: the build stops (2026-10-21, HR-4)", "- OQ-1 (G1): does the build stop?\n- ~~OQ-2~~ → A: yes (2026-10-21, HR-4)"));
  assert.equal(open.status, openQuestionExit, `an open question exits ${openQuestionExit} at nen ${nenVersion.join(".")} (1 from 0.28.0); the counts below are the decision's, never the verb's`);
  assert.ok(open.json, "exit 1 still carries the document on stdout");
  assert.deepEqual([open.json?.counts?.open, open.json?.counts?.resolved], [1, 1]);
  assert.deepEqual(open.json?.open?.map((r) => [r.number, r.gate]), [[1, "G1"]]);
  // 5. A malformed catalogue is wiring (exit 2), never a clean body.
  const broken = join(dir, "broken.json");
  writeFileSync(broken, "{ not json");
  assert.equal(call("body-check", good, ["--kind", "machinery"], broken).status, 2);
  assert.equal(call("questions", good, [], broken).status, 2);
  console.log("issue-shape: templates per kind, Requirements beside Acceptance criteria on epic only, nen issue body-check and nen issue questions over the catalogue, and the malformed-catalogue refusal passed");
} finally {
  rmSync(dir, { recursive: true, force: true });
}
