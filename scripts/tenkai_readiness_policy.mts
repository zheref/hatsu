// Tenkai owns rendering and admission here. The public adopter supplies its validated inputs.
import { spawnSync } from "node:child_process";
import { closeSync, constants, fstatSync, mkdirSync, openSync, readSync, renameSync, unlinkSync, writeFileSync } from "node:fs";
import { createHash, randomUUID } from "node:crypto";
import { dirname, join } from "node:path";
import {
  GUARD_MARKER, GUARD_PATH, POLICY_CONTRACT, POLICY_PATH, admittedDigests,
  fileInfo, parsePolicy, policyText, regularText, workflowDigest,
  type Admission,
} from "./readiness_workflow_policy.mts";
import { strictJson } from "./config_values_refresh.ts";

type State = "satisfied" | "missing" | "drift" | "blocked" | "repaired" | "staged";
export type ReadinessRow = { state: State; detail: string; action: string | null };
export type ReadinessRole = "process" | "product" | null;
export type ReadinessTemplate = { source: string; ref: string };
export type AdoptionRunner = {
  runs_on: string;
  fallback: string;
  reason: string;
  labels_required: boolean;
  derived_from: { visibility: string | null };
};
export const READINESS_WORKFLOW = ".github/workflows/pr-readiness.yml";
export const DEFER_READINESS = "HATSU_TENKAI_DEFER_READINESS";
export const DEFERRED_READINESS = "the public adopter is handling the readiness workflow";
export const LEGACY_READINESS = "HATSU_TENKAI_LEGACY_READINESS";
export const READINESS_CONTEXT_CHANGED = "repository role or workflow policy changed during adoption";
export type LegacyReadiness = { repo: string; slug: string; role: Exclude<ReadinessRole, null>; registry: string };
export type RenderInputs = {
  role: ReadinessRole;
  repository: string | null;
  path: string;
  rendered: string | null;
  runnerKnown: boolean;
  runnerLabelsRequired: boolean;
  registry: string | null;
};

const LEGACY_GUARD = "scripts/workflow_runner_policy_check.rb";
const REGISTRY = "nen/repos.json";
const MAX_INPUT_BYTES = 2 * 1024 * 1024;
const GUARD_PREFIX = "#!/usr/bin/env node\n" + GUARD_MARKER + "\n";
const WORKFLOW_MARKER = "# pr-readiness.yml — RENDERED BY hatsu:tenkai.";
const PORTABLE_MARKER = "# Workflow policy: Tenkai's portable guard";
const HEAD_REF = "          ref: ${{ github.event.pull_request.head.sha }}\n";
const TRUSTED_CHECKOUT = "      - name: Checkout guard code from the trusted workflow revision\n";
const TRUSTED_REF = "          ref: ${{ github.event.pull_request.base.sha }}\n          path: .trusted\n";
const POLICY_STEP = "      - name: Enforce workflow runner policy from trusted workflow revision\n";
const PIN_STEP = "      - name: Read the pinned nen ref from trusted nen/contract.json\n";
const PORTABLE_STEP = [
  POLICY_STEP.trimEnd(),
  "        shell: bash",
  "        run: |",
  '          node .trusted/' + GUARD_PATH + ' --self-test "$PWD/.candidate"',
  "",
  "",
].join("\n");

function row(state: State, detail: string, action: string | null = null): ReadinessRow {
  return { state, detail, action };
}

function inputText(root: string, relative: string): string | undefined {
  const path = join(root, relative);
  const parent = fileInfo(dirname(path));
  if (!parent) return undefined;
  if (!parent.isDirectory()) throw new Error(relative + " must have a regular, unlinked parent directory");
  const before = fileInfo(path);
  if (!before) return undefined;
  if (!before.isFile()) throw new Error(relative + " must be a regular file");

  const fd = openSync(path, constants.O_RDONLY | constants.O_NOFOLLOW | constants.O_NONBLOCK);
  try {
    const opened = fstatSync(fd);
    const currentParent = fileInfo(dirname(path));
    if (!opened.isFile() || opened.dev !== before.dev || opened.ino !== before.ino ||
        currentParent?.dev !== parent.dev || currentParent.ino !== parent.ino) {
      throw new Error(relative + " changed while opening it");
    }
    if (opened.size > MAX_INPUT_BYTES) throw new Error(relative + " exceeds the 2 MiB input limit");
    const bytes = Buffer.alloc(opened.size + 1);
    let used = 0;
    while (used < bytes.length) {
      const count = readSync(fd, bytes, used, bytes.length - used, null);
      if (count === 0) break;
      used += count;
    }
    if (used !== opened.size) throw new Error(relative + " changed while reading it");
    try { return new TextDecoder("utf-8", { fatal: true, ignoreBOM: true }).decode(bytes.subarray(0, used)); }
    catch { throw new Error(relative + " must be UTF-8"); }
  } finally {
    closeSync(fd);
  }
}

