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

function section(text: string, heading: string): string {
  const lines = text.split('\n')
  const starts = lines.flatMap((line, index) => line === heading ? [index] : [])
  if (starts.length !== 1) throw new Error(`Cannot read unique canon section: ${heading}`)
  const start = starts[0]! + 1
  const level = heading.indexOf(' ')
  const boundary = new RegExp(`^#{1,${level}} `)
  const end = lines.findIndex((line, index) => index >= start && boundary.test(line))
  return lines.slice(start, end < 0 ? undefined : end).join('\n')
}

const workflowPhaseHeading = '## 4 · The phases, and which of them a human calls'
const buildHeading = '## 4. Building protocol'

function humanCalls(workflow: string): string[] {
  const [, table] = requireMatch(section(workflow, workflowPhaseHeading),
    /^\| Phase \| What it does \| Why it is the human's \|\n\|---\|---\|---\|\n((?:\|[^\n]+\n)+)/m,
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
  // Tensho is a fill-only composition under HR-370, outside WORKFLOW's human-call table.
  const fillOnly = skillNames(deskCalls!)
  const direct = fillOnly.filter(call => call !== 'tensho')
  expect(humanCalls(text).sort()).toEqual([...direct, 'kagutsuchi', 'merge', 'mugetsu'].sort())
  expect([...HUMAN_CALLS].sort()).toEqual(fillOnly.sort())
}

type DeskStage = { name: string; skills: readonly string[] }

// Desk evidence excludes cross-stage actions and advisory skills. These expectations are
// independent of the production lookup. Canon-only exclusions below are scoped to their roles.
const neutralSkills = ['spiritual-message', 'jutaisho', 'hanten', 'murasaki', 'kotoamatsukami',
  'tsukuyomi', 'rikugan', 'direct', 'classify', 'file']

function workflowRen(text: string): string[] {
  const [, chain] = requireMatch(section(text, workflowPhaseHeading),
    /^\*\*Per request, the loop is `ren`\*\*[^\n]*\n\n([\s\S]+?)\n\n/m, 'the WORKFLOW Ren chain')
  return chain!.split('→').map(step => {
    const [, skill] = requireMatch(step.trim(), /^`([a-z-]+)`(?:\s|$)/, `Ren action: ${step}`)
    expect(skillNames(step)).toEqual([skill])
    return skill!
  })
}

function enOwnership(text: string): string[] {
  const en = section(text, '### `en` — the readiness watch, its two keys, and the Illumi hand-off')
  const [, chain] = requireMatch(en, /^`en`'s order: ([\s\S]+?)\n\n/m, 'En order')
  return chain!.split('→').flatMap((raw, index, steps) => {
    const step = raw.replace(/\s+/g, ' ').trim()
    const code = [...step.matchAll(/`([^`]+)`/g)].map(match => match[1])
    if (step.startsWith('**observe⁵ while ')) {
      expect(code).toEqual([])
      return []
    }
    if (index === steps.length - 1 && step.startsWith('the dated **final** report,')) {
      requireMatch(step, /\[`rikugan`\]\(\.\.\/claude\/skills\/rikugan\/\)'s .* `nen report render --variant final` \(`backlog-board` § 3's path\)/, 'En final report and its citation')
      expect(code).toEqual(['rikugan', 'nen report render --variant final', 'backlog-board', 'Reports/'])
      return []
    }

    const [, skill] = requireMatch(step, /^\[?`([a-z-]+)`/, `En action: ${step}`)
    expect(code).toEqual([skill])
    if (index === 0 && skill === 'spiritual-message' && step.includes('(landing —')) return []
    if (skill === 'murasaki' && /when the branch is behind$/.test(step)) return []
    if (index === steps.length - 2 && skill === 'jutaisho' && /once at Ready$/.test(step)) return []
    return [skill!]
  })
}

function checkStages(
  text: string, workflowText = workflow, stages: readonly DeskStage[] = STAGES,
  neutral: readonly string[] = STAGE_NEUTRAL,
): void {
  expect([...neutral].sort()).toEqual([...neutralSkills].sort())
  const body = section(text, buildHeading)
  const [, intro] = requireMatch(body, /^(\[`ten`\].*→ .*\[`cleanup`\].*wrap-up\.)$/m, 'the build skill chain')
  const [warmup, ...sequence] = skillNames(intro!).filter(skill => !['classify', 'direct', 'rikugan'].includes(skill))
  const [, table] = requireMatch(body, /^\| Phase \| Skill \| What build takes from it \|\n\|---\|---\|---\|\n((?:\|[^\n]+\n)+)/m, 'the Build phase table')
  const rows = table!.trimEnd().split('\n').map((row, index) => {
    const [, ordinal, skills] = requireMatch(row, /^\| \*\*(\d+) · [^|]+\*\* \| ([^|]+) \|/, 'a Build phase row')
    expect(Number(ordinal)).toBe(index + 1)
    return skillNames(skills!)
  })
  const owners = rows.map(row => row[0]!)
  expect(owners).toEqual(sequence.slice(0, -1))
  const wrap = sequence.at(-1)
  const ren = workflowRen(workflowText)
  expect(rows.find(row => row[0] === 'ren')?.slice(1)).toEqual(ren)
  expect(ren.slice(-2)).toEqual(['spiritual-message', 'jutaisho'])
  requireMatch(workflowText, /^### `gyo` — linting, every Ren turn$/m, 'Gyo in Ren')

  expect(stages.map(stage => stage.name)).toEqual([warmup, 'emperor-time', ...owners, 'gate', wrap])
  expect(stages.find(stage => stage.name === warmup)?.skills).toEqual([warmup])
  expect(stages.find(stage => stage.name === 'emperor-time')?.skills).toEqual(['emperor-time'])
  expect(stages.find(stage => stage.name === 'gate')?.skills).toEqual([])

  const assigned = new Set<string>()
  for (const [owner, ...steps] of rows) {
    let named = [owner!, ...steps]
    if (owner === 'ren') named = ['build', 'gyo', owner, ...ren.slice(0, -2)]
    if (owner === 'aka') named.push(...skillNames(deskCalls!).filter(skill => skill === 'tensho'))
    if (owner === 'mukai') {
      // Mukai ends by offering En. Catch-up, review and impacted suites also run outside Mukai.
      expect(steps.at(-1)).toBe('en')
      named = [owner, ...steps.slice(0, -1).filter(skill => !['murasaki', 'hanten', 'kotoamatsukami'].includes(skill))]
    }
    if (owner === 'en') named.push(...enOwnership(workflowText))
    const firstUse = [...new Set(named)].filter(skill => !assigned.has(skill))
    firstUse.forEach(skill => assigned.add(skill))
    expect([...stages.find(stage => stage.name === owner)!.skills].sort()).toEqual(firstUse.sort())
  }
  expect(stages.find(stage => stage.name === wrap)?.skills).toEqual(skillNames(wrapCalls!))
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

test('WORKFLOW table boundaries and the derived-only tensho call are guarded', () => {
  const moved = workflow.replace('| Phase | What it does | Why it is the human\'s |', "## Other policy\n\n| Phase | What it does | Why it is the human's |")
  expect(moved).not.toBe(workflow)
  expect(() => checkHumanCalls(moved)).toThrow('the WORKFLOW human-call table')
  const directTensho = workflow.replace('| **merge** |', '| **tensho** | action | reason |\n| **merge** |')
  expect(directTensho).not.toBe(workflow)
  expect(() => checkHumanCalls(directTensho)).toThrow()
})

test('a WORKFLOW-only Ren skill change and a relocated Build table fail', () => {
  const changed = workflow.replace('→ `rasengan` (**author the change**)', '→ `new-phase` (**author the change**)')
  expect(changed).not.toBe(workflow)
  expect(() => checkStages(build, changed)).toThrow()
  const moved = build.replace('| Phase | Skill | What build takes from it |', '## Other protocol\n\n| Phase | Skill | What build takes from it |')
  expect(moved).not.toBe(build)
  expect(() => checkStages(moved)).toThrow('the Build phase table')
})

test('moving a stage skill to neutral cannot mask drift', () => {
  const changed = STAGES.map(stage => stage.name === 'en'
    ? { ...stage, skills: stage.skills.filter(skill => skill !== 'sharingan') }
    : stage)
  expect(() => checkStages(build, workflow, changed, [...STAGE_NEUTRAL, 'sharingan'])).toThrow()
  expect(() => checkStages(build, workflow, changed)).toThrow()
})

test('new En actions fail, including prose-led actions and existing neutral skills', () => {
  for (const action of ['verify the current head with `verify-pr`', '`hanten`']) {
    const changed = workflow.replace('→ **observe⁵', `→ ${action} → **observe⁵`)
    expect(changed).not.toBe(workflow)
    expect(() => checkStages(build, changed)).toThrow()
  }
})
