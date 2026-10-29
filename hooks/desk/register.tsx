// The Hatsu desk: a pane beside the chat that mirrors where this session's effort stands in the
// canon and every path the maintainer can take from it, the gates waiting on them, and the other
// sessions' efforts read from the shared nen ledgers. Claude Code's function-hook module, named in
// hooks/hooks.json under `modules`; it switches on only in a checkout that declares nen/workflow.json,
// reads through nen, git and two cached read-only `gh pr list` queries (this branch's PR, every
// branch's newest), and never writes, pushes or merges: every button
// fills the prompt with a skill call for the maintainer to send (actions.ts holds the canon matrix).

import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register, RenderChildren } from 'claude-code'

import type { Activity, Effort, Gate, Pr, SessionEffort } from './state'
import { HUMAN_FLAG, glyphOf, readingOf, stepFor } from './actions'
import { chip } from './chip'
import { STAGES, isStageDone, progressOf, stageOf, stateOf } from './stages'
import type { ChipIcon, ChipSize, ChipStyle, Tone } from './chip'
import { ago, humanize, parseEffort, repoCode, safeBase, short, worktreeName } from './naming'

const PANE = 'hatsu-desk'
const TITLE = 'Hatsu desk'
const REFRESH_MS = 30_000
const PR_REFRESH_MS = 120_000
const STALE_MIN = 30
// How far back other sessions' ledgers are listed: a week, so a sitting from a day or two ago still shows.
const WINDOW_MIN = 7 * 24 * 60
const MAX_EFFORTS = 12
// A command that moves the effort forces a re-read, at most this often.
const FORCED_MIN_MS = 10_000

const session = atom({ plugin: 'hatsu', key: 'deskSession' } as const, null)
const efforts = atom({ plugin: 'hatsu', key: 'deskEfforts' } as const, [])
const gates = atom({ plugin: 'hatsu', key: 'deskGates' } as const, [])
const activity = atom({ plugin: 'hatsu', key: 'deskActivity' } as const, [])
const edits = atom({ plugin: 'hatsu', key: 'deskEdits' } as const, 0)
const showOthers = atom({ plugin: 'hatsu', key: 'deskShowOthers' } as const, false)
const openActivity = atom({ plugin: 'hatsu', key: 'deskOpenActivity' } as const, [])
const usd = atom({ plugin: 'hatsu', key: 'deskUsd' } as const, null)
const contextPercent = atom({ plugin: 'hatsu', key: 'deskContextPercent' } as const, null)
const updatedAt = atom({ plugin: 'hatsu', key: 'deskUpdatedAt' } as const, 0)
const failure = atom({ plugin: 'hatsu', key: 'deskError' } as const, null)

type Phase = { phase: string; startedAt: string; endedAt?: string | null; exitCode?: number | null; note?: string | null }
type StopRow = { gate?: string | null; effort?: string | null; at: string; title?: string | null }
type Where = { top: string; common: string; base: string }

// Module variables: a reload re-runs session.start, which sets them again.
let where: Where | null = null
let repo: SessionEffort['repo'] = null
let pr: Pr | null = null
let prReadAt = 0
// Every branch's newest PR in the repository, read in one call and cached like this session's own.
let branchPrs = new Map<string, { number: number; state: string }>()
let branchPrsReadAt = 0
const toasted = new Set<string>()
// The refresh in flight, so overlapping triggers share one read; and when a command last forced one.
let refreshing: Promise<void> | null = null
let forcedAt = 0
// A spawned subagent's id → its activity row: the spawn resolves once it started, its turn.complete ends it.
const spawned = new Map<string, string>()

// The next-step box's fill, a step above the desktop's dark background and below its button grey.
// Its round border is drawn in the same colour: the corners stay rounded with no visible outline.
const STEP_FILL = '#2B2B29'

const minutesSince = (iso: string, now: number) => Math.max(0, Math.round((now - Date.parse(iso)) / 60_000))

async function run($: EngineInterface, argv: string[]): Promise<{ code: number; out: string; err: string }> {
  const r = await $.process.run(argv, { cwd: where?.top, timeoutMs: 15_000 })

  return { code: r.exitCode, out: r.stdout, err: r.stderr }
}

async function json($: EngineInterface, argv: string[]): Promise<unknown> {
  const r = await run($, argv)
  if (r.code !== 0) {
    throw new Error(`${argv.slice(0, 3).join(' ')} exited ${r.code}: ${short(r.err.trim(), 160)}`)
  }

  return JSON.parse(r.out) as unknown
}

async function readRepo($: EngineInterface): Promise<void> {
  if (where === null || repo !== null) {
    return
  }
  const resolved = repoCode((await run($, ['nen', 'repo', 'resolve', '--from', where.top])).out)
  const classified = await run($, ['nen', 'repo', 'classify', '--repo', where.top, '--json'])
  let role: string | null = null
  let kind: string | null = null
  if (classified.code === 0) {
    const c = JSON.parse(classified.out) as { role?: string; kind?: string }
    role = c.role ?? null
    kind = c.kind ?? null
  }
  repo = resolved ? { ...resolved, role, kind } : null
}

