import { readFileSync } from 'node:fs'
import { expect, test } from 'vitest'
import { HUMAN_CALLS } from '../actions.ts'
import { STAGES, STAGE_NEUTRAL } from '../stages.ts'

function readCanon(path: string): string {
  return readFileSync(new URL(`../../../${path}`, import.meta.url), 'utf8')
}

function requireMatch(text: string, pattern: RegExp, source: string): RegExpMatchArray {
  const match = text.match(pattern)
  if (!match) throw new Error(`Cannot read ${source} from canon`)
  return match
}

function skillNames(text: string): string[] {
  return [...text.matchAll(/`(?:hatsu:)?([a-z][a-z-]*)(?: on <CODE>#<PR>)?`/g)].map(match => match[1]!)
}

function humanCalls(workflow: string): string[] {
  const [, table] = requireMatch(workflow,
    /^## 4 · The phases, and which of them a human calls\n[\s\S]*?^\| Phase \| What it does \| Why it is the human's \|\n\|---\|---\|---\|\n((?:\|[^\n]+\n)+)/m,
    'the WORKFLOW human-call table')
  return table!.trimEnd().split('\n').map(row => {
    const [, link, plain] = requireMatch(row,
      /^\| (?:\[`([a-z-]+)`\]\(\.\.\/claude\/skills\/\1\/\)|\*\*([a-z-]+)\*\*) \|/,
      `WORKFLOW human-call row: ${row}`)
    return link ?? plain!
  })
}

const workflow = readCanon('docs/WORKFLOW.md')
const build = readCanon('claude/skills/build/SKILL.md')
const roster = readCanon('docs/ROSTER.md')
const [, deskCalls] = requireMatch(roster, /^\| <a id="hr-370".*?maintainer's prompt \(([^)]+)\)/m, 'HR-370 desk buttons')
const [, wrapCalls] = requireMatch(roster, /^\| <a id="hr-371".*?desk shows the wrap-up buttons \(([^)]+)\)/m, 'HR-371 wrap-up buttons')

function checkHumanCalls(text: string): void {
  // HR-370 names the fill-only subset, including tensho, which composes aka and mukai.
  const fillOnly = skillNames(deskCalls!)
  const calls = humanCalls(text)
  expect(calls).toEqual(expect.arrayContaining(fillOnly.filter(call => call !== 'tensho')))
  expect([...new Set(calls.filter(call => !fillOnly.includes(call)))].sort()).toEqual(['kagutsuchi', 'merge', 'mugetsu'])
  expect(new Set(calls).size).toBe(calls.length)
  expect([...HUMAN_CALLS].sort()).toEqual(fillOnly.sort())
}

function checkStages(text: string): void {
  const [, intro] = requireMatch(text, /^(\[`ten`\].*→ .*\[`cleanup`\].*wrap-up\.)$/m, 'the build skill chain')
  const [warmup, ...sequence] = skillNames(intro!).filter(skill => !['classify', 'direct', 'rikugan'].includes(skill))
  const rows = [...text.matchAll(/^\| \*\*\d+ · ([^|]+)\*\* \| ([^|]+) \|/gm)]
  const owners = rows.map(row => skillNames(row[2]!)[0]!)
  expect(owners).toEqual(sequence.slice(0, -1))
  const wrap = sequence.at(-1)
  expect(STAGES.map(stage => stage.name)).toEqual([warmup, 'emperor-time', ...owners, 'gate', wrap])
  expect(STAGES.find(stage => stage.name === warmup)?.skills).toEqual([warmup])
  expect(STAGES.find(stage => stage.name === 'emperor-time')?.skills).toEqual(['emperor-time'])
  expect(STAGES.find(stage => stage.name === 'gate')?.skills).toEqual([])

  const neutral: readonly string[] = STAGE_NEUTRAL
  const assigned = new Set<string>()
  for (const [index, row] of rows.entries()) {
    const owner = owners[index]!
    const named = skillNames(row[2]!).filter(skill => !neutral.includes(skill))
    // Build offers en after Mukai. Gyo first runs during Ren, and Sharingan is named
    // inside En's own order in WORKFLOW. Build itself counts as authoring.
    if (owner === 'ren') {
      requireMatch(workflow, /^### `gyo` — linting, every Ren turn$/m, 'Gyo in Ren')
      named.unshift('build', 'gyo')
    }
    if (owner === 'aka') named.push(...skillNames(deskCalls!).filter(skill => skill === 'tensho'))
    if (owner === 'mukai' && named.includes('en')) named.splice(named.indexOf('en'), 1)
    if (owner === 'en') {
      const [, enOrder] = requireMatch(workflow, /^`en`'s order: ([\s\S]+?)\n\n/m, 'En order')
      const steps = enOrder!.split('→').flatMap(step => {
        const skill = /^\[?`([a-z-]+)`/.exec(step.trimStart())?.[1]
        return skill && !neutral.includes(skill) ? [skill] : []
      })
      named.push(...steps)
    }
    const firstUse = [...new Set(named)].filter(skill => !assigned.has(skill))
    firstUse.forEach(skill => assigned.add(skill))
    expect([...STAGES.find(stage => stage.name === owner)!.skills].sort()).toEqual(firstUse.sort())
  }
  expect(STAGES.find(stage => stage.name === wrap)?.skills).toEqual(skillNames(wrapCalls!))
}

test('desk human-call flags follow WORKFLOW and the HR-370 fill-only subset', () => {
  checkHumanCalls(workflow)
})

test('desk stages follow the build sequence, first ownership and the wrap-up ruling', () => {
  checkStages(build)
})

test('a new human-only call or an unreadable human-call table fails the drift check', () => {
  const withCall = workflow.replace('| **merge** |', '| **another-call** | action | reason |\n| **merge** |')
  expect(withCall).not.toBe(workflow)
  expect(() => checkHumanCalls(withCall)).toThrow()
  expect(() => checkHumanCalls('')).toThrow('Cannot read')
})

test('a new phase in the Build chain fails the desk ownership check', () => {
  const withPhase = build.replace('→ `rasengan` →', '→ `rasengan` → `new-phase` →')
  expect(withPhase).not.toBe(build)
  expect(() => checkStages(withPhase)).toThrow()
})
