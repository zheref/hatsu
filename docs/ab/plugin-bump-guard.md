# Evidence — the plugin-bump guard (zheref/hatsu#3)

Port of bankai-core's `scripts/plugin_bump_check.sh` into Hatsu as
[`scripts/plugin_bump_check.sh`](../../scripts/plugin_bump_check.sh), wired as the
[`plugin-bump-check`](../../.github/workflows/plugin-bump-check.yml) PR workflow.

This file is not a skill A/B — it is the **guard's own acceptance evidence**: the recorded proof that it
**refuses** a plugin-surface change carrying no version bump and **passes** the same change once the bump is
added. Every transcript below was produced by running the committed script; nothing is reconstructed.

**Run:** 2026-09-02T03:33Z (UTC), branch `p2/3-v0.1` at `00b41b13d92ef8c13ac12b23a28c12d6beee6b82`, base
`main` at `992427c714d8fcd6ee26981bea0c9a7627fae656`. GNU bash 5.2.37 (`x86_64-pc-msys`), `jq` 1.8.2. No
network, no `gh`, no GitHub: the four inputs the CLI takes are plain files, which is the whole point of the
comparison logic living in the script rather than in YAML.

---

## 1. What the guard protects

Claude Code keys its plugin cache on `.claude-plugin/plugin.json`'s **`version`** field. Change a
plugin-shipped surface without changing that field and the change is real in the repository and invisible on
every machine that already has the plugin installed. There is no error, no warning, and nothing in the PR
that says so.

The inherited incident record, kept in the script's header: the guard is bankai-core's **BC-IS-#557 item
5**, filed after **BC-PR-#546** changed four plugin-shipped surfaces — an agent definition, a skill, a
script, and the registry read at warm-up — without bumping the version. The fix never reached an installed
plugin until **BC-PR-#578** bumped it retroactively.

It moves to Hatsu because guards live beside the surface they guard, and this is now that surface.

## 2. What changed in the port

| | bankai-core `v0.11.3` | Hatsu |
|---|---|---|
| **Comparison logic** | `path_is_plugin_surface`, `any_path_is_plugin_surface`, `plugin_version`, `version_bumped`, `pr_body_has_opt_out`, then a 4-argument CLI | **unchanged**, function for function |
| **Surface globs** | `claude/*`, `scripts/ichigo_prompt.sh`, `scripts/ichigo_board.sh`, `scripts/ichigo_pix.txt`, `scripts/gate_stop.sh`, `scripts/attention_signal.sh`, `schemas/repos.json`, `.claude-plugin/*` | `.claude-plugin/*`, `claude/*`, `nen.contract.json`, `contracts/*`, `docs/ROSTER.md` |
| **Opt-out** | `no plugin bump: <reason>` in the PR body | **unchanged** |
| **Workflow** | reusable `workflow_call` with a self-hosted-runner probe and a GitHub App token | a plain `pull_request` job on `ubuntu-latest` — Hatsu has no runner fleet and no App |
| **Trusted-script posture** | guard checked out from `main`, never run from the PR | **unchanged** — a PR that can rewrite the guard judging it makes the guard worth nothing |
| **Credential posture** | `persist-credentials: false` on both checkouts; diff and base manifest over the API | **unchanged** |

### Why *these* globs

Derived from what `.claude-plugin/plugin.json` declares, plus the files an installed copy reads **at run
time** — staleness in either is the same failure.

