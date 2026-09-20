# Surface guides

One guide per agent surface Hatsu runs on. Each guide is the evolution record for that surface: what
the surface reads, where, under which keys, and the official page every one of those facts was read
from, with the line quoted and the day it was fetched. [`docs/SURFACES.md`](../SURFACES.md) is the hub
that compares the four; these files carry the detail.

| Guide | Surface | Layout the generator writes |
|---|---|---|
| [`claude-code.md`](claude-code.md) | Claude Code | none: the plugin under `claude/` is the canonical copy |
| [`codex.md`](codex.md) | Codex (CLI, IDE, ChatGPT app) | `surfaces/codex/` |
| [`cursor.md`](cursor.md) | Cursor (`cursor-agent`, IDE) | `surfaces/cursor/` |
| [`antigravity.md`](antigravity.md) | Antigravity (IDE, `agy` CLI) | `surfaces/antigravity/` |
| [`evidence/surfaces.md`](evidence/surfaces.md) | all | the recorded transcripts: every live run these guides cite, by section and finding number |

## The rule

**A row without a quoted line is not a claim.** Every capability a guide asserts about a surface sits in
that guide's dated checklist with the official URL and the sentence the page carries, verbatim. A fact
that was read from a changelog, a `--help`, or a live run is cited to the evidence file by section, and
that is a different kind of row: it says what a build did on a day, not what the vendor documents. A
fact with neither is a gap, and it goes under *Known gaps* by name so the next fetch knows to look.

## The skeleton

Every guide carries these sections, in this order, under these headings. A guide may add nothing above
the first heading except its title and one paragraph, and nothing after the last.

| # | Section | What it holds |
|---|---|---|
| 1 | **Identity and paths** | how Hatsu arrives on the surface, the discovery paths for skills, personas, rules and hooks (project and global), the invocation spelling, the headless command, and how to point the surface at a local checkout |
| 2 | **Skills** | the frontmatter keys the surface documents, any size or description budget, how the name is listed, and what the surface does with the tail of a description |
| 3 | **Personas and model config** | the per-persona file or its absence, the frontmatter the surface documents, the model key and its admissible values, and which `nen/workflow.json` tier maps to which alias |
| 4 | **Hooks** | the hook file and its shape, the events that exist, the decision key a `PreToolUse`-class hook answers with, and what Hatsu installs (trunk guard, session start, stop bell) |
| 5 | **Permissions** | where an allowlist lives, its syntax, whether the scope is a root or a pattern, and what `contracts/permissions.json` renders into |
| 6 | **Rules** | the rules or instructions file the surface reads, its precedence and size limit, and what Hatsu writes there |
| 7 | **The option picker** | the native tool `jutaisho` asks a gate question through, its argument shape, and whether several answers can be ticked |
| 8 | **Generation** | the one `nen surface mirror generate` line for this surface, what it emits, the marker and the stamp, and the `check --installed` line for a host's installed copy |
| 9 | **Dated checklist** | one table: fact, value, quoted line, source URL, fetched. Every row above that is a documented capability has a row here |
| 10 | **Known gaps (not documented)** | what the official pages do not say, named, so a later fetch looks for it rather than assuming |
| 11 | **How this guide evolves** | Great Hiker's duty on this guide, and the one Netero-shaped issue it files per surface |

## Generation, shared across the three mirrored surfaces

nen v0.13.0 carries one generator for all three mirrors and no shell generator survives beside it:

```sh
nen surface mirror generate --surface <codex|cursor|antigravity> \
  --source claude/skills --agents claude/agents --out surfaces/<surface> \
  --invocation-prefix hatsu: --models nen/workflow.json \
  --permissions contracts/permissions.json --hooks hooks/hooks.json \
  --rules claude/rules/hatsu.md --source-surface claude \
  --hooks-root <root expression> --manifest .claude-plugin/plugin.json --stamp <plugin version>
```
`--hooks-root` is the expression every mirrored hook command resolves the plugin root through: `${HATSU_PLUGIN_ROOT}` on Codex and Cursor, `${HATSU_PLUGIN_ROOT:-${GEMINI_CONFIG_DIR:-$HOME/.gemini}/config/plugins/hatsu}` on Antigravity; the hook scripts travel with the manifest under `hooks/`. `--manifest` writes Antigravity's `plugin.json` from the Claude plugin manifest. `--source-surface claude` names the row of `models` whose aliases the canonical personas carry (`model: opus`, `sonnet`, `haiku`), so the generator reads each alias back to its tier before mapping it to the target surface's alias.


`nen surface mirror check` takes the same flags and writes nothing; with `--installed <path>` it diffs a
host's installed copy against a fresh generation instead of the committed mirror, which is what the
warm-up runs before it copies. Every generated file carries, as its first markdown line after the
frontmatter fence (line 1 where there is no fence):

