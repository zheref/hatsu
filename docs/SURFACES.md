# Surfaces

**Hatsu is authored once, for Claude Code, and mirrored onto three other agent surfaces: Codex, Cursor
and Antigravity.** This file is the hub: the four compared, which files are written and which are
generated, the one generator and its stamp, the check and the workflow that regenerates. Everything
per surface, with every capability cited to the official line it was read from, is in
[`docs/surfaces/`](surfaces/README.md): [`claude-code.md`](surfaces/claude-code.md),
[`codex.md`](surfaces/codex.md), [`cursor.md`](surfaces/cursor.md),
[`antigravity.md`](surfaces/antigravity.md); the recorded transcripts are
[`surfaces/evidence/surfaces.md`](surfaces/evidence/surfaces.md).

Nothing here is a port. The mirrors are the same skill bodies, byte for byte, with the frontmatter
reduced to the keys each surface documents and the invocation respelled, produced by one generator,
[`nen surface mirror`](https://github.com/zheref/nen) (nen v0.13.0), for all three.

## 1. The four surfaces

| | **Claude Code** | **Codex** | **Cursor** | **Antigravity** |
|---|---|---|---|---|
| how Hatsu arrives | `claude plugin install hatsu@hatsu` | bootstrap seeds `hatsu-warmup`; the warm-up refreshes every session | the same, by symlink | global plugin at `~/.gemini/config/plugins/hatsu`, or bootstrapped into `.agents/` |
| skills read from | `$CLAUDE_PLUGIN_ROOT/claude/skills/<name>/SKILL.md` | `<repo>/.agents/skills/<name>/SKILL.md` (copies) | `<repo>/.cursor/skills/<name>/SKILL.md` (symlinks) | plugin `<name>/SKILL.md` or `<repo>/.agents/skills/<name>/SKILL.md` |
| personas read from | `claude/agents/<persona>.md` | `AGENTS.override.md` as prose, plus `.codex/agents/<persona>.toml` | `.cursor/agents/<persona>.md` | plugin `agents/<persona>.md` or `.agents/agents/<persona>.md` |
| rules file | none | `AGENTS.override.md` (32 KiB cap) | `.cursor/rules/hatsu.mdc` | `rules/hatsu.md`, 12,000 characters max |
| invocation spelling | `hatsu:<name>` | `$<name>` | `/<name>` | `/<name>` |
| turn-end hook | **yes**, `Stop` in `hooks/hooks.json` | **yes**, `Stop` in `.codex/hooks.json` | **yes**, `stop` in `.cursor/hooks.json` | **yes**, `Stop` in `.agents/hooks.json` |
| session-start hook | `SessionStart`, `hooks/session-start.sh` (a reminder; the plugin is read in place) | `SessionStart` (mirror refresh) | `sessionStart` (mirror refresh) | `PreInvocation` (no `SessionStart` exists; mirror refresh) |
| trunk guard | `PreToolUse` on `Bash`, `permissionDecision: deny` | `PreToolUse`, `permissionDecision: deny` (`ask` not honoured yet) | `beforeShellExecution`, `permission: deny` | `PreToolUse` on `run_command`, `decision: deny` |
| permissions | `.claude/settings.local.json`, `Bash(<exe> <args>)` | `.codex/config.toml`: `sandbox_mode`, `writable_roots` (the one root-scoped surface) | `.cursor/cli.json`, `Shell(<exe> <args>)` | per-agent `commandExecutionPolicy`; the guard is the enforcement |
| in-session subagent | the Agent tool | `spawn_agent` | `.cursor/agents/` | `invoke_subagent`, `Workspace` `inherit`, `branch` or `share` |
| native option picker | `AskUserQuestion` | `request_user_input` | the ask question tool (`cursor/ask_question`) | `ask_question`, `is_multi_select` |
| persona model key | `model`: tier alias | `model` in the TOML; `[agents]` fragment from the rows | `model: inherit` (Cursor-native only) | `model`: `inherit`, `flash`, `pro` |
| reviewer tier (`models.roles.reviewer` = `deep`) | `opus` | `sol` | `grok` | `pro` |
| minimum build | n/a | none documented; validated on `codex-cli 0.149.0` | `cursor-agent 2026.01.*`, below it no skill is seen | Antigravity IDE / `agy` CLI |

Each surface's rows are cited, dated 2026-09-20, in its guide's checklist. Two corrections made there
on that date: Codex and Cursor **do** have hooks (the hub used to say otherwise), and Antigravity's
workspace paths are `.agents/…` with `.agent/…` as back-compatibility only.

**First-run discovery is a bootstrap, not an environment variable.** `HATSU_PLUGIN_ROOT` names a
checkout; it cannot make an undiscovered skill callable. Codex, Cursor and Antigravity workspace mode
need one command before their first warm-up:
`"$HATSU_PLUGIN_ROOT/scripts/surface_bootstrap.sh" --surface <codex|cursor|antigravity> --target . --bootstrap`,
which seeds only `hatsu-warmup`; that skill's every-session refresh calls the same script with
`--install-all`. Fixture: `scripts/surface_bootstrap_fixture_check.sh`.

**The invocation spelling is the mirror's.** Every `hatsu:<name>` in a skill body is rewritten by the
generator because `--invocation-prefix hatsu:` tells it the source's namespace; `hatsu:` is caller data
and nen hard-codes no system's vocabulary.

## 2. Generated versus authored

| Path | |
|---|---|
| `claude/skills/<name>/SKILL.md` | **authored.** The one source, 44 directories (forty-three plus `hatsu-warmup`) |
| `claude/agents/<persona>.md` | **authored.** The one source, 11 personas plus `_review-preamble.md`, the shared reviewer protocol and not a persona (mirrored as one until `zheref/nen#223`) |
| `hooks/hooks.json`, `contracts/permissions.json`, `nen/workflow.json` | **authored.** The inputs the generator renders hooks, permissions and model config from |
| `surfaces/codex/<name>/SKILL.md`, `AGENTS.md`, `.codex/agents/*.toml`, `.codex/config.toml`, `.codex/hooks.json` | **generated** |
| `surfaces/cursor/<name>/SKILL.md`, `agents/*.md`, `.cursor/rules/hatsu.mdc`, `.cursor/cli.json`, `.cursor/hooks.json` | **generated** |
| `surfaces/antigravity/<name>/SKILL.md`, `agents/*.md`, `rules/hatsu.md`, `hooks.json`, `plugin.json` | **generated** |

Every generated file carries one marker as its first markdown line after the frontmatter fence (line 1
where there is no fence; the `description` field in a JSON file), stamped with the plugin version:

```text
<!-- GENERATED by nen surface mirror (surface: antigravity, stamp: 0.43.0) -- do not edit; edit the source and regenerate -->
```

**Edit the source, never the mirror.** A hand edit is reported by the check, by name, as
`hand-edited`; a stamp behind `.claude-plugin/plugin.json` is drift even when the bytes match. The
bodies carry relative links written for this layout, so inside a target's `.agents/skills/` a link like
`../../../docs/SURFACES.md` dangles; that is the price of a verbatim body and it is stated rather than
papered over.

### What the warm-up places in a target repository

| Surface | What is placed | Excluded how |
|---|---|---|
| Claude Code | the permission pack only; the plugin is read in place | `info/exclude` |
| Antigravity, global plugin | nothing; read from `${GEMINI_CONFIG_DIR:-~/.gemini}/config/plugins/hatsu` | none |
| Codex | `.agents/skills/<name>/` by `cp -R`, `AGENTS.override.md`, `.codex/` from the pack | `info/exclude` |
| Cursor | `.cursor/skills/<name>/` and `.cursor/agents/<persona>.md` by symlink, `.cursor/` from the pack | `info/exclude` |
| Antigravity, workspace | `.agents/skills/`, `.agents/agents/`, `.agents/rules/hatsu.md`, `.agents/hooks.json`, `.agents/hooks/` | `info/exclude` |

The ownership rule (`ours`), the `.gitignore` prohibition and the bell fallback are in
[`docs/surfaces/README.md`](surfaces/README.md) § *Shared rules*; the Codex sandbox and
`AGENTS.override.md` rules are in [`codex.md`](surfaces/codex.md) § 1.

## 3. Regenerating

From the repository root, one line per surface, in the same commit as the source change:

```sh
v="$(python3 -c 'import json;print(json.load(open(".claude-plugin/plugin.json"))["version"])')"
for s in codex cursor antigravity; do
  case "$s" in antigravity) root='${HATSU_PLUGIN_ROOT:-${GEMINI_CONFIG_DIR:-$HOME/.gemini}/config/plugins/hatsu}' ;; *) root='${HATSU_PLUGIN_ROOT}' ;; esac
  nen surface mirror generate --surface "$s" --source claude/skills --agents claude/agents \
    --out "surfaces/$s" --invocation-prefix hatsu: --models nen/workflow.json \
    --permissions contracts/permissions.json --hooks hooks/hooks.json --rules claude/rules/hatsu.md --source-surface claude \
    --hooks-root "$root" --manifest .claude-plugin/plugin.json --stamp "$v"
done
```

Each writes only the files whose bytes changed, deletes an orphan whose source is gone, and refuses at
exit 2 to overwrite a file that does not carry the marker. There is no shell generator any more.

## 4. The check

[`scripts/surface_mirror_check.sh`](../scripts/surface_mirror_check.sh) runs `nen surface mirror check`
with the same flags for codex, cursor and antigravity, and writes nothing:

| Exit | Meaning |
|---|---|
| `0` | every mirror is byte-identical to a fresh generation at the current stamp |
| `1` | drift: `missing`, `extra`, `stale` (marked for another surface), `hand-edited`, listed per surface |
| `2` | the `nen` on `PATH` has no `surface` verb, or a wiring defect; never silently passed |
| `3` | no `nen` on `PATH` |

With `--installed <path>` the same verb diffs a host's installed copy (`~/.claude/plugins/cache/…`,
`<repo>/.agents/skills`, `<repo>/.cursor`, `~/.gemini/config/plugins/hatsu`) against a fresh
generation; the warm-up runs it first and copies only on drift.

