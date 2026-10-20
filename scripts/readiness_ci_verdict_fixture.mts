#!/usr/bin/env node
import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import { formatVerdict } from "./readiness_ci_verdict.mts";

const head = "a".repeat(40);
const specs = [
  ["mergeable", "CON-42/1"],
  ["checks-green", "CON-32(a)"],
  ["round-stalled", "CON-32(b)"],
  ["rounds-owed", "CON-32(b)"],
  ["approvals-at-head", "CON-32(b)/CON-16"],
  ["unresolved-threads", "CON-32(d)"],
] as const;
const rows = specs.map(([id, clause], index) => ({ id, clause, order: index + 1,
  status: "ready", reason: null as string | null, missing: null as string | null }));
rows[3] = { ...rows[3], status: "failed", reason: "no round at head" };
const body = { contract: "nen.pr.ready/v0.1", verdict: "not-ready", judgedHead: head,
  failing: ["rounds-owed"], conjuncts: rows };
assert.deepEqual(formatVerdict(JSON.stringify(body), 1, head), {
  title: "not-ready",
  summary: `Verdict: not-ready\nJudged head: ${head}\nrounds-owed (CON-32(b)): failed — "no round at head"`,
});
const mixed = rows.map(row => ({ ...row }));
mixed[1] = { ...mixed[1], status: "unevaluated", missing: "checks rollup could not be read" };
assert.equal(formatVerdict(JSON.stringify({ ...body, conjuncts: mixed }), 1, head).summary,
  `Verdict: not-ready\nJudged head: ${head}\nchecks-green (CON-32(a)): unevaluated — "checks rollup could not be read"\nrounds-owed (CON-32(b)): failed — "no round at head"`);
const unknownOnly = rows.map(row => ({ ...row }));
unknownOnly[3] = { ...unknownOnly[3], status: "unevaluated", reason: null, missing: "reviews could not be read" };
assert.equal(formatVerdict(JSON.stringify({ ...body, failing: [], conjuncts: unknownOnly }), 1, head).title, "not-ready");
assert.equal(formatVerdict(JSON.stringify({ ...body, verdict: "ready", failing: [], conjuncts: rows.map(row => ({ ...row, status: "ready", reason: null })) }), 0, head).title, "ready");
assert.equal(formatVerdict(JSON.stringify({ ...body, verdict: "ready" }), 0, head).title, "readiness undetermined");
assert.equal(formatVerdict(JSON.stringify({ ...body, judgedHead: "b".repeat(40) }), 1, head).title, "readiness undetermined");
assert.equal(formatVerdict(JSON.stringify(body), 8, head).title, "superseded");
assert.equal(formatVerdict("::warning::not JSON", 1, head).title, "readiness undetermined");
assert.equal(formatVerdict("null", 1, head).title, "readiness undetermined");
assert.equal(formatVerdict(JSON.stringify({ ...body, failing: ["unlisted"] }), 1, head).title, "readiness undetermined");
assert.equal(formatVerdict(JSON.stringify({ ...body, failing: [] }), 1, head).title, "readiness undetermined");
assert.equal(formatVerdict(JSON.stringify({ ...body, verdict: "ready", failing: [], conjuncts: [] }), 0, head).title, "readiness undetermined");
assert.equal(formatVerdict(JSON.stringify({ ...body, conjuncts: rows.slice(0, -1) }), 1, head).title, "readiness undetermined");
assert.equal(formatVerdict(JSON.stringify({ ...body, conjuncts: rows.map((row, index) => index === 4 ? rows[3] : row) }), 1, head).title, "readiness undetermined");
assert.equal(formatVerdict(JSON.stringify({ ...body, conjuncts: rows.map((row, index) => index === 4 ? { ...row, id: "unexpected" } : row) }), 1, head).title, "readiness undetermined");
assert.equal(formatVerdict(JSON.stringify({ ...body, conjuncts: rows.map((row, index) => index === 3 ? { ...row, reason: "::error::hostile\nEOF" } : row) }), 1, head).summary.includes('"::error::hostile\\nEOF"'), true);

const dir = mkdtempSync(join(tmpdir(), "hatsu-readiness-json-"));
const fake = join(dir, "nen");
const output = join(dir, "output");
const argv = join(dir, "argv");
writeFileSync(fake, `#!/bin/sh\nprintf '%s\\n' "$@" > '${argv}'\ncat <<'JSON'\n${JSON.stringify(body)}\nJSON\nexit 1\n`, { mode: 0o755 });
const run = spawnSync(process.execPath, [join(import.meta.dirname, "readiness_ci_verdict.mts")], {
  cwd: dir, encoding: "utf8", env: { ...process.env, NEN: fake, REPO: "zheref/hatsu", PR: "325", RUN_ID: "123",
    EVENT_HEAD: head, GITHUB_OUTPUT: output },
});
assert.equal(run.status, 0, run.stderr);
assert.match(run.stdout, /^readiness: not-ready\n$/);
const args = readFileSync(argv, "utf8").trim().split("\n");
assert.deepEqual(args.slice(0, 7), ["pr", "ready", "325", "--gh-repo", "zheref/hatsu", "--json", "--gates"]);
assert.deepEqual(args.slice(-6), ["--exclude-run", "123", "--exclude-check", "readiness", "--require-head", head]);
assert.match(readFileSync(output, "utf8"), /title<<EOF_[0-9a-f]{32}\nnot-ready\n/);
console.log("readiness-json: six-row contract, unevaluated rows, head pin, hostile text, and exact Nen argv passed");
