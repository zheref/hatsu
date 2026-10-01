# jusshin — verification record

`hatsu:jusshin` was not ported from the frozen reference implementation; it was authored on 2026-09-30
against the design spec that fixes the `nen runner` verb family's flags, outputs and exit codes, and
against the operational learnings of bankai-core's `docs/SETUP-SELF-HOSTED-RUNNERS.md` (carried in the
skill as local ids J1–J7), and verified live on 2026-09-30/10-01 against nen `0.18.0`→`0.18.1`. This
file records what was **run**, so the skill's prose quotes behaviour rather than intent. The run is the
skill's first: target `zheref/nen` (`<nen>` = its checkout, `C:\Users\zhere\Code\CLIs\nen`), on the
maintainer's Windows 11 x64 host — machine code `NZ`, pool `windows-x64` with labels `[self-hosted,
Windows, X64]`, identity `.\lordzheref`, runner root `C:\GithubRunners` — in Git Bash, under Hatsu
`0.68.x`–`0.69.1`. The offline refusal rows this file carried before the run (a fixture at `0.18.0`)
are in its history at `861d955e`.

## 1. What ran, and what it answered

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
- **`enable` is fail-closed on a green run of the pool's own workflow** (row 10): its `--after-run` is
  that run's id, and nothing else sets the variable.
- **Registration is not capability — held twice** (rows 8, 11): the preflight proves the pool's declared
  tools (bash, jq, gh), not the host's PowerShell execution policy nor the consumer suite's
  portability. A green preflight enables the gate; the first real job is still the first evidence that
  the consumer's CI runs there.

Each claim the skill makes about a verb's output or exit code is checked against its row here; a
disagreement is fixed in the skill, never in this record.
