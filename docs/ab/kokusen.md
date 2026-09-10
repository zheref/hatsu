# Evidence — `kokusen` (new skill, Hatsu workflow fold-in)

`claude/skills/kokusen/SKILL.md`: the automatic local commit — triage before staging, an ask on every
flagged path, a shape-checked Conventional Commits message, `Akatsuki-Agent: kurapika` and no other
trailer, and no push.

**Not a port.** The nearest existing relative is [`tensho`](../../claude/skills/tensho/SKILL.md),
which stages and commits on the way to a **PR**; kokusen is the same two verbs with the GitHub half
removed and one rule added that tensho does not carry — **no AI attribution trailer at all**. § 2
records the live behaviour of the verbs at nen `0.3.0`, including the one that does *not* enforce that
rule.

> **Dated note, 2026-09-10 — the key changed after this record was made; the record did not.** Every
> transcript below is verbatim and stays that way. The maintainer's ruling of 2026-09-10
> ([`docs/ROSTER.md`](../ROSTER.md) § *Rulings of 2026-09-10*, *Two provenance trailers*) split
> provenance in two: a **local** Hatsu session writes **`Hatsu-Agent: <persona>`**, and
> `Akatsuki-Agent:` is the **autonomous CI plane's** key, which nothing on this plane writes. So read
> every `Akatsuki-Agent=…` below as *what was written on the day*, not as what to write now. What the
> runs establish about the verbs is unaffected: both keys sit on
> `commits.allowedAttributionTrailers`, so the accept/refuse behaviour is identical either way.

**Run:** 2026-09-09/10 (local clock; the session crossed midnight), `nen 0.3.0` at `/Users/zheref/.local/bin/nen`; host `Darwin 25.4.0 arm64`. Hatsu
at `origin/main` `e158349`. Verbs were exercised against a **constructed** throwaway git repository
under this worktree's `.nen-fixture/`, seeded for this section with one path of each hazard shape,
and deleted before the commit. Nothing was committed in the fixture and no primary checkout was
touched.

*Paths sanitized: this machine's absolute paths appear as `<fixture>`. Nothing is redacted — both
repositories are public — and the transcripts are otherwise verbatim.*

---

## 1. The skill

| Step | Mechanism | Owner |
|---|---|---|
| 1 | Read `commits.allowedAttributionTrailers`, `commits.forbiddenTrailers`, `iteration.*`, `branch.base` | the skill, as data (§ 3) |
| 2 | The checks are green **in this turn** | `hatsu:rasengan` (verbs) |
| 3 | Not on the trunk — `nen wc classify --repo --base` | verb |
| 4 | Triage every path — `nen stage triage --repo [--scope] [--mentions]` | verb |
| 5 | The ask on each flagged path; no ask at all for `secret-shape` | the skill (§ 3) |
| 6 | Format the message — `nen commit format --type --subject [--scope] [--body] --trailer` | verb |
| 7 | Check the rendered message against `forbiddenTrailers` | residue — the verb does not (§ 2.3) |
| 8 | Write the commit — `git commit --file` | residue (§ 3) |

**Count.** Eight steps; **five are verbs**, three are named residue — and one of those three (§ 7)
exists only because the verb that will eventually own it does not read a policy file yet.

## 2. Verbs exercised live

### 2.1 — `nen stage triage`, one path of each hazard, then `--scope`/`--mentions`

The fixture was seeded with: `src/app.js` **deleted** (tracked), `.env` (untracked, secret shape),
`.build.log` (untracked, matching a `.gitignore` written the same run), `logo.bin` (untracked,
binary), plus a genuinely modified `nen/contract.json` and the new `.gitignore`.

```
$ nen stage triage --repo <fixture>
clean: 2 file(s)
  nen/contract.json
  .gitignore
flagged: 4 file(s) -- never staged without an explicit yes
  src/app.js  [unmentioned-deletion]
  .env  [secret-shape]
  logo.bin  [binary]
  .build.log  [ignored]
exit=1
```

