#!/usr/bin/env node
// This launcher runs from the trusted base in the dedicated registration job.
import { spawnSync } from 'node:child_process'
import { randomBytes } from 'node:crypto'
import { copyFileSync, lstatSync, mkdirSync, mkdtempSync, realpathSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { isAbsolute, join } from 'node:path'

const sourceFiles = ['actions.ts', 'chip.ts', 'naming.ts', 'register.tsx', 'stages.ts', 'state.d.ts', 'tests/register.test.ts']
const version = '2.1.317 (Claude Code)'

function reportOutput(stdout: string, stderr: string): void {
  const fence = `desk_registration_${randomBytes(16).toString('hex')}`
  console.log(`::stop-commands::${fence}`)
  if (stdout) console.log(stdout.trimEnd())
  if (stderr) console.log(stderr.trimEnd())
  console.log(`::${fence}::`)
}

function main(args: string[]): number {
  const [candidate, claude] = args
  if (args.length !== 2 || !candidate || !claude || !isAbsolute(candidate) || !isAbsolute(claude)) {
    console.error('desk-registration-ci: expected absolute candidate root and verified Claude binary paths')
    return 2
  }

  const scratch = mkdtempSync(join(realpathSync(tmpdir()), 'hatsu-desk-registration-'))
  try {
    const root = realpathSync(candidate)
    const stage = join(scratch, 'plugin')
    const cwd = join(scratch, 'cwd')
    const home = join(scratch, 'home')
    const config = join(scratch, 'config')
    for (const dir of [cwd, home, config, join(stage, '.claude-plugin'), join(stage, 'hooks/tests')]) {
      mkdirSync(dir, { recursive: true })
    }
    for (const file of sourceFiles) {
      const source = join(root, 'hooks/desk', file)
      // A link in a parent directory is also outside the admitted input shape.
      if (!lstatSync(source).isFile() || realpathSync(source) !== source) {
        throw new Error(`expected a regular desk source: ${file}`)
      }
      copyFileSync(source, join(stage, 'hooks', file))
    }
    writeFileSync(join(stage, 'hooks/hooks.json'), JSON.stringify({ modules: ['./register.tsx'] }))
    writeFileSync(join(stage, '.claude-plugin/plugin.json'), JSON.stringify({
      name: 'hatsu', version: '0.0.0', description: 'Hatsu desk test stage', types: './hooks/state.d.ts',
    }))

    // Keep the candidate checkout out of config discovery and inherit no credentials or runner output paths.
    const options = {
      cwd,
      encoding: 'utf8' as const,
      env: {
        PATH: '/usr/bin:/bin', HOME: home, TMPDIR: scratch,
        CLAUDE_CONFIG_DIR: config, DISABLE_AUTOUPDATER: '1', NO_COLOR: '1',
      },
    }
    const installed = spawnSync(claude, ['--version'], options)
    if (installed.error || installed.status !== 0 || installed.stdout.trim() !== version) {
      throw new Error(`expected Claude ${version}`)
    }
    const tests = spawnSync(claude, ['plugin', 'test', stage], options)
    reportOutput(tests.stdout ?? '', tests.stderr ?? '')
    if (tests.error || tests.status !== 0) {
      console.error(`desk-registration-ci: engine failed (${tests.error?.message ?? tests.signal ?? tests.status})`)
      return 1
    }
    const output = `${tests.stdout}\n${tests.stderr}`
    if (!/^hooks\/tests\/register\.test\.ts:$/m.test(output) ||
        !/^Ran [1-9]\d* tests? across 1 file\. /m.test(output)) {
      console.error('desk-registration-ci: expected a nonempty run of the sole registration fixture')
      return 1
    }
    console.log('desk-registration-ci: registration suite passed')
    return 0
  } catch (error) {
    console.error(`desk-registration-ci: ${(error as Error).message}`)
    return 2
  } finally {
    rmSync(scratch, { recursive: true, force: true })
  }
}

process.exitCode = main(process.argv.slice(2))
