import { test } from 'node:test'
import { actionsCases } from './actions.cases.ts'
import { chipCases } from './chip.cases.ts'
import { namingCases } from './naming.cases.ts'
import { stagesCases } from './stages.cases.ts'

// Replay Vitest's behavior cases for native, exact-source LCOV.
for (const cases of [actionsCases, chipCases, namingCases, stagesCases]) cases(test)
