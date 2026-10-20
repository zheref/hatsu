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

`scripts/port_rule_reserve.sh` fetches, then reads the pair file at `origin/<base>`, at the run's
own HEAD and working tree (a batched call's second row never repeats its first — Chrollo C1 /
Nobunaga N2 at the first head), at every other pushed `ports-*` branch (an in-flight run has no PR
yet — Chrollo C4), and in every open PR whose file list names it (`gh pr list` + `gh pr view --json
files` + `gh pr diff` + `gh api search/issues`, named residue until zheref/nen#456). Hostile open PRs
(Feitan F1–F4): an id outside `^[1-9][0-9]{0,8}$` is a named refusal at exit 3, a short list or an
unread PR is exit 1 and reserves nothing, a `+++ b/<pair>` content line in another file's hunk is
never a header, the path is compared literally, the JSON escapes branch names. The
`port-rule-guard` lane (`nen shu test --repo <hatsu> --lane port-rule-guard`), the fixture's own
`gh` stub on PATH:

```
ok    branch B reserves PT-5 past branch A's open PT-4 (exit 0)
  ok    the tip's three and PR #7's one are all seen
  ok    --json carries complete, next and number and parses
  ok    from branch A the same answer, PT-5: its own PT-4 is the open PR's, the tip is main
  ok    the run's own branch counts: PT-4 first, then PT-5 from the working tree and from HEAD
  ok    a sibling run's pushed ports-* branch with no PR is read: PT-5 past its PT-4
  ok    a pair file absent at the tip and in every PR reserves PT-1 (exit 0)
  ok    a PR not touching the pair file is never read, even with a +++ b/<pair> content line (exit 0)
  ok    an id with a leading zero or past the ceiling is a named refusal at exit 3, listing the PR (exit 3)
  ok    an open-PR list shorter than the repository's open total is exit 1
  ok    an unreadable open PR diff is exit 1, never clean, and reserves nothing
  ok    an incomplete read prints complete:false and a null next
  ok    a quote in a branch name is escaped in --json
  ok    a pair path with regex metacharacters is refused as usage, never spliced into a pattern
  ok    p/x.md never reads p/xxmd (the tip's PT-1 only, next PT-2)
  ok    a pair path with .. or a leading / is usage
  ok    a prefix with a space is usage
  ok    a clone that is not a repository is exit 2
  ok    an unknown argument is exit 2
  ok    a flag with no value is usage, never an unbound-variable crash
  ok    a tip ref that does not resolve is a named exit 2, never PT-1
  ok    a failed fetch of origin is a named exit 2, never a stale tip
port-rule-guard: 22/22
```

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
- The open-PR reads (`gh pr list`, `gh pr view --json files`, `gh pr diff`, `gh api search/issues`) — zheref/nen#456.
- The pair file beside the stack handbook — zheref/nen#457.
- The authoring clone at the cache path is `git clone`, `bankai-handbooks` § 0's carve-out.
- The prefix: the template carries `<prefix>` until zheref/bankai-handbooks#4 rules it; § 4 refuses to
  write a row while it does.
