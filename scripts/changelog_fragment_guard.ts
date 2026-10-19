#!/usr/bin/env node
// #166: the PR-time changelog decision. This is trusted code beside the
// plugin-bump guard; the PR checkout supplies paths and Markdown as data.
import { lstatSync, readFileSync, realpathSync } from 'node:fs';
import { dirname, isAbsolute, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

type FragmentPolicy = {
  specPaths: string[];
  fragmentDir: string;
  headChangelog: string;
  directSection: { optOut: string };
};

function regularHeadFile(root: string, path: string): boolean {
  if (!path || isAbsolute(path) || path.split('/').includes('..')) return false;
  const candidate = resolve(root, path);
  const rel = relative(root, candidate);
  if (!rel || rel.startsWith('..') || isAbsolute(rel)) return false;
  try {
    const stat = lstatSync(candidate);
    if (!stat.isFile() || stat.isSymbolicLink()) return false;
    const resolved = realpathSync(candidate);
    const realRel = relative(root, resolved);
    return !!realRel && !realRel.startsWith('..') && !isAbsolute(realRel);
  } catch {
    return false;
  }
}

function visibleLine(body: string, target: string): boolean {
  let inComment = false;
  let fence: { marker: string; length: number } | null = null;
  for (const raw of body.split(/\r?\n/)) {
    if (fence) {
      // Inside a fence HTML-looking text is literal code, not a comment.
      const closing = raw.match(/^ {0,3}(`{3,}|~{3,})[ \t]*$/);
      if (closing && closing[1][0] === fence.marker && closing[1].length >= fence.length) {
        fence = null;
      }
      continue;
    }
    let line = raw;
    // HTML comments may start and end within a line or span several lines.
    let visible = '';
    while (line.length) {
      if (inComment) {
        const end = line.indexOf('-->');
        if (end < 0) { line = ''; break; }
        line = line.slice(end + 3);
        inComment = false;
      } else {
        const start = line.indexOf('<!--');
        if (start < 0) { visible += line; break; }
        visible += line.slice(0, start);
        line = line.slice(start + 4);
        inComment = true;
      }
    }
    const markerLine = visible.match(/^ {0,3}(`{3,}|~{3,})(.*)$/);
    if (markerLine) {
      const marker = markerLine[1][0];
      fence = { marker, length: markerLine[1].length };
      continue;
    }
    if (visible === target) return true;
  }
  return false;
}

function policyAt(scriptPath: string): FragmentPolicy {
  const contractPath = join(dirname(dirname(scriptPath)), 'contracts/pr-composition.json');
  const document = JSON.parse(readFileSync(contractPath, 'utf8')) as { changelogFragment?: unknown };
  const policy = document.changelogFragment as FragmentPolicy | undefined;
  if (!policy || !Array.isArray(policy.specPaths) ||
      !policy.specPaths.every((p) => typeof p === 'string' && p.length > 0) ||
      typeof policy.fragmentDir !== 'string' || !policy.fragmentDir ||
      typeof policy.headChangelog !== 'string' || !policy.headChangelog ||
      typeof policy.directSection?.optOut !== 'string' || !policy.directSection.optOut) {
    throw new Error('trusted changelogFragment contract is missing or malformed');
  }
  return policy;
}

function main(args: string[]): number {
  if (args.length !== 3) throw new Error('expected changed-files file, head root, and PR body file');
  const [changedFile, headRoot, bodyFile] = args;
  const root = realpathSync(headRoot);
  const policy = policyAt(fileURLToPath(import.meta.url));
  const changed = readFileSync(changedFile, 'utf8').split(/\r?\n/).filter(Boolean);
  const specTouched = changed.some((path) => policy.specPaths.some((spec) =>
    spec.endsWith('/') ? path.startsWith(spec) : path === spec));
  if (!specTouched) {
    console.log('changelog fragment: not applicable (no declared spec path changed)');
    return 0;
  }
  const fragmentPresent = changed.some((path) => {
    if (!path.startsWith(`${policy.fragmentDir}/`)) return false;
    const name = path.slice(policy.fragmentDir.length + 1);
    return /^[^/]+\.md$/.test(name) && regularHeadFile(root, path);
  });
  if (fragmentPresent) {
    console.log(`changelog fragment: changed ${policy.fragmentDir}/ fragment present at PR head`);
    return 0;
  }
  if (changed.includes(policy.headChangelog) &&
      regularHeadFile(root, policy.headChangelog) &&
      visibleLine(readFileSync(bodyFile, 'utf8'), policy.directSection.optOut)) {
    console.log(`changelog fragment: direct ${policy.headChangelog} section declared by this PR`);
    return 0;
  }
  console.error(`plugin-bump guard: a declared spec path changed, but this PR has no changed ${policy.fragmentDir}/<name>.md fragment at head; add the appropriate fragment (contracts/pr-composition.json, changelogFragment)`);
  return 1;
}

try {
  process.exitCode = main(process.argv.slice(2));
} catch (error) {
  console.error(`plugin-bump guard: ${(error as Error).message}`);
  process.exitCode = 2;
}
