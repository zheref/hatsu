# Regression note — two PRs called ready on CI alone (2026-09-22/23, zheref/hatsu#103)

**What happened.** Twice in one sitting Kurapika told the maintainer a pull request was ready at its gate
when it was not:

- **zheref/nen#246** (`chore(release): v0.14.0`, the release proposal getsuga § 3 opened) was reported
  "green … ready for you to merge" from `gh pr checks` alone. Nothing had handed the proposal to `hatsu:en`,
  so nothing observed its reviewer round or its threads before the maintainer was told to merge.
- **zheref/nen#247** (`fix(contract): declare the release row instead of a seat`, opened by a delegated
  Opus subagent whose brief said "stop when macOS, Linux and compile are green") was relayed as "ready for
  you to merge (G4)". Read afterwards, `nen pr ready 247 --gh-repo zheref/nen --explain` answered
  **not-ready** with two unresolved Copilot threads (`src/dev/release-publish.ts:117` and `:102`), posted at
  03:21Z — after the subagent had already stopped.

Canon already said a readiness claim is `nen pr ready`'s verdict, quoted, or it is not made
(`pr-state`, `en` § 4, `sharingan` § 4). Both PRs simply never entered the path that enforces it: a release
proposal stopped at the gate without `en`, a delegate's PR had no owner for readiness, and the chat line
"ready at G4" had no guard.

**What changed (zheref/hatsu#121, effort 3 of the futon run of 2026-09-28).**

- `getsuga` § 3 hands the release proposal to `hatsu:en` the moment it opens; § 3a is entered only once
  `en` has read `ready`, and a fall-back stop quotes the verdict, never "green".
- `docs/PROCESS.md` § *Reporting a phase* states the rule once for every skill and every brief: every PR a
  session opens or causes to be opened — a delegate's included — reaches the maintainer through `en` or with
  the verdict line quoted; a brief that opens a PR ends at the verdict with zero unresolved threads; *ready*,
  *G2-ready* and *G4-ready* appear only beside the quoted line; a `not-ready` on an excluded row stays
  `not-ready`, naming the row.
- `en` § 6's observation hold names the asynchronous reviewer round explicitly: a requested round not yet
  posted at the current head is pending, not ready, however green the checks, and spends no cycle.
- The nen half — `nen pr ready` short-circuiting so rows after the first failure read *unevaluated*
  (zheref/nen#248), and `--exclude-check` refusing a comma-bearing name (zheref/nen#243) — is nen's.

**The corrected practice, on the record.** HA-PR-#121 itself was driven this way: every readiness line in
its run quotes the verdict (`not-ready: a configured reviewer's round is still owed at the current head
(CON-32b): copilot (review requested, not yet posted)` minutes after opening; later `not-ready: 5 unresolved
review thread(s) (CON-32d)` after Copilot's round landed), and no line called it ready before the verb did.
