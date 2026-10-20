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
mkdirSync(join(repo, ".nen/direct"), { recursive: true });
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
writeFileSync(join(repo, ".nen/direct", `${encodeURIComponent(effort)}.json`), JSON.stringify({
  contract: "nen.direct.resolve/v0.1", mismatch: { match: true, compares: [
    { field: "surface", session: "codex", recommended: "codex", verdict: "match" },
    { field: "model", session: "sol", recommended: "sol", verdict: "match" },
    { field: "effort", session: "unread", recommended: "max", verdict: "unread" },
  ] },
}));
git("init", "-q", "-b", "main"); git("config", "user.name", "Fixture"); git("config", "user.email", "fixture@example.invalid");
git("add", "."); git("commit", "-qm", "base"); git("switch", "-qc", effort);

const report = {
  contract: "nen.report.data/v0.1",
  phases: [
    { effort, phase: "author", startedAt: "2026-10-20T10:00:00.000Z", surface: "codex", model: "sol", dial: "unread" },
    { effort, phase: "pr", startedAt: "2026-10-20T10:00:30.000Z", surface: "codex", model: "gpt-6-sol", dial: "high" },
    { effort, phase: "readiness", startedAt: "2026-10-20T10:00:45.000Z", surface: "codex", model: "gpt-6-sol", dial: "xhigh", note: "model-kind=served; registry alias sol" },
    { effort: "other/branch", phase: "author", startedAt: "2026-10-20T09:00:00.000Z", surface: "codex", model: "astra", dial: "max" },
  ],
  usage: [
    { effort, recordedAt: "2026-10-20T10:01:00.000Z", surface: "codex", model: "gpt-6-sol", dial: "high", source: "delegate author canon321; registry alias sol (Codex deep); exact served model from spawn_agent" },
    { effort, recordedAt: "2026-10-20T10:02:00.000Z", surface: "codex", model: "gpt-5.6-sol", dial: "high", source: "delegate author machinery321; registry alias terra (Codex fast); exact served model from assigned adapter; hostile | <script>\n\u001b[2J\u202e" },
    { effort, recordedAt: "2026-10-20T10:03:00.000Z", surface: "codex", model: "gpt-6-sol", dial: "high", source: "hanten § 4: hisoka, counters unavailable" },
    { effort, recordedAt: "2026-10-20T10:03:30.000Z", surface: "claude-code", model: "claude-opus-5-5", dial: "high", source: "hanten § 4: chrollo, counters unavailable; model-kind=served" },
    { effort, recordedAt: "2026-10-20T10:03:45.000Z", surface: "codex", model: "custom-opaque", dial: "high", source: "delegate author opaque321; unclassified caller token" },
    { effort: "ha-321-pr-delivery", recordedAt: "2026-10-20T08:00:00.000Z", surface: "codex", model: null, dial: null, source: "old intake" },
  ],
  sessions: [
    { effort, recordedAt: "2026-10-20T10:00:00.020Z", surface: "codex", model: "sol", dial: "unread", title: null, id: "thread-321", source: "Codex thread id" },
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
  console.log("pr-body-delivery fixture: exact effort, roles, served IDs and aliases, sessions, hostile cells, Nen render, row guard, private paths and wrapper passed");
});

test("normalization filters the exact branch and keeps served IDs separate from proved aliases", () => {
  document = normalize(repo, report);
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
  assert.equal(reviewer?.model, "exact: gpt-6-sol · alias: sol");
  assert.equal(claudeReviewer?.model, "exact: claude-opus-5-5 · alias: opus");
  assert.equal(author?.model, "exact: unread · alias: sol");
  assert.equal(landing?.model, "exact: gpt-6-sol · alias: sol");
  assert.equal(readiness?.model, "exact: gpt-6-sol · alias: sol");
  assert.match(readiness?.source ?? "", /model-kind=served/);
  assert.equal(opaque?.model, "exact: unread (recorded token: custom-opaque; classification unread) · alias: unread");
  assert.match(author?.session ?? "", /thread-321/);
  assert.match(unmatched?.role ?? "", /^unread/);
  assert.ok(document.deliveryRows.every((row): boolean => !row.source.includes("old intake") && !row.session.includes("other")));
  assert.match(machinery?.source ?? "", /\\\|/);
  assert.match(machinery?.source ?? "", /&lt;script&gt;/);
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
  const body = `${rendered}\n# ✨ What this changes for you\n`;
  assert.deepEqual(compareBody(body, rendered), []);
  const updatedDrive = rendered.replace(/gate forecast: unread — [^;]+; next: unread — [^;]+;/, "gate forecast: G4; next: hatsu:en on HA-PR-#321;");
  assert.deepEqual(compareBody(`${updatedDrive}\n# Changes`, rendered), []);
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

test("shell guard composes report data, normalization and Nen rendering, and propagates report failure", () => {
  mkdirSync(join(repo, "templates"), { recursive: true });
  writeFileSync(join(repo, "templates/pr-delivery.md"), readFileSync(TEMPLATE));
  const realNen = ok("sh", ["-c", "command -v nen"], repo).trim();
  const bin = join(temp, "bin"); mkdirSync(bin);
  const fake = join(bin, "nen");
  writeFileSync(fake, `#!/usr/bin/env bash\nset -euo pipefail\nif [ \"\${1:-} \${2:-}\" = 'report data' ]; then\n  [ \"\${FAKE_REPORT_FAIL:-0}\" = 0 ] || exit 7\n  cat \"$FIXTURE_REPORT\"\n  exit 0\nfi\nexec \"$REAL_NEN\" \"$@\"\n`);
  chmodSync(fake, 0o755);
  const body = join(temp, "guard-body.md"); writeFileSync(body, `${rendered}\n# ✨ What this changes for you\n`);
  const env = { ...process.env, PATH: `${bin}:${process.env.PATH ?? ""}`, REAL_NEN: realNen, FIXTURE_REPORT: join(repo, ".nen/reports/report.json") };
  const passed = run("bash", [GUARD, "--body", body, "--repo", repo, "--base", "main"], repo, env);
  assert.equal(passed.status, 0, `${passed.stdout}${passed.stderr}`);
  assert.match(passed.stdout, /every current-effort ledger row/);
  const failed = run("bash", [GUARD, "--body", body, "--repo", repo, "--base", "main"], repo, { ...env, FAKE_REPORT_FAIL: "1" });
  assert.equal(failed.status, 7); assert.match(failed.stderr, /exit 7/);
});
