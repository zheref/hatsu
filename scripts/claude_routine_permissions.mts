import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { constants, accessSync, readFileSync, realpathSync, statSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, resolve } from 'node:path';
import { type Settings, matchPermissions, object, sampleCommand, strings } from './claude_permissions.mts';

export const WRAPPER = 'scripts/gh_token_env.sh';
export const CLAUDE_LOCAL = '.claude/settings.local.json';
const API_READER = 'scripts/gh_api_read.mts';
const REPO_SLUG = /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/;
const BOUNDED_WRITE = /^(?:shu release --repo \* --lane plugin(?: --dry-run)?|pr merge \* --delivery --requirements-from \* --repo \* --require-head \* --run)$/;
const SAFE_WORD = /^[\w@%+=:,./-]+$/;
const AUTO_ALLOW = 'Allow Hatsu routine Nen writes to an already authorized pull request or issue in the working repository or one of the named Hatsu repositories. The agent prepares and reviews payload files separately and runs one Nen write per Bash call.';

type SharedRow = { exe: string; args: string };
type RoutineWrite = { prefix: string; command: string; by: string };
export type PermissionSource = {
  allow: SharedRow[]; deny: SharedRow[];
  claude_routine_writes: RoutineWrite[];
  claude_user_bounded_allow: string[];
};

function commandRows(value: unknown, name: string): SharedRow[] {
  if (!Array.isArray(value) || !value.every((row) =>
    object(row) && typeof row.exe === 'string' && typeof row.args === 'string')) {
    throw new Error(`${name} is not an array of command rows`);
  }
  return value as SharedRow[];
}

export function permissionSource(path: string): PermissionSource {
  const doc: unknown = JSON.parse(readFileSync(path, 'utf8'));
  if (!object(doc) || doc.claude_code_api_reader !== API_READER) {
    throw new Error('Claude API reader must name the audited entrypoint');
  }
  const routine = doc.claude_routine_writes;
  if (!Array.isArray(routine) || !routine.length || !routine.every((row) =>
    object(row) && typeof row.prefix === 'string' && /^nen(?: [a-z][a-z-]+){2,3}$/.test(row.prefix) &&
    typeof row.command === 'string' && row.command.startsWith(`${row.prefix} `) && typeof row.by === 'string')) {
    throw new Error('invalid Claude routine write catalogue');
  }
  if (new Set(routine.map((row) => row.prefix)).size !== routine.length) {
    throw new Error('duplicate Claude routine write prefix');
  }
  const allow = commandRows(doc.allow, 'allow');
  const bounded = strings(doc.claude_user_bounded_allow, 'claude_user_bounded_allow');
  if (!bounded.every((args) => BOUNDED_WRITE.test(args) && allow.some((row) => row.exe === 'nen' && row.args === args))) {
    throw new Error('bounded Claude user row must reference a shared Nen row');
  }
  return {
    allow,
    deny: commandRows(doc.deny, 'deny'),
    claude_routine_writes: routine as RoutineWrite[],
    claude_user_bounded_allow: bounded,
  };
}

const singleQuote = (text: string) => `'${text.replaceAll("'", "'\\''")}'`;
export const shellWord = (text: string) => SAFE_WORD.test(text) ? text : singleQuote(text);

export function sessionRoutineRule(prefix: string, installed: string): string {
  return `Bash(${shellWord(installed)} --path * -- ${prefix} *)`;
}

function installedFile(root: string, relative: string): string {
  const expected = join(realpathSync(root), relative);
  if (realpathSync(expected) !== expected || !statSync(expected).isFile() || /[\x00-\x1f\x7f*()]/.test(expected)) {
    throw new Error(`${relative} is not a safe installed file`);
  }
  return expected;
}

