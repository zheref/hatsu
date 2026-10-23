#!/usr/bin/env node
// Fixture for scripts/ruling_row.mts (lane ruling-row-guard): a ROSTER row is the record's cells.
// nen is real for the --effort form (CI's NEN, else PATH's; absent is exit 5): one answer is recorded
// through `nen stop answer` into a throwaway repository's git common dir and read back by id. The
// --record-file form runs on documents written here. Placeholder slugs only.
import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import { cell, readRecord, render } from "./ruling_row.mts";

const here = import.meta.dirname;
const script = join(here, "ruling_row.mts");
const dir = mkdtempSync(join(tmpdir(), "hatsu-ruling-row-"));
const nen = process.env.NEN ?? "nen";
const probe = spawnSync(nen, ["--version"], { encoding: "utf8" });
if (probe.error || probe.status !== 0) {
  console.error(`ruling-row: nen is not reachable as '${nen}' -- a missing tool is exit 5, never a pass`);
  process.exit(5);
}
const run = (args: string[]) => spawnSync(process.execPath, [script, ...args], { encoding: "utf8", env: { ...process.env, NEN: nen } });
const file = (name: string, text: string) => { const p = join(dir, name); writeFileSync(p, text); return p; };
const settles = file("settles.md", "The futon slot frees at the merge; `stacked-open` is zheref/hatsu#425's.\n");
const record = {
  contract: "nen.stop.answer/v0.1", id: "R-2026-10-23-01", effortId: "HA-IS-#425", n: 1, gate: null, row: "port-drift", who: "Kurapika",
  question: "Which rule binds a stacked effort's slot?\nHR-257 says merged; rule 4 of 2026-10-13 says open.\n",
  options: [{ key: "A", label: "Keep merged (Recommended)", consequence: "stacked PRs hold their slot" }, { key: "B", label: "Adopt stacked-open", consequence: "a stacked PR frees at open" }, { key: "C", label: "Ask | later", consequence: "the row stays open" }],
  kind: "picked", pick: "A", typed: null, answeredAt: "2026-10-23T03:37:26.938Z",
};

// 1. A picked answer renders the label in backticks, the options as shown, the question on one line,
// the status, the settles cell and the record's id, effort and date; a pipe in a label is escaped.
let r = run(["--record-file", file("picked.json", JSON.stringify(record)), "--hr", "334", "--settles-file", settles]);
assert.equal(r.status, 0, r.stderr);
assert.equal(r.stdout, "| <a id=\"hr-334\"></a>**HR-334** | Which rule binds a stacked effort's slot? HR-257 says merged; rule 4 of 2026-10-13 says open. | (A) Keep merged (Recommended) · (B) Adopt stacked-open · (C) Ask \\| later | `Keep merged (Recommended)` | ruled | The futon slot frees at the merge; `stacked-open` is zheref/hatsu#425's. — record `R-2026-10-23-01` (HA-IS-#425, 2026-10-23) |\n");

// 2. A typed answer renders the words verbatim, unquoted, one line, hostile characters dropped;
// --status reading and --json carry the same cells.
const typed = { ...record, id: "R-2026-10-23-02", n: 2, kind: "typed", pick: null, typed: "neither: hold the slot until\nthe maintainer merges\u202e\u001b" };
r = run(["--record-file", file("typed.json", JSON.stringify(typed)), "--hr", "335", "--settles-file", settles, "--status", "reading", "--json"]);
assert.equal(r.status, 0, r.stderr);
const parsed = JSON.parse(r.stdout) as { contract: string; hr: number; id: string; row: string; cells: { pick: string; status: string } };
assert.deepEqual([parsed.contract, parsed.hr, parsed.id, parsed.cells.status], ["hatsu.ruling-row/v1", 335, "R-2026-10-23-02", "reading"]);
assert.equal(parsed.cells.pick, "neither: hold the slot until the maintainer merges");
assert.ok(!parsed.row.includes("‮") && !parsed.row.includes("\u001b"), "hostile text is dropped");
assert.equal(cell("a |\r\n  b\t\n\nc"), "a \\| b c");

