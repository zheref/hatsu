# A/B evidence — `jujutsu` (new skill, wave 3)

`claude/skills/jujutsu/SKILL.md`: device pairing — walk the maintainer through the on-device steps,
verify with the platform's own probe, and register the device as a named `project.launch` target through
a declaration PR at **G4**. Runs once per device; simulators and the Mac desktop take the same path.

**A new skill, so there is no "old mechanics" column.** What this record establishes is that the two
probes work and say more than "present or absent" — Android's `unauthorized` and iOS's four-way State
column are the states this skill exists to read — that the device's own **name carries non-ASCII bytes**
that a match-by-name resolver will refuse over, and that a target registered today **cannot yet be
launched by nen**, because `--target` is not read by `shu dev` at the pinned `0.3.0`.

Run: 2026-09-10 (local clock). `nen 0.3.0` at `/Users/zheref/.local/bin/nen`, host `darwin` (arm64), with
a real iPhone and a real Android phone attached to this machine. **Every device command below is
read-only**: `xcrun devicectl list devices`, `xcrun simctl list devices available` and `adb devices` list
and report; **nothing was installed, launched, paired, unpaired, trusted or authorised by this run**, and
no prompt on any device was touched. `nen schema check` and `nen shu dev --target` ran against a
**constructed throwaway fixture** at `<worktree>/.nen-fixture`, created for this run and deleted before
the branch was committed.

Nothing below is redacted; both repositories are public. The device names and identifiers printed here
are the maintainer's own, on their own machine, in a repository they own.

---

## 1. The skill

| Step | Owned by | State at `v0.3.0` |
|---|---|---|
| The invocation | `nen parse jujutsu --grammar "pair <device>"` | **verb** (§ 2.1) |
| The on-device pairing steps | — | **boundary, never a verb** (§ 4.4) |
| Waiting for the device to appear | `nen watch until` | **refused by design** (§ 2.4) |
| The iOS probe | the declaration's own `device.resolve` argv | **by hand on the first run** (§ 2.2) |
| The Android probe | same | **by hand on the first run** (§ 2.3) |
| The declaration survives the loader | `nen schema check` | **verb** (§ 2.5) |
| Launching the registered target | `nen shu dev --target <name>` | **absent** → residue (§ 2.5, § 4.1) |
| Opening the declaration PR | [`aka`](../../claude/skills/aka/SKILL.md) → [`mukai`](../../claude/skills/mukai/SKILL.md) | **composed** |

**Eight rows; two are verbs, one is residue, two are boundaries.** The high boundary count is the point
of the skill rather than a shortfall — see § 4.4.

---

## 2. Verbs and probes exercised live

### 2.1 — `nen parse jujutsu`: `<device>` is required

```
$ nen parse jujutsu --grammar "pair <device>" --line "pair Sergio’s iPhone Pro"
device: Sergio’s iPhone Pro
exit=0
```

```
$ nen parse jujutsu --grammar "pair <device>" --line "pair"
nen parse: <device> is required and the line does not supply it.

Corrected line:
  jujutsu pair <device>
exit=2
```

**An unbracketed slot is required, and the refusal says so plainly.** This is the opposite shape from
`murasaki`/`gyo`/`hanten`'s optional clauses (`docs/ab/murasaki.md` § 2.1), and it is deliberate: a
pairing run with no named device would have to guess which attached thing was meant, and § 2.2 shows the
probe returning **38 devices** on this machine. The same reasoning `nen shu deploy`'s `--target` states
for itself — *"required, with no default ever, not even when there is exactly one"*.

Note the slot parsed the multi-word value including its apostrophe without quoting trouble; the parse's
echo is also the first place the maintainer can see whether the name they typed is the name the probe
prints (§ 2.2, § 4.2).

### 2.2 — `xcrun devicectl list devices`: four states, two realities, 38 rows

```
$ xcrun devicectl list devices
exit=0
Name                          Hostname   Identifier                             State                Model                                     Reality
---------------------------   --------   ------------------------------------   ------------------   ---------------------------------------   ---------
Apple Watch Ultra 3 (49mm)               5AD75D64-99CC-49D3-9464-75D444AAAEF1   shutdown             Apple Watch Ultra 3 (49mm) (Watch7,12)    simulated
Edwin’s iPhone                           A28E1282-75CD-5D1C-AC3D-0423ADAE929D   available (paired)   iPhone 16 (iPhone17,3)                    physical
Kro-CoverageAgent-ad288af4               C38D74A4-BD44-4FF9-B9FB-6C6E2D60FB24   connected            iPhone 17 Pro (iPhone18,1)                simulated
Kro-Details-Redesign                     5C6BA381-63F6-4B3F-95A0-93E610228384   connected            iPhone 17 Pro (iPhone18,1)                simulated
Sergio’s Apple Watch Black               26C3D600-7685-54CB-A36B-1C78A2B09258   unavailable          Apple Watch Ultra 2 (Watch7,5)            physical
Sergio’s iPhone Pro                      E4E6AC2C-5CA5-5A18-B762-0FA1DED4B4E0   connected            iPhone 17 Pro Max (iPhone18,2)            physical
iPad Pro 13-inch (M4)                    EEF72415-EB3A-4495-A1F1-EBFFC51EC964   shutdown             iPad Pro 13-inch (M4) (iPad16,6)          simulated
… (38 rows in total)
```

