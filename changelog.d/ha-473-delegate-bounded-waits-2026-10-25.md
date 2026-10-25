### Added

- `docs/WORKFLOW.md` § *Delegate briefs — how a delegate waits* carries the wait block every brief that raises a delegate copies word for word: never `gh pr checks --watch`, an open `sleep` or poll loop, or a background job left running; a wait is one `nen watch until … --max-iterations <n> --interval-ms <ms>`, both flags passed, within the brief's ceiling (10 minutes unless the brief names another); at the bound, settled or not, a hand-back of the head SHA, each check and review round as read, and what is still pending. Without `--max-iterations` the wait takes `monitor.maxCycles` (20 × 300 s here, 100 minutes). Kazaana § 3 hands the block to its builder delegate and futon § 4 cites it. Closes #473.
- `scripts/delegate_brief_check.mts` reads the block from WORKFLOW and refuses a brief that drops, rewords or paraphrases a line (exit 1, each line named; wiring exit 2; `--print` prints the block). Its fixture runs as the new `delegate-brief-guard` lane, gated in `scripts/unit_tests_ci.mts` with its runner-fixture case.

### Changed

- WORKFLOW § *Idle batches* rule 8: the `decisions` footer row is resolved by the `decisions` run fact (`--idle`, `--decisions`, or a non-empty nen manifest; a positive flag wins), as `contracts/pr-sections.json` already records since #474.
- Prose-diet trims to fit the new citations: kazaana § 3 drops "never raw `gh pr create`" (Authority's not-permitted list still carries it); futon § 6 drops the claimed-effort slot clause it restated from the line above and WORKFLOW § 2 `monitor`.