export function routineForms(source: PermissionSource, root: string, withSession = false) {
  const installed = installedFile(root, WRAPPER);
  accessSync(installed, constants.X_OK);
  const wrappers = ['', `./${WRAPPER} -- `, `${WRAPPER} -- `, `${shellWord(installed)} -- `];
  const forms = source.claude_routine_writes.flatMap((entry) => wrappers.map((wrapper) => ({
    rule: `Bash(${wrapper}${entry.prefix} *)`,
    command: `${wrapper}${sampleCommand(entry.command)}`,
  })));
  if (withSession) for (const entry of source.claude_routine_writes) {
    const absolute = shellWord(installed);
    forms.push({
      rule: sessionRoutineRule(entry.prefix, installed),
      command: `${absolute} --path /tmp/hatsu-session/bin -- ${sampleCommand(entry.command)}`,
    });
  }
  return forms;
}

export function checkoutPack(source: PermissionSource, root: string, marker: string) {
  return {
    $comment: `${marker}. Bash rules match command text. Settings placement is local to the checkout.`,
    permissions: {
      allow: [...new Set([
        ...source.allow.map(({ exe, args }) => `Bash(${exe} ${args})`),
        ...routineForms(source, root).filter(({ rule }) =>
          !rule.startsWith(`Bash(./${WRAPPER} `) && !rule.startsWith(`Bash(${WRAPPER} `)).map(({ rule }) => rule),
        `Bash(node ${singleQuote(installedFile(root, API_READER))} *)`,
      ])],
      deny: source.deny.map(({ exe, args }) => `Bash(${exe} ${args})`),
    },
  };
}

export function registeredRepositories(registry: unknown): string[] {
  if (!object(registry)) throw new Error('repository registry is not an object');
  const repositories = new Set<string>();
  for (const group of ['consumers', 'maintained_tools', 'pending_onboarding']) {
    const rows = registry[group] ?? [];
    if (!Array.isArray(rows)) throw new Error(`repository registry ${group} is not an array`);
    for (const row of rows) {
      const slug = group === 'pending_onboarding' && typeof row === 'string' ? row : object(row) ? row.repo : undefined;
      if (typeof slug !== 'string' || !REPO_SLUG.test(slug) || slug.split('/').some((part) => part === '.' || part === '..')) {
        throw new Error(`repository registry ${group} has an invalid repository slug`);
      }
      repositories.add(slug);
    }
  }
  return [...repositories].sort();
}

const GUARD = 'scripts/claude_routine_write_guard.mts';
const GUARD_FILES = [GUARD, 'scripts/claude_permissions.mts', 'scripts/claude_routine_permissions.mts',
  WRAPPER, 'contracts/permissions.json', 'nen/contract.json'];
const sha256 = (path: string) => createHash('sha256').update(readFileSync(path)).digest('hex');

// Claude invokes /bin/sh directly with argv. The shell verifies the bytes
// before starting Node, so neither PATH nor a changed checker can return allow.
const verifyHook = `
node=$1; entry=$2; shift 2
unavailable() {
  printf '%s\\n' 'Hatsu routine write: the approved checker binding is unavailable or changed. Review a fresh user proposal from an independent terminal.' >&2
  exit 2
}
while [ "$#" -gt 0 ]; do
  actual=$(/usr/bin/openssl dgst -sha256 "$1") || unavailable
  case "$actual" in
    *" $2") ;;
    *) unavailable ;;
  esac
  shift 2
done
exec /usr/bin/env -u NODE_OPTIONS -u NODE_PATH "$node" "$entry"
`;

export function userHook(root: string) {
  const runtime = realpathSync(process.execPath);
  const bindings = [runtime, ...GUARD_FILES.map((file) => installedFile(root, file))];
  return {
    type: 'command',
    command: '/bin/sh',
    args: ['-c', verifyHook, 'hatsu-routine-check', runtime, installedFile(root, GUARD),
      ...bindings.flatMap((path) => [path, sha256(path)])],
    onFailure: 'block',
    timeout: 10,
    statusMessage: 'Checking Hatsu routine writes',
  };
}

