# The schedule — the four steady-state rows

> **Lives in** [`contracts/schedule.json`](../../contracts/schedule.json) (the rows, one source) and, once the maintainer registers them, in Claude Desktop's own store on the maintainer's machine (`~/.claude/scheduled-tasks/<name>/SKILL.md`, never a tree) · **Written by** the maintainer of `zheref/hatsu`, on a PR at its `G4` gate; the tasks themselves are registered by the maintainer alone · **Printed by** [`scripts/schedule_install.mts`](../../scripts/schedule_install.mts), which registers nothing · **Validated by** the `schedule-printer` lane (`nen shu test --repo <hatsu> --lane schedule-printer`) · **Authority** ruling R-2026-10-23-21 (effort HA-IS-#450), answering OQ-1 of zheref/hatsu#448

## What it decides

The SDD plan's steady-state row names four recurring duties: a quarterly canon drift pass, a recapture on each family member's release tag, the morning desk after every idle wave, and the prose ratchet baseline shrinking in every prose PR. This page states, for each, its trigger, its cadence and where it runs.

**The scheduler is the maintainer's own machine.** On 2026-10-23 the maintainer ruled OQ-1 of zheref/hatsu#448 with *"Your own machine"* (record R-2026-10-23-21, effort HA-IS-#450): Claude Code Desktop's **local** scheduled tasks, which start a fresh session on the maintainer's Mac while the Desktop app is open and the machine is awake. A cloud task and a CI cron in this repository were the options not picked. Three consequences follow from the Desktop documentation ([Schedule recurring tasks in Claude Code Desktop](https://code.claude.com/docs/en/desktop-scheduled-tasks), fetched 2026-10-23):

- *"If your computer sleeps through a scheduled time, the run is skipped"*; on wake *"Desktop starts exactly one catch-up run for the most recently missed time"* within the last seven days. Every row's prompt is written so a late catch-up run is harmless.
- A local task fires on a schedule only. *"For tasks that … should trigger on an API call or GitHub event, create a cloud scheduled task instead"*: a tag trigger is outside the ruled scheduler, so the recapture row polls weekly (§ *Row 2*).
- Each run's date is on the task's detail page (*Review history*), skipped runs included with their reason. That page is where SC-1's *last run's date* is read.

**An agent prints, the maintainer registers.** `node scripts/schedule_install.mts --folder <hatsu checkout> --spec-folder <spec checkout> --family <slug>` prints each task as the fields of Desktop's *New scheduled task* form and the `SKILL.md` Desktop keeps for it, and writes nothing. Register each one in Desktop: **Code** tab → **Scheduled** → **New task** → **Set up manually**, **Advanced settings** → **Only on this computer** on, then the printed fields; after **Create**, press **Run now** once and answer each permission prompt so later runs do not stall. Exit `0` printed with every placeholder filled, `1` printed with a placeholder still open (each named on stderr), `2` wiring; the script's header is the full list. `--family` is a private value: it reaches stdout and nothing else.

**Never a release.** HR-5 lets a host scheduler re-invoke a build and never a release; every row's prompt ends on that line, and none names `getsuga`, `kagutsuchi` or `mugetsu`.

## The rows

| Row | Trigger and cadence | Runs | Ends at |
|---|---|---|---|
| `drift-pass` | Desktop, `Custom` `7 9 1 1,4,7,10 *`: 09:07 on the first day of each quarter | `hatsu:great-hiker evolve` over every surface in the Hatsu checkout, read-only | the drift table, then one issue per drifted surface filed through `hatsu:file`'s one confirmation |
| `recapture` | Desktop, `Weekly`, Mondays 08:07 | `hatsu:dowsing-chain recapture <family> --dry-run` in the spec checkout | a report per member; the real recapture is the maintainer's typed call |
| `morning-desk` | Desktop, `Weekdays`, 07:33 | `hatsu:rikugan for <repo> as register` | the register page's link, the last idle run first |
| `ratchet-shrink` | CI, every pull request | `canon-lint` in [`.github/workflows/prose-ambiguity-check.yml`](../../.github/workflows/prose-ambiguity-check.yml) | the check's summary line on the PR |

### Row 1 — the quarterly drift pass, dry first

`great-hiker` § 7 is the duty; this row is its timer. The plan's word *analyze* is `evolve` over every surface (AS-1 of zheref/hatsu#448). **Dry first**: the run prints the whole drift table and files nothing in that step. **Nothing filed twice on the same day**: before filing, each drifted surface is searched with `nen issue search --target zheref/hatsu --subject "Surface drift: <surface>"`; an open issue is amended (great-hiker § 7 step 4), an issue opened or closed today skips the surface and says so, and a search that could not run is reported as not run and that surface is not filed. A catch-up run on a later day files only what the first one did not. The run edits no file and opens no PR: a pure data edit § 7 step 5 would open is listed for the maintainer's typed `hatsu:great-hiker` call. The filing waits in the run's session for `hatsu:file`'s one confirmation, found from the task's *History*.

### Row 2 — the family recapture, weekly and dry

AC-2 of zheref/hatsu#448 asks for a recapture on each member's release tag. The ruled scheduler carries no tag event, and no nen verb reads a member's newest `v*` tag against the capture record (unfiled), so the row polls: every Monday it runs `recapture <family> --dry-run`, which reads every member's tip itself (dowsing-chain § 11, *runnable today*), writes only to scratch and asks nothing. A member tagged since the last capture shows up within a week as a changed tip. It needs a first capture (AS-2; zheref/hatsu#446) and says so in one line until one exists. The real recapture stays the maintainer's typed `hatsu:dowsing-chain recapture <family>`, ending at its spec PR's merge prompt at G2. It is not run under `--idle`: the idle profile is read by `futon` and `kazaana` only, and its `spec-*` rows hold because `dowsing-chain` is not an idle-run skill ([`workflow.json.md`](workflow.json.md) § `idle`).

### Row 3 — the morning desk

A `futon --idle` run already renders a `register` at its terminal (futon §§ 10 and 12; [`WORKFLOW.md`](../WORKFLOW.md) § *Idle batches*). The morning desk renders the repository's register again on each weekday, so the verdicts are the morning's and not the night's, every readiness quoted from `nen pr ready`. Where an idle run ended since the previous desk, its terminal state and parked efforts lead the page and its last report is linked. Strictly read-only, as `rikugan` is.

### Row 4 — the ratchet shrink, per pull request in CI

This row is not a task: it already runs on every pull request in `canon-lint`, the job of `.github/workflows/prose-ambiguity-check.yml`, which holds the PR's `contracts/prose.lint.baseline.json` against the trusted base revision's copy (`--base-baseline`) so the baseline never grows (HR-13). From zheref/hatsu#448 the same run counts the shrink: the summary line carries `<n> removed over <base>` and `--json` carries `removedBaseline` (null with no base), summed per key, so a dropped row and a lowered count both count. The count is printed by the trusted revision's guard, so the first PR to show it is the first opened after this lands. The count over the last ten prose PRs has no reader yet (unfiled).

## Sources

- zheref/hatsu#448 (the rows, AC-1 to AC-4, SC-1, SC-2, AS-1, AS-2, OQ-1); epic zheref/hatsu#454; the ruling record R-2026-10-23-21 under effort HA-IS-#450
- [Schedule recurring tasks in Claude Code Desktop](https://code.claude.com/docs/en/desktop-scheduled-tasks) and [Run prompts on a schedule](https://code.claude.com/docs/en/scheduled-tasks), both fetched 2026-10-23
- [`ROSTER.md`](../ROSTER.md) [HR-5](../ROSTER.md#hr-5) (a scheduler re-invokes a build, never a release), HR-13 (the ratchet)
- [`../../claude/skills/great-hiker/SKILL.md`](../../claude/skills/great-hiker/SKILL.md) § 7, [`dowsing-chain/SKILL.md`](../../claude/skills/dowsing-chain/SKILL.md) §§ 10–11, [`rikugan/SKILL.md`](../../claude/skills/rikugan/SKILL.md); [`prose.lint.json.md`](prose.lint.json.md)
- the printer's dry run: [`../ab/schedule-install.md`](../ab/schedule-install.md)
