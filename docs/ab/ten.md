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

## 2026-09-28 — the tree is named, never trusted by itself (zheref/hatsu#67)

Cursor bound `/mukai` from `~/.claude/plugins/cache/hatsu/hatsu/0.14.0/…` while the checkout in front of
it authored 0.25–0.30 (HA-PR-#64). The first cut of this effort let a newer checkout *replace* the
resolved candidate; hanten withdrew it (Feitan, SEC-14: a directory naming itself `hatsu` at 999.0.0
became the plugin root by being `cd`'d into, and ten § 4b then ran its scripts — reproduced with a
synthetic tree). `scripts/hatsu_root.sh` now keeps the candidate and names the tree. Live from this
checkout (0.53.0) with the installed 0.49.0 cache handed:

```text
$ scripts/hatsu_root.sh /Users/zheref/.claude/plugins/cache/hatsu/hatsu/0.49.0
hatsu_root.sh: the checkout in front of you (<this checkout>, version 0.53.0) is newer than the root the handed path resolved (/Users/zheref/.claude/plugins/cache/hatsu/hatsu/0.49.0, version 0.49.0) — the bound pin stays: this session's skill bodies came from it; read <this checkout>/claude/skills/<name>/SKILL.md for the tree's protocol, and export HATSU_PLUGIN_ROOT='<this checkout>' binds the tree from the next session (not on Claude Code, whose bodies are the installed pin's) (zheref/hatsu#67)
/Users/zheref/.claude/plugins/cache/hatsu/hatsu/0.49.0
exit=0
```

The fixture (`scripts/hatsu_root_fixture_check.sh`, lane `root-guard`) covers the named newer checkout
with its deferral and quoted export, a handed skill directory's walk line, a stale `$CLAUDE_PLUGIN_ROOT`,
an explicit export given as the root and as a skill directory, a 999.0.0 tree with no candidate (NOT
INSTALLED, named), older and equal, four unorderable versions (`1.0.0-rc.1`, `0.53`, `1`, a twenty-digit
field) with no shell noise, a path carrying a space and `;`, a newline-bearing toplevel beside a Hatsu
sibling, git absent from PATH, and a plain repository; every case runs from a neutral directory under
`/tmp` with git's ambient environment cleared (the first run without that failed exactly so: `root
resolved to '<this checkout>'`). **The line exists from the first installed pin whose resolver carries
it**: ten § 0 runs the bound pin's own `hatsu_root.sh`, so a 0.49.0 or 0.14.0 pin says nothing and
`export HATSU_PLUGIN_ROOT='<checkout>'` is the only form there (three reviewers, 3/3 through § 0 as
shipped). On Claude Code the bodies are always the installed pin's; on Cursor whether `.cursor/skills/`
outranks the cache is unverified.

## 2026-09-30 — installed is not reachable (zheref/hatsu#164)

The issue's own shape reproduced in the sitting that took it. Plugin 0.59.0 bound (this checkout at
0.67.0 named, not bound); the harness shell is non-interactive, so nothing in `~/.zshrc` applies to it:

```text
$ nen --version                                   # § 1, the agent's shell
(eval):6: command not found: nen                                                        # exit 127
$ ls -la ~/.local/bin/nen
lrwxr-xr-x  ~/.local/bin/nen -> /Users/zheref/.cache/nen/zheref_nen/v0.15.1/nen-darwin-arm64
$ "$SHELL" -lic 'command -v nen && nen --version'   # § 2c, the maintainer's login shell
/Users/zheref/.local/bin/nen
0.15.1                                                                                  # exit 0
```

Installed at the previous pin and reachable at it, invisible to the agent — the inverse of the
report that raised the issue, and the same two facts. Then the target's contract (`nen >= 0.16`,
pinned `v0.16.0`) read the host's build as older than the pin:

```text
$ nen shu tools --repo .                          # after PATH="$HOME/.local/bin:$PATH", session only
  WRONG    nen     0.15.1   pinned >=0.16.0 <0.17.0
                   verify-only: install by hand -- the bootstrap this repository pins installs v0.16.0. …
$ nen bootstrap --ref v0.16.0 --source zheref/nen --script "$d/nen-bootstrap.sh"          # § 2b
nen bootstrap: cache hit for zheref/nen@v0.16.0 (nen-darwin-arm64), checksum verified.
/Users/zheref/.cache/nen/zheref_nen/v0.16.0/nen-darwin-arm64                            # exit 0
$ nen shu tools --repo .                          # on (b), the session binding
  ok       nen     0.16.0   pinned >=0.16.0 <0.17.0
$ "$SHELL" -lic 'command -v nen && nen --version'
/Users/zheref/.local/bin/nen
0.15.1                                                                                  # a version other than the pin's
```

So the § 4 line for this sitting reads `Nen 0.16.0 · floor 0.7 · satisfies >=0.16.0 <0.17.0 · host:
installed, not reachable (~/.local/bin/nen → 0.15.1, pin v0.16.0) · bootstrapped to v0.16.0 (checksum
verified)`, and § 2c's offer is one `ln -sfn /Users/zheref/.cache/nen/zheref_nen/v0.16.0/nen-darwin-arm64
~/.local/bin/nen` — the shell line already there (`~/.zshrc` exports `~/.local/bin`, the reference
shape the issue recorded) is not touched. The offer was stated and not taken in this sitting: `(a)`
stays the maintainer's word (row `host-nen-link`), and the turn ran on `(b)`.

**Why the link and not the directory.** `~/.cache/nen/zheref_nen/v0.16.0/` holds one file,
`nen-darwin-arm64`; a `PATH` entry naming that directory resolves no `nen` and fails at the point of
use, silently, which is the trap the issue names. A name-correct link on a directory the login shell
already searches is repointed on a bump and the shell line never changes again.

**Residue.** The login-shell probe is harness shell — no nen verb reads a host's `PATH`, and none binds
a name on a host (`PROCESS.md` § Residue, ten). The verdict distinguishes installed from reachable in
the report line; `nen shu tools` keeps answering only what the shell it runs in resolves.

**After the pre-PR review (2026-09-30, hanten on `4b8d4668`).** Chrollo and Nobunaga showed § 1's `ok`
row reaches § 2c with no bootstrap, so the offer's `$verified` was undefined exactly on this host's
state — § 2c now names the operand for both routes (after § 2, `$verified`; on `ok`, the real path of
the binary § 1 ran, under the bootstrap cache). Both showed two version rules in one skill — § 1's
contract range against § 2c's exact-pin compare — so the probe now runs `nen shu tools` in the login
shell and reads its `nen` row: `ok` is reachable, anything else is `installed, not reachable (<row>)`.
Chrollo showed the fall-through: an unset or non-POSIX `$SHELL`, a non-zero exit with no path, and
win32 each landed on "nothing" and would have triggered the offer; a third reading, `not read (<rc>,
<first stderr line>)`, now covers them with no offer, and the probe reads `</dev/null` so a prompting
rc file cannot block it. § 4 says what replaces `warm-up clear` (`warm-up: unmet — host: …`), and a
taken option A asks the probe again. Option A gained `mkdir -p ~/.local/bin`, the `PATH` read and the
rc file it would append to. Phinks proved 3/3 that a `## Unreleased` heading beside a 0.69.0 bump
refuses at `scripts/release-publish.sh --dry-run`; the section is `## v0.69.0 — …` now. mugetsu § 7's
`host nen:` token is `session nen:` so `host` means the login shell in every skill.
