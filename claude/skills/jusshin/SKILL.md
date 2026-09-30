---
name: jusshin
description: Raise a consumer repository's self-hosted GitHub Actions runners — register one declared pool's runners on any GitHub-supported OS and arch as boot-persistent services, prove the pool with a preflight job that runs as the service does, and only then switch its jobs on; every deterministic step a nen runner verb, every human step handed over. Use when the maintainer invokes hatsu:jusshin [for <owner/repo>] [pool <id>] [x <count>] [on <machine-code>] [--dry-run], or asks to add, register or bring back self-hosted runners. Never elevates itself, never handles a password or token, never registers on a repository the maintainer did not type, never sets the enable variable without a green preflight run, never merges.
---

# Jusshin — the fleet, raised by hand once and standing on every boot

**Nature: Transmuter** (host machinery); **Manipulator** for the variable and the PR. Many bodies, one
act: one consent, and every planned runner stands as a service.

> **Plan the names, render the host script, let the maintainer consent, then prove the pool from inside
> a job before anything is switched on.**

The verbs are nen `v0.18.0`'s `runner` family, reading the consumer's `nen/workflow.json` → `runners`
(`naming`, `pools[]`). [`tenkai`](../tenkai/SKILL.md) § 5b **derives** which runner a readiness
workflow targets; jusshin **provisions** the pools a consumer declares.

## 0. Standalone entry

Typed by the maintainer — its wired position; no composite holds it
([`docs/STANDALONE-ENTRY.md`](../../../docs/STANDALONE-ENTRY.md) § 7b).

| Step | What jusshin does |
|---|---|
| **`P1`** | `hatsu:ten jusshin`, unconditionally — the `runner` verbs exist from nen `0.18` |
| **`P2`** | `nen wc classify --repo <path> --json` on the **consumer** checkout, read out loud |
| **`P1b`, `P3`** | **Declined**: the subject is a host and a pool, not a change set; there is no delta |
| **`P4`** | § 2's asks, one per missing item |
| **`P5`** | `standalone entry · <target> · pool <id> <labels> · machine <CODE> · x <n> · identity <id> · root <dir> · not running: nothing` |

## 1. Invocation

```
hatsu:jusshin [for <owner/repo>] [pool <id>] [x <count>] [on <machine-code>] [--dry-run]
```

```bash
nen parse jusshin --grammar "[for <target>] [pool <pool>] [x <count>] [on <machine>] [--dry-run]" --line="<line>"
```

Clauses parse **in this order only**; a line opening with a dash needs `--line=`. An anchor with no
value is dropped, and an out-of-order clause is swallowed by the slot before it — so the echo is read
back and a slot that is not one value is asked again (`missing-argument`). `--dry-run` renders § 5's
script and launches nothing.

## 2. Elicit

A missing argument or configuration item is asked for and set up inline (`missing-argument`,
`missing-configuration`; [`WORKFLOW.md`](../../../docs/WORKFLOW.md) § 4 *Ask, set up, continue*).

| Item | Source | Asked as |
|---|---|---|
| target | the checkout's `origin`, listed for reference | typed, never picked (`missing-maintainer-choice`) |
| machine code | `^[A-Z0-9]{1,8}$` | typed (same row) |
| service identity | § 4's table | typed (same row) |
| runner root | the pool's `root.<os>`, for reference | typed (same row) |
| pool | `runners.pools[]`, this host's OS/arch starred | picker (`missing-argument`) |
| count | no default; `0` registers nothing, starred when this machine already stands in the pool | picker (same row) |
| consumer code | `nen/repos.json` → `product_codes` | picker (same row) |

**No `runners` block** (a verb exits `2` naming the key): `missing-configuration`, asked per field,
written into the consumer's `nen/workflow.json`, `nen schema check` and `nen stage triage` run on it
(row `secret-shape`), and **landed through its declaration PR before a verb reads it live**. A **public** target quotes tenkai
§ 5b: a fork PR can execute code on a self-hosted runner, so the pool's jobs take no fork
`pull_request` event.

## 3. Inventory and plan

