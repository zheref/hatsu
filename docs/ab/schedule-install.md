# A/B — `scripts/schedule_install.mts`, the schedule printer

Evidence for [`docs/config/schedule.md`](../config/schedule.md): what the printer does on the live
[`contracts/schedule.json`](../../contracts/schedule.json), recorded from a run on 2026-10-23 at
integration-branch base `1243b2720` (node `v24.16.0`, macOS). The maintainer's Hatsu checkout is shown as
`<hatsu>`, the scratch spec checkout as `<spec>`; the family is the fixture slug `fixture-family`, never a
product family's name.

## 1. Nothing is registered

Before and after every run below, `ls -la ~/.claude/scheduled-tasks` hashed the same: the directory does not
exist on this machine (`No such file or directory`), and the printer did not create it. The script opens no
file for writing, starts no child process and calls no network; the fixture proves the same with `HOME`
pointed at an empty scratch directory that stays empty (`nen shu test --repo <hatsu> --lane schedule-printer`).

## 2. The three exits

| Invocation | Exit | stderr |
|---|---|---|
| `--folder <hatsu> --spec-folder <spec> --family fixture-family` | `0` | (empty) |
| no flags | `1` | `unfilled: <spec> (recapture) -- pass --spec-folder` · `unfilled: <family> (recapture) -- pass --family` |
| `--register` | `2` | `schedule_install: unknown flag --register` |

A run with no flags still prints every row, keeping `<spec>` and `<family>` in the text, so a task registered
from it reads as incomplete rather than pointing at the wrong folder.

## 3. The full printout (exit `0`)

```text
$ node scripts/schedule_install.mts --folder <hatsu> --spec-folder <spec> --family fixture-family
schedule_install: 4 rows from contracts/schedule.json (ruling R-2026-10-23-21; scheduler claude-desktop-local).
NOTHING IS REGISTERED. Register each task yourself in Claude Desktop: Code tab -> Scheduled -> New task -> Set up manually;
under Advanced settings turn on "Only on this computer", then fill the fields below. After Create, press Run now once and
answer each permission prompt, so later runs do not stall. A task fires only while Desktop is open and the machine is awake.

=== drift-pass ===
Name:            hatsu-drift-pass
Description:     Quarterly canon drift pass: great-hiker evolve on every surface, dry first, one issue per drifted surface, nothing filed twice on the same day.
Trigger:         Custom -- 09:07 local on the first day of January, April, July and October; as Custom (Edit form): 7 9 1 1,4,7,10 *
Local folder:    <hatsu>
Worktree:        off
Permission mode: Ask permissions (the default); never a bypass mode
Model:           your Claude Code default
SKILL.md, as Desktop keeps it at ~/.claude/scheduled-tasks/hatsu-drift-pass/SKILL.md (the instructions box):
  | ---
  | name: hatsu-drift-pass
  | description: "Quarterly canon drift pass: great-hiker evolve on every surface, dry first, one issue per drifted surface, nothing filed twice on the same day."
  | ---
  |
  | Quarterly canon drift pass: row drift-pass of docs/config/schedule.md, ruling R-2026-10-23-21. Work read-only in this checkout: edit no file, commit nothing, push nothing, open no pull request; a pure data edit great-hiker section 7 step 5 would open is listed for the maintainer's typed hatsu:great-hiker call instead.
  |
  | 1. Dry. Run hatsu:great-hiker evolve over every surface and print the drift table (per surface, each changed row with the fetched line beside the guide's line, and every page that could not be fetched as unread with its status). File nothing in this step.
  |
  | 2. Reconcile. For each drifted surface run nen issue search --target zheref/hatsu --subject "Surface drift: <surface>". An open issue for that surface is amended (great-hiker section 7 step 4), never duplicated; an issue for that surface opened or closed today means the surface is skipped and said; a search that could not run is reported as not run, never as nothing found, and that surface is not filed.
  |
  | 3. File. File one issue per remaining drifted surface through hatsu:file, which shows its one plan and waits in this session for the maintainer's confirmation.
  |
  | End with the drift table, every issue filed or amended as a link, and every surface skipped with its reason. Never a release step (HR-5).

=== recapture ===
Name:            hatsu-family-recapture
Description:     Weekly dry recapture of one product family's living spec, reading every member's tip; the real recapture stays the maintainer's typed call.
Trigger:         Weekly -- Mondays at 08:07 local; as Custom (Edit form): 7 8 * * 1
Local folder:    <spec>
Worktree:        off
Permission mode: Ask permissions (the default); never a bypass mode
Model:           your Claude Code default
SKILL.md, as Desktop keeps it at ~/.claude/scheduled-tasks/hatsu-family-recapture/SKILL.md (the instructions box):
  | ---
  | name: hatsu-family-recapture
  | description: "Weekly dry recapture of one product family's living spec, reading every member's tip; the real recapture stays the maintainer's typed call."
  | ---
  |
  | Weekly family recapture, dry: row recapture of docs/config/schedule.md, ruling R-2026-10-23-21. Write nothing outside the scratch directory, write no run record, open no pull request.
  |
  | If this family has no first capture yet (zheref/hatsu#446), say so in one line and stop.
  |
  | Otherwise run hatsu:dowsing-chain recapture fixture-family --dry-run in this spec checkout and report, per member, the tip it read and what a real recapture would change.
  |
  | End with one line: changed members, or a byte-identical recapture said as such. The real recapture is the maintainer's typed hatsu:dowsing-chain recapture fixture-family, ending at its spec pull request's merge prompt at G2. Never a release step (HR-5).

=== morning-desk ===
Name:            hatsu-morning-desk
Description:     Weekday morning register: the Rikugan register page over one repository, every verdict quoted, the last idle run first.
Trigger:         Weekdays -- Monday to Friday at 07:33 local; as Custom (Edit form): 33 7 * * 1-5
Local folder:    <hatsu>
Worktree:        off
Permission mode: Ask permissions (the default); never a bypass mode
Model:           your Claude Code default
SKILL.md, as Desktop keeps it at ~/.claude/scheduled-tasks/hatsu-morning-desk/SKILL.md (the instructions box):
  | ---
  | name: hatsu-morning-desk
  | description: "Weekday morning register: the Rikugan register page over one repository, every verdict quoted, the last idle run first."
  | ---
  |
  | Morning desk: row morning-desk of docs/config/schedule.md, ruling R-2026-10-23-21. Strictly read-only: no label, no comment, no push, no merge.
  |
  | Run hatsu:rikugan for zheref/hatsu as register, each pull request's readiness quoted from nen pr ready, never judged by eye.
  |
  | If a hatsu:futon --idle run on zheref/hatsu ended since the previous desk, put its terminal state and its parked efforts above the fold and link that run's last report.
  |
  | End with the page's link. Never a release step (HR-5).

=== ratchet-shrink ===
not a task: runs in CI, .github/workflows/prose-ambiguity-check.yml job canon-lint
when: every pull request (opened, synchronize, reopened, ready_for_review): scripts/prose_ambiguity_check.mts held against the trusted base revision's contracts/prose.lint.baseline.json prints `<n> removed over <base>` in its canon-lint summary line and `removedBaseline` in --json
```

## 4. What it leaves undone

- The tag trigger of zheref/hatsu#448's AC-2: Desktop local tasks fire on a schedule only, and no nen verb
  reads a member's newest tag against the capture record (unfiled), so the recapture row polls weekly.
- The ten-PR shrink trend of AC-4: `canon-lint` prints each PR's `removed` count; nothing reads it across
  PRs (unfiled).
- Registration itself, which is the maintainer's: the schedule page's *What it decides* lists the Desktop steps.