export function registryText(repo: string): string | undefined {
  return inputText(repo, REGISTRY);
}

// The frozen adopter validates the slug. Both readers use the same precedence
// and accept string entries and objects carrying a repo field.
export function adoptionRole(text: string | undefined, repository: string | null) {
  if (text === undefined) return { role: null, digest: null };
  let registry;
  try {
    registry = strictJson(text);
  } catch {
    throw new Error(REGISTRY + " must be strict JSON");
  }
  if (!registry || typeof registry !== "object" || Array.isArray(registry)) {
    throw new Error(REGISTRY + " must contain a JSON object");
  }
  const includes = (entries: unknown) => Array.isArray(entries) &&
    entries.some(entry => entry === repository || entry?.repo === repository);
  let role: ReadinessRole = null;
  if (repository && includes(registry.maintained_tools)) role = "process";
  else if (repository && includes(registry.consumers)) role = "product";
  return { role, digest: createHash("sha256").update(text).digest("hex") };
}

function pinnedRef(hatsuRoot: string): string | null {
  try {
    const contract = inputText(hatsuRoot, "nen/contract.json");
    const ref = contract === undefined ? undefined : JSON.parse(contract)?.dependency?.pinned_ref;
    if (typeof ref === "string" && /^[A-Za-z0-9][A-Za-z0-9._/-]{0,99}$/.exec(ref)?.[0] === ref &&
        !ref.includes("..") && !ref.includes("//")) return ref;
  } catch {
    // The readiness verdict names the missing or malformed pin.
  }
  return null;
}

export function readReadinessTemplate(hatsuRoot: string): ReadinessTemplate | null {
  const ref = pinnedRef(hatsuRoot);
  if (ref === null) return null;
  const relative = "templates/pr-readiness.yml";
  const source = inputText(hatsuRoot, relative);
  if (source === undefined) {
    throw new Error("no template at " + join(hatsuRoot, relative) + " — --hatsu-root must point at a Hatsu checkout or plugin root");
  }
  return { source: source.replace(/\r\n?/g, "\n"), ref };
}

export function readinessInputs(
  template: ReadinessTemplate | null, role: ReadinessRole, registry: string | null, repository: string | null, runner: AdoptionRunner,
): RenderInputs {
  const processRepository = role === "process";
  const rendered = repository && template
    ? template.source
      .replaceAll("@@REPO_SLUG@@", () => repository)
      .replaceAll("@@RUNS_ON@@", () => runner.runs_on)
      .replaceAll("@@RUNNER_REASON@@", () => runner.reason)
      .replaceAll("@@GUARD_REQUIRED@@", processRepository ? "true" : "false")
      .replaceAll("@@PIN_FALLBACK_ALLOWED@@", processRepository ? "false" : "true")
      .replaceAll("@@NEN_REF@@", () => template.ref)
    : null;
  return {
    role, registry, repository, path: READINESS_WORKFLOW, rendered,
    runnerKnown: runner.derived_from.visibility !== null,
    runnerLabelsRequired: runner.labels_required,
  };
}

// Keep one route predicate for the public handoff and the portable writer.
function portableTargets(repo: string, role: ReadinessRole) {
  const localGuard = regularText(repo, GUARD_PATH);
  const localPolicy = regularText(repo, POLICY_PATH);
  const installed = localGuard?.startsWith(GUARD_PREFIX) || localPolicy !== undefined;
  if (!installed && role !== "process") return null;
  if (!installed) {
    const legacy = fileInfo(join(repo, LEGACY_GUARD));
    if (legacy) {
      if (!legacy.isFile()) throw new Error(LEGACY_GUARD + " must be a regular file");
      return null;
    }
  }
  return { localGuard, localPolicy };
}

