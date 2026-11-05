// Vitest's positional arguments are substring filters over every test file it discovers, and CI
// checks the trusted base out beside the head at `.trusted/` (`.github/workflows/unit-tests.yml`), so
// `vitest run scripts/<fixture>.test.mts` also ran `.trusted/scripts/<fixture>.test.mts`: the base's copy,
// judged as if it were this tree's (HA-PR-#483, unit-tests runs 40369572869, 40371479933, 40372572954,
// 40377200586 — the `.trusted` copy of mechanical_conflicts_fixture failed on the runner's missing git
// identity while this tree's copy passed). The trusted runner is `.trusted/scripts/unit_tests_ci.mts`;
// the fixtures under review are this tree's, so the trusted checkout is never a test root here.
import { configDefaults, defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    // hooks/desk's tests import the engine's own kit ('claude-code/testing') and run under
    // `claude plugin test` on the desk-guard lane (scripts/desk_mod_test.sh), never under Vitest.
    exclude: [...configDefaults.exclude, '**/.trusted/**', 'hooks/desk/**'],
  },
});
