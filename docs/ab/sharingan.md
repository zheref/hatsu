# A/B evidence — `sharingan` (the `drive` rename, wave 3)

`claude/skills/sharingan/SKILL.md`: drive one open PR to `CON-32` readiness at its human gate and
stop there.

**This is a rename record, not a port record, and the distinction is the whole document.** The skill
was called `drive` from Hatsu `v0.1.0` through `v0.4.0`. At `v0.5.0` it is `sharingan`. **What
changed is the name.** Nothing else moved: not a procedure, not a `nen` invocation, not an
exit-code reaction, not a residue entry, not an authority line, not a hard limit. A reader who knew
`drive` knows `sharingan`, and a reader who does not can read the file front to back without
learning that it used to be called something else.

**The evidence for what the skill does is [`docs/ab/drive.md`](drive.md), under its original name.**
That file is a dated record of runs made on 2026-09-01 against a skill called `drive`; renaming it
would make those transcripts look like they were run against something they were not. It carries a
pointer paragraph at its top saying so. **There is no second A/B pass here** — re-running verbs to
re-prove behaviour a rename did not touch would be ceremony, and it would produce a document that
disagrees with the first one about which run happened when.

Nothing below is redacted; both repositories are public.

---

## 1. The skill

| | Before (`v0.4.0`) | After (`v0.5.0`) |
|---|---|---|
| Directory | `claude/skills/drive/` | `claude/skills/sharingan/` |
| Frontmatter `name:` | `drive` | `sharingan` |
| Invocation | `hatsu:drive <CODE>#<PR> to <G2\|G4>` | `hatsu:sharingan <CODE>#<PR> to <G2\|G4>` |
| Everything else in `SKILL.md` | — | **unchanged** |
| A/B evidence | `docs/ab/drive.md` | `docs/ab/drive.md`, unmoved, plus this file |

**Why the name changed.** Every other skill on this plane is named for a technique — `ren`,
`rasengan`, `kokusen`, `amaterasu`, `rikugan`, `jutaisho`, `izanagi`, `izanami`, `tensho`,
`getsuga`. `drive` was the one English verb in a roster of proper nouns, and an English verb is the
one kind of name that reads as a description: *drive* the PR, *drive* the backlog, "the drive
phase". Three of those readings are in this repository's own prose right now, and two of them are
not this skill. **`sharingan` cannot be misread as a common noun**, which is the entire property a
name is for.

**What the rename touched, outside the skill's own directory.** Every live pointer — a
`../drive/SKILL.md` link, a `hatsu:drive` invocation, a `` `drive` `` naming the skill — now names
`sharingan`, in `claude/skills/{build,tensho,jujisho,futon,senkei,backlog-loop,pr-state,izanami,
izanagi,getsuga}/SKILL.md`. **Historical sentences kept the old name and gained a pointer**: a line
in `docs/ab/tensho.md` recording what was and was not ported *at that run*, a fixture listing in
`docs/ab/plugin-bump-guard.md` naming the path the guard actually saw, the mapping tables in
`docs/ab/build.md` and `docs/ab/backlog-loop.md`. Rewriting those would have been the worse error —
an evidence file that describes a run is only worth keeping if it describes the run that happened.

## 2. Verbs exercised live

**None, and that is the finding.** A rename has no deterministic step for a `nen` verb to own: the
move is `git mv`, and the correctness question is whether every reference still resolves — a
question `git grep` answers and no verb does.

What *was* run, as the mechanical check that the rename left nothing dangling. **The question is not
"does the word `drive` still occur"** — it does, deliberately, in every historical sentence (§ 4.3) —
**it is "does any live pointer still name a path or an invocation that no longer exists".** Two
greps, run from the worktree root:

```
$ git grep -nE 'hatsu:drive|\(\.\./drive/SKILL\.md\)' -- claude/
(no output)
exit=1
```

```
$ git grep -nE '`drive`' -- claude/skills | grep -v 'skills/README.md'
claude/skills/sharingan/SKILL.md:3:description: … This skill was named `drive` until Hatsu v0.4.0 …
claude/skills/sharingan/SKILL.md:8:> **This skill was `drive` until Hatsu `v0.4.0`.** The rename …
claude/skills/sharingan/SKILL.md:10:> line and hard limit below is the one `drive` carried, unedited. …
claude/skills/tensho/SKILL.md:230:[`sharingan`](../sharingan/SKILL.md) prose (that skill was `drive` when this paragraph was written):
exit=0
```

**Four hits, and all four are the history note, not a missed reference.** Three are the renamed
skill's own paragraph explaining what it used to be called; the fourth is `tensho` § 5 saying that
its two-tier path split was copied from that skill's prose *before* the rename, which is a claim
about when the copy happened and would become false if the name were substituted.
`claude/skills/README.md` is excluded from the second grep because it is a shared file, edited by
the subagent assigned to the shared surfaces in this wave rather than by this one (brief § 5).

And the plugin's own validator — the one mechanical check that a skill directory's name and its
frontmatter `name:` agree:

```
$ claude plugin validate . --strict
Validating marketplace manifest: <worktree>/.claude-plugin/marketplace.json

✔ Validation passed
exit=0
```

