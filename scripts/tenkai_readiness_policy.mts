// Tenkai owns rendering and admission here. The legacy engine supplies its resolved inputs.
import { spawnSync } from "node:child_process";
import { closeSync, mkdirSync, openSync, renameSync, unlinkSync, writeFileSync } from "node:fs";
import { randomUUID } from "node:crypto";
import { assertManagedRequiredJobContexts } from "./tenkai_required_job_contexts.mts";
import { dirname, join } from "node:path";
import {
  GUARD_MARKER, GUARD_PATH, POLICY_CONTRACT, POLICY_PATH, admittedDigests,
  fileInfo, parsePolicy, policyText, regularText, workflowDigest,
  type Admission,
} from "./readiness_workflow_policy.mts";

type State = "satisfied" | "missing" | "drift" | "blocked" | "repaired" | "staged";
type Row = { state: State; detail: string; action: string | null };
export type RenderInputs = {
  role: string | null;
  repository: string | null;
  path: string;
  rendered: string | null;
  runnerKnown: boolean;
  runnerLabelsRequired: boolean;
};

const LEGACY_GUARD = "scripts/workflow_runner_policy_check.rb";
const LEGACY_WORKFLOW_MARKER = "RENDERED BY hatsu:tenkai";
const WORKFLOW_MARKER = "# pr-readiness.yml — " + LEGACY_WORKFLOW_MARKER + ".";
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

function row(state: State, detail: string, action: string | null = null): Row {
  return { state, detail, action };
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

// The frozen adopter handles ordinary legacy readiness drift. Own only the
// required-context defect here, after the same reader and Ruby policy gate.
export function adoptLegacyRequiredContext(
  repo: string, hatsuRoot: string, input: RenderInputs, mode: "diagnose" | "apply", gateReady: () => boolean,
): Row | null {
  if (!input.role || !input.repository || input.rendered === null || input.runnerLabelsRequired || !gateReady()) return null;
  try {
    const installed = regularText(repo, input.path);
    if (installed === undefined) return null;
    let contextError: string;
    try {
      assertManagedRequiredJobContexts(hatsuRoot, input.path, installed);
      return null;
    } catch (error) {
      contextError = (error as Error).message;
    }
    if (mode === "diagnose") return row("drift", contextError, "re-render from templates/pr-readiness.yml");
    if (!installed.includes(LEGACY_WORKFLOW_MARKER)) {
      return row("drift", "a pr-readiness.yml is installed that Tenkai did not render — it will not be overwritten",
        "review by hand, then delete it and re-run apply");
    }
    const live = installed.split(/\r?\n/).filter(line => !line.trimStart().startsWith("#")).join("\n");
    const runner = input.runnerKnown ? undefined : live.match(/runs-on:[ \t]*(\[[^\r\n\]]*\]|\S+)/)?.[1];
    const rendered = runner ? input.rendered
      .replace(/^    runs-on: [^\n]+$/m, () => "    runs-on: " + runner)
      .replace(/^#   runs-on      : [^\n]+$/m, () => "#   runs-on      : " + runner) : input.rendered;
    if (runner) assertManagedRequiredJobContexts(hatsuRoot, input.path, rendered);
    writeOwned(repo, input.path, installed, rendered);
    const shown = runner ?? rendered.match(/^    runs-on: ([^\n]+)$/m)?.[1];
    return row("repaired", "rendered for " + input.repository + ", runs-on " + shown +
      (runner ? " (runner preserved — the probe could not answer)" : ""));
  } catch (error) {
    return row("blocked", (error as Error).message, "repair the workflow path before re-adopting");
  }
}

export function adoptPortableReadiness(
  repo: string, hatsuRoot: string, input: RenderInputs, mode: "diagnose" | "apply", readerReady: boolean,
): Row | null {
  let lock: { path: string; descriptor: number } | undefined;
  try {
    if (input.rendered !== null) assertManagedRequiredJobContexts(hatsuRoot, input.path, input.rendered);
    // An existing repository-owned Ruby policy keeps its registration and rendering.
    // A previously adopted portable policy remains in effect when a Ruby file is added.
    let localGuard = regularText(repo, GUARD_PATH);
    let localPolicy = regularText(repo, POLICY_PATH);
    const prefix = "#!/usr/bin/env node\n" + GUARD_MARKER + "\n";
    const installed = localGuard?.startsWith(prefix) || localPolicy !== undefined;
    if (!installed && input.role !== "process") return null;
    const legacy = fileInfo(join(repo, LEGACY_GUARD));
    if (!installed && legacy) {
      if (!legacy.isFile()) throw new Error(LEGACY_GUARD + " must be a regular file");
      return null;
    }
    if (!input.role || !input.repository) {
      return row("blocked", "repository role or slug is unknown; the portable policy cannot be rendered",
        "record the role in nen/repos.json and resolve the repository slug");
    }
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
    if (!source?.startsWith("#!/usr/bin/env node\n") || source.startsWith(prefix)) {
      throw new Error("Hatsu's portable guard source is missing, linked or malformed");
    }
    const guard = source.replace("#!/usr/bin/env node\n", prefix) + "\nrunPolicyCheck();\n";
    if (localGuard !== undefined && !localGuard.startsWith(prefix)) {
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
      if (!trustedGuard?.startsWith(prefix)) {
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
      const localAdmitted = current !== undefined && localGuard?.startsWith(prefix) &&
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
    if (mode === "diagnose" && existing !== undefined) {
      try { assertManagedRequiredJobContexts(hatsuRoot, input.path, existing); }
      catch (error) { return row("drift", (error as Error).message, "re-run Tenkai apply to restore the required job name"); }
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