**Four state values appear in one listing** — `connected`, `available (paired)`, `unavailable`,
`shutdown` — and only `connected` means *usable right now*. `available (paired)` is the state of a
device this Mac has trusted before and which is not attached; a skill that read "present in the list" as
"ready" would register the wrong one of the two iPhones here.

**Simulators and physical devices share the table**, separated only by the **Reality** column. So
`devicectl` seeing a name is not evidence that a physical device is attached — which is why the skill's
§ 7 has a simulator declare `device.kind: "simulator"` explicitly rather than inferring it.

The machine-readable form carries the same facts as structured data:

```
$ xcrun devicectl list devices --json-output <path>
exit=0
# device count: 38
# 'Sergio’s iPhone Pro'  udid E4E6AC2C-5CA5-5A18-B762-0FA1DED4B4E0  tunnelState connected  platform iOS  pairingState paired
# 'Edwin’s iPhone'       udid A28E1282-75CD-5D1C-AC3D-0423ADAE929D  tunnelState disconnected  platform iOS  pairingState paired
```

**And the name is not ASCII:**

```
$ grep -o 'Sergio.\{1,3\}s iPhone Pro' <the probe's json> | head -1 | od -c
0000000    S   e   r   g   i   o 342 200 231   s       i   P   h   o   n
0000020    e       P   r   o  \n
```

`342 200 231` is **U+2019 RIGHT SINGLE QUOTATION MARK**, three bytes in UTF-8 — not the ASCII `'`
(U+0027, `047`) a keyboard produces. This is § 4.2.

**The simulator probe**, for the § 7 path:

```
$ xcrun simctl list devices available
== Devices ==
-- iOS 17.5 --
    iPhone 15 Pro (0E0EADC5-8121-411D-9D21-861DD1478DBB) (Shutdown)
    iPhone 15 (7D031B2B-B011-4341-B02A-50360D3E7FF7) (Shutdown)
    iPad Pro 11-inch (M4) (1E728045-0AC3-4310-A28B-4D5B996E179C) (Shutdown)
    …
```

### 2.3 — `adb devices`: `unauthorized` is the case, and it is not "no device"

```
$ adb devices
List of devices attached
R52X603Q9BA	unauthorized

exit=0
```

**This is the exact state jujutsu exists to walk somebody out of, captured live.** The phone is
attached, `adb` can see it, and it has **not** accepted the *Allow USB debugging?* prompt carrying this
host's RSA key fingerprint. The serial is known; nothing else is.

Three readings a skill could take, and only one is right:

- *"no device found"* — **wrong**, and it sends the maintainer to check the cable.
- *"device found, proceeding"* — **wrong**, and every subsequent `adb` command fails obscurely.
- *"attached, not authorised: accept the RSA prompt on the phone"* — the fix is on the device, and it is
  three seconds of the maintainer's time once the sentence names it.

Note also that `adb devices` **exits `0`** on this state. The exit code is about the *listing*, not
about any device in it, so the state column is the only thing that answers the question.

### 2.4 — `nen watch until` will not poll for a device, and refuses the whole run

```
$ nen parse izanami "adb devices until the device shows as device"
until: the device shows as device
  [unknown] adb devices
nen: at least one command does not classify as read-only -- the WHOLE run is refused. Use
'nen parse izanagi <task> until <condition> up to <N>' for a loop that must act.
exit=1
```

```
$ nen parse izanami "xcrun devicectl list devices until the iPhone appears"
until: the iPhone appears
  [unknown] xcrun devicectl list devices
nen: at least one command does not classify as read-only -- the WHOLE run is refused. …
exit=1
```

**Both probes classify `[unknown]`, not `[mutating]`** — izanami's table admits what it can certify, and
it has never heard of `xcrun` or `adb`. The refusal is *fail-closed and correct*: a watcher that ran an
unknown command because its name looked harmless would be certifying read-only-ness it never checked.

