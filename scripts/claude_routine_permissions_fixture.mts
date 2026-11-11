import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { chmodSync, copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, statSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { delimiter, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { bashPattern, matchPermissions, permissionRules, readSettings, sampleCommand } from './claude_permissions.mts';
import { CLAUDE_LOCAL, checkoutPack, diagnoseUser, permissionSource, preflightUserHook, readRegistry, registeredRepositories, routineForms, shellWord, userHook, userProposal, WRAPPER } from './claude_routine_permissions.mts';
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
  test('catalogue renders the four ordinary spellings and a verified session form', () => {
    const forms = routineForms(source, root, true);
    const proposal = userProposal(source, root, {
      maintained_tools: [{ repo: 'example/tool' }], pending_onboarding: ['example/next'],
      consumers: [{ repo: 'example/consumer' }, { repo: 'example/tool' }],
    });
    assert.equal(forms.length, intended.length * (wrappers.length + 1));
    for (const verb of intended) for (const wrapper of wrappers) {
      assert.ok(proposal.permissions.allow.includes(`Bash(${wrapper}nen ${verb} *)`), verb);
    }
    assert.ok(proposal.permissions.allow.every((row) => !retired.includes(row) && !['Bash', 'Bash(nen *)', 'Bash(node *)'].includes(row)));
    assert.deepEqual(proposal.autoMode.environment, ['$defaults', 'Trusted repo: github.com/example/consumer', 'Trusted repo: github.com/example/next', 'Trusted repo: github.com/example/tool']);
    assert.equal(proposal.autoMode.allow[0], '$defaults');
    assert.equal(proposal.permissions.allow.length, forms.length + source.claude_user_bounded_allow.length - 1);
    assert.equal(proposal.hooks.PreToolUse[0].hooks[0].onFailure, 'block');
    assert.ok(!proposal.permissions.allow.includes('Bash(nen shu release --repo * --lane plugin)'));
    assert.ok(proposal.permissions.allow.includes('Bash(nen shu release --repo * --lane plugin --dry-run)'));
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
    const proposed = userProposal(source, root, {});
    assert.equal(check().missing?.length, intended.length * (wrappers.length + 1));
    data(user, proposed);
    assert.deepEqual(check().missing, []);
    assert.equal(check().boundHook, true);
    data(user, { ...proposed, hooks: {} });
    assert.equal(check().boundHook, false);
    assert.equal(check().effective, 'unknown');
    data(user, { permissions: { deny: ['Bash(nen pr open *)'] }, autoMode: { classifyAllShell: true } });
    data(project, { permissions: { ask: ['Bash(nen pr threads *)'] } });
    const removed = check();
    assert.equal(removed.missing?.length, intended.length * (wrappers.length + 1));
    assert.deepEqual(removed.overrides, ['user autoMode.classifyAllShell', `deny in ${user}`, `ask in ${project}`]);
    writeFileSync(user, '{bad');
    writeFileSync(project, '{bad');
    const unreadable = check();
    assert.equal(unreadable.missing, null);
    assert.deepEqual(unreadable.unreadable, [user, project]);
  }));

  test('checkout placement records only inserted rows and retires them on a two-version upgrade', () => fixture((dir) => {
    const home = join(dir, 'home');
    const repo = join(dir, 'repo');
    const versions = ['0.160.0', '0.174.0'].map((version) => join(dir, 'plugins/cache/hatsu/hatsu', version));
    const required = ['contracts/permissions.json', WRAPPER, 'scripts/gh_api_read.mts',
      'scripts/claude_pack_placement.mts', 'scripts/claude_permissions.mts', 'scripts/claude_routine_permissions.mts',
      'scripts/permissions_pack_claude_render.mts', 'scripts/permissions_pack_claude_merge.mts'];
    for (const install of versions) for (const file of required) {
      const destination = join(install, file);
      mkdirSync(dirname(destination), { recursive: true });
      copyFileSync(join(root, file), destination);
    }
    const oldSource = JSON.parse(readFileSync(sourcePath, 'utf8'));
    oldSource.allow.push({ exe: 'gh', args: 'api *' });
    const duplicate = 'Bash(echo scratch-fixture-retired)';
    oldSource.allow.push({ exe: 'echo', args: 'scratch-fixture-retired' });
    data(join(versions[0], 'contracts/permissions.json'), oldSource);
    mkdirSync(home);
    mkdirSync(join(repo, 'nen'), { recursive: true });
    data(join(repo, 'nen/workflow.json'), {});
    const env = { ...process.env, HOME: home, CLAUDE_CONFIG_DIR: join(dir, 'claude'),
      GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: '/dev/null' };
    assert.equal(run('git', ['init', '-q', repo], dir, env).status, 0);
    const install = (version: string) => run('bash', [join(root, 'scripts/permissions_pack.sh'), '--surface',
      'claude-code', '--install', '--target', repo, '--hatsu-root', version], dir, env);
    const foreign = [`Bash(node '${dir}/unrelated/scripts/gh_api_read.mts' *)`,
      `Bash(${dir}/unrelated/scripts/gh_token_env.sh -- nen pr open *)`];
    const settings = join(repo, CLAUDE_LOCAL);
    const diagnose = () => diagnoseCheckoutPack(source, versions[1], repo).status;
    assert.equal(diagnose(), 'missing');
    mkdirSync(join(repo, '.claude'));
    data(settings, { other: { preserved: true }, $comment: 'maintainer', permissions: {
      allow: [...foreign, retired[1]], deny: ['Bash(echo denied)'], ask: ['Bash(echo asked)'],
    } });
    const first = install(versions[0]);
    assert.equal(first.status, 0, output(first));
    const installed = JSON.parse(readFileSync(settings, 'utf8'));
    assert.ok(installed.permissions.allow.includes(retired[0]));
    assert.ok(installed.permissions.allow.includes(duplicate));
    installed.permissions.allow.push(duplicate);
    data(settings, installed);
    assert.equal(diagnose(), 'retired');
    const next = install(versions[1]);
    assert.equal(next.status, 0, output(next));
    assert.match(next.stdout, /removed retired pack row/);
    assert.match(next.stdout, /kept row with unknown ownership/);
    assert.match(next.stdout, /kept row with unknown ownership permissions\.allow\[\d+\] \(Bash echo\)/);
    const upgraded = JSON.parse(readFileSync(settings, 'utf8'));
    assert.ok(!upgraded.permissions.allow.some((row: string) => row.includes(versions[0]) || row === retired[0]));
    assert.ok(upgraded.permissions.allow.some((row: string) => row.includes(versions[1])));
    for (const row of [...foreign, retired[1]]) assert.ok(upgraded.permissions.allow.includes(row), row);
    assert.equal(upgraded.permissions.allow.filter((row: string) => row === duplicate).length, 2);
    assert.deepEqual(upgraded.other, { preserved: true });
    assert.ok(upgraded.$comment.startsWith('maintainer'));
    assert.equal(diagnose(), 'blocked');
    const repeated = install(versions[1]);
    assert.equal(repeated.status, 0, output(repeated));
    assert.match(repeated.stdout, /kept row with unknown ownership permissions\.allow\[\d+\] \(Bash echo\)/);
    assert.equal(diagnose(), 'blocked');
    assert.deepEqual(JSON.parse(readFileSync(settings, 'utf8')), upgraded);
    // Dropping the unrelated historical rule and one duplicate does not prove who added the survivor.
    upgraded.permissions.allow.splice(upgraded.permissions.allow.indexOf(duplicate), 1);
    upgraded.permissions.allow.splice(upgraded.permissions.allow.indexOf(retired[1]), 1);
    data(settings, upgraded);
    assert.equal(diagnose(), 'blocked');
    upgraded.permissions.allow.splice(upgraded.permissions.allow.indexOf(duplicate), 1);
    data(settings, upgraded);
    assert.equal(install(versions[1]).status, 0);
    assert.equal(diagnose(), 'present');
    // An independently added row with exactly the same bytes as the owned legacy grant survives.
    const unowned = { permissions: { allow: [retired[0]] } };
    const current = checkoutPack(source, versions[1], 'fixture');
    assert.deepEqual(mergePack(unowned, current, 'fixture').document.permissions.allow.slice(0, 1), unowned.permissions.allow);
    assert.throws(() => mergePack(null, current, 'fixture'));
    assert.throws(() => mergePack({}, {}, 'fixture'));
    data(settings, { permissions: { allow: [] } });
    assert.equal(diagnose(), 'missing');
    writeFileSync(settings, '{bad');
    assert.equal(diagnose(), 'blocked');
    rmSync(join(repo, '.claude'), { recursive: true });
    symlinkSync(home, join(repo, '.claude'));
    assert.equal(diagnose(), 'blocked');
  }));

  test('lone-call guard refuses executable shell structure and accepts quoted data', () => {
    for (const wrapper of wrappers) assert.equal(checkRoutineWrite(wrapper + bare, source).refusal, null);
    for (const command of [
      `${bare} | tail`, `${bare} |& tail`, `${bare}; echo x`, `true && ${bare}`, `true || ${bare}`,
      `true\n${bare}`, `${bare} &`, `${bare} >out`, `${bare} "$(echo x)"`, `${bare} \`echo x\``,
      `echo "$(${bare})"`, `echo \`${bare}\``, `bash -c '${bare}'`, `env X=y ${bare}`,
      `cat <<'EOF' >payload\nbody\nEOF\n${bare}`, `${bare} <<EOF\nbody\nEOF`, `(${bare})`,
      ...['timeout -k 1s 5s', '/usr/bin/time -f format', 'nice -n 5', 'nohup', 'stdbuf -oL', 'command --', 'builtin', 'noglob', 'xargs -n 1', 'env -u TOKEN'].map((wrapper) => `${wrapper} ${bare}`),
      `>out ${bare}`, `nen 2>out pr threads resolve --pr 1`, `echo <(${bare})`,
      `sh <<'EOF'\n${bare}\nEOF`, `cat <<EOF | bash\n${bare}\nEOF`,
      `cat <<EOF\n$(${bare})\nEOF`, `bash <<< '${bare}'`,
      `bash -o pipefail <<'EOF'\n${bare}\nEOF`, `bash -euo pipefail <<'EOF'\n${bare}\nEOF`,
      `bash -O extglob <<< '${bare}'`, `bash -o pipefail -s -- arg <<< '${bare}'`,
      `./${WRAPPER} nen pr threads resolve --pr 1`, `nen  pr threads resolve --pr 1`,
    ]) assert.match(checkRoutineWrite(command, source).refusal ?? '', /one plain Nen write call/, command);
    for (const command of [
      `${bare} --body-file 'a ; | && || & $(literal).md'`, `${bare} --body-file "a ; | && || &.md"`,
      `echo '${bare}; false'`, `command -v ${bare}`, `cat <<'EOF'\n$(${bare})\nEOF`, `cat <<'EOF'\n${bare}\nEOF`,
      `cat <<'EOF'; sh -c 'true'\n${bare}\nEOF`, 'nen pr threads list --pr 1 | head', 'git status && git diff',
      `bash -o pipefail script.sh <<'EOF'\n${bare}\nEOF`, `bash -O extglob -- script.sh <<< '${bare}'`,
    ]) assert.equal(checkRoutineWrite(command, source).refusal, null, command);
    const skills = ['backlog-synthesis', 'file', 'hiraishin', 'kamui', 'mugetsu', 'sharingan', 'shibari', 'tensho'];
    const documents = [...skills.map((skill) => `claude/skills/${skill}/SKILL.md`), 'docs/WORKFLOW.md'];
    for (const path of documents) {
      const prose = readFileSync(join(root, path), 'utf8');
      const found = new Set<string>();
      for (const [, block] of prose.matchAll(/^```bash\n([\s\S]*?)^```/gm)) {
        const lines = block.trim().split('\n');
        for (const [index, line] of lines.entries()) {
          const entry = source.claude_routine_writes.find(({ prefix }) => line.includes(`${prefix} `));
          if (!entry) continue;
          found.add(entry.prefix);
          assert.ok(!lines[index - 1]?.endsWith('&&'), line);
          const command = sampleCommand(line.replace('<installed-wrapper>', shellWord(join(root, WRAPPER)))).replace(/[[\]]/g, '');
          assert.ok(routineForms(source, root).some(({ rule }) => bashPattern(rule)?.test(command)), line);
          assert.equal(checkRoutineWrite(command, source).refusal, null, line);
        }
      }
      assert.ok(found.size > 0, path);
      if (path === 'docs/WORKFLOW.md') {
        assert.ok(found.has('nen pr ledger post') && found.has('nen issue comment'), path);
        assert.match(prose, /private_name_check\.sh" --target <owner\/name> <path>\nnen issue comment /);
        assert.doesNotMatch(prose, /private_name_check\.sh[^\n]*&&\s*nen issue comment/);
        assert.match(prose, /branch_authorship_check\.sh … && nen wc squash\|publish/);
      }
    }
  });

  test('preflights the exact bound hook on supported POSIX hosts', () => fixture((dir) => {
    const usable = preflightUserHook(root, source);
    assert.ok('hook' in usable, JSON.stringify(usable));
    assert.equal(usable.hook.command, '/bin/sh');
    const unsupported = preflightUserHook(root, source, 'win32', () => assert.fail('native Windows must not bind this hook'));
    assert.match(unsupported.problem ?? '', /unsupported paired hook host \(win32\)/);
    const unreachableShell = preflightUserHook(root, source, process.platform,
      () => ({ ...usable.hook, command: join(dir, 'missing-shell') }));
    assert.match(unreachableShell.problem ?? '', /paired hook host preflight failed/);
    const helperFailure = preflightUserHook(root, source, process.platform,
      () => ({ ...usable.hook, args: ['-c', 'exit 2'] }));
    assert.match(helperFailure.problem ?? '', /paired hook host preflight failed/);
    assert.match(preflightUserHook(dir, source).problem ?? '', /paired hook host preflight failed/);
  }));

  test('user hook checks Ten’s private session pin without the plugin or a host Nen', () => fixture((dir) => {
    const install = join(dir, 'installed');
    const cwd = join(dir, 'consumer');
    const host = join(dir, 'host');
    const session = join(dir, 'session');
    const bin = join(session, 'bin');
    for (const path of [cwd, host, session]) mkdirSync(path, { mode: 0o700 });
    mkdirSync(bin);
    const fixtureToken = 'inert-scratch-token';
    writeFileSync(join(host, 'gh'), `#!/bin/sh\nprintf '%s\\n' '${fixtureToken}'\n`, { mode: 0o700 });
    const marker = join(dir, 'called-nen');
    const binary = join(dir, 'nen-pin');
    writeFileSync(binary, `#!/bin/sh\n[ "$GH_TOKEN" = '${fixtureToken}' ] || exit 7\nprintf '%s\\n' "$@" > "$HATSU_FIXTURE_MARKER"\n`, { mode: 0o700 });
    symlinkSync(binary, join(bin, 'nen'));
    for (const file of [WRAPPER, 'contracts/permissions.json', 'scripts/claude_permissions.mts',
      'scripts/claude_routine_permissions.mts', 'scripts/claude_routine_write_guard.mts']) {
      mkdirSync(dirname(join(install, file)), { recursive: true });
      copyFileSync(join(root, file), join(install, file));
    }
    mkdirSync(join(install, 'nen'));
    data(join(install, 'nen/contract.json'), { dependency: { bootstrap: { sha256: {
      [`${process.platform}-${process.arch}`]: createHash('sha256').update(readFileSync(binary)).digest('hex'),
    } } } });
    writeFileSync(join(host, 'node'), '#!/bin/sh\nexit 0\n', { mode: 0o700 });
    const env = { ...process.env, CLAUDE_PLUGIN_ROOT: '', GH_TOKEN: '', GITHUB_TOKEN: '',
      PATH: `${host}:/usr/bin:/bin`, HATSU_FIXTURE_MARKER: marker };
    const hook = userHook(install);
    const payload = (command: string) => JSON.stringify({ tool_name: 'Bash', cwd, tool_input: { command } });
    const check = (command: string, args = hook.args) => run(hook.command, args, cwd, env, payload(command));
    const wrapper = join(install, WRAPPER);
    const command = `${wrapper} --path ${bin} -- ${bare}`;
    // POSIX specifies a nonzero lookup miss, with no fixed exit code.
    const lookup = ['-c', 'if command -v nen; then printf "%s\\n" nen-found; else printf "%s\\n" nen-missing; fi'];
    const hostLookup = run('/bin/sh', lookup, cwd, env);
    const sessionLookup = run('/bin/sh', lookup, cwd, { ...env, PATH: `${bin}${delimiter}${env.PATH}` });
    for (const result of [hostLookup, sessionLookup]) {
      assert.equal(result.error, undefined);
      assert.equal(result.signal, null);
      assert.equal(result.status, 0, output(result));
      assert.equal(result.stderr, '');
    }
    assert.equal(hostLookup.stdout, 'nen-missing\n');
    assert.equal(sessionLookup.stdout, `${join(bin, 'nen')}\nnen-found\n`);
    assert.ok(routineForms(source, install, true).some(({ rule }) => bashPattern(rule)?.test(command)));
    assert.equal(checkHookInput(JSON.parse(payload(command)), install), null);
    assert.equal(check(command).status, 0);
    assert.equal(existsSync(marker), false);
    const executed = run(wrapper, ['--path', bin, '--', ...bare.split(' ')], cwd, env);
    assert.equal(executed.status, 0, output(executed));
    assert.deepEqual(readFileSync(marker, 'utf8').trim().split('\n'), bare.split(' ').slice(1));
    for (const noncanonical of [`timeout 5s ${bare}`, `>out ${bare}`, `bash -o pipefail <<'EOF'\n${bare}\nEOF`,
      `bash -O extglob <<< '${bare}'`]) {
      assert.equal(check(noncanonical).status, 2, noncanonical);
    }
    assert.equal(check(`bash -o pipefail script.sh <<'EOF'\n${bare}\nEOF`).status, 0);
    const nonNen = `${wrapper} --path ${bin} -- /bin/sh -c 'printf harmless # -- nen pr open x'`;
    assert.ok(routineForms(source, install, true).some(({ rule }) => rule.includes(' --path ') && bashPattern(rule)?.test(nonNen)));
    for (const raw of [nonNen, `true && ${nonNen}`, `timeout 5s ${nonNen}`]) {
      assert.match(check(raw).stderr, /one plain Nen write call/, raw);
    }
    assert.equal(check(`${wrapper} --path ${bin} -- nen --version`).status, 0);
    assert.equal(check(`echo ${shellWord(nonNen)}`).status, 0);
    mkdirSync(join(cwd, 'scripts'));
    writeFileSync(join(cwd, WRAPPER), '#!/bin/sh\ntrue\n', { mode: 0o700 });
    assert.match(check(`./${WRAPPER} -- ${bare}`).stderr, /could not be verified/);
    copyFileSync(wrapper, join(cwd, WRAPPER));
    assert.equal(check(`./${WRAPPER} -- ${bare}`).status, 0);
    writeFileSync(join(bin, 'another'), 'scratch');
    assert.match(check(command).stderr, /session bin or its pinned Nen/);
    rmSync(join(bin, 'another'));
    writeFileSync(binary, 'tampered');
    assert.match(checkHookInput(JSON.parse(payload(command)), install) ?? '', /session bin or its pinned Nen/);
    assert.equal(check(command).status, 2);
    assert.equal(check(command.replace(bin, host)).status, 2);
    const unavailable = [...hook.args];
    unavailable[3] = unavailable[5] = join(dir, 'missing-node');
    assert.equal(check(bare, unavailable).status, 2);
    writeFileSync(join(install, 'scripts/claude_permissions.mts'), 'tampered');
    assert.match(check(bare).stderr, /approved checker binding is unavailable or changed.*independent terminal/);
  }));

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

  test('recovers a stale paired proposal from an independent terminal', () => fixture((dir) => {
    const old = join(dir, 'installed-previous');
    const current = join(dir, 'installed-current');
    const repo = join(dir, 'repo');
    const config = join(dir, 'claude-config');
    const bin = join(dir, 'bin');
    const user = join(config, 'settings.json');
    const checker = 'scripts/claude_routine_write_guard.mts';
    for (const install of [old, current]) {
      for (const file of [WRAPPER, checker, 'scripts/permissions_pack.sh', 'scripts/claude_permissions.mts',
        'scripts/claude_routine_permissions.mts', 'scripts/claude_routine_permissions_cli.mts',
        'contracts/permissions.json', 'nen/contract.json', 'nen/repos.json']) {
        mkdirSync(dirname(join(install, file)), { recursive: true });
        copyFileSync(join(root, file), join(install, file));
      }
    }
    for (const path of [bin, config]) mkdirSync(path);
    writeFileSync(join(bin, 'claude'), '#!/bin/sh\necho 2.1.295\n', { mode: 0o700 });
    const env = { ...process.env, HOME: dir, CLAUDE_CONFIG_DIR: config, CLAUDE_PLUGIN_ROOT: '',
      GH_TOKEN: '', GITHUB_TOKEN: '', PATH: [bin, process.env.PATH].join(delimiter),
      GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: '/dev/null' };
    assert.equal(run('git', ['init', '-q', repo], dir, env).status, 0);
    const pack = (install: string, mode: string) => run('bash', [join(install, 'scripts/permissions_pack.sh'),
      '--surface', 'claude-code', mode, '--target', repo], dir, env);
    const oldRender = pack(old, '--render-user');
    assert.equal(oldRender.status, 0, output(oldRender));
    const prior: ReturnType<typeof userProposal> = JSON.parse(oldRender.stdout);
    const unrelated = { matcher: 'Read', hooks: [{ type: 'command', command: 'echo scratch' }] };
    const foreignRule = 'Bash(echo user-owned)';
    const settings = { theme: 'dark', ...prior,
      permissions: { allow: [...prior.permissions.allow, foreignRule], deny: ['Bash(echo forbidden)'] },
      hooks: { PreToolUse: [...prior.hooks.PreToolUse, unrelated] },
    };
    data(user, settings);
    const before = readFileSync(user);
    const oldHook = prior.hooks.PreToolUse[0].hooks[0];
    const payload = (command: string) => JSON.stringify({ tool_name: 'Bash', cwd: repo, tool_input: { command } });
    rmSync(join(old, checker));
    const blocked = run(oldHook.command, oldHook.args, repo, env, payload('echo inert'));
    assert.equal(blocked.status, 2, output(blocked));
    assert.match(blocked.stderr, /independent terminal/);
    const unavailable = pack(old, '--check-user');
    assert.equal(unavailable.status, 0, output(unavailable));
    assert.match(unavailable.stdout, /paired hook host preflight failed.*Paired proposal unavailable/);
    assert.equal(unavailable.stdout.trim().split('\n').length, 1);
    const withheld = pack(old, '--render-user');
    assert.equal(withheld.status, 2, output(withheld));
    assert.equal(withheld.stdout, '');

    const stale = pack(current, '--check-user');
    assert.equal(stale.status, 0, output(stale));
    assert.match(stale.stdout, /paired checker binding missing or stale.*independent terminal.*--render-user/);
    const renewed = pack(current, '--render-user');
    assert.equal(renewed.status, 0, output(renewed));
    assert.deepEqual(readFileSync(user), before);
    const replacement: ReturnType<typeof userProposal> = JSON.parse(renewed.stdout);
    assert.ok(replacement.permissions.allow.some((rule) => rule.includes(current)));
    assert.ok(replacement.permissions.allow.every((rule) => !rule.includes(old)));
    // Simulate the maintainer replacing only the prior proposal in this scratch file.
    const merged = { ...settings,
      permissions: { ...settings.permissions, allow: [...replacement.permissions.allow, foreignRule] },
      hooks: { PreToolUse: [...replacement.hooks.PreToolUse, unrelated] },
    };
    data(user, merged);
    const ready = pack(current, '--check-user');
    assert.match(ready.stdout, /routine user rows present.*paired checker binding present/);
    assert.deepEqual(JSON.parse(readFileSync(user, 'utf8')), merged);
    const refreshed = replacement.hooks.PreToolUse[0].hooks[0];
    assert.equal(run(refreshed.command, refreshed.args, repo, env, payload(bare)).status, 0);
    assert.equal(run(refreshed.command, refreshed.args, repo, env, payload(`${bare} | tail`)).status, 2);
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
    const claude = join(bin, 'claude');
    writeFileSync(claude, '#!/bin/sh\necho 2.1.294\n', { mode: 0o700 });
    const env = { ...process.env, HOME: home, CLAUDE_CONFIG_DIR: config, CLAUDE_PLUGIN_ROOT: root,
      GH_TOKEN: '', GITHUB_TOKEN: '', PATH: [bin, process.env.PATH].join(delimiter),
      GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: '/dev/null' };
    const git = run('git', ['init', '-q', repo], dir, env);
    assert.equal(git.status, 0, output(git));
    assert.equal(run('git', ['-C', repo, 'remote', 'add', 'origin', 'https://github.com/example/project.git'], dir, env).status, 0);
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
      if (row.state === 'blocked') {
        assert.deepEqual(row.fix.run, []);
        assert.match(row.detail, /tracked.*needs a maintainer edit/);
      }
      return row;
    };
    const missingPack = tenkaiPack('claude-code', 'missing', 'missing');
    tenkaiPack('codex', 'advisory', 'missing');
    assert.equal(tenkai('--surface', 'invalid').status, 2);
    const textDiagnosis = run('bash', [tenkaiEntry, 'diagnose', ...adoption, '--surface', 'claude-code'], dir, env);
    assert.equal(textDiagnosis.status, 1, output(textDiagnosis));
    assert.match(textDiagnosis.stdout, /MISS  permissions\/claude-code/);
    assert.match(textDiagnosis.stdout, /permissions_pack.sh.*--install/);
    assert.match(textDiagnosis.stdout, /tenkai_adopt.sh apply --surface claude-code --repo/);
    assert.match(textDiagnosis.stdout, /tenkai_adopt.sh diagnose --surface claude-code --repo/);
    const runner = run('bash', [tenkaiEntry, 'runner-policy', '--visibility', 'private', '--self-hosted', '0'], dir, env);
    assert.equal(runner.status, 0, output(runner));
    const invalidRenderer = run(process.execPath, [join(root, 'scripts/permissions_pack_claude_render.mts')], dir, env);
    assert.equal(invalidRenderer.status, 2);
    assert.match(invalidRenderer.stderr, /expected permissions source/);
    assert.match(pack('--check-user').stdout, /must report 2.1.295/);
    assert.equal(pack('--render-user').status, 2);
    writeFileSync(claude, '#!/bin/sh\necho 2.1.295\n');
    let result = pack('--check-user');
    assert.equal(result.status, 0, output(result));
    assert.match(result.stdout, /routine user rows missing.*effective managed\/session policy unknown.*--render-user/);
    assert.equal(result.stdout.trim().split('\n').length, 1);
    assert.equal(existsSync(user), false);
    result = pack('--render-user');
    assert.equal(result.status, 0, output(result));
    assert.equal(existsSync(user), false);
    const proposed = JSON.parse(result.stdout);
    assert.ok(!proposed.autoMode.environment.includes('Trusted repo: github.com/example/project'));
    assert.match(result.stderr, /Trust nomination from target registry.*github.com\/example\/project/);
    assert.equal(pack('--render-release-opt-in').status, 2);
    assert.equal(run('git', ['-C', repo, 'remote', 'set-url', 'origin', 'https://github.com/zheref/hatsu.git'], dir, env).status, 0);
    data(join(repo, 'nen/contract.json'), { project: { verbs: { plugin: { release: { exe: 'false' } } } } });
    assert.equal(pack('--render-release-opt-in').status, 2);
    copyFileSync(join(root, 'nen/contract.json'), join(repo, 'nen/contract.json'));
    const release = pack('--render-release-opt-in');
    assert.equal(release.status, 0, output(release));
    assert.deepEqual(JSON.parse(release.stdout).permissions.allow, [`Bash(nen shu release --repo ${repo} --lane plugin)`]);
    assert.match(release.stderr, /recorded G3 go and preflight/);
    const unsafe = join(dir, 'unsafe*publisher');
    assert.equal(run('git', ['init', '-q', unsafe], dir, env).status, 0);
    assert.equal(run('git', ['-C', unsafe, 'remote', 'add', 'origin', 'https://github.com/zheref/hatsu.git'], dir, env).status, 0);
    mkdirSync(join(unsafe, 'nen'));
    copyFileSync(join(root, 'nen/contract.json'), join(unsafe, 'nen/contract.json'));
    const unsafeRelease = run('bash', [join(root, 'scripts/permissions_pack.sh'), '--surface', 'claude-code',
      '--render-release-opt-in', '--target', unsafe], dir, env);
    assert.equal(unsafeRelease.status, 2);
    assert.match(unsafeRelease.stderr, /no safe Hatsu plugin publisher permission/);
    rmSync(join(repo, 'nen/contract.json'));
    assert.equal(run('git', ['-C', repo, 'remote', 'set-url', 'origin', 'https://github.com/example/project.git'], dir, env).status, 0);
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
    const repair = textDiagnosis.stdout.split('\n').find((line) => /run:.*permissions_pack.sh.*--install/.test(line));
    assert.ok(repair);
    const fixed = run('bash', ['-c', repair.trim().replace(/^run:\s*/, '')], dir, env);
    assert.equal(fixed.status, 0, output(fixed));
    const detected = run('bash', ['-c', `${missingPack.fix.detect} --json`], dir, env);
    assert.ok([0, 1].includes(detected.status ?? -1), output(detected));
    assert.equal(JSON.parse(detected.stdout).items.find((item: { id: string }) => item.id === 'permissions/claude-code').state, 'satisfied');
    const local = join(repo, CLAUDE_LOCAL);
    assert.equal(statSync(local).mode & 0o777, 0o600);
    const document = JSON.parse(readFileSync(local, 'utf8'));
    document.permissions.allow.push('Bash(echo private-text)');
    data(local, document);
    chmodSync(local, 0o640);
    result = pack('--install');
    assert.equal(result.status, 0, output(result));
    assert.match(result.stdout, /kept foreign permissions.allow\[\d+\] \(Bash echo\)/);
    assert.doesNotMatch(result.stdout, /private-text/);
    assert.equal(statSync(local).mode & 0o777, 0o640);
    assert.equal(diagnoseCheckoutPack(source, root, repo).status, 'present');
    tenkaiPack('claude-code', 'satisfied', 'present');
    const applied = run('bash', [tenkaiEntry, 'apply', ...adoption, '--surface', 'claude-code', '--json'], dir, env);
    assert.ok([0, 1].includes(applied.status ?? -1), output(applied));
    const appliedPack = JSON.parse(applied.stdout).items.find((row: { id: string }) => row.id === 'permissions/claude-code');
    assert.equal(appliedPack?.packStatus, 'present');
    assert.deepEqual(JSON.parse(readFileSync(user, 'utf8')), updated);
    const deficient = JSON.parse(readFileSync(local, 'utf8'));
    deficient.permissions.allow.pop();
    deficient.permissions.allow.shift();
    data(local, deficient);
    const stable = readFileSync(local);
    const add = run('git', ['add', '-f', CLAUDE_LOCAL], repo, env);
    assert.equal(add.status, 0, output(add));
    tenkaiPack('claude-code', 'blocked', 'blocked');
    assert.match(pack('--install').stdout, /left alone.*settings.local.json/);
    assert.deepEqual(readFileSync(local), stable);
    const wrongDestination = run(process.execPath, [join(root, 'scripts/permissions_pack_claude_merge.mts'), user,
      JSON.stringify(checkoutPack(source, root, 'fixture')), 'fixture'], dir, env);
    assert.equal(wrongDestination.status, 3);
    assert.match(wrongDestination.stderr, /only checkout/);
    assert.deepEqual(JSON.parse(readFileSync(user, 'utf8')), updated);

    const hookBinding = userHook(root);
    const hookEnv = { ...env, CLAUDE_PLUGIN_ROOT: '' };
    const hook = run(hookBinding.command, hookBinding.args, root, hookEnv,
      JSON.stringify({ tool_name: 'Bash', tool_input: { command: `${bare} | tail` }, cwd: root }));
    assert.equal(hook.status, 2, output(hook));
    assert.match(hook.stderr, /one plain Nen write call/);
    const encoded = JSON.stringify({ tool_name: 'Bash', tool_input: { command: `${bare} | tail` }, cwd: root })
      .replace('nen pr', String.raw`\u006e\u0065\u006e pr`);
    const encodedHook = run(hookBinding.command, hookBinding.args, root, hookEnv, encoded);
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

  }));
}
