#!/usr/bin/env node
// #131 & #554: Tenkai's readiness-reader, workflow-gate, and bootstrap-integrity decisions live in TypeScript (BC-11).
// The older Python engine passes only a mode and two paths, then relays this row.
import { closeSync, lstatSync, mkdirSync, openSync, readFileSync, realpathSync, renameSync, unlinkSync, writeFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

export type State = "satisfied" | "missing" | "drift" | "blocked" | "repaired" | "staged";
export type Row = { state: State; detail: string; action: string | null };
export type BootstrapPins = { ref: string; scriptSha256: string; binarySha256: string };
const REL = "scripts/readiness_ci_verdict.mts";
const GUARD = "scripts/workflow_runner_policy_check.rb";
const MARKER = "// RENDERED BY hatsu:tenkai from scripts/readiness_ci_verdict.mts";
const REF_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._/-]{0,99}$/;
const SHA256_PATTERN = /^[a-f0-9]{64}$/;
const PLATFORM_PATTERN = /^[a-z0-9-]+$/;

function row(state: State, detail: string, action: string | null = null): Row {
  return { state, detail, action };
}

function stat(path: string): ReturnType<typeof lstatSync> | null {
  try { return lstatSync(path); }
  catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") return null;
    throw error;
  }
}

function sourceText(hatsuRoot: string): string | null {
  const source = join(hatsuRoot, REL);
  const info = stat(source);
  if (!info?.isFile() || info.isSymbolicLink()) return null;
  const text = readFileSync(source, "utf8");
  return text.startsWith("#!/usr/bin/env node\n") ? text : null;
}

function readDependency(hatsuRoot: string): Record<string, unknown> | null {
  const contractPath = join(hatsuRoot, "nen", "contract.json");
  const info = stat(contractPath);
  if (!info?.isFile() || info.isSymbolicLink()) return null;
  try {
    const parsed = JSON.parse(readFileSync(contractPath, "utf8")) as Record<string, unknown>;
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return null;
    const dep = parsed.dependency;
    if (!dep || typeof dep !== "object" || Array.isArray(dep)) return null;
    return dep as Record<string, unknown>;
  } catch {
    return null;
  }
}

export function readPinnedRef(hatsuRoot: string): string | null {
  const dep = readDependency(hatsuRoot);
  if (!dep) return null;
  const ref = dep.pinned_ref;
  if (typeof ref !== "string" || !REF_PATTERN.test(ref) || ref.includes("..") || ref.includes("//")) return null;
  return ref;
}

export function readBootstrapIntegrity(hatsuRoot: string): { scriptSha256: string; binarySha256: string } | null {
  const dep = readDependency(hatsuRoot);
  if (!dep) return null;
  const data = dep.bootstrap;
  if (!data || typeof data !== "object" || Array.isArray(data)) return null;
  const bootstrap = data as Record<string, unknown>;
  const scriptSha256 = bootstrap.scriptSha256;
  const binaries = bootstrap.sha256;
  if (typeof scriptSha256 !== "string" || !SHA256_PATTERN.test(scriptSha256)) return null;
  if (!binaries || typeof binaries !== "object" || Array.isArray(binaries)) return null;
  const binaryMap = binaries as Record<string, unknown>;
  if (!Object.hasOwn(binaryMap, "linux-x64")) return null;
  for (const [key, value] of Object.entries(binaryMap)) {
    if (key === "$comment") continue;
    if (!PLATFORM_PATTERN.test(key) || typeof value !== "string" || !SHA256_PATTERN.test(value)) return null;
  }
  return { scriptSha256, binarySha256: binaryMap["linux-x64"] as string };
}

export function bootstrapPins(hatsuRoot: string): BootstrapPins | null {
  const ref = readPinnedRef(hatsuRoot);
  const integrity = readBootstrapIntegrity(hatsuRoot);
  if (!ref || !integrity) return null;
  return { ref, scriptSha256: integrity.scriptSha256, binarySha256: integrity.binarySha256 };
}

export function readerState(repo: string, hatsuRoot: string): Row {
  const source = sourceText(hatsuRoot);
  if (source === null) return row("blocked", "Hatsu's trusted readiness reader is missing, linked or malformed", "repair the Hatsu installation");
  const parent = join(repo, "scripts");
  const parentInfo = stat(parent);
  if (parentInfo?.isSymbolicLink() || (parentInfo && !parentInfo.isDirectory())) {
    return row("blocked", "reader parent directory is not a regular directory; Tenkai will not write through it");
  }
  const target = join(repo, REL);
  const targetInfo = stat(target);
  if (targetInfo?.isSymbolicLink()) return row("blocked", "reader path is a symlink; Tenkai will not follow it");
  if (!targetInfo) return row("missing", "trusted reader is not installed", "copy Hatsu's reader before installing the workflow");
  if (!targetInfo.isFile()) return row("blocked", "reader path is a regular directory or special file; expected a file");
  const actual = readFileSync(target, "utf8");
  const expected = source.replace("#!/usr/bin/env node\n", `#!/usr/bin/env node\n${MARKER}\n`);
  if (actual === source) return row("satisfied", "the exact Hatsu source reader is already installed");
  if (actual === expected) return row("satisfied", "trusted reader matches Hatsu's current source");
  if (!actual.includes(MARKER)) return row("blocked", "reader exists but was not installed by Tenkai; review it before replacement");
  return row("drift", "Tenkai's trusted reader differs from Hatsu's current source", "reinstall the reader");
}

