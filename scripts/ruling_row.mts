#!/usr/bin/env node
// ruling_row.mts — render one ROSTER ruling row from a recorded stop answer, never retyped.
//
// A picker's answer is recorded by `nen stop answer --record <effort> --row <id> | --gate <g> ...`
// (nen 0.26.0, `nen.stop.answer/v0.1`, under the git common dir's .nen/stops/<effort>/); the ROSTER
// row a sitting adds (docs/ROSTER.md § The ruling template, step 3) carries the record's own fields:
// the question as asked, the options as shown, the pick as the picker returned it or the typed words
// verbatim. This script copies those cells out of the record and adds the two the lead authors — the
// HR id and *What it settles* — so no cell of a ruling is a memory of the stop.
//
// USAGE
//   node scripts/ruling_row.mts (--record-file <path> | --effort <id> --id <R-YYYY-MM-DD-nn> [--repo <checkout>])
//        --hr <n> --settles-file <path> [--status ruled|reading] [--json]
//
//   --record-file <path>  one nen.stop.answer/v0.1 document (a fixture's, or a file `nen stop answer
//                         show --json` was saved to).
//   --effort <id> --id <R-…>  the record read through `nen stop answer show <effort> --repo <checkout>
//                         --json` (NEN, else PATH's nen); the id must be one of the effort's records.
//   --hr <n>              the HR id the sitting assigns (a positive integer; the clause guard owns
//                         uniqueness).
//   --settles-file <path> the one authored cell, *What it settles*; non-empty.
//   --status              `ruled` (default) or `reading` (docs/ROSTER.md § How HR ids are read).
//   --json                { contract, hr, id, effortId, row, answeredAt, cells } instead of the row.
//
// THE ROW  `| <a id="hr-N"></a>**HR-N** | <question> | (<key>) <label> · … | <pick> | <status> | <settles> — record `R-…` (<effort>, <date>) |`
//   A picked answer renders the picked option's LABEL in backticks, as the ROSTER's capture class
//   reads a pick; a typed answer renders the words verbatim, unquoted. Cells are one line: a newline
//   run becomes one space, `|` is escaped, and control and bidi characters are dropped (QA-16) — the
//   record keeps the bytes, the row says what was answered.
//
// EXIT CODES (docs/PROCESS.md § Exit codes and refusals)
//   0  the row rendered
//   1  could not read: nen's show failed, the id is not among the effort's records, or an unreadable
//      record or settles file (could not look is never found nothing)
//   2  usage, a malformed record (contract, id, options, pick or typed out of shape), or --hr not a
//      positive integer, or an empty settles cell
//   5  nen absent on --effort
//
// Owed to nen as a render of `nen stop answer show` (unfiled); the fixture is scripts/ruling_row_fixture.mts
// (lane ruling-row-guard).
import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";

type Option = { key: string; label: string; consequence: string };
type Record_ = { contract: string; id: string; effortId: string; n: number; gate: string | null; row: string | null; who: string; question: string; options: Option[]; kind: "picked" | "typed"; pick: string | null; typed: string | null; answeredAt: string };

const USAGE = "usage: node scripts/ruling_row.mts (--record-file <path> | --effort <id> --id <R-YYYY-MM-DD-nn> [--repo <checkout>]) --hr <n> --settles-file <path> [--status ruled|reading] [--json]";
const ID = /^R-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2,}$/;

class Stop extends Error {
  code: number;
  constructor(code: number, message: string) { super(message); this.code = code; }
}

export function cell(text: string): string {
  return text
    .replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f​-‏‪-‮⁦-⁩﻿]/g, "")
    .replace(/\r\n?/g, "\n")
    .replace(/[ \t]*\n[ \t\n]*/g, " ")
    .replace(/\|/g, "\\|")
    .trim();
}

export function readRecord(raw: string): Record_ {
  let parsed: unknown;
  try { parsed = JSON.parse(raw); } catch (error) { throw new Stop(2, `the record is not JSON: ${(error as Error).message}`); }
  const r = parsed as Partial<Record_>;
  if (!r || typeof r !== "object") throw new Stop(2, "the record is not an object");
  if (r.contract !== "nen.stop.answer/v0.1") throw new Stop(2, `the record's contract is ${JSON.stringify(r.contract)}, not nen.stop.answer/v0.1`);
  if (typeof r.id !== "string" || !ID.test(r.id)) throw new Stop(2, `the record's id ${JSON.stringify(r.id)} is not R-YYYY-MM-DD-nn`);
  if (typeof r.effortId !== "string" || r.effortId === "") throw new Stop(2, "the record names no effort");
  if (typeof r.question !== "string" || r.question.trim() === "") throw new Stop(2, "the record carries no question");
  if (typeof r.answeredAt !== "string" || Number.isNaN(Date.parse(r.answeredAt))) throw new Stop(2, "the record's answeredAt is not an instant");
  if (!Array.isArray(r.options) || r.options.length === 0) throw new Stop(2, "the record lists no options");
  const keys = new Set<string>();
  for (const [i, o] of r.options.entries()) {
    const option = o as Partial<Option>;
    if (!option || typeof option.key !== "string" || typeof option.label !== "string" || typeof option.consequence !== "string" || option.key === "" || option.label === "") throw new Stop(2, `option [${i}] is not {key, label, consequence}`);
    if (keys.has(option.key)) throw new Stop(2, `option key ${option.key} appears twice`);
    keys.add(option.key);
  }
  if (r.kind === "picked") {
    if (typeof r.pick !== "string" || !keys.has(r.pick)) throw new Stop(2, `the pick ${JSON.stringify(r.pick)} is none of the option keys`);
  } else if (r.kind === "typed") {
    if (typeof r.typed !== "string" || r.typed.trim() === "") throw new Stop(2, "a typed answer carries no words");
  } else throw new Stop(2, `the record's kind is ${JSON.stringify(r.kind)}, not picked or typed`);
  return r as Record_;
}

