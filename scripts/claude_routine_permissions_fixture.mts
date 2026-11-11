import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmodSync, copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, statSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { delimiter, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { bashPattern, matchPermissions, permissionRules, readSettings } from './claude_permissions.mts';
import { CLAUDE_LOCAL, checkoutPack, diagnoseUser, permissionSource, readRegistry, registeredRepositories, routineForms, shellWord, userProposal, WRAPPER } from './claude_routine_permissions.mts';
import { diagnoseCheckoutPack, mergePack } from './claude_pack_placement.mts';
import { checkHookInput, checkRoutineWrite, verifyWrapper } from './claude_routine_write_guard.mts';

type Test = (name: string, body: () => void) => unknown;
const root = realpathSync(fileURLToPath(new URL('..', import.meta.url)));
const sourcePath = join(root, 'contracts/permissions.json');
const source = permissionSource(sourcePath);
const retired = ['Bash(gh api *)', 'Bash(node */scripts/gh_api_read.mts *)'];
const bare = 'nen pr threads resolve --target example/project --pr 1 --thread ID';
const wrappers = ['', './scripts/gh_token_env.sh -- ', 'scripts/gh_token_env.sh -- ', `${shellWord(join(root, WRAPPER))} -- `];
const intended = ['pr threads reply', 'pr threads resolve', 'pr threads settle', 'pr open', 'pr edit-body', 'pr request-reviews', 'issue comment', 'pr ledger post', 'issue file'];
const output = (result: ReturnType<typeof run>) => `${result.stdout}${result.stderr}`;
const data = (path: string, value: unknown) => writeFileSync(path, JSON.stringify(value));
function run(command: string, args: string[], cwd: string, env: NodeJS.ProcessEnv, input?: string) {
  return spawnSync(command, args, { cwd, env, input, encoding: 'utf8', timeout: 15_000 });
}
function fixture(body: (dir: string) => void) {
  const dir = mkdtempSync(join(realpathSync(tmpdir()), 'hatsu-routine-'));
  try { body(dir); } finally { rmSync(dir, { recursive: true, force: true }); }
}

export function cases(test: Test) {
  test('catalogue renders exactly the narrow write prefixes in all four spellings', () => {
    const forms = routineForms(source, root);
    const proposal = userProposal(source, root, [
      { maintained_tools: [{ repo: 'example/tool' }], pending_onboarding: ['example/next'] },
      { consumers: [{ repo: 'example/consumer' }, { repo: 'example/tool' }] },
    ]);
    assert.equal(forms.length, intended.length * wrappers.length);
    for (const verb of intended) for (const wrapper of wrappers) {
      assert.ok(proposal.permissions.allow.includes(`Bash(${wrapper}nen ${verb} *)`), verb);
    }
    assert.ok(proposal.permissions.allow.every((row) => !retired.includes(row) && !['Bash', 'Bash(nen *)', 'Bash(node *)'].includes(row)));
    assert.deepEqual(proposal.autoMode.environment, ['$defaults', 'Trusted repo: github.com/example/consumer', 'Trusted repo: github.com/example/next', 'Trusted repo: github.com/example/tool']);
    assert.equal(proposal.autoMode.allow[0], '$defaults');
    assert.equal(proposal.permissions.allow.length, forms.length + source.claude_user_bounded_allow.length);
    assert.throws(() => registeredRepositories({ consumers: [{ repo: 'foo/bar\nTrust all' }] }));
    assert.throws(() => registeredRepositories({ consumers: {} }));
    assert.throws(() => registeredRepositories({ consumers: [{ repo: '../tool' }] }));
    assert.throws(() => registeredRepositories([]));
    assert.equal(shellWord("/a b'c"), "'/a b'\\''c'");
  });

  test('rejects malformed source and refuses unverifiable installed paths', () => fixture((dir) => {
    const path = join(dir, 'permissions.json');
    const document = JSON.parse(readFileSync(sourcePath, 'utf8'));
    for (const patch of [
      { claude_code_api_reader: 'other' },
      { claude_routine_writes: [] },
      { claude_routine_writes: [document.claude_routine_writes[0], document.claude_routine_writes[0]] },
      { allow: [{ exe: 'nen' }] },
      { claude_user_bounded_allow: ['unrelated verb'] },
      { claude_user_bounded_allow: ['*'] },
    ]) {
      data(path, { ...document, ...patch });
      assert.throws(() => permissionSource(path));
    }
    assert.throws(() => readRegistry(join(dir, 'absent')));
    mkdirSync(join(dir, 'space here', 'scripts'), { recursive: true });
    const target = join(dir, 'space here');
    const script = join(target, WRAPPER);
    symlinkSync(join(root, WRAPPER), script);
    assert.throws(() => routineForms(source, target), /safe installed file/);
    rmSync(script);
    copyFileSync(join(root, WRAPPER), script);
    chmodSync(script, 0o700);
    assert.ok(routineForms(source, target).some(({ rule }) => rule.startsWith(`Bash('${script}' -- nen`)));
  }));

  test('checks literal Bash rules and validates malformed permissions', () => fixture((dir) => {
    for (const prefix of ['Bash(nen pr *)', 'Bash(nen pr:*)']) {
      assert.equal(bashPattern(prefix)?.test('nen pr'), true);
      assert.equal(bashPattern(prefix)?.test('nen pr open'), true);
      assert.equal(bashPattern(prefix)?.test('nen provoke'), false);
    }
    assert.equal(bashPattern('Bash(npm * --help *)')?.test('npm test --help'), false);
    assert.equal(bashPattern('Bash(node a[1] *)')?.test('node a[1] x'), true);
    assert.equal(bashPattern('Read(./**)'), null);
    const rules = permissionRules({ permissions: { allow: ['Bash'], ask: ['Bash(nen pr *)'], deny: ['Bash(nen pr open *)'] } });
    assert.equal(matchPermissions('nen pr open X', rules).verdict, 'denied');
    assert.equal(matchPermissions(bare, rules).verdict, 'asks');
    assert.equal(matchPermissions('echo OK', rules).verdict, 'allowed');
    assert.equal(matchPermissions('echo OK', permissionRules({})).verdict, 'not-pre-allowed');
    const file = join(dir, 'settings.json');
    assert.equal(readSettings(file).state, 'absent');
    for (const value of [null, [], { permissions: null }, { permissions: { allow: false } }, { permissions: { ask: [true] } }]) {
      data(file, value);
      assert.equal(readSettings(file).state, 'unreadable');
    }
    writeFileSync(file, '{BROKEN');
    assert.equal(readSettings(file).state, 'unreadable');
    symlinkSync(file, join(dir, 'symlink.json'));
    assert.equal(readSettings(join(dir, 'symlink.json')).state, 'unreadable');
  }));

  test('detects removal, visible overrides and unknown effective host policy', () => fixture((dir) => {
    const user = join(dir, 'user.json');
    const project = join(dir, 'project.json');
    const check = () => diagnoseUser(source, root, readSettings(user), [readSettings(project)]);
    const proposed = userProposal(source, root, []);
    assert.equal(check().missing?.length, intended.length * wrappers.length);
    data(user, proposed);
    assert.deepEqual(check().missing, []);
    assert.equal(check().effective, 'unknown');
    data(user, { permissions: { deny: ['Bash(nen pr open *)'] }, autoMode: { classifyAllShell: true } });
    data(project, { permissions: { ask: ['Bash(nen pr threads *)'] } });
    const removed = check();
    assert.equal(removed.missing?.length, intended.length * wrappers.length);
    assert.deepEqual(removed.overrides, ['user autoMode.classifyAllShell', `deny in ${user}`, `ask in ${project}`]);
    writeFileSync(user, '{bad');
    writeFileSync(project, '{bad');
    const unreadable = check();
    assert.equal(unreadable.missing, null);
    assert.deepEqual(unreadable.unreadable, [user, project]);
  }));

  test('retirement owns exact legacy and prior Hatsu cache rows, preserving foreign bytes', () => fixture((dir) => {
    const cacheRoot = join(dir, 'plugins/cache/hatsu/hatsu');
    const old = `Bash(node '${cacheRoot}/0.160.0/scripts/gh_api_read.mts' *)`;
    const foreign = `Bash(node '${dir}/unrelated/scripts/gh_api_read.mts' *)`;
    const privateArg = 'Bash(echo private-text)';
    const current = { other: { preserved: true }, $comment: 'maintainer', permissions: {
      allow: [...retired, old, foreign, privateArg, privateArg], deny: ['Bash(echo denied)'], ask: ['Bash(echo asked)'],
    } };
    const pack = checkoutPack(source, root, 'test');
    const result = mergePack(current, pack, 'test', cacheRoot);
    assert.deepEqual(result.retired, [...retired, old]);
    assert.deepEqual(result.retained, ['permissions.allow[3] (Bash node)', 'permissions.allow[4] (Bash echo)', 'permissions.allow[5] (Bash echo)', 'permissions.deny[0] (Bash echo)', 'permissions.ask[0] (Bash echo)']);
    assert.deepEqual((result.document.permissions as typeof current.permissions).allow.slice(0, 3), [foreign, privateArg, privateArg]);
    assert.deepEqual(result.document.other, current.other);
    assert.equal(result.document.$comment, 'maintainer');
    assert.deepEqual(mergePack(result.document, pack, 'test', cacheRoot).document, result.document);
    assert.throws(() => mergePack(null, pack, 'test', cacheRoot));
    assert.throws(() => mergePack({}, {}, 'test', cacheRoot));
    const settings = join(dir, CLAUDE_LOCAL);
    const diagnose = () => diagnoseCheckoutPack(source, root, dir, cacheRoot).status;
    assert.equal(diagnose(), 'missing');
    mkdirSync(join(dir, '.claude'));
    data(settings, current);
    assert.equal(diagnose(), 'retired');
    data(settings, { permissions: { allow: [] } });
    assert.equal(diagnose(), 'missing');
    data(settings, result.document);
    assert.equal(diagnose(), 'present');
    writeFileSync(settings, '{bad');
    assert.equal(diagnose(), 'blocked');
    rmSync(join(dir, '.claude'), { recursive: true });
    mkdirSync(join(dir, 'foreign'));
    symlinkSync(join(dir, 'foreign'), join(dir, '.claude'));
    assert.equal(diagnose(), 'blocked');
  }));

  test('lone-call guard refuses executable shell structure and accepts quoted data', () => {
    for (const wrapper of wrappers) assert.equal(checkRoutineWrite(wrapper + bare, source).refusal, null);
    for (const command of [
      `${bare} | tail`, `${bare} |& tail`, `${bare}; echo x`, `true && ${bare}`, `true || ${bare}`,
      `true\n${bare}`, `${bare} &`, `${bare} >out`, `${bare} "$(echo x)"`, `${bare} \`echo x\``,
      `echo "$(${bare})"`, `echo \`${bare}\``, `bash -c '${bare}'`, `env X=y ${bare}`,
      `cat <<'EOF' >payload\nbody\nEOF\n${bare}`, `${bare} <<EOF\nbody\nEOF`, `(${bare})`,
      `./${WRAPPER} nen pr threads resolve --pr 1`, `nen  pr threads resolve --pr 1`,
    ]) assert.match(checkRoutineWrite(command, source).refusal ?? '', /one plain Nen write call/, command);
    for (const command of [
      `${bare} --body-file 'a ; | && || & $(literal).md'`, `${bare} --body-file "a ; | && || &.md"`,
      `echo '${bare}; false'`, `cat <<'EOF'\n${bare}\nEOF`, 'nen pr threads list --pr 1 | head', 'git status && git diff',
    ]) assert.equal(checkRoutineWrite(command, source).refusal, null, command);
  });

  test('verifies the token wrapper before relying on its string rule', () => fixture((dir) => {
    mkdirSync(join(dir, 'scripts'));
    const candidate = join(dir, WRAPPER);
    const payload = { tool_name: 'Bash', tool_input: { command: wrappers[1] + bare }, cwd: dir };
    assert.equal(verifyWrapper(WRAPPER, dir, root), false);
    assert.match(checkHookInput(payload, root) ?? '', /could not be verified/);
    symlinkSync(join(root, WRAPPER), candidate);
    assert.equal(verifyWrapper(WRAPPER, dir, root), false);
    rmSync(candidate);
    writeFileSync(candidate, '#!/bin/sh\ntrue\n', { mode: 0o700 });
    assert.equal(verifyWrapper(WRAPPER, dir, root), false);
    copyFileSync(join(root, WRAPPER), candidate);
    chmodSync(candidate, 0o700);
    assert.equal(verifyWrapper(WRAPPER, dir, root), true);
    assert.equal(checkHookInput(payload, root), null);
    assert.equal(checkHookInput({ ...payload, tool_name: 'Read' }, root), null);
    assert.equal(checkHookInput(null, root), null);
  }));

  test('entry points are hermetic and observe repeated user-setting removal', () => fixture((dir) => {
    const home = join(dir, 'home');
    const repo = join(dir, 'repo');
    const config = join(home, 'custom claude');
    const user = join(config, 'settings.json');
    mkdirSync(config, { recursive: true });
    mkdirSync(join(repo, 'nen'), { recursive: true });
    data(join(repo, 'nen', 'workflow.json'), {});
    data(join(repo, 'nen', 'repos.json'), { consumers: [{ repo: 'example/project' }] });
    const bin = join(dir, 'bin');
    mkdirSync(bin);
    writeFileSync(join(bin, 'gh'), '#!/bin/sh\nexit 1\n', { mode: 0o700 });
    const env = { ...process.env, HOME: home, CLAUDE_CONFIG_DIR: config, CLAUDE_PLUGIN_ROOT: root,
      GH_TOKEN: '', GITHUB_TOKEN: '', PATH: [bin, process.env.PATH].join(delimiter),
      GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: '/dev/null' };
    const git = run('git', ['init', '-q', repo], dir, env);
    assert.equal(git.status, 0, output(git));
    const pack = (...args: string[]) => run('bash', [join(root, 'scripts/permissions_pack.sh'), '--surface', 'claude-code', ...args, '--target', repo], dir, env);
    const tenkaiEntry = join(root, 'scripts/tenkai_adopt.sh');
    const adoption = ['--repo', repo, '--slug', 'example/project', '--visibility', 'private', '--self-hosted', '0'];
    const tenkai = (...args: string[]) => run('bash', [tenkaiEntry, 'diagnose', ...adoption, ...args, '--json'], dir, env);
    const tenkaiPack = (surface: string, expectedState: string, expectedPack: string) => {
      const result = tenkai('--surface', surface);
      assert.ok([0, 1].includes(result.status ?? -1), output(result));
      const report = JSON.parse(result.stdout);
      const row = report.items.find((item: { id: string }) => item.id === 'permissions/claude-code');
      assert.equal(row?.state, expectedState, output(result));
      assert.equal(row?.packStatus, expectedPack);
      if (['missing', 'drift'].includes(row.state)) assert.match(row.fix.run[0], /permissions_pack.sh.*--install/);
    };
    tenkaiPack('claude-code', 'missing', 'missing');
    tenkaiPack('codex', 'advisory', 'missing');
    assert.equal(tenkai('--surface', 'invalid').status, 2);
    const textDiagnosis = run('bash', [tenkaiEntry, 'diagnose', ...adoption, '--surface', 'claude-code'], dir, env);
    assert.equal(textDiagnosis.status, 1, output(textDiagnosis));
    assert.match(textDiagnosis.stdout, /MISS  permissions\/claude-code/);
    assert.match(textDiagnosis.stdout, /permissions_pack.sh.*--install/);
    const runner = run('bash', [tenkaiEntry, 'runner-policy', '--visibility', 'private', '--self-hosted', '0'], dir, env);
    assert.equal(runner.status, 0, output(runner));
    const invalidRenderer = run(process.execPath, [join(root, 'scripts/permissions_pack_claude_render.mts')], dir, env);
    assert.equal(invalidRenderer.status, 2);
    assert.match(invalidRenderer.stderr, /expected permissions source/);
    let result = pack('--check-user');
    assert.equal(result.status, 0, output(result));
    assert.match(result.stdout, /routine user rows missing.*effective managed\/session policy unknown.*--render-user/);
    assert.equal(result.stdout.trim().split('\n').length, 1);
    assert.equal(existsSync(user), false);
    result = pack('--render-user');
    assert.equal(result.status, 0, output(result));
    assert.equal(existsSync(user), false);
    const proposed = JSON.parse(result.stdout);
    assert.ok(proposed.autoMode.environment.includes('Trusted repo: github.com/example/project'));
    data(user, proposed);
    assert.match(pack('--check-user').stdout, /routine user rows present/);
    const updated = { permissions: { deny: ['Bash(nen pr open *)'] }, autoMode: { classifyAllShell: true } };
    data(user, updated);
    result = pack('--check-user');
    assert.match(result.stdout, /routine user rows missing.*classifyAllShell.*deny in/);
    assert.deepEqual(JSON.parse(readFileSync(user, 'utf8')), updated);
    result = pack('--render-user', '--install');
    assert.equal(result.status, 2, output(result));
    assert.equal(existsSync(join(repo, CLAUDE_LOCAL)), false);
    assert.equal(pack('--install').status, 0);
    const local = join(repo, CLAUDE_LOCAL);
    assert.equal(statSync(local).mode & 0o777, 0o600);
    const document = JSON.parse(readFileSync(local, 'utf8'));
    document.permissions.allow.push(...retired, 'Bash(echo private-text)');
    data(local, document);
    tenkaiPack('claude-code', 'drift', 'retired');
    chmodSync(local, 0o640);
    result = pack('--install');
    assert.equal(result.status, 0, output(result));
    assert.match(result.stdout, /removed retired allow/);
    assert.match(result.stdout, /kept foreign permissions.allow\[\d+\] \(Bash echo\)/);
    assert.doesNotMatch(result.stdout, /private-text/);
    assert.equal(statSync(local).mode & 0o777, 0o640);
    assert.equal(diagnoseCheckoutPack(source, root, repo).status, 'present');
    tenkaiPack('claude-code', 'satisfied', 'present');
    assert.deepEqual(JSON.parse(readFileSync(user, 'utf8')), updated);
    const stable = readFileSync(local);
    assert.equal(pack('--install').status, 0);
    assert.deepEqual(readFileSync(local), stable);
    const add = run('git', ['add', '-f', CLAUDE_LOCAL], repo, env);
    assert.equal(add.status, 0, output(add));
    assert.match(pack('--install').stdout, /left alone.*settings.local.json/);
    assert.deepEqual(readFileSync(local), stable);
    const wrongDestination = run(process.execPath, [join(root, 'scripts/permissions_pack_claude_merge.mts'), user,
      JSON.stringify(checkoutPack(source, root, 'fixture')), 'fixture'], dir, env);
    assert.equal(wrongDestination.status, 3);
    assert.match(wrongDestination.stderr, /only checkout/);
    assert.deepEqual(JSON.parse(readFileSync(user, 'utf8')), updated);

    const hook = run('sh', [join(root, 'hooks/guard-base-branch.sh')], root, env,
      JSON.stringify({ tool_name: 'Bash', tool_input: { command: `${bare} | tail` }, cwd: root }));
    assert.equal(hook.status, 2, output(hook));
    assert.match(hook.stderr, /one plain Nen write call/);
    const encoded = JSON.stringify({ tool_name: 'Bash', tool_input: { command: `${bare} | tail` }, cwd: root })
      .replace('nen pr', String.raw`\u006e\u0065\u006e pr`);
    const encodedHook = run('sh', [join(root, 'hooks/guard-base-branch.sh')], root, env, encoded);
    assert.equal(encodedHook.status, 2, output(encodedHook));
    assert.match(encodedHook.stderr, /one plain Nen write call/);
    const idle = run(process.execPath, [join(root, 'scripts/idle_permissions_check.mts'), '--repo', repo, '--json'], dir, env);
    assert.ok([0, 1].includes(idle.status ?? -1), output(idle));
    const exemplars = JSON.parse(idle.stdout).rows.map((row: { command: string }) => row.command);
    for (const verb of intended) assert.equal(exemplars.filter((command: string) => command.startsWith(`nen ${verb} `)).length, 1, verb);
    const needs = join(dir, 'word-boundary.json');
    const permissions = join(dir, 'word-boundary-settings.json');
    data(needs, { contract: 'hatsu.idle-permissions/v0.1', needs: ['nen provoke', 'nen pr', 'nen pr open'].map((command) => ({ command, by: 'boundary' })) });
    data(permissions, { permissions: { allow: ['Bash(nen pr:*)'] } });
    const boundary = run(process.execPath, [join(root, 'scripts/idle_permissions_check.mts'), '--needs', needs, '--settings', permissions, '--json'], dir, env);
    assert.equal(boundary.status, 1, output(boundary));
    assert.deepEqual(JSON.parse(boundary.stdout).rows.map((row: { verdict: string }) => row.verdict), ['not-pre-allowed', 'allowed', 'allowed']);

    const applied = run('bash', [tenkaiEntry, 'apply', ...adoption, '--surface', 'claude-code', '--json'], dir, env);
    assert.ok([0, 1].includes(applied.status ?? -1), output(applied));
    const appliedPack = JSON.parse(applied.stdout).items.find((row: { id: string }) => row.id === 'permissions/claude-code');
    assert.equal(appliedPack?.packStatus, 'present');
    assert.deepEqual(JSON.parse(readFileSync(user, 'utf8')), updated);
  }));
}