| Glob | Why it is covered |
|---|---|
| `.claude-plugin/*` | the manifests themselves. |
| `claude/*` | everything `plugin.json` points at: `agents` (kurapika, gon, hisoka, phinks, uvogin), `commands` (`/kurapika`), `skills` (the 17 ports + `hatsu-warmup`). |
| `nen.contract.json` | read at run time as `$CLAUDE_PLUGIN_ROOT/nen.contract.json` by `hatsu-warmup` and by the agent definitions. It carries the **pinned nen ref**: a stale copy pins an installed plugin to the wrong nen build. |
| `contracts/*` | `bankai-core.gates.json`, passed as `nen pr ready --gates "$CLAUDE_PLUGIN_ROOT/contracts/…"` by `pr-state`, `drive`, `backlog-state`, `futon` and `tensho`. Stale reviewer identities produce a **wrong readiness verdict, silently** — the worst failure mode in the repo. |
| `docs/ROSTER.md` | cited by `claude/agents/kurapika.md` and `claude/commands/kurapika.md` as *the authority* on who exists and what standing they have. An installed plugin reading a stale roster can act as an agent whose row changed, or miss one that was added. This is the direct analogue of bankai-core covering `schemas/repos.json` and `scripts/ichigo_pix.txt` — data the agent reads, not code it runs. |

Deliberately **not** covered, because nothing installed reads them at run time: `README.md`, `docs/ab/**`,
`docs/delegation-grammar-DRAFT.md` (a draft, cited by link, never executed), `scripts/**` (CI-only — no
agent or skill invokes anything there), `.github/**`.

Verified by classification sweep:

```
$ bash -c 'source scripts/plugin_bump_check.sh; for p in …; do path_is_plugin_surface "$p" && echo "COVERED      $p" || echo "not covered  $p"; done'
COVERED      .claude-plugin/plugin.json
COVERED      .claude-plugin/marketplace.json
COVERED      claude/agents/kurapika.md
COVERED      claude/commands/kurapika.md
COVERED      claude/skills/drive/SKILL.md
COVERED      claude/skills/hatsu-warmup/SKILL.md
COVERED      claude/skills/README.md
COVERED      nen.contract.json
COVERED      contracts/bankai-core.gates.json
COVERED      docs/ROSTER.md
not covered  README.md
not covered  docs/ab/drive.md
not covered  docs/delegation-grammar-DRAFT.md
not covered  scripts/plugin_bump_check.sh
not covered  .github/workflows/plugin-bump-check.yml
```

Note `claude/skills/README.md` is covered: `claude/*` is a bash pattern match, not filename globbing, so `*`
crosses `/` and the glob covers any depth. That is inherited behaviour, and it is the behaviour wanted.

---

## 3. The acceptance transcripts — refuse, then pass

**The fixtures.** `base_plugin.json` is `main`'s real manifest (`version` `0.0.1`); `head_bumped.json` is
the same file with `version` set to `0.1.0`; `head_unbumped.json` is a byte-identical copy of the base.
`changed_surface.txt` contains one line, `claude/skills/drive/SKILL.md`.

### 3.1 REFUSE — a plugin-surface change with no bump

```
$ bash scripts/plugin_bump_check.sh changed_surface.txt base_plugin.json head_unbumped.json pr_body_empty.md
This PR changes a plugin-shipped surface (.claude-plugin/**, claude/**,
nen.contract.json, contracts/**, or docs/ROSTER.md) but leaves
.claude-plugin/plugin.json's `version` field unchanged.

Claude Code keys its plugin cache on that field. An already-installed Hatsu
will never pick this change up until the version is bumped — no error, no
warning, the change simply does not ship. (Ported from bankai-core's
BC-IS-#557 item 5, filed after exactly this omission shipped BC-PR-#546 to
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
$ bash scripts/plugin_bump_check.sh changed_surface.txt base_plugin.json head_bumped.json pr_body_empty.md
plugin.json version bumped — plugin-bump guard satisfied
[exit 0]
```

### 3.3 Not applicable — nothing shipped changed

`changed_nonsurface.txt` = `README.md`, `docs/ab/drive.md`, `scripts/plugin_bump_check.sh`. Same unbumped
manifest as § 3.1.

```
$ bash scripts/plugin_bump_check.sh changed_nonsurface.txt base_plugin.json head_unbumped.json pr_body_empty.md
no plugin-shipped surface changed — plugin-bump guard does not apply
[exit 0]
```

### 3.4 Opt-out — declared in the PR body

