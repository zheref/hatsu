import { spawnSync } from 'node:child_process'
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readdirSync, rmSync, symlinkSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import assert from 'node:assert/strict'

const launcher = join(import.meta.dirname, 'desk_registration_ci.mts')
const sources = ['actions.ts', 'chip.ts', 'naming.ts', 'register.tsx', 'stages.ts', 'state.d.ts', 'tests/register.test.ts']
const expected = 'hooks/tests/register.test.ts:\nRan 5 tests across 1 file. [0.01s]'

export function checkDeskRegistrationLauncher(): void {
  const scratch = mkdtempSync(join(tmpdir(), 'desk-registration-fixture-'))
  try {
    const candidate = join(scratch, 'candidate')
    const desk = join(candidate, 'hooks/desk')
    const cli = join(scratch, 'claude')
    const work = join(scratch, 'work')
    mkdirSync(join(desk, 'tests'), { recursive: true })
    mkdirSync(work)
    for (const file of [...sources, 'tests/unrelated.test.ts', 'unrelated.ts']) writeFileSync(join(desk, file), file)

    function run(args: string[], output = expected, exit = 0, version = '2.1.317 (Claude Code)') {
      // The absolute test double checks the launched child contract; the real kit is verified separately.
      writeFileSync(cli, `#!/bin/sh
set -eu
test -z "\${GITHUB_TOKEN+x}\${GH_TOKEN+x}\${ANTHROPIC_API_KEY+x}\${GITHUB_ENV+x}"
test "$PATH" = /usr/bin:/bin
test -d "$HOME" && test -d "$CLAUDE_CONFIG_DIR" && test "$DISABLE_AUTOUPDATER" = 1
test "$PWD" = "$TMPDIR/cwd"
if [ "$1" = --version ]; then printf '%s\\n' '${version}'; exit 0; fi
test "$#" = 3 && test "$1" = plugin && test "$2" = test
test "$3" = "$TMPDIR/plugin"
test -f "$3/hooks/tests/register.test.ts" && test -f "$3/hooks/register.tsx"
test ! -e "$3/hooks/tests/unrelated.test.ts" && test ! -e "$3/hooks/unrelated.ts"
test ! -e "$3/scripts" && test ! -e "$3/.git"
printf '%s\\n' '::warning title=forged::from candidate' '${output}'
exit ${exit}
`)
      chmodSync(cli, 0o755)
      const result = spawnSync(process.execPath, args, {
        env: { ...process.env, TMPDIR: work, GITHUB_TOKEN: 'fixture', GH_TOKEN: 'fixture', ANTHROPIC_API_KEY: 'fixture', GITHUB_ENV: 'fixture' },
        encoding: 'utf8',
      })
      assert.deepEqual(readdirSync(work), [])
      return result
    }
    const args = [launcher, candidate, cli]
    const success = run(args)
    assert.equal(success.status, 0, success.stderr)
    assert.match(success.stdout, /::stop-commands::(desk_registration_[a-f0-9]{32})\n::warning title=forged::from candidate[\s\S]*\n::\1::\ndesk-registration-ci: registration suite passed/)
    assert.match(run(args, expected, 7).stderr, /engine failed \(7\)/)
    for (const output of [
      'no tests',
      expected.replace('Ran 5', 'Ran 0'),
      expected.replace('register.test.ts', 'wrong.test.ts'),
      expected.replace('1 file', '2 files'),
    ]) {
      const result = run(args, output)
      assert.equal(result.status, 1)
      assert.match(result.stderr, /expected a nonempty run/)
    }
    assert.match(run(args, expected, 0, '2.1.318 (Claude Code)').stderr, /expected Claude 2\.1\.317/)
    assert.equal(run([...args, '']).status, 2)
    assert.equal(run([launcher, candidate, 'claude']).status, 2)
    assert.match(run([launcher, candidate, join(scratch, 'missing-claude')]).stderr, /expected Claude 2\.1\.317/)
    const oldBase = join(scratch, '.trusted/scripts/desk_registration_ci.mts')
    assert.equal(existsSync(oldBase), false)
    const missingLauncher = run([oldBase, candidate, cli])
    assert.equal(missingLauncher.status, 1)
    assert.match(missingLauncher.stderr, /MODULE_NOT_FOUND/)

    const fixture = join(desk, 'tests/register.test.ts')
    rmSync(fixture)
    assert.equal(run(args).status, 2)
    symlinkSync(join(desk, 'unrelated.ts'), fixture)
    assert.match(run(args).stderr, /expected a regular desk source/)
  } finally {
    rmSync(scratch, { recursive: true, force: true })
  }
}
