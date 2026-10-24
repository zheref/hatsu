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
| The repository adopted | the install writes into declarations `tenkai` creates | `scripts/tenkai_adopt.sh diagnose` on the core checkout (never a linked worktree, which always reads unadopted) names each item; run `hatsu:tenkai apply` |
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
G4 for a canon repository), read from the provider at one proved commit — the commit the tag names (an annotated tag peeled), checked
against the local tag of a reading clone under `${XDG_CACHE_HOME:-$HOME/.cache}/hatsu/checkouts/` before any
file is read:

- `.github/workflows/akatsuki.yml`, rendered by the provider's verb: one job per lane, every `uses:`
  pinned to the tag, Hidan's job only when on;
- one `nen/gates.json` → `reviewers[]` entry per lane: `name`, `wake: "event"`, `login_pattern`
  `^<appSlug>\[bot\]$` and `review_check_pattern` `^<check>$` (both escaped, anchored),
  `round_check_pattern` only for a lane whose catalogue `roundShape` is `check-is-the-round`, and
  `delivery_holistic_pass` where the catalogue says so. Each name joins `round_quorum.any_of`;
  `minimum` is `2` once two or more lanes are installed (HR-136). A lane is never a `base_reviewers`
  entry. The shapes are [`GATE-CONFIGURATION.md`](../GATE-CONFIGURATION.md) § 3;
- the `ci` block of `nen/workflow.json` ([`workflow.json.md`](../config/workflow.json.md) § `ci`),
  one key at a time through `scripts/config_values.sh set`. Its catalogue rows are owned by Kuchiyose,
  so `tenkai` never asks or fills them.

**The provider's registry row comes after.** The provider's `nen/repos.json` → `consumers[]` records
what your default branch's caller references (`CON-14`), so its factual fields can only change once
the install PR has merged. `verify` reports the row owed at that point: a PR in a worktree of the
provider's core checkout, at the provider's G4 gate. Kuchiyose merges neither PR.

## The ceremony — yours

Decision row `ci-ceremony` (a G5). Kuchiyose prints one block per step and waits. **Run the secret
steps in your own terminal, never inside the agent session**, so no token reaches its transcript.

1. Create each lane's `-akatsuki` App with exactly the rows of its permission tier in the provider's
   `schemas/permission-tiers.yml` **at the pinned tag's commit** (an extra grant is a finding);
   `docs/provisioning/RUNBOOK.md` Part B is the recipe.
2. Install it on this repository and on the provider's.
3. Set `<NAME>_APP_ID`, and the private key from its file, never as a typed value:
   `gh secret set <NAME>_APP_PRIVATE_KEY --repo <owner/name> < <path to .pem>`. Store the key in your
   password manager and delete the downloaded `.pem` (RUNBOOK B3, A4).
4. Set the Claude secret you chose: `CLAUDE_CODE_OAUTH_TOKEN` (from `claude setup-token`, which prints
   the token, so run it in your terminal) or `ANTHROPIC_API_KEY`.
5. Set the `AKATSUKI_HIDAN_ACTIVE` variable to `true`, only when Hidan is on.
6. Apply the ruleset that makes the catalogue's required lane checks required on the default branch.
   The payload is printed inline with its `shasum -a 256`. Check the hash of the file you pass before
   running the printed `gh api --method POST repos/<owner/name>/rulesets --input <file>` line.

Never paste a secret value into the session. One that was typed there is rotated. The plugin's
permission pack denies the session `gh secret set`/`delete`, `gh variable set` and every `gh api` call on
the rulesets, secrets and variables paths, so these steps stay yours. A global flag placed before the
subcommand (`gh -R <owner/name> secret set`) is not matched by that deny, so the rule in the skill
still binds.

## Checking the lanes

`hatsu:kuchiyose verify [--repo <path>] [--pr <n>]` reads `nen pr ready --json` (through `scripts/gh_token_env.sh`, run from your core checkout: while the install PR is open it passes a copy of that PR's `nen/gates.json` from outside the checkout, which nen uses as given (`gates-flag`) because only that file lists the lanes; once the PR merges it reads the base as usual) on the PR you name, the
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