export function preflightUserHook(root: string, source: PermissionSource, platform = process.platform, bind = userHook) {
  if (platform !== 'darwin' && platform !== 'linux') {
    return { problem: `unsupported paired hook host (${platform}); use macOS or Linux` } as const;
  }
  try {
    const hook = bind(root);
    // The hook only parses this inert stdin payload. No shell command in the payload is executed.
    const command = `${sampleCommand(source.claude_routine_writes[0].command)} | :`;
    const input = JSON.stringify({ tool_name: 'Bash', cwd: root, tool_input: { command } });
    const result = spawnSync(hook.command, hook.args, { cwd: root, input, encoding: 'utf8', timeout: hook.timeout * 1000 });
    if (result.status === 2 && result.stderr.includes('one plain Nen write call')) return { hook } as const;
  } catch {
    // Binding failures and launch failures both withhold the proposal.
  }
  return { problem: 'paired hook host preflight failed; check /bin/sh, /usr/bin/openssl, /usr/bin/env and the trusted Hatsu Node binding' } as const;
}

export function userProposal(source: PermissionSource, root: string, registry: unknown, hook = userHook(root)) {
  const repositories = registeredRepositories(registry);
  return {
    permissions: {
      allow: [...routineForms(source, root, true).map(({ rule }) => rule),
        ...source.claude_user_bounded_allow.filter((args) => args.endsWith(' --dry-run') || args.startsWith('pr merge '))
          .map((args) => `Bash(nen ${args})`)],
    },
    hooks: { PreToolUse: [{ matcher: 'Bash', hooks: [hook] }] },
    autoMode: {
      allow: ['$defaults', AUTO_ALLOW],
      environment: ['$defaults', ...repositories.map((repo) => `Trusted repo: github.com/${repo}`)],
    },
  };
}

export function releaseOptIn(source: PermissionSource, target: string) {
  const row = source.claude_user_bounded_allow.find((args) => args === 'shu release --repo * --lane plugin');
  if (!row || /[\x00-\x1f\x7f*()]/.test(target)) throw new Error('no safe Hatsu plugin publisher permission for that path');
  return { permissions: { allow: [`Bash(nen ${row.replace('*', () => shellWord(target))})`] } };
}

export const userSettingsPath = () => resolve(process.env.CLAUDE_CONFIG_DIR || join(homedir(), '.claude'), 'settings.json');

export function diagnoseUser(source: PermissionSource, root: string, user: Settings, project: Settings[], expectedHook = userHook(root)) {
  const forms = routineForms(source, root, true);
  const present = user.state === 'read' ? new Set(user.rules.allow) : new Set<string>();
  const missing = user.state === 'unreadable' ? null : forms.filter(({ rule }) => !present.has(rule)).map(({ rule }) => rule);
  const overrides: string[] = [];
  const preToolUse = user.state === 'read' && object(user.document.hooks) ? user.document.hooks.PreToolUse : null;
  const boundHook = Array.isArray(preToolUse) && preToolUse.some((row) =>
    object(row) && row.matcher === 'Bash' && Array.isArray(row.hooks) && row.hooks.some((handler) =>
      object(handler) && handler.if === undefined && handler.async !== true &&
      handler.command === expectedHook.command && handler.type === expectedHook.type &&
      handler.onFailure === 'block' && JSON.stringify(handler.args) === JSON.stringify(expectedHook.args)));
  const userAutoMode = user.state === 'read' && object(user.document.autoMode) ? user.document.autoMode : {};
  if (userAutoMode.classifyAllShell === true) overrides.push('user autoMode.classifyAllShell');
  for (const settings of [user, ...project]) {
    if (settings.state !== 'read') continue;
    if (settings.document.disableAllHooks === true) overrides.push(`disableAllHooks in ${settings.path}`);
    const verdicts = forms.map(({ command }) => matchPermissions(command, settings.rules).verdict);
    if (verdicts.includes('denied')) overrides.push(`deny in ${settings.path}`);
    if (verdicts.includes('asks')) overrides.push(`ask in ${settings.path}`);
  }
  return {
    user: user.state,
    missing,
    boundHook,
    overrides,
    unreadable: [user, ...project].filter((settings) => settings.state === 'unreadable').map(({ path }) => path),
    effective: 'unknown' as const,
  };
}

export function readRegistry(path: string): unknown {
  try {
    return JSON.parse(readFileSync(path, 'utf8'));
  } catch {
    throw new Error(`could not read repository registry ${path}`);
  }
}
