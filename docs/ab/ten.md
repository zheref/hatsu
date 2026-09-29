# A/B — `hatsu:ten`

Evidence for the warm-up under its current name (the transcripts before the rename of 2026-09-28 stay
in [`hatsu-warmup.md`](hatsu-warmup.md)). The contract ([`nen/contract.json`](../../nen/contract.json))
stays the single source of truth for the pin; this file records what was observed on an installed
surface.

## 2026-09-28 — § 0 runs as written on an installed surface (zheref/hatsu#105)

Plugin 0.49.0 installed at `~/.claude/plugins/cache/hatsu/hatsu/0.49.0`; Claude Code prints the skill's
base directory as `<root>/claude/skills/ten`, which holds only `SKILL.md`. The old § 0 line failed there
twice — `no such file or directory` at `$base_dir/scripts/hatsu_root.sh`, then `NOT INSTALLED` when the
root's script was handed the skill directory — and the session recovered only by already knowing the
layout. `scripts/hatsu_root.sh` now walks a handed candidate up at most four levels, checking every
level for what it is, and names the walk on stderr; § 0's block is
`root="${HATSU_PLUGIN_ROOT:-$base_dir/../../..}"` then `"$root/scripts/hatsu_root.sh" "$base_dir"`.

```text
$ scripts/hatsu_root.sh "$cache/claude/skills/ten"
hatsu_root.sh: resolved by walking up from …/0.49.0/claude/skills/ten → …/0.49.0.
/Users/zheref/.claude/plugins/cache/hatsu/hatsu/0.49.0                                  # exit 0

$ scripts/hatsu_root.sh --quoted "$cache/claude/skills/ten"                             # exit 0, three lines
$ scripts/hatsu_root.sh "$cache"                                                        # exit 0, no walk
$ scripts/hatsu_root.sh "<checkout>/surfaces/cursor/ten"                                # exit 0 — a flat mirror, three levels
$ scripts/hatsu_root.sh "<checkout>/surfaces/antigravity/skills/ten"                    # exit 0 — the nested mirror, four levels
$ scripts/hatsu_root.sh "$(mktemp -d)/a/b/c/e/f"                                        # exit 1 — NOT INSTALLED, rejected at depth 0 (no Hatsu root within four levels)
$ scripts/hatsu_root.sh "$cache/claude/skills/ten/x/y"                                  # exit 1 — five levels is too many
```

The `NOT INSTALLED` stop still fires when Hatsu genuinely is not installed; nothing is accepted by shape.

## 2026-09-28 — § 5 has no mirror to check on Claude Code (zheref/hatsu#106)

nen 0.15.1. The old § 5 snippet refused twice as written (`--source is required`, then `--surface is
required`). With every flag supplied, the verb's `--installed` mode diffs a **full** mirror, so neither
copy Hatsu actually has on a host matches it:

```text
$ nen surface mirror check --source $cache/claude/skills --agents $cache/claude/agents --surface claude-code \
    --installed $cache/claude --permissions … --hooks … --rules … --stamp 0.49.0 --invocation-prefix hatsu:
ok: 57
missing: hooks/hooks.json, settings.local.json                      # nen's claude-code row is a target .claude/ layout
$ scripts/surface_mirror_check.sh --installed $cache                # every skill and persona `missing`: skills/ is not at the cache root
$ nen surface mirror check … --surface codex --installed <target>/.agents/skills
ok: 45
missing: AGENTS.md, agents/*.toml, config.toml, config.toml.fragment, hooks.json, hooks/…   # the warm-up places skills only
$ nen surface mirror check … --surface codex --installed surfaces/codex
ok: 63  missing: (none)  extra: (none)  stale: (none)  hand-edited: (none)                  # a whole mirror: exit 0
```

So § 5 now runs `scripts/surface_mirror_check.sh "$hatsu_root"` (the source against `surfaces/<s>`,
every flag the verb needs; `1` is a stale mirror **in the plugin**, said and regenerated only in a
Hatsu PR), lets `surface_bootstrap.sh --install-all` report the placed copy per name, and on Claude
Code records `mirrors: not applicable` and places the permission pack only. A genuine drift on a
mirroring surface still exits `1` from the same script — a hand-edited `aka/SKILL.md` in the copy above
read `hand-edited: aka/SKILL.md`, exit 1.

**Residue.** `scripts/surface_mirror_check.sh --installed <cache>` compares the versioned cache against a
layout it does not have and reads every file `missing`; it is not what ten runs, and a check that can tell a
stale cache from a fresh one is still owed — zheref/hatsu#122 (its header's #90 citation was the wrong issue).

**After the pre-PR review (2026-09-28).** Feitan showed the walk's answer travelled through a command
substitution, which strips a trailing newline, so a Hatsu-shaped `p<LF>` beside a plain `p` resolved to
`p` — a candidate carrying a newline is now refused before the walk and the canonical path is checked for
identity again; Chrollo and Nobunaga showed § 0's `$base_dir/../../..` is three levels (Claude Code) while
a nested mirror needs four and a stale profile export needs a fallback — § 0 now tries the export, three
levels and four levels for a resolver before running it; Phinks and Nobunaga showed the fixture's
"four-level" case was three deep — the nested antigravity layout is now the four-level case. The walk is
reported on its own stderr line (`resolved by walking up from …`), never under `passed over`.
