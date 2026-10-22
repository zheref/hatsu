# The Nen contract (D10)

> **Hatsu does not improvise shell.** Every deterministic step a skill takes is a verb of the
> [`nen`](https://github.com/zheref/nen) CLI, and the dependency on that binary is **hard**,
> **version-ranged** and **fail-closed with auto-install**. This page is the long form of the README's
> *Nen contract* section: what the contract file declares, how the version range is decided, what the
> warm-up does when the range is not met, and how the binary is bound on your host. It applies the same way
> on every surface Hatsu runs on: Claude Code, Codex, Cursor and Antigravity.

| | |
|---|---|
| **The file** | [`nen/contract.json`](../nen/contract.json), the single source of truth for every version, ref, URL and command on this page |
| **Executed by** | the [`ten`](../claude/skills/ten/SKILL.md) skill, at the start of every session and before any other Nen-owned work |
| **Key-by-key reference** | [`docs/config/contract.json.md`](config/contract.json.md) |
| **The policy half** | [`nen/workflow.json`](../nen/workflow.json), documented in [`docs/WORKFLOW.md`](WORKFLOW.md) and [`docs/config/workflow.json.md`](config/workflow.json.md) |


**[`nen/contract.json`](../nen/contract.json) is the single source of truth.** Every version, ref, URL and
command echoed anywhere else — this page included — is a convenience copy of a value that lives there.
**Where a copy disagrees with the contract, the contract wins and the copy is the bug.** The
[`ten`](../claude/skills/ten/) skill executes it at the start of every session, before any
other Nen-owned work.

The file sits where nen itself looks for a repository's dependency declaration — `nen/contract.json`, in
nen's own shape (`dependency.version_probe` as an argv array, `dependency.bootstrap` nested inside
`dependency`) — so that nen validates it rather than merely tolerating it:

```sh
nen schema check --repo <this checkout>
#   ok    nen/contract.json  dependency (nen >= 0.10, pinned v0.10.0), project (2 lanes: plugin, plugin-bump-guard; 11 verbs; 1 toolchain entry)
#   ok    nen/workflow.json  coverage 80/85/90 (touched), branch '{model}/{persona}/{descriptor}' off 'main', checks: lint
```

(Four taxonomy rows print above those two — three `FAIL` (`nen/labels.json`, `nen/repos.json`,
`nen/colors.yml`) and one `warn` (`nen/gates.json`) — and the command exits `1`: Hatsu ships no taxonomy of
its own, `schema check` requires the three of a repository that carries one, and only warns on the fourth,
which `pr ready` can take by `--gates` instead. The two `ok` rows are the ones this repository owns. **There
is no `schemas/` fallback at this pin** — it was removed in nen `v0.5.0`, so `nen/` is the only directory any
taxonomy-reading verb reads from, and a repository carrying a file only under `schemas/` is refused with the
migration named.) Every
Hatsu-authored key beside nen's own — the zero-major caveat, the two install paths, the halt template, the
no-`jq` rule — is preserved verbatim by nen's loader and read by nothing in nen. There is deliberately no
second copy: it was `nen.contract.json` at the root through `v0.2.0`.

Since `v0.4.0` the same file also carries a **`project`** block — Hatsu's own lane, written by hand because
`nen shu detect --repo .` answers *no lane detected* for a bash-and-markdown repository. `lint` is
`claude plugin validate . --strict`; every other verb of the family is an explicit `unsupported` **seat**
stating in this repository's words why it does not exist, because a seat is exit `4`, a stated fact, while an
omission is exit `2`, a broken declaration. Its policy half, [`nen/workflow.json`](../nen/workflow.json), is
**validated by nen at the pinned build** — the second `ok` row above, with a malformed key reported as a
FAIL by pointer — and [`docs/WORKFLOW.md`](WORKFLOW.md) documents both.

## The range

