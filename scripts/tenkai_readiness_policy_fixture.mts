// Exercise Tenkai's public adoption entry point and the step it actually renders.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, copyFileSync, cpSync, existsSync, mkdirSync, mkdtempSync, lstatSync, readFileSync, realpathSync, rmSync, statSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { delimiter, dirname, join, resolve } from "node:path";
import { GUARD_PATH, POLICY_PATH, verifyWorkflowPolicy, workflowDigest } from "./readiness_workflow_policy.mts";

const root = resolve(import.meta.dirname, "..");
const sandbox = realpathSync(mkdtempSync(join(tmpdir(), "hatsu-readiness-policy-")));
const repo = join(sandbox, "process");
const workspace = join(sandbox, "runner");
const trusted = join(workspace, ".trusted");
const candidate = join(workspace, ".candidate");
const slug = "fixture/portable-readiness";
const base = "release/main";
const trackedBase = "refs/remotes/origin/" + base;
const headExpression = "${{ github.event.pull_request.head.sha }}";
const baseExpression = "${{ github.event.pull_request.base.sha }}";
const workflowPath = ".github/workflows/pr-readiness.yml";
const ordinaryPath = ".github/workflows/ordinary.yml";
const env = {
  ...process.env,
  GH_TOKEN: "", GITHUB_TOKEN: "", GITHUB_REPOSITORY: slug,
  PATH: [join(sandbox, "bin"), process.env.PATH].join(delimiter),
  GIT_CONFIG_GLOBAL: "/dev/null", GIT_CONFIG_NOSYSTEM: "1",
};
let assertions = 0;
function check(condition: unknown, detail: string) {
  assert.ok(condition, detail);
  assertions++;
}
function equal(actual: unknown, expected: unknown, detail: string) {
  assert.deepEqual(actual, expected, detail);
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
  return result.stdout;
}
function command(args: string[], runnerOnline = false) {
  return spawnSync("bash", [join(root, "scripts/tenkai_adopt.sh"), ...args], {
    encoding: "utf8", env: { ...env, TENKAI_FIXTURE_RUNNER: runnerOnline ? "online" : "offline" }, timeout: 30_000,
  });
}
function adopt(mode: "apply" | "diagnose", visibility: "public" | "private" | null = "public", selfHosted = "0", runnerOnline = false) {
  const visibilityArgs = visibility === null ? [] : ["--visibility", visibility];
  const result = command([mode, "--repo", repo, ...visibilityArgs, "--self-hosted", selfHosted, "--json"], runnerOnline);
  assert.ok(result.status === 0 || result.status === 1, result.stderr || String(result.error));
  const report = JSON.parse(result.stdout);
  assert.equal(result.status, report.outstanding ? 1 : 0);
  const readiness = report.items.find((item: { id: string }) => item.id === workflowPath);
  assert.equal(result.status, report.outstanding ? 1 : 0, "JSON exit follows the aggregate report");
  return { ...readiness, outstanding: report.outstanding, report };
}
function copy(paths: string[], destination: string) {
  for (const path of paths) {
    mkdirSync(dirname(join(destination, path)), { recursive: true });
    copyFileSync(join(repo, path), join(destination, path));
  }
}
function commit(message: string) {
  git("add", ".");
  git("commit", "-qm", message);
  return git("rev-parse", "HEAD").trim();
}
function freezeBase(paths = [GUARD_PATH, POLICY_PATH, workflowPath]) {
  git("update-ref", trackedBase, commit("Fixture trusted base"));
  rmSync(trusted, { recursive: true, force: true });
  copy(paths, trusted);
}
function renderedCheckout(workflow: string, path: ".trusted" | ".candidate") {
  const refs = [...workflow.matchAll(/^          ref: (.+)\n          path: (.+)\n          persist-credentials: false$/gm)];
  const ref = refs.find((entry) => entry[2] === path)?.[1];
  assert.ok(ref, "rendered checkout with disabled credentials persistence at " + path);
  return ref;
}
function eventCheckout(workflow: string, path: ".trusted" | ".candidate", event: { baseSha: string; headSha: string }, files: string[]) {
  const ref = renderedCheckout(workflow, path);
  const sha = ref === headExpression ? event.headSha : ref === baseExpression ? event.baseSha : ref;
  for (const file of files) put(join(workspace, path), file, git("show", sha + ":" + file));
}
function runPolicy(workflow: string, repoSlug = slug) {
  const step = workflow.split("\n").find((line) => line.trimStart().startsWith("node .trusted/" + GUARD_PATH));
  assert.ok(step, "rendered step must call the trusted portable guard");
  return spawnSync("bash", ["-eo", "pipefail", "-c", step], {
    cwd: workspace, encoding: "utf8", env: { ...env, GITHUB_REPOSITORY: repoSlug }, timeout: 5_000,
  });
}