The consequence for the skill is § 3's: **the waiting is the maintainer's**, and jujutsu probes once
after being told. `docs/ab/ren.md` § 2.2 records the same primitive refusing for a different reason —
that `nen watch until` spawns exactly one program with no shell — and the two together are why nothing
in this plane polls.

### 2.5 — The declaration survives the loader; `--target` does not reach `shu dev`

Against a fixture whose `nen/contract.json` carries a `project.launch` block:

```
$ nen schema check --repo <fixture>
  …
  ok    nen/contract.json  project (2 lanes: app, shell; 5 verbs; 0 toolchain entries)
```

**`ok` with `launch` present** — the loader preserves Hatsu-authored keys verbatim and validates the
block it knows (`docs/WORKFLOW.md` § 3). The fixture's four taxonomy rows fail because a throwaway
fixture ships no taxonomy files; that is unrelated to `launch`, and the full transcript is
`docs/ab/kotoamatsukami.md` § 2.5.

**And the target cannot be launched:**

```
$ nen shu dev --repo <fixture> --target iphone --dry-run
nen shu: --target is not read by 'shu dev'. A flag accepted and ignored is worse than one refused: the
ignored thing is the instruction you gave.
Run 'nen shu --help'.
exit=2
```

`nen shu --help` confirms `--target` is `'deploy' only`. See § 4.1.

---

## 3. Residue

1. **`nen shu dev --target <name>`** (§ 2.5, exit `2`). A registered target is not launchable by nen at
   this pin; [`amaterasu`](../../claude/skills/amaterasu/SKILL.md) runs the declared `dev` and the
   `after` steps by hand and says so. P1 (brief § 4.2), ships at `0.4.0`.
2. **The on-device pairing steps** — a boundary (§ 4.4), performed by the maintainer.
3. **Waiting for the device** — no loop primitive will take it (§ 2.4). Jujutsu asks and waits.
4. **The first probe** — run from the platform's documented command, before there is a
   `device.resolve` to read it from (§ 2.2, § 2.3). Named every run; read from the file thereafter.
5. **`nen/workflow.json` read as data** — no schema row at `v0.3.0` (`docs/ab/rikugan.md` § 2.4).
   `launch.default` and `launch.fallback` are read directly.

---

## 4. Findings against the binary

*File nothing from this document; this is the list.*

### 4.1 — A target registered today cannot be launched today, and the PR must say so

§ 2.5. `--target` is `'deploy' only`; `nen shu dev --target <name>` is exit `2`. So the whole point of
jujutsu's output — a named target `hatsu:amaterasu` can launch — **does not execute at the pinned
`0.3.0`**. The block is written, preserved verbatim by the loader, validated as well-formed, and read by
nothing.

**This is a pin that has not moved, not a defect**: brief § 4.2 specifies the executing half —
`nen shu dev|run --target <name>` resolving the declared device via its `resolve` probe, matching
`device.name`, refusing by name when absent while listing what the probe saw, then running the lane's
verb with `args` appended and the `after` steps with `{device.id}`/`{artifact}` substituted. It lands at
`0.4.0`.

**What matters is the disclosure.** A declaration PR that reads *"registers the iPhone as a launch
target"* and lands into a repository where nothing launches it is a PR whose title is false for one
release cycle. The skill's § 6 puts it in the body; recorded here so the requirement has a citation.

**And the refusal itself is exemplary** — *"A flag accepted and ignored is worse than one refused: the
ignored thing is the instruction you gave."* An ignored `--target` would have launched the *default*
device while the caller believed it had named one, which on a machine with 38 devices attached (§ 2.2)
is a genuinely bad afternoon. Worth keeping that sentence when the flag starts being read.

### 4.2 — Device names carry non-ASCII bytes, and a match-by-name resolver has to say what "match" means

§ 2.2's `od` transcript: `Sergio’s iPhone Pro` uses **U+2019**, not `'`. Apple's default keyboard
substitutes the curly apostrophe when a device is named, so **this is the common case, not the exotic
one** — two of the physical devices on this machine have it.

Three ways it bites, in ascending order of subtlety:

1. **The typed form does not match.** A declaration written from memory with `'` never resolves, and
   nen refuses by name — correctly, and baffingly if the reason is unknown. The skill's answer is § 5:
   copy the bytes, never retype.