export function handlesPortableReadiness(repo: string, role: ReadinessRole): boolean {
  try { return portableTargets(repo, role) !== null; }
  catch {
    // The portable verdict reports unsafe paths without falling through to a legacy write.
    return true;
  }
}

function isManagedWorkflow(text: string): boolean {
  return text.startsWith(WORKFLOW_MARKER) || text.startsWith(PORTABLE_MARKER + "\n" + WORKFLOW_MARKER) ||
    text.startsWith(PORTABLE_MARKER + "\r\n" + WORKFLOW_MARKER);
}

function workflowRepository(workflow: string | undefined): string | undefined {
  return workflow?.match(/^jobs:\r?\n  readiness:\r?\n    if: \$\{\{ github\.repository == '([A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+)' && /m)?.[1];
}

// A prior slug is available only from the managed workflow on the fetched base.
// CI continues to call parsePolicy with the event repository as its only identity.
function parseAdoptionPolicy(text: string, repository: string, prior: string | undefined) {
  try {
    return parsePolicy(text, repository);
  } catch (error) {
    if (!prior || prior.toLowerCase() === repository.toLowerCase()) throw error;
    return parsePolicy(text, prior);
  }
}

function existingRunner(workflow: string | undefined): string | undefined {
  const runner = workflow?.match(/^    runs-on: ([^\r\n]+)\r?$/m)?.[1];
  if (runner === "ubuntu-latest" || (runner && /^\[self-hosted(?:, *[A-Za-z0-9][A-Za-z0-9._-]*){3,4}\]$/.test(runner))) {
    return runner;
  }
}

function render(source: string, base: string, priorRunner: string | undefined): string {
  const checkout = source.indexOf(TRUSTED_CHECKOUT);
  const uses = source.indexOf("        uses: ", checkout);
  const policy = source.indexOf(POLICY_STEP);
  const pin = source.indexOf(PIN_STEP);
  const trustedStep = source.slice(uses, policy);
  if (!source.startsWith(WORKFLOW_MARKER) || !source.includes(HEAD_REF) || checkout < 0 ||
      uses <= checkout || policy <= uses || pin <= policy || !trustedStep.includes(TRUSTED_REF) || source.includes("@@")) {
    throw new Error("Hatsu's readiness workflow template has no complete portable rendering");
  }
  let result = PORTABLE_MARKER + "\n" + source.slice(0, checkout).replace(HEAD_REF, HEAD_REF + "          path: .candidate\n") +
    TRUSTED_CHECKOUT + "        # Use the declared base even when the pull request targets a stacked branch.\n" +
    trustedStep.replace(TRUSTED_REF, "          ref: refs/heads/" + base + "\n          path: .trusted\n") +
    PORTABLE_STEP + source.slice(pin);
  if (priorRunner) {
    result = result.replace(/^    runs-on: [^\n]+$/m, () => "    runs-on: " + priorRunner)
      .replace(/^#   runs-on      : [^\n]+$/m, () => "#   runs-on      : " + priorRunner)
      .replace(/^#   runner reason: [^\n]+$/m, "#   runner reason: repository visibility was unreadable, so the existing runner was preserved");
  }
  return result;
}

function git(repo: string, args: string[], absent?: number): string | undefined {
  const out = spawnSync("git", ["-C", repo, ...args], {
    encoding: "utf8", timeout: 5_000, maxBuffer: 2 * 1024 * 1024,
    env: { ...process.env, GIT_NO_LAZY_FETCH: "1" },
  });
  if (out.status === 0) return out.stdout;
  if (out.status === absent) return undefined;
  throw new Error("cannot read the trusted base with git " + args[0]);
}

function declaredBase(repo: string): string {
  const workflow = regularText(repo, "nen/workflow.json");
  const base = workflow === undefined ? "main" : (JSON.parse(workflow)?.branch?.base ?? "main");
  if (typeof base !== "string" || !/^[A-Za-z0-9][A-Za-z0-9._/-]*$/.test(base) ||
      git(repo, ["check-ref-format", "refs/heads/" + base], 1) === undefined) {
    throw new Error("cannot read the trusted base from nen/workflow.json branch.base");
  }
  return base;
}

function committedText(repo: string, commit: string, path: string): string | undefined {
  const listing = git(repo, ["ls-tree", commit, "--", path]);
  if (!listing) return undefined;
  if (!/^100(?:644|755) blob [a-f0-9]+\t/.test(listing)) {
    throw new Error("trusted base " + path + " must be a regular file");
  }
  return git(repo, ["cat-file", "blob", commit + ":" + path]);
}

function writeOwned(repo: string, path: string, before: string | undefined, content: string) {
  if (before === content) return;
  const target = join(repo, path);
  if (regularText(repo, path) !== before) throw new Error(path + " changed during adoption; re-run diagnose");
  mkdirSync(dirname(target), { recursive: true });
  const temporary = target + "." + randomUUID() + ".tmp";
  try {
    writeFileSync(temporary, content, { encoding: "utf8", flag: "wx", mode: 0o644 });
    renameSync(temporary, target);
  } finally {
    if (fileInfo(temporary)) unlinkSync(temporary);
  }
}

export function adoptPortableReadiness(
  repo: string, hatsuRoot: string, input: RenderInputs, mode: "diagnose" | "apply", readerReady: boolean,
): ReadinessRow | null {
  let lock: { path: string; descriptor: number } | undefined;
  try {
    // An existing repository-owned Ruby policy keeps its registration and rendering.
    // A previously adopted portable policy remains in effect when a Ruby file is added.
    const targets = portableTargets(repo, input.role);
    if (!targets) return null;
    let { localGuard, localPolicy } = targets;
    if (!input.role || !input.repository) {
      return row("blocked", "repository role or slug is unknown; the portable policy cannot be rendered",
        "record the role in nen/repos.json and resolve the repository slug");
    }
    const registry = adoptionRole(registryText(repo), input.repository);
    if (registry.role !== input.role || registry.digest !== input.registry) throw new Error(READINESS_CONTEXT_CHANGED);
    if (!input.rendered) {
      return row("blocked", "Hatsu's dependency.pinned_ref is absent or malformed; the readiness workflow cannot bootstrap Nen",
        "repair Hatsu's nen/contract.json");
    }
    if (input.runnerLabelsRequired) {
      return row("blocked", "the self-hosted runner needs the pool's declared labels",
        "declare one pool in nen/workflow.json or pass --runner-labels");
    }
    if (!readerReady) {
      return row("staged", "the trusted JSON reader must be installed before the workflow can call it",
        "install scripts/readiness_ci_verdict.mts first");
    }
    if (mode === "apply") {
      const gitDir = git(repo, ["rev-parse", "--path-format=absolute", "--git-dir"])!.trim();
      const path = join(gitDir, "tenkai-readiness-policy.lock");
      try {
        lock = { path, descriptor: openSync(path, "wx", 0o600) };
      } catch (error) {
        if ((error as NodeJS.ErrnoException).code !== "EEXIST") throw error;
        return row("blocked", "portable readiness apply is already locked at " + path,
          "wait for the other apply, or verify its owner has stopped before removing an abandoned lock");
      }
      writeFileSync(lock.descriptor, String(process.pid) + "\n");
      localGuard = regularText(repo, GUARD_PATH);
      localPolicy = regularText(repo, POLICY_PATH);
    }
    const source = regularText(hatsuRoot, GUARD_PATH);
    if (!source?.startsWith("#!/usr/bin/env node\n") || source.startsWith(GUARD_PREFIX)) {
      throw new Error("Hatsu's portable guard source is missing, linked or malformed");
    }
    const guard = source.replace("#!/usr/bin/env node\n", GUARD_PREFIX) + "\nrunPolicyCheck();\n";
    if (localGuard !== undefined && !localGuard.startsWith(GUARD_PREFIX)) {
      throw new Error(GUARD_PATH + " belongs to the repository; review it before replacement");
    }
    const existing = regularText(repo, input.path);
    if (existing !== undefined && !isManagedWorkflow(existing)) {
      return row("drift", "a pr-readiness.yml is installed that Tenkai did not render. Its bytes were preserved",
        "review the workflow by hand before adopting the portable rendering");
    }

    const base = declaredBase(repo);
    const commit = git(repo, ["rev-parse", "--verify", "--quiet", "refs/remotes/origin/" + base + "^{commit}"], 1)?.trim();
    const trustedGuard = commit && committedText(repo, commit, GUARD_PATH);
    const trustedPolicy = commit && committedText(repo, commit, POLICY_PATH);
    const trustedWorkflow = commit && committedText(repo, commit, input.path);
    if ((trustedGuard === undefined) !== (trustedPolicy === undefined)) {
      throw new Error("trusted base has only one of the portable guard and its manifest");
    }
    if (trustedWorkflow !== undefined && !isManagedWorkflow(trustedWorkflow)) {
      return row("drift", "the trusted base carries a pr-readiness.yml that Tenkai did not render. Its bytes were preserved",
        "review the workflow on the trusted base before adopting the portable rendering");
    }

    const priorRepository = workflowRepository(trustedWorkflow);
    let policyRepository = input.repository;
    let allowed: string[] | undefined;
    if (trustedPolicy !== undefined) {
      if (!trustedGuard?.startsWith(GUARD_PREFIX)) {
        throw new Error("the trusted base does not carry Tenkai's portable guard");
      }
      const trusted = parseAdoptionPolicy(trustedPolicy, input.repository, priorRepository);
      const admission = trusted.workflows[input.path];
      if (!admission) throw new Error("trusted policy does not select " + input.path);
      allowed = admittedDigests(admission, trustedWorkflow);
      policyRepository = trusted.repository;
    }
    // The local manifest can still carry the old slug after a policy-first landing.
    // Allow that only after the fetched policy has verified the active workflow.
    const localAdmission = localPolicy === undefined ? undefined :
      parseAdoptionPolicy(localPolicy, input.repository, allowed ? priorRepository : undefined).workflows[input.path];
    const current = existing === undefined ? undefined : workflowDigest(existing);
    let priorRunner: string | undefined;
    if (!input.runnerKnown && (trustedWorkflow !== undefined || existing !== undefined)) {
      const localAdmitted = current !== undefined && localGuard?.startsWith(GUARD_PREFIX) &&
        (localAdmission?.current === current || allowed?.includes(current));
      priorRunner = existingRunner(trustedWorkflow ?? (localAdmitted ? existing : undefined));
      if (!priorRunner) {
        return row("staged", "portable workflow runner cannot be established while repository visibility is unreadable",
          "re-run apply when visibility is readable or pass the known repository visibility");
      }
    }

    const rendered = render(input.rendered, base, priorRunner);
    const expected = workflowDigest(rendered);
    const trustedDigest = trustedWorkflow === undefined ? undefined : workflowDigest(trustedWorkflow);
    const admission: Admission = trustedDigest !== undefined && trustedDigest !== expected
      ? { current: trustedDigest, next: expected } : { current: expected };
    const slugChanged = priorRepository !== undefined && priorRepository !== input.repository;
    const slugDetail = slugChanged ? " for the repository slug change from " + priorRepository + " to " + input.repository : "";
    const staged = allowed
      ? policyRepository.toLowerCase() !== input.repository.toLowerCase() || !allowed.includes(expected)
      : admission.next !== undefined;
    if (!commit && localPolicy !== undefined && localAdmission?.current !== expected && current !== expected) {
      return row("staged", "portable workflow policy needs the fetched trusted base before changing its admission",
        "fetch the declared origin base, then re-run apply");
    }

    const manifest = policyText({ contract: POLICY_CONTRACT, repository: input.repository, workflows: { [input.path]: admission } });
    if (mode === "apply") {
      writeOwned(repo, GUARD_PATH, localGuard, guard);
      writeOwned(repo, POLICY_PATH, localPolicy, manifest);
    }
    if (staged) {
      return row("staged", "portable workflow policy must admit the next rendering on the trusted base first" + slugDetail,
        "apply to prepare the portable guard and manifest, land them alone on the trusted base, then fetch it and re-run apply");
    }
    if (current === expected && localGuard === guard && localPolicy === manifest) {
      return row("satisfied", "portable policy and rendered readiness workflow match for " + input.repository);
    }
    if (mode === "diagnose") {
      return row(current === undefined ? "missing" : "drift", "portable policy or rendered readiness workflow differs from Hatsu's rendering" + slugDetail,
        "re-run Tenkai apply to install the portable guard, policy and workflow");
    }
    if (current !== expected) writeOwned(repo, input.path, existing, rendered);
    return row("repaired", "installed the portable readiness guard, policy and workflow for " + input.repository);
  } catch (error) {
    return row("blocked", (error as Error).message, "review the portable readiness policy and the path named above");
  } finally {
    if (lock) {
      closeSync(lock.descriptor);
      unlinkSync(lock.path);
    }
  }
}
