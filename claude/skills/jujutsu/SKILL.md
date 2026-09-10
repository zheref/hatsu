---
name: jujutsu
description: Pair a new device with this machine and register it as a named launch target, once, for good — walk the maintainer through the on-device steps, verify with the platform's own probe, then write the target into nen/contract.json and open the declaration PR at G4. Use when the maintainer invokes hatsu:jujutsu pair <device>, asks to set up a new phone, tablet, simulator or desktop target, or when hatsu:amaterasu reports a launch target this machine cannot resolve. It never taps a trust prompt, never changes a security setting and never merges the declaration PR; simulators and the Mac desktop register through the same path.
---

# Jujutsu — the device, bound to the declaration

**Nature: Transmuter.** The output is a `project.launch` block in `nen/contract.json` — machinery —
and machinery lands at **G4** (`claude/agents/kurapika.md` § *The six work-modes*).

> **Get this device paired, prove it with the probe, and write it into the declaration through a pull
> request — once, so nobody has to do it again.**

Jujutsu runs **once per device**, not once per session and not once per effort. What it produces is a
named target [`hatsu:amaterasu`](../amaterasu/SKILL.md) can launch from then on, and a device that has
been through it never needs to be described in prose again.

**Half of this skill is not something an agent does.** Trusting a computer, enabling Developer Mode,
accepting an RSA fingerprint — those are acts on the device's own screen, by the person holding it,
and they are the security boundary that makes a paired device mean anything. **Jujutsu walks the
maintainer through them and performs none of them** (§ 3). What it does itself is read-only probing,
one JSON block, and a pull request.

---

## 1. Invocation

```
hatsu:jujutsu pair <device>
```

```bash
nen parse jujutsu --grammar "pair <device>" --line "<the invocation, minus the hatsu:jujutsu prefix>"
```

Verified live at `v0.3.0` (`docs/ab/jujutsu.md` § 2.1): `pair Sergio's iPhone Pro` →
`device: Sergio's iPhone Pro`, exit `0`; a bare `pair` refuses at exit `2` — *"`<device>` is required
and the line does not supply it"* — with the corrected line printed.

**`<device>` is required, and it is not defaulted.** A pairing run with no named device would have to
guess which of the things plugged into this machine the maintainer meant, and a device registered
under the wrong name is a launch target that resolves to somebody else's phone. The slot is
**required rather than optional** for exactly the reason `nen shu deploy`'s `--target` is: *"required,
with no default ever — not even when there is exactly one."*

**The name typed here is provisional.** The name that goes into the declaration is the one the
**probe** prints, byte for byte (§ 5) — the invocation names which device the maintainer means; the
probe says what it is called.

## 2. Once per device — check before pairing anything

```bash
# is it already a target?
nen/contract.json → project.launch   # read the keys and each one's device.name
```

| State | What jujutsu does |
|---|---|
| the device is already a `project.launch` key **and** the probe resolves it | **Say so and stop.** Nothing to pair. Name the target key so the maintainer can use it |
| it is a key and the probe does **not** resolve it | **Not a pairing problem — a connection problem.** Report what the probe *did* see (§ 4) and stop. Re-registering an existing target would paper over a cable |
| it is a key and the probe sees it **present but not usable** (`unauthorized`, `offline`) | **Not a pairing problem either — an on-device step.** § 4's third outcome: name the state, quote the probe, say which of § 3's steps closes it, stop |
| it is not a key | § 3 |

**Pairing a device twice is not idempotent in a useful way**: it produces a second `project.launch`
key for the same hardware, and then two targets resolve to one phone and neither name means anything.
Check first, every run.

## 3. The pairing walk-through — the maintainer's hands, not this skill's

**Every step in this section is performed by the maintainer.** Present them as a numbered list, one
platform's list, and then **wait**. Say what the next probe will show when it has worked.

### iOS / iPadOS

1. **Connect** the device to this Mac by cable. (Wi-Fi pairing comes after the first cable pairing,
   never before it.)
2. **Unlock** the device and tap **Trust This Computer** on the prompt, then enter the passcode.
   The prompt appears on the *device*, not on the Mac.