```
$ nen stage triage --repo <fixture> --scope nen/ \
    --mentions "drops src/app.js and declares project.launch"
clean: 1 file(s)
  nen/contract.json
flagged: 5 file(s) -- never staged without an explicit yes
  src/app.js  [out-of-scope]
  .env  [secret-shape, out-of-scope]
  .gitignore  [out-of-scope]
  logo.bin  [binary, out-of-scope]
  .build.log  [ignored, out-of-scope]
exit=1
```

Three things the second run proves at once, all of them load-bearing for the skill's § 4:

- **`--mentions` cleared the deletion flag.** `src/app.js` is no longer `unmentioned-deletion` — its
  basename appears in the text — and is left flagged only for being outside `--scope`. Passing the
  message you are *about* to write is what makes that detector mean anything.
- **`--scope` flags more, not less.** Every path outside `nen/` gained `out-of-scope`, the honest
  `.gitignore` included. A narrow scope makes the ask longer, which is the correct direction.
- **Rows carry several reasons at once**, as arrays, not as display strings.

Exit `1` on both, as the verb's contract requires whenever anything is flagged: it detects and never
decides.

### 2.2 — `nen commit format`, the message shape

```
$ nen commit format --type feat --scope launch \
    --subject "declare project.launch for the sim target" \
    --body "The declaration now names one launch target; nen 0.3.0 preserves the key and reads it by nothing." \
    --trailer "Akatsuki-Agent=kurapika"
feat(launch): declare project.launch for the sim target

The declaration now names one launch target; nen 0.3.0 preserves the key and reads it by nothing.

Akatsuki-Agent: kurapika
exit=0

$ nen commit format --type feat --subject "add a launch target."
nen: subject ends with punctuation -- Conventional Commits subjects read as a sentence fragment, not
a sentence
exit=2
```

Shape only — a declared type, a non-empty subject under 72 characters, no trailing punctuation. What
changed and why never reaches the verb.

### 2.3 — the trailer rule is **not** enforced by the binary at `0.3.0`

```
$ nen commit format --type feat --subject "add a launch target" \
    --trailer "Akatsuki-Agent=kurapika,Co-Authored-By=Claude <noreply@anthropic.com>"
feat: add a launch target

Akatsuki-Agent: kurapika
Co-Authored-By: Claude <noreply@anthropic.com>
exit=0
```

Rendered, both of them, at exit `0`. And the verb's own usage confirms why it could not have done
otherwise:

```
$ nen commit --help
nen commit format -- Conventional Commits formatting, tensho §4.

usage:
  nen commit format --type feat --subject "a short imperative subject"
                    [--scope <scope>] [--breaking] [--body "paragraph one"]
                    [--trailer key=value,key2=value2]
  ...
  --trailer   comma-separated key=value pairs, e.g. 'Closes=#12'. Trailer KEYS
              are the caller's data, never a literal baked in here -- see
              src/commit/format.ts's header for why.
```

**There is no `--repo` flag on `nen commit format` at this pin**, so the verb cannot locate a
`nen/workflow.json`, let alone read `commits.forbiddenTrailers` out of one. Trailer keys are the
caller's data by design. The refusal is therefore the *skill's*, applied to the rendered text before
it becomes a commit — and both halves of the eventual mechanism (the verb reading the policy under
`--repo`, and a `commit-msg` hook written by `nen scaffold init` that refuses a trailer outside
`allowedAttributionTrailers`) are later waves.

### 2.4 — `nen wc classify`, the trunk refusal kokusen inherits

```
$ nen wc classify --repo <fixture> --base main
case: must-move
  on the trunk ('main') with 1 uncommitted path(s) -- this MUST move to a fresh branch cut from the
  target base; nothing is ever committed to the trunk directly
exit=0
```

kokusen does not move the work itself — that is `hatsu:breath` — but this is the reading that stops it
from committing onto `main`.

### 2.5 — the checks, green in this turn, before the commit

```
$ nen shu build --repo <fixture>
build ok
...
ran:           node -e 'console.log('\''build ok'\'')'  -- exit 0 in 30ms
exit=0
```

Recorded here (and in full in `docs/ab/rasengan.md` § 2.1) because kokusen's precondition is a green
run **in the same turn**, not a remembered one: with no build proof on disk at this pin, a fresh run
is the only proof there is.

