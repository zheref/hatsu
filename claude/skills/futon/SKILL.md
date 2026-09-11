---
name: futon
description: Take one whole severity band of a repo's backlog from open issues to PRs that have an actor driving them, then run the terminal step the maintainer typed. Use when the maintainer invokes hatsu:futon <repo>@<severity>[+] [then tag | then tag+fanout], or asks to build all the mediums, work the highs and cut a tag, or clear a severity band. Kurapika scopes backlog-loop's engine to one band; every PR this run produces is his own, because Hatsu carries no CI plane — done means CON-32 Ready and a per-PR merge prompt. Cuts only when a then clause asked for one, and the cut itself is getsuga's. Never merges main, never publishes a release.
---

# Futon — one severity band, from open issues to PRs with an actor behind them

**No fixed mode.** Futon is a composed run, not a single-nature one: **Conjurer/Transmuter**
(occasionally **Enhancer**) while an issue in the band is being authored — the same mode-confirmation
[`hatsu:build`](../build/SKILL.md) § 3 makes, invoked per issue — and **Manipulator** while a PR
that authorship produced is being driven to its gate ([`hatsu:sharingan`](../sharingan/SKILL.md)'s engine).
Name the mode in play and say when it switches; never blend two under one header
(`claude/agents/kurapika.md`).

The contract:

> **Name a severity band; I give it back to you with every issue in it carrying a PR that is
> `CON-32` Ready and prompted for your merge. Then, if you typed a terminal, the cut that follows.
> Nothing else, and never past G3.**

**In phase-lattice terms, and changing no mechanics below:** per issue, `futon` is
[`hatsu:build`](../build/SKILL.md) → [`hatsu:tensho`](../tensho/SKILL.md) →
[`hatsu:en`](../en/SKILL.md), and the terminal a `then` clause typed is handed to
[`hatsu:getsuga`](../getsuga/SKILL.md) rather than performed here — the tag and the
release-proposal PR, whose own release unit is [`hatsu:susanoo`](../susanoo/SKILL.md)'s.

**Neither phase past the tag is reachable from here, and each is unreachable for its own reason.**
[`hatsu:kagutsuchi`](../kagutsuchi/SKILL.md) — a non-production upload, per target — **never runs
from a composite at all**: it is the maintainer's own per-target call, and no `then` clause this
grammar accepts can name it (§ 1's refusal table; the only two terminals are `tag` and
`tag+fanout`). [`hatsu:mugetsu`](../mugetsu/SKILL.md) — publication, per target, **G3** — runs only
on the maintainer's recorded per-target go **after** a tag is cut, so `futon` reaches it neither
directly nor through `getsuga`, which never publishes either (§ 8, *G3 is never crossed*).

`futon` is a **scoped, terminated [`hatsu:backlog-loop`](../backlog-loop/SKILL.md)** — not a second
implementation of it. The engine — fetching the backlog, ordering it, advancing an issue, the
monitor, conflict discipline, the hard limits — is that skill's, invoked the way
[`hatsu:build`](../build/SKILL.md) invokes [`hatsu:sharingan`](../sharingan/SKILL.md): *"everything after the
first PR appears is literally that skill's engine."* Where the two would disagree, `futon` wins on
three things and `backlog-loop` wins on everything else:

1. a **severity filter** — the queue is one band, or one band-and-above, never the whole backlog;
2. an **explicit terminal the maintainer typed**, instead of an automatic batch-boundary trigger;
3. **who is behind every PR** — and here the retired skill's whole premise stopped applying.

> **Declared process change — read this before § 4.** The retired (`<reference-repo>`) skill's central
> mechanic was a *choice*: route to a CI lane agent by default, and take local authorship only on
> stall or structural impossibility. That choice presupposed a CI plane to route to.
> [`hatsu:build`](../build/SKILL.md) already established, for the identical structural gap, that
> **Hatsu carries no CI plane at all** — no App, no workflow, no bot identity
> (`claude/agents/kurapika.md` header; `docs/ROSTER.md` names no lane agent) — so *"there is nothing
> left to route a released issue to."* `futon` inherits that finding rather than re-deriving it: **every
> issue this run releases, Kurapika builds himself**, in this same session, in whichever mode § 3
> below confirms. The retired skill's hybrid, per-effort done rule — CI-authored means done at
> PR-open, locally-authored means held to Ready — **collapses to one rule for every PR this run
> ever originates**: `CON-32` Ready, prompted, nothing less (§ 5). This is a declared change from
> the retired skill's behaviour, not a silent one, per the ratified migration plan and
> its tracking issue (private) — the same declaration [`hatsu:build`](../build/SKILL.md) made and
> [`bankai-handbooks`](../bankai-handbooks/SKILL.md) made before it for its own identical gap.
>
> **One qualification, not a reopening of the choice.** A band's queue can still contain an issue
> whose PR was **already open before this run started**, authored by a CI identity that predates
> the migration and belongs to the *target* repository's own machinery (not Hatsu's) —
> `<reference-repo>#939`, whose PR `RR-PR-#925` was opened by `app/kisuke-bankai[bot]` before the
> freeze, is exactly this, verified live (`docs/ab/futon.md` § 2). **Detected mechanically, not
> eyeballed**: the PR author's login matches a bot/App identity pattern — a `[bot]` suffix or an
> `app/` prefix — read via `gh pr view --json author`; `app/kisuke-bankai[bot]` is exactly that
> pattern, the concrete instance above. That PR keeps **its own** done
> rule — open is its milestone, because something else was once driving it — and occupies the **CI**
> half of § 6's two budgets. `futon` never *creates* a new one: it cannot route to a plane that does
> not exist for Hatsu, and on `<reference-repo>` specifically no new one is even possible — the repo is
> frozen. On a still-live consumer this could reappear; say so if it does, rather than assuming
> every open PR in the band is this run's own.

