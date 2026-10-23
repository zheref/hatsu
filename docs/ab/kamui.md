# A/B evidence — `kamui` (zheref/hatsu#356)

`claude/skills/kamui/SKILL.md`: one issue or one shipped PR encoded as a spec-kit canon in its product
family's spec repository at **G2**, then one port issue per picked sibling, then the picked builds. Its
probes landed with HA-PR-#366; **this file is the dated dry run** the SDD assessment's wave 3 (*porting
closes the loop*, zheref/hatsu#354) owes: `--dry-run` over the offline fixtures, every command and its
output as they ran, so a reader can rerun them from a checkout. **A stale dry run is a finding** — the
date below is part of the record.

## 1. Dry run — `hatsu:kamui FI-IS-#7 --dry-run` over the fixtures

**Run: 2026-10-22 (UTC), nen `0.24.0` at `/Users/zheref/.local/bin/nen`, host `darwin` (arm64), from the
working tree of `fable/kurapika/port-term-guard` over base `4baf46d65` — the head this PR lands; every
command below reads only files that exist at the base too, so it reruns from `main`.** Inputs: `scripts/fixtures/port-family/with-family` (the source member's
registry, `FI`, scenario `swiftui-tca-uzf-v2`), `scripts/fixtures/port-family/spec-repo` (the family's spec
repository: registry and `port.specKit.*`) and `scripts/fixtures/spec-family/specs/` (one folder,
`001-fixture-capability`). **No GitHub call of any kind was made**: `fixture-owner/*` is an unclaimed login
and never reaches `gh` or a networked verb ([`PUBLIC-REDACTION.md`](../PUBLIC-REDACTION.md), the fixture
row; [`ports.md`](../config/ports.md) § *The run record*). Each read a live run makes from GitHub is named
below as *not read*. `--dry-run` writes nothing: no record, no issue, no spec PR, no label (kamui § 2, § 8).

### § 1 — the invocation, two templates chosen by the first token

```
$ nen parse kamui --grammar "<head>#<n> [--dry-run]" --line 'FI-IS-#7 --dry-run'
head: FI-IS-
n: 7
[--dry-run]: present
exit=0

$ nen ref parse 'FI-IS-#7' --repo scripts/fixtures/port-family/with-family
ref:    FI-IS-#7
code:   FI
kind:   IS
number: 7
glyph:  📄
exit=0

$ nen repo resolve FI --repo scripts/fixtures/port-family/with-family
fixture-owner/fixture-ios  (FI)  via code
exit=0
```

The first token is not `resume`, so the first template parses and the `resume <run_id>` template is never
tried (kamui § 1: one template for both is refused by construction). An `IS` source: the issue's own
implementation stays its own (HR-126).

### § 2 — setup, per missing item; the dry run lists, writes nothing

**2.1 The checkouts file** (ports.md § *The checkouts file*):

```
$ ls "${XDG_CONFIG_HOME:-$HOME/.config}/hatsu/checkouts"
ls: ~/.config/hatsu/checkouts: No such file or directory
```

Absent on this machine: a live run asks for each repository's path once (`missing-configuration`) and
writes the file with the surface's file tool, or clones into the cache path. The dry run **lists** it and
goes on.

**2.2 The spec repository**: the source registry's `families[].spec.repo` reads `fixture-owner/fixture-spec`.
`gh repo view fixture-owner/fixture-spec --json visibility` — **not read** (a fixture slug). A live run
refuses anything but `PRIVATE`; stderr *Could not resolve to a Repository* is the G5 hand-over naming the
one `gh repo create` line. Its `nen/workflow.json` is present in the fixture, so `tenkai` is not owed; its
registry classifies as kamui § 2 expects until zheref/nen#453 models role `spec`:

```
$ nen repo classify --repo scripts/fixtures/port-family/spec-repo --target fixture-owner/fixture-spec
fixture-owner/fixture-spec: role consumer · kind unknown · stack none · gate G2
  lanes: none
  role from: <checkout>/scripts/fixtures/port-family/spec-repo/nen/repos.json: consumers
  kind from: not this checkout: contract not read
  note: kind and stack not derived: 'fixture-owner/fixture-spec' is not this checkout (origin 'zheref/hatsu'), and a contract describes only the checkout it sits in -- run 'nen repo classify' from a checkout of 'fixture-owner/fixture-spec' for its lanes
exit=0
```

**2.3 The family**: `fixture-family`, members `FI` ios · `FA` android · `FW` web; the spec repository's copy
is the truth and the member's copy agrees (a differing member copy is `missing-configuration`):

```
$ diff <(sed -n '/"families"/,$p' scripts/fixtures/port-family/with-family/nen/repos.json) <(sed -n '/"families"/,$p' scripts/fixtures/port-family/spec-repo/nen/repos.json) && echo same
same
exit=0
```