3. **Enable Developer Mode**: Settings → **Privacy & Security** → **Developer Mode** → on. The device
   **restarts**, and after the restart it asks again — confirm it there too.
4. Say when all three are done.

### Android

1. **Enable Developer options**: Settings → About phone → tap **Build number** seven times.
2. **Enable USB debugging**: Settings → System → Developer options → **USB debugging**.
3. **Connect** by cable, then accept the **Allow USB debugging?** prompt on the device — the one
   showing this computer's **RSA key fingerprint**. Tick *Always allow from this computer* if the
   maintainer wants it to survive replugging.
4. **Optionally, wireless debugging** — and only after step 3 has worked over the cable: Developer
   options → **Wireless debugging** → **Pair device with pairing code**, then on this machine
   `adb pair <host>:<port>` with the six-digit code the phone shows, then
   `adb connect <host>:<debug-port>`. The pairing port and the connect port are different numbers;
   the phone shows both.
5. Say when it is done.

> **Jujutsu never performs any of the above, and this is a rule rather than a limitation.** A trust
> prompt, an RSA fingerprint confirmation and a Developer Mode toggle are **security settings on a
> device**, and their whole purpose is that a human looked at them. An agent that could tap them
> would have removed the thing they exist to provide. **This skill never enters a passcode, never
> accepts a trust or debugging prompt, never toggles a security setting, and never asks the
> maintainer to disable one** — if a step seems to require turning something off, that is a finding
> to report, not an instruction to relay.

> **And the waiting is not a loop.** `nen watch until` cannot poll for the device: verified live at
> this pin (`docs/ab/jujutsu.md` § 2.4), `nen parse izanami "adb devices until the device shows as
> device"` classifies `adb devices` as **`[unknown]`** and refuses the whole run at exit `1`, and
> `xcrun devicectl list devices` gets the identical answer. Izanami's table admits only what it can
> certify read-only, and it will not certify a command it does not know. So jujutsu **asks, and
> waits for the maintainer's word**, then probes once. Re-probing on a timer would be a loop nen
> declined to authorise.

## 4. Verify with the probe — and read the state, not just the presence

**iOS:**

```bash
xcrun devicectl list devices
xcrun devicectl list devices --json-output <path>     # the machine-readable form
```

Verified live (`docs/ab/jujutsu.md` § 2.2). The table's **State** column is the answer, and its values
are not interchangeable:

| State | Meaning | Register from it? |
|---|---|---|
| `connected` | paired, trusted, reachable **now** | **yes.** This is the only state to register from |
| `available (paired)` | this Mac has paired with it before; it is not attached right now | no — **present, not usable** (below) |
| `unavailable` | known, and not usable — an unpaired watch, a device that has been reset | no — **present, not usable** (below) |
| the name is not in the table at all | absent | no — report the whole list (below) |

The **Reality** column separates `physical` from `simulated`, and both appear in the same table.

**Android:**

```bash
adb devices
```

Verified live (`docs/ab/jujutsu.md` § 2.3), and the transcript is the case this skill exists for:

```
List of devices attached
R52X603Q9BA	unauthorized
```

**`unauthorized` is not "no device".** It means the phone is attached and has **not** accepted the RSA
prompt — § 3 step 3 has not been done, or was done for a different host key. The fix is on the phone,
not on this machine, and saying *"no device found"* here would send the maintainer to look at the
cable. The state to register from is `device`. `adb devices -l` prints the state in the **second
column**, and it is the column that decides:

| Second column | Meaning | Register from it? |
|---|---|---|
| `device` | attached, authorised, answering | **yes.** The only one |
| `unauthorized` | attached; the RSA prompt was never accepted, or was accepted for a different host key | no — **present, not usable** |
| `offline` | attached; the daemon has it in a state where it takes no commands (mid-reboot, a stale transport) | no — **present, not usable** |
| `no permissions` | attached; this host's udev/usb rules will not let `adb` open it | no — **present, not usable** |
| `recovery` / `sideload` / `bootloader` | attached, in a mode that runs no app | no — **present, not usable** |

