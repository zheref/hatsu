#!/usr/bin/env node
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { readSettings } from './claude_permissions.mts';
import { CLAUDE_LOCAL, diagnoseUser, permissionSource, readRegistry, shellWord, userProposal, userSettingsPath } from './claude_routine_permissions.mts';

try {
  const [mode, root, target, ...rest] = process.argv.slice(2);
  if (!['render', 'check'].includes(mode) || !root || !target || rest.length) {
    throw new Error('expected render|check, Hatsu root and target checkout');
  }
  const source = permissionSource(join(root, 'contracts/permissions.json'));
  if (mode === 'render') {
    const registryPaths = [...new Set([join(root, 'nen/repos.json'), join(target, 'nen/repos.json')])];
    console.log(JSON.stringify(userProposal(source, root, registryPaths.filter(existsSync).map(readRegistry)), null, 2));
  } else {
    const user = readSettings(userSettingsPath());
    const project = [CLAUDE_LOCAL, '.claude/settings.json'].map((path) => readSettings(join(target, path)));
    const result = diagnoseUser(source, root, user, project);
    const count = result.missing?.length;
    const presence = result.user === 'unreadable' ? 'user settings unreadable' :
      count === 0 ? 'routine user rows present' : `${count} routine user rows missing`;
    const proposal = `bash ${shellWord(join(root, 'scripts/permissions_pack.sh'))} --surface claude-code --render-user --target ${shellWord(target)}`;
    const safe = (text: string) => text.replace(/[\p{Cc}\p{Cf}]/gu, '');
    const notes = [
      ...result.overrides,
      ...result.unreadable.filter((path) => path !== user.path).map((path) => `unreadable ${path}`),
      'effective managed/session policy unknown',
      count || count === undefined ? `review proposal with ${proposal}` : '',
    ].filter(Boolean);
    console.log(safe(`Claude routine permissions: ${presence} (${user.path}); ${notes.join('; ')}`));
  }
} catch (error) {
  console.error(`Claude routine permissions: inspection unavailable (${error instanceof Error ? error.message : String(error)})`);
  process.exitCode = 2;
}