```text
<!-- GENERATED by nen surface mirror (surface: antigravity, stamp: 0.43.0) -- do not edit; edit the source and regenerate -->
```

The stamp is `.claude-plugin/plugin.json`'s `version`; a mirror whose stamp trails the manifest is drift
even when its bytes are otherwise current.

## Shared rules the warm-up follows on every mirrored surface

Moved here from the hub on 2026-09-20 so that the hub stays a comparison and this stays the one place
the placement discipline is written.

**Ownership at each destination.** An exclude governs untracked paths only, so a target that tracks a
destination keeps it tracked and an `ln -sfn` or `rm -rf` over it destroys a file in somebody's history.
Nothing there: create it. A previous Hatsu install (a symlink into `<hatsu root>/surfaces/`, or a
directory whose `SKILL.md` carries the marker above): replace it. Anything else, and a tracked path is
always anything else: leave it untouched, install nothing under that name, and name it in the report. A
skipped name is reported, never swallowed; the warm-up would rather place forty of forty-four and say
so than overwrite one file it did not write.

```sh
# ours DEST -- true only for a destination the warm-up made. Tracked is NEVER ours.
ours() {
  git -C "$target" ls-files --error-unmatch -- "$1" >/dev/null 2>&1 && return 1
  [ -L "$1" ] && case "$(readlink "$1")" in "$hatsu_root"/surfaces/*) return 0 ;; esac
  grep -qsE 'GENERATED by nen surface mirror' "$1/SKILL.md" "$1" 2>/dev/null
}
if { [ -e "$dest" ] || [ -L "$dest" ]; } && ! ours "$dest"; then kept="$kept $name"; continue; fi

exclude="$(git -C "$target" rev-parse --git-path info/exclude)"   # NEVER "$(rev-parse --git-dir)/info/exclude"
for line in '.agents/skills/' 'AGENTS.override.md' '.cursor/skills/' '.cursor/agents/'; do
  grep -qxF "$line" "$exclude" 2>/dev/null || printf '%s\n' "$line" >> "$exclude"
done
git -C "$target" status --porcelain      # must print nothing for these paths
```

`--git-path`, never `--git-dir`: in a linked worktree the latter names a file git never reads for
excludes, and the exclude file is per repository, shared by every worktree, so the report names it by
path. **Never write a target repository's `.gitignore`**: it is tracked, lands in their diff and their
history, and imposes this plugin's layout on every contributor. `.nen/` is never a mirror destination:
proof files, En ledgers, the stop marker and Hanten's cycle ledger live there and must survive a warm-up.

**The bell where no hook is installed.** Every surface documents a stop hook (see each guide's *Hooks*),
so the in-session fallback in `jutaisho` runs only on a session whose hook file was not placed. There
the skill fires rungs 2 and 3 itself and says so, sanitising every value exactly as
[`hooks/stop-bell.sh`](../../hooks/stop-bell.sh) does: strip `"`, `\` and newlines from title and body,
pass each as one argument, reduce the sound name to `[A-Za-z0-9_-]` with `Glass` as the fallback, and
drop a value that cannot be sanitised rather than ring with it. Read stderr, not the exit code:
`osascript` exits 0 with nothing delivered where the session has no Notification Center seat, and
`afplay` exits 1 with `AudioQueueStart failed`; either is reported `not applicable, no seat`, by rung.
Never retry, never substitute another noise-maker, and an unfired rung is never rendered as fired. On a
hookless surface the skill also removes `.nen/last-stop.json` once the stop is answered; on a surface
whose hook consumed the marker it does not.

**Keeping the plugin checkout current.** `scripts/hatsu_plugin_update.sh --root "$HATSU_PLUGIN_ROOT"`
with `--channel trunk` (ff-only on the base), `--channel release` (newest `vX.Y.Z` tag) or `--auto` (the
warm-up form: skip on a dirty tree, an authoring branch, a missing `origin`, a diverged trunk, or a fetch
failure, and say so). `--auto --claude` on Claude Code refreshes the versioned cache through
`claude plugin update hatsu@hatsu -y` instead of treating it as a checkout. It never discards, never
force-updates and never touches an authoring branch. Fixture:
`scripts/hatsu_plugin_update_fixture_check.sh`.

## How the set evolves

`hatsu:great-hiker` owns these guides. On each pass it re-fetches every URL in every checklist, diffs the
quoted line against the page, and files one Netero-shaped issue per surface whose checklist moved:
observable acceptance criteria, the row and the new line, and the machinery the change reaches
(generator rows, warm-up, permission pack). It never edits `surfaces/` by hand and never adds a row it
did not fetch.