```bash
nen runner inventory --target <t> --repo <path> --pool <id> --json
nen runner plan --repo <path> --target <t> --pool <id> --machine-code <CODE> --count <n> \
  --consumer-code <CC> --root <dir> --service-account <name> --out <path>/.nen/jusshin/<id>.plan.json --json
```

The inventory is read first on every run, so a re-run resumes: standing names are `existing`, and
`plan` only adds the lowest free slots; `x 0` skips `plan` and § 5. Exit `0` → § 4. `1`: inventory's *"needs
admin on `<target>`"* is refused, never asked; plan's name-exists,
or no-download refusal is quoted and the item re-asked. `2`: the declaration (§ 2), a count outside 1..16, or
*"pass --consumer-code"* (`missing-argument`). `5`: `gh` absent (row `missing-tool`). `mkdir -p
"<path>/.nen/jusshin"` first.

## 4. Host readiness — the three rules

- **W1 — machine-located and machine-readable.** A service resolves tools on the **machine** `PATH`,
  as its own account, with no profile: each declared tool must be on it **and** grant that account (or
  `BUILTIN\Users`) `ReadAndExecute` on the file the entry resolves to.
- **W2 — `126` ≠ `127`.** `127` is not found — location. `126` is found and refused — an ACL; every
  `PATH` check passes during a `126`, so re-running them proves nothing.
- **W3 — registration is not capability.** `online` and `Idle` prove the runner process. Only a job
  running **as the service** observes W1 and W2: § 7's preflight, never the session's own `where.exe`,
  proving only the session.

| Host | Service identity | Refused |
|---|---|---|
| Windows | a **local-only** `Users` account, logged into once so its profile exists | a Microsoft account or Hello PIN (no local hash); `NETWORK SERVICE` unless typed `network-service` (no profile: it dies starting) |
| Linux | the user `svc.sh install <user>` takes (systemd) | — |
| macOS | a launchd agent as the invoking user; not asked | — |

## 5. Render and run the host script

```bash
nen runner script --plan <path>/.nen/jusshin/<id>.plan.json --out <projectDir>/_jusshin/register-<id>.<ps1|sh> --json
```

The script mints each token itself, verifies the download's SHA-256, skips a runner already
configured, and grants `(RX)` on the root and project dirs. What runs it is `--json`'s **`launch`
field, verbatim** — never typed from memory:

- **Windows**: the session runs `launch`. The UAC consent and the service-account password, typed
  once into the elevated window, are the maintainer's on-device acts (row `on-device-act`), said
  before the launch. Afterwards the newest `<projectDir>\_jusshin\register-*.log` is read and its
  `jusshin: <n> registered, <m> skipped, <k> failed` line quoted.
- **Linux**: `sudo bash <script>` is **printed for the maintainer**, never run — an install needing
  `sudo` is refused, never asked (WORKFLOW § 4).
- **macOS**: the session runs `launch` (`bash <script>`); a `-` PID in its `launchctl print` is the
  Background Task Management hold — § 7's table, row T7.

Script exit `3` (not elevated), `5` (`gh`), `6` (checksum mismatch: refused, never retried) and `1`
(a runner not Running) are quoted; § 6 decides what stands.

## 6. Verify

```bash
nen runner verify --target <t> --expect <name,…> --labels <pool labels> --wait 120 --json
```

Exit `0` → § 7. Exit `1` quotes each row (`missing | offline | labels: missing <x>`), read against
§ 7's table. **Never a partial pass.**

## 7. Prove the pool

```bash
nen runner workflow --repo <path> --pool <id> --target <t> --template "$hatsu_root/templates/runner-preflight.yml" --json
```

On this effort's branch (`hatsu:breath jusshin-<id>` on `<path>`), committed through
`hatsu:kokusen --type ci --scope runners`. Exit `1` (an existing file differs) is asked; `--force`
only on the answer. A consumer whose policy wants SHA pins re-pins `actions/checkout`
in the PR; a red check there is row `red-lint`; a registration-first guard takes tenkai § 5a's
two-PR order. **The branch is ready to go up; `hatsu:mukai` is the maintainer's call**, at
the consumer's gate. After the merge, `x 0` resumes here.