Same surface change and same unbumped manifest as § 3.1; the PR body carries
`no plugin bump: comment-only edit, no shipped byte changes.`

```
$ bash scripts/plugin_bump_check.sh changed_surface.txt base_plugin.json head_unbumped.json pr_body_optout.md
plugin-bump opt-out present in PR body — skipping version check
[exit 0]
```

A **bare** `no plugin bump:` with nothing after the colon does not match — the regex requires a non-space
character. The reason is the point of the escape hatch.

### 3.5 Fail-closed on bad wiring

A missing changed-files file is a workflow-wiring bug, and the guard refuses to treat it as "no files
changed":

```
$ bash scripts/plugin_bump_check.sh nope.txt base_plugin.json head_unbumped.json pr_body_empty.md
error: changed-files-file 'nope.txt' does not exist — refusing to fail-open on a bad workflow wiring input
[exit 2]

$ bash scripts/plugin_bump_check.sh changed_surface.txt
usage: scripts/plugin_bump_check.sh <changed-files-file> <base-plugin-json> <head-plugin-json> <pr-body-file>
[exit 2]
```

---

## 4. Against this PR's own real diff

Not a constructed fixture — the actual `git diff --name-only main...HEAD` for `p2/3-v0.1`:

```
.claude-plugin/marketplace.json
.claude-plugin/plugin.json
.github/workflows/plugin-bump-check.yml
README.md
claude/skills/README.md
scripts/plugin_bump_check.sh
```

Two of those (`.claude-plugin/*`, `claude/skills/README.md`) are guarded surfaces, so the guard applies.

**With the real bump (`0.0.1` → `0.1.0`):**

```
$ bash scripts/plugin_bump_check.sh changed_thisbranch.txt base_plugin.json head_real.json pr_body_empty.md
plugin.json version bumped — plugin-bump guard satisfied
[exit 0]
```

**Counterfactual — the identical diff with the bump reverted** (`head_real.json` with `version` set back to
`0.0.1`, everything else untouched):

```
$ bash scripts/plugin_bump_check.sh changed_thisbranch.txt base_plugin.json head_real_unbumped.json pr_body_empty.md
This PR changes a plugin-shipped surface (.claude-plugin/**, claude/**,
nen.contract.json, contracts/**, or docs/ROSTER.md) but leaves
.claude-plugin/plugin.json's `version` field unchanged.
…
[exit 1]
```

The guard would have refused this very PR without its bump, and passes it with one. That is the acceptance
criterion, met against real content rather than a fixture.

---

## 5. The CI wiring, and what it deliberately does not do

`.github/workflows/plugin-bump-check.yml` fires on `pull_request` (`opened`, `synchronize`, `reopened`,
`edited`) and does four things before calling the script:

1. checks out the **PR head** as data only, `persist-credentials: false`;
2. checks out `main` into `.trusted/` and runs **that** copy of the guard — a PR must not be able to rewrite
   the guard that judges it;
3. reads the changed-files list and the base `.claude-plugin/plugin.json` **over the API** with the
   workflow's own `contents: read` / `pull-requests: read` token, so no git credential is needed and neither
   checkout carries one;
4. writes the PR body to a file **through an environment variable**, never by `${{ }}`-interpolating
   attacker-controlled text into a shell line.

`edited` is in the trigger list on purpose: the opt-out lives in the PR body, so a body edit has to re-run
the check or the escape hatch would need an empty push to take effect.

**Bootstrap caveat, self-limiting.** `scripts/plugin_bump_check.sh` does not exist on `main` until this PR
merges, so until then step 2 finds nothing and the workflow falls back to the PR's own copy — **loudly**,
via `::warning::`. After the merge that branch is never taken again. This is the same declared bootstrap the
bankai-core original carried on its own first PR.

**Not ported, deliberately:** the runner-probe job and the GitHub App token. Hatsu has no self-hosted runner
fleet and no App of its own — the whole point of the local plane — so `runs-on: ubuntu-latest` with the
default token is the honest wiring, not a reduced one.