// 3. Malformed records are exit 2 naming the defect; a missing settles file is 1; an empty cell 2.
for (const [name, bad] of [
  ["contract", { ...record, contract: "nen.stop.mark/v0.2" }],
  ["id", { ...record, id: "2026-10-23-01" }],
  ["no options", { ...record, options: [] }],
  ["pick", { ...record, pick: "Z" }],
  ["kind", { ...record, kind: "guessed" }],
  ["typed empty", { ...record, kind: "typed", pick: null, typed: "  " }],
  ["twice", { ...record, options: [...record.options, record.options[0]] }],
  ["question", { ...record, question: "" }],
] as const) {
  r = run(["--record-file", file(`${name.replace(/\W/g, "-")}.json`, JSON.stringify(bad)), "--hr", "1", "--settles-file", settles]);
  assert.equal(r.status, 2, `${name}: exit ${r.status} ${r.stderr}`);
  assert.throws(() => readRecord(JSON.stringify(bad)));
}
assert.equal(run(["--record-file", file("notjson.json", "{"), "--hr", "1", "--settles-file", settles]).status, 2);
assert.equal(run(["--record-file", join(dir, "absent.json"), "--hr", "1", "--settles-file", settles]).status, 1, "an unreadable record is never a row");
assert.equal(run(["--record-file", file("ok.json", JSON.stringify(record)), "--hr", "1", "--settles-file", join(dir, "absent.md")]).status, 1);
assert.equal(run(["--record-file", file("ok.json", JSON.stringify(record)), "--hr", "1", "--settles-file", file("empty.md", "\n")]).status, 2, "the settles cell is authored, never empty");
for (const args of [[], ["--hr", "1", "--settles-file", settles], ["--record-file", file("ok.json", JSON.stringify(record)), "--settles-file", settles], ["--record-file", file("ok.json", JSON.stringify(record)), "--hr", "0", "--settles-file", settles],
  ["--record-file", file("ok.json", JSON.stringify(record)), "--hr", "1", "--settles-file", settles, "--status", "final"], ["--record-file", file("ok.json", JSON.stringify(record)), "--effort", "x", "--id", "R-2026-10-23-01", "--hr", "1", "--settles-file", settles],
  ["--effort", "x", "--hr", "1", "--settles-file", settles], ["--record-file", file("ok.json", JSON.stringify(record)), "--hr", "1", "--settles-file", settles, "--bogus"]]) {
  r = run(args);
  assert.equal(r.status, 2, `${args.join(" ")}: exit ${r.status} ${r.stderr}`);
}

// 4. The --effort form: one answer recorded through the real nen into a throwaway repository's common
// dir, read back by id; an id not in the ledger and a ledger nen cannot name are 1; a missing nen is 5.
const repo = join(dir, "repo");
assert.equal(spawnSync("git", ["init", "-q", repo], { encoding: "utf8" }).status, 0);
const q = file("q.md", "Which equivalent binds this port?\n");
const recorded = spawnSync(nen, ["stop", "answer", "--record", "FX-IS-#1", "--gate", "G5", "--who", "Kurapika", "--question-file", q, "--option", "A=Quote the pair row::binds to the existing row", "--option", "B=Type the equivalent::a new row is reserved", "--pick", "B", "--repo", repo, "--json"], { encoding: "utf8" });
assert.equal(recorded.status, 0, recorded.stderr);
const written = (JSON.parse(recorded.stdout) as { record: { id: string } }).record.id;
assert.match(written, /^R-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2,}$/);
r = run(["--effort", "FX-IS-#1", "--id", written, "--repo", repo, "--hr", "7", "--settles-file", settles]);
assert.equal(r.status, 0, r.stderr);
assert.ok(r.stdout.startsWith("| <a id=\"hr-7\"></a>**HR-7** | Which equivalent binds this port? | (A) Quote the pair row · (B) Type the equivalent | `Type the equivalent` | ruled | "), r.stdout);
assert.ok(r.stdout.includes(`— record \`${written}\` (FX-IS-#1, ${written.slice(2, 12)}) |`), r.stdout);
r = run(["--effort", "FX-IS-#1", "--id", "R-1999-01-01-99", "--repo", repo, "--hr", "7", "--settles-file", settles]);
assert.equal(r.status, 1, "an id the ledger does not hold is never a row");
assert.equal(run(["--effort", "FX-IS-#1", "--id", written, "--repo", join(dir, "not-a-repo"), "--hr", "7", "--settles-file", settles]).status, 1, "a repository nen cannot read is 1");
assert.equal(spawnSync(process.execPath, [script, "--effort", "FX-IS-#1", "--id", written, "--repo", repo, "--hr", "7", "--settles-file", settles], { encoding: "utf8", env: { ...process.env, NEN: join(dir, "no-such-nen") } }).status, 5, "absent nen is a missing tool");
assert.equal(render(readRecord(JSON.stringify(record)), 1, "x", "ruled").cells.pick, "`Keep merged (Recommended)`");

console.log(`ruling-row: nen ${probe.stdout.trim()} -- picked and typed rows, one-line cells with hostile text dropped, every malformed record, usage, and the --effort read-back through nen stop answer passed`);
