import { expect, test } from 'claude-code/testing'

// The module's own wiring, driven through the engine's kit: a Hatsu checkout at /r whose reads are
// answered by `answer`, every other read failing; state honours the engine's get/set protocol.
// Adapted from Phinks's hanten repros on the desk (refire, ledger, ledgername).
type Answer = (argv: string[]) => { exitCode: number; stdout: string; stderr: string } | null

function harness(on: any, opts: { answer?: Answer; ledgers?: string[]; hasWorkflow?: boolean; failSetOn?: string | null } = {}) {
  const state = new Map<string, { value: unknown; version: number }>()
  const opened: string[] = []
  on('process.run', (_$: any, e: any) => {
    const a: string[] = e.argv ?? []
    if (a[0] === 'git' && a.includes('--git-common-dir')) return { value: { exitCode: 0, stdout: '/r\n/r/.git\n', stderr: '' } }
    return { value: opts.answer?.(a) ?? { exitCode: 1, stdout: '', stderr: 'offline' } }
  })
  on('fs.exists', (_$: any, e: any) => ({ value: String(e.path).endsWith('nen/workflow.json') ? opts.hasWorkflow !== false : true }))
  on('fs.read', () => ({ value: '{"branch":{"base":"main"}}' }))
  on('fs.list', () => ({ value: (opts.ledgers ?? []).map((name, i) => ({ kind: 'file', name, mtimeMs: 999_000 - i })) }))
  on('state.get', (_$: any, e: any) => ({ value: state.get(e.key) ?? { value: undefined, version: 0 } }))
  on('state.set', (_$: any, e: any) => {
    if (e.key === opts.failSetOn) throw new Error(`state store unavailable for ${e.key}`)
    state.set(e.key, { value: e.value, version: (state.get(e.key)?.version ?? 0) + 1 })
    return { value: { isSet: true } }
  })
  on('ui.open', (_$: any, e: any) => {
    opened.push(e.id)
    // Not placed: no surface draws the pane, so no render outlives the test.
    return { value: { isPlaced: false } }
  })
  for (const n of ['command.register', 'clock.every', 'ui.status', 'ui.toast']) on(n, () => ({ value: undefined }))
  on('session.messages', () => ({ value: [] }))
  on('session.usage', () => ({ value: { context: { percent: 1 } } }))
  on('clock.now', () => ({ value: 1_000_000 }))
  on('session.start', (_$: any, e: any) => e)
  on('turn.complete', () => ({ text: '' }))

  return { state, opened }
}

// A gate written to state redraws the band above the prompt; let that redraw finish inside the test.
// The kit's runtime has a timer; the module's types (no DOM, no Node) do not declare one.
const settle = (_$: any) => new Promise(resolve => (globalThis as any).setTimeout(resolve, 50))

const ok = (o: unknown) => ({ exitCode: 0, stdout: typeof o === 'string' ? o : JSON.stringify(o), stderr: '' })
const mine = 'opus/kurapika/ha-1-thing'
const checkout: Answer = a => {
  if (a[0] === 'nen' && a[1] === 'wc') return ok({ state: { branch: mine, aheadOfBase: 1, uncommittedPaths: [] } })
  if (a[0] === 'nen' && a[1] === 'stop') return ok({ marks: [{ gate: 'G4', effort: mine, at: '1970-01-01T00:00:00Z', title: 'merge' }] })
  if (a[0] === 'nen' && a[1] === 'phase') return ok({ phases: [] })
  return null
}

test('a checkout without nen/workflow.json gets no desk', async ($: any, on: any) => {
  const { opened } = harness(on, { hasWorkflow: false })
  await $.session.start({ cwd: '/r' })
  expect(opened).toEqual([])
})

test('a desk fault after the tool ran never runs the tool a second time', async ($: any, on: any) => {
  harness(on, { failSetOn: 'deskEdits' })
  let runs = 0
  on('tool.call', () => {
    runs += 1
    return { result: { ok: true, runs } }
  })
  await $.session.start({ cwd: '/r' })
  try {
    await $.tool.call({ tool: 'Edit', tool_use_id: 'toolu_1', input: { file_path: '/r/a', old_string: 'a', new_string: 'b' } })
  } catch {
    // The call's own outcome is not the question; how often it ran is.
  }
  expect(runs).toBe(1)
})

test('a subagent is running until its own turn completes', async ($: any, on: any) => {
  const { state } = harness(on)
  on('agent.spawn', () => ({ model: 'opus', agentId: 'agent-1' }))
  await $.session.start({ cwd: '/r' })
  await $.agent.spawn({ subagentType: 'hatsu:phinks', description: 'hanten · phinks', prompt: 'review', tool_use_id: 'toolu_2' })
  const row = () => (state.get('deskActivity')?.value as { id: string; isDone: boolean }[]).find(a => a.id === 'toolu_2')
  expect(row()?.isDone).toBe(false)
  await $.turn.complete({ agentId: 'agent-1', answer: 'done', reason: 'answer', durationMs: 1, isAborted: false, turnId: 't1' })
  expect(row()?.isDone).toBe(true)
})

test('an unreadable foreign ledger leaves the session and its gates drawn', async ($: any, on: any) => {
  const { state } = harness(on, {
    ledgers: ['opus%2Fkurapika%2Fha-1-thing.json', 'someone-else.json'],
    answer: a => (a[1] === 'phase' && a.includes('someone-else') ? { exitCode: 2, stdout: '', stderr: 'ledger schema 9 not understood' } : checkout(a)),
  })
  await $.session.start({ cwd: '/r' })
  expect(state.get('deskSession')?.value).toBeTruthy()
  expect((state.get('deskSession')?.value as { atGate: boolean }).atGate).toBe(true)
  expect((state.get('deskGates')?.value as unknown[]).length).toBe(1)
  expect(String(state.get('deskError')?.value)).toContain('someone-else.json')
  await settle($)
})

test('a ledger whose name does not decode is skipped, not fatal', async ($: any, on: any) => {
  const { state } = harness(on, { ledgers: ['opus%2Fkurapika%2Fha-1-thing.json', '100%25-done%zz.json'], answer: checkout })
  await $.session.start({ cwd: '/r' })
  expect(state.get('deskSession')?.value).toBeTruthy()
  expect((state.get('deskGates')?.value as unknown[]).length).toBe(1)
  await settle($)
})
