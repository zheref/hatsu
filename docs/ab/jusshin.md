# jusshin — verification record

`hatsu:jusshin` was not ported from the frozen reference implementation; it was authored on 2026-09-30
against the design spec that fixes the `nen runner` verb family's flags, outputs and exit codes, and
against the operational learnings of bankai-core's `docs/SETUP-SELF-HOSTED-RUNNERS.md` (carried in the
skill as local ids J1–J7), and verified live on 2026-09-30/10-01 against nen `0.18.0`→`0.18.1`. This
file records what was **run**, so the skill's prose quotes behaviour rather than intent. The run is the
skill's first: target `zheref/nen` (`<nen>` = its checkout, `C:\Users\zhere\Code\CLIs\nen`), on the
maintainer's Windows 11 x64 host — machine code `NZ`, pool `windows-x64` with labels `[self-hosted,
Windows, X64]`, identity `.\lordzheref`, runner root `C:\GithubRunners` — in Git Bash, under Hatsu
`0.68.x`–`0.69.1`. § 1a is that run; § 1b is the offline and refusal rows first taken at `0.18.0`
(history: `861d955e`), re-run at `0.18.1` on 10-01 in `<fx>`, a throwaway consumer carrying
`zheref/nen`'s `runners` block and `product_codes` (`HA`, `NN`) — reads and refusals that write
nothing to `zheref/nen`.

## 1. What ran, and what it answered

### 1a · The live run

| # | Command | Answer | Exit |
|---|---|---|---|
| 0 | `nen parse jusshin --grammar "[for <target>] [pool <pool>] [x <count>] [on <machine>] [--dry-run]" --line="for zheref/nen pool windows-x64 x 3 on NZ"` (re-run at `0.18.1`) | `target: zheref/nen` · `pool: windows-x64` · `count: 3` · `machine: NZ` | `0` |
| 1 | `nen runner inventory --target zheref/nen --repo '<nen>' --pool windows-x64` (a read) | before: `pool windows-x64 [self-hosted, Windows, X64]: 0 runner(s), 0 online, 0 free`, the three macOS runners `RJ2-NNR1..3` in `macos-arm64` · after (re-run 10-01): `zheref/nen: 6 self-hosted runner(s)`, `pool windows-x64 [self-hosted, Windows, X64]: 3 runner(s), 3 online, 3 free -- NZ-NNR1, NZ-NNR2, NZ-NNR3`, `unpooled: (none)` | `0` · `0` |
| 2 | `nen runner plan --repo '<nen>' --target zheref/nen --pool windows-x64 --machine-code NZ --count 3 --service-account lordzheref --out '<nen>\.nen\jusshin\windows-x64.plan.json' --json` | `consumerCode NN` · `root C:\GithubRunners` · `projectDir C:\GithubRunners\nen-runners` · `identity .\lordzheref` · `runnerVersion 2.337.0` · runners `NZ-NNR1, NZ-NNR2, NZ-NNR3` · `existing []`; download `actions-runner-win-x64-2.337.0.zip` (sha256 `1150692afa94e71f…`) | `0` |
| 3 | `nen runner script --repo '<nen>' --plan '<nen>\.nen\jusshin\windows-x64.plan.json' --out 'C:\Users\zhere\AppData\Local\nen\jusshin\register-windows-x64.ps1' --json` (rendered by nen `0.18.0`, the pin then — before nen#313's `--out`-under-root refusal; the path was already outside the root) | `needsElevation: true` · `scriptSha256 fa349ade4dbdbd3bbf0a8c32a825ac1ec1184af1872349094135de2459118028` · summary `C:\GithubRunners\nen-runners\_jusshin\register-*.summary`; launch `powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','C:\Users\zhere\AppData\Local\nen\jusshin\register-windows-x64.ps1'"` | `0` |
| 4 | row 3's launch, first attempt (22:54:47Z) | *"Start-Process : This command cannot be run due to the error: The operation was canceled by the user."* — UAC declined; no summary newer than the launch, so nothing registered (§ 5's row held) | — |
| 5 | the launch, second attempt (22:57:53Z) | `jusshin: 0 registered, 0 skipped, 3 failed` (`register-20260930-175757.summary`); server side `NZ-NNR1..3` registered but `offline`, no Windows service — the runner's service installer (`WindowsServiceControlManager`: *"Invalid windows credentials entered"* under `--unattended`) rejected a mistyped password **after** registering. A re-run before cleanup: `jusshin: 0 registered, 3 skipped, 0 failed` — a stale `.runner` is skipped as configured (zheref/nen#319). Remedy, the maintainer's (residue 3): registrations ids 24–26 deleted through the API on his word, the three `Runner<N>` folders removed in an Administrator shell | — |
| 6 | the launch, third attempt (23:14:59Z) | `jusshin: 3 registered, 0 skipped, 0 failed` (`register-20260930-181503.summary`); `Get-Service "actions.runner.zheref-nen.*"` → `NZ-NNR1`, `NZ-NNR2`, `NZ-NNR3` `Running`, StartType `Automatic`; server side all three `online`, `busy=false`, labels `self-hosted,Windows,X64` | — |
| 7 | `nen runner verify --target zheref/nen --expect NZ-NNR1,NZ-NNR2,NZ-NNR3 --labels self-hosted,Windows,X64 --wait 120` (re-run 10-01) | `ok: 3/3 runner(s) online on zheref/nen (1 attempt(s), waited 0s)`, rows `NZ-NNR1` · `NZ-NNR2` · `NZ-NNR3` each `ok` | `0` |
| 8 | `nen runner workflow --repo '<nen>' --pool windows-x64 --target zheref/nen --template "$hatsu_root/templates/runner-preflight.yml" --json` | `written: true` · `placeholders: null` · `runsOn [self-hosted, Windows, X64]`; shipped as zheref/nen#318 (merged), re-rendered through #320 (merged) after zheref/hatsu#177 (AppData matcher), #178 (first-match classifier, `$PATH:`-only `where.exe`), #179 (layout-agnostic remedy); every push ran it on the pool — runs 36791237018 (`NZ-NNR1`), 36794338630, 36798837545, 36799454071, 36802460051 (`NZ-NNR2`), all green | `0` |
| 9 | `nen runner preflight --target zheref/nen --workflow runner-preflight-windows-x64.yml --wait 600 --json` (the `x 0` resume, dispatched from `main`) | `runId 36802783501` · `conclusion success` · `verdict success` · `runnerName NZ-NNR2` · `runnerOs Windows` · `ref main` | `0` |
| 10 | `nen runner enable --repo '<nen>' --target zheref/nen --pool windows-x64 --after-run 36802783501 --json` | `variable NEN_WINDOWS_RUNNER` · `value online` · `previous null` · `changed true`; `gh variable list` → `NEN_WINDOWS_RUNNER online 2026-10-01T01:48:29Z`; `nen/gates.json` carries no `check_exclusions` row to remove | `0` |
| 11 | what the enable revealed: the first live `check-windows` (ci 36802734735, `NZ-NNR1`), then with `defaults: run: shell: bash` (zheref/nen#323, ci 36803257612) | first: failed at `bun install` — steps with no `shell:` ran as PowerShell script files under the service account, refused (*"running scripts is disabled on this system"*) · then: install, typecheck, lint pass; `bun run test` fails on 13 pre-existing win32 failures (nen effort `opus/kurapika/win32-suite-green`). The maintainer kept the variable `online` through it | `1` · `1` |

The skill's reviews ran on zheref/hatsu#174: 47 findings, 43 fixed, 4 deferred (zheref/nen#312, fixed
in `0.18.1`; zheref/hatsu#175 and #176, handbook questions). The off switch is named: `Stop-Service` on
the three services, and the variable back to its previous value (none).

### 1b · Offline rows, nen 0.18.0 → re-run at 0.18.1

| # | Command (`G` is row 0's grammar) | Answer at `0.18.1` | Exit |
|---|---|---|---|
| b1 | `nen parse jusshin --grammar "$G"`, `--line=""` · `--line="hello"` | each `(clause absent)` · *"the line must open with 'for' to supply <target>, or omit that clause entirely -- 'hello' is neither."* | `0` · `2` |
| b2 | the same, `--line="for zheref/nen x 0"` · row 0's line with `--dry-run` appended | `count: 0`, pool and machine absent · `[--dry-run]: present` | `0` · `0` |
| b3 | row 2's `plan` with `--repo '<fx>' --out '.nen/jusshin/windows-x64.plan.json'` | `.nen/jusshin/` created; with `NZ-NNR1..3` standing, `existing: [NZ-NNR1, NZ-NNR2, NZ-NNR3]` and runners `NZ-NNR4..6` — the lowest free slots (at `0.18.0`, before the run: `NZ-NNR1..3`, `existing: []`) | `0` |
| b4 | plan: `--count 0` · `--count 17` · `--machine-code nz-1` · `--pool linux-x64` · `--target zheref` · `--service-account <an e-mail>` | *"--count must be a whole number from 1 to 16; got 0."* (`got 17.`) · *"--machine-code 'nz-1' is not a machine code: one to eight letters or digits (it is upper-cased), e.g. NZ."* · *"no pool 'linux-x64' in the runners block. Declared: windows-x64, macos-arm64."* · *"--target takes an owner/name repository slug and 'zheref' is not one."* · *"… is not a local account."* | `2` each |
| b5 | plan, `macos-arm64`: `--service-account` with `--root '/Users/x/actions-runners'` (`MSYS_NO_PATHCONV=1`) · no `--root` · that root without `MSYS_NO_PATHCONV` | *"--service-account does not apply to a macOS pool … Drop the flag."* · *"the pool's root.darwin '~/actions-runners' starts with '~', and this process cannot expand it for a macOS host from win32. Pass --root …"* · *"--root 'C:/Program Files/Git/Users/x/actions-runners' is not an absolute path on a macOS host"* | `2` each |
| b6 | plan, `product_codes` naming no `zheref/nen` · a `workflow.json` with no `runners` block | *"… Pass --consumer-code <CODE>."* · *"… declares no 'runners' block, so there is no pool to act on. Declare one: …"* | `2` · `2` |
| b7 | `nen runner script --repo '<fx>' --plan <b3's> --out 'C:\Users\zhere\AppData\Local\nen\jusshin\register-windows-x64.ps1' --dry-run --json` | `needsElevation: true`, `written: false`, `launch` as row 3's — no `-PassThru`: the launch's exit is not the script's | `0` |
| b8 | script: `--out 'C:\Program Files\x\register.ps1'` · a plan whose `identity` is `ask` · `--out 'C:\GithubRunners\nen-runners\register.ps1'` (new, nen#313) | *"must end in .ps1 and carry no space or quote"* · *"the plan's identity is 'ask' … Re-run 'nen runner plan' with --service-account <name>"* · *"… is under the plan's runner root 'C:\GithubRunners'. Write the script where only you can change it before it runs elevated -- %LOCALAPPDATA%\nen\jusshin\ …"* | `2` each |
| b9 | unquoted in Git Bash: `echo C:\GithubRunners` · plan `--root C:\GithubRunners` · b7 with the `--out` unquoted | `C:GithubRunners` · *"--root 'C:GithubRunners' is not an absolute Windows path"* · *"(dry run) would write <fx>\UserszhereAppDataLocalnenjusshinregister-windows-x64.ps1"* | — · `2` · `0` |
| b10 | row 8's `workflow` on `<fx>` with `--dry-run` · `--pool linux-x64` · a template carrying `@@BOGUS@@` · a re-render over a hand-edited file | `out: <fx>\.github\workflows\runner-preflight-windows-x64.yml`, `written: false` · the b4 no-pool refusal · *"still carries @@BOGUS@@ … Nothing was written."* · *"exists and differs from the rendering in 1 line(s). Nothing was written; pass --force to overwrite it."* | `0` · `2` · `1` · `1` |
| b11 | `nen runner verify --target zheref/nen` (reads): `--expect ""` · `--expect NZ-NNR1,NZ-NNR9` · `--expect NZ-NNR1 --labels self-hosted,Linux` | *"--expect is required. It lists the runner names that must be online."* · `NOT READY: 1/2 runner(s) online`, `NZ-NNR9` `missing` · `labels: missing Linux` | `2` · `1` · `1` |
| b12 | `bash scripts/runner_preflight_fixture_check.sh` | *"runner-preflight: every property holds"* | `0` |

## 2. What these runs settle for the skill

- **The summary file is the session's only read** (rows 4–6): the elevated launch returns no exit the
  session can trust, so the outcome is the `register-<ts>.summary` newer than the launch, quoted.
- **A declined UAC prompt leaves no summary** (row 4): no newer summary means nothing registered, and
  the skill says so rather than reading an older file.
- **A mistyped password registers, then fails the service** (row 5), in the runner's own order — so
  `failed` can leave server-side registrations and local folders the skill cannot remove. That is
  residue 3, the maintainer's to clear; until zheref/nen#319 lands, a leftover `.runner` reads
  `skipped`, not `failed`.
- **`x 0` resumes** (rows 7, 9): plan and § 5 are skipped, § 6 expects the inventory's `NZ` runners
  in the pool, and the run goes on to the preflight after the workflow's merge.
- **The push-triggered preflight is the pre-merge proof** (row 8); `workflow_dispatch` needs the file on
  the default branch, so the dispatched preflight runs only after the merge (row 9).
- **`enable` set the variable on a green run of the pool's own workflow** (row 10): on run 36802783501,
  dispatched from `main`, it checked the workflow name, `completed`/`success` and the jobs' labels. It
  does not compare the run's branch or the workflow's blob with the default branch's, so a green run
  of an edited preflight on another branch would also pass — zheref/nen#319's second gap. The skill
  passes only § 7's `runId`, whose `preflight` dispatches on the default branch.
- **Every path is single-quoted, and the script lives outside the root** (b8, b9): `--out` creates its
  parent (b3), and an `--out` under the runner root is refused at `0.18.1`.
- **Registration is not capability — held twice** (rows 8, 11): the preflight proves the pool's declared
  tools (git, bash, gh), not the host's PowerShell execution policy nor the consumer suite's
  portability. A green preflight enables the gate; the first real job is still the first evidence that
  the consumer's CI runs there.

Exits covered by a row: `parse` `0`, `2`; `inventory` `0`; `plan` `0`, `2`; `script` `0`, `2`;
`verify` `0`, `1`, `2`; `workflow` `0`, `1`, `2`; `preflight` `0`; `enable` `0`. **Unexercised here**:
`inventory` `1` (a 403), `plan` `1` (a planned name taken), `script` `1`, `preflight` `1` and `2`
(the workflow not on the ref), `enable` `1` (not a green preflight) and `2` (a pool with no
`enableVariable`), and `5` (gh could not be started) on every verb — the skill's prose for those rests on
`nen runner --help` alone. Each other claim the skill makes about a verb's output or exit code is
checked against its row here; a disagreement is fixed in the skill, never in this record.
