#!/usr/bin/env node
import assert from "node:assert/strict";
import { chmodSync, copyFileSync, mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import { pathToFileURL } from "node:url";
import { applyPluginVersionCheck, formatVerdict } from "./readiness_ci_verdict.mts";

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
const linkedReader = join(dir, "linked-reader.mts");
const linkedOutput = join(dir, "linked-output");
symlinkSync(join(import.meta.dirname, "readiness_ci_verdict.mts"), linkedReader);
const linkedRun = spawnSync(process.execPath, [linkedReader], {
  cwd: dir, encoding: "utf8", env: { ...process.env, NEN: fake, REPO: "zheref/hatsu", PR: "325", RUN_ID: "123",
    EVENT_HEAD: head, GITHUB_OUTPUT: linkedOutput },
});
assert.equal(linkedRun.status, 0, linkedRun.stderr);
assert.match(readFileSync(linkedOutput, "utf8"), /title<<EOF_[0-9a-f]{32}\nnot-ready\n/);
const readerUrl = pathToFileURL(join(import.meta.dirname, "readiness_ci_verdict.mts")).href;
const importRun = spawnSync(process.execPath, ["--input-type=module", "-e",
  `process.argv[1] = "/path/that/does/not/exist"; await import(${JSON.stringify(readerUrl)});`],
  { encoding: "utf8" });
assert.equal(importRun.status, 0, importRun.stderr);

// applyPluginVersionCheck unit assertions (HA#545 AC-3)
const readyVerdict = { title: "ready", summary: `Verdict: ready\nJudged head: ${head}` };
assert.deepEqual(applyPluginVersionCheck(readyVerdict, { status: "ok" }), readyVerdict);
const failedOnReady = applyPluginVersionCheck(readyVerdict, {
  status: "failed",
  detail: "head version 0.170.1 equals the current tip of main (0.170.1)",
});
assert.equal(failedOnReady.title, "not-ready");
assert.match(failedOnReady.summary, /^Verdict: not-ready\n/);
assert.match(failedOnReady.summary, /plugin-version \(HA#545\): failed — head version 0\.170\.1 equals the current tip of main/);
assert.equal(
  applyPluginVersionCheck(readyVerdict, { status: "superseded" }).title,
  "superseded",
);
assert.equal(
  applyPluginVersionCheck(readyVerdict, { status: "undetermined", detail: "network error" }).title,
  "readiness undetermined",
);
const notReadyVerdict = { title: "not-ready", summary: `Verdict: not-ready\nJudged head: ${head}` };
const preservedNotReady = applyPluginVersionCheck(notReadyVerdict, { status: "undetermined", detail: "network error" });
assert.equal(preservedNotReady.title, "not-ready");
assert.match(preservedNotReady.summary, /plugin-version check undetermined — network error/);

// End-to-end HA#545 AC-3 check inside a Hatsu-like trusted checkout
const e2eDir = mkdtempSync(join(tmpdir(), "hatsu-readiness-e2e-"));
try {
  mkdirSync(join(e2eDir, ".trusted/scripts"), { recursive: true });
  mkdirSync(join(e2eDir, ".trusted/nen"), { recursive: true });
  mkdirSync(join(e2eDir, ".claude-plugin"), { recursive: true });
  writeFileSync(join(e2eDir, ".trusted/nen/gates.json"), "{}\n");
  writeFileSync(join(e2eDir, ".claude-plugin/plugin.json"), JSON.stringify({ name: "hatsu", version: "0.170.1" }) + "\n");
  copyFileSync(join(import.meta.dirname, "plugin_bump_api_retry.mts"), join(e2eDir, ".trusted/scripts/plugin_bump_api_retry.mts"));
  copyFileSync(join(import.meta.dirname, "plugin_bump_check.sh"), join(e2eDir, ".trusted/scripts/plugin_bump_check.sh"));
  chmodSync(join(e2eDir, ".trusted/scripts/plugin_bump_check.sh"), 0o755);

  const readyBody = {
    contract: "nen.pr.ready/v0.1",
    verdict: "ready",
    judgedHead: head,
    failing: [],
    conjuncts: rows.map(row => ({ ...row, status: "ready", reason: null, missing: null })),
  };
  const fakeReadyNen = join(e2eDir, "nen-ready");
  writeFileSync(fakeReadyNen, `#!/bin/sh\ncat <<'JSON'\n${JSON.stringify(readyBody)}\nJSON\nexit 0\n`, { mode: 0o755 });

  const mockFetchPath = join(e2eDir, "mock-fetch.mjs");
  writeFileSync(mockFetchPath, `
const head = ${JSON.stringify(head)};
const tip = "e".repeat(40);
globalThis.fetch = async (input) => {
  const url = String(input);
  const json = (status, data) => new Response(JSON.stringify(data), { status });
  if (url.includes("/repos/zheref/hatsu/pulls/325/files")) {
    return json(200, [{ filename: "claude/skills/ten/SKILL.md" }]);
  }
  if (url.includes("/repos/zheref/hatsu/pulls/610/files")) {
    return json(200, [{ filename: "claude/skills/aka/SKILL.md" }]);
  }
  if (url.includes("/repos/zheref/hatsu/pulls/325")) {
    return json(200, { base: { ref: "main" }, head: { sha: head } });
  }
  if (url.includes("/commits/main")) {
    return json(200, { sha: tip });
  }
  if (url.includes("/contents/.claude-plugin/plugin.json")) {
    if (url.includes("ref=" + "f".repeat(40))) {
      return json(200, { version: "0.170.1" });
    }
    return json(200, { version: process.env.MOCK_BASE_VERSION ?? "0.170.0" });
  }
  if (url.includes("/pulls?state=open")) {
    return json(200, JSON.parse(process.env.MOCK_OPEN_PRS ?? "[]"));
  }
  return json(404, { message: "unexpected url: " + url });
};
`);
  const mockUrl = pathToFileURL(mockFetchPath).href;
  const runE2e = (caseName: string, extraEnv: Record<string, string>) => {
    const outFile = join(e2eDir, `out-${caseName}`);
    const res = spawnSync(process.execPath, [join(import.meta.dirname, "readiness_ci_verdict.mts")], {
      cwd: e2eDir,
      encoding: "utf8",
      env: {
        ...process.env,
        NODE_OPTIONS: `--import ${mockUrl}`,
        NEN: fakeReadyNen,
        REPO: "zheref/hatsu",
        PR: "325",
        RUN_ID: "456",
        EVENT_HEAD: head,
        GH_TOKEN: "fixture-token",
        GITHUB_OUTPUT: outFile,
        ...extraEnv,
      },
    });
    assert.equal(res.status, 0, `${caseName}: ${res.stderr}`);
    return { stdout: res.stdout, output: readFileSync(outFile, "utf8") };
  };

  const clean = runE2e("clean", { MOCK_BASE_VERSION: "0.170.0", MOCK_OPEN_PRS: "[]" });
  assert.match(clean.stdout, /^readiness: ready\n$/);

  const staleBase = runE2e("stale-base", { MOCK_BASE_VERSION: "0.170.1", MOCK_OPEN_PRS: "[]" });
  assert.match(staleBase.stdout, /^readiness: not-ready\n$/);
  assert.match(staleBase.output, /equals the current tip of main/);

  const siblingHead = "f".repeat(40);
  const collidingPr = JSON.stringify([{
    number: 610,
    head: { sha: siblingHead, repo: { full_name: "zheref/hatsu" } },
  }]);
  const collision = runE2e("collision", { MOCK_BASE_VERSION: "0.170.0", MOCK_OPEN_PRS: collidingPr });
  assert.match(collision.stdout, /^readiness: not-ready\n$/);
  assert.match(collision.output, /collides with another open PR/);
  assert.match(collision.output, /PR #610/);

  // Deleted or symlinked .claude-plugin/plugin.json in PR head must fail closed, never skip.
  rmSync(join(e2eDir, ".claude-plugin/plugin.json"));
  const missingManifest = runE2e("missing-manifest", { MOCK_BASE_VERSION: "0.170.0", MOCK_OPEN_PRS: "[]" });
  assert.match(missingManifest.stdout, /^readiness: not-ready\n$/);
  assert.match(missingManifest.output, /missing, a symlink, or not a regular file/);

  const targetJson = join(e2eDir, "real-manifest.json");
  writeFileSync(targetJson, JSON.stringify({ name: "hatsu", version: "0.170.9" }) + "\n");
  symlinkSync(targetJson, join(e2eDir, ".claude-plugin/plugin.json"));
  const linkedManifest = runE2e("symlink-manifest", { MOCK_BASE_VERSION: "0.170.0", MOCK_OPEN_PRS: "[]" });
  assert.match(linkedManifest.stdout, /^readiness: not-ready\n$/);
  assert.match(linkedManifest.output, /missing, a symlink, or not a regular file/);
} finally {
  rmSync(e2eDir, { recursive: true, force: true });
}

console.log("readiness-json: six-row contract, unevaluated rows, head pin, hostile text, HA#545 freshness/collision, and exact Nen argv passed");
