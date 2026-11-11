// Exercise Tenkai's public adoption entry point and the step it actually renders.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { GUARD_PATH, POLICY_PATH, workflowDigest } from "./readiness_workflow_policy.mts";

const root = resolve(import.meta.dirname, "..");
const sandbox = realpathSync(mkdtempSync(join(tmpdir(), "hatsu-readiness-policy-")));
const repo = join(sandbox, "process");
const workspace = join(sandbox, "runner");
const trusted = join(workspace, ".trusted");
const candidate = join(workspace, ".candidate");
const slug = "fixture/portable-readiness";
const workflowPath = ".github/workflows/pr-readiness.yml";
const ordinaryPath = ".github/workflows/ordinary.yml";
const env = {
  ...process.env,
  GH_TOKEN: "", GITHUB_TOKEN: "", GITHUB_REPOSITORY: slug,
  GIT_CONFIG_GLOBAL: "/dev/null", GIT_CONFIG_NOSYSTEM: "1",
};
let assertions = 0;
function check(condition: unknown, detail: string) {
  assert.ok(condition, detail);
  assertions++;
}
function put(dir: string, path: string, value: string) {
  mkdirSync(dirname(join(dir, path)), { recursive: true });
  writeFileSync(join(dir, path), value);
}
function text(dir: string, path: string) {
  return readFileSync(join(dir, path), "utf8");
}
function json(dir: string, path: string, value: unknown) {
  put(dir, path, JSON.stringify(value, null, 2) + "\n");
}
function git(...args: string[]) {
  const result = spawnSync("git", ["-C", repo, ...args], { encoding: "utf8", env, timeout: 5_000 });
  assert.equal(result.status, 0, result.stderr);
}
function adopt(mode: "apply" | "diagnose", visibility = "public", selfHosted = "0") {
  const result = spawnSync("bash", [join(root, "scripts/tenkai_adopt.sh"), mode, "--repo", repo,
    "--visibility", visibility, "--self-hosted", selfHosted, "--json"], { encoding: "utf8", env, timeout: 30_000 });
  assert.ok(result.status === 0 || result.status === 1, result.stderr || String(result.error));
  const report = JSON.parse(result.stdout);
  const readiness = report.items.find((item: { id: string }) => item.id === workflowPath);
  return { ...readiness, outstanding: report.outstanding, report };
}
function copy(paths: string[], destination: string) {
  for (const path of paths) {
    mkdirSync(dirname(join(destination, path)), { recursive: true });
    copyFileSync(join(repo, path), join(destination, path));
  }
}
function freezeBase() {
  git("add", ".");
  git("commit", "-qm", "Fixture trusted base");
  git("update-ref", "refs/remotes/origin/main", "HEAD");
  copy([GUARD_PATH, POLICY_PATH, workflowPath], trusted);
}
function runPolicy(workflow: string, repoSlug = slug) {
  const step = workflow.split("\n").find((line) => line.trimStart().startsWith("node .trusted/" + GUARD_PATH));
  assert.ok(step, "rendered step must call the trusted portable guard");
  return spawnSync("bash", ["-eo", "pipefail", "-c", step], {
    cwd: workspace, encoding: "utf8", env: { ...env, GITHUB_REPOSITORY: repoSlug }, timeout: 5_000,
  });
}