**In CI.** [`surface-mirror-check.yml`](../.github/workflows/surface-mirror-check.yml) bootstraps nen at
the ref `nen/contract.json` pins and runs the script from the trusted checkout against the PR's. It is
**required on `main`, pending the ruleset**: listing the `surface-mirror-check` context in the
repository ruleset is the maintainer's act, named in the PR that lands this; renaming the job silently
un-requires it. [`surface-mirror-regenerate.yml`](../.github/workflows/surface-mirror-regenerate.yml)
runs the generator on drift and opens a pull request with the regenerated mirrors, as bankai-core's
sync-canon did, so a source change merged without its mirrors is repaired by a PR rather than by a
red check nobody reads.

**Not a second lint.** `nen/contract.json`'s `plugin` lane keeps one `lint` seat,
`claude plugin validate . --strict`, and `nen/workflow.json`'s `iteration.checks` keeps that one entry.
The check runs beside the regeneration, in `mukai`, before `shibari` opens the PR
([`docs/WORKFLOW.md`](WORKFLOW.md) § 2 → `iteration`).

## 5. Where the rest lives

| | |
|---|---|
| per-surface paths, keys, hooks, permissions, rules, picker, generation, dated checklist | [`docs/surfaces/<surface>.md`](surfaces/README.md) |
| the skeleton every guide follows, the shared placement rules, updating the checkout | [`docs/surfaces/README.md`](surfaces/README.md) |
| headless validation commands and their transcripts | [`docs/surfaces/evidence/surfaces.md`](surfaces/evidence/surfaces.md), Appendix A |
| placing the mirrors into a target | [`claude/skills/hatsu-warmup/SKILL.md`](../claude/skills/hatsu-warmup/SKILL.md) § 5 |
| the bell and the picker at a gate | [`claude/skills/jutaisho/SKILL.md`](../claude/skills/jutaisho/SKILL.md) |
| raising a reviewer per surface | [`claude/skills/hanten/SKILL.md`](../claude/skills/hanten/SKILL.md) § 9a |
| the model matrix | [`nen/workflow.json`](../nen/workflow.json) → `models`; [`docs/WORKFLOW.md`](WORKFLOW.md) § 2 |
| keeping the guides current | `hatsu:great-hiker`, one Netero-shaped issue per surface whose checklist moved |
