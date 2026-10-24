# kuchiyose — verification record

`hatsu:kuchiyose` was not ported; it was authored on 2026-10-23 for zheref/hatsu#331 against the
maintainer's rulings of 2026-10-19 (ROSTER HR-135…HR-142, HR-144), the provider's tier-catalogue design
(zheref/akatsuki-ai#49), its reviewer-lane design (AK-IS-#48) and its ceremony (AK-IS-#69, read with
`docs/provisioning/RUNBOOK.md`, `schemas/permission-tiers.yml` and `schemas/required-checks.json` at the
provider's `origin/main`, read-only). This file records the **dry run** that shaped the prose: every
command below was run on 2026-10-23 with nen `0.26.0` (the contract pin), Hatsu at `0.139.0` → `0.140.0`.
`<fx>` is a throwaway git repository in the session's scratch directory holding a copy of Hatsu's own
`nen/` directory, so every write below landed there and nowhere else. **No App, secret, variable,
ruleset, PR or push was made.**

## 1. The invocation

| # | Command | Answer | Exit |
|---|---|---|---|
| 1 | `nen parse kuchiyose --grammar "[verify] [<tier>] [--repo <path>] [--pr <n>] [--dry-run]" --line=""` | refused: *"the literal clause '[verify]' appears before any <slot>, and a clause with nothing to its left bounds nothing"* — so `verify` chooses the template and is never parsed | `2` |
| 2 | `--grammar "[<tier>] [--repo <path>] [--dry-run]"` | refused: *"its leading slot <tier> is bracketed but nothing introduces it"* — so the tier is anchored as `tier <tier>` | `2` |
| 3 | `--grammar "[tier <tier>] [--repo <path>] [--dry-run]"`, lines `""` · `tier reviewers` · `tier reviewers --repo /x/y --dry-run` · `--dry-run` | each `(clause absent)` · `tier: reviewers` · `tier: reviewers`, `path: /x/y`, `[--dry-run]: present` · `[--dry-run]: present` | `0` each |
| 4 | the same, `--line="reviewers"` | *"the line must open with 'tier' to supply <tier>, or omit that clause entirely -- 'reviewers' is neither."*, corrected line `kuchiyose` | `2` |
| 5 | `--grammar "[--repo <path>] [--pr <n>]"`, lines `""` · `--pr 12` · `--repo /x --pr 12` | absent · `n: 12` · `path: /x`, `n: 12` | `0` each |

`--pr x` parses as `n: x` (exit `0`): the slot is not typed, so § 6 passes it to `nen pr ready`, which
refuses a non-number itself.

## 2. Entry and adoption

| # | Command | Answer | Exit |
|---|---|---|---|
| 6 | `bash scripts/tenkai_adopt.sh diagnose --repo <the provider's checkout>` | `10 item(s) outstanding` — among them `BLOK .github/workflows/pr-readiness.yml` (*"repository role is unknown"*) and `ROUT workflow/review-scopes` (`nen/workflow.json` absent): the provider is not adopted (AK-IS-#50, HR-141), so § 0 routes it to `hatsu:tenkai apply` | `1` |
| 7 | the same on this effort's Hatsu worktree | `7 item(s) outstanding` (`MISS dirs/nen-state`, `MISS dirs/claude-worktrees`, `ROUT hooks/commit-msg`, `DRIF .github/workflows/pr-readiness.yml`, …): a linked worktree always reads unadopted, so § 0 diagnoses the core checkout (the parent of `git rev-parse --path-format=absolute --git-common-dir`), never a worktree | `1` |
| 7b | the same on Hatsu's core checkout | `3 item(s) outstanding` (`ROUT hooks/commit-msg`, `DRIF .github/workflows/pr-readiness.yml`, `MISS config/defaults`): even the canon checkout would be routed to `tenkai apply` today | `1` |
| 8 | `nen repo resolve AK --repo <hatsu>` | `zheref/akatsuki-ai  (AK)  via code` (HR-144 reading 4) | `0` |
| 9 | `nen repo classify --repo <hatsu> --json` | `role: canon` — a kuchiyose PR on Hatsu would stand at G4 | `0` |

## 3. The gates write — refused at nen 0.26

| # | Command (on `<fx>`) | Answer | Exit |
|---|---|---|---|
| 10 | `nen schema set --repo <fx> --file nen/gates.json --pointer /reviewers/- --value '{"name":"sasuke",…}' --dry-run` | *"… is a gate change … Setting it needs --gate-change"* | `2` |
| 11 | the same with `--gate-change` | *"/reviewers is an array, and appending to one ('-') is not an edit this verb makes. Nothing was written."* | `1` |
| 12 | `--pointer /reviewers/1 --gate-change` | *"/reviewers/1 is past the end of the array … adding to an array is not an edit this verb makes"* | `1` |
| 13 | `--pointer /round_quorum/any_of --gate-change --value '["copilot","sasuke"]'` · `--pointer /round_quorum` with the whole object | *"holds an array; this verb replaces a scalar … or adds a member, never a whole structure"* · *"holds an object; …"* | `1` · `1` |

So no nen verb at the pin adds a lane to `reviewers[]` or a name to `round_quorum.any_of`; a scalar
(`/round_quorum/minimum`) is settable. § 4.2 stops there and names the gap — the file is never
hand-edited, because that would be the improvised fallback `D10` forbids.

## 4. The `ci` block

| # | Command | Answer | Exit |
|---|---|---|---|
| 14 | `scripts/config_values.sh set --repo <fx> --id workflow.ci.<key> --value <v>` for `provider "AK"`, `pinned "v0.1.0"`, `tiers ["reviewers"]`, `rulings.hidan "off"`, `rulings.claudeAuth "claude_code_oauth_token"` | `set nen/workflow.json → ci.<key> = <v>` each; the block reads `{"provider":"AK","pinned":"v0.1.0","tiers":["reviewers"],"rulings":{"hidan":"off","$hidan":"one of: on \| off","claudeAuth":"claude_code_oauth_token","$claudeAuth":"one of: …"}}` | `0` each |
| 15 | `rulings.hidan "maybe"` · `rulings.claudeAuth` given a credential-shaped string | *"refusing "maybe": ci.rulings.hidan is one of: on \| off"* · refused the same way, the value never written | `2` · `2` |
| 16 | `nen schema check --repo <fx>` | `ok nen/workflow.json` (the block is tolerated, not validated) | `0` |
| 17 | `nen shu test --lane config-values-guard` after the five catalogue rows were added | green: the rows validate (`when: nen/workflow.json#ci`, so `fill` never writes a `ci` key into a consumer without the block) | `0` |

## 5. Provider, pin and catalogue

| # | Command | Answer | Exit |
|---|---|---|---|
| 18 | the provider's `nen/repos.json` → `latest` at `origin/main` | `null`; `git tag` lists no tag | — |
| 19 | `node scripts/gh_api_read.mts tag-ref zheref/akatsuki-ai v0.1.0` | `Not Found (HTTP 404)` | `1` |
| 19b | `gh api repos/zheref/hatsu/git/ref/tags/v0.94.0` beside `git rev-parse v0.94.0^{commit}` (a Hatsu annotated tag, the delta review's probe) | `object.type: tag`, `d6025f61…` · the commit `8952bef3…`: `tag-ref` answers the tag **object**, so comparing it with a commit refuses every annotated pin | — |
| 19c | `node scripts/provider_tag_commit.mts https://github.com/zheref/hatsu.git v0.94.0` | `{"tag":"v0.94.0","kind":"annotated","object":"d6025f61…","commit":"8952bef3…"}`: § 2 compares and reads at `commit`; the fixture (`provider_tag_commit_fixture.mts`, lane `gh-api-read-guard`) holds both tag kinds and the 1/2/3 refusals | `0` |
| 20 | `git show origin/main:schemas/tiers.json` in the provider's checkout | *"fatal: path 'schemas/tiers.json' does not exist in 'origin/main'"* (AK-IS-#49 open) | `128` |
| 21 | the provider's `ninjutsu/src` searched for a tier render verb | none (AK-IS-#49's `ninjutsu tier render` unbuilt); the RUNBOOK's A5 records `nen scaffold caller` absent (finding F1) | — |

**Today kuchiyose stops at § 2 on every consumer**: there is no provider tag, no catalogue and no
render verb. That is the correct outcome, reported, never routed around.

## 6. The pin sweep

| # | Command | Answer | Exit |
|---|---|---|---|
| 22 | `nen warmup --current v0.139.0 --repo <fx>` with row 14's block | `CI pin sweep: FAILED — CI registry has no latest tag` | `1` |
| 23 | the same with `--ci-registry <the provider's checkout directory>` | `CI pin sweep: FAILED — EISDIR: illegal operation on a directory, read`: the flag takes the registry **file**, not a checkout | `1` |

## 7. `verify`

| # | Command | Answer | Exit |
|---|---|---|---|
| 24 | `bash scripts/gh_token_env.sh nen pr ready 67 --gh-repo zheref/akatsuki-ai --json` from outside a checkout | *"nen: no reviewer identities …"* — so § 6 passes `--gates <core>/nen/gates.json` | `2` |
| 24b | the same with `--gates <the provider's checkout>/nen/gates.json` | `not-ready`, the JSON document as row 25 reads it | `1` |
| 25 | the same, run once from the provider's checkout (AK-PR-#67) | `not-ready`; `rounds-owed.owedRounds[]` = `sasuke`, `kakuzu`, `bugbot`, each `no-round-at-head` with **no `state`**: the provider's lanes are declared request-shaped (no `wake: "event"`), so nen reports no event-run state for them | `1` |

nen `0.26`'s `pr ready --help` settles which file a `--gates` path supplies: one naming the checkout's own `nen/gates.json` is read at the base like the default, any other file inside the checkout is `local-fallback`, and a file **outside** the checkout is used as given (`gates-flag`). So § 6 runs from the core checkout and passes a copy of the install PR's file from scratch.

nen `0.26`'s USAGE (*Event lanes*) gives an event lane's `eventRun.state` / `owedRounds[].state` as
`in-flight`, `no-run`, `completed-without-review` or `posted`; § 6's table maps those. The lanes' own
notices (`hidan-review.yml`, `sasuke-audit.yml` at the provider's `origin/main`) carry
`outcome=skipped-unprovisioned` under both the *withheld* and the *skipped* notice titles, so the two
are told apart only by the title, in a log no nen verb reads.

## 8. Findings, for the integrator

1. **nen** — `nen schema set` cannot add a member to a `nen/gates.json` array (rows 10–13). An append
   form under `--gate-change`, or a lane verb, is owed before § 4.2 can run. Unfiled.
2. **nen** — no read of a provider file at a ref (the catalogue) and no read of a job's log notice
   (§ 6). Unfiled; `nen warmup` already resolves the provider registry internally.
3. **Akatsuki** — AK-IS-#49: no `schemas/tiers.json` and no `ninjutsu tier render`; AK-IS-#50: no first tag. Until
   both land no tier is installable.
4. **Hatsu canon** — `GATE-CONFIGURATION.md` § 3 and PROCESS § *Event-driven reviewer lanes* predated nen
   `0.26`'s `wake: "event"` key (zheref/nen#440, closed). Repinned in this PR's settle: the posted-review
   shape carries `wake: "event"` (both shapes pass `nen schema check` at `0.26.0`, on `<fx>`), and
   reading `eventRun.state` as *The sixth stop*'s (c) observations is recorded as unruled.
5. **Hatsu** — `tenkai_adopt.sh diagnose`'s caller `drift` row (zheref/hatsu#331's last criterion) waits on the
   catalogue, so it is not built here.
6. **Permissions** — the skill needs no new allow row (its reads are `nen`, `git show` and
   `bash scripts/*`). The settle adds deny rows to `contracts/permissions.json` for `gh secret set *`,
   `gh secret delete *`, `gh variable set *` and `gh api` calls on `*rulesets*`, `*actions/secrets*` and
   `*actions/variables*`. They land only through this G4 PR, which the maintainer merges. A global flag before
   the subcommand (`gh -R <slug> secret set`) escapes a prefix deny, so the skill's rule still binds.