export function applyReader(repo: string, hatsuRoot: string): Row {
  const before = readerState(repo, hatsuRoot);
  if (before.state !== "missing" && before.state !== "drift") return before;
  const parent = join(repo, "scripts");
  mkdirSync(parent, { recursive: true });
  const parentInfo = stat(parent);
  if (!parentInfo?.isDirectory() || parentInfo.isSymbolicLink()) {
    return row("blocked", "reader parent directory became unsafe before the write");
  }
  const target = join(repo, REL);
  if (stat(target)?.isSymbolicLink()) return row("blocked", "reader path became a symlink before the write");
  const source = sourceText(hatsuRoot);
  if (source === null) return row("blocked", "Hatsu's trusted readiness reader changed before the write");
  const expected = source.replace("#!/usr/bin/env node\n", `#!/usr/bin/env node\n${MARKER}\n`);
  const temp = join(parent, `.readiness-ci-${randomBytes(16).toString("hex")}.tmp`);
  const fd = openSync(temp, "wx", 0o644);
  try {
    writeFileSync(fd, expected, "utf8");
  } finally { closeSync(fd); }
  try { renameSync(temp, target); }
  finally { if (stat(temp)) unlinkSync(temp); }
  return row("repaired", "trusted readiness JSON reader installed");
}

export function workflowGate(repo: string, hatsuRoot: string): Row {
  if (readerState(repo, hatsuRoot).state !== "satisfied") {
    return row("staged", "the trusted JSON reader must be installed before the workflow can call it",
      "install scripts/readiness_ci_verdict.mts first");
  }
  const guard = join(repo, GUARD);
  const info = stat(guard);
  if (info?.isSymbolicLink()) return row("staged", "the workflow guard is linked; its admission cannot be trusted");
  if (info?.isFile()) {
    const live = readFileSync(guard, "utf8").split("\n").filter(line => !line.trimStart().startsWith("#")).join("\n");
    if (live.includes("READINESS_FROZEN_VERDICT") && !live.includes("READINESS_FROZEN_VERDICT_NEXT")) {
      return row("staged", "the current workflow guard does not admit the JSON reader step",
        "land the guard's exact next-step policy in its own PR before installing the workflow");
    }
    if (live.includes("READINESS_RENDERED_STEPS") && !live.includes("READINESS_INTEGRITY_STEPS")) {
      return row("staged", "the current workflow guard does not admit the checksum-verified bootstrap step",
        "land the guard's exact READINESS_INTEGRITY_PIN and READINESS_INTEGRITY_BOOTSTRAP policy in its own PR before installing the workflow");
    }
  }
  if (!readPinnedRef(hatsuRoot)) {
    return row("blocked", "Hatsu's dependency.pinned_ref is absent or malformed; the readiness workflow cannot bootstrap Nen",
      "repair Hatsu's nen/contract.json");
  }
  if (!readBootstrapIntegrity(hatsuRoot)) {
    return row("blocked", "Hatsu's dependency.bootstrap checksums are absent or malformed; the readiness workflow cannot bootstrap Nen",
      "repair Hatsu's nen/contract.json");
  }
  return row("satisfied", "the trusted reader and workflow policy are ready");
}

function isEntrypoint(): boolean {
  try {
    return Boolean(process.argv[1]) && realpathSync(resolve(process.argv[1]!)) === realpathSync(fileURLToPath(import.meta.url));
  } catch {
    return false;
  }
}

if (isEntrypoint()) {
  const [mode, repo, hatsuRoot] = process.argv.slice(2);
  if (!repo || !hatsuRoot || !["diagnose", "apply", "workflow-gate", "bootstrap-pins"].includes(mode ?? "")) {
    throw new Error("usage: tenkai_readiness_guard.mts <diagnose|apply|workflow-gate|bootstrap-pins> <repo> <hatsu-root>");
  }
  if (mode === "bootstrap-pins") {
    const pins = bootstrapPins(hatsuRoot);
    if (!pins) {
      console.error("Hatsu's dependency.pinned_ref or dependency.bootstrap checksums are absent or malformed");
      process.exit(1);
    }
    process.stdout.write(JSON.stringify(pins) + "\n");
  } else {
    const result = mode === "apply" ? applyReader(repo, hatsuRoot)
      : mode === "workflow-gate" ? workflowGate(repo, hatsuRoot) : readerState(repo, hatsuRoot);
    process.stdout.write(JSON.stringify(result) + "\n");
  }
}
