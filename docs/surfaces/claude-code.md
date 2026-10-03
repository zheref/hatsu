# Claude Code

Claude Code is the surface Hatsu is authored for. Nothing is generated for it: the plugin under
`claude/` is the canonical copy, read in place from the maintainer's own checkout (§ 1), and Codex reads
the same skills through its own plugin install. This guide records what the
harness documents about the files that copy consists of, so that a change to a frontmatter key, a hook
event or a permission rule is made against a quoted line and not a memory.

## 1. Identity and paths

| | |
|---|---|
| how Hatsu arrives | **in place**: `~/.claude/skills/hatsu` is a link to the maintainer's checkout, loaded as `hatsu@skills-dir` with nothing copied (`scripts/hatsu_surface_link.sh --surface claude-code`, § 9). The marketplace route, `claude plugin install hatsu@hatsu` after `claude plugin marketplace add <path or repo>`, copies the tree into `~/.claude/plugins/cache/hatsu/hatsu/<version>/` even from a local directory, and an installed `hatsu@hatsu` shadows the link: it is the legacy form `hatsu:bakuryuha` § 3 migrates |
| manifest | `.claude-plugin/plugin.json` (`skills`, `agents`, `commands`, `hooks` by convention) |
| skills read from | `$CLAUDE_PLUGIN_ROOT/claude/skills/<name>/SKILL.md` (`plugin.json` → `"skills": "./claude/skills/"`); with the link, `$CLAUDE_PLUGIN_ROOT` is `~/.claude/skills/hatsu` and the file is the checkout's own |
| personas read from | `claude/agents/<persona>.md`, listed one by one under `plugin.json` → `agents` |
| hooks read from | `hooks/hooks.json` at the plugin root, active while the plugin is enabled |
| permissions | `.claude/settings.local.json` in the target checkout (the pack), never a plugin file |
| invocation spelling | `hatsu:<name>` |
| worktrees | the harness's own: "By default, the worktree is created under `.claude/worktrees/<name>/` at your repository root, on a new branch named `worktree-<name>`" (https://code.claude.com/docs/en/worktrees, 2026-09-30) — `--worktree`, Agent `isolation: "worktree"`, background sessions; git-ignored, **the one harness-native exception**. A `WorktreeCreate` hook may relocate it only outside any repository, and no `worktree.*` setting sets a location. **Hatsu-made**: `git worktree add .nen/worktrees/claude-code/<name>`, then `EnterWorktree` by `path` (one approval prompt for a path outside `.claude/worktrees/`) — `docs/WORKFLOW.md` § *Where worktrees live* |
| headless command | `claude -p "<prompt>"` in the target checkout with the plugin enabled |
| pointing at a local checkout | the link above is the local checkout: `"$HATSU_PLUGIN_ROOT/scripts/hatsu_surface_link.sh" --surface claude-code --root "$HATSU_PLUGIN_ROOT"`. A new commit there is served at the next `/reload-plugins` or session, with no version bump and no `claude plugin update`; `claude plugin list --json` shows `hatsu@skills-dir` and the link as `installPath` |
| update and activation | `hatsu:bakuryuha`: § 3 retargets a cache install onto the link, § 4 fast-forwards the linked checkout (`hatsu_plugin_update.sh --claude`), the new `ten` runs from disk, and `installPath` is read back; the switch is `/reload-plugins` **typed by the human** or the next session, never an app restart (§ 9) |

