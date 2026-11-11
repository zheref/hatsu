import { test } from 'node:test'
import { checkDeskRegistrationLauncher } from './desk_registration_ci_fixture.mts'

test('registration launcher admits only staged desk inputs and gates engine results', checkDeskRegistrationLauncher)
