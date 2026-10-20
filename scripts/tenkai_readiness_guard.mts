#!/usr/bin/env node
// #131: Tenkai's readiness-reader adoption decisions live in TypeScript (BC-11).
// The older Python engine passes only a mode and two paths, then relays this row.
import { closeSync, lstatSync, mkdirSync, openSync, readFileSync, renameSync, unlinkSync, writeFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import { join } from "node:path";

type State = "satisfied" | "missing" | "drift" | "blocked" | "repaired" | "staged";
type Row = { state: State; detail: string; action: string | null };
const REL = "scripts/readiness_ci_verdict.mts";
const GUARD = "scripts/workflow_runner_policy_check.rb";
const MARKER = "// RENDERED BY hatsu:tenkai from scripts/readiness_ci_verdict.mts";

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

function readerState(repo: string, hatsuRoot: string): Row {
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
  if (!targetInfo.isFile()) return row("blocked", "reader path is not a regular file");
  const actual = readFileSync(target, "utf8");
  const expected = source.replace("#!/usr/bin/env node\n", `#!/usr/bin/env node\n${MARKER}\n`);
  if (actual === source) return row("satisfied", "the exact Hatsu source reader is already installed");
  if (actual === expected) return row("satisfied", "trusted reader matches Hatsu's current source");
  if (!actual.includes(MARKER)) return row("blocked", "reader exists but was not installed by Tenkai; review it before replacement");
  return row("drift", "Tenkai's trusted reader differs from Hatsu's current source", "reinstall the reader");
}

function applyReader(repo: string, hatsuRoot: string): Row {
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

function workflowGate(repo: string, hatsuRoot: string): Row {
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
  }
  return row("satisfied", "the trusted reader and workflow policy are ready");
}

const [mode, repo, hatsuRoot] = process.argv.slice(2);
if (!repo || !hatsuRoot || !["diagnose", "apply", "workflow-gate"].includes(mode)) {
  throw new Error("usage: tenkai_readiness_guard.mts <diagnose|apply|workflow-gate> <repo> <hatsu-root>");
}
const result = mode === "apply" ? applyReader(repo, hatsuRoot)
  : mode === "workflow-gate" ? workflowGate(repo, hatsuRoot) : readerState(repo, hatsuRoot);
process.stdout.write(JSON.stringify(result) + "\n");
