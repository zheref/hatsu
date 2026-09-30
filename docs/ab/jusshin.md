# jusshin — verification record

`hatsu:jusshin` was not ported from the frozen reference implementation; it was authored on 2026-09-30
against the design spec that fixes the `nen runner` verb family's flags, outputs and exit codes, and
against the operational learnings of bankai-core's `docs/SETUP-SELF-HOSTED-RUNNERS.md` (§§ 5–6 and
§ *Troubleshooting*, rows T7–T13, carried in the skill under local ids J1–J7), carried as rules and not
as bankai machinery. **This file records what was run, so the skill's prose quotes behaviour rather than
intent.** § 1 is what ran offline — or as a read that registers nothing — at nen `0.18.0`; § 2 is the
live run against the first consumer, `zheref/nen`, on the maintainer's Windows 11 x64 host (machine code
`NZ`, local service account `lordzheref`, runner root `C:\GithubRunners`, three runners `NZ-NNR1..3` in
the `windows-x64` pool), each `pending` cell filled from that run's output, verbatim, before the skill's
claims about it are relied on.

## 1. What ran at nen `0.18.0`, and what it answered

2026-09-30, on that host, in Git Bash, `nen --version` → `0.18.0`. `<fx>` is a throwaway consumer
carrying `zheref/nen`'s own `runners` block (from nen `main` at `53d80287`: pools `windows-x64`,
`NEN_WINDOWS_RUNNER`, preflight `runner-preflight-windows-x64.yml`; and `macos-arm64`, ungated) and a
`nen/repos.json` whose `product_codes` are `HA` and `NN`. The grammar is
`G = "[for <target>] [pool <pool>] [x <count>] [on <machine>] [--dry-run]"`.

