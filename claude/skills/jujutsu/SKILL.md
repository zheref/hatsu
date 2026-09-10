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

| State | Meaning |
|---|---|
| `connected` | paired, trusted, reachable **now**. This is the state to register from |
| `available (paired)` | this Mac has paired with it before; it is not attached right now |
| `unavailable` | known, and not usable — an unpaired watch, a device that has been reset |

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
cable. The state to register from is `device`.

**When the probe does not see it, report what the probe *did* see** — the whole list. That is nen's
own refusal discipline for a declared device (`docs/WORKFLOW.md` § 3: *"the refusal lists what the
probe did see, which is the difference between a useful error and a shrug"*), and jujutsu holds itself
to it before there is any declaration to refuse from.

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
`nen shu dev --target` implements from `0.4.0`, and it is the rule the by-hand path holds itself to
today (`--target` refuses at `0.3.0`, verified live: *"--target is not read by 'shu dev'"*).

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
                             "argv": ["devicectl", "list", "devices", "--json-output", "-"] } },
    "after": [
      { "exe": "xcrun", "argv": ["devicectl","device","install","app","--device","{device.id}","{artifact}"] },
      { "exe": "xcrun", "argv": ["devicectl","device","process","launch","--device","{device.id}","<bundle id>"] }
    ]
  }
}
```

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

Verified live (`docs/ab/jujutsu.md` § 2.5): a declaration carrying `project.launch` reports
`ok nen/contract.json project (…)`. **At `v0.3.0` nen preserves the block verbatim and reads it with
nothing** (`docs/WORKFLOW.md` § 3), so the row being `ok` says the file is well-formed — it does **not**
say the target works, and jujutsu never reports it as if it did. What says the target works is § 4's
probe resolving the name, run and shown.

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

One line, then the block. The device as the probe named it, its state, the target key, the `resolve`
argv, whether `launch.default` moved, and the gate the PR stands at. Where the run stopped at § 2 or
§ 4, that instead — with the probe's full output, not a summary of it.

## Residue

1. **`nen shu dev --target <name>` does not exist at `v0.3.0`** — verified live: exit `2`, *"--target
   is not read by 'shu dev'. A flag accepted and ignored is worse than one refused: the ignored thing
   is the instruction you gave"* (`docs/ab/jujutsu.md` § 2.5). So a target this skill registers
   **cannot yet be launched by nen**: [`hatsu:amaterasu`](../amaterasu/SKILL.md) runs the lane's
   declared `dev` and then the `after` steps by hand, and says so. It is P1 (brief § 4.2) and ships at
   `0.4.0` — a pin that has not moved, not a feature to file. **Say this in the PR body**, so a target
   registered today is not read as a target that launches today.
2. **The pairing steps themselves have no verb and never will** — a boundary, not a gap (§ 3). They
   are acts on a device's own screen, by a person, and the security property depends on that.
3. **Waiting for the device has no loop primitive** — `nen watch until` refuses the probes, verified
   live (§ 3). Jujutsu asks and waits.
4. **The first probe is run from the platform's documented command**, before any declaration exists to
   read it from (§ 4). Named every run; from the second run onward it is read from the file.
5. **`nen/workflow.json` is unvalidated at `v0.3.0`** — no row in `nen schema check`
   (`docs/ab/rikugan.md` § 2.4). `launch.default` and `launch.fallback` are read as data.

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