try {
  put(sandbox, "bin/gh", `#!/bin/sh
if [ "$1" = api ] && [ "$2" = --paginate ] && [ "$TENKAI_FIXTURE_RUNNER" = online ]; then
  printf 'online\\tself-hosted,Linux,X64,pool-ci\\n'
  exit 0
fi
exit 1
`);
  chmodSync(join(sandbox, "bin/gh"), 0o755);
  mkdirSync(repo);
  git("init", "-qb", base);
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
    branch: { base },
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
  const textDiagnosis = command(["diagnose", "--repo", repo, "--visibility", "public", "--self-hosted", "0"]);
  check(textDiagnosis.status === 1 && textDiagnosis.stdout.includes("STAG  " + workflowPath) &&
    textDiagnosis.stdout.includes("trusted JSON reader must be installed") &&
    !existsSync(join(repo, workflowPath)) && !existsSync(join(repo, GUARD_PATH)),
  "text diagnosis reports the portable prerequisite without writing anything");
  const refusedApply = command(["apply", "--repo", join(sandbox, "missing"), "--json"]);
  check(refusedApply.status === 2 && refusedApply.stderr.includes("no such directory"),
    "an invalid apply retains the frozen adopter's exit and diagnostic");
  const alternateRoot = join(sandbox, "hatsu-without-readiness-template");
  json(alternateRoot, "nen/contract.json", { dependency: shipped.dependency });
  const refusedTemplate = command(["apply", "--repo", repo, "--hatsu-root", alternateRoot,
    "--visibility", "public", "--self-hosted", "0", "--json"]);
  check(refusedTemplate.status === 2 && refusedTemplate.stderr.includes("no template at") &&
    !existsSync(join(repo, workflowPath)) && !existsSync(join(repo, "scripts/readiness_ci_verdict.mts")),
  "a pinned Hatsu root with a missing template is refused before adoption writes");
  const runnerPolicy = command(["runner-policy", "--visibility", "public", "--self-hosted", "0", "--json"]);
  check(runnerPolicy.status === 0 && JSON.parse(runnerPolicy.stdout).runs_on === "ubuntu-latest",
    "runner-policy still returns the frozen runner report");
  const initial = adopt("apply");
  check(initial.state === "repaired", JSON.stringify(initial));
  const diagnosed = adopt("diagnose");
  check(diagnosed.state === "satisfied" && diagnosed.outstanding === 0, JSON.stringify(diagnosed.report.items.filter((item: { state: string }) => item.state !== "satisfied")));
  const satisfiedText = command(["diagnose", "--repo", repo, "--visibility", "public", "--self-hosted", "0"]);
  check(satisfiedText.status === 0 && satisfiedText.stdout.includes("every item is satisfied"),
    "the successful portable report stays successful in text output");
  check(diagnosed.report.items.some((item: { id: string; detail: string }) =>
    item.id === "guard/registration" && item.detail.includes("Ruby registration has no prerequisite PR")) &&
    diagnosed.report.items.some((item: { id: string; detail: string }) =>
      item.id === "workflows/privileged" && item.detail.includes("Other privileged workflows remain under repository-owned policy.")),
  "public report distinguishes portable readiness from repository-owned Ruby policy");
  json(repo, "nen/repos.json", { maintained_tools: [slug], consumers: [{ repo: slug }] });
  check(adopt("diagnose").state === "satisfied", "the frozen registry's maintained-tool precedence and string entry survive the handoff");
  json(repo, "nen/repos.json", { maintained_tools: [{ repo: slug }] });
  const old = text(repo, workflowPath);
  check(text(repo, ordinaryPath) === ordinary, "Tenkai preserves consumer-owned CI");
  const live = old.split("\n").filter((line) => line.trim() && !line.trimStart().startsWith("#"));
  const events = live.slice(live.indexOf("on:") + 1, live.indexOf("concurrency:"));
  equal(events, [
    "  pull_request_target:",
    "    types: [opened, synchronize, reopened, review_requested, review_request_removed, ready_for_review]",
    "  pull_request_review:",
    "    types: [submitted, edited, dismissed]",
  ], "the rendered workflow declares exactly the allowed event actions");
  equal(live[live.indexOf("  readiness:") + 1],
    "    if: ${{ github.repository == '" + slug + "' && github.event.pull_request.head.repo.full_name == github.repository && github.event.pull_request.draft == false }}",
    "the rendered job requires this repository, a same-repository head and a non-draft PR");
  equal(renderedCheckout(old, ".candidate"), headExpression, "candidate data is checked out at the exact event head");
  equal(renderedCheckout(old, ".trusted"), "refs/heads/" + base, "trusted files are checked out from the declared base");
  check(old.includes("TENKAI_PIN_FALLBACK_ALLOWED: false"), "the process rendering keeps the strict Nen pin");
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
  equal(verifyWorkflowPolicy(trusted, candidate, slug), 1,
    "the exact policy source verifies the same trusted and candidate trees as the rendered command");
  assert.throws(() => verifyWorkflowPolicy(trusted, candidate, "fixture/another-repository"), /for this repository/);
  assertions++;
  check(runPolicy(old, "fixture/another-repository").status === 1, "the trusted policy is repository-bound");

  // Apply and the rendered check both rely on the declared base for a stacked PR.
  git("switch", "-qc", "topic-base");
  const topicRendering = old.replace("timeout-minutes: 15", "timeout-minutes: 17");
  assert.notEqual(topicRendering, old);
  const topicPolicy = JSON.parse(text(repo, POLICY_PATH));
  topicPolicy.workflows[workflowPath].next = workflowDigest(topicRendering);
  json(repo, POLICY_PATH, topicPolicy);
  const topicBase = commit("Fixture topic-only admission");
  git("switch", "-qc", "topic-head");
  put(repo, workflowPath, topicRendering);
  const event = { baseSha: topicBase, headSha: commit("Fixture stacked candidate") };
  eventCheckout(old, ".trusted", event, [GUARD_PATH, POLICY_PATH, workflowPath]);
  eventCheckout(old, ".candidate", event, [workflowPath]);
  check(text(trusted, POLICY_PATH) !== git("show", topicBase + ":" + POLICY_PATH) &&
    text(candidate, workflowPath) === topicRendering && runPolicy(old).status === 1,
    "the rendered check evaluates the stacked event head against the declared base, where the topic-only admission is absent");
  git("switch", "-q", base);
  copy([workflowPath], candidate);
  for (const [from, to] of [
    ["\n  checks: write\n", "\n  contents: write\n"],
    ["runs-on: ubuntu-latest", "runs-on: self-hosted"],
    ["          ref: refs/heads/" + base, "          ref: " + headExpression],
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

  // An old slug is eligible only if the fetched workflow and manifest agree.
  const moved = "new-owner/renamed-readiness";
  const oldPolicy = text(repo, POLICY_PATH);
  const lastBase = git("rev-parse", trackedBase).trim();
  const mismatched = JSON.parse(oldPolicy);
  mismatched.workflows[workflowPath] = { current: "0".repeat(64) };
  json(repo, POLICY_PATH, mismatched);
  freezeBase();
  put(repo, POLICY_PATH, oldPolicy);
  git("remote", "set-url", "origin", "https://github.com/" + moved + ".git");
  json(repo, "nen/repos.json", { maintained_tools: [{ repo: moved }] });
  const invalidPrevious = adopt("apply");
  check(invalidPrevious.state === "blocked" && invalidPrevious.detail.includes("trusted workflow differs") &&
    text(repo, POLICY_PATH) === oldPolicy && text(repo, workflowPath) === old,
    "the previous slug cannot be migrated on a mismatched trusted pair");
  git("update-ref", trackedBase, lastBase);
  copy([POLICY_PATH], trusted);
  check(runPolicy(old, moved).status === 1, "CI rejects the old manifest under the new event slug");
  const rename = adopt("apply");
  check(rename.state === "staged" && rename.detail.includes(slug + " to " + moved) && text(repo, workflowPath) === old,
    "rename stages a policy for the new slug before it changes the workflow");
  const movedPolicy = JSON.parse(text(repo, POLICY_PATH));
  check(movedPolicy.repository === moved && movedPolicy.workflows[workflowPath].current === workflowDigest(old),
    "the new repository admission starts from the trusted old workflow bytes");
  check(adopt("apply").state === "staged", "an unlanded rename policy stays staged on retry");
  freezeBase();
  put(repo, POLICY_PATH, oldPolicy);
  check(adopt("apply").state === "repaired", "a fetched rename admission permits re-rendering with a stale local manifest");
  const movedWorkflow = text(repo, workflowPath);
  copy([workflowPath], candidate);
  check(movedWorkflow.includes("github.repository == '" + moved + "'") &&
    movedPolicy.workflows[workflowPath].next === workflowDigest(movedWorkflow) &&
    runPolicy(movedWorkflow, moved).status === 0 && runPolicy(movedWorkflow, slug).status === 1,
    "the new predicate and manifest agree and the guard accepts only the new repository");
  freezeBase();
  check(adopt("apply").state === "repaired" && adopt("diagnose").state === "satisfied",
    "after the renamed rendering lands, adoption reduces the manifest to its active digest");
  put(candidate, workflowPath, old);
  check(runPolicy(movedWorkflow, moved).status === 1, "the final trusted workflow retires the old slug rendering");

  // Produce a real process legacy workflow through the public Ruby registration path.
  rmSync(join(repo, GUARD_PATH));
  rmSync(join(repo, POLICY_PATH));
  rmSync(join(repo, workflowPath));
  rmSync(join(repo, ordinaryPath));
  rmSync(join(candidate, ordinaryPath), { force: true });
  git("update-ref", "-d", trackedBase);
  const customPath = "scripts/workflow_runner_policy_check.rb";
  const custom = "# Consumer-owned guard\nEXPECTED_JOBS = {}.freeze\n";
  put(repo, customPath, custom);
  check(adopt("diagnose").state === "staged", "diagnose leaves the custom Ruby registration route with the frozen adopter");
  check(adopt("apply").state === "staged", "the custom guard still owns its two-PR registration");
  check(text(repo, customPath) === custom && !existsSync(join(repo, GUARD_PATH)) &&
    !existsSync(join(repo, workflowPath)), "Tenkai preserves the custom Ruby guard and stages the workflow");
  put(repo, customPath, ["EXPECTED_JOBS", "EXPECTED_TYPES", "EXPECTED_STEPS"].map((name) =>
    name + " = { 'pr-readiness.yml' => [] }.freeze\n").join(""));
  check(adopt("apply").state === "repaired", "the registered Ruby route renders a legacy workflow");
  const legacy = text(repo, workflowPath);
  check(legacy.includes("TENKAI_GUARD_REQUIRED: true") && !existsSync(join(repo, GUARD_PATH)),
    "the prior process workflow expects the Ruby guard");
  const wrongContext = legacy.replace("  readiness:\n", "  readiness:\n    name: other-readiness\n");
  assert.notEqual(wrongContext, legacy, "the fixture must rename the reported job context");
  const renamedLegacy = "# Local rendering note\n" + wrongContext;
  const contextDiagnostic = workflowPath + ': required context "readiness"';
  put(repo, workflowPath, renamedLegacy);
  const legacyDrift = adopt("diagnose");
  check(legacyDrift.state === "drift" && legacyDrift.detail.includes(contextDiagnostic) &&
    text(repo, workflowPath) === renamedLegacy, "legacy required-context diagnosis is read-only: " + legacyDrift.detail);
  const textReport = command(["diagnose", "--repo", repo, "--visibility", "public", "--self-hosted", "0"]);
  check(textReport.status === 1 && textReport.stdout.includes("DRIF  " + workflowPath) &&
    textReport.stdout.includes(contextDiagnostic), "the public text report keeps the readiness row and outstanding exit");
  const malformedRoot = join(sandbox, "hatsu-with-invalid-required-context");
  for (const directory of ["contracts", "nen", "templates"]) {
    cpSync(join(root, directory), join(malformedRoot, directory), { recursive: true });
  }
  symlinkSync(join(root, "scripts"), join(malformedRoot, "scripts"), "dir");
  put(malformedRoot, "templates/pr-readiness.yml", text(root, "templates/pr-readiness.yml")
    .replace("  readiness:\n", "  readiness:\n    name: wrong-template-context\n"));
  const invalidSource = command(["apply", "--repo", repo, "--hatsu-root", malformedRoot, "--visibility", "public",
    "--self-hosted", "0", "--json"]);
  const invalidReadiness = JSON.parse(invalidSource.stdout).items.find((item: { id: string }) => item.id === workflowPath);
  check(invalidSource.status === 1 && invalidReadiness.state === "blocked" &&
    invalidReadiness.detail.includes(contextDiagnostic) && text(repo, workflowPath) === renamedLegacy,
  "a trusted rendering with a wrong required context blocks before any legacy readiness write");
  put(malformedRoot, "templates/pr-readiness.yml", text(root, "templates/pr-readiness.yml"));
  json(malformedRoot, "contracts/required-job-contexts.json", { contract: "hatsu.required-job-contexts/v1", workflows: {} });
  const invalidContract = command(["diagnose", "--repo", repo, "--hatsu-root", malformedRoot, "--visibility", "public",
    "--self-hosted", "0", "--json"]);
  const contractReadiness = JSON.parse(invalidContract.stdout).items.find((item: { id: string }) => item.id === workflowPath);
  check(invalidContract.status === 1 && contractReadiness.state === "blocked" &&
    contractReadiness.detail.includes("required job context declaration is missing or malformed") &&
    text(repo, workflowPath) === renamedLegacy, "the public legacy route refuses an invalid trusted context declaration");

  const registeredGuard = text(repo, customPath);
  put(repo, customPath, registeredGuard + "READINESS_FROZEN_VERDICT = 'current'\n");
  const stagedGuard = adopt("apply");
  check(stagedGuard.state === "staged" && stagedGuard.detail.includes("does not admit the JSON reader step") &&
    text(repo, workflowPath) === renamedLegacy, "legacy context apply preserves the frozen Ruby policy gate");
  put(repo, customPath, registeredGuard);

  const reader = "scripts/readiness_ci_verdict.mts";
  rmSync(join(repo, reader));
  check(adopt("diagnose").state === "staged" && text(repo, workflowPath) === renamedLegacy,
    "the reader gate stages an installed workflow with context drift");
  check(adopt("apply").state === "repaired" && text(repo, workflowPath) === legacy,
    "apply restores the required context after the reader is installed");
  const repairedAt = statSync(join(repo, workflowPath)).mtimeMs;
  check(adopt("apply").state === "satisfied" && text(repo, workflowPath) === legacy &&
    statSync(join(repo, workflowPath)).mtimeMs === repairedAt, "a second apply leaves the legacy rendering untouched");

  const privateRunner = "[self-hosted, Linux, X64, pool-ci]";
  const privateWorkflow = renamedLegacy.replaceAll("ubuntu-latest", privateRunner);
  put(repo, workflowPath, privateWorkflow);
  const offline = adopt("apply", null);
  check(offline.state === "repaired" && offline.detail.includes("runner preserved") &&
    text(repo, workflowPath).includes("    runs-on: " + privateRunner) &&
    text(repo, workflowPath).includes("  readiness:\n    if:"), "legacy context repair preserves an unreadable runner");

  const ownerWorkflow = wrongContext.replace(/^# pr-readiness[^\n]+\n/, "# Owner workflow\n");
  put(repo, workflowPath, ownerWorkflow);
  check(adopt("apply").state === "drift" && text(repo, workflowPath) === ownerWorkflow,
    "a context defect cannot authorize replacing an owner-maintained workflow");
  const linkedLegacyTarget = join(sandbox, "linked-readiness.yml");
  put(sandbox, "linked-readiness.yml", renamedLegacy);
  rmSync(join(repo, workflowPath));
  symlinkSync(linkedLegacyTarget, join(repo, workflowPath));
  check(adopt("apply").state === "blocked" && readFileSync(linkedLegacyTarget, "utf8") === renamedLegacy,
    "the required-context repair cannot follow a linked workflow");
  rmSync(join(repo, workflowPath));
  put(repo, workflowPath, legacy);
  rmSync(join(repo, customPath));
  freezeBase([workflowPath]);
  const migration = adopt("apply");
  check(migration.state === "staged" && text(repo, workflowPath) === legacy,
    "legacy migration prepares policy while preserving the trusted workflow");
  const legacyPolicy = JSON.parse(text(repo, POLICY_PATH)).workflows[workflowPath];
  check(legacyPolicy.current === workflowDigest(legacy) && legacyPolicy.next === workflowDigest(movedWorkflow),
    "the transition admits the trusted legacy bytes and exact portable rendering");
  freezeBase();
  check(adopt("apply").state === "repaired", "a fetched legacy transition admits the portable workflow");
  copy([workflowPath], candidate);
  check(runPolicy(text(repo, workflowPath), moved).status === 0,
    "the rendered portable self-check accepts the migration against the legacy base in a repository with no other workflow");

  rmSync(join(repo, GUARD_PATH));
  rmSync(join(repo, POLICY_PATH));
  git("update-ref", "-d", trackedBase);
  const foreign = "name: Owner-maintained readiness\non: pull_request\n";
  put(repo, workflowPath, foreign);
  for (const mode of ["diagnose", "apply"] as const) {
    const unowned = adopt(mode);
    check(unowned.state === "drift" && unowned.fix.fill === "route" && unowned.fix.run.length === 0 &&
      unowned.fix.edit.includes("owner review") && unowned.report.guide.routed.includes(workflowPath) &&
      !unowned.report.guide.defaults.includes(workflowPath) && text(repo, workflowPath) === foreign,
      mode + " preserves the owner-maintained workflow and routes manual review");
  }
  freezeBase([workflowPath]);
  rmSync(join(repo, workflowPath));
  check(adopt("apply").fix?.fill === "route" && !existsSync(join(repo, workflowPath)),
    "removing the local copy cannot bypass review of an unowned trusted workflow");

  const settings = JSON.parse(text(repo, "nen/workflow.json"));
  json(repo, "nen/workflow.json", { ...settings,
    runners: { pools: [{ id: "ci", labels: ["self-hosted", "Linux", "X64", "pool-ci"] }] },
  });
  freezeBase([]);
  check(adopt("apply", "private", "1", true).state === "repaired", "a reachable labelled runner is rendered on the adoption branch");
  const labelled = text(repo, workflowPath);
  const labelledPolicy = text(repo, POLICY_PATH);
  check(labelled.includes("    runs-on: [self-hosted, Linux, X64, pool-ci]"), "the workflow selects the declared pool");
  check(adopt("apply", null).state === "satisfied" && text(repo, workflowPath) === labelled &&
    text(repo, POLICY_PATH) === labelledPolicy, "unreadable visibility preserves the locally admitted runner before its workflow reaches the base");
  const unadmitted = labelled.replace("timeout-minutes: 15", "timeout-minutes: 16");
  put(repo, workflowPath, unadmitted);
  const unreadable = adopt("apply", null);
  check(unreadable.state === "staged" && unreadable.fix?.fill === "route" && text(repo, workflowPath) === unadmitted &&
    text(repo, POLICY_PATH) === labelledPolicy, "unreadable visibility and an unadmitted local workflow stage runner selection");
  const previousPolicy = text(repo, POLICY_PATH);
  const outside = join(sandbox, "outside-readiness.yml");
  put(sandbox, "outside-readiness.yml", "name: repository-owned workflow\n");
  rmSync(join(repo, workflowPath));
  symlinkSync(outside, join(repo, workflowPath));
  const linked = adopt("apply");
  check(linked.state === "blocked" && linked.detail.includes("must be a regular file") &&
    lstatSync(join(repo, workflowPath)).isSymbolicLink() &&
    text(sandbox, "outside-readiness.yml") === "name: repository-owned workflow\n" &&
    text(repo, POLICY_PATH) === previousPolicy,
  "an unsafe workflow path cannot fall back to the frozen writer or change the portable policy");
  rmSync(join(repo, workflowPath));
  json(repo, "nen/repos.json", []);
  const unknownRole = adopt("apply");
  check(unknownRole.state === "blocked" && unknownRole.detail.includes("repository role or slug is unknown") &&
    !existsSync(join(repo, workflowPath)) && text(repo, POLICY_PATH) === previousPolicy,
  "a malformed registry cannot authorize writes to an installed portable route");
} finally {
  rmSync(sandbox, { recursive: true, force: true });
}
console.log("tenkai portable readiness: " + assertions + " assertions passed");
