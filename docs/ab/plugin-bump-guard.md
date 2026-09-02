# Evidence — the plugin-bump guard (zheref/hatsu#3)

Port of `<reference-repo>`'s `scripts/plugin_bump_check.sh` into Hatsu as
[`scripts/plugin_bump_check.sh`](../../scripts/plugin_bump_check.sh), wired as the
[`plugin-bump-check`](../../.github/workflows/plugin-bump-check.yml) PR workflow.

This file is not a skill A/B — it is the **guard's own acceptance evidence**: the recorded proof that it
**refuses** a plugin-surface change carrying no version bump and **passes** the same change once the bump is
added. Every transcript below was produced by running the committed script; nothing is reconstructed.

**Run:** 2026-09-02T04:00Z (UTC), branch `p2/3-v0.1` at `b7615fbaec1305889c1ce5242fc2fe809ddf9c8d` plus the
adversarial-review fixes in this commit, base `main` at `992427c714d8fcd6ee26981bea0c9a7627fae656`. GNU bash
5.2.37 (`x86_64-pc-msys`), `jq` 1.8.2. No network, no `gh`, no GitHub: the four inputs the CLI takes are
plain files, which is the whole point of the comparison logic living in the script rather than in YAML.

*Paths sanitized: this machine's local absolute paths appear as `<tmp>` (a throwaway fixture directory).
Private repository names, and the product codes that identified them, are redacted to placeholders (see [`docs/PUBLIC-REDACTION.md`](../PUBLIC-REDACTION.md)); nothing else below is altered — the transcripts are otherwise verbatim.*