### Present, but not in a usable state — the third outcome, and it is not "absent"

**Two states of the world are easy to name and a third is the one that actually bites:** the device
is there and usable; the device is not there; and **the device is there and cannot be talked to**.
The third is the one this skill exists to report properly, and at the pinned nen `0.6.0` it is the
one the declaration this skill writes now **says out loud** (§ 6's `readyWhen`).

> **A device that is PRESENT is not a device that is READY, and at `0.6.0` nen holds that rule
> itself — where the declaration states it.** Observed live on 2026-09-10 against
> `zheref/KroAndroid`, at the then-pinned `0.5.0`: with two phones attached, `nen shu dev --target
> galaxy` matched the declared name in a row reading `R52X603Q9BA unauthorized usb:33-3.2`, printed
> `device: R52X603Q9BA  id usb:33-3.2` as *resolved*, and every `adb -s usb:33-3.2 …` after it
> answered `adb: device unauthorized` at exit `1`. That row's state is now declarable:
> `project.launch.<name>.device.readyWhen` names which of the probe's own states count, and a row
> that is present and not one of them is **exit `5` naming the device, the state seen and the states
> accepted**, listing what the probe offered — answered *before* the missing-id refusal, because a
> device whose state is the reason it is unusable routinely prints a row with no id on it.
> **`readyWhen` is absent-means-unchanged**, so it protects nobody until it is written, and writing
> it is § 6's job.

**At pairing time there is no declaration yet, so reading the state is THIS SKILL'S — and that is
the chicken-and-egg of § 4 rather than a gap in nen.** `readyWhen` is what jujutsu is about to write;
it cannot refuse for a target that does not exist. On a device whose row is present and not usable:

- **Refuse to register it**, in those words — *"`<name>` is attached and `unauthorized`; the probe
  saw: `<the whole list>`"* — naming the state and quoting the probe's full output.
- **Say which of § 3's steps closes it**, because every one of these states has a remedy on the
  device or on this host and none of them has one in the declaration: `unauthorized` → § 3 step 3,
  the RSA prompt; `offline` → replug, or `adb kill-server` on this host; `no permissions` → this
  host's USB rules.
- **Never register the name anyway "so the declaration is ready".** A target written from a row that
  cannot be talked to is a target that resolves at run time, reports itself resolved, and then fails
  in an `after` step — which is exactly the shape the run above produced, and it cost a whole build
  cycle to read.
- **Never fall through to the "absent" branch.** *"No device found"* sends the maintainer to look at
  the cable; the cable is fine and the phone is waiting for a tap.

**When the probe does not see it at all, report what the probe *did* see** — the whole list. That is
nen's own refusal discipline for a declared device (`docs/WORKFLOW.md` § 3: *"the refusal lists what
the probe did see, which is the difference between a useful error and a shrug"*), and jujutsu holds
itself to it before there is any declaration to refuse from.

> **The first probe is run from the platform's documented command, and that is named as such.** The
> chicken-and-egg is the point of this skill: `project.launch.<target>.device.resolve` is *what
> jujutsu is about to write*, so it cannot be read before it exists. **The argv typed here is the
> argv that goes into the declaration** — that is what makes it verifiable afterwards. From the
> second run onward the probe is read from the file, never retyped.

## 5. The name is **bytes**, and it is copied, never retyped

**`device.name` is matched byte for byte** — exact string equality against what the probe printed,
with no normalisation, no case folding, no Unicode equivalence and no punctuation smoothing — so a
device name carrying a typographic apostrophe (U+2019, as in `Sergio’s iPhone`) must be declared with
that same character and not with the ASCII `'` a keyboard produces. That is the contract
`nen shu dev --target` implements at the pinned `0.6.0`, and nen's own `docs/USAGE.md` states it in
that release's `nen shu dev` section: the comparison has no Unicode normalisation, so the declared
string must carry the same bytes the probe printed.

**Take `device.name` from the probe's own output.** Verified live (`docs/ab/jujutsu.md` § 2.2): the
device this machine sees is

```
Sergio’s iPhone Pro
```

whose apostrophe is **U+2019 RIGHT SINGLE QUOTATION MARK** — `342 200 231` octal, three bytes — and
not the ASCII `'` (U+0027) that a keyboard produces. A declaration written with the typed apostrophe
does not match, and nen **refuses by name** rather than falling back to the only device attached,
which is correct and would be baffling if the reason were not known.

Terminals compound it: the same name renders as `Sergio?s iPhone Pro` in a table that cannot show the
codepoint. **Neither the rendered form nor the typed form is the name.** Copy the bytes out of the
probe's JSON output, and where a name carries anything non-ASCII, **say so in the pull request body**
so the next reader does not "fix" it.

## 6. Register it — one `project.launch` key, then a PR at **G4**

```json
"launch": {
  "iphone": {
    "verb": "dev",
    "device": { "name": "<the probe's exact bytes>",
                "resolve": { "exe": "xcrun",
                             "argv": ["devicectl", "list", "devices", "--json-output", "-"] },
                "readyWhen": { "path": "connectionProperties.tunnelState", "in": ["connected"] } },
    "after": [
      { "exe": "xcrun", "argv": ["devicectl","device","install","app","--device","{device.id}","{artifact}"] },
      { "exe": "xcrun", "argv": ["devicectl","device","process","launch","--device","{device.id}","<bundle id>"] }
    ]
  }
}
```

### `readyWhen` — write the state column into the declaration, every time

> **The state § 4 read by eye is a state the file can carry, and a state the file carries is one nen
> refuses on. Declare it.** A target registered without it resolves an `unauthorized` row at exit `0`
> and fails one `adb -s` at a time afterwards — which is the run § 4's box records, and it is
> avoidable in one key.

Two shapes, and which one a probe takes is decided by what the probe **prints**, not by the platform:

| The probe prints | The shape | Written for the probes above |
|---|---|---|
| **lines** (`adb devices -l`) | `{ "field": <n>, "in": [ … ] }` — `field` counts whitespace-separated tokens **on the device's own row, the row's first token being field 1**, the way a reader counts columns on their screen | `"readyWhen": { "field": 2, "in": ["device"] }` — the serial is field 1, the state is field 2, and `device` is the only state § 4's table registers from |
| **JSON** (`xcrun devicectl list devices --json-output -`) | `{ "path": "<dotted key>", "in": [ … ] }` — read off the object whose `name` matched, or off an enclosing object up to **two** levels out, which is the same walk the id already makes | `"readyWhen": { "path": "connectionProperties.tunnelState", "in": ["connected"] }` |

- **Exactly one of `field` / `path`, never both and never neither**, `in` non-empty with every entry
  a non-empty string, and `field` a whole number **≥ 1** — all four checked **at load, by pointer**,
  so a zero-indexed rule is refused at `nen schema check` rather than reading one column to the left
  on every launch for a year.
- **A rule on a device with no `resolve` probe is refused too** — nothing is spawned there, so the
  rule could never be read. That is the same discipline `project.launch.<name>.artifact` gets when no
  after-step names `{artifact}`.
- **States are compared as whole strings, verbatim** — `device.name`'s rule, applied to the state
  column. A JSON `true` or `3` at the named path compares as `"true"` and `"3"`, so a boolean
  readiness flag needs no second shape.
- **A state is read only where the rows carrying the name agree about it.** One device described
  twice is one device; two rows naming two states is two answers, and nen reports neither — exactly
  as it picks neither of two competing ids.
- **`--dry-run` prints it as a `readiness:` line under the device**, with nothing connected, because
  it is the declaration's rule rather than a reading. `--json`'s `target.device` gains `readyWhen`,
  `null` on every device that declares none.
- **Absent means unchanged, in every particular** — which is why a jujutsu run that omits it has
  quietly shipped the `0.5.0` behaviour into a `0.6.0` declaration. Say in the PR body which states
  the rule admits and which the probe offered.
- **The `path` form is confirmed against the probe's own JSON on the run that first writes it.** The
  `field` form is exercised live in `docs/ab/jujutsu.md` § *Retired at nen 0.6*; the iOS `path` above
  is read off nen's documented two-level walk and devicectl's own nesting (`name` under
  `deviceProperties`, the state in the sibling `connectionProperties`) and **has not been run against
  a physical device**. Read the probe's JSON, paste the object into the PR body, and say which key
  you took.

### The rule that decides where each step goes, and it is one sentence

> **An `after` step is the ONLY place `{device.id}` reaches, so whatever must land on the named
> device belongs there — never in the verb.**

**The verb BUILDS. The `after` steps INSTALL and LAUNCH.** That is not an iOS idiom that Android
happens to copy; it is the thing that makes `--target` mean anything at all. nen substitutes
`{device.id}` and `{artifact}` in the target's `after` steps and nowhere else, and it says so by
name: a `{device.id}` written into `args` is exit `2` — *"nen substitutes `{device.id}` and
`{artifact}` in the target's 'after' steps only … Move the step that needs the value into 'after'"*.

**What a declaration that ignores it does, observed live on 2026-09-10 against `zheref/KroAndroid`:**
the target's verb was `./gradlew installDebug` — an install, inside the verb, with no way to name a
device. With two phones attached, nen resolved and reported one (`usb:33-3.2`) and Gradle installed
to the **other** (`R5CY213GAST`). Nothing in the transcript flagged the divergence, because from
nen's side nothing went wrong: it resolved the name it was given and ran the row it was given. The
device the declaration named and the device that got the app were simply two different phones.

| platform | `verb` (builds) | `after[]` (reaches the named device) |
|---|---|---|
| **Android** | `./gradlew assembleDebug`, with `artifacts` naming the APK | `adb -s {device.id} install -r {artifact}` → `adb -s {device.id} shell am start -n <pkg>/<activity>` |
| **iOS** | `xcodebuild … build`, with `artifacts` naming the `.app` | `xcrun devicectl device install app --device {device.id} {artifact}` → `xcrun devicectl device process launch --device {device.id} <bundle id>` |

**`installDebug`, `run`, `flutter run -d`, `xcodebuild … test` and every other verb that reaches a
device itself belong in neither column** — they are a build and an install welded together, and the
weld is where the device name gets lost. Split them: the lane's row builds, the `after` steps carry
`{device.id}`.

> **The Apple caveat, and it is a `lane`/`artifact` override rather than `args`.** A second scheme is
> the obvious thing to reach for and `args` is the obvious place to put it — **and `xcodebuild`
> refuses a second `-scheme`**, which AnteikuTV proved: a row already carrying `-scheme X` plus
> `args: ["-scheme","Y"]` is two `-scheme` flags on one command line, and the tool errors rather than
> letting the later one win. At the pinned nen `0.6.0` the answer is the per-target keys:
> `project.launch.<name>.lane` names the declared row this target's verb, `args` and after-steps are
> read from — a device build is routinely a different declared row from the iteration one — and
> `project.launch.<name>.artifact` names the thing the device installs, which is rarely the verb's
> first artifact. **Declare a second row and point the target at it; never append a second `-scheme`
> through `args`.**

`docs/WORKFLOW.md` § 3 is the authority on the block's shape. What jujutsu adds is the discipline for
filling it:

- **The key is a short, human name** — `iphone`, `sim`, `mac`, `pixel` — because it is what the
  maintainer will type at `hatsu:amaterasu`. It is not the device's name and not its identifier.
- **`{device.id}` and `{artifact}` are the only placeholders**, substituted from the `resolve` probe's
  output matched on `device.name`, and from the first entry of the verb's `artifacts`. **Never write a
  literal device identifier into the file** — a UDID is a fact about one machine's cable, and a
  declaration is shared.
- **Every toolchain name lives here, in the target repository's own file, and never in nen.** `xcrun`,
  `adb`, `open` — nen carries no build system and knows no tool's name, and its `purity.test.ts`
  enforces it.
- **Selecting the target is a separate key**: `nen/workflow.json` → `launch.default` / `launch.fallback`
  name `project.launch` keys. Registering a target does **not** make it the default; changing the
  default is the maintainer's decision and is stated in the PR either way.

**Prove the file before opening anything:**

```bash
nen schema check --repo <path>
```

Verified live (`docs/ab/jujutsu.md` § *Retired at nen 0.5*): a declaration carrying `project.launch`
reports `ok nen/contract.json project (…)`. **At the pinned `v0.6.0` nen PARSES the block rather than
preserving it** (`docs/WORKFLOW.md` § 3), so the row being `ok` now says more than it used to: a key
one spelling out — `arg`, `devices`, `resolver`, `verbs`, or the block key itself as `launches` or
`Launch` — is refused **by pointer** naming which misspelling it is, instead of being kept and read by
nobody. It still does **not** say the target works, and jujutsu never reports it as if it did. What
says the target works is § 4's probe resolving the name, run and shown — and, once the block is on
`main`, `nen shu dev --repo <path> --target <name> --dry-run`, which renders the whole plan without
spawning a thing.

**Then the pull request, at G4.** [`hatsu:aka`](../aka/SKILL.md) publishes the branch on the
maintainer's call and [`hatsu:mukai`](../mukai/SKILL.md) opens the PR; jujutsu writes the block, states
the gate, and **never merges**. The body says: which device, which target key, what the probe printed,
whether `launch.default` changed, and — where the name carries a non-ASCII byte — that it was copied
rather than typed (§ 5).

## 7. Simulators and the Mac desktop register the same way

There is nothing to pair for either, and that is exactly why they go through this skill instead of
being typed into the file in passing: **the registration is the same act, and one path means one set
of rules.**

**A simulator** declares `device.kind: "simulator"`, and its probe is the platform's simulator list:

```bash
xcrun simctl list devices available
```

Verified live (`docs/ab/jujutsu.md` § 2.2). Note that `xcrun devicectl list devices` shows simulators
too, under **Reality: simulated** — so a name that resolves there is not evidence that a *physical*
device is attached, and a target whose `device.kind` is absent is read as physical.

**The Mac desktop** declares **no `device` at all** — there is nothing to resolve — and reaches the app
through `args` and an `after` step:

```json
"mac": { "verb": "dev", "args": ["-scheme", "<scheme>"], "after": [ { "exe": "open", "argv": ["{artifact}"] } ] }
```

Both still get § 6's schema check and § 6's G4 PR. **Skipping the PR because "there was no pairing" is
how a declaration acquires an entry nobody reviewed.**

## 8. Report

One line, then the block. The device as the probe named it, **its state, quoted from the probe's own
column**, the target key, the `resolve` argv, whether `launch.default` moved, and the gate the PR
stands at. Where the run stopped at § 2 or § 4 — absent, or present and not usable — that instead,
with the probe's full output, not a summary of it, and the on-device step that closes it.

## Residue

1. **RETIRED at nen `0.5`: `nen shu dev --target <name>`.** Verified live at `v0.5.0`, exit `0`: the
   dry run prints `target: sim  (appends no argument)  -- on lane 'app', which this target declares`,
   the device row, both `would run:` lines and one `substitutes:` line
   (`docs/ab/jujutsu.md` § *Retired at nen 0.5*). **A target this skill registers is launched by nen**
   — [`hatsu:amaterasu`](../amaterasu/SKILL.md) § 5 runs one `--target` invocation and nothing by
   hand. **Say that in the PR body**, and say two more things the pin makes true: a target may declare
   its own `lane` (a device build is routinely a different declared row from the iteration one) and
   its own `artifact` (the thing the device installs, which is rarely the verb's first artifact), and
   `{device.id}`/`{artifact}` written into `args` is now exit `2` naming the token.
2. **The pairing steps themselves have no verb and never will** — a boundary, not a gap (§ 3). They
   are acts on a device's own screen, by a person, and the security property depends on that.
3. **Waiting for the device has no loop primitive** — `nen watch until` refuses the probes, verified
   live (§ 3). Jujutsu asks and waits.
4. **The first probe is run from the platform's documented command**, before any declaration exists to
   read it from (§ 4). Named every run; from the second run onward it is read from the file.
4b. **RETIRED at nen `0.6`: reading the device's STATE at LAUNCH time.**
   `project.launch.<name>.device.readyWhen` — `{field, in}` for a probe that prints lines,
   `{path, in}` for one that prints JSON — says which of the probe's own states count, and a row that
   is present and not one of them is exit `5` naming the device, the state seen and the states
   accepted (`docs/ab/jujutsu.md` § *Retired at nen 0.6*). **What this skill now does is WRITE that
   rule** (§ 6), not read the column on somebody else's behalf. Two things stay this skill's and
   neither is the retired one: the rule is **absent-means-unchanged**, so a declaration without it is
   a target with no readiness check at all — jujutsu writes one every time; and at **pairing** time
   the target does not exist yet, so § 4's first read of the state column is still by eye. That is
   the chicken-and-egg of § 4, the same shape as entry 4, and it is a read rather than a residue.
5. **RETIRED at nen `0.5`: `nen/workflow.json` is validated.** `nen schema check --repo <path>` carries
   an `ok  nen/workflow.json` row at the pinned `v0.6.0`, so a `launch.default` naming nothing is caught
   by a verb. The two keys are still read here; reading a file is not residue.

## Authority

- **Permitted:** run read-only device probes; read `nen/contract.json` and `nen/workflow.json`; write a
  `project.launch` block and, on the maintainer's word, a `launch.default` / `launch.fallback`; run
  `nen schema check`; commit that change on a branch.
- **Not permitted:** performing any on-device step (§ 3); entering a passcode or any credential;
  accepting a trust, pairing or debugging prompt; changing any security setting on any device or on
  this machine; installing anything; writing a device identifier into the declaration; merging the PR.
- **Carries no delegation**, and being reached from [`hatsu:amaterasu`](../amaterasu/SKILL.md)'s
  failure path does not lend it one.

## Hard limits

- **Never taps, confirms or bypasses a trust, pairing, Developer-Mode or USB-debugging prompt**, and
  never asks the maintainer to disable a security setting (§ 3).
- **Never enters a passcode, PIN, password or any credential**, anywhere, for any reason.
- **Never registers a device it has not seen the probe resolve** (§ 4). A block written from a name the
  maintainer typed is a target that will refuse the first time it is used.
- **Never registers a device whose probe row is present but not in a usable state** — `unauthorized`,
  `offline`, `no permissions`, `available (paired)`, `unavailable` (§ 4). At pairing time there is no
  target for nen to refuse on, so the state is read here and the refusal names it.
- **Never registers a device without a `readyWhen` rule** (§ 6). Absent, the key changes nothing at
  all: nen takes the row that carries the name and reports the device resolved, which is precisely
  the failure § 4's box records. A target with no readiness rule is a target this skill has not
  finished writing.
- **Never reports a present-but-unusable device as absent** (§ 4) — the two have different remedies,
  and "no device found" sends the maintainer to the cable while the phone waits for a tap.
- **Never writes an install or a launch into the target's verb** (§ 6). `{device.id}` reaches an
  `after` step and nothing else, so a verb that installs installs wherever it likes — observed live,
  onto a different phone than the one nen resolved.
- **Never appends a second `-scheme` through `args`** (§ 6) — `xcodebuild` refuses two, and the
  declared answer is a `lane` (or `artifact`) override on the target.
- **Never retypes a device name** — the bytes are copied from the probe (§ 5).
- **Never writes a UDID, serial or hardware identifier into the declaration** — `{device.id}` resolves
  at run time (§ 6).
- **Never reports `nen schema check`'s `ok` as evidence that the target works** (§ 6) — at this pin the
  block is preserved and read by nothing.
- **Never registers a second target for a device that already has one** (§ 2).
- **Never changes `launch.default` without saying so**, and never silently.
- **Never merges the declaration PR** — it is machinery, it stands at **G4**, and G4 is the
  maintainer's (`CON-7`).
- **Never polls for the device on a timer** (§ 3) — nen declined to authorise the loop, and this skill
  does not route around it.
- **Never presents a by-hand probe as a verb's output** — § Residue is named where it runs.
