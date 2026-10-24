#!/usr/bin/env node
/** HA#331: a catalogue row ownedBy a skill (the ci block, kuchiyose's) is never listed by diagnose, fill or need,
 *  so tenkai never asks or fills it; the owning skill still writes it through set (hermetic). */
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { after, beforeEach, test } from "node:test";
import { fileURLToPath } from "node:url";

const HATSU_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const SCRIPT = join(HATSU_ROOT, "scripts/config_values.sh");
const catalogue = JSON.parse(readFileSync(join(HATSU_ROOT, "contracts/config-catalogue.json"), "utf8"));
const ciRows = catalogue.values.filter((row: { id: string }) => row.id.startsWith("workflow.ci."));
const temporary: string[] = [];
let repo = "";

after(() => { for (const dir of temporary) rmSync(dir, { recursive: true, force: true }); });
beforeEach(() => {
  repo = mkdtempSync(join(tmpdir(), "hatsu-owned-row-"));
  temporary.push(repo);
  mkdirSync(join(repo, "nen"));
  // A partial ci block: the state in which a fill would otherwise write a default unasked.
  writeFileSync(join(repo, "nen/workflow.json"), `${JSON.stringify({ ci: { provider: "AK" } })}\n`);
  writeFileSync(join(repo, "nen/gates.json"), "{}\n");
  writeFileSync(join(repo, "nen/contract.json"), "{}\n");
});
const run = (...args: string[]) => spawnSync("bash", [SCRIPT, ...args], { encoding: "utf8" });
const workflow = () => JSON.parse(readFileSync(join(repo, "nen/workflow.json"), "utf8"));

test("every ci row is owned by kuchiyose and none carries a default (HR-137, HR-139)", () => {
  assert.equal(ciRows.length, 5);
  for (const row of ciRows) {
    assert.equal(row.ownedBy, "kuchiyose", row.id);
    assert.ok(!("default" in row), `${row.id} carries a default`);
  }
});

test("diagnose lists no ci row, even with a partial ci block", () => {
  const result = run("diagnose", "--repo", repo, "--json");
  assert.equal(result.stderr.includes("ownedBy"), false, result.stderr);
  const ids = (JSON.parse(result.stdout).values ?? []).map((row: { id: string }) => row.id);
  assert.ok(ids.length > 0, "diagnose listed nothing");
  assert.deepEqual(ids.filter((id: string) => id.startsWith("workflow.ci.")), []);
});

test("fill writes no ci key", () => {
  const result = run("fill", "--repo", repo);
  assert.ok([0, 1].includes(result.status ?? -1), `${result.stdout}${result.stderr}`);
  assert.deepEqual(workflow().ci, { provider: "AK" });
});

test("set still writes an owned row, inside its options only", () => {
  assert.equal(run("set", "--repo", repo, "--id", "workflow.ci.rulings.claudeAuth", "--value", '"claude_code_oauth_token"').status, 0);
  assert.equal(workflow().ci.rulings.claudeAuth, "claude_code_oauth_token");
  const refused = run("set", "--repo", repo, "--id", "workflow.ci.rulings.hidan", "--value", '"maybe"');
  assert.equal(refused.status, 2);
  assert.match(refused.stderr, /one of: on \| off/);
});
