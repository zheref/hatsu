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

## 2. Id reservation — two branches, one open PR, distinct ids

`scripts/port_rule_reserve.sh` reads the pair file at `origin/<base>` and every open PR's added rows
under that path (`gh pr list` + `gh pr diff`, named residue until zheref/nen#456), and prints the
next free id. The `port-rule-guard` lane (`nen shu test --repo <hatsu> --lane port-rule-guard`), the
fixture's own `gh` stub on PATH:

```
ok    branch B reserves PT-5 past branch A's open PT-4 (exit 0)
  ok    the tip's three and PR #7's one are all seen
  ok    --json carries next and number
  ok    from branch A the same answer, PT-5: its own PT-4 is the open PR's, the tip is main
  ok    a pair file absent at the tip and in every PR reserves PT-1 (exit 0)
  ok    an unreadable open PR is exit 1, never clean
  ok    a prefix with a space is usage
  ok    a clone that is not a repository is exit 2
  ok    an unknown argument is exit 2
port-rule-guard: 9/9
ran:           bash scripts/fixture_output_guard.sh bash scripts/port_rule_reserve_fixture.sh  -- exit 0 in 588ms
```

## 3. Resolving a pair file beside the stacks — `--always-load` until zheref/nen#457

`nen canon resolve` at `0.22.0` returns the always-load set and exactly one stack handbook. The pair
file rides `--always-load` until nen resolves it as a port handbook:

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

- The open-PR read (`gh pr list`, `gh pr diff`) — zheref/nen#456.
- The pair file beside the stack handbook — zheref/nen#457.
- The authoring clone at the cache path is `git clone`, `bankai-handbooks` § 0's carve-out.
- The prefix: the template carries `<prefix>` until zheref/bankai-handbooks#4 rules it; § 4 refuses to
  write a row while it does.