try {
  mkdirSync(repo);
  git("init", "-qb", "main");
  git("remote", "add", "origin", "https://github.com/" + slug + ".git");
  git("config", "user.name", "Fixture");
  git("config", "user.email", "fixture@example.invalid");
  put(repo, ".git/hooks/commit-msg", "#!/bin/sh\nexit 0\n");
  const shipped = JSON.parse(text(root, "nen/contract.json"));
  json(repo, "nen/repos.json", { maintained_tools: [{ repo: slug }] });
  json(repo, "nen/contract.json", {
    dependency: shipped.dependency,
    project: {
      kind: "process", defaultLane: "tools", lanes: { tools: { stack: "process" } },
      verbs: { tools: { release: { exe: "bash", argv: ["scripts/release-publish.sh", "--repo", "."] } } },
    },
  });
  json(repo, "nen/workflow.json", {
    branch: { base: "main" },
    review: { scopes: { code: { persona: "nobunaga", tier: "deep", budget: 1, paths: ["**"] } } },
    release: { unitPaths: ["CHANGELOG.md"] },
    commits: { allowedAttributionTrailers: ["Hatsu-Agent"], forbiddenTrailers: ["Co-Authored-By"] },
  });
  json(repo, "nen/gates.json", { approval_policy: "required", reviewers: [{ persona: "copilot", login: "copilot-pull-request-reviewer[bot]" }] });
  json(repo, "nen/labels.json", {});
  const ordinary = "name: Ordinary CI\non: pull_request\npermissions: {}\njobs:\n  ci:\n    runs-on: ubuntu-latest\n    steps:\n      - run: true\n";
  put(repo, ordinaryPath, ordinary);

  check(!existsSync(join(repo, "scripts/workflow_runner_policy_check.rb")), "the fixture starts without Ruby");
  check(adopt("diagnose").state === "staged", "diagnose reports the missing trusted reader");
  const initial = adopt("apply");
  check(initial.state === "repaired", JSON.stringify(initial));
  const diagnosed = adopt("diagnose");
  check(diagnosed.state === "satisfied" && diagnosed.outstanding === 0, JSON.stringify(diagnosed.report.items.filter((item: { state: string }) => item.state !== "satisfied")));
  const old = text(repo, workflowPath);
  check(text(repo, ordinaryPath) === ordinary, "Tenkai preserves consumer-owned CI");
  check(old.includes("github.repository == '" + slug + "'") && old.includes("path: .candidate") &&
    old.includes("pull_request.base.sha") && old.includes("path: .trusted") &&
    old.includes("TENKAI_PIN_FALLBACK_ALLOWED: false"), "the portable rendering retains the repository, trusted base and strict pin");
  check(!old.includes("TENKAI_GUARD_REQUIRED") && !old.includes("workflow_runner_policy_check.rb --self-test"),
    "the process workflow invokes its shipped guard");
  check(adopt("apply").state === "satisfied", "second apply is idempotent");
  put(repo, workflowPath, old.replace("\n  readiness:\n", "\n  renamed:\n"));
  const renamed = adopt("diagnose");
  check(renamed.state === "drift" && renamed.detail.includes(workflowPath + ': required context "readiness"'),
    "diagnose names the workflow and missing readiness job");
  check(adopt("apply").state === "repaired", "Tenkai restores the readiness job name");

  freezeBase();
  copy([workflowPath, ordinaryPath], candidate);
  check(runPolicy(old).status === 0, "rendered self-check passes beside ordinary CI");
  check(runPolicy(old, "fixture/another-repository").status === 1, "the trusted policy is repository-bound");
  for (const [from, to] of [
    ["\n  checks: write\n", "\n  contents: write\n"],
    ["runs-on: ubuntu-latest", "runs-on: self-hosted"],
    ["          ref: ${{ github.event.pull_request.base.sha }}", "          ref: ${{ github.event.pull_request.head.sha }}"],
    ["          persist-credentials: false", "          persist-credentials: true"],
  ]) {
    const changed = old.replace(from, to);
    assert.notEqual(workflowDigest(changed), workflowDigest(old), "the fixture must change the rendered YAML");
    put(candidate, workflowPath, changed);
    put(candidate, GUARD_PATH, "process.exit(0);\n");
    json(candidate, POLICY_PATH, { contract: "hatsu.tenkai.workflow-policy/v1", repository: slug,
      workflows: { [workflowPath]: { current: workflowDigest(changed) } } });
    check(runPolicy(old).status === 1, "candidate change and its own manifest are refused: " + to);
  }
  rmSync(join(candidate, workflowPath));
  symlinkSync(join(trusted, workflowPath), join(candidate, workflowPath));
  check(runPolicy(old).status === 1, "a linked workflow is refused");
  rmSync(join(candidate, workflowPath));
  check(runPolicy(old).status === 1, "a missing selected workflow is refused");
  put(candidate, workflowPath, old);
  const githubDir = join(candidate, ".github");
  const movedGithub = join(sandbox, "candidate-github");
  rmSync(githubDir, { recursive: true });
  mkdirSync(join(movedGithub, "workflows"), { recursive: true });
  put(movedGithub, "workflows/pr-readiness.yml", old);
  symlinkSync(movedGithub, githubDir);
  check(runPolicy(old).status === 1, "a linked workflow directory is refused");
  rmSync(githubDir);
  put(candidate, workflowPath, old);

  const manifest = text(trusted, POLICY_PATH);
  rmSync(join(trusted, workflowPath));
  check(runPolicy(old).status === 0, "an initial trusted manifest admits its exact workflow during bootstrap");
  put(trusted, workflowPath, old);
  rmSync(join(trusted, POLICY_PATH));
  check(runPolicy(old).status === 1, "a missing trusted manifest fails closed");
  put(trusted, POLICY_PATH, "{ incomplete");
  check(runPolicy(old).status === 1, "a malformed trusted manifest fails closed");
  put(trusted, POLICY_PATH, manifest);
  put(trusted, workflowPath, old.replace("\n  checks: write\n", "\n  checks: read\n"));
  check(runPolicy(old).status === 1, "a mismatched trusted workflow fails closed");
  put(trusted, workflowPath, old);

  // Model a prior admitted rendering and drive both legs through public apply.
  const earlier = old.replace("timeout-minutes: 15", "timeout-minutes: 16");
  assert.notEqual(earlier, old);
  put(repo, workflowPath, earlier);
  json(repo, POLICY_PATH, { contract: "hatsu.tenkai.workflow-policy/v1", repository: slug,
    workflows: { [workflowPath]: { current: workflowDigest(earlier) } } });
  freezeBase();
  const prepare = adopt("apply");
  check(prepare.state === "staged" && text(repo, workflowPath) === earlier, "prepare the manifest before changing the workflow");
  check(prepare.fix?.fill === "route" && prepare.fix.edit.includes("trusted base"), "the guide names the policy landing step");
  const staged = text(repo, POLICY_PATH);
  check(adopt("apply").state === "staged" && text(repo, POLICY_PATH) === staged, "the pending admission is idempotent");
  check(runPolicy(old).status === 1, "the existing base does not admit the new workflow");
  freezeBase();
  check(adopt("apply").state === "repaired", "a fetched trusted admission enables the workflow update");
  check(text(repo, workflowPath) === old && runPolicy(old).status === 0, "the prepared base admits the new workflow");
  put(candidate, workflowPath, earlier);
  check(runPolicy(old).status === 0, "the staged base still admits the current workflow");
  freezeBase();
  check(runPolicy(old).status === 1, "the new trusted workflow retires its predecessor");
  put(candidate, workflowPath, old);
  check(runPolicy(old).status === 0, "the new trusted workflow keeps passing");

  // Exercise the public custom-guard fallback on the same seeded fixture.
  rmSync(join(repo, GUARD_PATH));
  rmSync(join(repo, POLICY_PATH));
  rmSync(join(repo, workflowPath));
  git("update-ref", "-d", "refs/remotes/origin/main");
  const customPath = "scripts/workflow_runner_policy_check.rb";
  const custom = "# Consumer-owned guard\nEXPECTED_JOBS = {}.freeze\n";
  put(repo, customPath, custom);
  check(adopt("apply").state === "staged", "the custom guard still owns its two-PR registration");
  check(text(repo, customPath) === custom && !existsSync(join(repo, GUARD_PATH)) &&
    !existsSync(join(repo, workflowPath)), "Tenkai preserves the custom Ruby guard and stages the workflow");
} finally {
  rmSync(sandbox, { recursive: true, force: true });
}
console.log("tenkai portable readiness: " + assertions + " assertions passed");