// No nen verb finds a branch's PR; this is a read-only gh query, cached for two minutes.
async function readPr($: EngineInterface, branch: string, now: number): Promise<void> {
  if (now - prReadAt < PR_REFRESH_MS) {
    return
  }
  prReadAt = now
  const r = await run($, [
    'gh', 'pr', 'list', '--head', branch, '--state', 'all', '--limit', '1',
    '--json', 'number,state,title,url,isDraft,labels',
  ])
  if (r.code === 0) {
    const list = JSON.parse(r.out) as Pr[]
    pr = list[0] ?? null
  }
}

// No nen verb lists a repository's PRs by branch either; one read-only gh query covers every card.
async function readBranchPrs($: EngineInterface, now: number): Promise<void> {
  if (now - branchPrsReadAt < PR_REFRESH_MS) {
    return
  }
  branchPrsReadAt = now
  const r = await run($, ['gh', 'pr', 'list', '--state', 'all', '--limit', '200', '--json', 'number,state,headRefName'])
  if (r.code === 0) {
    const list = JSON.parse(r.out) as { number: number; state: string; headRefName: string }[]
    // The list is newest first: keep each branch's newest PR.
    branchPrs = new Map()
    for (const p of list) {
      if (!branchPrs.has(p.headRefName)) branchPrs.set(p.headRefName, { number: p.number, state: p.state })
    }
  }
}

function refresh($: EngineInterface): Promise<void> {
  refreshing ??= read_($).finally(() => {
    refreshing = null
  })

  return refreshing
}

async function read_($: EngineInterface): Promise<void> {
  if (where === null) {
    return
  }

  const now = await $.clock.now()
  try {
    await readRepo($)

    const wc = (await json($, ['nen', 'wc', 'classify', '--repo', where.top, '--base', where.base, '--json'])) as {
      state: { branch: string | null; aheadOfBase: number; uncommittedPaths: string[]; existingCommitSubjects?: string[] }
    }
    const branch = wc.state.branch ?? '(detached)'
    const upstream = await run($, ['git', 'rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}'])
    await readPr($, branch, now)
    await readBranchPrs($, now)

    const mine = parseEffort(branch)

    // Every phase ledger touched in the window; the one for this branch is this session's.
    const dir = `${where.common}/.nen/phases`
    const entries = (await $.fs.exists(dir)) ? await $.fs.list(dir) : []
    const recent = entries
      .filter(e => e.kind === 'file' && e.name.endsWith('.json'))
      .filter(e => (now - e.mtimeMs) / 60_000 < WINDOW_MIN)
      .sort((a, b) => b.mtimeMs - a.mtimeMs)
      .slice(0, MAX_EFFORTS + 1)

    // Which ledgered efforts are local branches, and which of those a worktree has checked out.
    const heads = new Set((await run($, ['git', '-C', where.top, 'for-each-ref', 'refs/heads', '--format=%(refname:short)'])).out.split('\n').filter(Boolean))
    const checkedOut = new Map<string, string>()
    let path: string | null = null
    for (const line of (await run($, ['git', '-C', where.top, 'worktree', 'list', '--porcelain'])).out.split('\n')) {
      if (line.startsWith('worktree ')) path = line.slice('worktree '.length)
      else if (line.startsWith('branch refs/heads/') && path !== null) checkedOut.set(line.slice('branch refs/heads/'.length), path)
    }

    const core = where.common.endsWith('/.git') ? where.common.slice(0, -'/.git'.length) : where.top
    const repoFolder = core.slice(core.lastIndexOf('/') + 1)

    // The gates first, so another effort's unreadable ledger never silences one waiting on you.
    const stops = (await json($, ['nen', 'stop', 'list', '--repo', where.top, '--json'])) as { marks?: StopRow[] }

    // No nen verb lists the ledgers (nen phase has begin/end/show; zheref/nen#583), so the directory is listed and each
    // file name decoded to its effort id, then read through `nen phase show`. Each ledger is read on
    // its own: a truncated, newer-schema or oddly named file is skipped and named, never fatal.
    let myPhases: string[] = []
    const others: Effort[] = []
    const skipped: string[] = []
    for (const entry of recent) {
      let id: string
      let phases: Phase[]
      try {
        id = decodeURIComponent(entry.name.slice(0, -'.json'.length))
        phases = ((await json($, ['nen', 'phase', 'show', '--effort', id, '--repo', where.top, '--json'])) as { phases?: Phase[] }).phases ?? []
      } catch {
        skipped.push(entry.name)
        continue
      }
      const name = parseEffort(id)
      if (id === branch || (mine.ref !== null && name.ref === mine.ref)) {
        myPhases = phases.map(p => p.phase)
        continue
      }
      const last = phases[phases.length - 1]
      if (last === undefined) {
        continue
      }
      const isOpen = !last.endedAt
      const ageMin = minutesSince(isOpen ? last.startedAt : (last.endedAt as string), now)
      others.push({
        id,
        ...name,
        phase: last.phase,
        isOpen,
        isStale: isOpen && ageMin >= STALE_MIN,
        ageMin,
        exitCode: last.exitCode ?? null,
        note: last.note ?? null,
        phases: phases.map(p => p.phase),
        records: phases.map(p => ({
          phase: p.phase,
          at: Date.parse(p.startedAt),
          isOpen: !p.endedAt,
          exitCode: p.exitCode ?? null,
          note: p.note ?? null,
        })),
        branch: heads.has(id) || checkedOut.has(id) ? id : null,
        worktree: checkedOut.has(id) ? worktreeName(checkedOut.get(id)!, repoFolder) : null,
        pr: branchPrs.get(id) ?? null,
      })
    }

    const waiting: Gate[] = (stops.marks ?? []).map(m => ({
      gate: m.gate ?? 'stop',
      effort: m.effort ?? null,
      effortTitle: m.effort ? parseEffort(m.effort).title : null,
      at: m.at,
      title: m.title ?? null,
    }))
    for (const g of waiting) {
      const key = `${g.gate}@${g.effort}@${g.at}`
      if (!toasted.has(key)) {
        toasted.add(key)
        $.ui.toast(`${g.gate} is waiting on you: ${short(g.title ?? g.effortTitle ?? 'a stop', 80)}`)
      }
    }

    const mineNow: SessionEffort = {
      branch,
      title: pr?.title ?? mine.title,
      ref: mine.ref,
      repo,
      dirty: wc.state.uncommittedPaths.length,
      ahead: wc.state.aheadOfBase,
      hasUpstream: upstream.code === 0,
      unpushed: upstream.code === 0 ? Number((await run($, ['git', '-C', where.top, 'rev-list', '--count', '@{u}..HEAD'])).out.trim()) || 0 : 0,
      pr,
      phases: myPhases,
      atGate: waiting.some(g => g.effort === branch && (g.gate === 'G2' || g.gate === 'G4')),
      nature: natureOf(pr, latestMode(await $.session.messages()), wc.state.existingCommitSubjects ?? [], wc.state.uncommittedPaths, repo),
    }

    const usage = await $.session.usage()
    await update($, usd, () => usage.cost?.usd ?? null)
    await update($, contextPercent, () => usage.context.percent ?? null)
    await update($, session, () => mineNow)
    await update($, efforts, () => others.slice(0, MAX_EFFORTS))
    await update($, gates, () => waiting)
    await update($, failure, () => (skipped.length > 0 ? `skipped ${skipped.length} unreadable ledger${skipped.length === 1 ? '' : 's'}: ${short(skipped.join(', '), 120)}` : null))
    const acts = await read($, activity)
    const at_ = stageOf(mineNow, acts, await read($, edits))
    $.ui.status(`Hatsu · ${STAGES[at_]!.name} (${stateOf(at_, mineNow, acts)})`)
  } catch (err) {
    await update($, failure, () => (err instanceof Error ? err.message : String(err)))
  }
  await update($, updatedAt, () => now)
}