## 3. Residue

1. **The forbidden-trailer refusal** (§ 2.3). No `--repo` on `nen commit format`, no policy read, no
   `commit-msg` hook at this pin. The skill compares the rendered message against
   `commits.forbiddenTrailers` and refuses to commit one that carries a forbidden trailer.
2. **Writing the commit.** `nen commit format` formats; nothing in nen commits. `git commit --file
   <message file>` is a named raw call, as is each explicit `git add <path>` — `git add -A` is barred
   by the skill's § 9.
3. **Local-config and "unusually large" detection.** No detector in `nen stage triage`, by the verb's
   own account and re-confirmed by § 2.1's `clean` rows: a path that is neither ignored nor
   out-of-scope reports clean whatever it is. The same residue
   [`tensho`](../../claude/skills/tensho/SKILL.md) § 3 names, inherited unchanged.
4. **The ask on every flagged path** stays the skill's — the verb's own `--help` says the yes is never
   its to give — and **`secret-shape` is not askable at all**.
5. **Reading `nen/workflow.json`** — no loader, no schema row (`docs/ab/breath.md` § 2.6).
6. **Whether a turn is one commit or two** stays judgment.

## 4. Findings against the binary

1. **`nen commit format` will render any trailer it is handed, including one a repository's own policy
   forbids** (§ 2.3) — and cannot do better, because it takes no `--repo` and therefore has no policy
   file to read. This is the single largest residue in the skill and the one with the worst failure
   mode: the guard is a habit until the verb and the hook arrive, and a habit is exactly what an
   attribution trailer slips past. Recorded as the reason the skill states the rule twice (§ 5 and
   § 9) rather than once.
2. **`--scope` broadens the flag set rather than narrowing the ask** (§ 2.1). Correct behaviour —
   out-of-scope is a hazard, not a filter — but the flag reads like a filter, and a caller who passes
   `--scope` expecting a shorter list gets a longer one. Worth one line in the verb's `--help`;
   recorded, not filed.
3. **A `secret-shape` path is reported in the same list, with the same exit code, as an ignored log
   file** (§ 2.1). The distinction that matters — one of these five flags has no yes — lives entirely
   in the caller. A severity field, or a distinct exit code for `secret-shape`, would let a guard
   enforce what today only prose does.
4. **No missing verb otherwise.** Triage and message shape are both verbs, exercised live; the commit
   itself is git's, which is not a gap nen has ever claimed.


---

## Retired at nen 0.5 — 2026-09-10

Run against the binary built from `zheref/nen` `v0.5.0` (`204b9ee6`), put on `PATH` as `nen`
(`nen --version` → `0.5.0`). This section records what stopped being residue when
`nen/contract.json`'s `pinned_ref` moved from `v0.4.0` to `v0.5.0`, with the exit code each verb
actually returned.

| Residue retired | Verb at the pin | Exit |
|---|---|---|
| no build proof to trust before a commit | `nen commit check --repo <fixture> --require-proof app` | `0` |
| the forbidden-trailer refusal | `nen commit format --repo . --trailer "Co-Authored-By=someone"` | `2` |
| `nen/workflow.json` unvalidated | `nen schema check --repo .` → `ok nen/workflow.json` | that row `ok` |

The proof transcripts are in `docs/ab/rasengan.md` § *Retired at nen 0.5*; the trailer transcripts in
`docs/ab/aka.md` § *Retired at nen 0.5*. Two readings this skill depends on:

- **`commit check` reports and blocks nothing.** No commit is refused and no file is written, so the
  refusal stays kokusen's. What the verb removes is the *guessing*: exit `1` distinguishes no proof, a
  different lane, and a tree that has moved (printing both hashes).
- **`--repo` is what turns the trailer refusal on.** The policy is opened only when the invocation
  carries a `--trailer`; without `--repo` there is no policy to open and nothing is refused, which is
  why layer (a) — reading the rendered message before committing — is still worth doing.

**Against a lane whose `build` is a declared seat** — hatsu's own `plugin` lane — `commit check` is exit
`1` forever, because no proof is ever written. That is a fact to state, not a failure to fix.
