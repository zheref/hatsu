import { spawnSync } from 'node:child_process';
import { lstatSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { object, permissionRules, readSettings, strings, type JsonObject } from './claude_permissions.mts';
import { CLAUDE_LOCAL, checkoutPack, userSettingsPath, WRAPPER, type PermissionSource } from './claude_routine_permissions.mts';

const OWNERSHIP = '\nHatsu checkout pack ownership v1: ';

// Historical spellings are diagnostic only. Before ownership was recorded, an
// identical user row cannot be distinguished from one inserted by a pack.
const LEGACY_ALLOW = new Set(['Bash(gh api *)', 'Bash(node */scripts/gh_api_read.mts *)']);
const OLD_ABSOLUTE = /^(?:Bash\(node '\/.*\/scripts\/gh_api_read\.mts' \*\)|Bash\('?.*\/scripts\/gh_token_env\.sh'? -- nen .+\))$/;
const LEGACY_WRAPPERS = [`Bash(${WRAPPER} -- nen `, `Bash(./${WRAPPER} -- nen `];

function unknownLegacyAllow(row: string): boolean {
  const cache = join(dirname(userSettingsPath()), 'plugins/cache/hatsu/hatsu');
  return LEGACY_ALLOW.has(row) || LEGACY_WRAPPERS.some((prefix) => row.startsWith(prefix)) ||
    (OLD_ABSOLUTE.test(row) && row.includes(`${cache}/`));
}

// A row's location and executable identify it without logging private arguments.
function foreignName(kind: 'allow' | 'deny' | 'ask', row: string, index: number): string {
  const command = /^(Bash|PowerShell)\(([\w./-]+)(?:[ :)]|$)/.exec(row);
  const tool = /^[A-Za-z][\w.-]{0,32}(?=\(|$)/.exec(row)?.[0];
  const name = command ? `${command[1]} ${command[2].split('/').at(-1)}` : tool ?? 'unrecognized rule';
  return `permissions.${kind}[${index}] (${name})`;
}

function ownedRows(comment: unknown) {
  if (comment !== undefined && typeof comment !== 'string') throw new Error('settings $comment is not a string');
  const marker = comment?.lastIndexOf(OWNERSHIP) ?? -1;
  const empty = { allow: [] as string[], deny: [] as string[] };
  if (comment === undefined || marker < 0) return { comment, ...empty, ambiguous: empty };
  const rows: unknown = JSON.parse(comment.slice(marker + OWNERSHIP.length));
  if (!object(rows)) throw new Error('invalid Hatsu checkout pack ownership');
  const ambiguous = rows.ambiguous === undefined ? {} : rows.ambiguous;
  if (!object(ambiguous)) throw new Error('invalid ambiguous Hatsu checkout pack ownership');
  return {
    comment: comment.slice(0, marker),
    allow: strings(rows.allow, 'owned allow'),
    deny: strings(rows.deny, 'owned deny'),
    ambiguous: {
      allow: strings(ambiguous.allow, 'ambiguous allow'),
      deny: strings(ambiguous.deny, 'ambiguous deny'),
    },
  };
}

export function mergePack(current: unknown, pack: unknown, marker: string) {
  if (!object(current)) throw new Error('settings top level is not an object');
  const rules = permissionRules(current);
  const existing = object(current.permissions) ? current.permissions : {};
  if (!object(pack) || !object(pack.permissions)) throw new Error('rendered pack lacks permissions');
  const incoming = permissionRules(pack);
  const owned = ownedRows(current.$comment);
  const retired: string[] = [];
  const retained: string[] = [];
  const unknown: string[] = [];
  const nextOwned = { allow: [] as string[], deny: [] as string[], ambiguous: { allow: [] as string[], deny: [] as string[] } };
  const permissions = { ...existing, allow: [] as string[], deny: [] as string[] };
  for (const kind of ['allow', 'deny'] as const) {
    const counts = new Map<string, number>();
    for (const row of rules[kind]) counts.set(row, (counts.get(row) ?? 0) + 1);
    const expected = new Set(incoming[kind]);
    const previous = new Set(owned[kind]);
    const previousAmbiguous = new Set(owned.ambiguous[kind]);
    const ambiguousRows = new Set<string>();
    for (const [index, row] of rules[kind].entries()) {
      const ambiguous = previousAmbiguous.has(row) || (previous.has(row) && counts.get(row) !== 1);
      const isOwned = previous.has(row) && !ambiguous;
      const description = foreignName(kind, row, index);
      if (isOwned && !expected.has(row)) {
        retired.push(description);
        continue;
      }
      permissions[kind].push(row);
      if (isOwned) {
        nextOwned[kind].push(row);
      } else {
        retained.push(description);
        // Once duplicate entries obscure provenance, even one remaining copy is ambiguous.
        if (ambiguous) ambiguousRows.add(row);
        if (!expected.has(row) && (ambiguous || (kind === 'allow' && unknownLegacyAllow(row)))) {
          unknown.push(description);
        }
      }
    }
    for (const row of expected) {
      if (!counts.has(row)) {
        permissions[kind].push(row);
        nextOwned[kind].push(row);
      }
    }
    nextOwned.ambiguous[kind] = [...ambiguousRows];
  }
  rules.ask.forEach((row, index) => retained.push(foreignName('ask', row, index)));
  return {
    document: { ...current, $comment: (owned.comment ?? marker) + OWNERSHIP + JSON.stringify(nextOwned), permissions },
    retired,
    retained,
    unknown,
  };
}

export function diagnoseCheckoutPack(source: PermissionSource, root: string, repo: string) {
  const path = join(repo, CLAUDE_LOCAL);
  try {
    if (lstatSync(dirname(path), { throwIfNoEntry: false })?.isSymbolicLink()) {
      return { status: 'blocked', detail: `${CLAUDE_LOCAL} is under a symbolic link` };
    }
  } catch {
    return { status: 'blocked', detail: `${CLAUDE_LOCAL} directory could not be inspected` };
  }
  const settings = readSettings(path);
  if (settings.state === 'unreadable') return { status: 'blocked', detail: `${CLAUDE_LOCAL} is unreadable or is not a regular file` };
  const expected = checkoutPack(source, root, '');
  const tracked = spawnSync('git', ['-C', repo, 'ls-files', '--error-unmatch', '--', CLAUDE_LOCAL], { stdio: 'ignore' }).status === 0;
  const trackedBlock = (reason: string) => ({ status: 'blocked', detail: `${CLAUDE_LOCAL} is tracked and needs a maintainer edit (${reason})` });
  if (settings.state === 'absent') return tracked ? trackedBlock('absent from the working tree') : { status: 'missing', detail: `${CLAUDE_LOCAL} is absent` };
  let merged: ReturnType<typeof mergePack>;
  try {
    merged = mergePack(settings.document, expected, '');
  } catch {
    return { status: 'blocked', detail: `${CLAUDE_LOCAL} has unreadable Hatsu checkout pack ownership` };
  }
  const missing = expected.permissions.allow.filter((row) => !settings.rules.allow.includes(row)).length +
    expected.permissions.deny.filter((row) => !settings.rules.deny.includes(row)).length;
  if (tracked && (merged.retired.length || missing)) return trackedBlock(`${missing} missing, ${merged.retired.length} retired pack rows`);
  if (merged.retired.length) return { status: 'retired', detail: `retired Claude pack rows: ${merged.retired.join(', ')}` };
  if (missing) return { status: 'missing', detail: `${CLAUDE_LOCAL} lacks ${missing} checkout pack rows` };
  if (merged.unknown.length) return { status: 'blocked', detail: `Claude legacy or duplicate rows with unknown ownership need a maintainer review: ${merged.unknown.join(', ')}` };
  return { status: 'present', detail: `${CLAUDE_LOCAL} carries the current Claude pack` };
}
