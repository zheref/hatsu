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
// The intake.challenger options stand in for ROSTER § The intake examiners (HR-24): the exact-four test
// below goes red if the two ever diverge, e.g. a code reviewer ruled choosable as a challenger.
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

function run(...args: string[]) {
  return spawnSync("bash", [SCRIPT, "set", "--repo", repo, ...args], { encoding: "utf8" });
}
const set = (value: unknown) => run("--id", "workflow.review.scopes", "--value", JSON.stringify(value));
const scope = (persona: string) => ({ ui: { persona, tier: "fast", budget: 2, paths: ["**/*.css"] } });
const written = () => readFileSync(join(repo, "nen/workflow.json"), "utf8");
function refused(result: ReturnType<typeof run>, pattern: RegExp, before: string) {
  assert.equal(result.status, 2, `${result.stdout}${result.stderr}`);
  assert.match(result.stderr, pattern);
  assert.equal(written(), before);
}
const EXAMINER = /intake examiner.*HR-23/;

test("the examiner set is the four intake examiners, each a definition on disk", () => {
  assert.deepEqual([...examiners].sort(), ["bisky", "buhara", "lippo", "satotz"]);
  for (const name of examiners) assert.ok(existsSync(join(HATSU_ROOT, "claude/agents", `${name}.md`)), name);
});

for (const name of ["satotz", "lippo", "buhara", "bisky", " Bisky ", "bis\u200bky", "\uff42\uff49\uff53\uff4b\uff59", "../agents/bisky", "./bisky", "bisky.md", "hatsu:bisky"]) {
  test(`set refuses ${JSON.stringify(name)} as a review.scopes persona and writes nothing`, () => {
    refused(set(scope(name)), /review\.scopes\.ui\.persona .*intake examiner.*HR-23/, written());
  });
}

test("the prose copies of the set name every examiner: hanten § 3 and the persona row", () => {
  const hanten = readFileSync(join(HATSU_ROOT, "claude/skills/hanten/SKILL.md"), "utf8").split("\n").find((line) => line.includes("**Never an examiner**")) ?? "";
  const row = readFileSync(join(HATSU_ROOT, "docs/config/workflow.json.md"), "utf8").split("\n").find((line) => line.startsWith("| `scopes.<scope>.persona`")) ?? "";
  for (const name of examiners) for (const [where, line] of [["hanten § 3", hanten], ["workflow.json.md", row]]) assert.ok(line.includes(`\`${name}\``), `${where} misses ${name}`);
});

test("set refuses an examiner in any scope of the value, not only the first", () => {
  refused(set({ code: { persona: "nobunaga", tier: "deep", budget: 2, paths: ["**"] }, ...scope("lippo") }), EXAMINER, written());
});

test("the last --value wins, as in the engine: a clean first --value hides nothing", () => {
  refused(run("--id", "workflow.review.scopes", "--value", JSON.stringify(scope("hisoka")), "--value", JSON.stringify(scope("bisky"))), EXAMINER, written());
});

test("the last --id wins, as in the engine: another id first hides nothing", () => {
  refused(run("--id", "workflow.review.base", "--id", "workflow.review.scopes", "--value", JSON.stringify(scope("bisky"))), EXAMINER, written());
});

test("a flag's value is never read as a flag: --skill consuming --value hides nothing", () => {
  refused(run("--skill", "--value", "--id", "workflow.review.scopes", "--value", JSON.stringify(scope("bisky"))), EXAMINER, written());
});

test("--hatsu-root before the mode hides nothing: the guard reads the engine's own mode", () => {
  const before = written();
  const result = spawnSync("bash", [SCRIPT, "--hatsu-root", HATSU_ROOT, "set", "--repo", repo, "--id", "workflow.review.scopes", "--value", JSON.stringify(scope("bisky"))], { encoding: "utf8" });
  refused(result, EXAMINER, before);
});

test("--hatsu-root before fill still writes the section-options annotation", () => {
  const result = spawnSync("bash", [SCRIPT, "--hatsu-root", HATSU_ROOT, "fill", "--repo", repo], { encoding: "utf8" });
  assert.equal(result.status, 0, `${result.stdout}${result.stderr}`);
  assert.match(JSON.parse(written()).pr.$sections, /available sections: /);
});

test("a literal the engine accepts but strict JSON does not (NaN) is refused, never passed through", () => {
  refused(run("--id", "workflow.review.scopes", "--value", '{"ui":{"persona":"bisky","tier":"fast","budget":NaN,"paths":["x"]}}'), /not strict JSON.*HR-23/, written());
});

test("set still writes a hanten reviewer as a review.scopes persona", () => {
  const result = set(scope("hisoka"));
  assert.equal(result.status, 0, `${result.stdout}${result.stderr}`);
  assert.equal(JSON.parse(written()).review.scopes.ui.persona, "hisoka");
});
