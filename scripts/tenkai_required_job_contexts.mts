// Check a static job name in rendered Actions YAML. Psych supplies YAML decoding;
// TypeScript owns the job-context policy and the diagnostic.
import { spawnSync } from "node:child_process";
import { regularText } from "./readiness_workflow_policy.mts";

const CONTRACT_PATH = "contracts/required-job-contexts.json";
type WorkflowJob = { name?: unknown; strategy?: { matrix?: unknown }; uses?: unknown; "runs-on"?: unknown; steps?: unknown };
type WorkflowDocument = { jobs?: Record<string, WorkflowJob> };

function workflowJobs(workflow: string, text: string, contexts: readonly string[]) {
  const decoded = spawnSync("ruby", ["-rpsych", "-rjson", "-e", "puts JSON.generate(Psych.safe_load(STDIN.read))"], {
    input: text, encoding: "utf8", timeout: 5_000, maxBuffer: 2 * 1024 * 1024,
  });
  if (decoded.error?.code === "ENOENT") {
    throw new Error(workflow + ": Ruby with Psych is required on the Tenkai host to read job contexts " + contexts.join(", "));
  }
  if (decoded.status !== 0 || decoded.error) {
    throw new Error(workflow + ": Ruby/Psych could not decode workflow jobs for required contexts " + contexts.join(", "));
  }
  const document: WorkflowDocument | null = JSON.parse(decoded.stdout);
  return document?.jobs ?? {};
}

export function assertRequiredJobContexts(workflow: string, text: string, contexts: readonly string[]) {
  assertJobContexts(workflow, workflowJobs(workflow, text, contexts), contexts);
}

function assertJobContexts(workflow: string, decoded: Record<string, WorkflowJob>, contexts: readonly string[]) {
  const jobs = Object.entries(decoded);
  for (const context of contexts) {
    const matches = jobs.filter(([id, job]) =>
      /^[A-Za-z_][A-Za-z0-9_-]*$/.test(id) && job !== null && typeof job === "object" && !Array.isArray(job) &&
      (job.name === undefined ? id : job.name) === context);
    if (matches.length !== 1 || matches[0][1].strategy?.matrix !== undefined || matches[0][1].uses !== undefined) {
      throw new Error(workflow + ': required context "' + context + '" must equal one static workflow job name');
    }
  }
}

function requiredContexts(root: string, workflow: string): string[] {
  const source = regularText(root, CONTRACT_PATH);
  const contract = source === undefined ? null : JSON.parse(source);
  const contexts: unknown = contract?.workflows?.[workflow];
  if (contract?.contract !== "hatsu.required-job-contexts/v1" ||
      !Array.isArray(contexts) || contexts.length === 0 ||
      !contexts.every(context => typeof context === "string" && context.trim() === context && context.length > 0) ||
      new Set(contexts).size !== contexts.length) {
    throw new Error(workflow + ": required job context declaration is missing or malformed in " + CONTRACT_PATH);
  }
  return contexts;
}

export function assertManagedRequiredJobContexts(root: string, workflow: string, text: string) {
  assertRequiredJobContexts(workflow, text, requiredContexts(root, workflow));
}

export function inspectReadinessJob(root: string, workflow: string, text: string) {
  const contexts = requiredContexts(root, workflow);
  let runner: string | undefined;
  try {
    const jobs = workflowJobs(workflow, text, contexts);
    const readiness = Object.values(jobs).filter(job => job && Array.isArray(job.steps) &&
      job.steps.some(step => step?.name === "Readiness verdict" && typeof step.run === "string" &&
        step.run.split(/\r?\n/).some(line => line.trim() === "node .trusted/scripts/readiness_ci_verdict.mts")));
    const selector = readiness.length === 1 ? readiness[0]["runs-on"] : undefined;
    const safeLabel = (label: unknown): label is string =>
      typeof label === "string" && /^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(label);
    const yamlLabel = (label: string) =>
      /^(?:[0-9]|(?:yes|no|on|off|true|false|null|y|n)$)/i.test(label) ? JSON.stringify(label) : label;
    if (safeLabel(selector) && selector !== "self-hosted") runner = yamlLabel(selector);
    if (Array.isArray(selector) && selector.length > 1 && selector.every(safeLabel)) {
      runner = "[" + selector.map(yamlLabel).join(", ") + "]";
    }
    assertJobContexts(workflow, jobs, contexts);
    return { runner, diagnostic: undefined };
  } catch (error) {
    return { runner, diagnostic: (error as Error).message };
  }
}