export function render(record: Record_, hr: number, settles: string, status: "ruled" | "reading"): { row: string; cells: { id: string; question: string; options: string; pick: string; status: string; settles: string } } {
  const picked = record.kind === "picked" ? record.options.find((o) => o.key === record.pick) as Option : null;
  const cells = {
    id: `<a id="hr-${hr}"></a>**HR-${hr}**`,
    question: cell(record.question),
    options: record.options.map((o) => `(${cell(o.key)}) ${cell(o.label)}`).join(" · "),
    pick: picked ? `\`${cell(picked.label)}\`` : cell(record.typed as string),
    status,
    settles: `${cell(settles)} — record \`${record.id}\` (${cell(record.effortId)}, ${record.answeredAt.slice(0, 10)})`,
  };
  return { row: `| ${cells.id} | ${cells.question} | ${cells.options} | ${cells.pick} | ${cells.status} | ${cells.settles} |`, cells };
}

function args(argv: string[]): Map<string, string | true> {
  const map = new Map<string, string | true>();
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (!a.startsWith("--")) throw new Stop(2, `${USAGE}\nunexpected argument ${a}`);
    const key = a.slice(2);
    if (key === "json") { map.set(key, true); continue; }
    const value = argv[i + 1];
    if (value === undefined || value.startsWith("--")) throw new Stop(2, `${USAGE}\n--${key} needs a value`);
    if (map.has(key)) throw new Stop(2, `${USAGE}\n--${key} given twice`);
    map.set(key, value);
    i += 1;
  }
  return map;
}

function readFile(path: string, what: string): string {
  try { return readFileSync(path, "utf8"); } catch (error) { throw new Stop(1, `could not read ${what} ${path}: ${(error as Error).message}`); }
}

function main(argv: string[]): number {
  const a = args(argv);
  for (const key of a.keys()) if (!["record-file", "effort", "id", "repo", "hr", "settles-file", "status", "json"].includes(key)) throw new Stop(2, `${USAGE}\nunknown flag --${key}`);
  const file = a.get("record-file") as string | undefined;
  const effort = a.get("effort") as string | undefined;
  const id = a.get("id") as string | undefined;
  if ((file === undefined) === (effort === undefined)) throw new Stop(2, `${USAGE}\ngive exactly one of --record-file or --effort with --id`);
  if (effort !== undefined && (id === undefined || !ID.test(id))) throw new Stop(2, `${USAGE}\n--effort needs --id R-YYYY-MM-DD-nn`);
  if (file !== undefined && (id !== undefined || a.has("repo"))) throw new Stop(2, `${USAGE}\n--id and --repo are read with --effort only`);
  const hrRaw = a.get("hr");
  if (typeof hrRaw !== "string" || !/^[1-9][0-9]{0,5}$/.test(hrRaw)) throw new Stop(2, `${USAGE}\n--hr must be a positive integer`);
  const settlesFile = a.get("settles-file");
  if (typeof settlesFile !== "string") throw new Stop(2, `${USAGE}\n--settles-file is required`);
  const statusRaw = a.get("status") ?? "ruled";
  if (statusRaw !== "ruled" && statusRaw !== "reading") throw new Stop(2, `${USAGE}\n--status is ruled or reading`);
  const settles = readFile(settlesFile, "the settles file");
  if (settles.trim() === "") throw new Stop(2, "the settles cell is empty: what the ruling settles is the lead's to author");
  let record: Record_;
  if (file !== undefined) {
    record = readRecord(readFile(file, "the record"));
  } else {
    const nen = process.env.NEN ?? "nen";
    const show = spawnSync(nen, ["stop", "answer", "show", effort as string, "--repo", (a.get("repo") as string | undefined) ?? process.cwd(), "--json"], { encoding: "utf8" });
    if (show.error) throw new Stop(5, `nen is not reachable as '${nen}': ${show.error.message}`);
    if (show.status !== 0) throw new Stop(1, `nen stop answer show ${effort} exited ${show.status}: ${show.stderr.trim()}`);
    let ledger: { records?: unknown[] };
    try { ledger = JSON.parse(show.stdout) as { records?: unknown[] }; } catch { throw new Stop(1, "nen stop answer show printed no JSON ledger"); }
    const found = (ledger.records ?? []).find((r) => (r as { id?: unknown }).id === id);
    if (found === undefined) throw new Stop(1, `${id} is none of ${effort}'s ${(ledger.records ?? []).length} recorded answer(s)`);
    record = readRecord(JSON.stringify(found));
  }
  const rendered = render(record, Number(hrRaw), settles, statusRaw);
  if (a.has("json")) {
    process.stdout.write(`${JSON.stringify({ contract: "hatsu.ruling-row/v1", hr: Number(hrRaw), id: record.id, effortId: record.effortId, row: rendered.row, answeredAt: record.answeredAt, cells: rendered.cells }, null, 2)}\n`);
  } else process.stdout.write(`${rendered.row}\n`);
  return 0;
}

if (process.argv[1] && import.meta.filename && (await import("node:fs")).realpathSync(process.argv[1]) === (await import("node:fs")).realpathSync(import.meta.filename)) {
  try {
    process.exit(main(process.argv.slice(2)));
  } catch (error) {
    if (error instanceof Stop) { console.error(`ruling_row: ${error.message}`); process.exit(error.code); }
    console.error(`ruling_row: ${(error as Error).message}`);
    process.exit(1);
  }
}