```bash
nen runner preflight --target <t> --workflow <pool.preflightWorkflow> --wait 600 --json
```

Exit `0` (quote `runId`, `runnerName`) → § 8. Exit `2` — not on the ref: *"merge the preflight
workflow first"*. Exit `1`: the failing job's log, read against this table; *queued at the deadline*
is no free runner, quoted with the inventory. Every remedy is the maintainer's act on the host, then
§ 7 again:

| Seen | Row | Remedy |
|---|---|---|
| service *"cannot start … timely fashion"* | T8 | a local account, logged in once; § 5 again |
| `config.cmd` rejects the password | T9 | a local-only account |
| `Access to the path … is denied` | T10 | `(RX)` on every parent up the hierarchy |
| exit `127` | T11 | machine-scope install; add `C:\Program Files\Git\bin` to `PATH` (no installer does); restart |
| exit `126` | T12 | created in place under `C:\Program Files\<tool>\`, never a winget portable or a `Move-Item`; `Get-Acl` shows `Users` `ReadAndExecute`; restart |
| landed on another OS | T13 | `runs-on` as rendered; an online runner with all three labels on **this** repository |
| macOS runner offline after start | T7 | Login Items → Allow in the Background, then `launchctl kickstart -kp gui/$(id -u)/<service>`, per runner |

**A service reads `PATH` at start**: after any install, `Get-Service "actions.runner.<owner>-<repo>.*" |
Restart-Service`, elevated — the maintainer's.

## 8. Switch it on

```bash
nen runner enable --repo <path> --target <t> --pool <id> --after-run <runId> --json
```

Exit `0`: `variable`, `value`, `previous` quoted. Exit `2`: not variable-gated — the jobs are live on
registration, said. Exit `1`: the run is not a green preflight of this pool — **nothing is
set**. Then the consumer's `nen/gates.json` → `check_exclusions[]`: a row excluding this pool's check
*until the runner is enabled* is removed through the file's own key at the consumer's gate
(`missing-configuration`).

## 9. Report

The P5 line; the fleet table — **name · labels · status · service · install dir** — from §§ 3 and 6;
the script's summary line; the preflight run; the enable line. Then, every run, last:

```
Next: <one line>
```

The first that holds: **dry run** — the same line without `--dry-run`; **a refusal or host remedy** —
the one act that unblocks it, then `hatsu:jusshin` again; **preflight unmerged** — `hatsu:mukai` in
`<path>`, then `hatsu:jusshin for <t> pool <id> x 0`; **live** — *nothing — the pool is live*. Then the
hand-back line ([`STANDALONE-ENTRY.md`](../../../docs/STANDALONE-ENTRY.md) § 6). Never a picker option.

## Residue

1. **The elevated launch has no verb** — the UAC consent is a human act by design.
2. The shared `_work/_actions` cache.
3. Removal and deregistration.
4. Runner groups on organization accounts.
5. `--ephemeral` supervisors.
6. `nen parse` carries no alternation and no integer slot, as for great-hiker; § 1's read-back stands in.

Listed in [PROCESS.md](../../../docs/PROCESS.md) § *Residue*.

## Authority and hard limits

**Permitted:** the seven `nen runner` verbs; the plan under `<path>/.nen/`, the script under the
project dir's `_jusshin`; `launch`, verbatim; the preflight workflow on this effort's branch; `nen runner enable` on
a green run; the `runners` declaration and the `check_exclusions` edit on the maintainer's answer.
**Not permitted:** another consumer's runners, a gate, elevation.

- **Never types a password, registration token or `gh` token** into chat, a file, a log or any
  argument the session runs — the elevated script mints its own under the maintainer's eyes.
- **Never elevates itself**; `config.cmd`, `config.sh` and `svc.sh` run only inside the rendered script.
- **Never renders a bare `self-hosted`** or an undeclared label set; never names a runner outside
  `runners.naming`.
- **Never registers on a repository the maintainer did not type**, and never sets the enable variable
  without a green preflight run id.
- **Never merges, never improvises a Nen-owned operation** — a missing verb is residue; the trailer is
  `Hatsu-Agent: kurapika`. **Never ends without the Next block.**
