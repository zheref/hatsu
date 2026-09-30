# jusshin — verification record

`hatsu:jusshin` was not ported from the frozen reference implementation; it was authored on 2026-09-30
against the design spec that fixes the `nen runner` verb family's flags, outputs and exit codes, and
against the operational learnings of bankai-core's `docs/SETUP-SELF-HOSTED-RUNNERS.md` (§§ 5–6 and the
troubleshooting table T7–T13), carried as rules and not as bankai machinery. **This file records what
was run, so the skill's prose quotes behaviour rather than intent** — and at authoring time nothing had
run yet: the verbs ship in nen `v0.18.0`. The table below lists the planned commands of the live run
against the first consumer, `zheref/nen`, on the maintainer's Windows 11 x64 host (machine code `NZ`,
local service account `lordzheref`, runner root `C:\GithubRunners`, three runners `NZ-NNR1..3` in the
`windows-x64` pool); each `pending` cell is filled from that run's output, verbatim, before the skill's
claims are relied on.

## 1. What ran, and what it answered

The one thing verified at authoring time is the grammar, against nen `0.17.0` on `PATH`.

| # | Command | Answer | Exit |
|---|---|---|---|
| 0 | `nen parse jusshin --grammar "[for <target>] [pool <pool>] [x <count>] [on <machine>] [--dry-run]"` with `for zheref/nen pool windows-x64 x 3 on NZ` · `""` · `hello` | all four slots filled · each `(clause absent)` · *"the line must open with 'for' to supply <target>, or omit that clause entirely -- 'hello' is neither."* | `0` / `0` / `2` |
| 1 | `nen runner inventory --target zheref/nen --repo <nen> --pool windows-x64 --json` | pending | pending |
| 2 | `nen runner plan --repo <nen> --target zheref/nen --pool windows-x64 --machine-code NZ --count 3 --consumer-code NN --root C:\GithubRunners --service-account lordzheref --out <nen>/.nen/jusshin/windows-x64.plan.json --json` | pending | pending |
| 3 | `nen runner script --plan <nen>/.nen/jusshin/windows-x64.plan.json --out C:\GithubRunners\nen-runners\_jusshin\register-windows-x64.ps1 --json` | pending | pending |
| 4 | the `launch` field of 3, run verbatim; the transcript's summary line | pending | pending |
| 5 | `nen runner verify --target zheref/nen --expect NZ-NNR1,NZ-NNR2,NZ-NNR3 --labels self-hosted,Windows,X64 --wait 120 --json` | pending | pending |
| 6 | `nen runner workflow --repo <nen> --pool windows-x64 --target zheref/nen --template "$hatsu_root/templates/runner-preflight.yml" --json` | pending | pending |
| 7 | `nen runner preflight --target zheref/nen --workflow runner-preflight.yml --wait 600 --json` | pending | pending |
| 8 | `nen runner enable --repo <nen> --target zheref/nen --pool windows-x64 --after-run <runId of 7> --json` | pending | pending |
| 9 | `nen runner enable … --after-run <a run id that is not a green preflight>` | pending — expected: nothing set | pending — expected `1` |
| 10 | a re-run of 2 after 4 (the resume) | pending — expected: `existing` names the three, and the planned slots start at `R4` | pending |

## 2. What these runs settle for the skill

Pending the run. Each claim the skill makes about a verb's output or exit code is checked against its
row here; a disagreement is fixed in the skill, never in this record.
