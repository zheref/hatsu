# A/B evidence — `bankai-rule` (new skill, zheref/hatsu#355)

`claude/skills/bankai-rule/SKILL.md`: the port-rulings clerk of the cross-platform porting epic
(zheref/hatsu#354, child 1): one ruling per row with a stable id in a directed pair file of
`zheref/bankai-handbooks`' `handbooks/ports/` family, ids reserved against open PRs, one rulings PR
per port run at G4. **A new skill, so there is no "old mechanics" column**; what this record
establishes is what nen `0.22.0` does and does not do for it, each verified live on 2026-10-20.

## 1. The grammar — enumerated slots, the ruling split off before the parse

The epic's challenge settlement (round 2, *grammar word collision*): a free `<to>` slot swallowed a
ruling containing the word *ruling*; the enumerated form refuses it at exit `2`. Verified, and one
step further — nen anchors `to` and `ruling` on their **last** whole-word occurrence, so a ruling that
says *maps to* or *the ruling is* moves the anchors into the prose and the enumerated `<to>` refuses
the swallowed text. So the skill splits the line at its **first** whole-word `ruling` and parses only
the head; the ruling is the verbatim remainder, stated back. A `from` equal to `to` parses (both are
in the set) and is refused by the skill's own rule — a pair is directed — which the grammar cannot
express.

```
$ nen parse bankai-rule --grammar '<from:…> to <to:…>' --line 'swiftui-tca-uzf-v2 to compose-uzf-v2'
from: swiftui-tca-uzf-v2
to: compose-uzf-v2
exit 0

$ nen parse bankai-rule --grammar '<from:…> to <to:…>' --line 'swiftui-tca-uzf-v2 to flutter-uzf-v1'
nen parse: <to> is one of swiftui-tca-uzf-v2 | compose-uzf-v2 | react-uzf-v1 | bankai-machinery (case-insensitively), and 'flutter-uzf-v1' is none of them. It is resolved, never guessed at: the closest match is not the answer.

Corrected line:
  bankai-rule swiftui-tca-uzf-v2 to <to: swiftui-tca-uzf-v2 | compose-uzf-v2 | react-uzf-v1 | bankai-machinery>
exit 2

$ nen parse bankai-rule --grammar '<from:…> to <to:…>' --line 'swiftui-tca-uzf-v2 ruling x'
nen parse: <from> is one of swiftui-tca-uzf-v2 | compose-uzf-v2 | react-uzf-v1 | bankai-machinery (case-insensitively), and 'swiftui-tca-uzf-v2 ruling x' is none of them. It is resolved, never guessed at: the closest match is not the answer.
nen parse: <to> is required and the line does not supply it.

Corrected line:
  bankai-rule <from: swiftui-tca-uzf-v2 | compose-uzf-v2 | react-uzf-v1 | bankai-machinery> to <to: swiftui-tca-uzf-v2 | compose-uzf-v2 | react-uzf-v1 | bankai-machinery>
exit 2

$ nen parse bankai-rule --grammar '<from:…> to <to:…>' --line ''
nen parse: <to> is required and the line does not supply it.
nen parse: <from> is required and the line does not supply it.

Corrected line:
  bankai-rule <from: swiftui-tca-uzf-v2 | compose-uzf-v2 | react-uzf-v1 | bankai-machinery> to <to: swiftui-tca-uzf-v2 | compose-uzf-v2 | react-uzf-v1 | bankai-machinery>
exit 2

$ nen parse bankai-rule --grammar '<from:…> to <to:…>' --line 'swiftui-tca-uzf-v2 to swiftui-tca-uzf-v2'
from: swiftui-tca-uzf-v2
to: swiftui-tca-uzf-v2
exit 0

$ the first draft's grammar, the ruling as a trailing clause, handed the WHOLE line
nen parse: <from> is one of swiftui-tca-uzf-v2 | compose-uzf-v2 | react-uzf-v1 | bankai-machinery (case-insensitively), and 'swiftui-tca-uzf-v2 to compose-uzf-v2 ruling a TCA reducer effect maps' is none of them. It is resolved, never guessed at: the closest match is not the answer.
nen parse: <to> is one of swiftui-tca-uzf-v2 | compose-uzf-v2 | react-uzf-v1 | bankai-machinery (case-insensitively), and 'a Hilt-injected repository call; the' is none of them. It is resolved, never guessed at: the closest match is not the answer.

Corrected line:
  bankai-rule <from: swiftui-tca-uzf-v2 | compose-uzf-v2 | react-uzf-v1 | bankai-machinery> to <to: swiftui-tca-uzf-v2 | compose-uzf-v2 | react-uzf-v1 | bankai-machinery> ruling is map
exit 2

$ the skill's split: head = 'swiftui-tca-uzf-v2 to compose-uzf-v2', ruling = the remainder after the FIRST whole-word ruling
from: swiftui-tca-uzf-v2
to: compose-uzf-v2
exit 0
```

## 2. Id reservation — the tip, the run's own branch, sibling pushed branches, open PRs

**One global counter** (the maintainer's ruling of 2026-10-21, `docs/ROSTER.md` § *Rulings of
2026-10-21 — the port rule prefix (HA#355)*): the prefix is `PT` (`--prefix` anything else is exit 2; a pair file declaring
another prefix or numbering is exit 3) and every read below covers
**every pair file** of the rulings directory (`<rulingsDir>/*.md`, the `--pair-file`'s own directory),
so the next id exceeds every `PT-<n>` in any of them, and `--check` catches one id in two different
pair files. `scripts/port_rule_reserve.sh` (run against the run's rulings worktree) fetches and prunes, then reads the pair files at `origin/<base>`, at the run's
own HEAD and working tree (a batched call's second row never repeats its first — Chrollo C1 /
Nobunaga N2 at the first head), at every other pushed or local `ports-*` branch (Chrollo C4; a run that has not pushed is
otherwise invisible, so `--check` repeats the reads as a duplicate pass at catch-up and the gate — Chrollo C16),
and in every open same-repository PR whose file list names one of them (a fork PR never read at all, listed by number — Feitan F8, hanten round 1 S5; the run's own push and own PR read as
this branch, never as others — S2) (`gh pr list` + `gh api --paginate
repos/<t>/pulls/<n>/files` + `gh pr diff` + `gh api search/issues`, named residue until zheref/nen#456). Hostile open PRs
(Feitan F1–F4): an id outside `^[1-9][0-9]{0,8}$`, or a counted pair file named outside
`^[A-Za-z0-9_-][A-Za-z0-9._-]*\.md$` (its path printed through `%q`, S9), is a named refusal at exit 3, a short list, an
unread PR, a failed git listing or blob read and an unreadable working-tree file are exit 1 and reserve
nothing (S3), a row's first cell is read with any padding (S4), a `--pair-file` with an empty, `.` or `..`
segment is exit 2 (S1), a local `ports-*` head tracking `refs/pull/*` or another remote is skipped (S6), a `+++ b/<pair>` content line in another file's hunk is
never a header, the path is compared literally, the JSON escapes branch names. **Own is decided by ancestry, never by name** (hanten round 2, T1): `origin/<current>` and the
PR whose head is the current branch are this run's own only when they are ancestors of HEAD (the PR
by its `headRefOid`); a same-named branch or PR of another run is read and counted. **Rows** (T2):
every line with a `|` is judged by its first cell, emphasis stripped; `PT-<n>` indented at most three
spaces is counted, any other `PT-<digits>` first cell or another prefix's `[A-Z]+-[0-9]+` is a named
exit 3; a row in a fenced example is counted too, a safe over-count. **Headers** (T3): a `<!--` line
naming `prefix:` or `numbering:` (keys in any case, at any indent, in a file or in an open PR's added
lines) must read exactly one `prefix: PT · numbering: global`, `global` followed by whitespace, `)`,
`·` or `-->`, else exit 3; **a headerless file is counted.** **Telling the exits apart** (bankai-rule
§ 3): a non-zero exit reserves nothing; among exit 3s, a `--check` duplicate is the one whose lines
read `also at`, every other exit 3 a refusal of a shape. Local heads (T4): a remote unset or `.` is
read; `refs/pull/*` and a remote whose URL is not origin's are skipped, reported by count and reason.
The `port-rule-guard` lane (`nen shu test --repo <hatsu> --lane port-rule-guard`), the fixture's own
`gh` stub on PATH, at bash 5.3 and at `/bin/bash` 3.2:

```
ok    branch B reserves PT-5 past branch A's open PT-4 (exit 0)
  ok    the tip's three and PR #7's one are all seen
  ok    --json carries complete, next and number and parses
  ok    from branch A the same answer, PT-5: its own PT-4 is the open PR's, the tip is main
  ok    the run's own branch counts: PT-4 first, then PT-5 from the working tree and from HEAD
  ok    a sibling run's pushed ports-* branch with no PR is read: PT-5 past its PT-4
  ok    run against the run's worktree (clone root on main): its own unpushed PT-5 is seen, next PT-6
  ok    --check: an id this branch adds that a sibling branch carries is exit 3, naming both
  ok    --check: no duplicate is exit 0
  ok    a symlinked working-tree pair file is refused at exit 2
  ok    a sibling branch deleted on origin (and locally) is pruned and stops counting (next PT-4)
  ok    a pair file absent at the tip and in every PR takes the directory's next id, PT-5, never PT-1 (exit 0)
  ok    an empty rulings directory starts the counter at PT-1 (exit 0)
  ok    a PR not touching the pair file is never read, even with a +++ b/<pair> content line (exit 0)
  ok    a header line inside another file's hunk is never a header: PT-77 not seen, next PT-5
  ok    a PR naming the pair file with no hunk header (a rename) is exit 1, named, never read as empty
  ok    a PR deleting the pair file is read as empty, exit 0
  ok    a local, unpushed sibling ports-* head in the same clone is read: PT-5 past its PT-4
  ok    a clone whose fetch refspec does not cover refs/heads/* is refused at exit 2
  ok    a same-repo id with a leading zero or past the ceiling is a named refusal at exit 3, listing the PR (exit 3)
  ok    a fork PR at the ceiling or out of shape is listed as not read, by number only, and never moves the id (exit 0)
  ok    an open-PR list shorter than the repository's open total is exit 1
  ok    a PR file list shorter than its changedFiles is exit 1, never clean
  ok    an unreadable open PR diff is exit 1, never clean, and reserves nothing
  ok    an incomplete read prints complete:false and a null next
  ok    a quote in a branch name is escaped in --json
  ok    a pair path with regex metacharacters is refused as usage, never spliced into a pattern
  ok    p/x.md never reads p/xxmd (the tip's PT-1 only, next PT-2)
  ok    a pair path with .. or a leading / is usage
  ok    a prefix with a space is usage
  ok    a worktree that is not a git checkout is exit 2
  ok    an unknown argument is exit 2
  ok    a flag with no value is usage, never an unbound-variable crash
  ok    a pair path with no directory is usage: the counter is the rulings directory's
  ok    global: the next id exceeds every pair file's -- the tip's two, a sibling's third, a PR's fourth: PT-9 (exit 0)
  ok    global: every read is named with its file
  ok    global: a pair with no file yet takes the same PT-9, never PT-1 (--json parses)
  ok    global: a pair file this run creates in its working tree counts: next PT-10
  ok    global --check: one id in two of this branch's own pair files is exit 3, naming both files
  ok    global --check: an id a sibling branch carries in a DIFFERENT pair file is exit 3
  ok    global --check: an id the tip carries in a DIFFERENT pair file is exit 3, never skipped as a merged row
  ok    global --check: an id an open PR adds to a DIFFERENT pair file is exit 3
  ok    global --check: the reserved PT-9 beside the tip's carried rows is no duplicate, exit 0
  ok    global: a same-repository PR naming a pair file out of shape is a named refusal at exit 3
  ok    global: a fork PR naming a pair file out of shape is never read, exit 0, PT-7 past the sibling's PT-6
  ok    S1: a pair path with '//', a leading './' or a '/./' segment is usage, exit 2 (got 2 2 2)
  ok    S7: a --target outside owner/name's shape is usage, exit 2
  ok    S8: a --prefix other than PT is usage, exit 2, named
  ok    S2: --check after the run's own push is exit 0, its pushed copy never a sibling
  ok    S2: --check with only the run's own PR open (its headRefOid an ancestor of HEAD) is exit 0
  ok    S3: a sibling whose blob is missing is exit 1, named, complete:false and a null next
  ok    S3: a working-tree pair file at mode 000 is exit 1, named, complete:false and a null next
  ok    S8: a pair file whose header declares a foreign prefix or numbering is exit 3, named
  ok    S9: a working-tree pair file named out of shape is exit 3, its path named
  ok    S9: a sibling's pair file named out of shape is exit 3, its path and branch named
  ok    S6: a local head tracking refs/pull/* or a remote whose URL is not origin's is skipped, counted by reason, never named or counted (next PT-7)
  ok    S5: fork PRs with a mode-change diff, an unreadable diff and a short file list are listed, never read: exit 0, next PT-4
  ok    S4: tip rows '|PT-40|' and '|  PT-41  |' are counted: next PT-42
  ok    T1: a same-named pushed branch that is not an ancestor of HEAD is a sibling: its PT-50 is counted, next PT-51
  ok    T1: --check catches this run's PT-50 against the same-named branch's PT-50, exit 3
  ok    T1: a same-named PR whose headRefOid is not an ancestor of HEAD is read as an open PR: --check exit 3
  ok    T1: one id in two rows of the same pair file is a --check duplicate, exit 3
  ok    T2: a pipe-less row, a three-space indent, bold, code and emphasis first cells are each counted: next PT-71 (0 next: PT-71 / 0 next: PT-71 / 0 next: PT-71 / 0 next: PT-71 / 0 next: PT-71)
  ok    T2: a row indented four spaces, a struck or suffixed PT cell, and another prefix's first cell are each a named exit 3 (3 3 3 3)
  ok    T2: the header row and the separator row are not rows (next PT-42)
  ok    T2: a row inside a fenced example is counted too, the documented safe over-count (next PT-81)
  ok    T3: a doubled numbering, an indented foreign header, global.per-pair, a second numbering, capitalised keys and globalish are each a named exit 3 (got 3 3 3 3 3 3)
  ok    T3: the ruled header indented, with keys in any case, is accepted (exit 0)
  ok    T3: an open same-repository PR adding a pair file with a foreign header is a named exit 3, as at the tip
  ok    T4: a local head tracking '.' is read (next PT-96)
  ok    T4: a refs/pull/* head is skipped by count and reason, never by name
  ok    T5: a control character in a branch name is escaped as \u0001 and the JSON parses
  ok    T6: --target acme/. and acme/.. are usage, exit 2
  ok    T15: templates/ports/pair.md and INDEX.md rendered into the tip read clean, the row counted: exit 0, next PT-4
  ok    SCALE: 3000 rows in 6 pair files and two siblings reserve PT-3003 and --check is clean, both within 30 s (took 1 s)
  ok    a tip ref that does not resolve is a named exit 2, never PT-1
  ok    a failed fetch of origin is a named exit 2, never a stale tip
port-rule-guard: 77/77
```

**Cost — no slower than main's one-file read** (the maintainer's ruling on HA-PR-#392: no performance
decrease, the structural cost of reading the whole directory included). One `git ls-tree` per place lists
its pair files; one `git cat-file --batch` serves every blob of every place; one POSIX awk judges every
line of every file in read order; duplicates are found once, after collection, by one awk over the seen
lines. The process count is the number of places plus two, whatever the number of pair files, and the
work is linear in rows. Every exit, message and output line is unchanged: a differential harness ran the
round-2 script and this one side by side on every guard call of the fixture and of every hanten repro and
compared stdout, stderr and the exit byte for byte, with zero mismatches. The scaling case above holds 3000
rows to 30 s; the round-2 script took 178 s on it.

Method: `perfbench.sh <scratch> <files> <rows> <siblings> <prs>` times main's script (`old`) against this
one (`new`) on one throwaway rulings directory, `gh` stubbed so the network side is equal (the stated
number of open same-repository PRs, none touching a pair file), 5 runs each, the median reported, on an
Apple M4 Max, macOS 27.0, GNU bash 5.3.20, git 2.54.0, `/usr/bin/awk` (BWK 20200816).

| Tree (files × rows, siblings, PRs) | old median (s) | new median (s) | Same `next:` |
|---|---|---|---|
| realistic, 6 × 100, 3, 5 | 0.32 | 0.27 | PT-605, both |
| many small files, 20 × 50, 3, 5 | 0.30 | 0.28 | PT-1005, both |
| heavy, 6 × 1000, 10, 20 | 1.34 | 0.88 | PT-6012, both |
| one large file, 1 × 200000, 0, 0 | 42.13 | 3.25 | `(none)` for both from the harness itself; PT-200003 for both with its `seq` guarded |

The quadratic round-2 script, measured before this change, took 4.3 s and 410 s on the first and third
rows. On the last row, BSD `seq 1 0` counts down, so the harness's stub lists two PRs against a search
total of zero and both scripts refuse the short list at exit 1 after the same reads; a copy with `seq`
guarded (one run) printed PT-200003 for both, in 46.6 s and 4.7 s.

## 3. Resolving a pair file beside the stacks — `--always-load` until zheref/nen#457

`nen canon resolve` at `0.22.0` returns the always-load set and exactly one stack handbook. The pair
file rides `--always-load` until nen resolves it as a port handbook — **accepted and echoed**: the verb
checks no file exists (a `does-not--exist.md` path is echoed the same way, Chrollo C13), so the
caller tests existence on the canon checkout first. **No mirror carries it** at `0.22.0`: `mirror
generate`/`check` render the stack's rules leaf only (Chrollo C2, Nobunaga N3); the limbo half of
zheref/hatsu#354 criterion 5 is owed to zheref/nen#457.

```
$ nen canon resolve --repo <fixture registry: acme/android-app, scenario compose-uzf-v2> --target acme/android-app --always-load handbooks/uzf-core.md,handbooks/security-baseline.md,handbooks/ux-baseline.md,handbooks/release-policy.md,handbooks/quality-baseline.md,handbooks/ports/swiftui-tca-uzf-v2--compose-uzf-v2.md --stack-dir handbooks/stacks --json   # cwd: a scratch copy of the canon checkout at v0.6.0 carrying the pair file rendered from templates/ports/pair.md
{
  "scenario": "compose-uzf-v2",
  "alwaysLoad": [
    "handbooks/uzf-core.md",
    "handbooks/security-baseline.md",
    "handbooks/ux-baseline.md",
    "handbooks/release-policy.md",
    "handbooks/quality-baseline.md",
    "handbooks/ports/swiftui-tca-uzf-v2--compose-uzf-v2.md"
  ],
  "stackHandbook": "handbooks/stacks/compose-uzf-v2/architecture.md"
}
exit 0

$ the same resolve naming no pair file (0.22.0 knows no port handbook: exactly one stack, nothing else)
{
  "scenario": "compose-uzf-v2",
  "alwaysLoad": [
    "handbooks/uzf-core.md"
  ],
  "stackHandbook": "handbooks/stacks/compose-uzf-v2/architecture.md"
}
exit 0
```

## 4. The catalogue rows — proved on a fixture consumer with and without the keys

`workflow.port.handbooksRepo` and `workflow.port.rulingsDir`, domain `port` (the catalogue's ninth):

```
$ config_values.sh diagnose --repo <fixture consumer without the port keys> --domain port
port — porting between sibling repositories: where port rulings live and which handbooks repository carries them
  DFLT  nen/workflow.json → port.handbooksRepo
        absent — its readers apply the default "zheref/bankai-handbooks"; fill writes it
  DFLT  nen/workflow.json → port.rulingsDir
        absent — its readers apply the default "handbooks/ports"; fill writes it
2 value(s) outstanding — `fill` writes the defaults and annotations; the ASK rows are the maintainer's answers (docs/WORKFLOW.md § 4).
$ config_values.sh need --repo <fixture consumer without the port keys> --skill bankai-rule
bankai-rule: every value it needs is set.
exit 0
$ config_values.sh diagnose --repo <fixture consumer with the port keys> --domain port
port — porting between sibling repositories: where port rulings live and which handbooks repository carries them
  ok    nen/workflow.json → port.handbooksRepo
        "acme/handbooks"
  ok    nen/workflow.json → port.rulingsDir
        "docs/ports"
every settable value is written out and every needed one is set.
$ config_values.sh need --repo <fixture consumer with the port keys> --skill bankai-rule
bankai-rule: every value it needs is set.
exit 0
```

## 5. Residue, named

- The `ruling` split at its first occurrence, in shell before the parse — zheref/nen#458 (a first-anchored clause).
- The open-PR reads (`gh pr list`, `gh api --paginate repos/<t>/pulls/<n>/files`, `gh pr diff`, `gh api search/issues`) — zheref/nen#456.
- The pair file beside the stack handbook — zheref/nen#457.
- The authoring clone at the cache path is `git clone`, `bankai-handbooks` § 0's carve-out.
- The script takes the run's rulings worktree (`--worktree`), never reads a fork PR, matches a hunk header only in a file's header region, paginates the file list, prunes on fetch
  and refuses a symlinked working-tree file; `--check` is the duplicate pass at catch-up and the gate
  (hanten round 2: Chrollo C15–C16, Feitan F8–F12).

## 6. The dry run — `--dry-run` over the fixtures, dated

**Run: 2026-10-22 (UTC), nen `0.24.0` at `/Users/zheref/.local/bin/nen`, host `darwin` (arm64), from the
working tree of `fable/kurapika/port-term-guard` over base `4baf46d65` — the head this PR lands, since the
guard and the `--dry-run` token do not exist at the base.** The SDD assessment's wave 3 (*porting closes the
loop*, zheref/hatsu#354) owes one real dry run per port skill; **this is bankai-rule's, and a stale one is a
finding** — the date is part of the record. `--dry-run` joined the grammar in this same change (§ 1: the
line's last token only, the bare form included; §§ 1–2 read, § 3 and § 4's guards in a scratch clone under
the session's scratch directory, nothing written outside it). Inputs: the consumer fixture
`scripts/fixtures/port-family/with-family`; a scratch **rulings repository** rendered from
`templates/ports/pair.md` and `INDEX.md`, standing in for `zheref/bankai-handbooks`' authoring clone; a `gh`
stand-in on `PATH` answering *no open PRs* for the reserve's two reads (zheref/nen#456); and a two-term
stand-in for the maintainer's product-term list (invented terms, shown). **No GitHub call was made** save
the private-name guard's live list read, the maintainer's own credentials reading their own list; no
`fixture-owner/*` slug reached a networked verb.

**The scaffold, as run** (`<scratch>` is a directory under the session's scratch directory; cwd a Hatsu
checkout):

```sh
D=<scratch>
mkdir -p "$D/bin" && cat > "$D/bin/gh" <<'SH'
#!/usr/bin/env bash
# offline stand-in for the reserve's two open-PR reads (zheref/nen#456): no PRs open, nothing else answered
case "$1 $2" in
  "api search/issues"*) echo 0 ;;
  "pr list") : ;;
  *) exit 2 ;;
esac
SH
chmod +x "$D/bin/gh"
g() { GIT_AUTHOR_NAME=dry GIT_AUTHOR_EMAIL=dry@example.com GIT_COMMITTER_NAME=dry GIT_COMMITTER_EMAIL=dry@example.com git "$@"; }
g init -q -b main "$D/origin" && mkdir -p "$D/origin/handbooks/ports"
sed -e 's/<from>/swiftui-tca-uzf-v2/g' -e 's/<to>/compose-uzf-v2/g' -e 's/<from-prefix>/SW/g' -e 's/<to-prefix>/KT/g' templates/ports/pair.md > "$D/origin/handbooks/ports/swiftui-tca-uzf-v2--compose-uzf-v2.md"
cp templates/ports/INDEX.md "$D/origin/handbooks/ports/INDEX.md"
printf '| swiftui-tca-uzf-v2 | compose-uzf-v2 | swiftui-tca-uzf-v2--compose-uzf-v2.md | 0 | — |\n' >> "$D/origin/handbooks/ports/INDEX.md"
g -C "$D/origin" add -A && g -C "$D/origin" commit -qm "tip: the rendered templates, no rows"
g clone -q "$D/origin" "$D/clone" && mkdir -p "$D/clone/.nen/worktrees/claude-code"
g -C "$D/clone" worktree add -q "$D/clone/.nen/worktrees/claude-code/ports-dry" -b fable/kurapika/ports-swiftui-tca-uzf-v2--compose-uzf-v2-dry
printf '# the maintainer'"'"'s product terms (dry-run stand-in; two invented terms)\nOrderReview\nGold Tier\n' > "$D/product-terms"
```

```
$ cat <scratch>/product-terms
# the maintainer's product terms (dry-run stand-in; two invented terms)
OrderReview
Gold Tier
```

### § 1 — the strip, the split, then the parse; the totality probes

§ 1's block as the skill states it (trailing blanks dropped; a lone or last-token `--dry-run` stripped first;
a bare `ruling` its own arm; the head passed as `--line="$head"`), on five inputs — the ruling, the three
inputs Chrollo's totality pass found unrouted on the first draft, and a trailing blank:

```
$ line="swiftui-tca-uzf-v2 to compose-uzf-v2 ruling the OrderReview sheet becomes a ModalBottomSheet --dry-run"
dry=1 head=[swiftui-tca-uzf-v2 to compose-uzf-v2] ruling=[the OrderReview sheet becomes a ModalBottomSheet]
$ nen parse bankai-rule --grammar "<from:swiftui-tca-uzf-v2|compose-uzf-v2|react-uzf-v1|bankai-machinery> to <to:swiftui-tca-uzf-v2|compose-uzf-v2|react-uzf-v1|bankai-machinery>" --line="$head"
from: swiftui-tca-uzf-v2
to: compose-uzf-v2
exit=0

$ line="--dry-run"
dry=1 head=[] ruling=[]
(no head: the bare form, nothing parsed)

$ line="ruling --dry-run"
dry=1 head=[] ruling=[]
(no head: the bare form, the ruling asked)

$ line="ruling"
dry=0 head=[] ruling=[]
(no head: the bare form, the ruling asked)

$ line="swiftui-tca-uzf-v2 to compose-uzf-v2 --dry-run "
dry=1 head=[swiftui-tca-uzf-v2 to compose-uzf-v2] ruling=[]
$ nen parse bankai-rule --grammar "<from:…> to <to:…>" --line="$head"
from: swiftui-tca-uzf-v2
to: compose-uzf-v2
exit=0
```

The ruling text — holding the word *sheet* and a product-shaped word — never reaches the grammar; the head
alone does (§ 1 of this record). The scenario ids above are the matrix's at `v0.6.0`, read for the record,
not from the skill. Every input lands on one row of § 1's table, the two modifiers composing with it.

### § 2 — what the run reads

```
$ bash scripts/config_values.sh need --repo scripts/fixtures/port-family/with-family --skill bankai-rule
bankai-rule: every value it needs is set.
exit=0

$ nen canon pin --repo scripts/fixtures/port-family/with-family --source zheref/bankai-handbooks
nen: <checkout>/scripts/fixtures/port-family/with-family/nen/repos.json records no 'pinned' tag for zheref/bankai-handbooks under maintained_tools. Record one (maintained_tools[].pinned) so the pin is data.
exit=1

$ nen canon pin --repo . --source zheref/bankai-handbooks
source: zheref/bankai-handbooks
ref: v0.6.0
recorded in: <checkout>/nen/repos.json (maintained_tools[].pinned)
exit=0
```

`need` reads green: both `port.*` keys are at their defaults, said. **The fixture consumer pins no handbooks
repository**, so `handbooksRepo` is `missing-configuration` there (§ 2: the pinned `maintained_tools` row,
none → stop) — a live run on that consumer stops here, the maintainer asked to record the pin; the dry run
lists it and reads the pin off Hatsu's own registry (`v0.6.0`) to show the shape. The reading copy
(`nen canon checkout`) and the cache-path clone are not touched: the scratch repository stands in for the
clone, and the worktree is cut under its `.nen/worktrees/claude-code/`.

### § 3 — the reservation, against a rulings directory with no rows

```
$ PATH=<scratch>/bin:$PATH bash scripts/port_rule_reserve.sh --worktree <scratch>/clone/.nen/worktrees/claude-code/ports-dry --target fixture-owner/fixture-handbooks --pair-file handbooks/ports/swiftui-tca-uzf-v2--compose-uzf-v2.md --prefix PT --json
{"complete":true,"next":"PT-1","number":1,"seen":[]}
exit=0

$ PATH=<scratch>/bin:$PATH bash scripts/port_rule_reserve.sh --worktree … --target fixture-owner/fixture-handbooks --pair-file handbooks/ports/swiftui-tca-uzf-v2--compose-uzf-v2.md --prefix PT --check
port_rule_reserve --check: no duplicate -- every id this branch adds is its own
exit=0
```

The rendered template carries no row at the tip, on this branch, on no sibling and in no open PR (the
stand-in answers *none*), so the counter starts at `PT-1` and `--check` is clean — trivially so: the lane's
two-branch and global cases (§ 2 of this record) are where `--check` earns its keep. `--target` is the
stand-in's `owner/name`, shape-checked and handed only to the `gh` stand-in. Nothing is reserved by a dry run
beyond printing the id it would take.

### § 4 — the two guards on the drafted row, then on the pair file and INDEX

The drafted row, the ruling verbatim in `rationale`, the `redraft` still to write:

```
$ printf '| PT-1 | SwiftUI .sheet | ModalBottomSheet | map | %s | <redraft> | 2026-10-22 | |\n' "$ruling" > <scratch>/row.md
| PT-1 | SwiftUI .sheet | ModalBottomSheet | map | the OrderReview sheet becomes a ModalBottomSheet | <redraft> | 2026-10-22 | |

$ bash scripts/product_term_check.sh --terms-file <scratch>/product-terms <scratch>/row.md
<scratch>/row.md:1: product term #2 -- restate it technology-level, or move the words to the spec folder (docs/config/ports.md section The product-term guard)
product_term_check: 1 mention(s) of a product term or an object reference in a row; the row is restated technology-level, or its words moved to the spec folder, before anything is written (docs/config/ports.md section The product-term guard)
exit=1

$ bash scripts/product_term_check.sh <scratch>/row.md   # the default list, absent on this machine
product_term_check: missing-configuration: no product-term list at ~/.config/hatsu/product-terms -- the maintainer writes it by hand (docs/config/ports.md section The product-term guard), one term per line; a session never does, and nothing is clean until it exists
exit=2
```

**The hit is § 1's product modifier**: standalone (no brief, no spec folder) the words are refused and the
row is redrafted technology-level and said back; under a composite with a spec folder the words would go to
`spec.md § ## Platform decisions` and the picked label (`map`) would be the `rationale`. The index `#2` is
the list's second entry in `LC_ALL=C` order (`Gold Tier`, then `OrderReview`) and never the term. **With no
list the guard refuses, never passes** — on this machine the maintainer's file does not exist, so a live
`bankai-rule` run stops at `missing-configuration` until it is written. The redraft, re-run to `0`:

```
$ printf '| PT-1 | SwiftUI .sheet | ModalBottomSheet | map | map | a SwiftUI sheet presentation becomes a Compose ModalBottomSheet; the business rule it carries is unchanged | 2026-10-22 | |\n' > <scratch>/row2.md
$ bash scripts/product_term_check.sh --terms-file <scratch>/product-terms <scratch>/row2.md
product_term_check: ok -- no product term and no object reference in a row (the --terms-file list; every input read as text)
exit=0
```

Then the pair file and INDEX as they would be written — the rendered template and the INDEX row, in the
worktree — through both guards; the private-name guard against the **live** list on the maintainer's
credentials (no ignore file on this machine, said; one name ruled public dropped):

```
$ bash scripts/private_name_check.sh <worktree>/handbooks/ports/swiftui-tca-uzf-v2--compose-uzf-v2.md <worktree>/handbooks/ports/INDEX.md
private_name_check: ok -- no private repository named (live list, 8 owner(s); no ignore file, so nothing ignored; 1 named by ruling; 0 skipped as binary or not a regular file)
exit=0

$ bash scripts/product_term_check.sh --terms-file <scratch>/product-terms <worktree>/handbooks/ports/swiftui-tca-uzf-v2--compose-uzf-v2.md <worktree>/handbooks/ports/INDEX.md
product_term_check: ok -- no product term and no object reference in a row (the --terms-file list; every input read as text)
exit=0

$ git -C <worktree> status --porcelain | wc -l
0
```

The template's header cites a Hatsu ruling by object id (`HA#355`) inside an HTML comment: not a row, not a
hit — the row rule judges table rows only. **Nothing was written**: the worktree is clean, no row, no INDEX
count moved, no commit, no PR; `nen shu lint` and `kokusen` are the write path's and did not run.

### The lane

`nen shu test --repo <hatsu> --lane product-term-guard` — `scripts/product_term_check_fixture.sh` over the
TypeScript guard behind its shim, hermetic and offline, **129 assertions, 0 failed** at GNU bash 5.3 and at
`/bin/bash` 3.2.57 on this host: every join (camel case, `-`, `_`, `.`, `/`, a double space, a plain join),
the whole-token rule (`checkouts`, `precheckout`, `orders review`, `review order` pass), every encoding and
markup split (entities, URL encoding, a zero-width space, a soft hyphen, a fullwidth letter, a backslash
escape, a tag, a comment, a code span, intraword emphasis), the marks and ignorables this guard folds (a
combining acute, a variation selector, a combining grapheme joiner, a hangul filler, a right-to-left
override) and the confusable letter it does not (pinned as the documented miss), the row rule in and out of
a row (an issue id, an invocation-grammar ref, a PR id, through entities, indented, inside a fence; a header
comment, prose, `PT-5`, `SW-3`, `AC-001`, a bare number, four capitals pass), CRLF and UTF-16-with-BOM
files, a NUL byte in a file, on stdin and in a BOM-less UTF-16 file each refused, a term inside a camel-case
path or label withheld whole, a path or label naming a term redacted or withheld, a `--label` holding a
newline refused, a term with a diacritic folded on both sides and a term in another script refused naming
the alphabet, four spellings of one term sharing one stable index across two runs, stdin once and twice, and
every wiring fault: no default list (`missing-configuration`, who writes it), a dangling link, an unreadable,
empty or comment-only list, a one-character or punctuation-only term, an unknown option, `--resolve` off a
terminal. The shipped `templates/ports/pair.md` and `INDEX.md` read clean; a rendered pair file with one
technology-level row reads clean and is refused at the one product row appended to it. **Not exercised**:
`--resolve` on a real terminal (it needs one), and the Antigravity, Codex or Cursor hosts. The lane also
runs in `unit-tests.yml` through `scripts/unit_tests_ci.mts` once this lands (BC-9).

### Findings against the binary and the fixtures

1. **The fixture consumer pins no handbooks repository**, so a live `bankai-rule` run on it stops at § 2
   (`nen canon pin` exit `1`, quoted above). The fixture was built for `kamui`'s family read, not for a
   rulings run; the dry run says so rather than pinning one. Adding a `pinned` row to the fixture is a
   fixture decision, not this record's.
2. **No product-term list exists on this machine**, so every live `bankai-rule` write is refused at
   `missing-configuration` until the maintainer writes
   `${XDG_CONFIG_HOME:-$HOME/.config}/hatsu/product-terms`. That is the design (ports.md § *The product-term
   guard*): the guard never reads green over a list it does not have, and a session never writes the file.
3. **`nen canon checkout` is unresolvable from this checkout without `--canon-checkout`**: `nen/repos.json`
   declares no `checkout` or `checkout_env` for `zheref/bankai-handbooks` (found by the hanten reviewers on
   this change). A registry gap outside this change, for the wrap-up.
4. **The first draft of this guard was shell with embedded perl.** Hanten read it as a BC-11 breach (HR-171:
   a three-way verdict is TypeScript's) and it was ported to `scripts/product_term_check.mts` behind the
   `.sh` shim before this PR opened; the lane's argv did not change. The owed nen verb is unfiled.
