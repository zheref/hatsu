#!/usr/bin/env node
import { checkoutPack, permissionSource } from './claude_routine_permissions.mts';

try {
  const args = process.argv.slice(2);
  if (args.length !== 3) throw new Error('expected permissions source, Hatsu root, marker');
  const [source, root, marker] = args;
  console.log(JSON.stringify(checkoutPack(permissionSource(source), root, marker), null, 2));
} catch (error) {
  console.error(`permissions-pack-claude-render: ${error instanceof Error ? error.message : String(error)}`);
  process.exitCode = 2;
}
