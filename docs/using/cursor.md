# Hatsu on Cursor

> **Setup · usage · maintenance** for the Cursor surface (`cursor-agent` and the IDE). The cross-surface
> requirements, the checkout you keep and the update table are in [the hub](README.md); the surface's
> evolution record is [`../surfaces/cursor.md`](../surfaces/cursor.md).

| | |
|---|---|
| **How Hatsu arrives** | a one-time bootstrap in each repository, then the warm-up links every skill and persona into the checkout's generated mirror |
| **Skills read from** | `<repo>/.cursor/skills/<name>/`, one symlink each into `$HATSU_PLUGIN_ROOT/surfaces/cursor/<name>` |
| **Personas** | `<repo>/.cursor/agents/<persona>.md`, one subagent file each, symlinked |
| **You type** | `/<skill>`: `/ten`, `/ren`, `/aka`, `/mukai` |
| **Gate questions** | the surface's own option picker; the bell is the `stop` hook, or `jutaisho`'s in-session fallback |
| **Update** | `/bakuryuha`; the links already point into the checkout, so a fast-forward is most of the update |

---

## 1 · Requirements

- The host: `cursor-agent`, **`2026.01.*` or newer, and this one is a real floor**. The box below says why.
- Signing in: `cursor-agent login`. `cursor-agent status` answers `✓ Logged in as <you>`.
- The shared three (`nen`, `git` + `gh`, a `nen/contract.json`), plus `python3` on the installed plugin
  path: [the hub's *Requirements*](README.md#requirements).
- A checkout, with `HATSU_PLUGIN_ROOT` pointing at it: [the hub's *A checkout you keep*](README.md#a-checkout-you-keep).

> ### ⚠️ Below `2026.01`, `cursor-agent` sees **none** of the skills — and answers anyway
>
> A `cursor-agent` that predates skills support takes your prompt, runs your commands and exits `0` with
> not one of the fifty-one loaded. With the mirror installed exactly as the warm-up mandates,
> `2025.09.18-39624ef` answered a discovery probe with the whole reply **`NO SKILLS VISIBLE`**, seventeen
> bytes — and the control that settles it is that the same build cannot see a plain `cp -R` **copy**
> either: it has no skills mechanism at all, and reached its answer by grepping the working tree.
>
> **The floor is a month, not a build id.** [Cursor's CLI changelog](https://cursor.com/docs/cli/changelog)
> dates *"Skills, rules, and commands in the CLI"* to its **January 2026** entry and groups by month, while
> `cursor-agent -v` prints `YYYY.MM.DD-<sha>` — so there is no exact version string to pin and the
> comparison is the date part. The build every Cursor fact on this page was measured on is
> **`2026.09.08-6caf4ff`**. **The warm-up prints `cursor-agent -v` beside the install count and refuses to
> claim the surface below the minimum**, because an install that succeeded onto a build that cannot read it
> is the exact shape of an unperformed step reported as a passing one.

## 2 · Setup

Check the version **first** — below `2026.01` the install succeeds and the surface sees nothing:

```sh
cursor-agent -v          # 2026.09.08-6caf4ff on the host these records were made on
```

Then, from the repository you want to work in, seed the one skill Cursor must discover first:

```sh
"$HATSU_PLUGIN_ROOT/scripts/surface_bootstrap.sh" --surface cursor --target . --bootstrap
```

It links only `.cursor/skills/ten/`, preserving the same collision, tracked-file and
`info/exclude` safeguards as the full warm-up. Restart or open Cursor in that repository, then invoke:

```
/ten
```

The warm-up refreshes the complete Cursor surface every session:

| | |
|---|---|
| `<repo>/.cursor/skills/<name>/` | one **symlink** per mirrored skill directory — **60**, the fifty-nine plus `ten` itself — pointing at `$HATSU_PLUGIN_ROOT/surfaces/cursor/<name>` |
| `<repo>/.cursor/agents/<persona>.md` | one markdown subagent file each — **18**: every persona — Kurapika, the twelve independents and the four intake examiners — plus the preamble include — symlinked from `$HATSU_PLUGIN_ROOT/surfaces/cursor/agents/` |

**Symlinks are honest here, and that is measured rather than assumed.** Four controlled probes on
`2026.09.08-6caf4ff` found a skill through a symlink **inside** the workspace and through one pointing
**outside** it, and listed a symlink into this plugin checkout under its **bare** name — so Codex's
namespacing behaviour does **not** reproduce on Cursor and the mirrors' `/<name>` spelling works as
printed.

**The first two refusals apply to the local generated Cursor adapter too** — a destination the warm-up
did not make is left alone and named, and your `.gitignore` is never written (`info/exclude`, again).
That adapter generates no `AGENTS.md`; instead, **`.cursor/agents/` is a directory a Cursor user is
*expected* to keep their own subagents in**, which makes it the likeliest collision of all. Cursor Cloud
is different: create a repository `AGENTS.md`, or merge the Cloud bullets below into the file already
there, because Cloud agents read it. Before installing anything the local warm-up **lists every name
already standing under `.cursor/skills/`** and reports what it found by name — and says plainly what
that listing cannot see: **a same-named skill from another plugin elsewhere on the host may shadow the
mirror, and is invisible from inside your repository.**

**First-run check**, from the Hatsu checkout:

```sh
scripts/surface_mirror_check.sh
```

### Cursor Cloud agents

Cursor Cloud agents run on isolated Ubuntu machines and start from a prepared Build. Put the current
contract pin in the Build's disk state with this committed `.cursor/environment.json` (merge its
`install` command with any existing one):

```json
{
  "install": "set -eu; d=\"$(mktemp -d)\"; trap 'rm -rf \"$d\"' EXIT; printf '%s\\n' 'abf2bde0ebc207588bd078acbf861377d4755562514aec26d070aafd1267ba70' | grep -Eq '^[0-9a-f]{64}$'; printf '%s\\n' 'b8004b27620a6ffceacde1703d4844029f675431b27c9681a632092e1a5d5f35' | grep -Eq '^[0-9a-f]{64}$'; curl -fsSL https://raw.githubusercontent.com/zheref/nen/v0.28.0/bootstrap/nen.sh -o \"$d/nen-bootstrap.sh\"; printf '%s  %s\\n' \"abf2bde0ebc207588bd078acbf861377d4755562514aec26d070aafd1267ba70\" \"$d/nen-bootstrap.sh\" | sha256sum -c -; nen_path=\"$(bash \"$d/nen-bootstrap.sh\" --ref v0.28.0 --source zheref/nen)\"; test -x \"$nen_path\"; printf '%s  %s\\n' \"b8004b27620a6ffceacde1703d4844029f675431b27c9681a632092e1a5d5f35\" \"$nen_path\" | sha256sum -c -; mkdir -p \"$HOME/.local/bin\"; if [ -e \"$HOME/.local/bin/nen\" ] && [ ! -L \"$HOME/.local/bin/nen\" ]; then echo 'refusing to replace non-link $HOME/.local/bin/nen' >&2; exit 1; fi; ln -sfn \"$nen_path\" \"$HOME/.local/bin/nen\"; \"$HOME/.local/bin/nen\" --version"
}
```

Those literals are the current `nen/contract.json` values: `zheref/nen@v0.28.0`. Keep the ref, `bootstrap.scriptSha256` and `bootstrap.sha256["linux-x64"]` together
when the contract repins. The Build verifies the downloaded script against the independently reviewed
contract digest before Bash runs, then verifies the binary against the contract before linking or executing it. On Cursor's Linux host, the bootstrap caches the verified binary at
`${XDG_CACHE_HOME:-$HOME/.cache}/nen/zheref_nen/v0.28.0/nen-linux-x64`; the stable link is
`$HOME/.local/bin/nen`. The bootstrap fetches `SHA256SUMS` before the binary, verifies the manifest's
digest, deletes rejected bytes, and prints a path only after verification. The command is idempotent:
an already-valid cache entry is rechecked and reused, while a real file at the link path is refused.

Builds preserve disk state, but Cursor explicitly says exported shell variables do not continue into
an agent run. Create a repository `AGENTS.md` with this section, or merge the bullets into its existing
instructions:

```md
### Cursor Cloud specific instructions

- Run the Hatsu warm-up before any other Nen-owned operation.
- Bind the Build-installed binary on every call: `PATH="$HOME/.local/bin:$PATH" nen ...`.
- Quote the warm-up's one-line probe/bootstrap result in the pull request body, including `not run`.
- If bootstrap fails, stop. Do not substitute raw git, `gh`, or a remembered shell equivalent for a Nen-owned operation.
```

For restricted network mode, allow the exact HTTPS path the bootstrap needs:
`raw.githubusercontent.com` for the pinned script; `github.com`, `api.github.com` (the `gh` path), and
`release-assets.githubusercontent.com` for the release's `SHA256SUMS` and `nen-linux-x64`. GitHub API
and `gh` requests use Cursor's Cloud Agent egress, not its git egress proxy.

Finally, point the saved environment's **Environment JSON location** at this committed file. Cursor's
resolution order is personal saved environment, team saved environment, then the committed file; an
already-saved environment whose location is **None** skips it. Self-Hosted Machines also skip it by
design. A local fixture can prove the JSON and checksum flow, but only an actual Cursor Cloud Build can
prove the saved-environment selection and its network policy.

## 3 · Usage


```
/ten                                     # once per session: links .cursor/skills and .cursor/agents (the links persist), verifies nen and cursor-agent's version
/ren Add a "Clear all" action to the notifications list, with a confirmation sheet
/aka
/mukai
```

Personas are `.cursor/agents/<persona>.md`, and `/ren` runs as Kurapika. Headless:
`cursor-agent -p --output-format text --model "$grok" -f '/ren <request>'` — the full form, with the model
id resolved rather than remembered, is under [Headless, for automation](#headless-for-automation).


**Same loop, same gates, same roster.** What changes is the spelling, how much of a description survives,
whose `build` you get when two plugins claim the name, who rings the bell, and which aliases the matrix
answers with.

**Cursor is Hatsu's coding surface for Grok-based models.** The `EDITOR_FRONTIER` route uses Cursor's
Grok line for local authoring. For a declared CI job that needs a Grok agent, xAI also documents
[Grok Build's headless CLI](https://docs.x.ai/build/cli/headless-scripting) with `grok -p` and
`--no-auto-update`; that job must supply its own authentication, permissions and checks. Grok Build
is not a separate Hatsu interactive surface ([the ruling](../ROSTER.md#rulings-of-2026-10-17--cursor-carries-grok-coding-grok-build-is-a-ci-option)).


### Invoking a skill

**You type `/<name>`** — `/ren`, `/aka`, `/mukai`, `/ten`. **Cursor lists a mirrored skill under
its bare frontmatter `name`, with no plugin namespace** — even through a symlink into this checkout, which
carries a plugin manifest. Codex's namespacing behaviour does not reproduce here, so the `/name` spelling
the mirrors print is the one that works.

### The loop, and the phases only you call

Unchanged: **`/ren` on every request** — `/breath`, `/rasengan`, `/kokusen`, `/amaterasu`, `/spiritual-message`,
`/jutaisho` — never pushing. Yours to call: `/aka`, `/mukai`, the **merge**, `/kagutsuchi` and `/mugetsu`
(**G3**). A **G5** stop is the banner, the report link, the lettered options with a star on the recommended decision (the report linked, never an option; `HATSU_ATTENTION=off` silences rungs 2 and 3 on any host), and
the question asked through this surface's own option picker — the same four parts, and all four or it is
not a stop. As on Codex, **the picker is not the turn-end hook**; the bell is a separate matter, below.

### Personas and reviewers

**Cursor has subagents, so a persona is a file again** — `.cursor/agents/<persona>.md`, one per persona,
placed by the warm-up. `/hanten` classifies the change set by scope and invokes the matching persona as
that surface documents; the reviewer runs at `models.roles.reviewer` = tier `deep`.

> **A persona's `model:` pin does not translate between surfaces, and one of them collides.**
> `nen surface mirror generate` carries `model` through verbatim — correctly, since it mirrors rather than
> translates — so **Hisoka arrives on Cursor carrying `model: sonnet`, a Claude alias in a Cursor-native
> matrix.** The rule is `hanten`'s: **report the pin unresolvable, fall back to the role's tier (`grok`),
> and state the substitution in the title.** Never silently honoured, never silently dropped.

### The bell

**Cursor has a `stop` hook.** Where it is absent, `/jutaisho` uses its in-session fallback: it writes
the marker, rings the rungs **your repository's** `notifications.rungs` declares, says which actually
rang, and removes its marker once the stop is answered. A headless `cursor-agent -p` run has no OS or
sound seat; the stop itself still stands.

### The model matrix

| tier | role | Cursor alias |
|---|---|---|
| `frontier` | `orchestrator` — never a subagent, save [`WORKFLOW.md`](../WORKFLOW.md) § `models`'s one exception | `grok` |
| `deep` | `reviewer` | **`grok`** |
| `fast` | `worker`, `measurer` | `composer` |
| `economy` | | `composer` |

**The Cursor column is Cursor-native only**, and the file says why in its own words:
`"Cursor-native only; provider models there are reserved for Bugbot"`. `cursor-agent models` lists provider
ids too — `claude-opus-5-*`, `gpt-5.6-sol-*`, `gemini-3.7-*` — and `--help`'s own examples *are* provider
models: **the CLI accepts them and this policy does not.** Naming one here is out of policy, not a local
optimisation.

> **`frontier` and `deep` name the same alias on this surface, and the rule survives that.** "Never the
> frontier tier for a subagent" (save [`WORKFLOW.md`](../WORKFLOW.md) § `models`'s one exception) cannot be checked by reading the alias here, so it is enforced on the
> **role**: a reviewer is raised at `models.roles.reviewer`, never as an orchestrator. Say the tier *and*
> the alias — *"tier `deep` → `grok`"* — so a transcript read afterwards is unambiguous.

### Headless, for automation

```sh
# the deep/frontier tier's id AS THE HOST SPELLS IT TODAY — resolved, never remembered
grok="$(cursor-agent models | sed -n 's/^\(cursor-grok-[0-9.]*-high\) - .*$/\1/p' | sort -Vr | head -n 1)"
[ -n "$grok" ] || { echo "cursor-agent models lists no cursor-grok id" >&2; exit 1; }

cd <repo> && cursor-agent -p --output-format text --model "$grok" -f "<prompt>"
```

> **`--model grok` does not exist and nothing runs.** `grok` is the *alias* the policy file carries; the
> command line needs the id the host is serving. `cursor-agent models` prints `<id> - <label>`, one per
> line, and the Cursor-native rows today are `cursor-grok-4.6-{low,medium,high,xhigh}[-fast]`,
> `cursor-grok-4.5-high[-fast]` and `composer-2.5[-fast]`. The id is a **two-axis** choice — version and
> reasoning tier — so the rule is written down rather than left to each caller: **newest version, plain
> `-high`, never `-fast`.** The `sed` / `sort -Vr` above is that rule, executable; it resolves to
> `cursor-grok-4.6-high` on this host today, and `composer` resolves the same way to `composer-2.5`.

- `-p, --print` is the non-interactive form; `--output-format` takes `text`, `json` or `stream-json` and
  **only works with `--print`**.
- **`sort -V` is what picks the newest version, and macOS's own `/usr/bin/sort` has it** — verified on
  macOS `26.4.1`, where `-Vr` orders `cursor-grok-4.6-high` above `cursor-grok-4.5-high`. On a host whose
  `sort` lacks it the substitution comes back empty and the `[ -n "$grok" ]` guard exits `1` rather than
  running on a wrong id: the fail-closed direction, and the reason the guard is written out.
- **`-f` is `--force`, and it is NOT a file flag.** It *"force allow[s] commands unless explicitly
  denied"*; the line above parses only because `-f` takes no value and the prompt is a **positional**
  argument. The Codex block uses no such adjacency, so a reader copying one line is being invited to
  misread it.
- **The working root is the shell's own `cd`**, and that form works on every build. This build's `--help`
  also lists `--workspace <path-or-name>`, `--add-dir <path>` and `-w, --worktree [name]`.
- **There is no sandbox to widen, and that is a difference rather than an absence.** Codex's whole
  `--add-dir` box exists because `-s workspace-write` cannot perform a single git write in a linked
  worktree. Cursor has no counterpart to that failure: a headless run fetched, cut a branch, rebased and
  first-published **inside a linked worktree** with no permission failure of any kind.
- **Answering a G5 stop is `--resume`, a flag on the same command line** — unlike `codex exec resume`, so a
  stop is answered with the same line plus the id. Fix the id up front with `cursor-agent create-chat`,
  which prints one, rather than relying on `--resume`'s "latest". **The path is unexercised**: no G5 fired
  in the recorded run, so `--resume` has never been used in anger.
- **Give a `-p` run a timeout.** Observed once, on the pre-skills build: the process printed its complete
  answer and then stayed alive at 0% CPU twelve minutes later. There is no `-o/--output-last-message`
  equivalent to read a result from, so a caller waiting on process exit rather than on output hangs. Not
  reproduced on `2026.09.08-6caf4ff`, where every run exited `0`.

### What is different on this surface, the honest list

1. **Roughly thirty characters of a description survive, and that is not a shorter Codex.** Asked for the
   length of one, a session answered *"The description text is 30 characters long"* — the description dies
   inside its own first clause, taking the trigger, the invocation spelling and every never-clause with it.
   **Do not shorten a description to fit this**: there is no length that survives, the other surfaces
   keep the tail, and a thirty-character description would be worse everywhere and no better here. What
   follows instead is that **on Cursor the skill `name` does almost all of the routing work.**
2. **The name space is flat, global and shared.** It is not only your repository's `.cursor/skills/`: on
   this host one listing carried the fifty-one mirrored skills **plus** Cursor's own built-ins **plus**
   this host's Claude Code plugin skills, `build` and `drive` among them. Hatsu claims fifty-nine ordinary
   words at once — `build`, `file`, `en`, `ao`, `ren`, `breath`. **The shadowing itself is inferred, not
   proven, and is written here as such**: two probes tried to confirm it and could not, because the
   descriptions this surface keeps are far too short to tell two rival `build` entries apart. It is a
   documented hazard, not a documented mechanism — and the warm-up's collision listing cannot see it,
   because it lives outside your repository entirely.
3. **`$CLAUDE_PLUGIN_ROOT` is not this surface's variable**, and may point at another plugin. Use
   `$HATSU_PLUGIN_ROOT`.
4. **`--model` is Cursor-native only.** The CLI will accept a provider model; the policy will not.
5. **A mirrored persona keeps its `model:` pin verbatim**, which may name a model this surface cannot
   resolve — reported and substituted, never silently either way.
6. **One half is still unverified**: which repository a mirror's relative `../../../nen/workflow.json`
   lands in **through a symlink** was not re-tested here. The rule that carries it is the one the warm-up
   states — **read the file in the repository the session is standing in**, and where it has none, say so
   and use the defaults rather than falling back to this plugin's copy.
7. **A Cursor cloud agent cannot commit cleanly here.** Cursor's own docs say a cloud agent commits as
   `Cursor Agent <cursoragent@cursor.com>` and adds the person who started it as `Co-authored-by` on each
   commit, and document no switch for that trailer (the IDE/CLI *Attribution* toggle covers
   `Made with Cursor`). `Co-Authored-By` is forbidden, so a cloud-agent effort reads the trailer back
   after every commit and **stops at G5 before its first push** — it never publishes and discloses
   ([`../AGENT-ATTRIBUTION.md`](../AGENT-ATTRIBUTION.md), zheref/hatsu#470). The IDE and `cursor-agent`
   have a documented *Attribution* toggle, but it is documented for `Made with Cursor` only: turn it off,
   and if a `Co-authored-by` still reads back, that path stops on the same read-back before any push.

---

## 4 · Maintenance

**To update**, `/ten` runs [`scripts/hatsu_plugin_update.sh`](../../scripts/hatsu_plugin_update.sh)
`--auto` against `$HATSU_PLUGIN_ROOT` first. The links already point into the checkout, so a trunk
fast-forward or a newer tag *is* most of the update; re-running the warm-up is what repairs a link the
target lost, re-prints the version and the collision list, and is what catches a skip (dirty tree,
authoring branch) rather than pretending the source moved. Same hand form as Codex:

```sh
"$HATSU_PLUGIN_ROOT/scripts/hatsu_plugin_update.sh" --channel trunk
"$HATSU_PLUGIN_ROOT/scripts/hatsu_plugin_update.sh" --channel release
```

| What is served | How it updates | Next, to use it |
|---|---|---|
| `.cursor/skills/<name>` links into `<checkout>/surfaces/cursor/` | fast-forward the checkout (`--auto` in the warm-up); `/ten` repairs links | a new chat, or **Developer: Reload Window** |

### Targeting a local checkout, and authoring this repository on Cursor

```sh
export HATSU_PLUGIN_ROOT="$HOME/Code/Agents/hatsu"
"$HATSU_PLUGIN_ROOT/scripts/surface_bootstrap.sh" --surface cursor --target /path/to/product-repo --bootstrap
# then open that product repo and run /ten
```


**Authoring this repository on Cursor** — so the session does not bind Claude's versioned cache (on this
host that cache has sat at `0.14.0` while `plugin.json` on the tree already read `0.30.0`):

```sh
export HATSU_PLUGIN_ROOT="$HOME/Code/Agents/hatsu"   # this checkout
"$HATSU_PLUGIN_ROOT/scripts/surface_bootstrap.sh" --surface cursor --target "$HATSU_PLUGIN_ROOT" --install-all
```

That writes `.cursor/skills/<name>` → `surfaces/cursor/<name>` of **this tree**, excluded through
`info/exclude`, and that workspace path is what Cursor lists ahead of `~/.claude/plugins/cache/hatsu/…`.
`$HATSU_PLUGIN_ROOT` already belongs in the shell profile; without the bootstrap, Cursor still discovers
the Claude cache and serves last-tag prose while you edit current canon. `--auto` will skip this tree
while you are on a feature branch — correctly — and `ten` § 5 still installs the branch's own mirrors.

## 5 · Uninstall and rollback

Nothing server-side changed. In each repository the warm-up placed into, remove the `.cursor/skills/<name>`
and `.cursor/agents/<persona>.md` symlinks; the warm-up recorded every one of them in that repository's
`.git/info/exclude`, never in `.gitignore`, so nothing tracked changes. The checkout is yours to keep.

## 6 · Caveats

The honest list under *Usage* above is the full set. The three that bite first: roughly thirty characters
of a skill description survive on this surface, so the skill **name** does the routing; the skill name
space is flat, global and shared with Cursor's built-ins and every other plugin on the host; and
`--model` accepts a provider model that the policy file forbids, so a headless run resolves the
Cursor-native id live rather than remembering one.

## Sources

- [`../surfaces/cursor.md`](../surfaces/cursor.md), the dated checklist, the probes, the known gaps
- [`mirrors.md`](mirrors.md), generated versus authored, regenerating, and the check
- [`../../scripts/surface_bootstrap.sh`](../../scripts/surface_bootstrap.sh) · [`../../scripts/hatsu_plugin_update.sh`](../../scripts/hatsu_plugin_update.sh) · [`../../scripts/surface_mirror_check.sh`](../../scripts/surface_mirror_check.sh)
- [`../DIRECT-MATRIX.md`](../DIRECT-MATRIX.md), the model each job is routed to, with this surface's `grok` and `composer` aliases
