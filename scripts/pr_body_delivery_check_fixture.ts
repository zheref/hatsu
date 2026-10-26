#!/usr/bin/env node
/** HA#321 hostile, ledger-completeness, rendering, path and wrapper fixtures. */
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  chmodSync,
  lstatSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve as resolvePath } from "node:path";
import { after, test } from "node:test";
import { fileURLToPath } from "node:url";

import { compareBody, normalize, type DeliveryDocument } from "./pr_delivery.ts";

const ROOT = resolvePath(dirname(fileURLToPath(import.meta.url)), "..");
const ENGINE = join(ROOT, "scripts/pr_delivery.ts");
const GUARD = join(ROOT, "scripts/pr_body_delivery_check.sh");
const TEMPLATE = join(ROOT, "templates/pr-delivery.md");
const temp = mkdtempSync(join(tmpdir(), "ha321-delivery-"));
const repo = join(temp, "repo");
const effort = "codex/sol/kurapika/fixture";

function run(command: string, args: readonly string[], cwd = repo, env: NodeJS.ProcessEnv = process.env): ReturnType<typeof spawnSync> {
  return spawnSync(command, [...args], { cwd, env, encoding: "utf8" });
}
function ok(command: string, args: readonly string[], cwd = repo, env: NodeJS.ProcessEnv = process.env): string {
  const result = run(command, args, cwd, env);
  assert.equal(result.status, 0, `${result.stdout}${result.stderr}`);
  return result.stdout;
}
function git(...args: string[]): void { ok("git", args); }

mkdirSync(repo, { recursive: true });
mkdirSync(join(repo, "nen"));
mkdirSync(join(repo, ".nen/reports"), { recursive: true, mode: 0o700 });
writeFileSync(join(repo, "nen/workflow.json"), JSON.stringify({
  branch: { base: "main" },
  models: {
    codex: { frontier: "astra", deep: "sol", fast: "terra", economy: "luna" },
    claude: { frontier: "fable", deep: "opus", fast: "sonnet", economy: "haiku" },
    cursor: { frontier: "grok", deep: "grok", fast: "composer", economy: "composer" },
    roles: { reviewer: "deep", worker: "fast", orchestrator: "frontier" },
  },
}));
git("init", "-q", "-b", "main"); git("config", "user.name", "Fixture"); git("config", "user.email", "fixture@example.invalid");
git("add", "."); git("commit", "-qm", "base"); git("switch", "-qc", effort);
// The direct record lives in nen's durable home, the git common directory (zheref/nen#509), never the
// checkout's own .nen/: the fixture writes it there so the engine is held to the path nen writes.
const directRecord = JSON.stringify({
  contract: "nen.direct.resolve/v0.1", mismatch: { match: true, compares: [
    { field: "surface", session: "codex", recommended: "codex", verdict: "match" },
    { field: "model", session: "sol", recommended: "sol", verdict: "match" },
    { field: "effort", session: "unread", recommended: "max", verdict: "unread" },
  ] },
});
const durableDirect = join(repo, ".git/.nen/direct");
mkdirSync(durableDirect, { recursive: true });
writeFileSync(join(durableDirect, `${encodeURIComponent(effort)}.json`), directRecord);