2. **The rendered form does not match either.** The same name prints as `Sergio?s iPhone Pro` in a
   terminal that cannot show the codepoint (§ 2.2's first transcript is exactly that). Copying *that*
   produces a third string that matches nothing.
3. **Unicode normalisation is an open question for the resolver.** `U+2019` is a single codepoint and is
   normalisation-stable, but a name like `José's iPad` is **not**: NFC gives `é` as one codepoint and NFD
   as `e` + combining acute, the two are byte-different and visually identical, and macOS surfaces both
   forms in different contexts. **A byte-exact matcher will refuse a name a human copied correctly.**

**So `nen shu dev --target`'s matching rule is a contract question to answer explicitly when it lands
(brief § 4.2), not to discover afterwards.** Candidate answer: compare after Unicode **NFC**
normalisation on both sides, and have the refusal print the probe's names *and* say that the comparison
was normalised — so a mismatch that survives normalisation is visibly a different device rather than a
different encoding. Whatever is chosen, `USAGE.md` should state it, because "match `device.name` in the
probe's output" reads as unambiguous and is not.

Ranked: this is the finding most likely to produce a support question, and the cheapest to settle before
the code exists.

### 4.3 — `adb devices` exits `0` on `unauthorized`, so the state column is the only answer

§ 2.3. The listing succeeded; the device is unusable. Any caller that reads the exit code — a
precondition, a CI step, a `nen` `resolve` probe that only checks the probe ran — concludes the device is
fine.

`project.launch.<target>.device.resolve` is declared as an argv whose **output** is matched on
`device.name`, which is the right design and sidesteps this: nen will look for the name and refuse when
it is not there. **But `R52X603Q9BA` is a serial, not a name** — `adb devices` prints no device name at
all, and `adb -s <serial> shell getprop ro.product.model` is a *second* command. So an Android
`device.resolve` probe either matches on a serial (a fact about one cable, exactly what § 6 of the skill
forbids writing into a shared declaration) or runs a two-step probe the `resolve` block's `{exe, argv}`
shape does not obviously express.

**Recorded as an open question for the `0.4.0` resolver**, alongside § 4.2: iOS's `devicectl` returns
names and identifiers in one JSON document, and Android's `adb` does not. A `resolve` shape that works
for one may need a `steps:[…]` form — which `project.verbs` already has — for the other. Nothing here is
broken today; nothing here is declared today either, and KroAndroid's `project.launch` block will be the
first to find out.

### 4.4 — Not a finding: the pairing itself has no verb, and must not

Trusting a computer, enabling Developer Mode, accepting an RSA fingerprint — these are **security
decisions taken on a device's own screen by the person holding it**, and their entire value is that a
human looked. An agent that could perform them would have removed the property they exist to provide.

So half of this skill is a numbered list for a person, and that is the correct shape rather than an
automation gap. Recorded in the same class as `kotoamatsukami`'s *"look at the golden"*
(`docs/ab/kotoamatsukami.md` § 4.3) and `hanten`'s *"raising a delegate"* (`docs/ab/hanten.md` § 4.4):
three places in this wave where the honest answer is a boundary, and where writing a verb would make the
system worse.

What the skill owes in exchange is precision about the boundary — which prompt, on which screen, in which
menu, and what the next probe will print when it has worked — so that the human's half is three minutes
rather than a search. § 3 of the skill is that list.


---

## Retired at nen 0.5 — 2026-09-10

Run against the binary built from `zheref/nen` `v0.5.0` (`204b9ee6`), put on `PATH` as `nen`
(`nen --version` → `0.5.0`). This section records what stopped being residue when
`nen/contract.json`'s `pinned_ref` moved from `v0.4.0` to `v0.5.0`, with the exit code each verb
actually returned.

| Residue retired | Verb at the pin | Exit |
|---|---|---|
| a registered target cannot be launched by nen | `nen shu dev --repo <fixture> --target sim --dry-run` | `0` |
| `nen/workflow.json` unvalidated | `nen schema check --repo <fixture>` → `ok nen/workflow.json` | that row `ok` |

The full launch transcript is in `docs/ab/amaterasu.md` § *Retired at nen 0.5*. What matters here is what
a jujutsu PR may now promise: **a target it registers is launched by nen**, and the declaration may carry
two more keys — `lane` (a device build is routinely a different declared row from the iteration one) and
`artifact` (the thing the device installs, which is rarely the verb's first artifact).

**One thing that was accepted through `v0.4.0` and is now refused**, worth stating in a jujutsu PR body:
`{device.id}` or `{artifact}` written into `project.launch.<name>.args` is exit `2` naming the token.
Substitution reaches the target's `after` steps and nowhere else, so a token in `args` was never
unfillable — it reached the child process as itself.

The exact-bytes rule for `device.name` (§ 5) is now nen's own documented behaviour: `docs/USAGE.md`'s
`nen shu dev` section states from this release that the match is a string comparison with **no Unicode
normalisation**, so a name macOS writes with U+2019 must be declared with that character.
