# Installing a CI tier with Kuchiyose

Run `hatsu:kuchiyose [tier <tier>] [--repo <path>]` on a repository Hatsu already adopted. It installs
one tier of the Akatsuki CI roster, today the **reviewers** (the Sasuke, Kakuzu, Konan and Hidan
lanes), as one pull request in that repository, prints the GitHub-only steps that are yours, and
`hatsu:kuchiyose verify` reads back whether each lane is live. `--dry-run` renders and prints
everything and writes nothing. The installed surface respells the invocation as the table in
[the guide](README.md) describes (`/hatsu:kuchiyose`, `$hatsu:kuchiyose`, `/kuchiyose`). The skill is
[`claude/skills/kuchiyose/SKILL.md`](../../claude/skills/kuchiyose/SKILL.md); the rulings it carries
out are [`ROSTER.md`](../ROSTER.md) § *Rulings of 2026-10-19 — the CI reviewers tier* (HR-135…HR-142).

Near-names, so a typo lands nowhere: `jujutsu` (pairing a device as a launch target), `jujisho` (splitting a mixed working copy),
`jusshin` (self-hosted runners). `tenkai` adopts a repository; `kuchiyose` installs a tier on one
that is adopted; `limbo` keeps its canon mirror current.

## Before you run it

| Needs | Why | If missing |
|---|---|---|
| The repository adopted | the install writes into declarations `tenkai` creates | `scripts/tenkai_adopt.sh diagnose` names each item; run `hatsu:tenkai apply` |
| nen `0.26` or later | the lanes are declared `wake: "event"` and `nen warmup --ci-registry` sweeps the pin | `hatsu:ten` re-pins |
| A provider release tag | the caller and the catalogue are read at a tag, never a branch | stop: no tier is installable before the provider's first tag |
| The tier catalogue at that tag | `schemas/tiers.json` names each lane's job, check, App, secrets and steps | stop, naming zheref/akatsuki-ai#49 |
| A provider render verb | the caller workflow is rendered, never typed | stop, naming zheref/akatsuki-ai#49 |

## What it asks

One picker call (decision row `ci-install-rulings`, a G5): the tier, then each ruling the catalogue
lists. **Hidan** `on` or `off` is asked per repository and never defaulted. **Claude billing** offers the
subscription token (`claude_code_oauth_token`, starred) or the metered API key (`anthropic_api_key`);
only the type is recorded, never the secret.

## What it writes, and where

Everything lands in the consumer's own tree, in one PR at that repository's gate (G2 for a consumer,
G4 for a canon repository):

- `.github/workflows/akatsuki.yml`, one job per lane, every `uses:` pinned to the tag, Hidan's job only
  when on;
- one `nen/gates.json` → `reviewers[]` entry per lane (`wake: "event"`, the App login anchored), each
  name added to `round_quorum.any_of`, `minimum` `2` once two or more lanes are installed, never a
  `base_reviewers` entry — the shapes are [`GATE-CONFIGURATION.md`](../GATE-CONFIGURATION.md) § 3;
- the `ci` block of `nen/workflow.json` ([`workflow.json.md`](../config/workflow.json.md) § `ci`),
  one key at a time through `scripts/config_values.sh set`.

A second PR adds the consumer's factual row to the provider's own registry. Kuchiyose merges neither.

## The ceremony — yours

Decision row `ci-ceremony` (a G5). Kuchiyose prints one block per step and waits:

1. create each lane's `-akatsuki` App with exactly its permission tier (the provider's
   `schemas/permission-tiers.yml`; `docs/provisioning/RUNBOOK.md` Part B is the recipe);
2. install it on this repository and on the provider's;
3. set `<NAME>_APP_ID` and `<NAME>_APP_PRIVATE_KEY` as Actions secrets;
4. set the Claude secret you chose, `CLAUDE_CODE_OAUTH_TOKEN` or `ANTHROPIC_API_KEY`;
5. set the `AKATSUKI_HIDAN_ACTIVE` variable to `true`, only when Hidan is on;
6. apply the ruleset that makes the lane checks required on the default branch — the payload and the
   `gh api` line are printed; you run it.

Never paste a secret value into the session. One that was typed there is rotated.

## Checking the lanes

`hatsu:kuchiyose verify [--repo <path>] [--pr <n>]` reads `nen pr ready --json` on the PR you name, the
newest open one, or a draft probe PR you open, and reports each lane as `live` (a review posted under
its App), `skipped-unprovisioned` or `withheld` (it ran and did not review), `no run`, or pending. The
two middle states differ only in the job log's notice, which no nen verb reads yet, so until one does
they are reported together as `completed-without-review (notice not read)`. A check's colour is never
the evidence.

## Known gaps

Recorded in [`docs/ab/kuchiyose.md`](../ab/kuchiyose.md): the provider has no tag and no tier catalogue
yet; `nen schema set` cannot add a member to a `nen/gates.json` array, so the gates write stops with
the gap named; reading a provider file at a tag and a lane's log notice have no nen verb; `tenkai`'s
caller drift row waits on the catalogue.