const report = {
  contract: "nen.report.data/v0.1",
  phases: [
    { effort, phase: "author", startedAt: "2026-10-20T10:00:00.000Z", surface: "codex", model: "sol", dial: "unread" },
    { effort, phase: "pr", startedAt: "2026-10-20T10:00:30.000Z", surface: "codex", model: "gpt-6-sol", dial: "high" },
    { effort, phase: "readiness", startedAt: "2026-10-20T10:00:45.000Z", surface: "codex", model: "gpt-6-sol", dial: "xhigh", note: "model-kind=served; registry alias sol; PRIVATE_NOTE_CANARY" },
    { effort: "other/branch", phase: "author", startedAt: "2026-10-20T09:00:00.000Z", surface: "codex", model: "astra", dial: "max" },
  ],
  usage: [
    { effort, recordedAt: "2026-10-20T10:01:00.000Z", surface: "codex", model: "gpt-6-sol", dial: "high", source: "delegate author canon321; registry alias sol (Codex deep); exact served model from spawn_agent" },
    { effort, recordedAt: "2026-10-20T10:02:00.000Z", surface: "codex", model: "gpt-5.6-sol", dial: "high", source: "delegate author machinery321; registry alias terra (Codex fast); exact served model from assigned adapter; PRIVATE_USAGE_CANARY | <script>\n\u001b[2J\u202e" },
    { effort, recordedAt: "2026-10-20T10:03:00.000Z", surface: "codex", model: "gpt-5.6-sol", dial: "xhigh", source: "hanten § 4: hisoka, counters unavailable; model-kind=served; PRIVATE_REVIEW_CANARY" },
    { effort, recordedAt: "2026-10-20T10:03:30.000Z", surface: "claude-code", model: "claude-opus-5-5", dial: "high", source: "hanten § 4: chrollo, counters unavailable; model-kind=served; PRIVATE_CLAUDE_CANARY" },
    { effort, recordedAt: "2026-10-20T10:03:45.000Z", surface: "codex", model: "custom-opaque", dial: "high", source: "delegate author opaque321; unclassified caller token" },
    { effort: "ha-321-pr-delivery", recordedAt: "2026-10-20T08:00:00.000Z", surface: "codex", model: null, dial: null, source: "old intake" },
  ],
  sessions: [
    { effort, recordedAt: "2026-10-20T10:00:00.020Z", surface: "codex", model: "sol", dial: "unread", title: null, id: "thread-321", source: "Codex thread id; PRIVATE_SESSION_CANARY" },
    { effort, recordedAt: "2026-10-20T10:00:30.020Z", surface: "codex", model: "gpt-6-sol", dial: "high", title: null, id: "served-session", source: "exact served model from harness" },
    { effort, recordedAt: "2026-10-20T10:04:00.000Z", surface: "cursor", model: "composer", dial: "medium", title: null, id: "unmatched-session", source: "session identity only" },
    { effort: "other/branch", recordedAt: "2026-10-20T09:00:00.000Z", surface: "codex", model: "astra", dial: "max", title: null, id: "other", source: "foreign" },
  ],
  gate: "G4 — yours",
  objects: [],
};

let document: DeliveryDocument;
let rendered = "";
after((): void => {
  rmSync(temp, { recursive: true, force: true });
  console.log("pr-body-delivery fixture: exact effort, roles, served IDs and aliases, sessions, hostile cells, Nen render, row guard, private paths, wrapper and per-effort Delivery passed");
});