| # | Command | Answer | Exit |
|---|---|---|---|
| 0 | `nen parse jusshin --grammar "$G" --line="for zheref/nen pool windows-x64 x 3 on NZ"` | `target: zheref/nen` · `pool: windows-x64` · `count: 3` · `machine: NZ` | `0` |
| 1 | the same, `--line=""` · `--line="hello"` | each `(clause absent)` · *"the line must open with 'for' to supply <target>, or omit that clause entirely -- 'hello' is neither."* | `0` · `2` |
| 2 | the same, `--line="for zheref/nen x 0"` · with `--dry-run` appended to row 0's line | `count: 0`, pool and machine absent · `[--dry-run]: present` | `0` · `0` |
| 3 | `nen runner inventory --target zheref/nen --repo '<fx>' --pool windows-x64` (a read) | `zheref/nen: 3 self-hosted runner(s)` — `RJ2-NNR1..3`, macOS ARM64, online · `pool windows-x64 [self-hosted, Windows, X64]: 0 runner(s), 0 online, 0 free` | `0` |
| 4 | `nen runner plan --repo '<fx>' --target zheref/nen --pool windows-x64 --machine-code NZ --count 3 --service-account lordzheref --out '.nen/jusshin/windows-x64.plan.json' --json` (a read; registers nothing) | `consumerCode: NN` (derived), `root: C:\GithubRunners` (the pool's), `identity: .\lordzheref`, `actions-runner-win-x64-2.337.0.zip`, runners `NZ-NNR1..3` in `C:\GithubRunners\nen-runners\Runner1..3`, `existing: []`; **`.nen/jusshin/` did not exist and the verb created it** | `0` |
| 5 | plan refusals: `--count 0` · a macOS pool with `--service-account` (and an absolute `--root`) · a macOS pool without `--root`, from win32 · `--machine-code nz-1` · `--pool linux-x64` · `--service-account zheref@gmail.com` · `--target zheref` · a `repos.json` with no `consumers` | *"--count must be a whole number from 1 to 16; got 0."* · *"--service-account does not apply to a macOS pool … Drop the flag."* · *"the pool's root.darwin '~/actions-runners' starts with '~', and this process cannot expand it for a macOS host from win32. Pass --root …"* · *"is not a machine code"* · *"no pool 'linux-x64' in the runners block. Declared: windows-x64, macos-arm64."* · *"is not a local account …"* · *"--target takes an owner/name repository slug"* · *"… Pass --consumer-code <CODE> instead."* | `2` each |
| 6 | `nen runner script --repo '<fx>' --plan '.nen/jusshin/windows-x64.plan.json' --out 'C:\Users\zhere\AppData\Local\nen\jusshin\register-windows-x64.ps1' --dry-run --json` | `needsElevation: true`, `written: false`, `launch`: `powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','C:\Users\zhere\AppData\Local\nen\jusshin\register-windows-x64.ps1'"` — the script outside the runner root, and no `-PassThru`: the launch's own exit is not the script's | `0` |
| 7 | the same, `--out 'C:\Program Files\x\register.ps1'` · a plan whose `identity` is `ask` | *"must end in .ps1 and carry no space or quote"* · *"the plan's identity is 'ask' … Re-run 'nen runner plan' with --service-account <name>"* | `2` · `2` |
| 8 | `nen runner workflow --repo '<fx>' --pool windows-x64 --target zheref/nen --template "$hatsu_root/templates/runner-preflight.yml" --dry-run --json` · `--pool linux-x64` · a template carrying `@@BOGUS@@` | `out: <fx>\.github\workflows\runner-preflight-windows-x64.yml`, `written: false` · *"no pool 'linux-x64' …"* · *"the rendered workflow still carries @@BOGUS@@ … Nothing was written."* | `0` · `2` · `1` |
| 9 | **unquoted paths in Git Bash**: `echo C:\GithubRunners` · `plan … --root C:\GithubRunners` · `script … --out C:\Users\zhere\AppData\Local\nen\jusshin\register-windows-x64.ps1 --dry-run` | `C:GithubRunners` · *"--root 'C:GithubRunners' is not an absolute Windows path"* · *"(dry run) would write <fx>\UserszhereAppDataLocalnenjusshinregister-windows-x64.ps1"* — the backslashes eaten, the file relative to the working tree | — · `2` · `0` |
| 10 | `nen runner verify --target zheref/nen --expect ""` | *"--expect is required. It lists the runner names that must be online."* — why `x 0` refuses an empty set before it reaches this | `2` |
| 11 | `bash scripts/runner_preflight_fixture_check.sh` | every conjunct `ok` on the template and on the `windows-x64` and `macos-arm64` renderings; the hostile copy, a bare `self-hosted` and a leftover placeholder refused; *"runner-preflight: every property holds"* | `0` |

## 2. The live run — pending

| # | Command | Answer | Exit |
|---|---|---|---|
| L1 | row 4's `plan`, on the nen checkout (`--repo '<nen>'`) | pending | pending |
| L2 | row 6 without `--dry-run` | pending | pending |
| L3 | the `launch` field of L2, run verbatim through the harness's prompt; the `register-<ts>.summary` newer than it (needs a nen `0.18.1` rendering, zheref/nen#312) | pending | pending |
| L4 | `nen runner verify --target zheref/nen --expect NZ-NNR1,NZ-NNR2,NZ-NNR3 --labels self-hosted,Windows,X64 --wait 120 --json` | pending | pending |
| L5 | row 8 without `--dry-run`, on the effort's branch; the PR through `mukai` | pending | pending |
| L6 | `nen runner preflight --target zheref/nen --workflow runner-preflight-windows-x64.yml --wait 600 --json`, after the merge | pending | pending |
| L7 | `nen runner enable --repo '<nen>' --target zheref/nen --pool windows-x64 --after-run <runId of L6> --json` | pending | pending |
| L8 | `nen runner enable … --after-run <a run id that is not a green preflight>` | pending — expected: nothing set | pending — expected `1` |
| L9 | `hatsu:jusshin for zheref/nen pool windows-x64 x 0 on NZ` after L3 (the resume) | pending — expected: § 6 expects `NZ-NNR1..3` from the inventory, no plan | pending |

## 3. What § 1 settles for the skill

- **`--out` creates its parent** (row 4): the skill carries no `mkdir` before `plan`.
- **A macOS pool takes no `--service-account`**, and a `~` root cannot be planned from another OS
  (row 5): § 3 omits the flag for macOS, and the root is asked only when it cannot be derived.
- **Every path argument is single-quoted** (row 9); the Windows script path has no space (row 7).
- **The Windows launch returns before the script's exit is known** (row 6): § 5 reads the summary file.
- **`workflow`'s exit `1` is three causes** (row 8, USAGE): only *"differs"* is asked; a placeholder or
  invalid YAML is a finding against the template.
- **An empty `--expect` is a usage error** (row 10): `x 0` refuses an empty pool first.

Each claim the skill makes about a verb's output or exit code is checked against its row here; a
disagreement is fixed in the skill, never in this record.
