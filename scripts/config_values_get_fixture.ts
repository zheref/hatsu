#!/usr/bin/env node
/** HA#414: config_values.sh get reads one catalogued value, at a git ref or in the working tree (hermetic). */
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { after, test } from "node:test";
import { fileURLToPath } from "node:url";

const SCRIPT = join(resolve(dirname(fileURLToPath(import.meta.url)), ".."), "scripts/config_values.sh");
const ID = "workflow.release.proposalMerge";
const temporary: string[] = [];
after(() => { for (const dir of temporary) rmSync(dir, { recursive: true, force: true }); });

function git(repo: string, ...args: string[]) {
  const result = spawnSync("git", ["-C", repo, "-c", "user.name=fixture", "-c", "user.email=fixture@example.invalid", "-c", "commit.gpgsign=false", ...args], { encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);
}
/** A repository whose committed nen/workflow.json is `workflow` (raw text), or none at all when undefined. */
function repoWith(workflow: string | undefined): string {
  const repo = mkdtempSync(join(tmpdir(), "hatsu-config-get-"));
  temporary.push(repo);
  git(repo, "init", "-q", "-b", "main");
  mkdirSync(join(repo, "nen"));
  writeFileSync(join(repo, "nen/contract.json"), "{}\n");
  if (workflow !== undefined) writeFileSync(join(repo, "nen/workflow.json"), workflow);
  git(repo, "add", "-A");
  git(repo, "commit", "-qm", "fixture");
  return repo;
}
const get = (repo: string, ...args: string[]) => spawnSync("bash", [SCRIPT, "get", "--repo", repo, "--id", ID, ...args], { encoding: "utf8" });
function reading(repo: string, ...args: string[]) {
  const result = get(repo, ...args, "--json");
  return { status: result.status, stderr: result.stderr, ...(result.stdout ? JSON.parse(result.stdout) : {}) };
}
/** getsuga § 3a merges only on exit 0 with the value "self"; every other reading falls back to the declaration gate. */
const mergeAllowed = (r: { status: number | null; value?: unknown }) => r.status === 0 && r.value === "self";
const declaring = (value: unknown) => `${JSON.stringify({ release: { unitPaths: ["CHANGELOG.md"], proposalMerge: value } })}\n`;

test("a repository declaring human reads human at the ref: § 3a refuses the merge", () => {
  const r = reading(repoWith(declaring("human")), "--ref", "HEAD");
  assert.equal(r.status, 0, r.stderr);
  assert.equal(r.value, "human");
  assert.equal(r.state, "declared");
  assert.match(r.sha, /^[0-9a-f]{40}$/);
  assert.equal(mergeAllowed(r), false);
});

test("a repository that does not declare it reads the default self: § 3a may merge", () => {
  const r = reading(repoWith(`${JSON.stringify({ release: { unitPaths: ["CHANGELOG.md"] } })}\n`), "--ref", "HEAD");
  assert.equal(r.status, 0, r.stderr);
  assert.deepEqual([r.value, r.state], ["self", "default"]);
  assert.equal(mergeAllowed(r), true);
});

test("no nen/workflow.json at the ref reads the default, never an error", () => {
  const r = reading(repoWith(undefined), "--ref", "HEAD");
  assert.deepEqual([r.status, r.value, r.state], [0, "self", "default"]);
});

test("--ref reads the committed value, never an uncommitted edit in the working tree", () => {
  const repo = repoWith(declaring("human"));
  writeFileSync(join(repo, "nen/workflow.json"), declaring("self"));
  assert.equal(reading(repo, "--ref", "HEAD").value, "human");
  assert.equal(reading(repo).value, "self");
  assert.match(get(repo).stdout, /^workflow\.release\.proposalMerge = "self" \(declared\) in the working tree\n$/);
});

test("a declared value outside self | human is exit 1, state invalid: § 3a refuses the merge", () => {
  const r = reading(repoWith(declaring("maybe")), "--ref", "HEAD");
  assert.deepEqual([r.status, r.state, r.value], [1, "invalid", "maybe"]);
  assert.equal(mergeAllowed(r), false);
  assert.match(get(repoWith(declaring(true)), "--ref", "HEAD").stdout, /declared, outside self \| human/);
});

test("an unreadable declaration, an unresolvable ref and a symlinked file are exit 2, never a default", () => {
  const broken = get(repoWith("{ not json\n"), "--ref", "HEAD");
  assert.equal(broken.status, 2);
  assert.match(broken.stderr, /could not read nen\/workflow\.json at [0-9a-f]{40}: not valid JSON/);
  const unresolved = get(repoWith(declaring("human")), "--ref", "origin/nowhere");
  assert.equal(unresolved.status, 2);
  assert.match(unresolved.stderr, /does not resolve to a commit/);
  const linked = repoWith(undefined);
  const outside = mkdtempSync(join(tmpdir(), "hatsu-config-get-outside-"));
  temporary.push(outside);
  writeFileSync(join(outside, "workflow.json"), declaring("self"));
  symlinkSync(join(outside, "workflow.json"), join(linked, "nen/workflow.json"));
  const refused = get(linked);
  assert.equal(refused.status, 2);
  assert.match(refused.stderr, /symlink is refused/);
});

test("usage: an unknown flag, a missing --id and an unknown catalogue id are exit 2", () => {
  const repo = repoWith(undefined);
  assert.equal(get(repo, "--bogus").status, 2);
  assert.equal(spawnSync("bash", [SCRIPT, "get", "--repo", repo], { encoding: "utf8" }).status, 2);
  const unknown = spawnSync("bash", [SCRIPT, "get", "--repo", repo, "--id", "workflow.nope"], { encoding: "utf8" });
  assert.equal(unknown.status, 2);
  assert.match(unknown.stderr, /no catalogue row "workflow\.nope"/);
  assert.equal(get(repo, "--ref", "--json").status, 2);
});

test("set refuses a value outside self | human and writes human with its annotation", () => {
  const repo = repoWith(`${JSON.stringify({ release: { unitPaths: ["CHANGELOG.md"] } })}\n`);
  const before = readFileSync(join(repo, "nen/workflow.json"), "utf8");
  const refused = spawnSync("bash", [SCRIPT, "set", "--repo", repo, "--id", ID, "--value", '"maybe"'], { encoding: "utf8" });
  assert.equal(refused.status, 2);
  assert.match(refused.stderr, /one of: self \| human/);
  assert.equal(readFileSync(join(repo, "nen/workflow.json"), "utf8"), before);
  const written = spawnSync("bash", [SCRIPT, "set", "--repo", repo, "--id", ID, "--value", '"human"'], { encoding: "utf8" });
  assert.equal(written.status, 0, written.stderr);
  const release = JSON.parse(readFileSync(join(repo, "nen/workflow.json"), "utf8")).release;
  assert.deepEqual([release.proposalMerge, release.$proposalMerge], ["human", "one of: self | human"]);
});
