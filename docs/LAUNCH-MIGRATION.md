# Shared launch resolution and consumer migration

Hatsu #48 owns the workflow contract. Nen #204 owns record extraction in the existing
`nen shu dev/run --target` machinery. Hatsu #49 owns capture and reconciliation of new gaps.
The consumer owns its concrete build, installation and launch commands. These are linked
changes, not three copies of the same implementation.

## Availability and release boundary

[Nen v0.9.0](https://github.com/zheref/nen/releases/tag/v0.9.0) publishes the implementation of
[Nen #204](https://github.com/zheref/nen/issues/204) from [PR #206](https://github.com/zheref/nen/pull/206),
released at the merge of [PR #208](https://github.com/zheref/nen/pull/208). Its three binaries and
SHA256SUMS are published. Hatsu initially adopted extraction with `minimum: "0.9"` and
`pinned_ref: "v0.9.0"`; Nen 0.8.0 does not execute `device.extract`. Hatsu's current dependency is
declared in `nen/contract.json` and is Nen 0.10 for the explicit reviewer policy. Nen 0.9 kept compatibility floor 0.7 for
consumers that retain older declarations, which is separate from the feature minimum.
Verify the installed binary accepts the extraction declaration before changing a consumer.
Retain KroApple's normalizer until its declaration migration and successful physical build,
install and launch; publishing the shared replacement is not consumer-device proof.
Hatsu #49 was addressed by Hatsu PR #50 before the next Hatsu release. This migration guide does
not itself authorize a tag or release.

## Record ownership

A probe describes devices; the extraction declaration identifies the device record boundary and
maps its name, canonical identifier and readiness value. Repeated descriptive names within one
record remain one device. Two distinct records with the same selected name remain ambiguous.
Selection stays exact, and readiness is never inferred from presence. Malformed output is a
refusal, not an empty successful inventory. Nen spawns only commands in the consumer declaration.

| Platform | Declaration responsibility | Shared resolver responsibility |
|---|---|---|
| Apple | Declare devicectl JSON probe, physical-platform lane, install and launch after-steps | Read one record per `result.devices` entry; select the logical identifier and supported readiness paths without counting nested aliases as devices |
| Android | Declare an appropriate text/JSON probe and native build/install/launch commands | Extract the declared record fields, preserve exact selection and reject missing/unusable readiness; only declared header/line handling applies |
| Expo | Select the iOS or Android native lane and its platform probe and artifact | Use the corresponding Apple/Android extraction; no Expo-only resolver or implicit tool command |

The exact schema and runnable examples are maintained with Nen's implementation in `docs/USAGE.md`
and `docs/STACK-MATRIX.md`. Check those against the installed release; do not copy an unreleased
key into an older consumer and hope it is ignored. Existing targets without extraction preserve
their documented behavior until migrated.

## KroApple sequence

KroApple commit `718d3766` records the temporary `ci_scripts/nen_apple_devices.py` normalizer and
`ci_scripts/test_nen_apple_devices.py`. The normalized probe plus the physical build lane reportedly
completed build/install/launch; that issue evidence is not a device run by this Hatsu change.

1. Retain the working normalizer and its focused test while the shared replacement is unreleased.
2. After the compatible release is published, update the consumer's pin as required by its
   compatibility verdict and use a probe/extraction declaration supported by that binary.
3. Inspect the target-specific lane: the build platform is physical iOS, the installed artifact is
   that build's app, and both install and launch after-steps are declared.
4. Through Nen, prove synthetic record tests and the applicable checkpoint checks. Run the full
   regression in aka and extraction-only coverage in mukai; do not turn migration into a hidden
   early full-suite or coverage run.
5. From the maintainer's core checkout, read the target's declared `verb` and run
   `nen shu <declared-dev-or-run-verb> --repo <core-checkout> --target iphone`.
   Record build, installation and launch results separately. A dry run is not delivery. Preserve
   the temporary fallback until the replacement is verified; remove the two Python files and the
   probe-only test row as part of the verified consumer migration. If device proof is unavailable,
   report the migration pending and retain the fallback.
6. Regenerate Hatsu surface mirrors with `nen surface mirror generate` from canonical source.
   Refresh consumer skills through Hatsu's supported surface bootstrap/warm-up installation;
   regenerate inherited rules through that consumer's declared Nen canon synchronization workflow.
   Never hand-edit `.agents/skills/` or `.claude/rules/` generated copies.

The consumer's testing/coverage declarations must also separate instrumented regression collection
from extraction. Bankai's testing, completion and screenshot source rules remain an upstream owner
change preserving UZF-19/UZF-26; consumer generated rules cannot repair their own source.

## Reviewable outcomes

| Case | Required outcome |
|---|---|
| One record repeats its name and carries two identifier aliases | One selected record and its declared canonical identifier |
| Two records carry the same exact name | Refuse before build or installation |
| Device is present but unauthorized/offline | Report unusable; never apply absent-device fallback |
| Device is absent | Use only configured fallback, or report disconnected with no launch |
| Output is malformed or readiness is missing | Refuse honestly; no successful empty inventory or implicit ready state |
| Device target builds a simulator artifact | Declaration defect; no successful physical-device delivery claim |
| Build succeeds but install/launch fails | Report the failed step and incomplete delivery |
| No app target exists (Hatsu/Nen tooling) | Explicit no-launch skip |

These are acceptance scenarios. Synthetic execution belongs to Nen #204's tests; actual device
execution belongs to the consumer migration. This document does not claim either ran merely
because a row describes its expected outcome.

---

## Launch declaration rules

Moved here on 2026-09-20 (zheref/hatsu#89) from `hatsu:jujutsu` §§ 4 and 6 and `hatsu:amaterasu` §§ 2
and 4, which carried them twice over; both skills now point here. `jujutsu` **writes** these
declarations and `amaterasu` **executes** them.

### The block, and what nen owns

`project.launch.<target>` carries `verb` (`dev` or `run` — a **closed set**, refused at load
otherwise, and nen does **not** carry a target across the two), `args`, `device`
(`name`, `kind` — `simulator` marks one, and an absent `kind` is read as physical — `resolve`
`{exe, argv}`, `extract`, `readyWhen`), `after[]`, and the optional `lane` and `artifact`.
**`nen shu dev|run --target <name>` executes the whole block** — the probe, the lane's verb with
`args` appended, then the after-steps with `{device.id}` and `{artifact}` substituted — and **nen
parses the block rather than preserving it**, so a key one spelling out (`arg`, `devices`, `resolver`,
`verbs`, or the block key itself as `launches`/`Launch`) is refused **by pointer**. A green
`nen schema check` therefore proves the block **parses**, and never that the target works.

### The canonical block

Moved here with the rules (2026-09-20) from `jujutsu` § 6, which is now one line pointing at it. An
iOS physical target, complete:

```json
"launch": {
  "iphone": {
    "verb": "dev",
    "device": { "name": "<the probe's exact bytes>",
                "resolve": { "exe": "xcrun",
                             "argv": ["devicectl", "list", "devices", "--json-output", "-"] },
                "extract": {
                  "format": "json",
                  "records": "result.devices",
                  "name": ["properties.state.name", "deviceProperties.name"],
                  "identifier": ["identifier", "hardwareProperties.udid"],
                  "readiness": ["properties.connection.state", "connectionProperties.tunnelState"]
                },
                "readyWhen": { "in": ["connected"] } },
    "after": [
      { "exe": "xcrun", "argv": ["devicectl","device","install","app","--device","{device.id}","{artifact}"] },
      { "exe": "xcrun", "argv": ["devicectl","device","process","launch","--device","{device.id}","<bundle id>"] }
    ]
  }
}
```

A **simulator** declares `device.kind: "simulator"` with the platform's simulator list as its probe
(`xcrun simctl list devices available`). The **Mac desktop** declares **no `device` at all**, reaching
the app through `args` and an after-step: `"mac": { "verb": "dev", "args": ["-scheme", "<scheme>"],
"after": [ { "exe": "open", "argv": ["{artifact}"] } ] }`.

### `readyWhen` — the state column, written into the declaration every time

**A device that is PRESENT is not a device that is READY.** A target registered without `readyWhen`
resolves an `unauthorized` row at exit `0`, prints it as *resolved*, and then fails one `adb -s` at a
time afterwards; **absent means unchanged, so the key protects nobody until it is written.**

With `device.extract`, **`extract.readiness` owns the ordered readiness paths and `readyWhen` owns
only the accepted values in `in`**; **never add a legacy `readyWhen.path` or `.field` beside
`extract`**, which the schema refuses as mixed ownership. For a legacy declaration without `extract`,
which shape applies is decided by what the probe **prints**:

| The probe prints | The shape | Written for the probes below |
|---|---|---|
| **lines** (`adb devices -l`) | `{ "field": <n>, "in": [ … ] }` — `field` counts whitespace-separated tokens on the device's own row, the row's first token being field 1 | `{ "field": 2, "in": ["device"] }` |
| **JSON** (`xcrun devicectl list devices --json-output -`) | `{ "path": "<dotted key>", "in": [ … ] }` — read off the object whose `name` matched, or an enclosing object up to **two** levels out | `{ "path": "connectionProperties.tunnelState", "in": ["connected"] }` |

**Four validations, all at load and all by pointer**: exactly one of `field`/`path`, never both and
never neither; `in` non-empty with every entry a non-empty string; `field` a whole number **≥ 1**, so
a zero-indexed rule is refused rather than reading one column to the left for a year; and **a rule on
a device with no `resolve` probe is refused outright**, nothing being spawned there for it to read.

- **States are compared as whole strings, verbatim** — a JSON `true` or `3` at the named path compares
  as `"true"` and `"3"`, so a boolean readiness flag needs no second shape.
- **A state is read only where the rows carrying the name agree about it**: one device described twice
  is one device, two rows naming two states is two answers, and nen reports neither.
- **`--dry-run` prints it as a `readiness:` line** under the device, with nothing connected, because it
  is the declaration's rule rather than a reading; `--json`'s `target.device` gains `readyWhen`.

### The probe's states, and the third outcome

| Probe | Register / launch from | **Present, not usable** | Absent |
|---|---|---|---|
| `xcrun devicectl list devices` (**State** column) | `connected` — the only one | `available (paired)`, `unavailable` | the name is not in the table |
| `adb devices -l` (**second** column) | `device` — the only one | `unauthorized`, `offline`, `no permissions`, `recovery`, `sideload`, `bootloader` | not listed |

**Present-but-unusable is a THIRD outcome and it is not "absent".** `unauthorized` means the phone is
attached and has not accepted the RSA prompt; saying *"no device found"* sends the maintainer to look
at the cable while the phone waits for a tap. **Refuse, name the state, quote the probe's whole
output, and name the on-device step that closes it** — `unauthorized` → the RSA prompt, `offline` →
replug or `adb kill-server`, `no permissions` → this host's USB rules. **Never fall back to the
simulator for it**: the fallback answers "nobody plugged it in", and this device is one tap from
working. Where the target declares `readyWhen`, **nen has already refused at exit `5`** naming the
device, the state seen and the states accepted — relay that verbatim; where it declares none, read the
state column by hand and **report the missing `readyWhen` as a declaration defect**.

**`device.name` is matched byte for byte** — exact string equality, no case folding, no Unicode
normalisation, no punctuation smoothing — so a name carrying **U+2019** (`Sergio’s iPhone`) declared
with the ASCII `'` is a *different name*, and a plugged-in device is reported absent. **Copy the bytes
out of the probe's own output**, never retype them, and say in the PR body where a name carries
anything non-ASCII. **Never match loosely**: a probe listing three devices none of which is the
declared one is an **absent** device, not "close enough".

### The verb builds; the after-steps install and launch

> **An `after` step is the ONLY place `{device.id}` reaches, so whatever must land on the named device
> belongs there — never in the verb.**

nen substitutes `{device.id}` and `{artifact}` in the target's `after` steps and nowhere else, and a
`{device.id}` or `{artifact}` written into `args` is **exit `2` naming the token**. A declaration that
ignores this resolves one phone and installs to another, with nothing in the transcript flagging it,
because from nen's side nothing went wrong.

| platform | `verb` (builds) | `after[]` (reaches the named device) |
|---|---|---|
| **Android** | `./gradlew assembleDebug`, with `artifacts` naming the APK | `adb -s {device.id} install -r {artifact}` → `adb -s {device.id} shell am start -n <pkg>/<activity>` |
| **iOS** | `xcodebuild … build`, with `artifacts` naming the `.app` | `xcrun devicectl device install app --device {device.id} {artifact}` → `xcrun devicectl device process launch --device {device.id} <bundle id>` |

**`installDebug`, `run`, `flutter run -d`, `xcodebuild … test` and every other verb that reaches a
device itself belong in neither column** — they are a build and an install welded together, and the
weld is where the device name gets lost. **The Apple caveat is a `lane`/`artifact` override, never
`args`**: `xcodebuild` refuses a second `-scheme`, so declare a second row and point
`project.launch.<name>.lane` at it, naming what the device installs with `.artifact`.

**Which path `{artifact}` reads is a fact the dry run states**: `project.launch.<name>.artifact` where
declared, otherwise the verb's own **first** `artifacts` entry. The override is refused outside the
tree, refused as an empty string, and refused when **no after-step names `{artifact}`**. And
**`{artifact}` is substituted as the after-step's own directory sees it** — declared paths are stated
against the repository root while an after-step is spawned with its cwd set to
`project.lanes.<lane>.cwd` — so the `substitutes:` line says both strings when they differ while
`artifacts:` keeps reporting the repository-relative one. The two answer different questions: what
does this build produce, and what will the child receive.

### Other rules these two skills share

- **The key is a short, human name** (`iphone`, `sim`, `mac`, `pixel`), because it is what the
  maintainer types at `hatsu:amaterasu` — not the device's name and not its identifier.
- **Never write a literal device identifier into the declaration**: a UDID is a fact about one
  machine's cable, and a declaration is shared. `{device.id}` resolves at run time.
- **Every toolchain name lives in the target repository's own file, never in nen.**
- **Selecting the target is a separate key**: `nen/workflow.json` → `launch.default` /
  `launch.fallback` name `project.launch` keys, so **registering a target does not make it the
  default**, and changing the default is the maintainer's decision, stated in the PR either way.
- **A simulator declares `device.kind: "simulator"`** with the platform's simulator list as its probe;
  `devicectl` lists simulators too, under **Reality: simulated**, so a name resolving there is no
  evidence that a *physical* device is attached. **The Mac desktop declares no `device` at all** and
  reaches the app through `args` and an after-step.