> ### Corrections recorded at `v0.1.0` — read these first
>
> An adversarial review of this PR found **two false claims in the version of this document that shipped
> with the guard**, and one omission. They are corrected in place below, and named here so the correction
> is not something a reader has to notice:
>
> 1. **§ 5's "after the merge that branch is never taken again" was false**, and § 2's "trusted-script
>    posture: **unchanged**" was false with it. The workflow gated the trusted copy on `[ -x
>    .trusted/scripts/plugin_bump_check.sh ]` while `scripts/plugin_bump_check.sh` was committed `100644`.
>    An `-x` test on a non-executable file is false *forever*, so the bootstrap fallback would have been
>    taken on **every** PR, not just the bootstrap one — meaning every PR would have been judged by **its
>    own copy of the guard**. That is precisely the hole the workflow header calls fatal. **Fixed two
>    ways**: the file is now committed `100755` (`git update-index --chmod=+x`), *and* the workflow's test
>    is now `-f`, which is the honest predicate because the invocation is `bash "$guard"` — it needs the
>    file to exist and be readable, not to be executable. A new workflow step also asserts the exec bit
>    in-tree (§ 5.1).
> 2. **The surface globs were missing `docs/delegation-grammar-DRAFT.md`** — excluded as "a draft, cited by
>    link, never executed", which was the wrong criterion. `claude/agents/gon.md` mandates reading it at run
>    time. It is covered now, along with forward-proofing globs for `hooks/**` and `.mcp.json` (§ 2).
> 3. **Enforcement was overstated by omission.** The guard is **advisory** until the maintainer requires
>    the check; see § 6.

---

## 1. What the guard protects

Claude Code keys its plugin cache on `.claude-plugin/plugin.json`'s **`version`** field. Change a
plugin-shipped surface without changing that field and the change is real in the repository and invisible on
every machine that already has the plugin installed. There is no error, no warning, and nothing in the PR
that says so.

The inherited incident record, kept in the script's header: the guard is `<reference-repo>`'s **RR-IS-#557 item
5**, filed after **RR-PR-#546** changed four plugin-shipped surfaces — an agent definition, a skill, a
script, and the registry read at warm-up — without bumping the version. The fix never reached an installed
plugin until **RR-PR-#578** bumped it retroactively.

It moves to Hatsu because guards live beside the surface they guard, and this is now that surface.

## 2. What changed in the port

| | `<reference-repo>` `v0.11.3` | Hatsu |
|---|---|---|
| **Comparison logic** | `path_is_plugin_surface`, `any_path_is_plugin_surface`, `plugin_version`, `version_bumped`, `pr_body_has_opt_out`, then a 4-argument CLI | **unchanged**, function for function |
| **Surface globs** | `claude/*`, `scripts/ichigo_prompt.sh`, `scripts/ichigo_board.sh`, `scripts/ichigo_pix.txt`, `scripts/gate_stop.sh`, `scripts/attention_signal.sh`, `schemas/repos.json`, `.claude-plugin/*` | `.claude-plugin/*`, `claude/*`, `nen.contract.json`, `contracts/*`, `docs/ROSTER.md`, `docs/delegation-grammar-DRAFT.md`, `hooks/*`, `.mcp.json` |
| **Opt-out** | `no plugin bump: <reason>` in the PR body | **unchanged** |
| **Workflow** | reusable `workflow_call` with a self-hosted-runner probe and a GitHub App token | a plain `pull_request` job on `ubuntu-latest` — Hatsu has no runner fleet and no App |
| **Trusted-script posture** | guard checked out from `main`, never run from the PR | **intended to be unchanged, and was BROKEN on first submission — now fixed.** See the correction box above and § 5. The posture only became real once the script was committed `100755` and the workflow's gate became `-f` |
| **Exec-bit assertion** | `tests/workflow_script_exec_bit.bats` | **no bats harness in Hatsu** — the equivalent assertion is a workflow step reading `git ls-files -s` (§ 5.1). Stated as a real difference, not a parity claim |
| **Credential posture** | `persist-credentials: false` on both checkouts; diff and base manifest over the API | **unchanged** |
| **Enforcement** | required by `<reference-repo>`'s own branch protection | **advisory** in Hatsu until the maintainer requires the check (§ 6) |

### Why *these* globs

Derived from what `.claude-plugin/plugin.json` declares, plus the files an installed copy reads **at run
time** — staleness in either is the same failure.

| Glob | Why it is covered |
|---|---|
| `.claude-plugin/*` | the manifests themselves. |
| `claude/*` | everything `plugin.json` points at: `agents` (kurapika, gon, hisoka, phinks, uvogin), `commands` (`/kurapika`), `skills` (the 17 ports + `hatsu-warmup`). |
| `nen.contract.json` | read at run time as `$CLAUDE_PLUGIN_ROOT/nen.contract.json` by `hatsu-warmup` and by the agent definitions. It carries the **pinned nen ref**: a stale copy pins an installed plugin to the wrong nen build. |
| `contracts/*` | `reference.gates.json`, passed as `nen pr ready --gates "$CLAUDE_PLUGIN_ROOT/contracts/…"` by `pr-state`, `drive`, `backlog-state`, `futon` and `tensho`. Stale reviewer identities produce a **wrong readiness verdict, silently** — the worst failure mode in the repo. |
| `docs/ROSTER.md` | cited by `claude/agents/kurapika.md` and `claude/commands/kurapika.md` as *the authority* on who exists and what standing they have. An installed plugin reading a stale roster can act as an agent whose row changed, or miss one that was added. This is the direct analogue of `<reference-repo>` covering `schemas/repos.json` and `scripts/ichigo_pix.txt` — data the agent reads, not code it runs. |
| `docs/delegation-grammar-DRAFT.md` | **Added by the review correction.** The same criterion as `ROSTER`, and the first cut got it wrong. `claude/agents/gon.md` § 1 says, in the shipped file: *"Read `docs/delegation-grammar-DRAFT.md` before your first act of any run"* — that is a **run-time read by an installed copy**, and `claude/agents/kurapika.md` cites it for the unratified-grant rule too. The original justification ("a draft, cited by link, never executed") confused a statement about the document's *authority* with a statement about whether it *ships*. A stale draft is exactly as invisible to an installed plugin as a stale roster, and the consequence is worse: an agent reading a superseded grammar. |
| `hooks/*` | **Forward-proofing.** Nothing lives here today. The day a hook is added it is plugin-shipped and executed every session — and a guard that has to be *remembered* at that moment is a guard that is not there. |
| `.mcp.json` | **Forward-proofing**, same reasoning: an MCP server declaration is read by the installed plugin at start-up. |

Deliberately **not** covered, because nothing installed reads them at run time: `README.md`, `docs/ab/**`
(these evidence records — read by humans on GitHub, never by an installed copy), `scripts/**` (CI-only — no
agent or skill invokes anything there), `.github/**`.

Verified by classification sweep, re-run after the glob change:

```
$ bash -c 'source scripts/plugin_bump_check.sh; for p in …; do path_is_plugin_surface "$p" && echo "COVERED      $p" || echo "not covered  $p"; done'
COVERED      .claude-plugin/plugin.json
COVERED      .claude-plugin/marketplace.json
COVERED      claude/agents/kurapika.md
COVERED      claude/agents/gon.md
COVERED      claude/commands/kurapika.md
COVERED      claude/skills/drive/SKILL.md
COVERED      claude/skills/hatsu-warmup/SKILL.md
COVERED      claude/skills/README.md
COVERED      nen.contract.json
COVERED      contracts/reference.gates.json
COVERED      docs/ROSTER.md
COVERED      docs/delegation-grammar-DRAFT.md
COVERED      hooks/session_start.sh
COVERED      .mcp.json
not covered  README.md
not covered  docs/ab/drive.md
not covered  docs/ab/plugin-bump-guard.md
not covered  scripts/plugin_bump_check.sh
not covered  .github/workflows/plugin-bump-check.yml
```

`hooks/session_start.sh` is a **hypothetical** path — the directory does not exist yet. That is the point of
the row: the glob is in place before the file is.

Note `claude/skills/README.md` is covered: `claude/*` is a bash pattern match, not filename globbing, so `*`
crosses `/` and the glob covers any depth. That is inherited behaviour, and it is the behaviour wanted.

### One inherited weakness, stated rather than quietly carried

`version_bumped` returns true when HEAD's `version` is **non-empty and different** from BASE's. It does
**not** parse semver and does **not** check direction. So a **downgrade** satisfies the guard, and so does a
**non-semver string**:

```
$ bash scripts/plugin_bump_check.sh <tmp>/changed_surface.txt <tmp>/base_010.json <tmp>/head_downgrade.json <tmp>/pr_body_empty.md
plugin.json version bumped — plugin-bump guard satisfied      # 0.1.0 -> 0.0.1
[exit 0]

$ bash scripts/plugin_bump_check.sh <tmp>/changed_surface.txt <tmp>/base_plugin.json <tmp>/head_nonsemver.json <tmp>/pr_body_empty.md
plugin.json version bumped — plugin-bump guard satisfied      # 0.0.1 -> "not-a-version"
[exit 0]
```

This is **inherited from the `<reference-repo>` original, function for function**, and it is left that way here
deliberately: the guard's job is to catch the *silent no-bump*, which is the failure that actually shipped
(RR-PR-#546). A wrong-direction or malformed bump is visible in the diff and caught by review. Recorded so
that nobody reads "guard satisfied" as "the version is correct" — it means only "the field changed".

---

## 3. The acceptance transcripts — refuse, then pass

**Every transcript in this section was re-run after the review fixes** (the new globs and the exec-bit
change), against the same fixtures, and the verdicts are unchanged.

**The fixtures**, all in a throwaway directory shown as `<tmp>`. `base_plugin.json` is `main`'s real
manifest (`version` `0.0.1`, confirmed by `git show main:.claude-plugin/plugin.json`); `head_bumped.json` is
the same file with `version` set to `0.1.0`; `head_unbumped.json` is a byte-identical copy of the base.
`changed_surface.txt` contains one line, `claude/skills/drive/SKILL.md`; `changed_nonsurface.txt` contains
`README.md`, `docs/ab/drive.md`, `scripts/plugin_bump_check.sh`.

### 3.1 REFUSE — a plugin-surface change with no bump

```
$ bash scripts/plugin_bump_check.sh <tmp>/changed_surface.txt <tmp>/base_plugin.json <tmp>/head_unbumped.json <tmp>/pr_body_empty.md
This PR changes a plugin-shipped surface (.claude-plugin/**, claude/**,
nen.contract.json, contracts/**, docs/ROSTER.md,
docs/delegation-grammar-DRAFT.md, hooks/**, or .mcp.json) but leaves
.claude-plugin/plugin.json's `version` field unchanged.

Claude Code keys its plugin cache on that field. An already-installed Hatsu
will never pick this change up until the version is bumped — no error, no
warning, the change simply does not ship. (Ported from <reference-repo>'s
RR-IS-#557 item 5, filed after exactly this omission shipped RR-PR-#546 to
nobody.)

Bump `.claude-plugin/plugin.json`'s `version` (semver):
  - patch  — wording/fix-only change to a shipped surface.
  - minor  — an agent definition's or a skill's BEHAVIOUR changes; a new skill;
             a new pinned nen ref in nen.contract.json.
  - major  — a breaking change to the plugin's public interface (a command, an
             agent's invocation contract, the shape of the Nen contract).

Or, if this change provably does not affect the shipped plugin surface (e.g. a
comment-only edit), state `no plugin bump: <reason>` in the PR body.
[exit 1]
```

### 3.2 PASS — the **same** change, once the bump is added

The only difference between this run and § 3.1 is `version: "0.0.1"` → `"0.1.0"`. The changed-files list is
byte-identical.

```
$ bash scripts/plugin_bump_check.sh <tmp>/changed_surface.txt <tmp>/base_plugin.json <tmp>/head_bumped.json <tmp>/pr_body_empty.md
plugin.json version bumped — plugin-bump guard satisfied
[exit 0]
```

### 3.3 Not applicable — nothing shipped changed

`changed_nonsurface.txt` = `README.md`, `docs/ab/drive.md`, `scripts/plugin_bump_check.sh`. Same unbumped
manifest as § 3.1.

```
$ bash scripts/plugin_bump_check.sh <tmp>/changed_nonsurface.txt <tmp>/base_plugin.json <tmp>/head_unbumped.json <tmp>/pr_body_empty.md
no plugin-shipped surface changed — plugin-bump guard does not apply
[exit 0]
```

### 3.4 Opt-out — declared in the PR body

Same surface change and same unbumped manifest as § 3.1; the PR body carries
`no plugin bump: comment-only edit, no shipped byte changes.`

```
$ bash scripts/plugin_bump_check.sh <tmp>/changed_surface.txt <tmp>/base_plugin.json <tmp>/head_unbumped.json <tmp>/pr_body_optout.md
plugin-bump opt-out present in PR body — skipping version check
[exit 0]
```

A **bare** `no plugin bump:` with nothing after the colon does not match — the regex requires a non-space
character. The reason is the point of the escape hatch.

### 3.5 Fail-closed on bad wiring

A missing changed-files file is a workflow-wiring bug, and the guard refuses to treat it as "no files
changed":

```
$ bash scripts/plugin_bump_check.sh <tmp>/nope.txt <tmp>/base_plugin.json <tmp>/head_unbumped.json <tmp>/pr_body_empty.md
error: changed-files-file '<tmp>/nope.txt' does not exist — refusing to fail-open on a bad workflow wiring input
[exit 2]

$ bash scripts/plugin_bump_check.sh <tmp>/changed_surface.txt
usage: scripts/plugin_bump_check.sh <changed-files-file> <base-plugin-json> <head-plugin-json> <pr-body-file>
[exit 2]
```

---

## 4. Against this PR's own real diff

Not a constructed fixture — the actual changed-file set of `p2/3-v0.1` against `main`, re-taken after the
adversarial-review fixes and including the working tree:

```
.claude-plugin/marketplace.json          COVERED
.claude-plugin/plugin.json               COVERED
.github/workflows/plugin-bump-check.yml  not covered
README.md                                not covered
claude/skills/README.md                  COVERED
claude/skills/backlog-loop/SKILL.md      COVERED
claude/skills/backlog-synthesis/SKILL.md COVERED
claude/skills/build/SKILL.md             COVERED
claude/skills/drive/SKILL.md             COVERED
claude/skills/futon/SKILL.md             COVERED
claude/skills/getsuga/SKILL.md           COVERED
claude/skills/izanagi/SKILL.md           COVERED
claude/skills/izanami/SKILL.md           COVERED
claude/skills/jujisho/SKILL.md           COVERED
claude/skills/pr-state/SKILL.md          COVERED
claude/skills/senkei/SKILL.md            COVERED
claude/skills/tensho/SKILL.md            COVERED
docs/ab/*.md  (17 files)                 not covered
scripts/plugin_bump_check.sh             not covered
```

**Fifteen** of those are guarded surfaces — every `.claude-plugin/*` manifest and every changed
`claude/skills/**/SKILL.md` — so the guard applies. (The first cut of this document said *"Two of those"*
while listing three paths under two globs; that arithmetic error is corrected here along with the file
list, which has grown with the review fixes.)

**With the real bump (`0.0.1` → `0.1.0`):**

```
$ bash scripts/plugin_bump_check.sh <tmp>/changed_all.txt <tmp>/base_plugin.json <tmp>/head_real.json <tmp>/pr_body_empty.md
plugin.json version bumped — plugin-bump guard satisfied
[exit 0]
```

**Counterfactual — the identical diff with the bump reverted** (`head_real.json` with `version` set back to
`0.0.1`, everything else untouched):

```
$ bash scripts/plugin_bump_check.sh <tmp>/changed_all.txt <tmp>/base_plugin.json <tmp>/head_real_unbumped.json <tmp>/pr_body_empty.md
This PR changes a plugin-shipped surface (.claude-plugin/**, claude/**,
nen.contract.json, contracts/**, docs/ROSTER.md,
docs/delegation-grammar-DRAFT.md, hooks/**, or .mcp.json) but leaves
.claude-plugin/plugin.json's `version` field unchanged.
…
[exit 1]
```

The guard would have refused this very PR without its bump, and passes it with one. That is the acceptance
criterion, met against real content rather than a fixture.

---

## 5. The CI wiring, and what it deliberately does not do

`.github/workflows/plugin-bump-check.yml` fires on `pull_request` (`opened`, `synchronize`, `reopened`,
`edited`) and does five things before calling the script:

1. checks out the **PR head** as data only, `persist-credentials: false`;
2. asserts the guard script's **exec bit in-tree** on that head (§ 5.1);
3. checks out `main` into `.trusted/` and runs **that** copy of the guard — a PR must not be able to rewrite
   the guard that judges it;
4. reads the changed-files list and the base `.claude-plugin/plugin.json` **over the API** with the
   workflow's own `contents: read` / `pull-requests: read` token, so no git credential is needed and neither
   checkout carries one;
5. writes the PR body to a file **through an environment variable**, never by `${{ }}`-interpolating
   attacker-controlled text into a shell line.

`edited` is in the trigger list on purpose: the opt-out lives in the PR body, so a body edit has to re-run
the check or the escape hatch would need an empty push to take effect.

### 5.1 The trusted-copy gate — what was broken, and what fixed it

**What shipped first was wrong, and this section previously claimed it was fine.** The bootstrap fallback
was gated on `[ -x .trusted/scripts/plugin_bump_check.sh ]`, and `scripts/plugin_bump_check.sh` was
committed with mode `100644`. `-x` on a non-executable file is false, permanently — so the sentence *"after
the merge that branch is never taken again"* was false: it would have been taken on **every** PR forever,
and every PR would have been judged by **its own copy of the guard**. A PR could therefore have deleted the
guard's logic and passed its own check. That is exactly the failure the workflow header calls fatal, and the
document asserted the opposite.

**Fixed both ways, deliberately, because either alone leaves a trap:**

- `git update-index --chmod=+x scripts/plugin_bump_check.sh` — the file is now `100755` in the index. (Git
  tracks only the exec bit; on a Windows checkout the working-tree permission is irrelevant, which is
  precisely how this was missed.)
- The workflow's test is now `-f`, not `-x`. **`-f` is the honest predicate**: the job invokes the guard as
  `bash "$guard"`, which needs the file to exist and be readable, not to be executable. Gating on a property
  the invocation does not require is how a silent fallback gets built.

With `-f`, the bootstrap sentence becomes true as written: `scripts/plugin_bump_check.sh` does not exist on
`main` until this PR merges, so until then step 3 finds nothing and the workflow falls back to the PR's own
copy — **loudly**, via `::warning::`. Once the file exists on `main`, the branch is genuinely never taken
again.

**The exec-bit assertion, and a named gap.** `<reference-repo>` catches this whole class with
`tests/workflow_script_exec_bit.bats`. **Hatsu has no bats harness, and adding one is out of this PR's
scope** — so the equivalent assertion lives in the workflow itself, as a step that reads the index of the PR
head:

```yaml
mode="$(git ls-files -s -- scripts/plugin_bump_check.sh | awk '{print $1}')"
[ "$mode" = "100755" ] || exit 1
```

This is a **narrower** guarantee than the bats test it substitutes for — it asserts one file's mode rather
than a property of every workflow-invoked script — and that narrowing is stated rather than papered over. A
bats harness remains the better answer whenever Hatsu grows a second such script.

**Not ported, deliberately:** the runner-probe job and the GitHub App token. Hatsu has no self-hosted runner
fleet and no App of its own — the whole point of the local plane — so `runs-on: ubuntu-latest` with the
default token is the honest wiring, not a reduced one.

---

## 6. Enforcement — what this check does NOT do today

Two things are true right now, and neither is a defect in the script:

1. **The check is advisory.** Nothing requires it. Until the maintainer adds branch protection or a
   repository ruleset that marks `plugin-bump-check` a **required** status check on `main`, a red check
   blocks no merge. The guard tells the truth; it does not yet enforce it.
2. **A same-repo PR is judged by its own workflow definition.** That is GitHub's behaviour, not a choice
   made here: for a pull request from a branch in the same repository, the workflow file that runs is the
   one on the PR head. Checking the *guard script* out of `main` (§ 5.1) closes the script half of that hole
   and is the reason it matters; it cannot close the YAML half, because the YAML is what does the checking
   out.

**Recommended hardening — repository settings, which is a human gate.** This is a recommendation, not
something this PR performs or could perform:

- Require the `plugin-bump-check` status check on `main` (branch protection or a ruleset).
- Protect `.github/**` with a ruleset or a `CODEOWNERS` entry, so a PR cannot silently rewrite the workflow
  that judges it and have the rewrite take effect on that same PR.

Stated here, and in one line in the README's *Contributing* section, so that no reader takes a green check
for an enforced one.