test("normalization filters the exact branch and keeps served IDs separate from proved aliases", () => {
  document = normalize(repo, report, "G4");
  assert.equal(document.effort, effort);
  assert.equal(document.deliveryRows.length, 9);
  const canon = document.deliveryRows.find((row): boolean => row.role.includes("canon321"));
  const machinery = document.deliveryRows.find((row): boolean => row.role.includes("machinery321"));
  const reviewer = document.deliveryRows.find((row): boolean => row.role.includes("hisoka"));
  const claudeReviewer = document.deliveryRows.find((row): boolean => row.role.includes("chrollo"));
  const author = document.deliveryRows.find((row): boolean => row.role === "author");
  const landing = document.deliveryRows.find((row): boolean => row.role === "landing");
  const readiness = document.deliveryRows.find((row): boolean => row.role === "readiness");
  const opaque = document.deliveryRows.find((row): boolean => row.role.includes("opaque321"));
  const unmatched = document.deliveryRows.find((row): boolean => row.session.includes("unmatched-session"));
  assert.equal(canon?.model, "exact: gpt-6-sol · alias: sol");
  assert.equal(machinery?.model, "exact: gpt-5.6-sol · alias: terra");
  assert.equal(reviewer?.model, "exact: gpt-5.6-sol · alias: unread");
  assert.equal(claudeReviewer?.model, "exact: claude-opus-5-5 · alias: unread");
  assert.equal(author?.model, "exact: unread · alias: sol");
  assert.equal(landing?.model, "exact: gpt-6-sol · alias: unread");
  assert.equal(readiness?.model, "exact: gpt-6-sol · alias: sol");
  assert.match(readiness?.source ?? "", /^phase\\\[2\\\] · 2026-10-20T10:00:45\.000Z · readiness$/);
  assert.equal(opaque?.model, "exact: unread (recorded token: custom-opaque; classification unread) · alias: unread");
  assert.match(author?.session ?? "", /thread-321/);
  assert.match(unmatched?.role ?? "", /^unread/);
  assert.ok(document.deliveryRows.every((row): boolean => !row.source.includes("old intake") && !row.session.includes("other")));
  assert.ok(!JSON.stringify(document).includes("PRIVATE_"));
  assert.ok(!JSON.stringify(document).includes("&lt;script&gt;"));
  assert.ok(!JSON.stringify(document).includes("\u001b"));
  assert.ok(!JSON.stringify(document).includes("\u202e"));
  const currentHead = ok("git", ["rev-parse", "HEAD"]).trim();
  const postOpen = normalize(repo, { ...report, branch: effort, objects: [{ kind: "pr", number: 321, notation: "HA-PR-#321", url: "https://github.com/zheref/hatsu/pull/321", head: currentHead }] }, "G4");
  assert.equal(postOpen.drive, "gate forecast: G4; next: hatsu:en on HA-PR-#321; readiness is nen pr ready's verdict");
  const ambiguous = normalize(repo, { ...report, sessions: [...report.sessions, { effort, recordedAt: "2026-10-20T10:00:00.030Z", surface: "codex", model: "sol", dial: "unread", title: null, id: "second-thread", source: "another matching identity" }] });
  const ambiguousAuthor = ambiguous.deliveryRows.find((row): boolean => row.role === "author");
  assert.equal(ambiguousAuthor?.session, "unread — multiple matching sessions");
  assert.ok(ambiguous.deliveryRows.some((row): boolean => row.session.includes("thread-321")));
  assert.ok(ambiguous.deliveryRows.some((row): boolean => row.session.includes("second-thread")));
  const duplicateIdentity = normalize(repo, { ...report, sessions: [...report.sessions, { effort, recordedAt: "2026-10-20T10:00:00.030Z", surface: "codex", model: "sol", dial: "unread", title: null, id: "thread-321", source: "duplicate ledger entry for the same identity" }] });
  const duplicateAuthor = duplicateIdentity.deliveryRows.find((row): boolean => row.role === "author");
  assert.match(duplicateAuthor?.session ?? "", /thread-321/);
  assert.equal(duplicateIdentity.deliveryRows.filter((row): boolean => row.session.includes("thread-321")).length, 2);
});

test("reviewer spend attributes initial, numbered and bounded delta passes including HA-PR-#433 history", () => {
  const sources = [
    ["hanten § 4: phinks, subagent tokens 46513", "phinks"],
    ["hanten § 4: nobunaga round 2, subagent tokens 85843", "nobunaga"],
    ["hanten § 4: phinks round 2, counters unavailable", "phinks"],
    ["hanten § 4: chrollo round 10, counters unavailable", "chrollo"],
    ["hanten § 4: feitan delta since 3830f0e, counters unavailable", "feitan"],
    ["hanten § 4: phinks delta since 3830f0eb3d46363b8e61051d68f57799a2328734, counters unavailable; registry alias sol", "phinks"],
    ["hanten § 4: feitan delta, subagent tokens 29348", "feitan"],
    ["hanten § 4: phinks delta, subagent tokens 29348", "phinks"],
    ["hanten § 4: chrollo delta, subagent tokens 29348", "chrollo"],
  ];
  const data = { ...report, phases: [], sessions: [], usage: sources.map(([source]) => ({
    effort, recordedAt: "2026-10-20T10:01:00.000Z", surface: "codex", model: "sol", dial: "high", source,
  })) };
  const before = JSON.stringify(data);
  const result = normalize(repo, data);
  assert.deepEqual(result.deliveryRows.map((row) => row.role), sources.map(([, persona]) => `reviewer · ${persona}`));
  assert.equal(result.deliveryRows.length, sources.length);
  assert.ok(result.deliveryRows.every((row) => row.model === "exact: unread · alias: sol"));
  assert.equal(JSON.stringify(data), before, "normalization must not rewrite ledger fields or review history");
  const normalized = join(repo, ".nen/reports/reviewer-passes.json");
  const renderedPasses = join(repo, ".nen/reports/reviewer-passes.md");
  writeFileSync(normalized, JSON.stringify(result), { mode: 0o600 });
  ok("nen", ["report", "render", "--template", TEMPLATE, "--data", normalized, "--out", renderedPasses, "--repo", repo]);
  const body = readFileSync(renderedPasses, "utf8");
  assert.equal((body.match(/\| reviewer · /g) ?? []).length, sources.length);
  assert.ok(!body.includes("unread — usage records no supported role"));
  assert.ok(!body.includes("subagent tokens"), "private source readouts stay local");
  assert.deepEqual(compareBody(`${body}\n# Changes\n`, body), []);
});