---

## 1. Invocation — `nen parse futon` is a BUILT-IN grammar, never a template you supply

```
hatsu:futon <repo>@<severity>[+] [then tag | then tag+fanout]
```

```bash
nen parse futon --repo <target repo's own checkout> "<the raw invocation, minus the hatsu:futon prefix>" [--self <owner/name>]
```

Unlike every other skill's invocation (`nen parse <skill> --grammar <template> --line <text>`),
`futon` is one of the three grammars `nen parse` ships **built in** — verified live
(`nen parse --help`): *"futon ... carries its own grammar and additional domain logic ... and
takes no `--grammar`."* It resolves the repo token, expands `+`, reads the terminal, **and**
enforces the terminal's own scope rule, all in one call — there is no hand-written template to get
wrong the way [`hatsu:backlog-state`](../backlog-state/SKILL.md) found `nen parse`'s *generic* path
does (its own A/B doc § 4: one bracketed clause silently swallows everything after the slot). `futon`
never touches that generic path at all.

**Echo the full parse before anything is fetched** — repo, band (expanded, with the severities it
covers named), terminal or *build-only* — and **say the run has started**. A named run holds a
bounded `CON-25` delegation (§ 7), and a delegation nobody announced is a delegation nobody can end.

### Verified live, every band shape and both terminals

Run against the real `<reference-repo>` checkout (`--repo` = that checkout's path; `GH_TOKEN` not
needed — this verb reads only `nen/repos.json` on disk,
no GitHub call):

| Invocation | Result |
|---|---|
| `@high` (bare — "the repo you are standing in") | `repo: <reference-repo>` · `band: high -> high` · `terminal: (none -- build-only)` |
| `<reference-repo>@high+` | `band: high+ -> critical, high` · no terminal |
| `@high+ then tag` (bare, no `--self` needed) | `band: high+ -> critical, high` · `terminal: tag` |
| `<reference-repo>@high+ then tag+fanout` | `band: high+ -> critical, high` · `terminal: tag+fanout` |
| `@medium` (`--json`) | `{"repo":"<reference-repo>","code":null,"isSelf":true,"band":{"severity":"medium","plus":false,"severities":["medium"]},"terminal":null}` |

Full transcripts, including an `RA@high+` cross-check that expands the same way for a real consumer,
are in `docs/ab/futon.md` § 1.

### Refusals — every one exit `2`, every one with the corrected line ready to paste

| Invocation tried | Refusal (trimmed) |
|---|---|
| `RA@high then tag` (standing in `<reference-repo>`) | *"'then tag' is refused against '`<product-repo-A>`' -- the terminal is that repository's own release machinery, and it is not the one you are standing in (`<reference-repo>`)."* → `try: RA@high` |
| `RA@urgent` | *"'urgent' is not a severity. Expected one of critical, high, medium, low, optionally suffixed '+'."* → `try: RA@critical` |
| `RA@high then release` | *"'then release' is not a recognized terminal. Only 'then tag' and 'then tag+fanout' are accepted."* → `try: RA@high then tag` |
| `ZZ@high` | *"'ZZ' does not resolve against this registry's product_codes (BC, BS, RA, RB, RC, KC), its consumers, or its maintained_tools/pending_onboarding listings. Resolving it to a near match would point a mutating run at the wrong backlog."* — at the port the code list also printed the registry's own `$comment` documentation key as if it were a code; nen `v0.2.0` (#81, closes zheref/nen#17) skips `$`-prefixed keys as metadata, and the refusal at `v0.3.0` (re-verified live against a registry carrying one) lists codes only |
| `kp@HIGH+ then TAG` | Case-insensitive parsing confirmed (band/terminal parsed correctly); refused on the **same** self-mismatch as row 1, with the corrected line preserving the caller's own casing: `try: kp@high+` |

