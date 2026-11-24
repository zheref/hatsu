#!/usr/bin/env node
import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { object, readSettings } from './claude_permissions.mts';
import { CLAUDE_LOCAL, diagnoseUser, permissionSource, preflightUserHook, readRegistry, registeredRepositories, releaseOptIn, shellWord, userProposal, userSettingsPath } from './claude_routine_permissions.mts';

function compatibleClaude(): boolean {
  const result = spawnSync('claude', ['--version'], { encoding: 'utf8', timeout: 3000 });
  const version = result.status === 0 && /^(\d+)\.(\d+)\.(\d+)(?:\s|$)/.exec(result.stdout.trim());
  if (!version) return false;
  const [major, minor, patch] = version.slice(1).map(Number);
  return major > 2 || (major === 2 && (minor > 1 || (minor === 1 && patch >= 295)));
}

function publisherLane(checkout: string): unknown {
  const contract = readRegistry(join(checkout, 'nen/contract.json'));
  if (!object(contract) || !object(contract.project) || !object(contract.project.verbs) ||
      !object(contract.project.verbs.plugin)) return undefined;
  return contract.project.verbs.plugin.release;
}

function main() {
  const [mode, root, target, ...rest] = process.argv.slice(2);
  if (!['render', 'check', 'render-release-opt-in'].includes(mode) || !root || !target || rest.length) {
    throw new Error('expected render|check|render-release-opt-in, Hatsu root and target checkout');
  }
  const source = permissionSource(join(root, 'contracts/permissions.json'));
  const compatible = compatibleClaude();
  const hostRequirement = 'Claude Code CLI on PATH must report 2.1.295 or newer for a blocking user hook';
  if (mode === 'render-release-opt-in') {
    if (!compatible) throw new Error(hostRequirement);
    const origin = spawnSync('git', ['-C', target, 'config', '--local', '--get', 'remote.origin.url'], {
      encoding: 'utf8', timeout: 3000,
    });
    const trustedLane = publisherLane(root);
    if (origin.status !== 0 || !/^(?:https:\/\/github\.com\/|git@github\.com:|ssh:\/\/git@github\.com\/)zheref\/hatsu(?:\.git)?\/?$/i.test(origin.stdout.trim()) ||
        !object(trustedLane) || JSON.stringify(publisherLane(target)) !== JSON.stringify(trustedLane)) {
      throw new Error('release opt-in requires a named Hatsu checkout with the installed plugin publisher declaration');
    }
    console.error('Explicit publisher opt-in for this checkout. Each publication still requires Mugetsu’s recorded G3 go and preflight.');
    console.log(JSON.stringify(releaseOptIn(source, target), null, 2));
    return;
  }

  const readiness = preflightUserHook(root, source);
  if ('problem' in readiness) {
    if (mode === 'render') throw new Error(readiness.problem);
    console.log(`Claude routine permissions: ${readiness.problem}. Paired proposal unavailable.`);
    return;
  }

  if (mode === 'render') {
    if (!compatible) throw new Error(hostRequirement);
    const registry = readRegistry(join(root, 'nen/repos.json'));
    const nominations = join(target, 'nen/repos.json');
    if (root !== target && existsSync(nominations)) {
      const trusted = new Set(registeredRepositories(registry));
      try {
        for (const repo of registeredRepositories(readRegistry(nominations)).filter((slug) => !trusted.has(slug))) {
          console.error(`Trust nomination from target registry, needs explicit maintainer review: github.com/${repo}`);
        }
      } catch {
        console.error('Target registry nominations could not be inspected');
      }
    }
    console.error('For a separately reviewed, path-specific Hatsu publisher rule, use --render-release-opt-in with the publisher checkout.');
    console.log(JSON.stringify(userProposal(source, root, registry, readiness.hook), null, 2));
  } else {
    const user = readSettings(userSettingsPath());
    const project = [CLAUDE_LOCAL, '.claude/settings.json'].map((path) => readSettings(join(target, path)));
    const result = diagnoseUser(source, root, user, project, readiness.hook);
    const count = result.missing?.length;
    const presence = result.user === 'unreadable' ? 'user settings unreadable' :
      count === 0 ? 'routine user rows present' : `${count} routine user rows missing`;
    const proposal = `bash ${shellWord(join(root, 'scripts/permissions_pack.sh'))} --surface claude-code --render-user --target ${shellWord(target)}`;
    const safe = (text: string) => text.replace(/[\p{Cc}\p{Cf}]/gu, '');
    const notes = [
      ...result.overrides,
      ...result.unreadable.filter((path) => path !== user.path).map((path) => `unreadable ${path}`),
      result.boundHook ? 'paired checker binding present' : 'paired checker binding missing or stale',
      'visible deny/ask check uses exemplars only',
      'effective managed/session policy unknown',
      compatible ? '' : hostRequirement,
      compatible && (count || count === undefined || !result.boundHook) ? `from an independent terminal, review the proposal with ${proposal}` : '',
    ].filter(Boolean);
    console.log(safe(`Claude routine permissions: ${presence} (${user.path}); ${notes.join('; ')}`));
  }
}

try {
  main();
} catch (error) {
  console.error(`Claude routine permissions: inspection unavailable (${error instanceof Error ? error.message : String(error)})`);
  process.exitCode = 2;
}
