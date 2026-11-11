// Tenkai owns rendering and admission here. The legacy engine supplies its resolved inputs.
import { spawnSync } from "node:child_process";
import { closeSync, mkdirSync, openSync, renameSync, unlinkSync, writeFileSync } from "node:fs";
import { randomUUID } from "node:crypto";
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
const WORKFLOW_MARKER = "# pr-readiness.yml — RENDERED BY hatsu:tenkai.";
const PORTABLE_MARKER = "# Workflow policy: Tenkai's portable guard";
const HEAD_REF = "          ref: ${{ github.event.pull_request.head.sha }}\n";
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

function render(source: string, trusted: string | undefined): string {
  const start = source.indexOf(POLICY_STEP);
  const end = source.indexOf(PIN_STEP);
  if (!source.startsWith(WORKFLOW_MARKER) || !source.includes(HEAD_REF) || start < 0 || end <= start || source.includes("@@")) {
    throw new Error("Hatsu's readiness workflow template has no complete portable rendering");
  }
  let result = PORTABLE_MARKER + "\n" + source.slice(0, start).replace(HEAD_REF, HEAD_REF + "          path: .candidate\n") +
    PORTABLE_STEP + source.slice(end);
  const priorRunner = trusted?.match(/^    runs-on: ([^\r\n]+)$/m)?.[1];
  if (priorRunner) {
    result = result.replace(/^    runs-on: [^\n]+$/m, () => "    runs-on: " + priorRunner)
      .replace(/^#   runs-on      : [^\n]+$/m, () => "#   runs-on      : " + priorRunner);
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

function baseCommit(repo: string): string | undefined {
  const workflow = regularText(repo, "nen/workflow.json");
  const base = workflow === undefined ? "main" : (JSON.parse(workflow)?.branch?.base ?? "main");
  if (typeof base !== "string" || !/^[A-Za-z0-9][A-Za-z0-9._/-]*$/.test(base) || base.includes("..")) {
    throw new Error("cannot read the trusted base from nen/workflow.json branch.base");
  }
  return git(repo, ["rev-parse", "--verify", "--quiet", "refs/remotes/origin/" + base + "^{commit}"], 1)?.trim();
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
): Row | null {
  let lock: { path: string; descriptor: number } | undefined;
  try {
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
    if (existing !== undefined && !existing.startsWith(WORKFLOW_MARKER) && !existing.startsWith(PORTABLE_MARKER + "\n" + WORKFLOW_MARKER)) {
      return row("drift", "a pr-readiness.yml is installed that Tenkai did not render; its bytes were preserved",
        "review the workflow by hand before adopting the portable rendering");
    }

    const commit = baseCommit(repo);
    const trustedGuard = commit && committedText(repo, commit, GUARD_PATH);
    const trustedPolicy = commit && committedText(repo, commit, POLICY_PATH);
    const trustedWorkflow = commit && committedText(repo, commit, input.path);
    if ((trustedGuard === undefined) !== (trustedPolicy === undefined)) {
      throw new Error("trusted base has only one of the portable guard and its manifest");
    }
    const localAdmission = localPolicy === undefined ? undefined : parsePolicy(localPolicy, input.repository).workflows[input.path];
    const managedBase = trustedWorkflow?.startsWith(WORKFLOW_MARKER) || trustedWorkflow?.startsWith(PORTABLE_MARKER + "\n" + WORKFLOW_MARKER);
    const rendered = render(input.rendered, input.runnerKnown || !managedBase ? undefined : trustedWorkflow);
    const expected = workflowDigest(rendered);
    const current = existing === undefined ? undefined : workflowDigest(existing);
    let admission: Admission = { current: expected };
    let staged = false;
    if (trustedPolicy !== undefined) {
      if (!trustedGuard?.startsWith(prefix)) {
        throw new Error("the trusted base does not carry Tenkai's portable guard");
      }
      const trusted = parsePolicy(trustedPolicy, input.repository).workflows[input.path];
      if (!trusted) throw new Error("trusted policy does not select " + input.path);
      const allowed = admittedDigests(trusted, trustedWorkflow);
      staged = !allowed.includes(expected);
      if (trustedWorkflow !== undefined && allowed[0] !== expected) admission = { current: allowed[0], next: expected };
    } else if (!commit && localPolicy !== undefined && localAdmission?.current !== expected && current !== expected) {
      return row("staged", "portable workflow policy needs the fetched trusted base before changing its admission",
        "fetch the declared origin base, then re-run apply");
    }

    const manifest = policyText({ contract: POLICY_CONTRACT, repository: input.repository, workflows: { [input.path]: admission } });
    if (mode === "apply") {
      writeOwned(repo, GUARD_PATH, localGuard, guard);
      writeOwned(repo, POLICY_PATH, localPolicy, manifest);
    }
    if (staged) {
      return row("staged", "portable workflow policy must admit the next rendering on the trusted base first",
        "apply to prepare the portable guard and manifest, land them alone on the trusted base, then fetch it and re-run apply");
    }
    if (current === expected && localGuard === guard && localPolicy === manifest) {
      return row("satisfied", "portable policy and rendered readiness workflow match for " + input.repository);
    }
    if (mode === "diagnose") {
      return row(current === undefined ? "missing" : "drift", "portable policy or rendered readiness workflow differs from Hatsu's rendering",
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
