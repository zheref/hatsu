#!/usr/bin/env node
// Verifies Tenkai's managed workflow bytes using an admission from the trusted base.
import { createHash } from "node:crypto";
import { lstatSync, readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

export const GUARD_PATH = "scripts/readiness_workflow_policy.mts";
export const POLICY_PATH = "scripts/readiness_workflow_policy.json";
export const GUARD_MARKER = "// RENDERED BY hatsu:tenkai from scripts/readiness_workflow_policy.mts";
export const POLICY_CONTRACT = "hatsu.tenkai.workflow-policy/v1";

export type Admission = { current: string; next?: string };
export type Policy = {
  contract: typeof POLICY_CONTRACT;
  repository: string;
  workflows: Record<string, Admission>;
};

export function fileInfo(path: string) {
  try {
    return lstatSync(path);
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") return undefined;
    throw error;
  }
}

// Inspect every parent before opening a file from the PR checkout.
export function regularText(root: string, relative: string): string | undefined {
  let path = root;
  const parts = relative.split("/");
  for (const part of parts.slice(0, -1)) {
    const info = fileInfo(path);
    if (!info) return undefined;
    if (!info.isDirectory()) throw new Error("unsafe directory for " + relative);
    path = join(path, part);
  }
  const parent = fileInfo(path);
  if (!parent) return undefined;
  if (!parent.isDirectory()) throw new Error("unsafe directory for " + relative);
  const target = join(path, parts.at(-1)!);
  const info = fileInfo(target);
  if (!info) return undefined;
  if (!info.isFile()) throw new Error(relative + " must be a regular file");
  return readFileSync(target, "utf8");
}

export function workflowDigest(text: string): string {
  // The leading provenance banner is outside the workflow document. Preserve
  // all document bytes, including comments or whitespace inside run scalars.
  const document = text.replace(/\r\n/g, "\n").replace(/^(?:#[^\n]*\n|\n)+/, "");
  return createHash("sha256").update(document).digest("hex");
}

export function policyText(policy: Policy): string {
  return JSON.stringify(policy, null, 2) + "\n";
}

export function parsePolicy(text: string | undefined, repository: string): Policy {
  if (text === undefined) throw new Error("trusted " + POLICY_PATH + " is missing");
  const invalid = "invalid rendered " + POLICY_PATH;
  const slug = /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/;
  const digest = /^[a-f0-9]{64}$/;
  let value: Policy;
  try {
    value = JSON.parse(text);
  } catch {
    throw new Error(invalid);
  }
  if (!value || value.contract !== POLICY_CONTRACT || typeof value.repository !== "string" ||
      !slug.test(value.repository) || !slug.test(repository) ||
      value.repository.toLowerCase() !== repository.toLowerCase() ||
      !value.workflows || typeof value.workflows !== "object" || Array.isArray(value.workflows)) {
    throw new Error(invalid + " for this repository");
  }
  const workflows: Policy["workflows"] = {};
  for (const [path, admission] of Object.entries(value.workflows)) {
    if (!/^\.github\/workflows\/[A-Za-z0-9][A-Za-z0-9_.-]*\.ya?ml$/.test(path) ||
        !admission || typeof admission.current !== "string" || !digest.test(admission.current) ||
        (admission.next !== undefined && (typeof admission.next !== "string" ||
          !digest.test(admission.next) || admission.next === admission.current))) {
      throw new Error(invalid);
    }
    workflows[path] = { current: admission.current };
    if (admission.next !== undefined) workflows[path].next = admission.next;
  }
  const policy: Policy = { contract: POLICY_CONTRACT, repository: value.repository, workflows };
  // Reject duplicates, extra keys and partial writes in the generated format.
  if (!Object.keys(workflows).length || text.replace(/\r\n/g, "\n") !== policyText(policy)) throw new Error(invalid);
  return policy;
}

export function admittedDigests(admission: Admission, trusted: string | undefined): string[] {
  if (trusted === undefined) {
    // A bootstrap PR may land the single initial admission before its workflow.
    if (!admission.next) return [admission.current];
    throw new Error("the current workflow is missing from a transition policy's trusted base");
  }
  const active = workflowDigest(trusted);
  if (active === admission.next) return [active];
  if (active !== admission.current) throw new Error("the trusted workflow differs from its admission");
  return admission.next ? [active, admission.next] : [active];
}

function verify(trusted: string, candidate: string, repository: string): number {
  const policy = parsePolicy(regularText(trusted, POLICY_PATH), repository);
  for (const [path, admission] of Object.entries(policy.workflows)) {
    const allowed = admittedDigests(admission, regularText(trusted, path));
    const proposed = regularText(candidate, path);
    if (proposed === undefined || !allowed.includes(workflowDigest(proposed))) {
      throw new Error(path + " differs from its trusted workflow admission");
    }
  }
  return Object.keys(policy.workflows).length;
}

export function runPolicyCheck() {
  const entry = fileURLToPath(import.meta.url);
  try {
    const [mode, root, ...extra] = process.argv.slice(2);
    if (mode !== "--self-test" || !root || extra.length || !process.env.GITHUB_REPOSITORY) {
      throw new Error("usage: GITHUB_REPOSITORY=owner/name node " + GUARD_PATH + " --self-test <candidate-root>");
    }
    const count = verify(dirname(dirname(entry)), resolve(root), process.env.GITHUB_REPOSITORY);
    process.stdout.write("readiness-workflow-policy: " + count + " rendered workflow(s) match the trusted admission\n");
  } catch (error) {
    process.stderr.write("readiness-workflow-policy: " + (error as Error).message.replace(/[\p{Cc}\p{Cf}]/gu, " ") + "\n");
    process.exitCode = 1;
  }
}
