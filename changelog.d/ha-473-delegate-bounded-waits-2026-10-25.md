### Added

- `docs/WORKFLOW.md` § *Delegate briefs — how a delegate waits* carries the wait block every brief that raises a builder delegate (kazaana § 3's, futon § 4's) copies word for word; Illumi's long watch, en's observation hold, is excluded by name: never `gh pr checks --watch`, an open `sleep` or poll loop, or a background job left running; a wait is one `nen watch until … --max-iterations <n> --interval-ms <ms>`, both flags passed, within the brief's ceiling (9 minutes unless the brief names another, under Claude Code's 600000 ms Bash maximum), the host call's own timeout set above the wait's, a named ceiling staying under the host's maximum and a longer wait split into several bounded waits, each with its own hand-back; at the bound, settled or not, a hand-back of the head SHA, each check and review round as read, and what is still pending. Without `--max-iterations` the wait takes `monitor.maxCycles` (20 × 300 s here, 100 minutes). Kazaana § 3 hands the block to its builder delegate and futon § 4 cites it. Closes #473.
- `scripts/delegate_brief_check.mts` reads the block from WORKFLOW and refuses a brief that drops, rewords or paraphrases a line (exit 1, each line named against the canon actually read; wiring exit 2, a comma, colon or line break refused in the brief's path and a line break in the canon's; `--print` prints the block). Its fixture runs as the new `delegate-brief-guard` lane, gated in `scripts/unit_tests_ci.mts` with its runner-fixture case.

### Changed

- WORKFLOW § *Idle batches* rule 8: the `decisions` footer row is resolved by the `decisions` run fact as that `contracts/pr-sections.json` footer row records it (#474).
- Prose-diet trims to fit the new citations: kazaana § 3 drops "never raw `gh pr create`" (Authority's not-permitted list still carries it); futon § 6 drops the claimed-effort slot clause it restated from the line above and WORKFLOW § 2 `monitor`. After HA-PR-#490 grew `kazaana`, its § 3 link to `WORKFLOW.md` § *Where worktrees live* is written in the file's plain `WORKFLOW §` form (35 bytes, the same reference) to stay under its 12288-byte ceiling.

### Fixed

- `scripts/mechanical_conflicts_fixture.test.mts` hands nen the same git identity it hands its own `git` calls and writes it into each fixture repository's config, so the `mechanical-conflicts-guard` lane passes on a GitHub-hosted runner, which has none (the lane landed on `main` through HA-PR-#489 and first ran on this branch's catch-up: `git merge` refused with "empty ident name").