test("malformed Hanten usage refuses with the indexed record and expected source forms", () => {
  for (const source of [
    "hanten § 4: chrollo", "hanten § 4: chrollo,", "hanten § 4: chrollo,   ",
    "hanten § 4: chrollo round 0, counters unavailable", "hanten § 4: chrollo round -1, counters unavailable",
    "hanten § 4: chrollo round 02, counters unavailable", "hanten § 4: chrollo round two, counters unavailable",
    "hanten § 4: chrollo delta since potato, counters unavailable", "hanten § 4: chrollo delta since abc123, counters unavailable",
    "hanten § 4: chrollo delta since ABC1234, counters unavailable", "hanten § 4: chrollo round 2 delta, counters unavailable",
    "hanten § 4 chrollo, counters unavailable", "hanten § 5: chrollo, counters unavailable",
    "Hanten § 4: chrollo, counters unavailable", "hanten: chrollo, counters unavailable",
  ]) {
    assert.throws(() => normalize(repo, { ...report, usage: [{ ...report.usage[0], source }] }), (error: unknown) => {
      assert.ok(error instanceof Error);
      assert.match(error.message, /^usage\[0\]\.source: malformed Hanten reviewer source; expected /);
      assert.ok(error.message.includes("<persona> round <positive integer>"));
      assert.ok(error.message.includes("<persona> delta since <7–40 lowercase hex SHA>"));
      return true;
    }, source);
  }
});

test("unrelated usage and phase records retain their roles and foreign malformed usage stays excluded", () => {
  const data = { ...report, sessions: [], phases: [{ ...report.phases[0], note: "hanten § 4: historical phase note" }], usage: [
    { ...report.usage[0], source: "ren: author counters unavailable", futureField: { preserve: true } },
    { ...report.usage[0], source: "mukai: landing counters unavailable" },
    { ...report.usage[0], source: "opaque source mentioning hanten § 4: chrollo" },
    { ...report.usage[0], source: "hantenish: counters unavailable" },
    { ...report.usage[0], effort: "another/branch", source: "hanten § 4: chrollo" },
  ] };
  const before = JSON.stringify(data);
  assert.deepEqual(normalize(repo, data).deliveryRows.map((row) => row.role), [
    "author", "author", "landing", "unread — usage records no supported role", "unread — usage records no supported role",
  ]);
  assert.equal(JSON.stringify(data), before);
});

test("the direct record is read from the common directory, the older checkout home in place, and both homes refused", () => {
  const name = `${encodeURIComponent(effort)}.json`;
  const authorAlias = (): string | undefined => normalize(repo, report).deliveryRows.find((row): boolean => row.role === "author")?.model;
  assert.equal(authorAlias(), "exact: unread · alias: sol");
  const legacyDir = join(repo, ".nen/direct");
  mkdirSync(legacyDir, { recursive: true });
  writeFileSync(join(legacyDir, name), directRecord);
  assert.throws((): unknown => normalize(repo, report), /in both homes/);
  rmSync(join(durableDirect, name));
  writeFileSync(join(legacyDir, name), JSON.stringify({ session: 5 }));
  assert.throws((): unknown => normalize(repo, report), (error: Error): boolean => error.message.startsWith(join(repo, ".nen/direct")) && /session must be an object/.test(error.message));
  rmSync(join(legacyDir, name));
  writeFileSync(join(durableDirect, name), JSON.stringify({ session: 5 }));
  assert.throws((): unknown => normalize(repo, report), (error: Error): boolean => error.message.includes(".git/.nen/direct") && /session must be an object/.test(error.message));
  writeFileSync(join(durableDirect, name), directRecord);
  assert.equal(authorAlias(), "exact: unread · alias: sol");
});