**`+` means this band or higher, never anything else; a bare severity never quietly widens.**
Verified above: `high+` → `critical, high`; a bare `high` never includes `critical`. **The terminal
is read from the LAST whole-word `then`**, so an issue title containing the word cannot be
mistaken for one — this is the built-in grammar's own job, never a hand-rolled `sed`.

**The terminal's scope rule generalizes beyond what the retired skill assumed, and that is a
finding, not a bug.** The retired skill hard-coded *"a `then` clause is valid on `<reference-repo>`
ONLY."* `nen parse futon` instead enforces *"valid only on the repo you are standing in"* —
verified live: pointed at the same registry with `--self <product-repo-A>`, `RA@high then tag`
**parses** (`docs/ab/futon.md` § 1.4). Nothing in this port exploits that generality — the release
machinery a `then` hands off to (§ 8) is `<reference-repo>`'s specifically (`consumes`/`CON-22`), and
Kurapika's real sessions stand in `<reference-repo>` when they type it — but the grammar itself does not
hard-code that assumption the way the retired prose did, and a future run standing in a different
registry-owning repo would get the identical protection with no code change.

> **Finding this port filed against `v0.1.0`, closed by nen `v0.2.0` (#66, closes zheref/nen#27).**
> At the port the product-code form failed to resolve the registry's **own** repo: `nen parse futon
> --repo <reference-repo checkout> "BC@medium"` refused at exit `2` (*"'BC' resolves to
> '`<reference-repo>`' in this registry's own product_codes, but no owner is recorded for it (it names
> no consumer) …"*), the same refusal reproduced for a `pending_onboarding` entry (`KC`), and only the
> owner/name or short-name form parsed (`docs/ab/futon.md` § 1.5–1.8). The cause was structural — the
> lookup stopped at `consumers[]`, which never lists the registry's own source repo — and
> [`backlog-state`](../backlog-state/SKILL.md)/[`tensho`](../tensho/SKILL.md) hit the same blind spot in
> `nen repo resolve`'s no-token form. **nen `v0.2.0` widened every token lookup to everything the
> registry records** — consumers, `product_codes` keys *and* values, `maintained_tools`,
> `pending_onboarding` — and the no-token origin form resolves by the same rules. Verified live at
> `v0.3.0` against nen's bundled registry: `nen parse futon --repo <path> "BC@medium" --self
> zheref/bankai-core` → `repo: zheref/bankai-core (BC) · band: medium -> medium · terminal: (none --
> build-only)`, exit `0`; `"BC@high+ then tag"` → `terminal: tag`, exit `0`. **`hatsu:futon BC@high` —
> the maintainer's most natural invocation — now parses**, and the bare `@<severity>` and
> `<owner/name>@<severity>` forms still do.

**An unparseable invocation is refused with the corrected line ready to paste** — the same
discipline [`hatsu:izanagi`](../izanagi/SKILL.md) applies to its own grammar. Never run the closest
valid reading "to see"; this run applies labels and opens PRs.

## 2. The queue is the band — and only the band

Fetch the repo's open issues whole, with labels, comments, linked PRs and check/review state
(`nen backlog fetch --repo-slug <owner/name>`, paginated past GitHub's 100-row clamp — never a
cached list). Verified live against the real `<reference-repo>` backlog: 88 open issues, of which
**0 critical, 7 high, 60 medium, 14 low, 7 untriaged** (no `bankai:severity/*` label at all) —
counts sum exactly, confirmed no issue double-carries a severity label
(`docs/ab/futon.md` § 2). A capped fetch (`--limit`) is always reported **truncated**, never
presented as complete — never cap it for a real run.

Then:

- **Select** every issue carrying a `bankai:severity/*` label inside the band. With `+`, the band
  is that severity **and every severity above it** (§ 1).
- **Triage the untriaged** exactly as `backlog-loop`'s own triage step does — propose a severity
  with one line of reasoning, apply it under the run-scoped delegation (`nen label apply ...
  --run`, logged), record it. **If the triaged severity lands inside the band it joins the queue;
  if it does not, it is recorded as triaged-and-out-of-scope and left alone.** Say which, every
  time — a run that silently widened its own band is a run whose scope the maintainer never agreed
  to.
- **`bankai:handbook-question` items and design calls are briefed, never guessed** — they stay in
  the report as *briefed*, and do **not** hold the band open (§ 10).
- **Order within the band**: `nen backlog order --rows-from <path> --severity-order
  critical,high,medium,low --blocks <ids> --affects-consumers <ids>` — verified live against a
  three-row sample drawn from the real fetch, ranking `937` (high) ahead of `938`/`939` (medium,
  tie-broken by age) exactly as expected (`docs/ab/futon.md` § 2). `--rows-from` is **not** `backlog
  fetch --json`'s output: reshape each fetched row to `{ id, severity, createdAt, number }` first
  (severity read off the `bankai:severity/*` label). Since nen `v0.3.0` (#107) the verb validates that
  file at the read seam and refuses a fetch document, or a row missing `id`, at exit `2` naming the file,
  row and field — verified live — instead of crashing. `--blocks`/`--affects-consumers` take a row's
  `id` **or** its bare issue number, and an unmatched token is refused at `2` (nen `v0.2.0`, #64). With
  `+`, the higher severity is worked first and **`critical` pre-empts everything**.

**State the queue before advancing anything**: the count, every issue in it, and what was excluded
and why. The band is the run's whole scope, so a reader who cannot see it cannot audit the run.

## 3. The engine is `backlog-loop`'s, invoked — not restated

Everything about *how* an issue advances is that skill's own, cited rather than copied: triage and
briefing, ordering within a severity, the monitor and its fetch triggers, conflict discipline (one
worktree per effort, cascading `main`, never two efforts on one file), and the hard limits (no
`main` merge, no self-review, no `request_changes`, no G1 label, no release). `futon` does not
re-derive any of it — if that skill's engine changes, `futon` changes with it, which is the whole
point of composing rather than duplicating.

**Where the retired skill's routing table named CI lane labels** (`bankai:agent/naruto` /
`yamamoto` / `kisuke` on `<reference-repo>`, or a consumer's own equivalents), **that label now picks
Kurapika's MODE instead** — the identical substitution [`hatsu:build`](../build/SKILL.md) § 3 makes:
a governance/`CON-{n}` label or a handbook/schema/agent-def label means **Conjurer**; a machinery-only
label an existing rule already sanctions means **Transmuter**. When an issue in the band carries
none of these, propose one and ask, as a `DECIDE` (`CON-37`) — routing decides which authority and
which handbook the work is built under.

## 4. Releasing into build — the mode is confirmed, then Kurapika builds it

Release is still `bankai:stage/building` — real bookkeeping
[`hatsu:backlog-state`](../backlog-state/SKILL.md)/[`hatsu:backlog-board`](../backlog-board/SKILL.md)
read to place the issue on the board:

```bash
nen label apply <CODE>-IS-#<N> --label bankai:stage/building --repo-slug <owner/name> \
  --reason "<why, for the ledger>" --run
```

Contract-inspected only against `<reference-repo>` — never exercised live there (the shared brief's
read-only rule); the flag surface matches `nen label --help` exactly (`docs/ab/futon.md` § 3).

**Then Kurapika builds it, in this same session, in the mode just confirmed.** There is no wake to
verify, no `build` job to poll, no probe run to distinguish from a swallowed one — those describe a
CI plane Hatsu does not have (the declared-change callout above). The build itself runs through the
verbs the target repository declares, exactly as [`hatsu:build`](../build/SKILL.md) § 5 lays them out
and this skill invokes rather than restates: per issue, `nen shu warmup --repo <path> --branch
kurapika/<slug>` — `--dry-run` first, then bare — to cut the branch from the fresh trunk tip and prove the
declared build (on a band of several issues the one worktree-per-effort rule holds, so the warm-up runs
in that effort's own worktree), `nen shu tools --repo <path>` once on a fresh host, then
`nen shu build`/`test`/`lint` as
the work goes — with exit `4` quoted as the lane's own seat, exit `5` sent back to `shu tools`, exit `3`
a **G5** naming the host, and a repository with no declaration built by its own documented commands,
said so (`claude/agents/kurapika.md` § *The `shu` verbs*). Where the work is something a local
session structurally cannot do at all, **stop at G5 immediately** and name the gap — the same move
[`hatsu:build`](../build/SKILL.md) § 5 makes for its own identical hole.

## 5. Done is `CON-32` Ready and prompted — for every PR this run originates

> **The single most important sentence in this skill:** every PR `futon` produces is Kurapika's
> own, so it is not done at PR-open. It is done when `nen pr ready` **and** `nen pr body-check` both
> pass, and the maintainer has been prompted to merge it — and it **holds its slot** until then.

```bash
export GH_TOKEN=$(gh auth token)
# BC#940 / BC#925 below are <reference-repo> PRs, so this run's own identity flag is --gates;
# see the paragraph below for the other two shapes sharingan § 4 names.
# $hatsu_root is THIS plugin's checkout, ABSOLUTE, resolved IN THIS SHELL: the block below is
# hatsu-warmup § 5's prelude in its same-shell form. The variable is not exported, so a value
# another shell set is not here. The second candidate is SINGLE-quoted: hatsu-warmup § 0 prints the root
# already quoted with any ' escaped, ALONE on the line after its label — paste that line in place of '<…>',
# quotes included, nothing else. The awk line is hatsu-warmup § 5's manifest_name on one line: the TOP-LEVEL
# name of the canonical pretty-print, or nothing — any other manifest shape is refused, not parsed.
hatsu_root=""; for c in "${HATSU_PLUGIN_ROOT:-}" '<the absolute path § 0 printed>' "${CLAUDE_PLUGIN_ROOT:-}"; do
  [ -n "$c" ] || continue; case $c in -*) c=./$c;; esac              # an option-looking relative candidate is a path, not a flag
  [ -f "$c/.claude-plugin/plugin.json" ] && [ -d "$c/claude/skills" ] &&
  mn=$(awk 'function scalar(v){return v~/^("([^"\\[:cntrl:]]|\\["\\\/bfnrt]|\\u[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])*"|-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?|true|false|null)$/} function value_ok(v){return v=="{"||v=="["||v=="{}"||v=="[]"||scalar(v)} NR==1{if($0!="{")b=1;sp=1;top[1]="{";ind[1]=0;first=1;comma=0;next} {if(b||d){b=1;next};ni=match($0,/[^ ]/)-1;if(ni<0){b=1;next};body=substr($0,ni+1);if(body~/^[}\]],?$/){c=substr(body,1,1);tr=(body~/,$/);if(sp==0||ni!=ind[sp]||(top[sp]=="{"&&c!="}")||(top[sp]=="["&&c!="]")||comma){b=1;next};sp--;if(sp==0){if(tr)b=1;d=1;next};comma=tr;first=0;next};if(sp==0||ni!=ind[sp]+2||(!first&&!comma)){b=1;next};tr=(body~/,$/);if(tr)body=substr(body,1,length(body)-1);if(top[sp]=="{"){if(body!~/^"([^"\\[:cntrl:]]|\\["\\\/bfnrt]|\\u[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])*": /){b=1;next};v=body;sub(/^"([^"\\[:cntrl:]]|\\["\\\/bfnrt]|\\u[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])*": /,"",v);if(sp==1&&body~/^"name": "/){s=v;sub(/^"/,"",s);sub(/"$/,"",s);n++;name=s}}else v=body;if(!value_ok(v)){b=1;next};if(v=="{"||v=="["){if(tr){b=1;next};sp++;top[sp]=v;ind[sp]=ni;first=1;comma=0;next};comma=tr;first=0} END{if(!b&&d&&sp==0&&n==1)print name}' "$c/.claude-plugin/plugin.json") && [ "$mn" = hatsu ] &&   # captured first: bash 3.2 mis-parses quotes inside "$( )"
  r=$(CDPATH= cd "$c" >/dev/null 2>&1 && pwd -P) && [ "$r/." -ef "$c/." ] && [ "$(printf '%s' "$r" | wc -l)" -eq 0 ] && hatsu_root=$r && break
done
[ -n "$hatsu_root" ] || { echo "no Hatsu root resolved — pass --reviewers by hand instead (sharingan § 4)" >&2; exit 1; }
nen pr ready <CODE>#<N> --repo <path> --gates "$hatsu_root/contracts/reference.gates.json" --explain
```

**Which identity flag goes on that call is [`sharingan`](../sharingan/SKILL.md) § 4's identity rule,
cited rather than restated, and it is resolved BEFORE the call, never defaulted to `--gates`.** A
target that ships its own `nen/gates.json` needs no identity flag at all. `<reference-repo>`
(frozen, ships no gates file of its own — the case above) is the one target `--gates
"$hatsu_root/contracts/reference.gates.json"` is for — always `$hatsu_root`-anchored: the Hatsu
checkout as [`hatsu-warmup`](../hatsu-warmup/SKILL.md) § 5's prelude resolves it on every surface — absolute,
and resolved in the shell that runs this call by the same-shell block above, since the variable is not
exported — never
`$CLAUDE_PLUGIN_ROOT` alone, which is Claude Code's and is unset or wrong on the two mirrored surfaces. Since nen `v0.2.0` a relative `--gates` resolves against `--repo`'s root rather than the cwd, so only
an absolute path reaches a file that lives in *this* plugin's checkout
([`hatsu:pr-state`](../pr-state/SKILL.md) § 2 has the live transcript). Any OTHER target with no
`nen/gates.json` gets `--reviewers` supplied by hand from its `CODEOWNERS` or the PR's own requested
reviewers — a repository is never judged by another repository's reviewers. **The vacuous-approve
caveat belongs to that hand-supplied `--reviewers` path alone**: run with no `--approvers` alongside
it, the approve row's pass is vacuous and is said so on the page — but `contracts/reference.gates.json`
declares its own `default_approvers` (`sasuke`, `tenma`), so the `--gates` form above is a real
approver check even with no `--approvers` flag. **Verified live against both of `<reference-repo>`'s
real open PRs**, contrasting a Ready maintainer-authored PR against a not-Ready pre-existing CI one
(`docs/ab/futon.md` § 4):

- `BC#940` (opened by the maintainer, `zheref`, matching this run's own authorship pattern):
  `ready` — all six conjuncts pass (mergeable, checks green, no owed round, every approval at
  head, zero unresolved threads).
- `BC#925` (opened by `app/kisuke-bankai[bot]` before the freeze — the legacy-CI exception noted above): `not-ready:
  required checks reported but are not all green (CON-32a)`, short-circuited at conjunct 2.

**`nen pr ready`'s verdict is never re-derived by eye.** Then run the confirmation pass — one
directional, a veto only, never a promotion — exactly [`hatsu:sharingan`](../sharingan/SKILL.md) § 4's own
discipline: does every summary-level finding have an inline disposition, was any thread resolved
without a reply, does `nen pr body-check` pass (`## How to verify`, the `changelog.d/` fragment).
Both must pass for Ready; either failing is Not ready, full stop.

**Every PR that reaches Ready gets its own `PushNotification` and its own merge prompt, as it
happens** — never a batched list held until the run ends (§ 10). The terminal (§ 8) waits on **all**
of them.

**A PR that stalls is driven by [`hatsu:sharingan`](../sharingan/SKILL.md)'s own engine** — its
first-blocking-condition ordering (conflict → red check → owed round → unresolved thread → missing
body requirement), its unblocking channels, and its escalation ladder are this run's, invoked, not
restated. Since Kurapika authored the PR himself, the channel is always the "Kurapika authored it"
row of that skill's § 5: reply and resolve threads, push the fix, re-request review — never a wake
label (there is no CI author on this run's own PRs to wake), and never `request_changes`.

**The legacy-CI exception's own done rule is untouched**: a pre-existing CI-authored PR is done at
PR-open, because a different actor was once behind it. `futon` reports it, links it, and moves on —
it does not drive it, and a red one does not hold the band open.

## 6. Two concurrency budgets, counted separately — and futon needs no override

```bash
nen loop slots --efforts efforts.json --ci-cap 2 --local-cap 7 --json
```

| Plane | Cap | Frees when | Populated by |
|---|---|---|---|
| **CI** | 2 | the PR **opens** | only the legacy-CI exception noted above — a PR this run never originates |
| **Local** | 7 | the PR is **Ready and prompted** | every PR this run itself authors |

**`--local-cap 7` is `futon`'s own policy and must be passed; `--ci-cap 2` is still the verb's default.**
At the port (`docs/ab/futon.md` § 5) both were the verb's own defaults, so passing them was
belt-and-braces. **nen `v0.2.0` removed the local-plane default of `7`** (#69, closes zheref/nen#52: a
concurrency guard must be chosen, never inherited) — verified live at `v0.3.0`, `nen loop slots
--efforts <path>` without `--local-cap` refuses at exit `2` naming the flag — so the invocation above,
which always passed the flag, is unchanged and now mandatory; `--ci-cap` defaults to `2` as before.
**`--efforts` resolves against `--repo`'s root from nen `0.7`**, not the process's cwd
(`zheref/nen#100`); an absolute path is still used as-is, and is still what to pass from a worktree.

Two exercised transcripts, built from a mix of the two real open PRs above plus clearly-labelled
illustrative fill (`docs/ab/futon.md` § 5): `BC#925` modelled truly (`prOpen: true, ready: false`)
already shows up in `freed:` — the PR **opening** is what frees a CI slot, readiness is irrelevant to
that plane's rule — while one clearly-synthetic CI-plane row with no live counterpart (no PR yet)
still occupies the other slot, alongside six clearly-synthetic local efforts none yet
Ready-and-prompted: `ci: 1/2 occupied, 1 free` / `local: 6/7 occupied, 1 free`, exit `0`; fill both
planes to capacity (both CI rows synthetic and PR-less, since a genuinely-open CI PR would just free
its own slot) and the report reads `ci: 2/2 occupied, 0 free <- BINDING` / `local: 7/7 occupied, 0
free <- BINDING`, exit `1`. **The two budgets are never traded against each other** — the local budget
filling up and staying full while its PRs work through review rounds is back-pressure, not a bug:
it stops the run from authoring more locally than it can actually drive to the gate. Never let two
efforts, in either plane, touch one file.

## 7. Authority — the same CON-25 delegation, opened and closed out loud

`futon` is a human-invoked named run, so `CON-25`'s carve-out applies, bounded by three conditions
— **logged, run-scoped, those label classes only**:

| | `futon` may |
|---|---|
| **Release** | `bankai:stage/building` on issues in the band |
| **Triage** | `bankai:severity/*` on an untriaged issue, with its reasoning, logged (§ 2) |

**No `Route` row and no `Wake` row.** The retired skill's routing row chose a CI lane; there is none
to choose (the callout above). Its wake row re-fired a CI builder's own stalled loop; there is no CI builder for
`futon`'s own PRs to wake (§ 5) — a stalled review round on a Kurapika-authored PR is
[`hatsu:sharingan`](../sharingan/SKILL.md)'s own channel (reply/resolve/re-request), never a label fire.
Dropping both rows is part of the declared change (the callout above), not an oversight.

| | `futon` may **not** |
|---|---|
| **G1 mode labels** | `ready-for-bankai` / `ready-for-shikai` — never delegated, inside a run or outside it (`CON-4`) |
| **Merge** | Not `main` (`CON-5`/`CON-7`), not its own PR anywhere |
| **Vote** | No review, ever — and **never `request_changes`** (`CON-26`) |
| **Publish** | A release is **G3, the maintainer's** (`CON-6`). Preparing is allowed; publishing is not |
| **Widen its own band** | An out-of-band issue is reported, never worked |

**Every application is logged** — object, label, time — in the status table. **Say when the run
ends**, so the delegation lapses.

## 8. The terminal — futon gates it; getsuga cuts it

**No `then` clause: there is no terminal.** The run ends at § 10 with the band advanced and nothing
cut. Do not "helpfully" cut because a band happens to look finished.

**`futon`'s own job at the terminal is exactly one gate, and no more**: **no PR this run
authored anywhere in the band is short of `CON-32` Ready** (§ 5) — this run owns those PRs; nothing
else drives them, so cutting past one is the half-done release a terminal exists to avoid. Hold the
cut, name every PR still short of Ready with its verdict, and keep driving them. A PR under the
legacy-CI exception does not hold the cut — its own actor (or the fact that `<reference-repo>` is frozen and
takes no further action on it) is independent of this run.

**Everything else about the cut — the whole-repo `critical` check regardless of band, the `CON-36`
live-chore check, honouring an active `RELEASE_HOLD`, collating `changelog.d/`, bumping `latest`,
cutting the tag, and the `CON-22` fan-out computation — is
[`hatsu:getsuga`](../getsuga/SKILL.md)'s own lane**, not restated or reimplemented here. `nen release preflight` and `nen
fanout compute/record` are that skill's own verbs by the binary's own documentation (`nen release
preflight --help` cites *"getsuga SKILL.md § 2"*; `nen fanout compute --help` cites *"getsuga
SKILL.md § 7"* — verified live, `docs/ab/futon.md` § 6) — `futon` never calls either.

**`then tag`**: once § 8's own gate is clear, hand off to
[`hatsu:getsuga`](../getsuga/SKILL.md) for the cut. **Fan-out is skipped, and its issues stay open** — say this explicitly: the
`bankai:handbook-question` fan-out issues this cut *would have* covered are **still open**, the
consumers are **still pinned to the previous tag**, and closing that gap is a later `then
tag+fanout` or a `getsuga` run of its own.

**`then tag+fanout`**: the same hand-off to `hatsu:getsuga`, which performs the cut **and** the
fan-out — affected-consumer computation, repin PRs, closing the covered fan-out issues.

**If the tag capability is refused, HALT and hand the maintainer the exact command.** Never route
around a refusal, and this run never writes `latest` for a tag that does not resolve (`CON-14`) —
it never writes `latest` at all; that write belongs to the cut it hands off.

### G3 is never crossed

`futon` may prepare the ground for a release by clearing its own gate (§ 8's first paragraph); it
**never publishes one**, and the actual cut is a different skill's lane entirely. Where the band's
completion would normally suggest a release, `futon` stops at its own gate and names `getsuga` as
the maintainer's next step.

## 9. Reporting

**Progress turns carry no banner.** Report a compact table each cycle and whenever the maintainer
asks:

| Issue | Sev | Mode | Plane | PR | Done? | Awaiting you | Logged label |
| --- | --- | --- | --- | --- | --- | --- | --- |
| RR-IS-#937 | high | Conjurer | **local** | RR-PR-#940 | ✅ `ready` (both conjuncts verbatim) | **G4 merge** | `stage/building` — |
| RR-IS-#939 | medium | — | **CI (legacy)** | RR-PR-#925 | ⏳ `not-ready: required checks reported but are not all green (CON-32a)` — pre-existing, its own actor | — | — |

**The `Plane` column is not decoration.** A `local` row not yet Ready is **this run's** outstanding
obligation; a `CI (legacy)` row is a fact this run reports and never drives (the callout above). For a local row,
the `Done?` cell carries the `nen pr ready` verdict **verbatim**, never a paraphrase.

Objects use the `<CODE>-<IS|PR>-#<N>` notation (`nen ref format`). Also list every cycle: **briefed
items awaiting a decision**, **blocked items and what blocks them**, **issues triaged into and out
of the band**, and **every label applied under the run-scoped delegation**.

**Every gate stop is the full protocol**: `nen stop --who Kurapika --gate <Gn> [--notified]
efforts.md`, the regenerated gate board published as an Artifact, ~5 lines of chat, and the
question through the harness's question interface. The gates this run reaches:

| Gate | When | Ask kind |
|---|---|---|
| **G4 / G2** | a PR this run authored reaches `CON-32` Ready | `MERGE` — one prompt, per PR, at the moment it happens |
| **G5** | a build Kurapika structurally cannot do, a stall past the escalation ladder, a briefed policy call | `DECIDE` or `DO`, with options and a ⭐ recommendation |

**When the maintainer is needed, do not stop the whole run** — notify, record it, and keep
advancing the rest of the band.

## 10. Ending the run

The run ends when **every issue in the band** is either delivered as a PR that is `CON-32` Ready and
prompted (or, under the legacy-CI exception, already open with its own actor), or briefed and awaiting a
decision, or blocked with its blocker named — **and the terminal, if one was typed, has run or is
explicitly held at its gate (§ 8)**.

> **A run that ends with one of its own PRs short of Ready has NOT ended — it has stopped.** There
> is no actor behind that PR but this run, so calling it done is the one report this skill must
> never produce.

Say the run has ended, so the `CON-25` delegation lapses, and give a final report: the band and
every issue in it with its plane; **for every PR this run authored, its `nen pr ready` verdict
quoted verbatim**; what was triaged into and out of the band; every label applied, with times; the
terminal's outcome (handed to `getsuga`, or the precondition that held it); and what is on the
maintainer's plate.

**`futon` never resumes itself.** Re-invoke it — the same line re-reads live state and picks up
where the objects actually are.

## 11. Hard limits

- **Never merges `main`**, never merges its own PR.
- **Never publishes a release** — G3 is the maintainer's. Preparing is not publishing, and the cut
  itself is `getsuga`'s lane, never this skill's.
- **Never cuts anything without a typed `then` clause**, and never accepts one where `nen parse
  futon` itself refuses it (§ 1) — the resolved repo must be the one standing.
- **Never claims a CI author for a PR it opened.** Hatsu has no CI plane — every PR this run
  originates is Kurapika's, said plainly, every time (the declared-change callout above).
- **Never abandons one of its own PRs at PR-open.** It holds its slot until `CON-32` Ready and
  prompted (§ 5, § 6).
- **Never claims readiness it did not get from `nen pr ready` + `nen pr body-check`**, quoted, never
  paraphrased.
- **Never exceeds 2 CI-plane objects or 7 local worktrees** (`nen loop slots`, § 6), and never lets
  two efforts touch one file.
- **Never widens its band**, and never treats a bare severity as if it carried `+`.
- **Never applies a G1 mode label**, inside a run or outside it.
- **Never self-reviews, never impersonates a reviewer, never casts `request_changes`.**
- **Never batches the merge prompts.** One prompt and one gate stop per PR, as it becomes Ready.
- **Never invokes `nen release preflight` or `nen fanout compute/record` itself** — both are
  `getsuga`'s own verbs (§ 8).
- **Never runs `nen shu deploy --run`** — a deploy is past the tag and behind **G3**, which no `then`
  clause this grammar accepts can name.
- **Never reaches `kagutsuchi` or `mugetsu`**, directly or through the terminal it hands to
  `getsuga`. Both are the maintainer's own per-target calls, and a composite is not where either
  begins (the phase-lattice callout above).
- **Never leaves the delegation open** — the run says when it ends.
