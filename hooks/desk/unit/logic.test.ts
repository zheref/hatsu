import { test } from 'vitest'
import { actionsCases } from './actions.cases.ts'
import { chipCases } from './chip.cases.ts'
import { namingCases } from './naming.cases.ts'
import { stagesCases } from './stages.cases.ts'

for (const cases of [actionsCases, chipCases, namingCases, stagesCases]) cases(test)