test("Nen alone renders Markdown and the semantic guard names missing, duplicate and extra rows", () => {
  const data = join(repo, ".nen/reports/normalized.json");
  const out = join(repo, ".nen/reports/rendered.md");
  writeFileSync(data, `${JSON.stringify(document)}\n`, { mode: 0o600 });
  ok("nen", ["report", "render", "--template", TEMPLATE, "--data", data, "--out", out, "--repo", repo]);
  rendered = readFileSync(out, "utf8");
  assert.match(rendered, /^## 📬 Delivery\n/);
  assert.match(rendered, /exact: gpt-6-sol · alias: sol/);
  assert.match(rendered, /exact: gpt-5\.6-sol · alias: terra/);
  assert.match(rendered, /unmatched-session/);
  assert.ok(!rendered.includes("PRIVATE_"));
  const body = `${rendered}\n# ✨ What this changes for you\n`;
  assert.deepEqual(compareBody(body, rendered), []);
  const wrongGate = rendered.replace("gate forecast: G4", "gate forecast: G2");
  assert.match(compareBody(`${wrongGate}\n# Changes`, rendered).join("\n"), /Drive differs from rendered current-effort expectation/);
  const wrongPr = rendered.replace(/next: unread — [^;]+;/, "next: hatsu:en on HA-PR-#999;");
  assert.match(compareBody(`${wrongPr}\n# Changes`, rendered).join("\n"), /Drive differs from rendered current-effort expectation/);
  const lines = rendered.split("\n");
  const dataRows = lines.filter((line): boolean => /^\| .* \|$/.test(line) && !line.startsWith("| Role "));
  const missing = rendered.replace(`${dataRows[0]}\n`, "");
  assert.match(compareBody(`${missing}\n# Changes`, rendered).join("\n"), /missing ledger row/);
  const duplicate = rendered.replace(`${dataRows[0]}\n`, `${dataRows[0]}\n${dataRows[0]}\n`);
  assert.match(compareBody(`${duplicate}\n# Changes`, rendered).join("\n"), /extra or duplicate/);
  const extra = rendered.replace("\n*Drive:*", "\n| foreign | codex | exact: fake · alias: sol | high | fake | fixture |\n\n*Drive:*");
  assert.match(compareBody(`${extra}\n# Changes`, rendered).join("\n"), /extra or duplicate/);
  assert.match(compareBody(`${rendered.replace("*Drive:*", "*Drive:* changed ")}\n# Changes`, rendered).join("\n"), /Drive must name/);
});

test("CLI writes mode 0600 and refuses output and input symlinks", () => {
  const data = join(repo, ".nen/reports/report.json");
  const out = join(repo, ".nen/reports/cli-normalized.json");
  writeFileSync(data, JSON.stringify(report), { mode: 0o600 });
  const result = run(process.execPath, [ENGINE, "normalize", "--data", data, "--out", out, "--repo", repo]);
  assert.equal(result.status, 0, `${result.stdout}${result.stderr}`);
  assert.equal(lstatSync(out).mode & 0o777, 0o600);
  const malformedData = join(repo, ".nen/reports/malformed-review.json");
  const refusedOut = join(repo, ".nen/reports/refused-review.json");
  writeFileSync(malformedData, JSON.stringify({ ...report, usage: [{ ...report.usage[0], source: "hanten § 4: chrollo" }] }));
  const malformed = run(process.execPath, [ENGINE, "normalize", "--data", malformedData, "--out", refusedOut, "--repo", repo]);
  assert.equal(malformed.status, 2);
  assert.match(malformed.stderr, /usage\[0\]\.source: malformed Hanten reviewer source; expected/);
  assert.throws(() => lstatSync(refusedOut), { code: "ENOENT" });
  const link = join(repo, ".nen/reports/link.json");
  symlinkSync(out, link);
  const linkedOut = run(process.execPath, [ENGINE, "normalize", "--data", data, "--out", link, "--repo", repo]);
  assert.equal(linkedOut.status, 2); assert.match(linkedOut.stderr, /symlink/);
  const linkedData = run(process.execPath, [ENGINE, "normalize", "--data", link, "--out", join(repo, ".nen/reports/no.json"), "--repo", repo]);
  assert.equal(linkedData.status, 2); assert.match(linkedData.stderr, /symlink/);
  const outside = join(temp, "outside-report.json"); writeFileSync(outside, JSON.stringify(report));
  const outsideRead = run(process.execPath, [ENGINE, "normalize", "--data", outside, "--out", join(repo, ".nen/reports/outside.json"), "--repo", repo]);
  assert.equal(outsideRead.status, 0, `${outsideRead.stdout}${outsideRead.stderr}`);
  const outsideBody = join(temp, "outside-body.md"); writeFileSync(outsideBody, `${rendered}\n# Changes\n`);
  const outsideBodyRead = run(process.execPath, [ENGINE, "check", "--body", outsideBody, "--expected", join(repo, ".nen/reports/rendered.md"), "--repo", repo]);
  assert.equal(outsideBodyRead.status, 0, `${outsideBodyRead.stdout}${outsideBodyRead.stderr}`);
});

test("shell guard composes report data, normalization and Nen rendering from the plugin's own template, and propagates report failure", () => {
  // The target carries no templates/ (a consumer never does): the guard renders from the plugin root.
  rmSync(join(repo, "templates"), { recursive: true, force: true });
  const realNen = ok("sh", ["-c", "command -v nen"], repo).trim();
  const currentHead = ok("git", ["rev-parse", "HEAD"]).trim();
  const postReport = { ...report, objects: [{ kind: "pr", number: 321, notation: "HA-PR-#321", url: "https://github.com/zheref/hatsu/pull/321", head: currentHead }] };
  const wrongPrReport = { ...report, objects: [{ kind: "pr", number: 322, notation: "HA-PR-#322", url: "https://github.com/zheref/hatsu/pull/322", head: currentHead }] };
  const reportPath = join(repo, ".nen/reports/report.json");
  const postReportPath = join(repo, ".nen/reports/report-pr.json");
  const wrongPrReportPath = join(repo, ".nen/reports/report-wrong-pr.json");
  writeFileSync(reportPath, JSON.stringify(report), { mode: 0o600 });
  writeFileSync(postReportPath, JSON.stringify(postReport), { mode: 0o600 });
  writeFileSync(wrongPrReportPath, JSON.stringify(wrongPrReport), { mode: 0o600 });
  const postDataPath = join(repo, ".nen/reports/post-normalized.json");
  const postRenderedPath = join(repo, ".nen/reports/post-rendered.md");
  writeFileSync(postDataPath, JSON.stringify(normalize(repo, postReport, "G4")), { mode: 0o600 });
  ok(realNen, ["report", "render", "--template", TEMPLATE, "--data", postDataPath, "--out", postRenderedPath, "--repo", repo]);
  const bin = join(temp, "bin"); mkdirSync(bin);
  const fake = join(bin, "nen");
  writeFileSync(fake, `#!/usr/bin/env bash
set -euo pipefail
if [ "\${1:-} \${2:-}" = 'report data' ]; then
  [ "\${FAKE_REPORT_FAIL:-0}" = 0 ] || exit 7
  actual_target=''
  actual_pr=''
  actual_effort=''
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --effort) actual_effort="$2"; shift 2 ;;
      --target) actual_target="$2"; shift 2 ;;
      --prs) actual_pr="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ "$actual_effort" = "\${EXPECT_EFFORT:-}" ] || exit 9
  if [ -n "\${EXPECT_TARGET:-}" ]; then [ "$actual_target" = "$EXPECT_TARGET" ] || exit 8; fi
  if [ -n "\${EXPECT_PR:-}" ]; then [ "$actual_pr" = "$EXPECT_PR" ] || exit 8; fi
  if [ "\${EXPECT_NO_PR:-0}" = 1 ]; then [ -z "$actual_target" ] && [ -z "$actual_pr" ] || exit 8; fi
  cat "$FIXTURE_REPORT"
  exit 0
fi
exec "$REAL_NEN" "$@"
`);
  chmodSync(fake, 0o755);
  const body = join(temp, "guard-body.md"); writeFileSync(body, `${rendered}\n# ✨ What this changes for you\n`);
  const postBody = join(temp, "guard-post-body.md"); writeFileSync(postBody, `${readFileSync(postRenderedPath, "utf8")}\n# ✨ What this changes for you\n`);
  const env = { ...process.env, PATH: `${bin}:${process.env.PATH ?? ""}`, REAL_NEN: realNen, FIXTURE_REPORT: reportPath, EXPECT_NO_PR: "1", EXPECT_EFFORT: effort };
  const passed = run("bash", [GUARD, "--body", body, "--repo", repo, "--base", "main", "--gate-forecast", "G4"], repo, env);
  assert.equal(passed.status, 0, `${passed.stdout}${passed.stderr}`);
  assert.match(passed.stdout, /every current-effort ledger row/);
  // A template the target plants is never read in place of the plugin's.
  mkdirSync(join(repo, "templates"), { recursive: true });
  writeFileSync(join(repo, "templates/pr-delivery.md"), "## 📬 Delivery\n\nplanted by the target\n");
  const planted = run("bash", [GUARD, "--body", body, "--repo", repo, "--base", "main", "--gate-forecast", "G4"], repo, env);
  assert.equal(planted.status, 0, `${planted.stdout}${planted.stderr}`);
  // ...and never stands in when the plugin's own is missing: a plugin root without it refuses.
  const bare = join(temp, "bare-plugin"); mkdirSync(join(bare, "scripts"), { recursive: true });
  for (const file of ["pr_body_delivery_check.sh", "pr_delivery.ts"]) writeFileSync(join(bare, "scripts", file), readFileSync(join(ROOT, "scripts", file)));
  const noTemplate = run("bash", [join(bare, "scripts/pr_body_delivery_check.sh"), "--body", body, "--repo", repo, "--base", "main", "--gate-forecast", "G4"], repo, env);
  assert.equal(noTemplate.status, 2, `${noTemplate.stdout}${noTemplate.stderr}`);
  assert.match(noTemplate.stderr, /bare-plugin\/scripts\/\.\.\/templates\/pr-delivery\.md/);
  rmSync(join(repo, "templates"), { recursive: true, force: true });
  // Through a symlinked plugin root (~/.claude/skills/hatsu is one), from a cwd outside the target.
  const linked = join(temp, "linked plugin root"); symlinkSync(ROOT, linked);
  const viaLink = run("bash", [join(linked, "scripts/pr_body_delivery_check.sh"), "--body", body, "--repo", repo, "--base", "main", "--gate-forecast", "G4"], temp, env);
  assert.equal(viaLink.status, 0, `${viaLink.stdout}${viaLink.stderr}`);
  assert.match(viaLink.stdout, /every current-effort ledger row/);
  // shibari § 3 runs the engine itself through $hatsu_root: through the link it must still act, not exit 0 silently.
  const linkedOut = join(repo, ".nen/reports/linked-normalized.json");
  const direct = run(process.execPath, [join(linked, "scripts/pr_delivery.ts"), "normalize", "--data", reportPath, "--out", linkedOut, "--repo", repo, "--gate-forecast", "G4"], temp);
  assert.equal(direct.status, 0, `${direct.stdout}${direct.stderr}`);
  assert.match(direct.stdout, /pr-delivery normalized/);
  const postEnv = { ...env, FIXTURE_REPORT: postReportPath, EXPECT_NO_PR: "0", EXPECT_TARGET: "zheref/hatsu", EXPECT_PR: "321" };
  const postPassed = run("bash", [GUARD, "--body", postBody, "--repo", repo, "--base", "main", "--gate-forecast", "G4", "--target", "zheref/hatsu", "--pr", "321"], repo, postEnv);
  assert.equal(postPassed.status, 0, `${postPassed.stdout}${postPassed.stderr}`);
  const wrongPr = run("bash", [GUARD, "--body", postBody, "--repo", repo, "--base", "main", "--gate-forecast", "G4", "--target", "zheref/hatsu", "--pr", "322"], repo, { ...postEnv, FIXTURE_REPORT: wrongPrReportPath, EXPECT_PR: "322" });
  assert.equal(wrongPr.status, 1, `${wrongPr.stdout}${wrongPr.stderr}`); assert.match(wrongPr.stdout, /Drive differs from rendered current-effort expectation/);
  const wrongGate = run("bash", [GUARD, "--body", postBody, "--repo", repo, "--base", "main", "--gate-forecast", "G2", "--target", "zheref/hatsu", "--pr", "321"], repo, postEnv);
  assert.equal(wrongGate.status, 1, `${wrongGate.stdout}${wrongGate.stderr}`); assert.match(wrongGate.stdout, /Drive differs from rendered current-effort expectation/);
  const invalidPr = run("bash", [GUARD, "--body", body, "--repo", repo, "--base", "main", "--gate-forecast", "G4", "--target", "zheref/hatsu", "--pr", "0"], repo, env);
  assert.equal(invalidPr.status, 2); assert.match(invalidPr.stderr, /positive integer/);
  const failed = run("bash", [GUARD, "--body", body, "--repo", repo, "--base", "main", "--gate-forecast", "G4"], repo, { ...env, FAKE_REPORT_FAIL: "1" });
  assert.equal(failed.status, 7); assert.match(failed.stderr, /exit 7/);
  // No branch, no effort: a detached HEAD is refused before nen is asked, never read globally.
  git("switch", "-q", "--detach");
  const detached = run("bash", [GUARD, "--body", body, "--repo", repo, "--base", "main", "--gate-forecast", "G4"], repo, env);
  git("switch", "-q", effort);
  assert.equal(detached.status, 2, `${detached.stdout}${detached.stderr}`); assert.match(detached.stderr, /current branch is unread/);
});

test("a body rendered by shibari § 3's exact commands (report data --effort <branch>) passes the guard against real nen ledgers (zheref/hatsu#492)", () => {
  const perEffort = join(temp, "per-effort");
  const branchName = "claude/opus/kurapika/per-effort";
  mkdirSync(join(perEffort, "nen"), { recursive: true });
  writeFileSync(join(perEffort, "nen/workflow.json"), readFileSync(join(repo, "nen/workflow.json")));
  const inPerEffort = (...args: string[]): string => ok(args[0] as string, args.slice(1), perEffort);
  inPerEffort("git", "init", "-q", "-b", "main"); inPerEffort("git", "config", "user.name", "Fixture"); inPerEffort("git", "config", "user.email", "fixture@example.invalid");
  inPerEffort("git", "add", "."); inPerEffort("git", "commit", "-qm", "base"); inPerEffort("git", "switch", "-qc", branchName);
  // A sibling effort's rows sit in the same shared ledgers: read globally they shift every index.
  for (const phase of ["breath", "rasengan", "kokusen"]) inPerEffort("nen", "phase", "begin", "--effort", "aaa-sibling-effort", "--phase", phase, "--surface", "codex", "--model", "sol", "--dial", "high", "--repo", perEffort);
  for (const phase of ["breath", "rasengan"]) inPerEffort("nen", "phase", "begin", "--effort", branchName, "--phase", phase, "--surface", "claude-code", "--model", "opus", "--dial", "medium", "--repo", perEffort);
  const reports = join(perEffort, ".nen/reports"); mkdirSync(reports, { recursive: true, mode: 0o700 });
  const renderFrom = (name: string, extra: readonly string[]): string => {
    const data = join(reports, `${name}-data.json`); const normalized = join(reports, `${name}-normalized.json`); const out = join(reports, `${name}.md`);
    writeFileSync(data, inPerEffort("nen", "report", "data", "--repo", perEffort, "--base", "main", ...extra, "--json"), { mode: 0o600 });
    inPerEffort(process.execPath, ENGINE, "normalize", "--data", data, "--out", normalized, "--repo", perEffort, "--gate-forecast", "G4");
    inPerEffort("nen", "report", "render", "--template", TEMPLATE, "--data", normalized, "--out", out, "--repo", perEffort);
    const body = join(temp, `${name}-body.md`); writeFileSync(body, `${readFileSync(out, "utf8")}\n# ✨ What this changes for you\n`);
    return body;
  };
  const shibariBody = renderFrom("per-effort", ["--effort", branchName]);
  assert.match(readFileSync(shibariBody, "utf8"), /phase\\\[0\\\]/);
  const guarded = run("bash", [GUARD, "--body", shibariBody, "--repo", perEffort, "--base", "main", "--gate-forecast", "G4"], perEffort);
  assert.equal(guarded.status, 0, `${guarded.stdout}${guarded.stderr}`);
  assert.match(guarded.stdout, /every current-effort ledger row/);
  // The pre-#492 shape (indices numbered across every effort) is the one the guard now refuses.
  const globalBody = renderFrom("global", []);
  const refused = run("bash", [GUARD, "--body", globalBody, "--repo", perEffort, "--base", "main", "--gate-forecast", "G4"], perEffort);
  assert.equal(refused.status, 1, `${refused.stdout}${refused.stderr}`);
  assert.match(refused.stdout, /missing ledger row|extra or duplicate/);
});
