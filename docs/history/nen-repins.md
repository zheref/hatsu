# Nen repins — one row per pin

This file holds the per-repin narrative that `nen/contract.json` → `dependency.minimum_semantics` used to
carry as one string. **The contract is the authority on the current values** (`dependency.minimum`,
`dependency.pinned_ref`); every row below is history and stays true of the pin it names.
[`docs/NEN-CONTRACT.md`](../NEN-CONTRACT.md) § *The range* explains how the two values move.

## The rule

`minimum` is a MAJOR.MINOR capability minimum, checked by `nen shu tools` against the installed binary
and its compatibility floor. Raise it for either a breaking compatibility floor or a newly adopted
feature unavailable in earlier releases. **A minimum names the OLDEST release carrying every verb Hatsu
executes, so it moves to the newest adoption and never back.** Never treat an older binary that accepts
unknown JSON keys as proof it executes the new capability. Nen kept its compatibility floor at 0.7
through 0.16.x and raised it with each breaking line after that (the floor column below).

## The pins

Date and commit are the Hatsu commit that moved `pinned_ref` (`git log -G'"pinned_ref": "v' --
nen/contract.json`); PR is the Hatsu pull request that landed it. A pin with no section below carried no
adoption narrative in the contract.

| Pin | Minimum | Nen floor | Date | Commit | PR | Adopted / breaking notes |
|---|---|---|---|---|---|---|
| `v0.3.0` | 0.3 | — | 2026-09-08 | `4563aad94` | #28 | — |
| `v0.4.0` | 0.4 | — | 2026-09-10 | `3c8060770` | #30 | — |
| `v0.6.0` | 0.6 | — | 2026-09-10 | `cc69215d3` | #37 | — |
| `v0.7.0` | 0.7 | — | 2026-09-10 | `ae64a6ad6` | #39 | — |
| `v0.8.0` | 0.7 | 0.7 | 2026-09-10 | `94e917a6d` | #42 | the pin read against nen's compatibility floor |
| `v0.9.0` | 0.9 | 0.7 | 2026-09-12 | `21d5acc9a` | #50 | — |
| `v0.10.0` | 0.10 | 0.7 | 2026-09-12 | `60adabf43` | #55 | — |
| `v0.11.0` | 0.11 | 0.7 | 2026-09-19 | `a39b1ac58` | #87 | [§ v0.11.0 and v0.12.0](#v0110-and-v0120) |
| `v0.12.0` | 0.12 | 0.7 | 2026-09-20 | `40335ab32` | #91 | [§ v0.11.0 and v0.12.0](#v0110-and-v0120) |
| `v0.13.0` | 0.13 | 0.7 | 2026-09-20 | `b16308114` | #94 | [§ v0.13.0](#v0130) |
| `v0.14.0` | 0.14 | 0.7 | 2026-09-22 | `0975a314e` | #109 | [§ v0.14.0](#v0140) |
| `v0.15.0` | 0.15 | 0.7 | 2026-09-27 | `0b12b8dd1` | #114 | [§ v0.15.0](#v0150) |
| `v0.15.1` | 0.15 | 0.7 | 2026-09-28 | `d72adcd41` | #114 | the v0.15.0 verbs, fail-closed |
| `v0.16.0` | 0.15 | 0.7 | 2026-09-29 | `6b0fd663c` | #134 | [§ v0.16.0](#v0160) |
| `v0.18.0` | 0.18 | 0.18 | 2026-09-30 | `fd4d7f3a9` | #174 | [§ v0.18.0](#v0180) |
| `v0.18.1` | 0.18 | 0.18 | 2026-09-30 | `676d37dc5` | #174 | — |
| `v0.18.2` | 0.18 | 0.18 | 2026-09-30 | `dcf8f9321` | #184 | — |
| `v0.19.0` | 0.19 | 0.19 | 2026-10-04 | `53ac0e30e` | #226 | [§ v0.19.0](#v0190) |
| `v0.20.0` | 0.20 | 0.20 | 2026-10-04 | `98b3e6630` | #231 | [§ v0.20.0](#v0200) |
| `v0.21.0` | 0.21 | 0.21 | 2026-10-11 | `a03865101` | #245 | [§ v0.21.0](#v0210) |
| `v0.22.0` | 0.22 | 0.22 | 2026-10-18 | `f58d5a683` | #315 | [§ v0.22.0](#v0220) |
| `v0.24.0` | 0.24 | 0.24 | 2026-10-20 | `d9645c8e3` | #374 | [§ v0.24.0](#v0240) |
| `v0.26.0` | 0.26 | 0.26 | 2026-10-22 | @@COMMIT@@ | @@PR@@ | [§ v0.26.0](#v0260) |

One move had no pin: the minimum rose to 0.16 at `a228b0855` (2026-09-29, `hatsu:limbo`) with
`pinned_ref` unchanged at `v0.16.0`.

The minimum's own path, as the contract recorded it: 0.13, then 0.14, 0.15, 0.16, 0.18, 0.19, 0.20,
0.21, 0.22, 0.24 and 0.26. Nen raised its floor to 0.17 at v0.17.0, to 0.18 at v0.18.0 (the maintainer's
ruling of 2026-09-30: nen commit format's new exit 2 on an unreadable commitlint config with prose lines
over 100, zheref/nen#302, is breaking), to 0.19 at v0.19.0, to 0.20 at v0.20.0, to 0.21 at v0.21.0, to
0.22 at v0.22.0, to 0.24 by v0.24.0 and to 0.26 at v0.26.0. So 0.18 was the minimum on both counts at that repin, the
feature and the floor, as 0.19 was at the v0.19.0 repin, 0.20 at the v0.20.0 repin (the classify and
direct families), 0.21 at the v0.21.0 repin (the floor and nen's gates keys), 0.22 at the v0.22.0 repin
(v0.22.0 moved the floor to 0.22 and Hatsu adopted the list slots and backlog filters), 0.24 at the
v0.24.0 repin and 0.26 at the v0.26.0 repin (the floor and `nen review ledger`).

## v0.26.0

zheref/hatsu#216 adopts released v0.26.0 (release PR NN#499, published 2026-10-22): `nen review ledger
init|ensure|decide|record|show|recover-first` (zheref/nen#346, NN-PR-#471) replaces
`scripts/hanten_cycle_ledger.sh` in hanten §§ 1–2b, breath § 3b and tenkai's review-ledger row; the script,
its late-persona fixture and lane `ledger-guard` retire. The verb reads the roster and maxima from
`review.scopes` alone (no built-in personas or fallback budgets) and has no late-persona exception: an
unstamped ledger missing a declared reviewer's row refuses at exit `2` and is restored by hand. nen's mutex
does not exclude the script's OS lock, so legacy writers stop first: WORKFLOW § *The review ledger's exits*
(*Switching writers*) names how a stale installed copy is found and drained. The pin
crosses v0.25.0 (no breaking notes, floor 0.24) and v0.26.0 (floor 0.26). Absorbed, note by note:

- **`pr open` adopts an open PR at exit `0`** (`existing: true`) for the same head, base and head commit:
  shibari § 4 says so.
- **`--json` refusals arrive as one `nen.refusal/v0.1` envelope on stdout** for `issue file`, `idea file`,
  `canon resolve` and `commit format`: file § 4 reads `refused[]` instead of stderr (emperor-time cites file
  § 4); no Hatsu caller reads `canon resolve` or `commit format` refusals under `--json`.
- **Ledger homes in the git common directory**: the loop ledger is `<git-common-dir>/.nen/loop/<id>.json`
  of `--repo` (izanagi § 3 and WORKFLOW § *`monitor`* updated; en already said so); stop answers and run
  manifests move to `<git-common-dir>/.nen/stops/` and `.nen/runs/`, under the common-dir `.nen/` cleanup § 4 now keeps as records;
  no Hatsu skill reads them yet.
- **`parse --grammar` refuses an unintroduced later slot**: the 36 (skill, grammar) pairs this run extracted return the
  same exits on 0.24.0 and 0.26.0 (144 runs, none differing).
- **`pr ready` and `pr merge --release-unit` read `aiReviewers`**: no Hatsu change here; getsuga § 3a's and
  kazaana § Residue's "owed to nen" clause is zheref/hatsu#380's to rewrite.
- **`pr converge` exits** and **`repo classify`'s spec role**: no Hatsu caller yet (zheref/hatsu#413 adopts
  `pr converge`; `nen/repos.json` declares no families).

v0.25.0's `pr sections resolve` envelope fix (NN#464) makes the retirement of Hatsu's interim PR-section
resolver possible; that retirement is separate and not adopted here.

## v0.24.0

HA321 adopts released v0.24.0 (NN#437/PR439, release PR462, published 2026-10-20): phase/usage --dial,
session record/show and report data sessions[]. This crosses v0.23 and v0.24 breaking notes: base-pinned
gate policy; guarded public-text writes and their private-name refusal exits; default label ledgers;
stricter undeclared flags, selector/prune arguments and deletion-only release paths; schema mirror row.
Hatsu keeps explicit paths/flags and authenticates guarded writes; schemas are checked at this released
binary. PR-section resolver retirement is separate; Hatsu retains its interim resolver because released
0.24 has the envelope defect tracked as NN#464.

## v0.22.0

Hatsu adopts, FROM v0.22.0 (zheref/nen#411..#414 and #422, released by #423, published 2026-10-18 UTC;
zheref/hatsu#297): nen parse list slots ({+}, {&}) and three-way alternations, read through the
alternative and items fields of a parsed slot, and the --label/--severity filters on nen backlog fetch
and nen report data -- hatsu:backlog-state and hatsu:backlog-board execute them, so the minimum was 0.22:
a 0.21 binary refuses g4+g5 as one enumerated value and --label as an undeclared flag, which is the
fail-closed reading a minimum exists to give.

**Breaking notes absorbed.** The same repin crosses the 0.22 line's compatibility floor (v0.22.0's
consumer notes are breaking, so every 0.22+ build refuses a 0.21 pin at exit 5): a --grammar template
using | or {...} outside <...> changes meaning (no Hatsu template does; checked 2026-10-17); = is an
exact-path marker in release.unitPaths, review.scopes and report tiers (Hatsu's entries are bare
prefixes); lane cwd declarations and dependabot_carve_out.author_pattern are validated at load (Hatsu's
declarations pass schema check under 0.22.0, checked 2026-10-18); threads settle screens bodies for
credential shapes; and wc squash --message-file requires an admitted agent trailer (aka passes
Hatsu-Agent).

## v0.21.0

Hatsu adopted, FROM v0.21.0 (zheref/nen#381..#401, released by #402, published 2026-10-11 UTC;
zheref/hatsu#227): nen's own reading of the two gates keys Hatsu used to keep for itself --
checks.excluded (from v0.20.0, zheref/nen#249) replaces Hatsu's retired check_exclusions, and
round_policy.minRounds/.maxRounds become nen keys (zheref/nen#240), maxRounds refused past by pr
request-reviews at exit 2 -- under the maintainer's ruling of 2026-10-04, 'retire 2, adopt 2'
(zheref/nen#310), so the minimum was 0.21: a 0.21 build refuses every nen/gates.json key it does not
read (pr ready, pr next-blocker and schema check exit 2 naming it), and only a 0.21+ build reads
minRounds/maxRounds as its own; a 0.20 binary reads Hatsu's file without the ceiling, which is the
fail-closed reading a minimum exists to give.

**Breaking notes absorbed.** The same repin crosses the 0.21 line's compatibility floor (v0.21.0's
consumer notes are breaking, so every 0.21+ build refuses a 0.20 pin at exit 5): Hatsu's
nen/gates.json carries only keys nen reads, reviewer_fallback deleted (round_quorum and zheref/nen#361
supersede it); runner pools gain their own pool-<id> label, last (Hatsu declares no runners; jusshin's
consumers relabel through nen runner relabel); pr body-check without --requirements-from derives the
requirement set from the PR template (Hatsu's callers pass the flag); a shu step running past 30 s
prints heartbeat lines on stderr (stdout and --json unchanged); a select block on any verb but test
fails the contract (Hatsu declares none); pr open reports a PR gh created as opened at exit 1 when gh
then fails; and every thrown message is printed with control, bidi and zero-width characters stripped.

## v0.20.0

Hatsu adopted, FROM v0.20.0 (zheref/nen#370/#371, carried to main by #380, released by #384, published
2026-10-05 UTC; zheref/hatsu#168): the nen classify family (labels, install, status, apply) that
hatsu:classify executes (from Hatsu 0.87.0) and the nen direct family (registry, resolve, answer) that
hatsu:direct executes (from 0.88.0) -- until this repin both skills ran under row missing-tool -- and
round_quorum fulfilling its members' rounds (zheref/nen#359, the maintainer's ruling of 2026-10-04, the
canon Hatsu 0.91.0 recorded), so the minimum was 0.20: a 0.19 binary refused nen classify and nen direct
as unknown commands, which is the fail-closed reading a minimum exists to give.

**Breaking notes absorbed.** The same repin crosses the 0.20 line's compatibility floor (v0.20.0's
consumer notes are breaking, so every 0.20+ build refuses a 0.19 pin at exit 5): nen shu tools exits 7
with a BEHIND row when the host nen satisfies the minimum but sits below pinned_ref (ten section 1 reads
the row and routes it to section 2's install; nen_global.sh reads only satisfied on a strictly newer
host and is unchanged); nen wc catch-up exits 3 when every conflicted path is in a declared mechanical
set (ao section 3's table carries the row; Hatsu declares no mechanical block, so its own catch-ups
still stop at 1); pr ready answers ready where an unavailable any_of member's round is excused once the
quorum is met; stage triage refuses --nul (Hatsu passes none; the NUL list is stage list --nul); nen
issue file, comment and edit-body exit 4 before writing a private repository's name to a public target,
and their dry runs read visibility (file section 4 reads the exits and passes the guard's ignore file,
which nen reads by no default; mugetsu, sharingan and backlog-synthesis point there, and
private_name_check.sh stays the first guard); issue file --body-file resolves a relative path against
--repo; issue edit-body --json names v0.3; and report data's repo is the hosted owner/name or null.

## v0.19.0

Hatsu adopted, FROM v0.19.0 (zheref/nen#333, released by #358/#362): the interactive runner mode --
nen/workflow.json runners.pools[].mode (service | interactive; an interactive Windows pool's labels are
exactly [self-hosted, Windows, <arch>, desktop]), runner plan's nen.runner.plan/v0.2 with mode and
dailyAccount, runner script's logon-task rendering and --accept-daily-account, and runner workflow's
eighth placeholder MODE, which templates/runner-preflight.yml uses (zheref/hatsu#206) -- so the minimum
was 0.19: a 0.18 binary leaves that placeholder standing and refuses the rendering at exit 1, which is
the fail-closed reading a minimum exists to give.

**Breaking notes absorbed.** The same repin crosses the 0.19 line's compatibility floor (v0.19.0's
consumer notes are breaking, so every 0.19+ build refuses a 0.18 pin by name): nen pr ready reads a
draft, an all-skipped head and a queued re-run as not-ready (shibari names nen pr mark-ready,
zheref/nen#355, for the draft transition); nen runner enable certifies only a default-branch
workflow_dispatch run (jusshin section 8 already passes that run); nen runner plan names contract v0.2;
nen commit write and nen wc squash exit 3 when the written commit carries a refused trailer, the commit
left in place (kokusen section 5 and aka section 4 map it, retiring the tip read-back, zheref/nen#273);
nen wc squash loads nen/workflow.json on every run; and the codex mirror's summary line gains quotes
once regenerated (zheref/nen#343).

## v0.18.0

Hatsu adopted, FROM v0.18.0 (zheref/nen#305): the nen runner family -- inventory, plan, script, verify,
workflow, preflight, enable -- and the nen/workflow.json runners block ({naming, pools[]}, one preflight
workflow per pool) -- hatsu:jusshin executes them, so the minimum was 0.18. A 0.17 binary refuses nen
runner as an unknown command, which is the fail-closed reading a minimum exists to give.

**Breaking notes absorbed.** The same repin crosses the 0.17 line's compatibility floor: v0.17.0 moved
the floor to 0.17 because its consumer notes are breaking, so every 0.17+ build refused Hatsu's 0.16 pin
by name (nen shu tools: "Repin to '0.17'"), and Hatsu absorbs those notes with this repin -- nen wc
publish on a branch whose upstream names another branch exits 2 unless --set-upstream (and nen shu
warmup cuts branches with --no-track); a round check counts only a SUCCESS conclusion; nen commit format
and nen commit write read nen/workflow.json on every run (a malformed file exits 1, a nonexistent --repo
exits 2, and nen: warning: lines print at exit 0); nen pr request-reviews exits 9 for an unrecorded bot;
nen pr ready --exclude-check may repeat and splits on commas outside brackets; case-colliding product
codes are refused at exit 2; a non-string scenario on a maintained_tools row stops registry loading; nen
surface mirror check reports a mirror generated by an older build as stale; and changelog completeness
and release preflight exit 0 on a range whose only uncited PR is the release PR. v0.17.0's additions
(round_quorum in nen/gates.json, commits.subjectCase, unrecordedBots, <CODE>#<n> on pr merge and
unit-check, scenario on maintained_tools rows, link re-aiming in surface mirror generate, zheref/nen#270)
arrive with the pin.

## v0.16.0

Hatsu adopted, FROM v0.16.0 (zheref/nen#272/#274/#278, released by #281): nen canon pin, and nen canon
mirror generate|check with --surfaces (the per-surface canon mirror -- AGENTS.md as one managed block,
.cursor/rules/*.mdc, .agents/rules/*.md, .claude/rules/*.md -- with the generated-from marker as the
ownership claim) -- hatsu:limbo executes them, so the minimum was 0.16. A 0.15 binary refuses canon pin
as an unknown subcommand and the --surfaces form as an unknown flag, which is exactly the fail-closed
reading a minimum exists to give; Hatsu 0.59.0 moved the pin first and left the minimum at 0.15 on
purpose, because no skill on main executed those verbs until limbo.

## v0.15.0

Hatsu adopted, FROM v0.15.0 (zheref/nen#265, released by #266): nen parse futon label selectors,
then-clause skill chains and the futon.advanceGo gate, nen repo classify's declared project.kind
(library), nen release unit-check and nen pr merge --release-unit -- futon, getsuga and mugetsu execute
them, so the minimum was 0.15.

## v0.14.0

Hatsu adopted, FROM v0.14.0 (zheref/nen#242): nen wc swap and nen wc worktrees, the
hatsu:amenotejikara engine.

## v0.13.0

Hatsu adopted, FROM v0.13.0 (zheref/nen#227): the antigravity and claude-code surface rows with
--models, --permissions, --hooks, --rules and --stamp, nen surface mirror check --installed, nen usage
record, shu step durations in the phase ledger, phases[] and usage[] in report data, nen wc catch-up,
nen wc publish, nen commit write, nen pr open and the profile key -- so its minimum was 0.13 then.

## v0.11.0 and v0.12.0

PRIOR ADOPTION, from v0.12.0 (zheref/nen#220): objects[] in nen report data, nen review scopes, nen pr
threads, nen report render --variant and --graph, nen report mermaid; from v0.11.0 (zheref/nen#216) and
still required: the decision matrix (nen/decisions.json), the rich stop (nen stop
--options/--propose-issue, nen.stop.mark/v0.2), nen shu warmup --carry, nen repo classify, nen surface
capabilities and nen phase.
