# The schedule — the four steady-state rows

> **Lives in** [`contracts/schedule.json`](../../contracts/schedule.json) (the rows, one source) and, once the maintainer registers them, in Claude Desktop's own store on the maintainer's machine (`~/.claude/scheduled-tasks/<name>/SKILL.md`, never a tree) · **Written by** the maintainer of `zheref/hatsu`, on a PR at its `G4` gate; the tasks themselves are registered by the maintainer alone · **Printed by** [`scripts/schedule_install.mts`](../../scripts/schedule_install.mts), which registers nothing · **Validated by** the `schedule-printer` lane (`nen shu test --repo <hatsu> --lane schedule-printer`) · **Authority** the ruling record R-2026-10-23-21 (effort HA-IS-#450), answering OQ-1 of zheref/hatsu#448, quoted below and in the contract's `ruling`

## What it decides

The SDD plan's steady-state row names four recurring duties: a quarterly canon drift pass, a recapture on each family member's release tag, the morning desk after every idle wave, and the prose ratchet baseline shrinking in every prose PR. This page states, for each, its trigger, its cadence and where it runs.

**The scheduler is the maintainer's own machine.** The record, answered at G4 on 2026-10-23 (`nen.stop.answer/v0.1`, `R-2026-10-23-21`, effort HA-IS-#450), asked: *"HA#448 (steady state): four recurring rows need a scheduler: a quarterly drift pass, a recapture on each member's release tag, the morning desk after every wave, and the ratchet-baseline shrink report. Which host carries them?"*

| Key | Option, as shown | Consequence, as shown |
|---|---|---|
| A | Claude Code routines (Recommended) | Scheduled cloud agents run the agent-driven rows; the ratchet report stays per-PR in CI |
| B | CI cron in hatsu | GitHub Actions cron workflows in zheref/hatsu, with an API key secret for the agent rows |
| C | **Your own machine** (picked) | Claude Code scheduled tasks on the maintainer's Mac, running while it is awake |

**Reading, not ruled:** this page reads option C as Claude Desktop's **local** scheduled tasks (*Only on this computer*), the one Claude Code scheduler that persists across restarts on the maintainer's machine without an open session; session-scoped `/loop` tasks expire after seven days and need an open session. The reading is the maintainer's to confirm or correct; the ROSTER row is rendered from the record by the ruling-capture machinery, never written here. Three consequences follow from the Desktop documentation ([Schedule recurring tasks in Claude Code Desktop](https://code.claude.com/docs/en/desktop-scheduled-tasks), fetched 2026-10-23):

- *"If your computer sleeps through a scheduled time, the run is skipped"*; on wake *"Desktop starts exactly one catch-up run for the most recently missed time"* within the last seven days, and older missed runs are discarded. Every row's prompt is written so a late catch-up run is harmless, but a machine off or asleep for more than seven days around a run's time loses that run: the quarter's drift pass included. The task's *History* shows it as skipped; nothing else does (unfiled).
- A local task fires on a schedule only. *"For tasks that … should trigger on an API call or GitHub event, create a cloud scheduled task instead"*: a tag trigger is outside the ruled scheduler, so the recapture row polls weekly (§ *Row 2*).
- Each run's date is on the task's detail page (*Review history*), skipped runs included with their reason. That page is where SC-1's *last run's date* is read.

**An agent prints, the maintainer registers.** `node scripts/schedule_install.mts --folder <hatsu checkout> --spec-folder <spec checkout> --family <slug>` prints each task as the fields of Desktop's *New scheduled task* form and the `SKILL.md` Desktop keeps for it, and writes nothing. Register each one in Desktop: **Code** tab → **Scheduled** → **New task** → **Set up manually**, **Advanced settings** → **Only on this computer** on, then the printed fields; after **Create**, select **Worktree** in the Edit form where the row says so, then press **Run now** once and answer each permission prompt so later runs do not stall. Exit `0` printed with every placeholder filled, `1` printed with a placeholder still open (each named on stderr), `2` wiring; the script's header is the full list. `--family` is a private value: it reaches stdout and nothing else.

**Permissions are bounded per row.** Desktop saves an *always allow* answer for every later run of that task, and the allow rules of `~/.claude/settings.json` apply to these sessions too. So each row lists the reads it may pre-approve (`alwaysAllow`), and the contract lists what is answered *allow once* every time (`permissions.neverAlwaysAllow`: issue filing and edits, PR and comment writes, `git commit`/`push`, `Write`/`Edit`, and `update_scheduled_task`, a task rewriting its own prompt); the printer prints both under each task (SEC-9, SEC-15). Every public write therefore asks on every run, by design. **The first Run now of `drift-pass` is a live run**: it fetches every surface's pages and files on confirmation. `drift-pass` and `morning-desk` run in their own Desktop worktree and refuse unless it is clean at `origin/main`'s commit, so a half-edited or unmerged branch in the checkout is never read as canon.

**The warrant is the ruling; HR-5 is the floor.** The rows exist because of R-2026-10-23-21. HR-5 adds the floor every row keeps: a scheduler may re-invoke a build and never a release. Every prompt ends on that line, and none names `getsuga`, `kagutsuchi` or `mugetsu`.

## The rows

<!-- schedule-table:begin (rendered by `node scripts/schedule_install.mts --table`; the schedule-printer fixture compares) -->
| Row | Trigger | Cadence | What it does |
|---|---|---|---|
| `drift-pass` | Desktop, `Custom` `7 9 1 1,4,7,10 *` | 09:07 local on the first day of January, April, July and October | Quarterly canon drift pass: great-hiker evolve on every surface, dry first, one issue per drifted surface, nothing filed twice on the same day. |
| `recapture` | Desktop, `Weekly` `7 8 * * 1` | Mondays at 08:07 local | Weekly dry recapture of one product family's living spec, reading every member's tip; the real recapture stays the maintainer's typed call. |
| `morning-desk` | Desktop, `Weekdays` `33 7 * * 1-5` | Weekdays at 07:33 local (Mon–Fri) | Weekday morning register: the Rikugan register page over one repository, every verdict quoted, the last idle run first. |
| `ratchet-shrink` | CI, job `canon-lint` | every pull request | The prose ratchet: every pull request's canon-lint counts the baseline rows it removed. |

<!-- schedule-table:end -->

### Row 1 — the quarterly drift pass, dry first

`great-hiker` § 7 is the duty; this row is its timer. The plan's word *analyze* is `evolve` over every surface (AS-1 of zheref/hatsu#448). **Dry first**: the run prints the whole drift table and files nothing in that step. **Nothing filed twice on the same day**: before filing, each drifted surface is searched with `nen issue search --target zheref/hatsu --subject "Surface drift: <surface>"`; an open issue is amended (great-hiker § 7 step 4), an issue opened or closed today skips the surface and says so, and a search that could not run is reported as not run and that surface is not filed. A catch-up run on a later day files only what the first one did not. The run edits no file and opens no PR: a pure data edit § 7 step 5 would open is listed for the maintainer's typed `hatsu:great-hiker` call. The filing waits in the run's session for `hatsu:file`'s one confirmation, found from the task's *History*.

### Row 2 — the family recapture, weekly and dry

AC-2 of zheref/hatsu#448 asks for a recapture on each member's release tag. That half is **owed**: the ruled scheduler carries no tag event (an event trigger needs an event-driven host, such as a cloud task, which the record did not pick), and no nen verb reads a member's newest `v*` tag against the capture record (unfiled; the neighbour of `nen spec diff` in zheref/nen#493). Until both exist the row polls: every Monday it runs `recapture <family> --dry-run`, which reads every member's tip itself (dowsing-chain § 11, *runnable today*), writes only to scratch and asks nothing, so it needs no run profile. It reports each member's tip beside the capture record's sha and the plan the dry run prints, never what a real recapture would change, which is `nen spec diff`'s (zheref/nen#493). It needs a first capture (AS-2; zheref/hatsu#446) and says so in one line until one exists. The real recapture stays the maintainer's typed `hatsu:dowsing-chain recapture <family>`, ending at its spec PR's merge prompt at G2.

### Row 3 — the morning desk

AC-3 is carried by the idle run itself: a `futon --idle` run ends at `idle.terminal` and renders a `register` (futon §§ 10 and 12; [`WORKFLOW.md`](../WORKFLOW.md) § *Idle batches*), and its final report is that rikugan page. The morning desk is the additional daily render: on each weekday it renders the repository's register again, so the verdicts are the morning's and not the night's, every readiness quoted from `nen pr ready`. Where an idle run ended since the previous desk, its terminal state and parked efforts lead the page. No GitHub write; the page goes to the reports directory only.

### Row 4 — the ratchet shrink, per pull request in CI

This row is not a task: it already runs on every pull request in `canon-lint`, the job of `.github/workflows/prose-ambiguity-check.yml`, which holds the PR's `contracts/prose.lint.baseline.json` against the trusted base revision's copy (`--base-baseline`) so the baseline never grows (HR-13). From zheref/hatsu#448 the same run counts the shrink: the summary line carries `<n> removed over <base>` and `--json` carries `removedBaseline` (null with no base), summed per key, so a dropped row and a lowered count both count. The count is printed by the trusted revision's guard, so the first PR to show it is the first opened after this lands. The count over the last ten prose PRs is **owed**: no nen verb reads `canon-lint`'s count across pull requests (unfiled), so AC-4's second half is not delivered here.

## Sources

- zheref/hatsu#448 (the rows, AC-1 to AC-4, SC-1, SC-2, AS-1, AS-2, OQ-1); epic zheref/hatsu#454; the ruling record R-2026-10-23-21 under effort HA-IS-#450
- [Schedule recurring tasks in Claude Code Desktop](https://code.claude.com/docs/en/desktop-scheduled-tasks) and [Run prompts on a schedule](https://code.claude.com/docs/en/scheduled-tasks), both fetched 2026-10-23
- [`ROSTER.md`](../ROSTER.md) [HR-5](../ROSTER.md#hr-5) (the floor: a scheduler re-invokes a build, never a release), HR-13 (the ratchet)
- [`../../claude/skills/great-hiker/SKILL.md`](../../claude/skills/great-hiker/SKILL.md) § 7, [`dowsing-chain/SKILL.md`](../../claude/skills/dowsing-chain/SKILL.md) §§ 10–11, [`rikugan/SKILL.md`](../../claude/skills/rikugan/SKILL.md); [`prose.lint.json.md`](prose.lint.json.md)
- the printer's dry run: [`../ab/schedule-install.md`](../ab/schedule-install.md)