A live run reads each copy with `git -C <checkout> show origin/<base>:nen/repos.json` after a fetch; the
fixture directories are not repositories, so the files are read in place.

**2.4 The pin and layout** — the spec repository's `port.specKit.*` at the catalogue's defaults, the two
rulings keys absent and said (`DFLT`), `nen schema check` green but for the optional `gates.json`:

```
$ bash scripts/config_values.sh diagnose --repo scripts/fixtures/port-family/spec-repo --domain port
port — carrying a delivered feature to a product family's sibling platforms: the spec repository's spec-kit set, and where port rulings live and which handbooks repository carries them
  DFLT  nen/workflow.json → port.handbooksRepo
        absent — its readers apply the default "zheref/bankai-handbooks"; fill writes it
  DFLT  nen/workflow.json → port.rulingsDir
        absent — its readers apply the default "handbooks/ports"; fill writes it
  ok    nen/workflow.json → port.specKit.pin
        "v1.2.2"
  ok    nen/workflow.json → port.specKit.layout
        "specs/{nnn}-{slug}"

2 value(s) outstanding — `fill` writes the defaults and annotations; the ASK rows are the maintainer's answers (docs/WORKFLOW.md § 4).
exit=1

$ bash scripts/config_values.sh need --repo scripts/fixtures/port-family/spec-repo --skill kamui
kamui: every value it needs is set.
exit=0

$ nen schema check --repo scripts/fixtures/port-family/spec-repo
repository: <checkout>/scripts/fixtures/port-family/spec-repo
  ok    nen/labels.json  4 labels
  ok    nen/repos.json  1 consumers, 6 product codes, latest (unrecorded)
  ok    nen/colors.yml  absent (optional)
  warn  nen/gates.json  <checkout>/scripts/fixtures/port-family/spec-repo/nen/gates.json: no such file. Nen reads this repository's taxonomy from 'nen/gates.json' in the TARGET repo and has no built-in copy to fall back on -- a binary that guessed the names would report a taxonomy this repository does not have. Point it at a checkout that carries the file with --repo <path>, or add the file.
  ok    nen/contract.json  absent (optional)
  ok    nen/workflow.json  coverage 80/85/90 (touched), branch '{model}/{persona}/{descriptor}' off 'main', checks: build
  ok    nen/workflow.json#reports.sections  none declared
  ok    nen/workflow.json#review.scopes  none declared
  ok    nen/workflow.json#profile  default standard; allowed fast, standard, thorough
  ok    nen/workflow.json#runners  none declared
  ok    nen/workflow.json#deploy.defaultTarget  none declared (a caller's tooling asks; nen shu deploy still requires --target)
  ok    nen/workflow.json#release  none declared (release unit-check refuses an undeclared unit)
  ok    nen/decisions.json  absent (none declared)
  ok    .claude/rules/  absent (optional): no .claude/canon-values.yml
exit=0
```

`diagnose` exits `1` because two settable values are outstanding; **`need --skill kamui` is the verdict the
skill reads** (ten § 6 step 5b), and it is `0`: no `BLOK`, no invalid row, no stop.

### § 3 — the folder plan

The search for the source and its linked objects, fixed-string and word-bounded, over the layout's first
segment (`specs/`); a live run runs it as `git -C <spec> grep -lwF … origin/<base> -- specs/` after a fetch
and reads open spec PRs with `gh pr list --repo <spec> --state open --search '<object>'` (**not read**):

```
$ grep -rlwF -e 'FI-IS-#7' scripts/fixtures/spec-family/specs/ || echo 'no hit'
no hit
exit=0

$ ls scripts/fixtures/spec-family/specs
001-fixture-capability
exit=0
```

