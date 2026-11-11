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

function installedFile(root: string, relative: string): string {
  const expected = join(realpathSync(root), relative);
  if (realpathSync(expected) !== expected || !statSync(expected).isFile() || /[\x00-\x1f\x7f*()]/.test(expected)) {
    throw new Error(`${relative} is not a safe installed file`);
  }
  return expected;
}

export function routineForms(source: PermissionSource, root: string) {
  const installed = installedFile(root, WRAPPER);
  accessSync(installed, constants.X_OK);
  const wrappers = ['', `./${WRAPPER} -- `, `${WRAPPER} -- `, `${shellWord(installed)} -- `];
  return source.claude_routine_writes.flatMap((entry) => wrappers.map((wrapper) => ({
    rule: `Bash(${wrapper}${entry.prefix} *)`,
    command: `${wrapper}${sampleCommand(entry.command)}`,
  })));
}

export function checkoutPack(source: PermissionSource, root: string, marker: string) {
  return {
    $comment: `${marker}. Bash rules match command text. Settings placement is local to the checkout.`,
    permissions: {
      allow: [...new Set([
        ...source.allow.map(({ exe, args }) => `Bash(${exe} ${args})`),
        ...routineForms(source, root).map(({ rule }) => rule),
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

export function userProposal(source: PermissionSource, root: string, registries: unknown[]) {
  const repositories = [...new Set(registries.flatMap(registeredRepositories))].sort();
  return {
    permissions: {
      allow: [...routineForms(source, root).map(({ rule }) => rule),
        ...source.claude_user_bounded_allow.map((args) => `Bash(nen ${args})`)],
    },
    autoMode: {
      allow: ['$defaults', AUTO_ALLOW],
      environment: ['$defaults', ...repositories.map((repo) => `Trusted repo: github.com/${repo}`)],
    },
  };
}

export const userSettingsPath = () => resolve(process.env.CLAUDE_CONFIG_DIR || join(homedir(), '.claude'), 'settings.json');

export function diagnoseUser(source: PermissionSource, root: string, user: Settings, project: Settings[]) {
  const forms = routineForms(source, root);
  const present = user.state === 'read' ? new Set(user.rules.allow) : new Set<string>();
  const missing = user.state === 'unreadable' ? null : forms.filter(({ rule }) => !present.has(rule)).map(({ rule }) => rule);
  const overrides: string[] = [];
  const userAutoMode = user.state === 'read' && object(user.document.autoMode) ? user.document.autoMode : {};
  if (userAutoMode.classifyAllShell === true) overrides.push('user autoMode.classifyAllShell');
  for (const settings of [user, ...project]) {
    if (settings.state !== 'read') continue;
    const verdicts = forms.map(({ command }) => matchPermissions(command, settings.rules).verdict);
    if (verdicts.includes('denied')) overrides.push(`deny in ${settings.path}`);
    if (verdicts.includes('asks')) overrides.push(`ask in ${settings.path}`);
  }
  return {
    user: user.state,
    missing,
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
