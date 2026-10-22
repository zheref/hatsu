#!/usr/bin/env node
/** HR-23: config_values.sh set refuses an intake examiner as a review.scopes persona (hermetic). */
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { after, beforeEach, test } from "node:test";
import { fileURLToPath } from "node:url";

const HATSU_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const SCRIPT = join(HATSU_ROOT, "scripts/config_values.sh");
const catalogue = JSON.parse(readFileSync(join(HATSU_ROOT, "contracts/config-catalogue.json"), "utf8"));
const examiners: string[] = [...new Set<string>(catalogue.values
  .filter((row: { path?: string }) => String(row.path ?? "").startsWith("intake.challenger."))
  .flatMap((row: { options?: string[] }) => row.options ?? []))];
const temporary: string[] = [];
let repo = "";

after(() => { for (const dir of temporary) rmSync(dir, { recursive: true, force: true }); });
beforeEach(() => {
  repo = mkdtempSync(join(tmpdir(), "hatsu-examiner-scope-"));
  temporary.push(repo);
  mkdirSync(join(repo, "nen"));
  writeFileSync(join(repo, "nen/workflow.json"), `${JSON.stringify({ review: { scopes: {} } })}\n`);
  writeFileSync(join(repo, "nen/gates.json"), "{}\n");
  writeFileSync(join(repo, "nen/contract.json"), "{}\n");
});

function set(value: unknown) {
  return spawnSync("bash", [SCRIPT, "set", "--repo", repo, "--id", "workflow.review.scopes", "--value", JSON.stringify(value)], { encoding: "utf8" });
}
const scope = (persona: string) => ({ ui: { persona, tier: "fast", budget: 2, paths: ["**/*.css"] } });
const written = () => readFileSync(join(repo, "nen/workflow.json"), "utf8");

test("the examiner set is the four intake examiners, each a definition on disk", () => {
  assert.deepEqual([...examiners].sort(), ["bisky", "buhara", "lippo", "satotz"]);
  for (const name of examiners) assert.ok(existsSync(join(HATSU_ROOT, "claude/agents", `${name}.md`)), name);
});

for (const name of ["satotz", "lippo", "buhara", "bisky", " Bisky "]) {
  test(`set refuses ${JSON.stringify(name)} as a review.scopes persona and writes nothing`, () => {
    const before = written();
    const result = set(scope(name));
    assert.equal(result.status, 2, `${result.stdout}${result.stderr}`);
    assert.match(result.stderr, /review\.scopes\.ui\.persona .*intake examiner.*HR-23/);
    assert.equal(written(), before);
  });
}

test("set still writes a code reviewer as a review.scopes persona", () => {
  const result = set(scope("hisoka"));
  assert.equal(result.status, 0, `${result.stdout}${result.stderr}`);
  assert.equal(JSON.parse(written()).review.scopes.ui.persona, "hisoka");
});