> **`nen` has no verb for this, and is not expected to grow one.** The closest thing on the roster is
> `nen surface mirror generate|check --source <skills dir>` (brief § 4, P2/P3, wave 4), which writes
> per-surface copies of a skills directory and refuses hand edits on `check`. That verb would notice
> a *stale mirror* after a rename; it would not perform the rename and it would not find a dangling
> `../drive/SKILL.md` in prose. **Cross-file reference integrity in markdown is not a repository
> operation** — it is a property of the prose, which is why the check above is `git grep` and is
> named here as such rather than dressed up as a verb.

## 3. Residue

1. **The rename itself is `git mv` plus a reference sweep, and both are named residue.** There is no
   `nen skill rename`, no `nen surface` verb at `0.3.0` at all (`nen --help` lists no `surface`
   family), and nothing in nen reads a markdown link. The sweep is § 2's `git grep`, run to empty,
   and its own exit `1` is the proof.
2. **Every residue entry `drive` carried is still open, unchanged, under the new name.** They are
   listed in `claude/skills/sharingan/SKILL.md` and evidenced in `docs/ab/drive.md`, and this
   document deliberately does not restate them — a restated residue list is a second copy that
   drifts, which is the failure the rename record exists to avoid rather than commit.
3. **`docs/ab/drive.md` keeps its filename**, so a reader arriving at `sharingan` from the skill
   index reaches its evidence through a pointer rather than by name. That is a real cost of keeping
   the record honest, and the pointer paragraph at both ends is what pays it.

## 4. Findings against the binary

*File nothing from this document; this is the list.*

### 4.1 — A plugin's skill directory name and its frontmatter `name:` must agree, and only the validator says so

`claude plugin validate . --strict` is the only thing in the toolchain that would have caught a
`git mv` with no frontmatter edit. `nen schema check` does not look at `claude/**` at all — verified
live against this worktree, it reports exactly five rows, and every one of them names a file under
`nen/`:

```
$ nen schema check --repo .
repository: <worktree>
  FAIL  nen/labels.json    no such file …
  FAIL  nen/repos.json     no such file …
  FAIL  nen/colors.yml     no such file …
  warn  nen/gates.json     no such file …
  ok    nen/contract.json  dependency (nen >= 0.3, pinned v0.3.0), project (1 lane: plugin; 10 verbs; 1 toolchain entry)
nen: this repository's taxonomy could not be read. Nen has no built-in copy to fall back on -- a
binary that guessed the names would report a taxonomy this repository does not have.
exit=1
```

*(The three `FAIL` rows and the `warn` are Hatsu's own standing state, not this change's: it ships no
label, repo or colour taxonomy of its own and never has — the same five rows `docs/ab/rikugan.md`
§ 2.4 records, at the same exit `1`, and the same reason there is still no `nen/workflow.json` row
at this pin. The `project` clause on the `ok` row is new since that run only because Hatsu's
contract gained its `project` block in wave 1.)*
**Recorded as a boundary, not a gap**:
the skills directory is Claude Code's schema, not nen's, and a nen verb asserting a claim about
another tool's manifest would be the kind of cross-ownership this stack keeps out of nen on purpose.

### 4.2 — The plugin bump guard covers this change and does not care about the name

`scripts/plugin_bump_check.sh` treats anything under `claude/**` as plugin surface
(`docs/ab/plugin-bump-guard.md` § 2), so a rename of a skill directory owes a
`.claude-plugin/plugin.json` bump on the PR that lands on `main` exactly as a content change would.
The guard reads changed *paths*, so a rename shows up as both a deletion and an addition under
`claude/skills/`, and either half alone would have been enough. **No change is needed to the guard**;
noted because the rename is the first change in this repository that moves a covered path rather
than editing one.

### 4.3 — Not a finding: the old name survives on purpose in four documents

`docs/ab/drive.md`, `docs/ab/tensho.md` § 4.7, `docs/ab/plugin-bump-guard.md` § 3's fixtures, and the
mapping tables in `docs/ab/build.md` and `docs/ab/backlog-loop.md` each keep `drive` in a sentence
that describes a past run, with a pointer added rather than a substitution made. **A grep for
`drive` in this repository will therefore never come back empty, and should not.** Recorded so that
a later reader does not read the remaining hits as an incomplete rename and "finish" it.


---

## Retired at nen 0.5 — 2026-09-10

Run against the binary built from `zheref/nen` `v0.5.0` (`204b9ee6`), put on `PATH` as `nen`
(`nen --version` → `0.5.0`). This section records what stopped being residue when
`nen/contract.json`'s `pinned_ref` moved from `v0.4.0` to `v0.5.0`, with the exit code each verb
actually returned.

| Residue retired | Verb at the pin | Exit |
|---|---|---|
| `--policy-paths`' prose about a live `schemas/` fallback | the fallback is **removed**; the list itself is unchanged | — |

The reasoning is recorded once, in `docs/ab/tensho.md` § *Retired at nen 0.5*: `gate derive` takes a
prefix literally and nen's taxonomy resolution never sees it, so an un-migrated target still edits a real
`schemas/*.json` and that edit is still policy. **Dropping the prefix would under-derive a gate.**

Nothing else in this skill's verb surface moved at the pin; the `pr` family gained `edit-body`, which
`shibari` owns.