No hit → **a new folder**, `specs/002-<slug>` (`001` is taken; `<nnn>` is the next free three digits across
`origin/<base>` and open spec PRs' folders), `<slug>` from the source title, which the dry run does not have
(the issue is not read). The pinned set (`github/spec-kit` `v1.2.2`): `spec.md`, `plan.md`, `research.md`,
`data-model.md`, `quickstart.md`, `contracts/`, `tasks.md`, `checklists/requirements.md`, plus Hatsu's
`spec.md § ## Platform decisions` and `port-ledger.md`; once, `.specify/memory/constitution.md`. Source text
only as fenced `source-data`. The folder plan is printed; nothing is written.

### § 5 — the sibling list, always asked, none starred

Every member but the source: `FA · android` and `FW · web`, each scenario read by `nen repo scenario` from
**the sibling's own checkout** (kamui § 5). The dry run has only the source's registry, and a sibling named
there under `product_codes` alone carries no scenario:

```
$ nen repo scenario --repo scripts/fixtures/port-family/with-family --target fixture-owner/fixture-ios
swiftui-tca-uzf-v2
exit=0

$ nen repo scenario --repo scripts/fixtures/port-family/with-family --target fixture-owner/fixture-android
nen: 'fixture-owner/fixture-android' is recorded in <checkout>/scripts/fixtures/port-family/with-family/nen/repos.json (as product code 'FA' ('fixture-owner/fixture-android')), but on no row that can carry a 'scenario' field -- only consumers[], maintained_tools[] and pending_onboarding[] rows do, and a product_codes value is a name rather than a row. To give it one, add a row for it under maintained_tools[] if it is one of this registry's own tool repositories, pending_onboarding[] if it has not adopted the machinery yet, or consumers[] if it consumes it, with a 'scenario'.
exit=1

$ nen repo scenario --repo scripts/fixtures/port-family/with-family --target fixture-owner/fixture-web
nen: 'fixture-owner/fixture-web' is recorded in <checkout>/scripts/fixtures/port-family/with-family/nen/repos.json (as product code 'FW' ('fixture-owner/fixture-web')), but on no row that can carry a 'scenario' field -- only consumers[], maintained_tools[] and pending_onboarding[] rows do, and a product_codes value is a name rather than a row. To give it one, add a row for it under maintained_tools[] if it is one of this registry's own tool repositories, pending_onboarding[] if it has not adopted the machinery yet, or consumers[] if it consumes it, with a 'scenario'.
exit=1
```

So the dry run's list reads `FA · android · scenario: not read (no sibling checkout)` and `FW · web · scenario:
not read (no sibling checkout)`; on a live run a sibling whose own checkout declares no scenario is
`handbook-question (CON-37)`, dropped if picked, said. **The picker is not shown under `--dry-run`** — the
answer would be the G1 for the filings, and a dry run files nothing.

**Each filing plan**, per sibling, from *conventions* (ports.md § *Shared conventions*): title
`port: <source title> (from FI-IS-#7)`; labels `job/parity`, `job/implementation`, the sibling's `lang/`
(`lang/kotlin` for `FA`, `lang/typescript` for `FW`, read off the target's taxonomy on a live run); the body
one fenced `source-data` block carrying `spec.md`'s user stories and acceptance scenarios verbatim with their
ids, one unfenced `- AC-{n}: … (F<nnn>-AC-###)` row per scenario, that platform's `tasks.md` rows, the folder
at the merged ref and the source — a link alone refused. `nen issue file --dry-run --target
fixture-owner/fixture-<sibling> …` is **not run**: the verb takes a `--target` and a fixture slug never reaches
a networked verb. The write would be:

```
"$hatsu_root/scripts/gh_token_env.sh" nen issue file --target <owner/name> --repo <sibling checkout> --title '<title>' --body-file <abs body.md> --label job/parity,job/implementation,lang/<key> --assignee <maintainer> --private-names-ignore-file <file § 4's ignore file> --json
gh issue view <N> --repo <owner/name> --json title,body,labels
```

### End — nothing written

No run record (ports.md: *a `--dry-run` writes no record*), no checkouts file, no spec PR, no issue, no label.
The run id a live run would take: `kamui-fi-is-7-20261022`, matching
`^(kamui|hiraishin)-[a-z]{2,3}-(is|pr)-[0-9]+-[0-9]{8}(-[0-9]+)?$`.

## 2. Findings against the binary and the fixtures

*File nothing from this document; this is the list.*

1. **A sibling's scenario lives in the sibling's own registry.** `nen repo scenario` refuses a `--target` the
   registry knows only as a `product_codes` value (exit `1`, the message above). Kamui § 5 already reads each
   scenario from the member's own checkout, so this is the verb agreeing with the skill — but a dry run over one
   fixture registry cannot show a sibling's scenario, and says *not read* rather than inventing one.
2. **`config_values.sh diagnose --domain port` exits `1` on a spec repository that leaves the two rulings keys
   at their defaults.** The exit says *outstanding settable values*, not *stop*; the skill's gate is `need
   --skill kamui`, which reads `0`. A reader of the raw exit code could mistake the one for the other — the
   verdict kamui reads is named in § 2.4 for that reason.
3. **`nen repo classify` on a fixture directory reads the enclosing checkout's `origin`** (`zheref/hatsu`) for
   kind and stack, by design; the role and gate (`consumer`, `G2`) come from the fixture's own registry. The
   `spec` role is still zheref/nen#453's.
4. **The checkouts file is absent on this machine**, so the dry run's § 2.1 lists it; a live run asks once.

## 3. Residue

The spec text, the search reading and the record are judgement (kamui § *Residue*). Owed to nen, unchanged
at `0.24.0`: `families[]` and the `spec` role (zheref/nen#453), `watch until --until merged` (zheref/nen#454),
a file-fed title (zheref/nen#444), the prose lint lane for a new spec repository (zheref/nen#450).