**Whatever the linked checkout holds is what Claude Code serves**, at the next reload or session: a
feature branch, a swap `hatsu:amenotejikara` made in core, uncommitted edits. So the checkout stays on its
trunk, and the updater never moves an authoring branch; it says which branch is served instead. There is
no mirror to drift-check on this surface (zheref/hatsu#106): `ten` § 5 runs the installed-copy check
(§ 8) and places the permission pack. `ten` § 4b runs `scripts/hatsu_plugin_update.sh --auto --claude`,
which fast-forwards the linked checkout, never runs `claude plugin update` for it, and names a shadowing
`hatsu@hatsu`; on a host still on the cache it keeps the #118 path, the marketplace source first. An
update reaches the running session only through `/reload-plugins`, which the human types, or a new
session; until then `hatsu:bakuryuha` § 6 follows the new skill bodies from the checkout, and hooks and
personas stay the loaded version's (§ 9).

## 2. Skills

| | |
|---|---|
| file | `<plugin>/skills/<skill-name>/SKILL.md`, read wherever the plugin is enabled |
| frontmatter documented | `name`, `description`, `when_to_use`, `disable-model-invocation`, `user-invocable`, `allowed-tools`, `disallowed-tools`, `model`, `effort`, `context`, `agent`, `background`, `argument-hint`, `arguments`, `paths`, `shell`, `hooks`, `metadata`, `license`, `compatibility` |
| required | none; `description` is recommended |
| description budget | 1,536 characters for `description` and `when_to_use` combined |
| name listed as | `hatsu:<name>`, namespaced by the plugin manifest |

Hatsu keeps every documented key on the source; the mirrors reduce to what each other surface documents.
The 1,536-character ceiling is the one hard number any surface states for a description, and it is the
reason Hatsu's authoring rule leads with what the skill does, then its trigger, then its never-clauses.

## 3. Personas and model config

| | |
|---|---|
| file | `claude/agents/<persona>.md`, one per persona; `_review-preamble.md` is the shared reviewer protocol and not a persona |
| frontmatter documented | `name`, `description` (required); `tools`, `disallowedTools`, `model`, `permissionMode`, `maxTurns`, `skills`, `mcpServers`, `hooks`, `memory`, `background`, `omitClaudeMd`, `effort`, `isolation`, `color`, `initialPrompt`, `experimental` |
| model values | `sonnet`, `opus`, `haiku`, `fable`, a full model ID, or `inherit` |
| ignored on a plugin subagent | `hooks`, `mcpServers`, `permissionMode` |
| precedence | the plugin's `agents/` directory is the lowest of five sources, so a same-named project agent wins |
| tier aliases (`nen/workflow.json` → `models.claude`) | frontier `fable`, deep `opus`, fast `sonnet`, economy `haiku` |

A persona's `model` is a tier alias resolved from the matrix, never a versioned id: `models.rule` says
"latest alias only, never a version".

## 4. Hooks

| | |
|---|---|
| file | `hooks/hooks.json` (plugin); `.claude/settings.json` (project, committable) |
| events | 33, including `SessionStart`, `PreToolUse`, `PostToolUse`, `Stop`, `SubagentStop`, `SessionEnd`, `UserPromptSubmit`, `PreCompact`, `Notification`, `PermissionRequest`, `WorktreeCreate`, `Setup`, `ConfigChange`, `Elicitation` |
| `PreToolUse` decision | `hookSpecificOutput.permissionDecision`: `allow`, `deny`, `ask` or `defer`, with `permissionDecisionReason` |
| what Hatsu installs | `SessionStart` → `hooks/session-start.sh` (first the nen binding — `scripts/nen_global.sh --root <hatsu_root>`, fail-open, its summary line appended to the additional context — then the warm-up reminder; on a mirrored surface the mirror refresh); `Stop` → `hooks/stop-bell.sh` (rungs 2 and 3 off `.nen/last-stop.json`); `PreToolUse` on `Bash` → `hooks/guard-base-branch.sh` (refuses `git commit` and `git push` on the base branch) |
| session start | the pinned `nen` bound on the host — `~/.local/bin/nen` linked to the checksum-verified pin (a non-symlink there is refused, exit 3) and a marked `# >>> hatsu nen-global >>>` PATH block in the shell rc when the bin dir is not on `PATH`; `HATSU_NEN_GLOBAL=0` opts out (ruling 2026-09-30). The plugin itself is read in place, so there is nothing to refresh |

Both scripts are POSIX sh, use no jq, yq or python, and fail open except the guard, which fails closed
on the five forms where the branch it can see is not the branch the write would land on. The permission
pack is placed by the warm-up, an install-time step, never by a hook: a hook is plugin-global and fires
in every repository.

## 5. Permissions

| | |
|---|---|
| file | `.claude/settings.local.json` at the root of the git repository (where an interactive "always allow" is saved too) |
| syntax | `"allow": [ "Bash(npm run *)", "Bash(git commit *)" ]`; `Bash(ls:*)` and `Bash(ls *)` match the same commands |
| scope | exe-and-argument patterns; no root syntax. The scope is that the file lives in this checkout's `.claude/` |
| can a plugin ship them | no: a plugin's `settings.json` supports only the `agent` and `subagentStatusLine` keys |
| when they apply | after each teammate trusts the folder |
| what the pack renders | `contracts/permissions.json` → `allow` and `deny` rows as `Bash(<exe> <args>)`, merged into `settings.local.json`, never the tracked `settings.json` |

## 6. Rules

Claude Code reads `CLAUDE.md` and the plugin's own files; Hatsu writes no rules file on this surface.
A persona can opt out of `CLAUDE.md` with `omitClaudeMd`; Hatsu's do not.

## 7. The option picker

`AskUserQuestion`, the harness's own tool, is what `jutaisho` asks a gate question through: lettered
options, a star on the recommended one, several tickable when several can be true. The tool is what the
session exposes; no official page for it was fetched on 2026-09-20, so it stands as an observed fact
rather than a checklist row (see *Known gaps*).

## 8. Generation

Nothing is generated for this surface, and no mirror is drift-checked on it (zheref/hatsu#106): the
canonical copy is `claude/skills/**` and `claude/agents/**`, and the three mirrors are generated from it
(see the other guides). `nen surface mirror check --surface claude-code --installed <cache>` diffs a
target `.claude/` layout Hatsu never places and reads every skill `missing` against the cache (measured
in `docs/ab/ten.md`), so `scripts/surface_mirror_check.sh --installed` refuses and names the check that
replaced it.

**The installed-copy check** (zheref/hatsu#122) is
[`scripts/plugin_cache_check.sh`](../../scripts/plugin_cache_check.sh) `[--installed <path>] [--root
<checkout>]`. It compares what Claude Code serves against the source root `ten` § 0 resolves
(`scripts/hatsu_root.sh`, handed the script's own plugin root, so a § 5 call that never exported
`$hatsu_root` still resolves one). It compares the **whole tree** minus a top-level ignore list —
`.git`, `.nen`, `Reports`, `.claude`, `.cursor`, `.codex`, `.agents`, `.gemini`, `surfaces`,
`node_modules`, `.in_use` (Claude Code's `.in_use/<pid>` marker in the version it serves),
`.orphaned_at`, and `.DS_Store` files — so the scripts a hook executes from the plugin root, the
`nen/contract.json` pin, `claude/commands` and `claude/rules` are in it, and a directory the plugin
starts loading cannot fall outside it. Per path it compares the type first (two links by their link
strings; a FIFO or device is never opened), then the executable bit for this user, then the bytes; a
difference on a path the source checkout does not track is said as `(untracked in source)`; nothing
is written. A source root that is a copy — under `*/plugins/cache/*` or the plugins root, or the same
directory as any recorded `installPath` or as an `--installed` path under a plugins root — is
refused.

**Which copy it reads**, in the loading page's name-conflict order
([plugins/loading](https://code.claude.com/docs/en/plugins/loading) § *Name conflicts*), without
`--installed`:

1. a Hatsu tree named by `CLAUDE_CODE_PLUGIN_DIRS` (`:`-separated, absolute or `~` paths), which loads
   in place ahead of every installed or skills-directory copy; it is judged like a link. The
   `--plugin-dir` **flag** is out of scope — a flag on the parent's command line is invisible to a
   child process — and so is a managed-settings lock;
2. a `hatsu@<any marketplace>` entry in `installed_plugins.json` under the plugins root
   (`${CLAUDE_CODE_PLUGIN_CACHE_DIR:-~/.claude/plugins}`,
   [env-vars](https://code.claude.com/docs/en/env-vars)): the most specific scope that applies wins —
   `local`, then `project`, each only when its `projectPath` is this checkout (its git toplevel, or
   the main checkout of a linked worktree), then `user`, `managed` (an organisation-pinned install,
   placed like `user`) or no scope. Two at that scope are refused as ambiguous; a project or local
   entry for another project is passed over; one with no `projectPath`, or at a scope the check does
   not know, is refused and named; an empty array is "not installed";
3. else `~/.claude/skills/hatsu`.

The registry is read in the one two-space-indented v2 shape Claude Code writes. A registry that
cannot be read, is not a regular file, or mentions `"hatsu@` in any other shape, and a chosen
`installPath` that does not resolve, are refused rather than read as "not installed", which would
report the link while a stale copy shadows it. **Shadowing predicate:** the loading page orders
*enabled* plugins, and `hatsu:bakuryuha` § 2 reads the serving row of `claude plugin list --json`;
this check reads the install record, so an installed-but-disabled copy is still checked (a stale
alarm for a copy that may not be served, never a miss). Reading `enabled` would mean spawning the CLI
inside a hermetic check; settling the one predicate is owed, unfiled.

| Exit | Last line | Means |
|---|---|---|
| `0` | `plugin-cache: linked (identical by construction)` | what is served resolves to the source checkout itself (the skills-directory link, § 1, or a plugin dir): nothing is copied, nothing can be stale |
| `0` | `plugin-cache: current` | a copy, identical to the source |
| `1` | `plugin-cache: stale (<n> paths)` | each path named `differs:` (with `(type)`, `(link)` or `(mode)` where that is the difference), `missing:` or `extra:`; a same-version copy with different bytes (#118's class) is said as one, extra files only and untracked-only differences as what they are |
| `1` | `plugin-cache: linked to <target> (not <root>)` | the link serves ANOTHER checkout's branch, not the root this session resolved; repoint it with `hatsu:bakuryuha`, or bind that checkout with `export HATSU_PLUGIN_ROOT` |
| `1` | `plugin-cache: plugin-dir <target> (not <root>)` | `CLAUDE_CODE_PLUGIN_DIRS` serves another Hatsu tree in place, ahead of every copy |
| `2` | no `plugin-cache:` line; the reason is on stderr | a wiring defect: no source root, a source root that is a copy, no install found, an unreadable or non-file registry, an unknown scope, a project entry with no path, an ambiguous or dangling entry, a path that is not an installed Hatsu (a cache's parent directory is answered with the versions it holds), a path carrying a control byte, an unreadable directory — and any unexpected failure, so a crash never reads as `stale` |

`ten` § 5 quotes the last line, or `plugin-cache: not checked (<reason>)` on exit `2`
([`PROCESS.md`](../PROCESS.md) § *`ten` § 5's rules*). `bash scripts/plugin_cache_check.sh --self-test`
is its hermetic fixture (the `plugin-cache-guard` lane). A stale copy is refreshed by `hatsu:bakuryuha`
(§ 1), or on a host that keeps the cache by `ten` § 4b's `hatsu_plugin_update.sh --auto --claude`.
There is no marker on this surface because there is no generated file.

## 9. Dated checklist

| fact | value | quoted line | source | fetched |
|---|---|---|---|---|
| plugin hooks file | `hooks/hooks.json` | "Plugin `hooks/hooks.json` \| When plugin is enabled" | https://code.claude.com/docs/en/hooks | 2026-09-20 |
| project hooks file | `.claude/settings.json` | "`.claude/settings.json` \| Single project \| Yes, can be committed to the repo" | https://code.claude.com/docs/en/hooks | 2026-09-20 |
| hook events | 33, `SessionStart`, `PreToolUse`, `Stop`, `SessionEnd` among them | (event table on the page; 33 rows counted on fetch) | https://code.claude.com/docs/en/hooks | 2026-09-20 |
| PreToolUse decision key | `hookSpecificOutput.permissionDecision` | "`permissionDecision` (allow/deny/ask/defer), `permissionDecisionReason`" | https://code.claude.com/docs/en/hooks | 2026-09-20 |
| deny and ask semantics | deny blocks, ask prompts | "`\"deny\"` prevents the tool call. `\"ask\"` prompts the user to confirm." | https://code.claude.com/docs/en/hooks | 2026-09-20 |
| allow syntax | `Bash(<exe> <args>)` | "`\"allow\": [ \"Bash(npm run *)\", \"Bash(git commit *)\" ]`" | https://code.claude.com/docs/en/permissions | 2026-09-20 |
| where an interactive allow is saved | `.claude/settings.local.json` | "saves the rule to `.claude/settings.local.json` at the root of the git repository" | https://code.claude.com/docs/en/permissions | 2026-09-20 |
| colon and space forms | equivalent | "`Bash(ls:*)` matches the same commands as `Bash(ls *)`" | https://code.claude.com/docs/en/permissions | 2026-09-20 |
| plugin can ship permissions | no | "Only the `agent` and `subagentStatusLine` keys are supported" | https://code.claude.com/docs/en/plugins-reference | 2026-09-20 |
| when allow rules apply | after trust | "`permissions.allow` rules … apply only after each teammate trusts the folder" | https://code.claude.com/docs/en/settings | 2026-09-20 |
| subagent required keys | `name`, `description` | (frontmatter table: both marked required) | https://code.claude.com/docs/en/sub-agents | 2026-09-20 |
| subagent model values | `sonnet`, `opus`, `haiku`, `fable`, id, `inherit` | "`model` … `sonnet`, `opus`, `haiku`, `fable`, a full model ID … or `inherit`" | https://code.claude.com/docs/en/sub-agents | 2026-09-20 |
| plugin agents precedence | lowest | "Plugin's `agents/` directory \| Where plugin is enabled \| 5 (lowest)" | https://code.claude.com/docs/en/sub-agents | 2026-09-20 |
| keys ignored on plugin subagents | `hooks`, `mcpServers`, `permissionMode` | "Ignored for plugin subagents" | https://code.claude.com/docs/en/sub-agents | 2026-09-20 |
| skill required keys | none | "All fields are optional; only `description` is recommended" | https://code.claude.com/docs/en/skills | 2026-09-20 |
| description budget | 1,536 chars with `when_to_use` | "Max 1,536 characters combined with `when_to_use`" | https://code.claude.com/docs/en/skills | 2026-09-20 |
| plugin skill path | `<plugin>/skills/<skill-name>/SKILL.md` | "Plugin \| `<plugin>/skills/<skill-name>/SKILL.md` \| Wherever plugin enabled" | https://code.claude.com/docs/en/skills | 2026-09-20 |
| manifest path | `.claude-plugin/plugin.json` | "Manifest \| `.claude-plugin/plugin.json` \| Plugin metadata and configuration (optional)" | https://code.claude.com/docs/en/plugins-reference | 2026-09-20 |
| manifest keys | `name`, `displayName`, `version`, `description`, `author`, `homepage`, `repository`, `license`, `keywords`, `metadata`, `skills`, `commands`, `agents`, `hooks`, `mcpServers`, `outputStyles`, `lspServers`, `experimental`, `dependencies` | (manifest schema on the page) | https://code.claude.com/docs/en/plugins-reference | 2026-09-20 |
| plugin layout hooks row | `hooks/hooks.json` | "Hooks \| `hooks/hooks.json` \| Hook configuration" | https://code.claude.com/docs/en/plugins-reference | 2026-09-20 |
| when an update applies | next session, or `/reload-plugins` | "Update a plugin to the latest version its marketplace offers. The new version loads in your next session, or after you run `/reload-plugins` in a running one." | https://code.claude.com/docs/en/plugins/cli-reference | 2026-09-29 |
| the running session's layer | loaded at start or last reload | "Changes to settings or to disk don't reach this layer until you run `/reload-plugins` or start a new session." | https://code.claude.com/docs/en/plugins/loading | 2026-09-29 |
| what `/reload-plugins` switches | skills, agents, hooks, plugin MCP and LSP servers | "Claude Code reloads every active plugin and prints one summary line, `Reloaded: N plugins · N skills · N agents · N hooks · N plugin MCP servers · N plugin LSP servers`" | https://code.claude.com/docs/en/plugins/cli-reference | 2026-09-29 |
| `/reload-plugins` in the desktop app | from v2.1.260; MCP servers wait | "`/reload-plugins` also runs in sessions without an interactive terminal, such as the desktop app, the Agent SDK, and non-interactive mode with `-p`. Requires Claude Code v2.1.260 or later." · "The reload in those sessions doesn't connect or disconnect plugin MCP servers." | https://code.claude.com/docs/en/plugins/cli-reference | 2026-09-29 |
| who can run `/reload-plugins` | the human, typed | "the command runs only when you type it into the session yourself, such as in the `-p` prompt or the desktop app's prompt box" | https://code.claude.com/docs/en/plugins/cli-reference | 2026-09-29 |
| hooks after a mid-session update | the previous path, until reload | "When a copied plugin updates mid-session, hook commands, monitors, MCP servers, and LSP servers keep using the previous version's path." | https://code.claude.com/docs/en/plugins/loading | 2026-09-29 |
| plugin skills watched live | no; skill directories only | "When you add, edit, or remove a skill under `~/.claude/skills/`, the project `.claude/skills/`, or a `.claude/skills/` inside an `--add-dir` directory, Claude Code picks up the change within the current session, without a restart." | https://code.claude.com/docs/en/skills | 2026-09-29 |
| local-directory marketplace plugin | loads in place (documented; **not observed** for Hatsu's shape, evidence § 10 F1) | "the plugin loads in place from its path inside the marketplace folder. Your edits to the source directory take effect at the next session start or `/reload-plugins`, and you don't need to increase the version." | https://code.claude.com/docs/en/plugins/loading | 2026-09-29 |
| version read-back | `claude plugin list --json` → `version`, `installPath` | "`id`, `version`, `scope`, `enabled`, and `installPath` are always present" · "`installPath` \| string \| Directory the plugin loads from" | https://code.claude.com/docs/en/plugins/cli-reference | 2026-09-29 |
| auto-update for a local marketplace | off by default | "**Off by default**: every other marketplace, including the community marketplace, third-party marketplaces, and local development marketplaces." | https://code.claude.com/docs/en/plugins/install | 2026-09-29 |
| cloud sessions | no local plugins | "has no plugin browser and doesn't load the plugins you installed on your own machine or the ones your repository's `.claude/settings.json` turns on" | https://code.claude.com/docs/en/plugins/install | 2026-09-29 |
| skills-directory plugin | loads in place | "`--plugin-dir` and skills-directory plugins: the directory loads in place and is never copied" | https://code.claude.com/docs/en/plugins/loading | 2026-09-29 |
| its id | `hatsu@skills-dir` | "You saved a plugin directory that has a `.claude-plugin/plugin.json` under `~/.claude/skills/` or the project's `.claude/skills/`" | https://code.claude.com/docs/en/plugins/loading | 2026-09-29 |
| precedence | an installed marketplace plugin wins | "An installed marketplace plugin. A skills-directory plugin of the same name gets the same `Not loaded` row, naming the installed plugin" | https://code.claude.com/docs/en/plugins/loading | 2026-09-29 |
| a link under `skills/` | accepted, loads in place (live, not a page) | `hatsu@skills-dir` · `Status: ✔ loaded` · `installPath` = the link; the cache route copies — evidence § 10 F1–F3 | [evidence § 10](evidence/surfaces.md) | 2026-09-29 |
| a declared marketplace | re-cloned, enabled plugins re-downloaded | "**A marketplace that settings declare but `known_marketplaces.json` lacks**: Claude Code clones it, then reloads plugins and downloads enabled plugins that aren't cached yet" — observed reinstalling `hatsu@hatsu` over the link on the maintainer's host (evidence § 10 F9) | https://code.claude.com/docs/en/plugins/loading | 2026-09-29 |

## 10. Known gaps (not documented)

- A skill `name` length limit. No page states one; Hatsu's longest is `spiritual-message`.
- A page for `AskUserQuestion`. The tool is observed in the session's tool set; no URL was fetched.
- Whether the 1,536-character budget is enforced by truncation or by refusal to load.
- Why the loading page's in-place claim for a local-directory marketplace does not hold for Hatsu's
  shape (`"source": "./"`, a pinned `version`): observed copying on 2.1.284 (evidence § 10 F1). Hatsu
  does not depend on it; the skills-directory link is the install.
- A `hatsu` marketplace or `hatsu@hatsu` enable declared in a **project** or **managed** settings scope: the handover clears the user scope only, and such a declaration could bring a shadowing copy back after the name is freed (Feitan's note, 2026-09-29); Claude Code's own trust prompt stands in front of a project declaration.
- Whether live `SKILL.md` change detection ("picks up the change within the current session") reaches a
  skills-directory plugin's nested `claude/skills/` bodies, and what watching a linked checkout that holds
  worktrees (`.claude/worktrees/`, the harness's own; `.nen/worktrees/claude-code/`, Hatsu's — § 1) costs. Not claimed: `hatsu:bakuryuha` names `/reload-plugins` or a new session.

## 11. How this guide evolves

`hatsu:great-hiker` re-fetches the nine URLs above on each pass, diffs every quoted line, and files one
Netero-shaped issue for this surface when a line moved: which row, the old line, the new line, and what
in `claude/`, `hooks/hooks.json` or `scripts/permissions_pack.sh` the change reaches. A key this surface
stops documenting is removed from the source frontmatter in that issue's PR, never silently.
