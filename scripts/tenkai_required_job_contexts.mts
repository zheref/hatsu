// Check a static job name in rendered Actions YAML. Psych supplies YAML decoding;
// TypeScript owns the job-context policy and the diagnostic.
import { spawnSync } from "node:child_process";
import { regularText } from "./readiness_workflow_policy.mts";

const CONTRACT_PATH = "contracts/required-job-contexts.json";
type WorkflowDocument = { jobs?: Record<string, { name?: unknown; strategy?: { matrix?: unknown }; uses?: unknown }> };

export function assertRequiredJobContexts(workflow: string, text: string, contexts: readonly string[]) {
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
  const jobs = Object.entries(document?.jobs ?? {});
  for (const context of contexts) {
    const matches = jobs.filter(([id, job]) =>
      job !== null && typeof job === "object" && !Array.isArray(job) &&
      (job.name === undefined ? id : job.name) === context);
    if (matches.length !== 1 || matches[0][1].strategy?.matrix !== undefined || matches[0][1].uses !== undefined) {
      throw new Error(workflow + ': required context "' + context + '" must equal one static workflow job name');
    }
  }
}

export function assertManagedRequiredJobContexts(root: string, workflow: string, text: string) {
  const source = regularText(root, CONTRACT_PATH);
  const contract = source === undefined ? null : JSON.parse(source);
  const contexts: unknown = contract?.workflows?.[workflow];
  if (contract?.contract !== "hatsu.required-job-contexts/v1" ||
      !Array.isArray(contexts) || contexts.length === 0 ||
      !contexts.every(context => typeof context === "string" && context.trim() === context && context.length > 0) ||
      new Set(contexts).size !== contexts.length) {
    throw new Error(workflow + ": required job context declaration is missing or malformed in " + CONTRACT_PATH);
  }
  assertRequiredJobContexts(workflow, text, contexts);
}
