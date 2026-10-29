### Added

- `hatsu:breath` § 4a adds the plan-time constitution check [HR-10](docs/ROSTER.md#hr-10) rules, narrowed by [HR-337](docs/ROSTER.md#hr-337). It runs once per new effort, after the base tip is proved and before `rasengan` writes a line, over the request (the issue body, the brief or the maintainer's words, saved under the effort's `.nen/`). It sits inside `ren`'s step 1, never a seventh step ([HR-58](docs/ROSTER.md#hr-58)).
  - **The list is the minimum to read, never the cap.** It always carries the gate floor (`CON-4`, `CON-5`, `CON-6`, `CON-7`, `CON-47` and HR-10), whatever the request says. The judgement may name any other clause as a conflict.
  - **The record** is the `breath` phase-ledger entry's note: `<begin note>; constitution-check: floor=…; listed=…; not-binding=…; dangling=…; CON at <tag> <sha>; <pass | none listed>`. It keeps the begin note because `nen phase end --note` replaces it. An empty `listed=` is `none listed`, never `pass`.
  - **A conflict** is the new G5 row `constitution-conflict` in `nen/decisions.json`. Its exits are **A** change the plan (starred), **B** amend the CON clause (a `CON-15` PR in the constitution's repository) and **C** amend the HR row (a ROSTER ruling). B and C end the effort held; a new effort runs the check after the amendment merges.
  - **A check that did not run** (exit `2`) is row `capability-unavailable`, parked `g5-capability-unavailable` when idle. The `breath` entry is left open, so the row's **A** resumes it with `nen phase begin --resume` and the check runs again.
  - Closes #505.
- `scripts/constitution_check.mts` (lane `constitution-check`, with a `node_modules/vitest` path precondition) is the deterministic half of the check. Its CI gate in `scripts/unit_tests_ci.mts` takes effect only after merge, because `unit-tests.yml` runs the base's trusted copy.
  - **What it lists:** the floor, every HR and CON id the request cites, every binding HR row whose definition line names a skill the request names, and every row a `reversed by` / `superseded by` status points to. Each comes with `whole`, `part` or `none` from `scripts/clause_id_guard.mts`'s imported parser.
  - **How it reads CON:** `CONSTITUTION.md` is read through git at the tag `nen/repos.json` pins, and only when `refs/tags/<tag>^{commit}` equals the recorded `pinnedSha` (HR-338; a moved tag is exit `2`).
  - **Exits:** a dangling id exits `1`. Every not-run cause, including any unexpected failure, exits `2`.
  - **Interim:** zheref/nen#554 owes the verb to nen.
- `docs/WORKFLOW.md` § *The constitution check* covers the floor, the CON read at the pin, the exits, the judgement past the list, the record, the stop and the resume. `docs/config/decisions.json.md` adds the row and extends `capability-unavailable`. `contracts/idle-permissions.json` lists the check and the two git commands that fetch the pinned tag by its full ref.

### Changed

- `hatsu:breath` is put on a diet to make room for the check (12,285 to 12,251 of 12,288 bytes).
  - **Citations:** the no-`workflow.json` paragraph now cites PROCESS § *Invocation and parsing*, the host's exit `5`/`7` paragraph cites `kurapika.md` § *The `shu` verbs*, and the branch rendering cites WORKFLOW § 2 *`branch`*.
  - **Duplicates:** restated rules moved into § 6's hard limits, including the duplicated `--discard` and `origin/main` reasons.
  - **Stale residue:** the line "opening the cycle ledger" is gone (a nen verb since v0.26.0, [HR-244](docs/ROSTER.md#hr-244)). The bare `#113` is now `zheref/hatsu#113`, so their two rows leave `contracts/prose.lint.baseline.json` (1,208 to 1,206).
- `hatsu:ren` § 2a: step 1's `end` note composes the begin note with the check's record. The gate and the resume are cited to WORKFLOW rather than restated.
- `hatsu:build` § 4's phase-1 row names the check. It drops two duplicates its hard limits already state: the trailer in the kokusen cell and "Say when it ends."