*Current pin, echoed for convenience:* **`nen >= 0.24`**, with the bootstrap installing **`v0.24.0`**.
Those are two values and they move independently (`scripts/plugin_version_refs.sh --check-nen-pin` exits `1` when this line disagrees with the contract; the `plugin-version-refs-guard` lane runs it on the committed tree, by hand at each repin, and no CI step runs it yet). Hatsu adopts the phase and usage `--dial`, `nen session record`/`show` and report data `sessions[]` (v0.24.0, zheref/hatsu#321), the `nen parse` list slots and alternations and the `--label`/`--severity` filters on `nen backlog fetch` and `nen report data`, executed by `hatsu:backlog-state` and `hatsu:backlog-board` (v0.22.0, zheref/hatsu#297), nen's own reading of `nen/gates.json` — `checks.excluded` in place of Hatsu's retired `check_exclusions`, and `round_policy.minRounds`/`.maxRounds` as nen keys, with the request ceiling in `nen pr request-reviews` (v0.21.0, zheref/hatsu#227) — the `nen classify` and `nen direct` families, executed by `hatsu:classify` and `hatsu:direct`, and the round quorum that fulfils its members' rounds (v0.20.0), the `nen runner` family, introduced in
v0.18.0 and executed by `hatsu:jusshin`, with its interactive desktop mode and `@@MODE@@` (v0.19.0), on top of `nen canon pin` and `nen canon mirror generate|check
--surfaces` (v0.16.0, `hatsu:limbo`), the futon label selector, `then` skill chains and advance-go gate, the
`library` kind, `nen release unit-check` and `nen pr merge --release-unit` (v0.15.0, fail-closed in
v0.15.1); each feature requirement raised the minimum. Nen's compatibility floor stayed 0.7 until v0.17.0
raised it to 0.17, v0.18.0 to 0.18, v0.19.0 to 0.19, v0.20.0 to 0.20, v0.21.0 to 0.21, v0.22.0 to 0.22 and, by v0.24.0, to 0.24, each for breaking consumer notes, which this pin absorbs. Every repin's adoptions and absorbed notes are in
[`docs/history/nen-repins.md`](history/nen-repins.md).

**The range is nen's answer, not this README's arithmetic — and not the warm-up's either.** The binary
ships `COMPATIBLE_MINOR_FLOOR` (`src/version.ts`), the lowest `minimum` pin that build satisfies, and
`nen shu tools` applies it, prints it as `compat floor:` on every run, and carries it in `--json` as
`compatibleMinorFloor`. Hatsu reads that verdict off the `nen` row and never recomputes it.

**The rule, in the maintainer's words on 2026-09-10: *exact minor is fine, unless there is a breaking
change*.** A nen release whose CHANGELOG `### Breaking / consumer notes` section carries a real bullet
sets the floor to its own minor; one that carries none leaves it where it stands and goes on accepting the
pins already written. So a pin of `0.A` is satisfied by a build `0.B.z` with floor `0.F` when `A ≤ B`,
`A ≥ F`, and `B` is at or below that build's own minor:

| the pin | the build | floor | verdict |
|---|---|---|---|
| `0.7` | `0.7.0` | `0.7` | **ok** — `>=0.7.0 <0.8.0`; a pin's own minor always satisfies it |
| `0.7` | `0.8.0` | `0.7` | **ok** — `>=0.7.0 <0.9.0`. `v0.8.0` declared no breaking notes, so **no repin** |
| `0.6` | `0.7.0` | `0.7` | **below the floor** — no build of the `0.7` line satisfies it; repin `0.6` → `0.7` |
| `0.9` | `0.8.0` | `0.7` | the binary is **older than the pin** — install the pinned ref |
| `1.4` | any | — | `>=1.4.0 <2.0.0`; above major zero the floor is not consulted at all |

**It is fail-closed at both ends.** An older binary never certifies a newer line it cannot know about, and
a pin below the floor is refused by name however new the host's binary is. The widening only ever *adds*
versions, which is why nen's own notes record that shipping it was not itself a breaking change.

**Why the floor is `0.7`, and what would move it again.** At major version zero SemVer 2.0.0 clause 4 makes
the *minor* the breaking-change vehicle, and nen's last three minors are the proof: `v0.5.0` **removed**
something a consumer could rely on (the `schemas/` fallback), the first release since `v0.1.0` to do so;
`v0.6.0` changed three behaviours **in place**; and `v0.7.0` changed four more, none of them announced by a
new flag — `nen stage triage` gained the `local-config` and `large` detectors, so a tree that answered
exit `0` answers exit `1` on the same bytes; every relative own-path flag (`--body-file`, `--out`,
`--input`, `--efforts`, `--original`, `--table`, and `canon mirror`'s five) resolves against `--repo`'s root
instead of the process's directory; a missing or malformed `--target` exits `2` rather than `1` across
sixteen verbs, and so does an unreadable caller-named input on `split verify`, `changelog` and
`canon mirror check`; and `nen pr ready` **reads** `nen/gates.json`'s `dependabot_carve_out`, so an
unchanged file can turn a `not-ready` into a `ready`. That explains the original `0.7` minimum. A minimum also moves when Hatsu adopts a new capability:
`device.extract` requires `0.9`; the explicit `review-round-only` approval policy raises the current
minimum to `0.10`. Breaking changes remain the other reason to raise it.
`pinned_ref` may move on
its own to a newer release inside the range, which is exactly what `v0.7.0` → `v0.8.0` was. The familiar
"compatible within a major" reading applies from **`1.0` onward**, and the contract is bumped to say so
when nen gets there.

**A repin moves the digests with the pin.** `dependency.bootstrap.sha256` moves with `pinned_ref`, in
the same pull request: the three workflows that bootstrap nen compare the linux-x64 binary with `main`'s
copy of that digest, so a digest left behind fails every later pull request closed
([`GATE-CONFIGURATION.md`](GATE-CONFIGURATION.md), the 2026-10-13 nen-digest record).

## What happens when the range is not satisfied

Two cases, two paths, chosen by the probe (`nen --version`) and never by preference:

| Probe result | What the warm-up does |
|---|---|
| **nen absent** | Fetches nen's own published `bootstrap/nen.sh` at the pinned ref and runs it. This is the **sole** chicken-and-egg carve-out for shell anywhere on a Hatsu path: `nen bootstrap` is a `nen` subcommand, so it presupposes the binary that is missing. |
| **nen present, out of range** | Re-pins **through the verb**: `nen bootstrap --ref <pinned> --source zheref/nen --script <fetched script>`. `--script` is required — the verb *runs* the bootstrap rather than reimplementing it, so it needs the script on disk. |

Either way:

- **The bootstrap is checksum-verified.** It fetches nen's published `SHA256SUMS` and refuses bytes that do
  not verify. A checksum failure is **never** retried — retrying one is how a fail-closed guard becomes a
  fail-open one by attrition.
- **The script is fetched to a file and then run — never `curl … | bash`.** It reads `${BASH_SOURCE[0]}`
  under `set -u`, so a pipe kills it before it parses its own arguments.
- **The bootstrap is never vendored here.** Hatsu fetches nen's own script at the pinned ref, every time, so
  there is no second, unreviewed copy to drift from the manifest it verifies against.

## Halt — and what it is not

An absent or out-of-range `nen` is **not** a halt; it is an auto-install. The session halts **only when the
bootstrap itself fails**, and then it prints the exact command for you to run yourself, and stops.

**There is no LLM-improvised fallback for a Nen-owned operation, ever.** If nen is unavailable and the
bootstrap failed, the operation does not happen — not with raw `gh`, not with a shell equivalent, not from
memory. Reporting that is the correct outcome; substituting a hand-rolled equivalent is not.

---


---

## Where `nen` is installed, and how it is bound on your host

The warm-up installs `nen` itself where the host allows it, and from `v0.73.0` also binds the pinned
binary on the host so your own terminal and the agent run the same build. The one surface that needs the
binary placed by hand before a sandboxed run is Codex, for the reason the box below gives.

> **`nen` auto-installs itself on Claude Code and on Cursor — and, from `v0.73.0`, binds itself on the
> host. Put it on the host yourself before a sandboxed Codex run.** The bootstrap resolves and verifies the
> binary into `${XDG_CACHE_HOME:-$HOME/.cache}/nen`
> ([`nen/contract.json`](../nen/contract.json) → `dependency.bootstrap.flags`), which is **outside** the
> directory `codex exec -s workspace-write` makes writable — so a session under that sandbox has nowhere to
> install to. Everywhere else the `SessionStart` hook runs `scripts/nen_global.sh` first — on the source
> copy always, on a mirrored copy once its plugin root is verified: it checks the binary's SHA256 against
> the contract's `dependency.bootstrap.sha256.<platform>` before anything is linked, links
> `~/.local/bin/nen` to the verified pin atomically (never over a file that is not a symlink; a linked
> `nen` newer than the pin that nen accepts is kept, never downgraded) and appends one marked
> `# >>> hatsu nen-global >>>` PATH block to your shell rc and profile (`~/.zshrc`/`~/.zprofile`,
> `~/.bashrc`/`~/.bash_profile`, else `~/.profile`). **That block prepends `~/.local/bin` on purpose**, so
> the pinned `nen` wins over any other on your `PATH` (a Homebrew `nen`, say) — a documented trade-off,
> not an accident; and **a block you removed is never re-added** (a marker under `~/.config/hatsu/`
> remembers). **Opting out**: `HATSU_NEN_GLOBAL=0`, `false`, `no` or `off` in the environment, or a file
> `${XDG_CONFIG_HOME:-$HOME/.config}/hatsu/nen-global` containing `off`; a Windows (win32/MSYS) host is
> skipped too. A skipped run prints `skipped (<reason>)` and `ten` § 2 falls back to its session-only
> bind; a real file at `~/.local/bin/nen` or a refused host write does the same. A Cursor session did run
> the bootstrap itself, checksum-verified, and put the result on its own session `PATH`. **The hook links;
> `ten` § 2c then verifies**: either way the warm-up asks **your own login shell** whether `nen` resolves
> inside the contract's range ([`ten`](../claude/skills/ten/SKILL.md) § 2c) — a build outside it, or no `nen`
> on that shell's `PATH`, reads *installed, not reachable*, an unmet dependency with that reason — and
> the one name-correct link (`~/.local/bin/nen`, row `host-nen-link`) is **offered as the fallback**, by
> `ten` § 2c's predicate, verbatim: offered where the login shell reads installed, not reachable; never where it reads reachable; an opt-out skip is no offer (host: opted out), win32 is not read, and a removed-by-user rc entry withholds the PATH half of option A.
> Option A's halves follow the hook's state: where it bound the host (`current`, `linked`, `kept-newer`)
> A is the one `PATH` line only, never a relink; where it did not (exit `2` unfixed, `3`, `4`, a lock skip)
> A is the link plus the `PATH` line — on exit `3` the statement names the real file and that A replaces
> it, and the star moves to B. Stated first, taken only on your word. A shell the probe cannot run (unset
> or non-POSIX `$SHELL`, win32) reads *not read*.