const MODE_NATURE: Record<string, string> = {
  Enhancer: 'feature',
  Conjurer: 'governance',
  Transmuter: 'machinery',
  Manipulator: 'operations',
  Emitter: 'release',
  Specialist: 'product intake',
}

const COMMIT_NATURE: Record<string, string> = {
  feat: 'feature', fix: 'bugfix', refactor: 'refactor', perf: 'performance', docs: 'docs',
  test: 'tests', ci: 'devops', build: 'devops', chore: 'maintenance', style: 'redesign',
}

/** Kurapika names his work-mode in every reply; the newest one named is the session's. */
function latestMode(messages: { role: string; text: string }[]): string | null {
  const mode = new RegExp(`\\b(${Object.keys(MODE_NATURE).join('|')})\\b`)
  for (const message of [...messages].reverse()) {
    const found = message.role === 'assistant' ? mode.exec(message.text) : null
    if (found) return found[1]!
  }

  return null
}

// Strongest first: the PR's job/ label, the declared work-mode, the commits' Conventional type,
// the paths touched, and last the repository's own kind.
function natureOf(
  p: Pr | null,
  mode: string | null,
  subjects: string[],
  paths: string[],
  r: SessionEffort['repo'],
): SessionEffort['nature'] {
  const job = p?.labels?.find(l => l.name.startsWith('job/'))
  if (job) return { label: humanize(job.name.slice('job/'.length)).toLowerCase(), source: `label ${job.name}` }
  if (mode) return { label: MODE_NATURE[mode]!, source: `work-mode ${mode}` }
  const type = subjects.map(t => /^(\w+)(\(|!|:)/.exec(t)?.[1]).find(t => t && t in COMMIT_NATURE)
  if (type) return { label: COMMIT_NATURE[type]!, source: `commits typed ${type}` }
  if (paths.some(x => x.startsWith('.github/workflows/'))) return { label: 'devops', source: 'workflow paths' }
  if (paths.some(x => x.startsWith('scripts/') || x.startsWith('hooks/'))) return { label: 'machinery', source: 'script paths' }
  if (paths.some(x => x.startsWith('docs/') || x.startsWith('claude/'))) return { label: 'canon', source: 'canon paths' }

  return r?.kind ? { label: r.kind, source: 'repository kind' } : null
}

// Every action fills the prompt; the maintainer reads it and presses Enter.
async function fill($: EngineInterface, text: string): Promise<void> {
  await $.prompt.fill({ text, mode: 'replace' })
}

const EDIT_TOOLS = new Set(['Write', 'Edit', 'MultiEdit', 'NotebookEdit'])

async function track($: EngineInterface, act: Activity): Promise<void> {
  await update($, activity, list => (list.some(a => a.id === act.id) ? list : [...list, act].slice(-30)))
}

// Catch up on what the session did before the desk loaded, from the transcript's tool calls.
async function seed($: EngineInterface): Promise<void> {
  const known = new Set((await read($, activity)).map(a => a.id))
  const past: Activity[] = []
  let edited = 0
  for (const message of await $.session.messages()) {
    for (const use of message.toolUses) {
      const input = use.input
      if (use.tool === 'Skill' && typeof input.skill === 'string' && input.skill.startsWith('hatsu:')) {
        past.push({ id: use.tool_use_id, at: null, kind: 'skill', label: input.skill.slice('hatsu:'.length), detail: null, isDone: true })
      } else if (use.tool === 'Agent' && typeof input.subagent_type === 'string') {
        const detail = typeof input.description === 'string' ? input.description : null
        past.push({ id: use.tool_use_id, at: null, kind: 'agent', label: humanize(input.subagent_type.replace(/^.*:/, '')), detail, isDone: true })
      } else if (EDIT_TOOLS.has(use.tool)) {
        edited += 1
      }
    }
  }
  const fresh = past.filter(a => !known.has(a.id))
  await update($, activity, list => [...fresh, ...list].slice(-30))
  await update($, edits, n => Math.max(n, edited))
}

async function finish($: EngineInterface, id: string): Promise<void> {
  await update($, activity, list => list.map(a => (a.id === id ? { ...a, isDone: true } : a)))
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const git = await $.process.run(['git', 'rev-parse', '--path-format=absolute', '--show-toplevel', '--git-common-dir'])
    const [top, common] = git.stdout.trim().split('\n')
    // Only a Hatsu consumer gets the desk: one that declares nen/workflow.json.
    if (git.exitCode === 0 && top && common && (await $.fs.exists(`${top}/nen/workflow.json`))) {
      // Whatever the desk's own start-up does, the session starts: a fault is shown, never thrown.
      try {
        let base = 'main'
        try {
          const workflow = JSON.parse(await $.fs.read(`${top}/nen/workflow.json`)) as { branch?: { base?: unknown } }
          base = safeBase(workflow.branch?.base)
        } catch {
          // An unreadable workflow file keeps the default base.
        }
        where = { top, common, base }
        await $.command.register({ name: 'hatsu-desk', description: 'Open the Hatsu desk' })
        await seed($)
        await refresh($)
        $.clock.every(REFRESH_MS, () => void refresh($))
        void $.ui.open({ id: PANE, title: TITLE })
      } catch (err) {
        await update($, failure, () => (err instanceof Error ? err.message : String(err)))
      }
    }

    return next(e)
  })

  on('command.run', { command: 'hatsu-desk' }, async $ => {
    await refresh($)
    await $.ui.open({ id: PANE, title: TITLE })

    return { text: 'Hatsu desk opened.' }
  })

  // Live: Hatsu skill calls and subagents land in the activity feed as they happen.
  on('tool.call', async ($, e, next) => {
    if (where !== null && e.tool === 'Skill' && e.skill.startsWith('hatsu:')) {
      await track($, { id: e.tool_use_id, at: await $.clock.now(), kind: 'skill', label: e.skill.slice('hatsu:'.length), detail: null, isDone: true })
    }
    const result = await next(e)
    if (where !== null && EDIT_TOOLS.has(e.tool)) {
      await update($, edits, n => n + 1)
    }
    if (where !== null && e.tool === 'Bash' && /\b(nen (phase|stop|wc|pr)|git (commit|push)|gh pr)\b/.test(e.command)) {
      const now = await $.clock.now()
      if (now - forcedAt >= FORCED_MIN_MS) {
        forcedAt = now
        prReadAt = 0
        branchPrsReadAt = 0
        void refresh($)
      }
    }

    return result
  })
    // The desk only watches tool calls: a fault of its own fails open and never stands in a call's way.
    // `next` is replay-safe here (the engine's Caught): a call already made settles to its own result.
    .catch(($, e, next) => next(e))

  on('agent.spawn', async ($, e, next) => {
    if (where === null) {
      return next(e)
    }
    const who = humanize(e.subagentType.replace(/^.*:/, ''))
    await track($, { id: e.tool_use_id, at: await $.clock.now(), kind: 'agent', label: who, detail: e.description, isDone: false })
    const result = await next(e)
    // The spawn resolves once the subagent started; it is done at its own turn.complete.
    if ('agentId' in result && result.agentId) {
      spawned.set(result.agentId, e.tool_use_id)
    } else {
      await finish($, e.tool_use_id)
    }

    return result
  })
    // Likewise for a subagent: the spawn goes on whatever the desk's own bookkeeping did.
    .catch(($, e, next) => next(e))

  on('turn.complete', async ($, e, next) => {
    const id = e.agentId ? spawned.get(e.agentId) : undefined
    if (id !== undefined) {
      spawned.delete(e.agentId!)
      await finish($, id)
    }

    return next(e)
  })
    .catch(($, e, next) => next(e))

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const waiting = await read($, gates)
    const first = waiting[0]
    if (where === null || e.props.hasSurvey || first === undefined) {
      return next(e)
    }

    const { Box, Button, Text } = $.ui.resolve(e)

    return (
      <Box gap={1} alignItems="center">
        <Text backgroundColor="warning" color="inverseText" bold>
          {` ${first.gate} `}
        </Text>
        <Text>
          {waiting.length === 1 ? 'A gate is waiting on you' : `${waiting.length} gates are waiting on you`}
          {' · '}
          {short(first.title ?? first.effortTitle, 60)}
        </Text>
        <Button key="open" label="Open desk" plain onPress={() => $.ui.open({ id: PANE, title: TITLE })} />
      </Box>
    )
  })


  // Hierarchy by colour: this session is the accent, gates are a warning, other sessions recede.
  // Code names (branches, effort ids, skills, phases) are monospace tags; facts are coloured pills.
  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const ui = $.ui.resolve(e)
    const { Box, Button, Link, Text } = ui
    const Svg = 'Svg' in ui ? ui.Svg : null
    const s = await read($, session)
    const acts = await read($, activity)
    const edited = await read($, edits)
    const others = await read($, efforts)
    const waiting = await read($, gates)
    const expanded = await read($, showOthers)
    const opened = new Set(await read($, openActivity))
    const spend = await read($, usd)
    const ctx = await read($, contextPercent)
    const error = await read($, failure)
    const at = await read($, updatedAt)

    const Chip = (p: { text: string; tone: Tone; minor?: string; mono?: boolean; bold?: boolean; icons?: ChipIcon[]; style?: ChipStyle; size?: ChipSize }) => {
      if (Svg === null) {
        return (
          <Text backgroundColor={p.tone === 'muted' ? 'subtle' : p.tone === 'code' ? 'subtle' : 'claude'} color="inverseText" mono={p.mono}>
            {` ${p.icons?.includes('done') ? '✓ ' : ''}${p.icons?.includes('progress') ? '◐ ' : ''}${p.icons?.includes('person') ? '👤 ' : ''}${p.text}${p.minor ? ` ${p.minor}` : ''} `}
          </Text>
        )
      }
      const c = chip(p.text, p.tone, { minor: p.minor, mono: p.mono, bold: p.bold, icons: p.icons, style: p.style, size: p.size })
      return <Svg source={c.source} alt={c.alt} width={c.width} height={c.height} />
    }
    const Pill = (p: { text: string; tone: Tone }) => <Chip text={p.text} tone={p.tone} />
    const Tag = (p: { text: string }) => <Chip text={p.text} tone="code" mono />
    const Section = (p: { title: string; tone: string; count?: number; hint?: string }) => (
      <Box gap="xs" alignItems="center">
        <Text size="footnote" weight="bold" color={p.tone}>{p.title.toUpperCase()}</Text>
        {p.count !== undefined && <Text size="footnote" dimColor tabular>{p.count}</Text>}
        {p.hint && <Text size="caption" dimColor>{p.hint}</Text>}
      </Box>
    )
    const Label = (p: { text: string }) => (
      <Text size="caption" weight="semibold" dimColor>{p.text}</Text>
    )
    const clock = (t: number | null) =>
      t === null ? 'earlier' : new Date(t).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
    // A time today reads as the clock; an older one carries its day.
    const stamp = (t: number | null) =>
      t !== null && new Date(t).toDateString() !== new Date(at || t).toDateString()
        ? `${new Date(t).toLocaleDateString([], { month: 'short', day: 'numeric' })} ${clock(t)}`
        : clock(t)

    // One activity record, the same in this session's box and in every other session's card:
    // the state glyph, when, the skill or persona as a tag, what it was doing, then its detail.
    type Row = { key: string; at: number | null; state: 'done' | 'running' | 'failed'; reading: string; detail: string | null }
    const ActivityList = (p: { id: string; rows: Row[]; empty: string; trailing?: RenderChildren }) => {
      const isOpen = opened.has(p.id)
      return (
        <Box flexDirection="column" gap="xs">
          <Box gap={1} alignItems="center" justifyContent="space-between">
            <Box gap="xs" alignItems="center">
              <Label text="Activity" />
              <Text size="footnote" dimColor tabular>{p.rows.length}</Text>
              <Button
                key={`activity-${p.id}`}
                label={isOpen ? 'Hide ▴' : 'Show ▾'}
                plain
                onPress={() => update($, openActivity, ids => (ids.includes(p.id) ? ids.filter(i => i !== p.id) : [...ids, p.id]))}
              />
            </Box>
            {p.trailing}
          </Box>
          {isOpen && p.rows.length === 0 && <Text size="caption" dimColor>{p.empty}</Text>}
          {isOpen &&
            [...p.rows].reverse().map(r => (
              <Box key={r.key} gap="xs" alignItems="flex-start">
                <Text color={r.state === 'done' ? 'success' : r.state === 'failed' ? 'error' : 'claude'}>
                  {r.state === 'done' ? '✓' : r.state === 'failed' ? '✗' : '◐'}
                </Text>
                <Box flexShrink={0}>
                  <Text size="caption" dimColor tabular wrap="truncate">{stamp(r.at)}</Text>
                </Box>
                <Box flexShrink={0}>
                  <Chip text={r.reading} tone={r.state === 'failed' ? 'warning' : r.state === 'running' ? 'accent' : 'code'} style={r.state === 'running' ? 'dotted' : 'fill'} />
                </Box>
                {r.detail && (
                  <Box flexShrink={1}>
                    <Text size="caption" dimColor wrap="wrap">{r.detail}</Text>
                  </Box>
                )}
              </Box>
            ))}
        </Box>
      )
    }

    if (where === null || s === null) {
      return (
        <Box flexDirection="column" padding="xs" gap="xs">
          <Text dimColor>{where === null ? 'This folder is not a Hatsu consumer: it has no nen/workflow.json.' : 'Reading the ledgers…'}</Text>
          {error && <Text color="error">{error}</Text>}
        </Box>
      )
    }

    const stage = stageOf(s, acts, edited)
    // Where the effort runs: the main checkout, the worktree inside it (if any), the branch.
    const home = (path: string) => path.replace(/^\/(Users|home)\/[^/]+/, '~')
    const checkout = where.common.endsWith('/.git') ? where.common.slice(0, -'/.git'.length) : where.top
    const worktree = where.top !== checkout ? where.top.slice(where.top.lastIndexOf('/') + 1) : null
    const gateOfMerge = s.repo?.role === 'canon' ? 'G4' : 'G2'
    const step = stepFor({
      dirty: s.dirty,
      ahead: s.ahead,
      hasUpstream: s.hasUpstream,
      unpushed: s.unpushed ?? 0,
      pr: s.pr,
      ref: s.ref,
      code: s.repo?.code ?? '',
      gate: gateOfMerge,
      base: where.base,
      ...progressOf(s, acts, edited),
    })
    const reading = stateOf(stage, s, acts)

    return (
      <Box flexDirection="column" padding="xs" gap={1}>
        {/* Header: the repository */}
        <Box justifyContent="space-between" alignItems="center">
          <Box gap="xs" alignItems="center">
            {s.repo && <Pill text={s.repo.code} tone="accent" />}
            <Tag text={s.repo?.slug ?? where.top} />
            {s.repo?.role && <Text size="caption" dimColor>{s.repo.role}{s.repo.kind ? ` · ${s.repo.kind}` : ''}</Text>}
          </Box>
          <Box gap="xs" alignItems="center">
            {at > 0 && <Text size="caption" dimColor>read {clock(at)}</Text>}
            <Button key="refresh" label="↻ Refresh" plain onPress={() => refresh($)} />
          </Box>
        </Box>
        {error && <Text color="error">Could not read everything: {error}</Text>}

        {/* Level 1 — this session's effort */}
        <Box flexDirection="column" borderStyle="round" borderColor="claude" paddingX={1} paddingY={1} gap={1}>
          <Box flexDirection="column" gap="xs">
            <Box gap={1} alignItems="center" justifyContent="space-between">
              <Box gap="xs" flexWrap="wrap" alignItems="center">
                <Text size="caption" dimColor>Path</Text>
                <Tag text={home(checkout)} />
                {worktree && <Text size="caption" dimColor>Worktree</Text>}
                {worktree && <Tag text={worktree} />}
                <Text size="caption" dimColor>Branch</Text>
                <Tag text={s.branch} />
              </Box>
              <Chip text="This session" tone="code" size="md" bold />
            </Box>
            <Box gap={1} alignItems="center" justifyContent="space-between">
              <Box gap={1} alignItems="center" flexWrap="wrap">
                <Text size="title" weight="bold">{s.title}</Text>
                {s.nature && <Chip text={s.nature.label} tone="info" size="md" />}
              </Box>
              <Chip text={reading} tone="accent" size="lg" bold style="dotted" />
            </Box>
            <Box gap="xs" flexWrap="wrap" alignItems="center">
              {s.ref && <Pill text={s.ref} tone="ref" />}
              {s.pr && <Pill text={`PR #${s.pr.number} · ${s.pr.isDraft ? 'draft' : s.pr.state.toLowerCase()}`} tone={s.pr.state === 'MERGED' ? 'merged' : 'success'} />}
            </Box>
            <Text size="caption" dimColor>
              {s.dirty > 0 ? `${s.dirty} uncommitted` : 'nothing uncommitted'}
              {` · ${s.ahead} commit${s.ahead === 1 ? '' : 's'} ahead of `}
              <Text mono size="caption">{where.base}</Text>
              {s.hasUpstream ? ' · pushed' : ' · not pushed'}
              {edited > 0 ? ` · ${edited} file edit${edited === 1 ? '' : 's'} this session` : ''}
              {spend !== null ? ` · $${spend.toFixed(2)} spent` : ''}
              {ctx !== null ? ` · context ${Math.round(ctx)}% full` : ''}
            </Text>
          </Box>

          {/* The effort's timeline */}
          <Box flexDirection="column" gap="xs">
            <Box gap="xs" flexWrap="wrap" alignItems="center">
              {STAGES.map((st, i) => {
                const isDone = isStageDone(i, stage, s)
                return (
                <Box key={`stage-${i}`} gap="xs" alignItems="center">
                  <Chip
                    text={st.name === 'gate' ? gateOfMerge : st.name}
                    minor={st.meaning}
                    tone={isDone ? 'done' : i === stage ? 'accent' : 'muted'}
                    bold={i === stage}
                    icons={[...(isDone ? (['done'] as const) : i === stage ? (['progress'] as const) : []), ...(st.name === 'gate' ? (['person'] as const) : [])]}
                    style={isDone ? 'fill' : i === stage ? 'dotted' : 'outline'}
                  />
                  {i < STAGES.length - 1 && <Text color="inactive">›</Text>}
                </Box>
                )
              })}
            </Box>
          </Box>

          {/* The recommended next step */}
          <Box flexDirection="column" borderStyle="round" borderColor={STEP_FILL} backgroundColor={STEP_FILL} paddingX={1} paddingY={1} gap="xs">
            <Box flexDirection="column">
              <Box gap={1} alignItems="center" justifyContent="space-between">
                <Text size="heading" weight="semibold">{step.headline}</Text>
                <Chip text="Next step" tone="info" style="line" />
              </Box>
              <Text size="caption" dimColor>{step.why}</Text>
            </Box>
            <Box gap={1} alignItems="center" flexWrap="wrap">
              {step.paths.map(path => (
                path.blocked === null ? (
                  <Button
                    key={`path-${path.prompt}`}
                    label={[path.isPrimary ? glyphOf(path.prompt) : null, path.label, path.isHumanCall ? HUMAN_FLAG : null].filter(Boolean).join(' ')}
                    variant={path.isPrimary ? 'primary' : 'secondary'}
                    onPress={() => fill($, path.prompt)}
                  />
                ) : Svg === null ? (
                  <Button
                    key={`path-${path.prompt}`}
                    label={path.label}
                    dimColor
                    onPress={() => $.ui.toast(`${path.label}: ${path.blocked}`)}
                  />
                ) : (
                  // The desktop's native button ignores a text colour, so a blocked path is drawn in its
                  // place: the button's grey with near-black text. Its reason is the image's alt text.
                  (() => {
                    const c = chip([path.label, path.isHumanCall ? HUMAN_FLAG : null].filter(Boolean).join(' '), 'blocked', { size: 'button' })
                    return <Svg key={`path-${path.prompt}`} source={c.source} alt={`${path.label}: ${path.blocked}`} width={c.width} height={c.height} />
                  })()
                )
              ))}
              {s.pr && <Link key="pr" href={s.pr.url} label="Open the PR on GitHub ↗" />}
            </Box>
          </Box>

          {/* What this session did */}
          <ActivityList
            id="session"
            empty="No Hatsu skill or reviewer has run in this session yet."
            rows={acts.map(a => ({
              key: `act-${a.id}`,
              at: a.at,
              state: a.isDone ? 'done' : 'running',
              reading: a.kind === 'skill' ? readingOf(a.label, a.isDone) : `${a.label} ${a.isDone ? 'reviewed' : 'reviewing'}`,
              detail: a.detail,
            }))}
          />
        </Box>

        {/* Level 2 — gates waiting on the maintainer */}
        <Box flexDirection="column" gap="xs">
          <Section title="Waiting on you" tone="warning" count={waiting.length} hint={waiting.length === 0 ? 'nothing right now' : undefined} />
          {waiting.map((g, i) => (
            <Box key={`gate-${i}`} flexDirection="column" borderStyle="round" borderColor="warning" paddingX={1} paddingY="xs" gap="xs">
              <Box gap="xs" alignItems="center" flexWrap="wrap">
                <Pill text={g.gate} tone="warning" />
                <Text weight="semibold">{g.effortTitle ?? 'Unnamed effort'}</Text>
                <Text size="caption" dimColor>· waiting {ago(minutesSince(g.at, at || Date.parse(g.at)))}</Text>
              </Box>
              {g.effort && <Tag text={g.effort} />}
              {g.title && <Text size="caption">{short(g.title, 160)}</Text>}
              {g.gate === 'G3' ? (
                <Text size="caption" dimColor>Publishing is a typed go: type it yourself.</Text>
              ) : (
                <Box>
                  <Button
                    key={`answer-${i}`}
                    label="Show me this stop"
                    variant="secondary"
                    // By reference only: the stop's title is read by the skill, never copied into the prompt.
                    onPress={() => fill($, `Take me to the ${g.gate} stop on effort ${g.effort ?? '(none)'}: show the question and its options.`)}
                  />
                </Box>
              )}
            </Box>
          ))}
        </Box>

        {/* Level 3 — other sessions' efforts, folded until asked for */}
        <Box flexDirection="column" gap="xs">
          <Box justifyContent="space-between" alignItems="center">
            <Section
              title="Other sessions"
              tone="subtle"
              count={others.length}
              hint={others.some(o => o.isStale) ? `${others.filter(o => o.isStale).length} look stuck` : undefined}
            />
            {others.length > 0 && (
              <Button key="others" label={expanded ? 'Hide ▴' : 'Show ▾'} plain onPress={() => update($, showOthers, v => !v)} />
            )}
          </Box>
          {others.length === 0 && (
            <Text size="caption" dimColor>
              No other effort has recorded a phase in the last {WINDOW_MIN / 1440} days.
            </Text>
          )}
          {expanded &&
            others.map(o => {
              // The same three rows as this session's box: who and where on top with the status on
              // the right, the title with its phase as the state chip, then the history and the action.
              // What the session is doing now comes from its ledger; where the work stands, from its PR.
              const prNo = o.pr ? ` · #${o.pr.number}` : ''
              const status: { text: string; tone: Tone; icons: ChipIcon[] } = o.isStale
                ? { text: 'Stuck', tone: 'warning', icons: [] }
                : o.isOpen
                  ? { text: 'Running', tone: 'accent', icons: ['progress'] }
                  : o.pr?.state === 'MERGED'
                    ? { text: `Merged${prNo}`, tone: 'merged', icons: ['done'] }
                    : o.pr?.state === 'CLOSED'
                      ? { text: `Closed${prNo}`, tone: 'muted', icons: [] }
                      : o.pr?.state === 'OPEN'
                        ? { text: `PR open${prNo}`, tone: 'info', icons: [] }
                        : o.exitCode
                          ? { text: `Stopped · exit ${o.exitCode}`, tone: 'warning', icons: [] }
                          : { text: 'Idle', tone: 'muted', icons: [] }
              return (
                <Box key={`effort-${o.id}`} flexDirection="column" borderStyle="round" borderColor={o.isStale ? 'warning' : 'inactive'} paddingX={1} paddingY={1} gap="xs">
                  <Box gap={1} alignItems="center" justifyContent="space-between">
                    <Box gap="xs" flexWrap="wrap" alignItems="center">
                      {o.worktree && <Text size="caption" dimColor>Worktree</Text>}
                      {o.worktree && <Tag text={o.worktree} />}
                      <Text size="caption" dimColor>{o.branch ? 'Branch' : 'Effort'}</Text>
                      <Tag text={o.id} />
                    </Box>
                    <Chip text={status.text} tone={status.tone} icons={status.icons} size="md" bold />
                  </Box>
                  <Box gap={1} alignItems="center" justifyContent="space-between">
                    <Box gap="xs" flexWrap="wrap" alignItems="center">
                      <Text size="heading" weight="semibold">{o.title}</Text>
                      {o.surface && <Pill text={o.surface} tone="surface" />}
                      {o.model && <Pill text={o.model} tone="accent" />}
                      {o.persona && <Pill text={o.persona} tone="info" />}
                    </Box>
                    <Chip
                      text={readingOf(o.phase, !o.isOpen)}
                      minor={o.isOpen ? `for ${ago(o.ageMin)}` : `${ago(o.ageMin)} ago`}
                      tone={o.isStale ? 'warning' : o.isOpen ? 'accent' : 'muted'}
                      style={o.isOpen ? 'dotted' : 'fill'}
                      mono
                      bold
                    />
                  </Box>
                  <ActivityList
                    id={o.id}
                    empty="No phase recorded."
                    rows={(o.records ?? []).map((r, i) => ({
                      key: `phase-${o.id}-${i}`,
                      at: r.at,
                      state: r.isOpen ? 'running' : r.exitCode ? 'failed' : 'done',
                      reading: readingOf(r.phase, !r.isOpen),
                      detail: r.exitCode ? `exit ${r.exitCode}${r.note ? ` · ${r.note}` : ''}` : r.note,
                    }))}
                    trailing={
                      <Box gap="xs" alignItems="center">
                        {o.ref && <Pill text={o.ref} tone="ref" />}
                        {o.isStale && (
                          <Button
                            key={`unstick-${o.id}`}
                            label="Unstick it"
                            variant="secondary"
                            onPress={() => fill($, `Effort ${o.id} has sat in its ${o.phase} phase for ${ago(o.ageMin)} with no end recorded. Find what it is waiting on and either resume it or end the phase with its real exit.`)}
                          />
                        )}
                      </Box>
                    }
                  />
                </Box>
              )
            })}
        </Box>
      </Box>
    )
  })
}
