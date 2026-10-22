### Changed

- **nen `review ledger` owns hanten's review-cycle ledger (zheref/hatsu#216, zheref/nen#346).** `hanten` §§ 1–2b and `breath` § 3b call `nen review ledger ensure|init|decide|record|show|recover-first --json`; the roster and maxima are the target's `review.scopes` alone, with no fallback persona or late-persona exception, so an unstamped ledger missing a declared reviewer's row refuses at exit `2` and is restored by hand. `scripts/tenkai_adopt.sh`'s review-ledger row asks `nen review ledger show` instead of re-checking persona rows itself. ROSTER HR-244 records the delivery.
- **Repinned nen to v0.26.0, minimum and floor 0.26.** Absorbed: `shibari` § 4 reads `pr open`'s adoption of an open PR at exit `0`; `file` § 4 reads `issue file`'s `--json` refusals from the `nen.refusal/v0.1` envelope on stdout; `izanagi` § 3 and `docs/WORKFLOW.md` § *`monitor`* name the loop ledger's git-common-dir home. `docs/history/nen-repins.md` § *v0.26.0* lists every v0.25/v0.26 note and its disposition.

### Removed

- **`scripts/hanten_cycle_ledger.sh`, `scripts/hanten_cycle_ledger_late_persona_fixture.sh` and lane `ledger-guard`.** The ledger's tests are nen's own; the BC-11 freeze (HR-243) ends with the script.
