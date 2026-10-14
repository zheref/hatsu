#!/usr/bin/env ruby
# Structural, offline regression guard for Hatsu's workflow runner policy.
require "psych"
require "tmpdir"
require "fileutils"
require "stringio"
require "digest"
require "json"
require "open3"

# Every workflow YAML this script reads is UTF-8 (git, GitHub Actions, this
# repository's own editors). Ruby 2.6's `File.read` otherwise decodes with
# `Encoding.default_external`, which follows the process locale -- under
# `LANG` unset or `C` (macOS's own default outside an interactive shell,
# and some CI images) that is US-ASCII, and a workflow file carrying any
# non-ASCII byte (an em dash, a curly quote) then raises
# `Encoding::InvalidByteSequenceError` on the very first `File.read`, well
# after this script has already announced success on unrelated checks.
# Setting both defaults here, once, makes every `File.read` in this file
# UTF-8 regardless of the calling shell's locale.
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

SAME_REPO_GUARD = "${{ github.repository == 'zheref/hatsu' && github.event.pull_request.head.repo.full_name == github.repository }}"
MAC_RUNNER = %w[self-hosted macOS ARM64].freeze
WINDOWS_RUNNER = %w[self-hosted Windows X64].freeze
HOSTED_RUNNER = "ubuntu-latest"
# This constant does DOUBLE DUTY: it is the portable-workflow set (each member
# must run on GitHub-hosted ubuntu-latest) AND the required-PRESENCE list that
# validate_repo checks. pr-readiness.yml is listed because the workflow now
# EXISTS -- it was withheld while the registration landed ahead of the file,
# since naming an absent file fails every pull request from the other direction,
# and that staging is finished.
#
# So: the CHECK this workflow publishes is advisory and sits in no ruleset, but
# the FILE's presence and shape are enforced by a guard that a required check
# runs. Removing it from this list does not "relax" anything -- it stops the
# workflow's deletion being caught at all.
#
# prose-size-check.yml (zheref/hatsu#135) was registered ahead of its file, the
# #80 ordering: step one knew and judged it without requiring it, while it
# shipped inert at templates/; step two installed it and listed it here.
PORTABLE_HOSTED_WORKFLOWS = %w[plugin-bump-check.yml surface-mirror-check.yml pr-readiness.yml prose-size-check.yml].freeze

# REGISTERED AHEAD OF ITS FILE, A PERMANENT TIER (docs/GATE-CONFIGURATION.md,
# the new-workflow rule; Chrollo, hanten on #135): a portable, hosted
# pull-request workflow this policy knows and judges wherever it sits, staged
# at templates/<name>, but does not yet require -- `main`'s validator refuses
# any workflow it does not know, so the registration lands first. The pull
# request that installs it moves it to PORTABLE_HOSTED_WORKFLOWS. Empty when
# nothing is pending.
PENDING_HOSTED_WORKFLOWS = %w[].freeze

# The one non-PR-targeting workflow this policy admits: a push-to-main /
# workflow_dispatch BUILDER that regenerates surfaces/ and opens a PR, never a
# `pull_request_target`/`pull_request_review` job holding a credential over
# PR-controlled content. It is validated by `validate_builder_workflow`, a
# separate and lighter pipeline, because the `.trusted/` split that the three
# PR-targeting workflows below are held to has no PR checkout to defend
# against here — the trust boundary this workflow needs is "never push
# directly to main", not "never trust the PR's own copy of anything".
BUILDER_WORKFLOWS = %w[surface-mirror-regenerate.yml].freeze

# THE CLOSED SET OF WORKFLOWS THIS POLICY KNOWS ABOUT AT ALL. `validate_repo`
# refuses any `.github/workflows/*.yml` whose basename is in neither list,
# rather than letting it fall through unchecked — a new workflow is exactly
# the thing a PR-controlled diff could add to gain a privileged trigger this
# policy never reasoned about, so silence is not an option the fail-closed
# design allows.
KNOWN_WORKFLOWS = (PORTABLE_HOSTED_WORKFLOWS + PENDING_HOSTED_WORKFLOWS + BUILDER_WORKFLOWS).freeze

EXPECTED_JOBS = {
  "plugin-bump-check.yml" => "check",
  "surface-mirror-check.yml" => "surface-mirror-check",
  "pr-readiness.yml" => "readiness",
  "surface-mirror-regenerate.yml" => "regenerate",
  "prose-size-check.yml" => "prose-size-check"
}.freeze

# The job-level same-repository guard each PR-targeting workflow must carry.
#
# TWO-STEP LANDING (maintainer ruling, 2026-09-20; docs/GATE-CONFIGURATION.md).
# The hardened shape — the DRAFT-SKIP CONJUNCTION, paired with `ready_for_review`
# in the trigger types below — is where these three workflows are headed: a
# draft PR has nothing ready to judge, and re-running these jobs on every push
# to a draft spends minutes on a verdict nobody can act on yet. But the LIVE
# workflows are judged on every PR by the TRUSTED copy of this very script
# checked out from `main` (`ruby .trusted/scripts/workflow_runner_policy_check.rb
# --self-test "$PWD"`), and main's copy still expects the bare guard and the
# narrower trigger set. Shipping the hardened shape and this validator's
# acceptance of it in the SAME PR is therefore self-defeating: the PR that
# changes the live files is judged by the OLD validator on `main`, which
# refuses them, so no PR could ever land the two together. The landing is
# split instead: this PR ships a validator that accepts BOTH the bare guard
# and the draft-skip conjunction (and both trigger shapes below), while the
# live `.github/workflows/*.yml` files stay on the bare shape main's
# validator still recognizes; a follow-up PR — once THIS validator is the one
# `main` trusts — flips the live files to the hardened shape.
#
# NOT `"#{SAME_REPO_GUARD} && ..."` — SAME_REPO_GUARD already carries its own
# closing `}}`, so naively appending text after it would put the draft check
# OUTSIDE the `${{ }}` expression: `${{ A }} && B` string-concatenates `A`'s
# rendered "true"/"false" with the literal text " && B" into one non-empty
# string, which is ALWAYS TRUTHY regardless of either operand. The whole
# conjunction has to live inside one `${{ }}` for the `&&` to be evaluated
# rather than concatenated. ALLOWED_JOB_GUARDS therefore holds the two exact
# accepted strings, never a pattern that could admit that bug.
DRAFT_SKIP_GUARD = "${{ github.repository == 'zheref/hatsu' && github.event.pull_request.head.repo.full_name == github.repository && github.event.pull_request.draft == false }}"
ALLOWED_JOB_GUARDS = {
  "plugin-bump-check.yml" => [SAME_REPO_GUARD, DRAFT_SKIP_GUARD].freeze,
  "surface-mirror-check.yml" => [SAME_REPO_GUARD, DRAFT_SKIP_GUARD].freeze,
  "pr-readiness.yml" => [SAME_REPO_GUARD, DRAFT_SKIP_GUARD].freeze,
  # New with the hardened shape, so it never knew the bare guard.
  "prose-size-check.yml" => [DRAFT_SKIP_GUARD].freeze
}.freeze

# `cancel-in-progress` is a PR-GUARD property, not a builder one. A guard
# superseded by a newer push has nothing left worth finishing, so cancelling
# it is free; a REGENERATION superseded mid-run could leave `surfaces/` half
# written when the `git status --porcelain` check below runs, so it is
# FORBIDDEN there instead — the second push queues behind the first rather
# than racing it.
CANCEL_IN_PROGRESS_REQUIRED = %w[plugin-bump-check.yml surface-mirror-check.yml pr-readiness.yml prose-size-check.yml].freeze
CANCEL_IN_PROGRESS_FORBIDDEN = %w[surface-mirror-regenerate.yml].freeze

# REGENERATE_PATHS is the exact `paths:` filter surface-mirror-regenerate.yml's
# `push` trigger is held to — the ONLY place in either workflow a `paths:`
# filter is still permitted (Hatsu 0.44.0, zheref/hatsu#97): a `push` trigger
# only BUILDS, it is never a merge gate, so a path it misses costs a delayed
# regeneration rather than a deadlocked required check. `.claude-plugin/**` IS
# an input (the stamp source, and the manifest --manifest renders into every
# mirror); `surfaces/**` is NOT (it is the GENERATED OUTPUT this workflow
# itself writes, never an input to wake on — see the workflow's own comment).
REGENERATE_PATHS = %w[
  claude/**
  .claude-plugin/**
  contracts/**
  hooks/**
  nen/**
  scripts/surface_*
  templates/**
  .github/workflows/surface-mirror-check.yml
].freeze

# Per-(workflow, event) expected `paths:` filter. A workflow/event pair absent
# here carries NO `paths:` key at all (see the trigger loop in
# `validate_workflow`) — FORBIDDEN, not merely unchecked. plugin-bump-check.yml,
# surface-mirror-check.yml and pr-readiness.yml are all REQUIRED contexts on
# `main` (or meant to become one), and a required context that carries a
# `paths:` filter never reports at all on a PR whose diff misses every listed
# path — not a false negative, a deadlock. So all three PR guards are
# deliberately absent from this map; only a `push`-triggered BUILDER
# (surface-mirror-regenerate.yml) may carry one, validated separately below.
EXPECTED_PATHS = {}.freeze
# Each workflow declares its EXACT trigger set as a map of event => types. This
# replaced a single hardcoded `pull_request_target` key on the maintainer's
# ruling of 2026-09-19. The shape is still exactly enumerated and still frozen --
# what changed is that a workflow may now name MORE THAN ONE event, not that any
# event is accepted.
#
# WHY THE READINESS WORKFLOW NEEDS MORE THAN ONE. Three of the five conjuncts
# `nen pr ready` evaluates change on events `pull_request_target` cannot see:
# CON-32(a) when a check completes, CON-32(b)/CON-16 when a review lands, and
# CON-32(d) when a thread resolves. With only `pull_request_target`, the verdict
# is computed at push time -- while checks are still pending -- and never
# recomputed, so the `ready` transition is essentially never published and the
# signal reads not-ready almost always. Found by the automated reviewer on #80.
#
# EVERY EVENT HERE CARRIES `github.event.pull_request`, which is what lets all
# three share one byte-compared SAME_REPO_GUARD. `check_suite` does NOT -- its
# payload carries `check_suite.pull_requests[]` instead -- so admitting it would
# need a second, weaker job guard, and it is deliberately NOT admitted here.
# TWO SHAPES, BOTH ACCEPTED (see ALLOWED_JOB_GUARDS above for why). BASE_TYPES
# is exactly what `main`'s trusted validator still expects today. HARDENED_TYPES
# adds `ready_for_review`, which is what re-fires each PR guard/readiness job
# the instant a draft's flag clears — paired with the draft-skip conjunction,
# which otherwise leaves a just-undrafted PR waiting for its NEXT push or
# review event before any of these jobs runs again. A workflow may carry
# EITHER shape for a given event's `types:` (and independently of which job-if
# guard it carries — the follow-up PR that flips the live files is free to
# move either one first).
BASE_TYPES = {
  "plugin-bump-check.yml" => {
    "pull_request_target" => %w[opened synchronize reopened edited]
  },
  "surface-mirror-check.yml" => {
    "pull_request_target" => %w[opened synchronize reopened]
  },
  "pr-readiness.yml" => {
    # No `edited`: the verdict reads checks, rounds and threads, and none of
    # those changes when the body or title is edited.
    # `review_requested` / `review_request_removed` are CON-32(b) inputs in their
    # own right: the gate distinguishes a round in flight from one that is owed.
    "pull_request_target" => %w[opened synchronize reopened review_requested review_request_removed],
    # CON-32(b) / CON-16 -- a reviewer round landing, changing or being dismissed.
    "pull_request_review" => %w[submitted edited dismissed]
  },
  # Hardened from the start, so both maps carry the one shape. No `edited`:
  # the guard reads files, never the body or the title.
  "prose-size-check.yml" => {
    "pull_request_target" => %w[opened synchronize reopened ready_for_review]
  }
}.freeze
HARDENED_TYPES = {
  "plugin-bump-check.yml" => {
    "pull_request_target" => %w[opened synchronize reopened edited ready_for_review]
  },
  "surface-mirror-check.yml" => {
    "pull_request_target" => %w[opened synchronize reopened ready_for_review]
  },
  "pr-readiness.yml" => {
    "pull_request_target" => %w[opened synchronize reopened review_requested review_request_removed ready_for_review],
    "pull_request_review" => %w[submitted edited dismissed]
  },
  "prose-size-check.yml" => {
    "pull_request_target" => %w[opened synchronize reopened ready_for_review]
  }
}.freeze
# The event SET (the keys of either shape's map) is identical between
# BASE_TYPES and HARDENED_TYPES for every workflow -- only a `types:` array
# inside an already-admitted event ever differs between the two shapes -- so
# either constant would do for deriving the expected event set; HARDENED_TYPES
# is used for that below purely because it is declared last.
ALLOWED_TYPE_SHAPES = HARDENED_TYPES.keys.each_with_object({}) do |file, memo|
  memo[file] = [BASE_TYPES.fetch(file), HARDENED_TYPES.fetch(file)]
end.freeze

# The only events a privileged job in this repository may be triggered by. All
# run in the BASE repository context with a credential, so this list is the
# trust boundary and widening it again is a maintainer ruling, not an edit.
# `pull_request_review_thread` was admitted here briefly and REMOVED: it is a
# webhook event, not an Actions trigger, so a workflow naming it cannot register.
# Confirmed against GitHub's event reference after the automated reviewer flagged
# it on #78. CON-32(d) -- thread resolution -- therefore has NO trigger available
# and its staleness is a named limitation rather than an oversight.
ALLOWED_TRIGGERS = %w[pull_request_target pull_request_review].freeze
# WHEN the exact-head check run is created. `:start` opens it `in_progress` and
# PATCHes a conclusion at the end -- right for a guard whose job IS the verdict.
# `:end` creates it once, already completed, AFTER the work.
#
# The readiness workflow must be `:end`, and the reason is a soundness bug rather
# than a preference. Its check is created green, so under `:start` it is a
# REPORTED GREEN CHECK while `nen pr ready` runs -- and CON-32(a) passes on a
# non-empty all-green rollup while FAILING on an empty one. On a pull request
# with no other checks, the gate would therefore read `ready` BECAUSE OF THIS
# CHECK'S OWN EXISTENCE. `--exclude-run` does not save it: an API-created check
# run is attached to an arbitrary check suite, which is why the check is created
# green in the first place. Evaluating before the check exists is the only
# ordering that is sound in both directions.
CHECK_CREATION = {
  "plugin-bump-check.yml" => :start,
  "surface-mirror-check.yml" => :start,
  "pr-readiness.yml" => :end,
  "prose-size-check.yml" => :start
}.freeze

EXPECTED_STEPS = {
  "plugin-bump-check.yml" => [
    "Start required check on the exact PR head",
    "Checkout PR head (data only — nothing from here is executed)",
    "Checkout guard code from the trusted workflow revision",
    "Enforce workflow runner policy from trusted workflow revision",
    "Assert the guard script keeps its exec bit in-tree",
    "Compute changed files + base .claude-plugin/plugin.json (API — no git credential)",
    "Write PR body to file",
    "Plugin-bump guard check",
    "Finish required check on the exact PR head"
  ],
  "surface-mirror-check.yml" => [
    "Start check on the exact PR head",
    "Checkout PR head (data only — nothing from here is executed)",
    "Checkout guard code from the trusted workflow revision",
    "Enforce workflow runner policy from trusted workflow revision",
    "Assert the guard script keeps its exec bit in-tree",
    "Read the pinned nen ref from trusted nen/contract.json",
    "Bootstrap nen at the trusted pinned ref (checksum-verified, two steps, never a pipe)",
    "Verify the nen binary against trusted nen/contract.json's sha256",
    "Surface-mirror drift check",
    "Finish check on the exact PR head"
  ],
  # No "Assert the guard script keeps its exec bit in-tree": this workflow runs
  # no in-repo guard script. Its executable is the checksum-verified nen binary,
  # pinned from the TRUSTED contract, so the exec-bit assertion has no subject.
  "pr-readiness.yml" => [
    "Checkout PR head (data only — nothing from here is executed)",
    "Checkout guard code from the trusted workflow revision",
    "Enforce workflow runner policy from trusted workflow revision",
    "Read the pinned nen ref from trusted nen/contract.json",
    "Bootstrap nen at the trusted pinned ref (checksum-verified, two steps, never a pipe)",
    # zheref/hatsu#230. Hatsu's own form only: tenkai's rendered form carries
    # none (ALLOWED_STEP_SHAPES admits that shape beside this one).
    "Verify the nen binary against trusted nen/contract.json's sha256",
    # No freshness step: the verdict's `--require-head "$EVENT_HEAD"` pins the
    # judgement to the event head and exits 8 on a mismatch, which is what that
    # step only approximated (zheref/hatsu#160). The verdict and Publish steps
    # are FROZEN below, so the pin cannot be dropped with the step.
    "Readiness verdict",
    "Publish the check on the exact PR head"
  ],
  "surface-mirror-regenerate.yml" => [
    "Checkout main",
    "Read the pinned nen ref from nen/contract.json",
    "Bootstrap nen at the pinned ref (checksum-verified, two steps, never a pipe)",
    "Verify the nen binary against nen/contract.json's sha256",
    "Read the plugin stamp",
    "Regenerate every surface",
    "Detect drift",
    "Verify the regenerated tree passes its own drift check",
    "Open a pull request with the regenerated mirrors",
    "Delete the branch when the pull request could not be opened"
  ],
  # No exec-bit step: the guard runs as `sh "$guard"`, so the bit has no
  # subject, as in pr-readiness.yml.
  "prose-size-check.yml" => [
    "Start check on the exact PR head",
    "Checkout PR head (data only — nothing from here is executed)",
    "Checkout guard code from the trusted workflow revision",
    "Enforce workflow runner policy from trusted workflow revision",
    "Prose size guard",
    "Finish check on the exact PR head"
  ]
}.freeze

# THE PROSE-DIET GUARD, ON EVERY PULL REQUEST (zheref/hatsu#135). hanten/
# SKILL.md reached main over its ceiling because scripts/prose_size_check.sh
# ran only by hand and in its focused lane. prose-size-check.yml runs the
# TRUSTED revision's guard against the pull request's checkout as its root,
# its output fenced by `::stop-commands::` because file names come from the
# PR's tree; an offender fails the check, named by the guard with its size and
# ceiling. The step is FROZEN, so its one admitted form is this one. Its fence
# token must be a fresh one: a failed `openssl` would otherwise leave a token
# anyone can predict, so the step refuses to measure without one (Feitan,
# hanten on #135).
PROSE_WORKFLOW = "prose-size-check.yml"
PROSE_GUARD_STEP = "Prose size guard"
PROSE_FROZEN_GUARD = {
  "shell" => "bash",
  "run" => <<~'RUN'.strip
    set -uo pipefail
    guard=.trusted/scripts/prose_size_check.sh
    [ -f "$guard" ] || { echo "::error::trusted workflow revision has no scripts/prose_size_check.sh"; exit 1; }
    stop="stop_$(openssl rand -hex 16)" || stop=""
    [[ "$stop" =~ ^stop_[0-9a-f]{32}$ ]] || { echo "::error::could not draw a fresh token to fence the guard's output; nothing was measured."; exit 1; }
    code=0
    echo "::stop-commands::${stop}"
    sh "$guard" --headroom "$PWD" 2>&1 || code=$?
    printf '\n::%s::\n' "$stop"
    case "$code" in
      0) echo "every measured file is within its prose ceiling." ;;
      1)
        echo "::error::a file is over its prose ceiling, or could not be measured; each offender is named above, an OVER row with its size and ceiling. Diet the file; ceilings are not raised (zheref/hatsu#119)."
        exit 1
        ;;
      *)
        echo "::error::the prose guard could not run (exit ${code}), a wiring refusal: scripts/prose_size_check.sh's header names every cause. See its output above."
        exit 1
        ;;
    esac
  RUN
}.freeze

# ONE STEP SHAPE EACH, FROZEN, after the two-step landing (docs/GATE-
# CONFIGURATION.md, 2026-09-20): step one (zheref/hatsu#193) taught `main`'s
# trusted copy of this validator the next shapes beside the current ones; step
# two flipped the live workflows and narrowed this table back to one shape.
#
# pr-readiness.yml (zheref/hatsu#160): the bespoke freshness step is gone,
# because `nen pr ready --require-head` pins the judgement to the event head and
# exits 8 on a mismatch -- closing the window the step only approximated. Its
# guarantee lives in the verdict step, so the verdict and Publish steps are
# admitted ONLY in the exact, frozen forms below (READINESS_FROZEN_VERDICT,
# READINESS_FROZEN_PUBLISH): a verdict without the flags fails the guard.
#
# FROZEN, NOT PATTERN-MATCHED, for the reason the cleanup step below is: a
# per-invocation matcher over the run let an unpinned `pr ready` through spelled
# `pr  ready`, `pr "ready"`, `pr $sub`, a function, eval, `bash -c`, a here-doc
# or `printf -v`, with the flags only in a trailing comment, an env prefix or
# another argument; an EVENT_HEAD regex missed eval, a for loop, an array
# element, a quoted export, a nameref, `printf -v "EVENT_HEAD"`, `source <(...)`
# and getopts; and an extra `--exclude-check` dropped a real check (hanten,
# Nobunaga N01b-N16, E01-E08). Each closes as a byte inequality. The run is
# compared WHOLE, comment lines included: `code_of` would admit a `#` line
# inserted after a `\` continuation, which bash reads as a comment ending the
# `pr ready` call before its pinning flags. The bodies carry no comments of
# their own, so their prose lives in the YAML comments above each step.
#
# The verdict pins the evaluation to the event head and drops this workflow's
# own prior `readiness` check by its exact name. Exit 8 is nen's head-mismatch
# answer, no verdict: the arm titles the check `superseded`, asserts nothing,
# and the step still exits 0, so the run for the new head is the one that
# counts. Publish no longer reads the dropped step's output.
# EVERY STEP OF pr-readiness.yml IS FROZEN, not only the verdict and Publish
# (hanten round 1 on step two: Feitan, Nobunaga, Phinks; the v0.78.0 promise).
# Freezing two bodies byte for byte did not decide what ran INSIDE them: an
# earlier, unfrozen step could still write BASH_ENV into $GITHUB_ENV through a
# name assembled at run time (`printenv | sed`, `eval "$GITHUB_E""NV"`, a glob
# over `$RUNNER_TEMP/_runner_file_comm*`), set RUBYOPT or PATH in its own env,
# pick another `shell:`, call a local `uses:` action, or have the bootstrap
# step print a PR-checkout path as `bin` -- which the frozen verdict then runs
# as $NEN with GH_TOKEN. A text check cannot see every spelling of those, so
# the job has exactly ONE admitted form: each step below, compared key for key
# and the run byte for byte, exactly as require_frozen_step compares the verdict.
# Only `name` and the YAML comments above each step are free.
READINESS_FROZEN_HEAD_CHECKOUT = {
  "uses" => "actions/checkout@v7",
  "with" => {
    "ref" => "${{ github.event.pull_request.head.sha }}",
    "persist-credentials" => "false"
  }
}.freeze
READINESS_FROZEN_TRUSTED_CHECKOUT = {
  "uses" => "actions/checkout@v7",
  "with" => {
    "ref" => "${{ github.event.pull_request.base.sha }}",
    "path" => ".trusted",
    "persist-credentials" => "false"
  }
}.freeze
READINESS_FROZEN_POLICY = {
  "shell" => "bash",
  "run" => <<~'RUN'.strip
    set -euo pipefail
    ruby .trusted/scripts/workflow_runner_policy_check.rb --self-test "$PWD"
  RUN
}.freeze
READINESS_FROZEN_PIN = {
  "id" => "pin",
  "shell" => "bash",
  "run" => <<~'RUN'.strip
    set -euo pipefail
    ref="$(jq -r '.dependency.pinned_ref // empty' .trusted/nen/contract.json)"
    [ -n "$ref" ] || { echo "::error::nen/contract.json carries no dependency.pinned_ref."; exit 1; }
    case "$ref" in
      *..*|*//*) echo "::error::dependency.pinned_ref '$ref' is not a valid git ref (contains '..' or '//')."; exit 1 ;;
    esac
    if [[ ! "$ref" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]{0,99}$ ]]; then
      echo "::error::dependency.pinned_ref is not a plain git ref ([A-Za-z0-9][A-Za-z0-9._/-]{0,99}); refusing to use it in a URL or a shell."
      exit 1
    fi
    echo "ref=$ref" >> "$GITHUB_OUTPUT"
    echo "pinned nen ref: $ref"
  RUN
}.freeze
READINESS_FROZEN_BOOTSTRAP = {
  "id" => "nen",
  "env" => {
    "PINNED_REF" => "${{ steps.pin.outputs.ref }}"
  },
  "shell" => "bash",
  "run" => <<~'RUN'.strip
    set -euo pipefail
    ref="$PINNED_REF"
    url="https://raw.githubusercontent.com/zheref/nen/${ref}/bootstrap/nen.sh"
    curl -fsSL "$url" -o "${RUNNER_TEMP}/nen-bootstrap.sh"
    bin="$(bash "${RUNNER_TEMP}/nen-bootstrap.sh" --ref "$ref")"
    [ -x "$bin" ] || { echo "::error::bootstrap printed '$bin', which is not executable."; exit 1; }
    echo "bin=$bin" >> "$GITHUB_OUTPUT"
    echo "nen: $("$bin" --version) at $bin"
  RUN
}.freeze
# THE BOOTSTRAPPED BINARY, HASHED AGAINST THE CONTRACT (zheref/hatsu#230). The
# bootstrap script checks the binary against SHA256SUMS from the SAME release,
# so a moved tag or replaced assets verify against themselves. The contract
# records each platform's binary digest (dependency.bootstrap.sha256), and only
# scripts/nen_global.sh read it. This step hashes the binary the bootstrap
# printed and compares it with the TRUSTED copy's linux-x64 digest (every job
# here is ubuntu), failing closed on a mismatch or a missing or malformed key
# with both digests named. A malformed value is printed with every character
# outside [0-9A-Za-z] as `?`, so even the trusted file cannot start a log line
# with a workflow command. The builder's copy reads main's own checkout.
#
# NOTHING RUNS THE BINARY BEFORE IT MATCHES (hanten on #230: Nobunaga,
# Feitan). The bootstrap step printed `nen --version`, running the binary
# before this step could check it. Beside this step the bootstrap prints only
# the path (NEN_BOOTSTRAP_NEXT), and this step prints the version last, after
# the match; the old order, a version printed before the check, is refused.
# The contract is tested before it is read, a failed hash fails by name, and
# the value is read whole (`jq -j` and a sentinel), so a trailing newline that
# `$( )` would strip cannot pass as a digest (Nobunaga, Phinks).
#
# Landed in two steps (docs/GATE-CONFIGURATION.md): step one admitted each of
# the three workflows in two shapes -- as it was, or with this step and the
# bootstrap's next form; step two put them in the live files and narrowed
# Hatsu's own shapes to carrying them, frozen. Tenkai's rendered readiness
# form never carries the step: a product repository's contract need not
# record nen's digest, so rendering one is tenkai's change.
NEN_DIGEST_STEP = "Verify the nen binary against trusted nen/contract.json's sha256"
NEN_DIGEST_FROZEN = {
  "env" => {
    "NEN_BIN" => "${{ steps.nen.outputs.bin }}"
  },
  "shell" => "bash",
  "run" => <<~'RUN'.strip
    set -euo pipefail
    [ -f "$NEN_BIN" ] || { echo "::error::no bootstrapped nen binary to hash at '${NEN_BIN}'."; exit 1; }
    [ -f .trusted/nen/contract.json ] || { echo "::error::no trusted nen/contract.json to read the expected sha256 from."; exit 1; }
    observed="$(sha256sum "$NEN_BIN")" || { echo "::error::could not hash the bootstrapped nen binary at '${NEN_BIN}'."; exit 1; }
    observed="${observed%% *}"
    expected="$(jq -j '.dependency.bootstrap.sha256["linux-x64"] // empty' .trusted/nen/contract.json 2>/dev/null && printf .)" || expected=""
    expected="${expected%.}"
    if [[ ! "$expected" =~ ^[0-9a-f]{64}$ ]]; then
      shown="${expected//[^0-9A-Za-z]/?}"
      echo "::error::trusted nen/contract.json records no well-formed dependency.bootstrap.sha256[\"linux-x64\"]: expected 64 lowercase hex characters, found '${shown:0:80}'; observed ${observed}."
      exit 1
    fi
    if [ "$observed" != "$expected" ]; then
      echo "::error::the bootstrapped nen binary does not match trusted nen/contract.json: expected sha256 ${expected}, observed ${observed}."
      exit 1
    fi
    echo "nen binary sha256 ${observed} matches trusted nen/contract.json (linux-x64)."
    echo "nen: $("$NEN_BIN" --version) at $NEN_BIN"
  RUN
}.freeze
# The bootstrap step's form beside the digest step: the same body without the
# line that ran the binary (`--version`) before it was checked. All three
# workflows bootstrap with one body, so one next form fits each.
NEN_BOOTSTRAP_VERSION_LINE = %q{echo "nen: $("$bin" --version) at $bin"}
NEN_BOOTSTRAP_NEXT = READINESS_FROZEN_BOOTSTRAP.merge(
  "run" => READINESS_FROZEN_BOOTSTRAP.fetch("run").sub("\n#{NEN_BOOTSTRAP_VERSION_LINE}", "")
).freeze
# The builder's form: the same body, reading the contract in main's checkout.
REGENERATE_NEN_DIGEST_STEP = "Verify the nen binary against nen/contract.json's sha256"
REGENERATE_NEN_DIGEST_FROZEN = NEN_DIGEST_FROZEN.merge(
  "run" => NEN_DIGEST_FROZEN.fetch("run").gsub(".trusted/nen/contract.json", "nen/contract.json")
                                         .gsub("trusted nen/contract.json", "nen/contract.json")
).freeze
# Where the digest step sits, by workflow: validate_workflow freezes it
# wherever it appears and refuses it in tenkai's rendered form.
NEN_DIGEST_STEPS = {
  "surface-mirror-check.yml" => [NEN_DIGEST_STEP, NEN_DIGEST_FROZEN],
  "pr-readiness.yml" => [NEN_DIGEST_STEP, NEN_DIGEST_FROZEN],
  "surface-mirror-regenerate.yml" => [REGENERATE_NEN_DIGEST_STEP, REGENERATE_NEN_DIGEST_FROZEN]
}.freeze

READINESS_VERDICT_STEP = "Readiness verdict"
READINESS_PUBLISH_STEP = "Publish the check on the exact PR head"
READINESS_FROZEN_VERDICT = {
  "id" => "verdict",
  "env" => {
    "GH_TOKEN" => "${{ github.token }}",
    "NEN" => "${{ steps.nen.outputs.bin }}",
    "REPO" => "${{ github.repository }}",
    "PR" => "${{ github.event.pull_request.number }}",
    "RUN_ID" => "${{ github.run_id }}",
    "EVENT_HEAD" => "${{ github.event.pull_request.head.sha }}"
  },
  "shell" => "bash",
  "run" => <<~'RUN'.strip
    set -uo pipefail
    explain="$("$NEN" pr ready "$PR" --gh-repo "$REPO" --explain \
      --gates "$PWD/.trusted/nen/gates.json" \
      --exclude-run "$RUN_ID" \
      --exclude-check readiness \
      --require-head "$EVENT_HEAD" 2>&1)" || rc=$?
    rc="${rc:-0}"
    nonce="stop_$(openssl rand -hex 16)"
    echo "::stop-commands::${nonce}"
    printf '%s\n' "$explain"
    echo "::${nonce}::"
    title="$(printf '%s\n' "$explain" | head -1)"
    title="${title#*: }"
    case "$rc" in
      0) title="ready — ${title}" ;;
      1) : ;;
      8)
        title="superseded — the head moved while this run was evaluating"
        explain="A newer commit was pushed before this run finished, so its verdict would have described a different tree. The run for the new head publishes the verdict that counts. Nothing is asserted about this SHA."
        ;;
      *) title="readiness undetermined — nen exited ${rc}" ;;
    esac
    title="${title:0:240}"
    d="EOF_$(openssl rand -hex 16)"
    {
      printf 'title<<%s\n%s\n%s\n' "$d" "$title" "$d"
      printf 'summary<<%s\n%s\n%s\n' "$d" "$explain" "$d"
    } >> "$GITHUB_OUTPUT"
  RUN
}.freeze
READINESS_FROZEN_PUBLISH = {
  "if" => "${{ always() }}",
  "env" => {
    "GH_TOKEN" => "${{ github.token }}",
    "REPO" => "${{ github.repository }}",
    "HEAD_SHA" => "${{ github.event.pull_request.head.sha }}",
    "TITLE" => "${{ steps.verdict.outputs.title }}",
    "SUMMARY" => "${{ steps.verdict.outputs.summary }}"
  },
  "shell" => "bash",
  "run" => <<~'RUN'.strip
    set -euo pipefail
    title="${TITLE:-readiness undetermined — the verdict step did not report}"
    summary="${SUMMARY:-The readiness step did not complete. Nothing is asserted about this PR.}"
    gh api --method POST "repos/${REPO}/check-runs" \
      -f name=readiness \
      -f head_sha="$HEAD_SHA" \
      -f status=completed \
      -f conclusion=success \
      -f "output[title]=${title}" \
      -f "output[summary]=${summary}" >/dev/null
    echo "readiness: ${title}"
  RUN
}.freeze
# Name -> frozen form, in EXPECTED_STEPS order: every step of the job.
READINESS_FROZEN_STEPS = {
  "Checkout PR head (data only — nothing from here is executed)" => READINESS_FROZEN_HEAD_CHECKOUT,
  "Checkout guard code from the trusted workflow revision" => READINESS_FROZEN_TRUSTED_CHECKOUT,
  "Enforce workflow runner policy from trusted workflow revision" => READINESS_FROZEN_POLICY,
  "Read the pinned nen ref from trusted nen/contract.json" => READINESS_FROZEN_PIN,
  "Bootstrap nen at the trusted pinned ref (checksum-verified, two steps, never a pipe)" => NEN_BOOTSTRAP_NEXT,
  NEN_DIGEST_STEP => NEN_DIGEST_FROZEN,
  READINESS_VERDICT_STEP => READINESS_FROZEN_VERDICT,
  READINESS_PUBLISH_STEP => READINESS_FROZEN_PUBLISH
}.freeze
#
# THE RENDERED FORM -- the second, and only other, admitted pr-readiness.yml
# (Copilot on HA-PR-#211). tenkai renders templates/pr-readiness.yml into a
# process repository, which carries a copy of this validator (tenkai § 5d), and
# four of that rendering's steps are not Hatsu's own: both checkouts pin
# actions/checkout by commit SHA, the policy step tolerates a missing guard for
# a repository that adopted before carrying one, and the pin step validates the
# contract's shape and may fall back to the ref tenkai rendered. Freezing only
# Hatsu's form refused that rendering at its first step, so a process
# repository that followed § 5d (land this validator, then re-render) would
# have failed its own trusted policy step before reaching the verdict.
#
# It is frozen exactly like the first: every key, the run byte for byte. The
# ONLY free values are tenkai's three render-time placeholders, each held to
# the values tenkai writes (RENDERED_ENV_VALUES) and, together, to the two
# role pairs it renders (TENKAI_RENDERED_PAIRS). The job is ONE form or the
# other, never a mix: the head checkout's `uses:` selects the form and every
# step is then compared against that form alone. The SHA-pinned checkout and
# the TENKAI_* env keys are admitted in pr-readiness.yml only -- no other
# workflow's allowlist grows. The bootstrap, verdict and Publish steps are
# identical in both forms. Where the root carries templates/pr-readiness.yml
# (Hatsu itself), the self-test renders it for both roles and validates the
# result, so the template and these constants cannot drift apart unseen.
READINESS_RENDERED_CHECKOUT = "actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1"
# A first refusal only: TENKAI_RENDERED_PAIRS below admits two boolean pairs
# and nothing else, so it subsumes this pattern (a mutant loosening it alone
# survives the self-test by design).
TENKAI_BOOLEAN = /\A(?:true|false)\z/.freeze
# The pin step's own ref shape: a plain git ref, never '..' or '//'.
TENKAI_PLAIN_REF = %r{\A(?!.*\.\.)(?!.*//)[A-Za-z0-9][A-Za-z0-9._/-]{0,99}\z}.freeze
# [TENKAI_GUARD_REQUIRED, TENKAI_PIN_FALLBACK_ALLOWED]: process, product.
TENKAI_RENDERED_PAIRS = [%w[true false], %w[false true]].freeze
READINESS_RENDERED_HEAD_CHECKOUT = READINESS_FROZEN_HEAD_CHECKOUT.merge("uses" => READINESS_RENDERED_CHECKOUT).freeze
READINESS_RENDERED_TRUSTED_CHECKOUT = READINESS_FROZEN_TRUSTED_CHECKOUT.merge("uses" => READINESS_RENDERED_CHECKOUT).freeze
READINESS_RENDERED_POLICY = {
  "env" => {
    "TENKAI_GUARD_REQUIRED" => TENKAI_BOOLEAN
  },
  "shell" => "bash",
  "run" => <<~'RUN'.strip
    set -euo pipefail
    if [ -f .trusted/scripts/workflow_runner_policy_check.rb ]; then
      ruby .trusted/scripts/workflow_runner_policy_check.rb --self-test "$PWD"
    elif [ "$TENKAI_GUARD_REQUIRED" = true ]; then
      echo "::error::The process repository's trusted workflow guard is missing."
      exit 1
    else
      echo "::notice::No repository workflow guard is installed; Tenkai checks the rendered workflow at adoption."
    fi
  RUN
}.freeze
READINESS_RENDERED_PIN = {
  "id" => "pin",
  "env" => {
    "TENKAI_PIN_FALLBACK_ALLOWED" => TENKAI_BOOLEAN,
    "TENKAI_FALLBACK_REF" => TENKAI_PLAIN_REF
  },
  "shell" => "bash",
  "run" => <<~'RUN'.strip
    set -euo pipefail
    ref=""
    if [ -f .trusted/nen/contract.json ]; then
      if ! ref="$(jq -r '
        if type != "object" then error("root must be an object")
        elif has("dependency") and (.dependency | type) != "object" then error("dependency must be an object")
        elif (.dependency.pinned_ref | type) != "string" and (.dependency.pinned_ref | type) != "null" then error("dependency.pinned_ref must be a string")
        elif .dependency.pinned_ref == "" then error("dependency.pinned_ref must not be empty")
        else .dependency.pinned_ref // empty end
      ' .trusted/nen/contract.json)"; then
        echo "::error::Trusted nen/contract.json is malformed or unreadable."
        exit 1
      fi
    fi
    if [ -z "$ref" ] && [ "$TENKAI_PIN_FALLBACK_ALLOWED" = true ]; then
      ref="$TENKAI_FALLBACK_REF"
      echo "Using the Nen ref rendered from Hatsu's dependency contract: $ref"
    fi
    [ -n "$ref" ] || { echo "::error::nen/contract.json carries no dependency.pinned_ref."; exit 1; }
    case "$ref" in
      *..*|*//*) echo "::error::dependency.pinned_ref '$ref' is not a valid git ref (contains '..' or '//')."; exit 1 ;;
    esac
    if [[ ! "$ref" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]{0,99}$ ]]; then
      echo "::error::dependency.pinned_ref is not a plain git ref ([A-Za-z0-9][A-Za-z0-9._/-]{0,99}); refusing to use it in a URL or a shell."
      exit 1
    fi
    echo "ref=$ref" >> "$GITHUB_OUTPUT"
    echo "pinned nen ref: $ref"
  RUN
}.freeze
READINESS_RENDERED_STEPS = READINESS_FROZEN_STEPS.reject { |name, _| name == NEN_DIGEST_STEP }.merge(
  "Checkout PR head (data only — nothing from here is executed)" => READINESS_RENDERED_HEAD_CHECKOUT,
  "Checkout guard code from the trusted workflow revision" => READINESS_RENDERED_TRUSTED_CHECKOUT,
  "Enforce workflow runner policy from trusted workflow revision" => READINESS_RENDERED_POLICY,
  "Read the pinned nen ref from trusted nen/contract.json" => READINESS_RENDERED_PIN,
  # Tenkai's template keeps the bootstrap that prints the version: it carries
  # no digest step to print it after (zheref/hatsu#230).
  "Bootstrap nen at the trusted pinned ref (checksum-verified, two steps, never a pipe)" => READINESS_FROZEN_BOOTSTRAP
).freeze
READINESS_RENDERED_USES = [READINESS_RENDERED_CHECKOUT].freeze
READINESS_RENDERED_ENV = %w[TENKAI_GUARD_REQUIRED TENKAI_PIN_FALLBACK_ALLOWED TENKAI_FALLBACK_REF].freeze
#
# surface-mirror-regenerate.yml (zheref/hatsu#165): create-pull-request pushes
# its branch BEFORE asking GitHub for the PR, so a repository whose "Allow
# GitHub Actions to create and approve pull requests" toggle is off strands
# bot/surface-mirror-regenerate. That toggle cannot be read first: GET
# /repos/{owner}/{repo}/actions/permissions/workflow needs the repository
# Administration (read) permission, which GITHUB_TOKEN cannot be granted; only a
# secret-held GitHub App installation token or a personal access token could read
# it, and this job declines to hold one (SEC-9). So the frozen shape gives the PR
# step `id: cpr` and adds one cleanup step after it, admitted only in the exact,
# frozen form validate_builder_workflow checks (REGENERATE_CLEANUP).
REGENERATE_CLEANUP_STEP = "Delete the branch when the pull request could not be opened"
# The cleanup step has exactly ONE legitimate form, so it is FROZEN rather than
# pattern-matched: a substring test ("-X DELETE" somewhere, every git/refs token
# the bot ref) admitted an extra write, an assembled ref path, a `${{ }}`
# injection, a DELETE only in a comment and a token sent off-host (hanten,
# Feitan G1-G5). Its condition reads the PR step's own outcome, so a failure of
# the verify step BEFORE the PR step never deletes a branch an earlier run's PR
# still uses. It fails visible, never `|| true`: the first line names the toggle
# on EVERY failure of the PR step -- the likeliest cause, and the one a
# successful delete would otherwise hide -- and the second deletes the branch or
# says to delete it by hand.
REGENERATE_PR_STEP_ID = "cpr"
REGENERATE_CLEANUP = {
  "if" => "failure() && steps.cpr.outcome == 'failure'",
  "env" => { "GH_TOKEN" => "${{ github.token }}", "REPO" => "${{ github.repository }}" },
  "shell" => "bash",
  "run" => <<~'RUN'.strip
    echo "::error::the regeneration PR could not be opened; if GitHub Actions is not permitted to create pull requests, turn on Settings → Actions → General → Allow GitHub Actions to create and approve pull requests"
    gh api -X DELETE "repos/${REPO}/git/refs/heads/bot/surface-mirror-regenerate" || echo "::error::could not delete bot/surface-mirror-regenerate; delete it by hand"
  RUN
}.freeze
# EVERY STEP OF surface-mirror-regenerate.yml BUT THE PULL REQUEST STEP IS
# FROZEN (zheref/hatsu#190), as every step of pr-readiness.yml is. The job
# holds `contents: write` over a checkout that keeps its credential, and its
# only push guard was lexical: `git -C . push origin HEAD:refs/tags/v9.9.9` or
# `gh api -X DELETE repos/${REPO}/git/refs/heads/<any>` added to any run step
# passed it (Feitan, hanten on the #160/#165 step-one PR, fixture P0), and the
# `main` ruleset guards no other ref. So each step has ONE admitted form, held
# by require_frozen_step: its keys, `env`, `if`, `id`, `shell`, a checkout's
# `with`, and the run WHOLE, comment lines included -- `code_of` would admit a
# `#` line after a `\` continuation, which bash reads as ending the call, and
# the regenerate step has continuations. Only `name` and the YAML comments are
# free, so changing a body (a generate flag, a hooks root) is a two-step
# landing (docs/GATE-CONFIGURATION.md). The pull request step is a `uses:` step;
# its pin, condition, id and branch are held in validate_builder_workflow.
REGENERATE_FROZEN_STEPS = {
  "Checkout main" => {
    "uses" => "actions/checkout@v7",
    "with" => {
      "ref" => "main"
    }
  },
  "Read the pinned nen ref from nen/contract.json" => {
    "id" => "pin",
    "shell" => "bash",
    "run" => <<~'RUN'.strip
      set -euo pipefail
      ref="$(jq -r '.dependency.pinned_ref // empty' nen/contract.json)"
      [ -n "$ref" ] || { echo "::error::nen/contract.json carries no dependency.pinned_ref."; exit 1; }
      case "$ref" in
        *..*|*//*) echo "::error::dependency.pinned_ref '$ref' is not a valid git ref (contains '..' or '//')."; exit 1 ;;
      esac
      if [[ ! "$ref" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]{0,99}$ ]]; then
        echo "::error::dependency.pinned_ref is not a plain git ref ([A-Za-z0-9][A-Za-z0-9._/-]{0,99}); refusing to use it in a URL or a shell."
        exit 1
      fi
      echo "ref=$ref" >> "$GITHUB_OUTPUT"
      echo "pinned nen ref: $ref"
    RUN
  },
  "Bootstrap nen at the pinned ref (checksum-verified, two steps, never a pipe)" => NEN_BOOTSTRAP_NEXT,
  REGENERATE_NEN_DIGEST_STEP => REGENERATE_NEN_DIGEST_FROZEN,
  "Read the plugin stamp" => {
    "id" => "stamp",
    "shell" => "bash",
    "run" => <<~'RUN'.strip
      set -euo pipefail
      stamp="$(awk -F'"' '/"version"[[:space:]]*:/ { for (i = 1; i <= NF; i++) { if ($i == "version") { print $(i + 2); exit } } }' .claude-plugin/plugin.json)"
      [ -n "$stamp" ] || { echo "::error::.claude-plugin/plugin.json carries no readable version."; exit 1; }
      echo "value=$stamp" >> "$GITHUB_OUTPUT"
    RUN
  },
  "Regenerate every surface" => {
    "env" => {
      "NEN" => "${{ steps.nen.outputs.bin }}",
      "STAMP" => "${{ steps.stamp.outputs.value }}"
    },
    "shell" => "bash",
    "run" => <<~'RUN'.strip
      set -euo pipefail
      for surface in codex cursor antigravity; do
        case "$surface" in
          antigravity) root='${HATSU_PLUGIN_ROOT:-${GEMINI_CONFIG_DIR:-$HOME/.gemini}/config/plugins/hatsu}' ;;
          codex) root='${PLUGIN_ROOT:-${HATSU_PLUGIN_ROOT:-./.codex}}' ;;
          cursor) root='${HATSU_PLUGIN_ROOT:-./.cursor}' ;;
        esac
        "$NEN" surface mirror generate \
          --source claude/skills \
          --agents claude/agents \
          --surface "$surface" \
          --out "surfaces/$surface" \
          --models nen/workflow.json \
          --permissions contracts/permissions.json \
          --hooks hooks/hooks.json \
          --rules claude/rules/hatsu.md \
          --source-surface claude \
          --hooks-root "$root" \
          --manifest .claude-plugin/plugin.json \
          --stamp "$STAMP" \
          --invocation-prefix "hatsu:"
      done
    RUN
  },
  "Detect drift" => {
    "id" => "drift",
    "shell" => "bash",
    "run" => <<~'RUN'.strip
      set -euo pipefail
      if [ -n "$(git status --porcelain -- surfaces/)" ]; then
        echo "dirty=true" >> "$GITHUB_OUTPUT"
        {
          echo "changed<<SURFACE_DRIFT_EOF"
          git status --porcelain -- surfaces/
          echo "SURFACE_DRIFT_EOF"
        } >> "$GITHUB_OUTPUT"
      else
        echo "dirty=false" >> "$GITHUB_OUTPUT"
      fi
    RUN
  },
  "Verify the regenerated tree passes its own drift check" => {
    "if" => "steps.drift.outputs.dirty == 'true'",
    "env" => {
      "NEN_BIN" => "${{ steps.nen.outputs.bin }}"
    },
    "shell" => "bash",
    "run" => <<~'RUN'.strip
      set -euo pipefail
      bash scripts/surface_mirror_check.sh "$PWD"
    RUN
  },
  REGENERATE_CLEANUP_STEP => REGENERATE_CLEANUP
}.freeze

# THE PULL REQUEST STEP, HELD SHORT OF FROZEN (hanten on #190, Feitan). It is a
# `uses:` step, so validate_builder_workflow checks its pin, condition and id;
# its keys are exactly these, its `with` carries exactly these inputs, and each
# input's value is fixed but `body`'s, which is free prose. No `with` value
# reaches a shell: create-pull-request takes each as data, so an expression in
# `body` is a value, never code.
REGENERATE_PR_KEYS = %w[name id if uses with].freeze
REGENERATE_PR_WITH = {
  "commit-message" => "chore(surfaces): regenerate mirrors",
  "branch" => "bot/surface-mirror-regenerate",
  "delete-branch" => "true",
  "title" => "chore(surfaces): regenerate mirrors",
  "body" => nil
}.freeze

# One shape each, and a second for pr-readiness.yml: tenkai's rendered form,
# which carries no digest step. Hatsu's own form must carry it, because its
# every step is held in READINESS_FROZEN_STEPS (zheref/hatsu#230).
# surface-mirror-check.yml gains "Canon data contracts check" after the drift step
# (zheref/hatsu#223, the two-step landing: this revision admits the next shape
# beside the current one AND freezes the step's one form, so the pull request
# that adds the step to the workflow is judged by a validator that already
# holds its exact body; that pull request narrows EXPECTED_STEPS to the new
# shape). The step runs the TRUSTED nen's own validators (`direct registry`,
# `classify labels`, `classify install --dry-run`) over the pull request's data
# through the TRUSTED scripts/canon_contracts_check.sh, `NEN` the bootstrapped
# binary's absolute path and `--root "$PWD"` the PR checkout; nothing from the
# PR checkout is executed, and the guard's output is fenced between
# `::stop-commands::<token>` and the token so no line in it is a workflow
# command (hanten on #223, Feitan). The shape is anchored to the drift step by
# its name: a renamed drift step fails this file's own self-test below, never
# silently collapses the two shapes.
CANON_CONTRACTS_STEP = "Canon data contracts check"
CANON_CONTRACTS_AFTER = "Surface-mirror drift check"
CANON_CONTRACTS_FROZEN = {
  "env" => {
    "NEN_BIN" => "${{ steps.nen.outputs.bin }}"
  },
  "shell" => "bash",
  "run" => <<~'RUN'.strip
    set -uo pipefail
    guard=.trusted/scripts/canon_contracts_check.sh
    [ -f "$guard" ] || { echo "::error::trusted workflow revision has no scripts/canon_contracts_check.sh"; exit 1; }
    [ -f "$NEN_BIN" ] || { echo "::error::no bootstrapped nen binary at '${NEN_BIN}'."; exit 1; }
    stop="stop_$(openssl rand -hex 16)"
    code=0
    echo "::stop-commands::${stop}"
    NEN="$NEN_BIN" bash "$guard" --root "$PWD" 2>&1 || code=$?
    printf '\n::%s::\n' "$stop"
    case "$code" in
      0) echo "the canon data contracts hold every stated invariant." ;;
      1) echo "::error::a canon data contract breaks an invariant nen states (contracts/direct.registry.json, contracts/classify.taxonomy.json or nen/labels.json) — see the guard output above."; exit 1 ;;
      *) echo "::error::canon_contracts_check could not run (exit ${code}) — see the guard output above."; exit 1 ;;
    esac
  RUN
}.freeze
ALLOWED_STEP_SHAPES = EXPECTED_STEPS.transform_values { |steps| [steps] }.merge(
  "pr-readiness.yml" => [EXPECTED_STEPS.fetch("pr-readiness.yml"), EXPECTED_STEPS.fetch("pr-readiness.yml") - [NEN_DIGEST_STEP]],
  "surface-mirror-check.yml" => [
    EXPECTED_STEPS.fetch("surface-mirror-check.yml"),
    EXPECTED_STEPS.fetch("surface-mirror-check.yml").flat_map { |step| step == CANON_CONTRACTS_AFTER ? [step, CANON_CONTRACTS_STEP] : [step] }
  ]
).freeze

# surface-mirror-regenerate.yml's own trigger shape. `nil` marks an event that
# carries no further keys at all (`workflow_dispatch: {}` — a bare mapping
# with nothing inside it, not `types:`); every other event names its expected
# sub-keys and their exact values.
BUILDER_TRIGGERS = {
  "surface-mirror-regenerate.yml" => {
    "workflow_dispatch" => nil,
    "push" => { "branches" => %w[main], "paths" => REGENERATE_PATHS }
  }
}.freeze

# The exact workflow-level `permissions:` this builder needs and no more:
# `contents: write` to push its branch, `pull-requests: write` to open the PR.
# Nothing here ever touches `checks:` — that is the PR-targeting workflows'
# concern, not a push-to-main builder's.
BUILDER_PERMISSIONS = {
  "surface-mirror-regenerate.yml" => { "contents" => "write", "pull-requests" => "write" }
}.freeze

# EVERY PER-WORKFLOW TABLE COVERS EXACTLY THE WORKFLOWS IT SHOULD (Chrollo,
# hanten on #135). A registration that misses one table -- a workflow in
# neither cancel-in-progress list, which validate_concurrency would accept in
# silence -- stops this script at load, before it judges anything.
PR_WORKFLOWS = (PORTABLE_HOSTED_WORKFLOWS + PENDING_HOSTED_WORKFLOWS).freeze
{
  "EXPECTED_JOBS" => [EXPECTED_JOBS.keys, KNOWN_WORKFLOWS],
  "EXPECTED_STEPS" => [EXPECTED_STEPS.keys, KNOWN_WORKFLOWS],
  "ALLOWED_JOB_GUARDS" => [ALLOWED_JOB_GUARDS.keys, PR_WORKFLOWS],
  "BASE_TYPES" => [BASE_TYPES.keys, PR_WORKFLOWS],
  "HARDENED_TYPES" => [HARDENED_TYPES.keys, PR_WORKFLOWS],
  "CHECK_CREATION" => [CHECK_CREATION.keys, PR_WORKFLOWS],
  "BUILDER_TRIGGERS" => [BUILDER_TRIGGERS.keys, BUILDER_WORKFLOWS],
  "BUILDER_PERMISSIONS" => [BUILDER_PERMISSIONS.keys, BUILDER_WORKFLOWS],
  "the two cancel-in-progress lists" => [CANCEL_IN_PROGRESS_REQUIRED + CANCEL_IN_PROGRESS_FORBIDDEN, KNOWN_WORKFLOWS]
}.each do |table, (have, want)|
  next if have.sort == want.sort
  abort "workflow-runner-policy: #{table} covers #{have.sort.join(", ")}, not #{want.sort.join(", ")}: a workflow's registration is incomplete"
end

# Workflows that read a dependency pin and then fetch+execute a bootstrap from a
# URL built out of it. The pin MUST come from the trusted workflow checkout: a PR
# that can edit the pin can choose the binary that judges it. Keyed by the step's
# declared NAME, not its index -- an index silently pointed at the wrong step when
# pr-readiness.yml (no exec-bit step) shifted everything up by one.
TRUSTED_PIN_STEP = "Read the pinned nen ref from trusted nen/contract.json"
# Steps whose `run` must carry an exact argument. Same reason: nen 0.10.0 falls
# back to <cwd>/nen/gates.json when --gates is absent, and the cwd in these jobs
# is the PR HEAD checkout -- so a dropped flag hands the PR the gate that judges
# it, and reads like a harmless simplification.
# An argument is required ON THE INVOCATION, not merely present in the step. A
# substring test is satisfied by `echo --gates "$PWD/.trusted/nen/gates.json"`
# while the real call omits the flag and nen falls back to <cwd>/nen/gates.json --
# the PR's own copy. So each entry names the command that must carry it.
REQUIRED_STEP_ARGS = {
  "pr-readiness.yml" => {
    "Readiness verdict" => { invocation: "pr ready", argument: '--gates "$PWD/.trusted/nen/gates.json"' }
  }
}.freeze

# A `run:` scalar with its COMMENT LINES REMOVED. Every assertion below matches
# against this, never the raw scalar. `include?` on the raw text proves only that
# a string appears SOMEWHERE -- a PR can satisfy it from a comment or an unrelated
# `echo` while the executable line reads the PR's own copy, which is precisely the
# bypass these guards exist to stop. This repository's own workflow headers quote
# these paths in prose, so the bypass vector is present by construction, not
# hypothetical.
# Is the occurrence at `index` inside a DIAGNOSTIC command -- an `echo`/`printf`
# that merely names the file -- rather than a command that opens it?
#
# SCOPED TO THE COMMAND SEGMENT, not to the whole line, and that distinction is
# the finding this answers. Testing "does echo appear anywhere before the match"
# exempts `echo ok; cat nen/gates.json`, where the second command really does
# read the PR-controlled file. So the line is split on shell command separators
# and only the segment containing the occurrence is considered.
# Every construct that can RUN a command. `$(...)` and backticks are command
# substitution; `<(...)` and `>(...)` are process substitution, which runs its
# body in a subshell and is easy to miss because it contains no `$`.
# Every construct through which a "diagnostic" can actually touch a file.
# `$(...)` and backticks are command substitution; `<(...)`/`>(...)` are process
# substitution. PLAIN REDIRECTION belongs here too and was missed: `echo <
# nen/gates.json` runs no sub-command and still makes the shell open the
# PR-controlled file, and `<<<` is the same in here-string form. `>` is included
# for the mirror case -- a "diagnostic" that writes to a taxonomy path is not a
# diagnostic either.
EXECUTING_CONSTRUCTS = ["$(", "`", "<(", ">(", "<", ">"].freeze

def diagnostic_at?(line, index)
  start = 0
  # `&&` is listed before the single-character class so it wins at the same
  # position; a BARE `&` is a separator in its own right -- `echo ok & cat
  # nen/gates.json` runs `cat` -- and omitting it left the whole line reading as
  # one `echo` segment.
  line.scan(/\|\||&&|[;|&]/) do
    match = Regexp.last_match
    break if match.begin(0) > index
    start = match.end(0)
  end
  # Leading `{`, `(` and whitespace are grouping, not the command word.
  segment = line[start...index].to_s.sub(/\A[\s({]+/, "")
  # NO FORM OF SHELL EXECUTION IS A DIAGNOSTIC, even inside `echo`. The command
  # word alone is not enough: `echo "ref=$(jq -r .dependency.pinned_ref
  # nen/contract.json)"` begins with `echo`, but the substitution performs a real
  # read and emits its value -- and `echo > >(cat nen/gates.json)` does the same
  # through a PROCESS substitution, which carries neither `$(` nor a backtick.
  # Enumerated as one list rather than patched per form, because this has now
  # been wrong twice and the next form would have been a third fix.
  return false if EXECUTING_CONSTRUCTS.any? { |form| segment.include?(form) }
  !(segment =~ /\A(echo|printf)\b/).nil?
end

def code_of(run)
  return "" unless run
  run.lines.reject { |line| line.strip.start_with?("#") }.join
end

# Taxonomy files that decide how a privileged job behaves: the dependency pin
# selects the BINARY, and the gates file selects the REVIEWER IDENTITIES. In a
# pull_request_target job the cwd is the PR HEAD checkout, so an unprefixed read
# is the PR's own copy -- a PR choosing the binary, or the gate, that judges it.
TRUSTED_ONLY_DATA = %w[nen/contract.json nen/gates.json].freeze

# Refs that denote a revision the pull request cannot control. `github.sha` is
# trusted on `pull_request_target` (last commit on the default branch) but NOT on
# `pull_request_review`, where it is the last MERGE COMMIT ON THE PR BRANCH -- so
# a workflow subscribing to review events must use the base SHA, which is trusted
# on every admitted event. Found by the automated reviewer on #78.
BASE_SHA_REF = "${{ github.event.pull_request.base.sha }}".freeze
GITHUB_SHA_REF = "${{ github.sha }}".freeze

# `github.sha` is trusted ONLY when the workflow subscribes to nothing but
# `pull_request_target`, where it is the last commit on the default branch. The
# moment a review event is added it becomes the last MERGE COMMIT ON THE PR
# BRANCH, and checking that out loads PR-controlled content into a job holding a
# credential. So the admissible trusted refs depend on the trigger set, and this
# is conditional rather than a list.
def trusted_refs_for(events)
  events == ["pull_request_target"] ? [BASE_SHA_REF, GITHUB_SHA_REF] : [BASE_SHA_REF]
end

# The ONLY spellings that denote the trusted checkout: `.trusted/` at the start of
# the token, optionally rooted at $PWD, optionally opened by a quote. Anything
# else -- a sibling `attacker.trusted/`, a traversal `../.trusted/` -- is refused.
TRUSTED_PREFIX = %r{\A["']?(?:\$PWD/|\$\{PWD\}/)?\.trusted/\z}.freeze

# Messages carry PR-controlled text (workflow file names, step names) and are
# printed in the trusted policy step, outside any `::stop-commands::` window.
# A file named `x\n::warning title=forged::y.yml` would otherwise start a log
# line with a workflow command (hanten on step two, Feitan SEC-7), so every
# control character is printed escaped, never raw.
def fail_policy(message)
  safe = message.to_s.gsub(/[\x00-\x1f\x7f]/) { |c| format("\\x%02x", c.ord) }
  warn "workflow-runner-policy: #{safe}"
  raise SystemExit, 1
end

def mapping(node, context)
  fail_policy("#{context} must be a mapping") unless node.is_a?(Psych::Nodes::Mapping)
  result = {}
  node.children.each_slice(2) do |key, value|
    fail_policy("#{context} repeats key #{key.value.inspect}") if result.key?(key.value)
    result[key.value] = value
  end
  result
end

# A merge key (`<<:`) or an alias (`*name`) makes a mapping's keys or a value
# something other than what the node in front of this validator says: `<<:
# {GH_HOST: attacker.invalid}` adds an env var no key spells, and an alias node
# carries no value at all. No workflow here uses either, so both are refused by
# name rather than crashing the readers below (hanten, Nobunaga N24).
def reject_duplicate_keys(node, context = "workflow")
  case node
  when Psych::Nodes::Mapping
    seen = {}
    node.children.each_slice(2) do |key, value|
      fail_policy("#{context} carries a non-scalar mapping key") unless key.is_a?(Psych::Nodes::Scalar)
      fail_policy("#{context} uses a YAML merge key (<<:), which this policy does not admit") if key.value == "<<"
      fail_policy("#{context} repeats key #{key.value.inspect}") if seen[key.value]
      seen[key.value] = true
      reject_duplicate_keys(value, "#{context}.#{key.value}")
    end
  when Psych::Nodes::Sequence
    node.children.each_with_index { |child, index| reject_duplicate_keys(child, "#{context}[#{index}]") }
  when Psych::Nodes::Alias
    fail_policy("#{context} uses a YAML alias (*#{node.anchor}), which this policy does not admit")
  end
end

def scalar(node)
  return nil if node.nil?
  fail_policy("expected a plain value, found a YAML #{node.class.name.split("::").last.downcase}") unless node.is_a?(Psych::Nodes::Scalar)
  node.value
end

# A step with exactly ONE legitimate form: the keys are name plus the frozen
# hash's own, and every value is equal byte for byte -- the run compared WHOLE,
# comment lines included, never through code_of.
def require_frozen_step(step, frozen, label)
  fail_policy("#{label} is missing") unless step
  allowed = (["name"] + frozen.keys).sort
  fail_policy("#{label} may carry only #{allowed.join(", ")}") unless step.keys.sort == allowed
  frozen.each do |key, value|
    if value.is_a?(Hash)
      # `env` and a checkout's `with`: an exact mapping, every key and every
      # value, so an added RUBYOPT/PATH/BASH_ENV or a moved ref is a byte
      # inequality like any other. A Regexp value is one of tenkai's render-time
      # placeholders (READINESS_RENDERED_STEPS): the key is still exact, and
      # the value must match the pattern whole.
      actual = mapping(step[key], "#{label} #{key}").transform_values { |node| scalar(node) }
      fail_policy("#{label} #{key} must carry exactly #{value.keys.join(", ")}") unless actual.keys.sort == value.keys.sort
      value.each do |name, want|
        ok = want.is_a?(Regexp) ? actual[name].is_a?(String) && want.match?(actual[name]) : actual[name] == want
        fail_policy("#{label} #{key} #{name} must be exactly the frozen form") unless ok
      end
      next
    end
    actual = if key == "run"
               scalar(step["run"]).to_s.strip
             else
               scalar(step[key])
             end
    fail_policy("#{label} #{key} must be exactly the frozen form") unless actual == value
  end
end

# The YAML text of a frozen step, as the self-test writes it and step 2 copies
# it: `name`, then the frozen keys in their own order, the run as a `|` block.
def render_step(name, frozen)
  text = +"      - name: #{name}\n"
  frozen.each do |key, value|
    case key
    when "env", "with" then text << "        #{key}:\n" << value.map { |var, val| "          #{var}: #{val}\n" }.join
    when "run" then text << "        run: |\n" << value.lines.map { |line| "          #{line.chomp}\n" }.join
    else text << "        #{key}: #{value}\n"
    end
  end
  text
end

# A TRIPWIRE, NOT THE BOUNDARY. A line appended to $GITHUB_ENV becomes every
# later step's environment (`BASH_ENV=./x.sh` makes bash source a PR-checkout
# file before even a frozen body), and a line appended to $GITHUB_PATH puts a
# PR directory ahead of `nen`, `gh` and `openssl`. No workflow here needs
# either, so a LITERAL mention in a run -- comment lines included, since a text
# check cannot tell a write from a quote -- is refused, with the runner's
# file-command directory and `${!` indirection. THAT IS ALL IT CATCHES: a name
# assembled at run time (`printenv | sed -n 's/^GITHUB_E.V=//p'`, `eval` over
# `"$GITHUB_E""NV"`, a glob over `$RUNNER_TEMP/_runner_file_comm*`) passes it
# (hanten on step two: Feitan, Nobunaga, Phinks). The control that closes those
# is structural: in pr-readiness.yml every step is frozen (READINESS_FROZEN_
# STEPS), so no step can carry such a line at all; in the other workflows the
# step keys, `uses:`, `shell:` and env keys are held to exact allowlists below.
# A step-level `BASH_ENV` or `ENV` is refused here within its own step.
ENV_FILE_COMMANDS = /GITHUB_ENV|GITHUB_PATH|_runner_file_commands|\$\{!/.freeze
def refuse_env_writes(path, step)
  name = scalar(step["name"]).inspect
  if scalar(step["run"]).to_s.match?(ENV_FILE_COMMANDS)
    fail_policy("#{path} step #{name} touches $GITHUB_ENV, $GITHUB_PATH or an indirect expansion; " \
                "a later step, frozen or not, would inherit what it writes (BASH_ENV, PATH)")
  end
  return unless step["env"]
  keys = mapping(step["env"], "#{path} step #{name} env").keys
  bad = keys & %w[BASH_ENV ENV]
  fail_policy("#{path} step #{name} sets #{bad.join(", ")}, which makes bash source a file first") unless bad.empty?
end

# AN EXPRESSION IN A RUN IS SHELL SOURCE (zheref/hatsu#190). Actions substitutes
# every `${{ }}` in a `run:` before bash parses it -- in a bash comment line
# too -- so `${{ github.event.head_commit.message }}` there is script
# injection: a quote or a newline in the message becomes code. A value reaches
# a run through the step's `env:`, which no quoting can escape, and no
# workflow here writes an expression into a run, so ANY `${{` in one is
# refused: `github.event.*`, and `github.head_ref`, `inputs.*` and step
# outputs with it, in every workflow, the frozen ones included.
def refuse_run_expressions(path, step)
  return unless scalar(step["run"]).to_s.include?("${{")
  fail_policy("#{path} step #{scalar(step["name"]).inspect} writes a ${{ }} expression into its run, which " \
              "Actions substitutes into the shell source before bash parses it; pass the value through env")
end

# THE EXACT-HEAD CHECK RUN, FROZEN AT BOTH ENDS (Phinks QA-18, hanten on #135).
# A `:start` workflow creates its check in_progress and finishes it with the
# job's status mapped: success, cancelled, and failure for anything else. The
# pattern checks let `*) conclusion=failure` become success, a check be created
# already completed and green, and `cancelled` map to success, each through
# --self-test, so both steps are held in one form; the check's name is the one
# free value, and it is the job's own.
EXACT_HEAD_START_RUN = <<~'RUN'.strip
  set -euo pipefail
  id="$(gh api --method POST "repos/${REPO}/check-runs" -f name=@CHECK@ -f head_sha="$HEAD_SHA" -f status=in_progress --jq .id)"
  echo "id=$id" >> "$GITHUB_OUTPUT"
RUN
def exact_head_start(check)
  {
    "id" => "head_check",
    "env" => {
      "GH_TOKEN" => "${{ github.token }}",
      "REPO" => "${{ github.repository }}",
      "HEAD_SHA" => "${{ github.event.pull_request.head.sha }}"
    },
    "shell" => "bash",
    "run" => EXACT_HEAD_START_RUN.sub("@CHECK@", check)
  }
end
EXACT_HEAD_FINISH = {
  "if" => "${{ always() && steps.head_check.outputs.id != '' }}",
  "env" => {
    "GH_TOKEN" => "${{ github.token }}",
    "REPO" => "${{ github.repository }}",
    "CHECK_ID" => "${{ steps.head_check.outputs.id }}",
    "JOB_STATUS" => "${{ job.status }}"
  },
  "shell" => "bash",
  "run" => <<~'RUN'.strip
    set -euo pipefail
    case "$JOB_STATUS" in
      success) conclusion=success ;;
      cancelled) conclusion=cancelled ;;
      *) conclusion=failure ;;
    esac
    gh api --method PATCH "repos/${REPO}/check-runs/${CHECK_ID}" -f status=completed -f conclusion="$conclusion" >/dev/null
  RUN
}.freeze

# EXACT ALLOWLISTS for the shape of every job and step, in every workflow this
# policy validates. A job key outside the list (`container:`, `services:`,
# `env:`, `defaults:`, `strategy:`) changes where or how every step runs; a step
# key outside it (`continue-on-error`, `working-directory`, `timeout-minutes`)
# changes what a failure means; a `uses:` other than the pinned entries runs an
# action this policy never read -- `./.github/actions/x` would run from the PR
# checkout -- and a `shell:` other than plain bash (`bash --rcfile ./x.sh -i
# {0}`) sources a file before the run. An env key outside the list (RUBYOPT,
# PATH, LD_PRELOAD, NODE_OPTIONS, ...) loads code into the step's interpreter.
# The lists are the keys these workflows use today and nothing else.
PR_JOB_KEYS = %w[if runs-on timeout-minutes steps].freeze
BUILDER_JOB_KEYS = %w[runs-on timeout-minutes steps].freeze
STEP_KEYS = %w[name id if env shell run uses with].freeze
ADMITTED_USES = [
  "actions/checkout@v7",
  "peter-evans/create-pull-request@22a9089034f40e5a961c8808d113e2c98fb63676"
].freeze
ADMITTED_STEP_ENV = %w[
  GH_TOKEN REPO HEAD_SHA PR BASE_SHA PR_BODY CHECK_ID JOB_STATUS PINNED_REF NEN_BIN
  NEN STAMP RUN_ID EVENT_HEAD TITLE SUMMARY
].freeze
# `extra_uses` / `extra_env`: admitted for ONE workflow's job only -- the
# rendered pr-readiness.yml's SHA-pinned checkout and TENKAI_* keys -- so no
# other workflow's allowlist grows.
def refuse_unadmitted_step_shapes(path, job_name, job, step_maps, job_keys, extra_uses: [], extra_env: [])
  extra = job.keys - job_keys
  fail_policy("#{path} job #{job_name} carries #{extra.join(", ")}, which this policy does not admit (#{job_keys.join(", ")} only)") unless extra.empty?
  step_maps.each do |step|
    name = scalar(step["name"]).inspect
    extra = step.keys - STEP_KEYS
    fail_policy("#{path} step #{name} carries #{extra.join(", ")}, which this policy does not admit") unless extra.empty?
    if step.key?("uses")
      uses = scalar(step["uses"])
      fail_policy("#{path} step #{name} uses #{uses.inspect}, which is not an admitted action (#{ADMITTED_USES.join(", ")})") unless (ADMITTED_USES + extra_uses).include?(uses)
      fail_policy("#{path} step #{name} both runs and uses an action") if step.key?("run")
    end
    if step.key?("run")
      fail_policy("#{path} step #{name} must declare shell: bash, exactly") unless scalar(step["shell"]) == "bash"
    elsif step.key?("shell")
      fail_policy("#{path} step #{name} declares a shell with nothing to run")
    end
    next unless step["env"]
    keys = mapping(step["env"], "#{path} step #{name} env").keys
    bad = keys - ADMITTED_STEP_ENV - extra_env
    fail_policy("#{path} step #{name} sets env #{bad.join(", ")}, which is not on the admitted list") unless bad.empty?
  end
end

def sequence(node, context)
  fail_policy("#{context} must be a sequence") unless node.is_a?(Psych::Nodes::Sequence)
  node.children.map(&:value)
end

def reject_write_permissions(node, context)
  return unless node
  mapping(node, context).each do |name, value|
    fail_policy("#{context} grants #{name}: write") if scalar(value) == "write" && name != "checks"
  end
end

def same_repository?(repository, head_repository)
  repository == "zheref/hatsu" && head_repository == repository
end

# --- validate_concurrency PATH ROOT ------------------------------------------
# Shared by both pipelines. `group` is required on every workflow this policy
# knows about — an ungrouped guard or builder can run arbitrarily many copies
# of itself concurrently, which is exactly the race
# `surface-mirror-regenerate.yml`'s own `cancel-in-progress: false` posture is
# there to avoid on the builder side, and burns runner minutes needlessly on
# the guard side. Whether `cancel-in-progress: true` is REQUIRED or FORBIDDEN
# is per-workflow (see CANCEL_IN_PROGRESS_REQUIRED / _FORBIDDEN); a workflow in
# neither list is not reachable here (every known workflow is in exactly one).
def validate_concurrency(path, root)
  basename = File.basename(path)
  concurrency = mapping(root.fetch("concurrency") { fail_policy("#{path} has no concurrency block") }, "#{path} concurrency")
  fail_policy("#{path} concurrency must declare a group") unless concurrency.key?("group")
  extra = concurrency.keys - %w[group cancel-in-progress]
  fail_policy("#{path} concurrency has unexpected keys #{extra.inspect}") unless extra.empty?
  cancel = concurrency.key?("cancel-in-progress") ? scalar(concurrency["cancel-in-progress"]) : nil
  if CANCEL_IN_PROGRESS_REQUIRED.include?(basename)
    fail_policy("#{path} concurrency must set cancel-in-progress: true") unless cancel == "true"
  elsif CANCEL_IN_PROGRESS_FORBIDDEN.include?(basename)
    fail_policy("#{path} concurrency must not set cancel-in-progress: true — it is a builder, not a PR guard, and cancelling it mid-run risks a half-written surfaces/ tree") if cancel == "true"
  end
end

# --- validate_timeout PATH JOB_NAME JOB -------------------------------------
# `timeout-minutes` is required on EVERY job this policy validates, PR-target
# or builder alike: an unbounded job is an unbounded credentialed runner
# minute, and the value itself is left to the workflow's own judgement (a
# guard's few minutes vs. a builder's regeneration) rather than fixed here.
def validate_timeout(path, job_name, job)
  timeout = job["timeout-minutes"]
  fail_policy("#{path} job #{job_name} needs timeout-minutes") unless timeout
  fail_policy("#{path} job #{job_name} timeout-minutes must be a positive integer") unless scalar(timeout) =~ /\A[1-9][0-9]*\z/
end

# `reason`, when given, must match the refusal fail_policy printed: a case
# that names a property asserts the refusal for that property, never merely a
# refusal (Feitan, hanten on #136).
def expect_rejected(label, reason = nil)
  captured = StringIO.new
  real_stderr = $stderr
  rejected = false
  begin
    $stderr = captured
    yield
  rescue SystemExit => error
    raise unless error.status == 1
    rejected = true
  ensure
    $stderr = real_stderr
    $stderr.write(captured.string)
  end
  fail_policy("#{label} was accepted") unless rejected
  return if reason.nil? || captured.string.match?(reason)
  fail_policy("#{label} was refused for another reason: #{captured.string.strip}")
end

# --- A HOSTILE FIXTURE CHANGES WHAT RUNS, OR STOPS AS BROKEN (zheref/hatsu#136)
# Most hostile fixtures edit a REAL workflow at a literal, and `String#sub`
# takes the FIRST occurrence -- which a comment can hold. On #134 a comment
# above surface-mirror-check.yml's pin step spelled the trusted contract path,
# the edit landed in the comment, the read it attacks was left as it was, and
# the case went red. That was the loud form. The quiet one is an edit
# redirected somewhere that still leaves the guard something to reject: the
# suite stays green while the case no longer tests what it names.
#
# So no occurrence is taken on trust. `fixture_sub` tries each in order and
# keeps the first whose edit changes what the parser and the shell see (YAML
# comments are not in the parse; fixture_code drops a run's comment text) --
# inside the one step the fixture names, and nowhere else, or outside every
# step when it names none. When no occurrence qualifies, the self-test stops
# as a BROKEN FIXTURE naming the case. Prose in a workflow may therefore spell
# any literal a fixture edits.

# A run as bash reads it, for the fixtures' comparisons only, never a verdict:
# each comment's text is dropped and its `#` kept, so a comment can neither
# hold a fixture's edit nor hide that one was added. A `#` opens a comment
# where bash's does -- at the start of a word, outside '...', "..." and
# ANSI-C $'...' quotes, escapes and `${...}`, with `$(...)` nesting tracked --
# and a heredoc's body is passed over as data, up to its delimiter line.
#
# It is a reader, not a parser, and it can still misread in two directions.
# Code read as a comment hides an edit, which stops the self-test as a broken
# fixture. A comment read as code can hold a fixture's edit again, and the
# case then fails as accepted or, if the guard refuses the edited comment
# too, passes having tested nothing. The causes known to do that are a `<<`
# shift inside `$(( ))`, taken for a heredoc; a `case` pattern's `)` inside a
# `$( )`, taken as its close; a heredoc delimiter that is quoted in part or
# begins with a digit; and backquotes, which are not tracked. No workflow
# here uses any of them (Nobunaga, hanten on #136).
def fixture_code(run)
  out = +""
  stack = [:code]
  heredocs = []
  prev = "\n"
  i = 0
  while i < run.length
    ch = run[i]
    state = stack.last
    if ch == "\n" && state == :code && !heredocs.empty?
      out << ch
      i += 1
      heredocs.each do |word, tabs|
        while i < run.length
          eol = run.index("\n", i) || run.length
          line = run[i...eol]
          out << run[i...[eol + 1, run.length].min]
          i = eol + 1
          break if (tabs ? line.sub(/\A\t+/, "") : line) == word
        end
      end
      heredocs.clear
      prev = "\n"
      next
    end
    heredoc = state == :code && run[i, 2] == "<<" && run[i + 2] != "<" &&
              run[i..-1].match(/\A<<(-?)[ \t]*(?:'([^'\n]*)'|"([^"\n]*)"|\\?([A-Za-z_][A-Za-z0-9_]*))/)
    opener = ch == "$" && { dq: %w[( {], code: %w[{ '], brace: %w[{ '] }.fetch(state, []).include?(run[i + 1])
    if state == :sq
      stack.pop if ch == "'"
    elsif ch == "\\" && i + 1 < run.length
      out << ch << run[i + 1]
      prev = run[i + 1]
      i += 2
      next
    elsif heredoc
      heredocs << [heredoc[2] || heredoc[3] || heredoc[4], heredoc[1] == "-"]
      out << heredoc[0]
      prev = heredoc[0][-1]
      i += heredoc[0].length
      next
    elsif opener
      stack.push({ "(" => :code, "{" => :brace, "'" => :ansi }.fetch(run[i + 1]))
      out << ch << run[i + 1]
      prev = run[i + 1]
      i += 2
      next
    elsif state == :ansi
      stack.pop if ch == "'"
    elsif state == :dq
      stack.pop if ch == '"'
    elsif ch == "#" && state == :code && prev.match?(/[\s;&|()<>]/)
      out << ch
      i += 1 while i < run.length && run[i] != "\n"
      prev = ch
      next
    elsif ch == "'" || ch == '"'
      stack.push(ch == "'" ? :sq : :dq)
    elsif ch == "("
      stack.push(:code)
    elsif (ch == ")" && state == :code && stack.length > 1) || (ch == "}" && state == :brace)
      stack.pop
    end
    out << ch
    prev = ch
    i += 1
  end
  out
end

# What the parser and the shell see of a workflow, comments gone: the node tree,
# quoting ignored, every `run` through fixture_code. `mask`, one step mapping,
# is left out of its sequence, so the rest can be compared without it.
def fixture_view(node, mask = nil, key = nil)
  case node
  when Psych::Nodes::Document then fixture_view(node.root, mask)
  when Psych::Nodes::Mapping
    [:map, node.anchor, node.tag, node.children.each_slice(2).map { |name, value|
      [fixture_view(name, mask), fixture_view(value, mask, name.is_a?(Psych::Nodes::Scalar) ? name.value : nil)]
    }]
  when Psych::Nodes::Sequence
    [:seq, node.anchor, node.tag, node.children.reject { |child| child.equal?(mask) }.map { |child| fixture_view(child, mask) }]
  when Psych::Nodes::Scalar then [:scalar, node.anchor, node.tag, key == "run" ? fixture_code(node.value) : node.value]
  when Psych::Nodes::Alias then [:alias, node.anchor]
  else [node.class.name]
  end
end

def fixture_key(node, key)
  return nil unless node.is_a?(Psych::Nodes::Mapping)
  pair = node.children.each_slice(2).find { |name, _| name.is_a?(Psych::Nodes::Scalar) && name.value == key }
  pair && pair.last
end

# Every step mapping under jobs.*.steps, as [name, node], in order.
def fixture_steps(document)
  jobs = fixture_key(document.root, "jobs")
  return [] unless jobs.is_a?(Psych::Nodes::Mapping)
  jobs.children.each_slice(2).flat_map do |_, job|
    steps = fixture_key(job, "steps")
    next [] unless steps.is_a?(Psych::Nodes::Sequence)
    steps.children.map do |step|
      name = fixture_key(step, "name")
      [name.is_a?(Psych::Nodes::Scalar) ? name.value : nil, step]
    end
  end
end

# Each place `from` (a String, or a Regexp whose `to` may be a lambda over the
# match) occurs in `text`, as [start, finish, replacement], in order.
def fixture_occurrences(text, from, to)
  found = []
  if from.is_a?(Regexp)
    text.scan(from) { match = Regexp.last_match; found << [match.begin(0), match.end(0), to.respond_to?(:call) ? to.call(match) : to] }
  else
    at = 0
    while (index = text.index(from, at))
      found << [index, index + from.length, to]
      at = index + 1
    end
  end
  found
end

# `base` with the first occurrence of `from` that changes the step named
# `step` -- adds, edits, moves or removes it -- and nothing else; or, with no
# step named, something outside every step and no step at all.
def fixture_sub(label, base, from, to, step: nil)
  before = Psych.parse(base)
  before_steps = fixture_steps(before)
  before_step = step && before_steps.find { |name, _| name == step }&.last
  before_view = fixture_view(before, before_step)
  fixture_occurrences(base, from, to).each do |start, finish, replacement|
    text = base[0...start] + replacement + base[finish..-1]
    after = begin
      Psych.parse(text)
    rescue Psych::SyntaxError
      next
    end
    after_steps = fixture_steps(after)
    if step
      after_step = after_steps.find { |name, _| name == step }&.last
      next if after_step.nil? && before_step.nil?
      if before_step && after_step && fixture_view(after_step) == fixture_view(before_step)
        # The same step, unedited: still a change if it MOVED.
        next if after_steps.index { |pair| pair.last.equal?(after_step) } == before_steps.index { |pair| pair.last.equal?(before_step) }
      end
      next unless fixture_view(after, after_step) == before_view
    else
      next unless after_steps.map { |_, node| fixture_view(node) } == before_steps.map { |_, node| fixture_view(node) }
      next if fixture_view(after) == before_view
    end
    return text
  end
  where = step ? "step #{step.inspect} and only it" : "the workflow outside its steps"
  fail_policy("self-test: BROKEN FIXTURE #{label.inspect}: no occurrence of #{from.inspect} outside a comment " \
              "changes #{where}, so the case would test nothing")
end

# A fixture built whole rather than by fixture_sub must still change what runs.
def fixture_changed!(label, base, text)
  return unless fixture_view(Psych.parse(text)) == fixture_view(Psych.parse(base))
  fail_policy("self-test: BROKEN FIXTURE #{label.inspect}: it changes nothing but comments, so the case would test nothing")
end

# `hatsu`: the root holds templates/pr-readiness.yml, the source of tenkai's
# rendered readiness form, so it is Hatsu's own repository.
def validate_workflow(path, hatsu: false)
  document = Psych.parse_file(path)
  reject_duplicate_keys(document.root, path)
  root = mapping(document.root, path)
  triggers = mapping(root.fetch("on") { fail_policy("#{path} has no on mapping") }, "#{path} on")
  expected_shapes = ALLOWED_TYPE_SHAPES.fetch(File.basename(path)) { fail_policy("#{path} has no declared trigger policy") }
  expected_events = expected_shapes.first.keys
  triggers.keys.each do |event|
    fail_policy("#{path} uses trigger #{event.inspect}, which is not an admitted privileged trigger") unless ALLOWED_TRIGGERS.include?(event)
  end
  fail_policy("#{path} trigger set changed") unless triggers.keys.sort == expected_events.sort
  expected_events.each do |event|
    trigger = mapping(triggers[event], "#{path} #{event}")
    trigger_types = sequence(trigger.fetch("types") { fail_policy("#{path} #{event} has no types") }, "#{path} #{event} types")
    allowed_types = expected_shapes.map { |shape| shape.fetch(event) }.uniq
    fail_policy("#{path} #{event} types changed") unless allowed_types.include?(trigger_types)
    # `paths:` is a declared, per-(workflow, event) EXTRA key — absent here
    # means FORBIDDEN, not merely unchecked. plugin-bump-check.yml and
    # pr-readiness.yml must judge every pull request, so they carry no filter;
    # surface-mirror-check.yml's own job only reads the surface-relevant tree,
    # so it may.
    expected_paths = EXPECTED_PATHS.dig(File.basename(path), event)
    allowed_keys = expected_paths ? %w[paths types] : %w[types]
    fail_policy("#{path} #{event} has unexpected keys") unless trigger.keys.sort == allowed_keys
    next unless expected_paths
    actual_paths = sequence(trigger.fetch("paths") { fail_policy("#{path} #{event} has no paths") }, "#{path} #{event} paths")
    fail_policy("#{path} #{event} paths changed") unless actual_paths == expected_paths
  end
  targets_pr = true
  reject_write_permissions(root["permissions"], "#{path} permissions")
  if targets_pr && scalar(mapping(root["permissions"], "#{path} permissions")["checks"]) != "write"
    fail_policy("#{path} needs only checks: write to publish the exact-head result")
  end
  validate_concurrency(path, root)

  jobs = mapping(root.fetch("jobs") { fail_policy("#{path} has no jobs mapping") }, "#{path} jobs")
  expected_job = EXPECTED_JOBS.fetch(File.basename(path)) { fail_policy("#{path} has no declared job policy") }
  fail_policy("#{path} job id must be exactly #{expected_job}") unless jobs.keys == [expected_job]
  jobs.each do |job_name, job_node|
    job = mapping(job_node, "#{path} job #{job_name}")
    allowed_guards = ALLOWED_JOB_GUARDS.fetch(File.basename(path)) { fail_policy("#{path} has no declared job guard") }
    if targets_pr && !allowed_guards.include?(scalar(job["if"]))
      shapes = allowed_guards.length > 1 ? "bare or with the draft-skip conjunction" : "with the draft-skip conjunction"
      fail_policy("#{path} job #{job_name} needs the same-repository job guard, #{shapes}")
    end

    validate_timeout(path, job_name, job)

    runner_node = job.fetch("runs-on") { fail_policy("#{path} job #{job_name} has no runs-on") }
    runner = runner_node.is_a?(Psych::Nodes::Sequence) ? sequence(runner_node, "runs-on") : scalar(runner_node)
    allowed = runner == MAC_RUNNER || runner == WINDOWS_RUNNER || runner == HOSTED_RUNNER
    fail_policy("#{path} job #{job_name} uses an unapproved runner #{runner.inspect}") unless allowed
    if (PORTABLE_HOSTED_WORKFLOWS + PENDING_HOSTED_WORKFLOWS).include?(File.basename(path)) && runner != HOSTED_RUNNER
      fail_policy("#{path} is portable and must use GitHub-hosted ubuntu-latest")
    end

    fail_policy("#{path} job #{job_name} must inherit workflow permissions") if job.key?("permissions")

    next unless targets_pr
    steps_node = job.fetch("steps") { fail_policy("#{path} job #{job_name} has no steps") }
    fail_policy("#{path} job #{job_name} steps must be a sequence") unless steps_node.is_a?(Psych::Nodes::Sequence)
    steps = steps_node.children
    step_maps = steps.each_with_index.map { |node, index| mapping(node, "#{path} job #{job_name} step #{index + 1}") }
    step_names = step_maps.map { |step| scalar(step["name"]) }
    fail_policy("#{path} job #{job_name} step set or order changed") unless ALLOWED_STEP_SHAPES.fetch(File.basename(path)).include?(step_names)
    # The readiness shape carries no freshness step: its guarantee is in the
    # verdict step, and EVERY step of the job is admitted only in its exact
    # frozen form (READINESS_FROZEN_STEPS), so no earlier step can reach the
    # verdict through the environment, the PATH, a shell or an action.
    extra_uses = []
    extra_env = []
    rendered = false
    # The nen digest step (zheref/hatsu#230) and the bootstrap beside it.
    digest_name, digest_frozen = NEN_DIGEST_STEPS[File.basename(path)]
    carries_digest = digest_name && step_names.include?(digest_name)
    bootstrap_step = step_maps.find { |step| scalar(step["name"]).to_s.start_with?("Bootstrap nen at ") }
    if File.basename(path) == "pr-readiness.yml"
      # ONE form for the whole job, selected by the head checkout's `uses:`:
      # Hatsu's own, or tenkai's rendering (READINESS_RENDERED_STEPS). Every
      # step is then compared against that form alone, so the two never mix.
      head_step = step_maps.find { |step| scalar(step["name"]) == READINESS_FROZEN_STEPS.keys.first }
      rendered = head_step && head_step.key?("uses") && scalar(head_step["uses"]) == READINESS_RENDERED_CHECKOUT
      # Tenkai's rendering carries no digest step, and Hatsu's own repository
      # carries only its own form, so no pull request there can trade the
      # checked bootstrap for the consumer's (Feitan, hanten on #230).
      if rendered && carries_digest
        fail_policy("#{path} tenkai's rendered readiness form carries no #{digest_name.inspect} step")
      end
      if rendered && hatsu
        fail_policy("#{path} is tenkai's rendered readiness form; Hatsu's own repository, which holds templates/pr-readiness.yml, carries only its own form")
      end
    end
    # Nothing runs the binary before the digest step has checked it: beside
    # that step, a bootstrap that still prints `--version` is the old order.
    if carries_digest && bootstrap_step && scalar(bootstrap_step["run"]).to_s.include?("--version")
      fail_policy("#{path} step #{scalar(bootstrap_step["name"]).inspect} runs the bootstrapped nen (--version) before #{digest_name.inspect} has checked it")
    end
    if File.basename(path) == "pr-readiness.yml"
      form = rendered ? READINESS_RENDERED_STEPS : READINESS_FROZEN_STEPS
      form = form.merge(scalar(bootstrap_step["name"]) => NEN_BOOTSTRAP_NEXT) if carries_digest && bootstrap_step
      kind = rendered ? "rendered" : "frozen"
      form.each do |name, frozen|
        require_frozen_step(step_maps.find { |step| scalar(step["name"]) == name }, frozen, "#{path} #{kind} readiness step #{name.inspect}")
      end
      if rendered
        guard = scalar(mapping(step_maps[2]["env"], "#{path} policy env")["TENKAI_GUARD_REQUIRED"])
        fallback = scalar(mapping(step_maps[3]["env"], "#{path} pin env")["TENKAI_PIN_FALLBACK_ALLOWED"])
        unless TENKAI_RENDERED_PAIRS.include?([guard, fallback])
          fail_policy("#{path} rendered readiness pairs TENKAI_GUARD_REQUIRED=#{guard} with TENKAI_PIN_FALLBACK_ALLOWED=#{fallback}, which tenkai never renders")
        end
        extra_uses = READINESS_RENDERED_USES
        extra_env = READINESS_RENDERED_ENV
      end
    end
    if File.basename(path) == PROSE_WORKFLOW
      require_frozen_step(step_maps.find { |step| scalar(step["name"]) == PROSE_GUARD_STEP }, PROSE_FROZEN_GUARD,
                          "#{path} #{PROSE_GUARD_STEP.inspect}")
    end
    # The canon-contracts step in its one admitted form wherever
    # surface-mirror-check.yml carries it (zheref/hatsu#223, step one).
    if File.basename(path) == "surface-mirror-check.yml" && step_names.include?(CANON_CONTRACTS_STEP)
      require_frozen_step(step_maps.find { |step| scalar(step["name"]) == CANON_CONTRACTS_STEP }, CANON_CONTRACTS_FROZEN,
                          "#{path} #{CANON_CONTRACTS_STEP.inspect}")
    end
    # The digest step in its one admitted form wherever a workflow carries it,
    # and the bootstrap beside it in the form the digest step selects.
    if carries_digest
      require_frozen_step(step_maps.find { |step| scalar(step["name"]) == digest_name }, digest_frozen, "#{path} #{digest_name.inspect}")
    end
    if digest_name && bootstrap_step
      require_frozen_step(bootstrap_step, carries_digest ? NEN_BOOTSTRAP_NEXT : READINESS_FROZEN_BOOTSTRAP,
                          "#{path} #{scalar(bootstrap_step["name"]).inspect}")
    end
    refuse_unadmitted_step_shapes(path, job_name, job, step_maps, PR_JOB_KEYS, extra_uses: extra_uses, extra_env: extra_env)
    starter = step_maps.first
    finisher = step_maps.last
    expected_check_name = File.basename(path) == "plugin-bump-check.yml" ? "check" : job_name
    exact_name = /(?:^|\s)-f name=#{Regexp.escape(expected_check_name)}(?:\s|$)/
    creation = CHECK_CREATION.fetch(File.basename(path)) { fail_policy("#{path} has no declared check-creation policy") }
    if creation == :start
      start_env = mapping(starter["env"], "#{path} exact-head check env")
      unless scalar(starter["id"]) == "head_check" && scalar(start_env["HEAD_SHA"]) == "${{ github.event.pull_request.head.sha }}" && scalar(starter["run"])&.match?(exact_name)
        fail_policy("#{path} job #{job_name} must create #{expected_check_name} on the exact event head before other work")
      end
      require_frozen_step(starter, exact_head_start(expected_check_name), "#{path} #{scalar(starter["name"]).inspect}")
    else
      # :end -- nothing may create the check before the work, and the FINAL step
      # must create it already completed against the exact event head.
      # ANY check-run creation, not just this name. nen treats a non-empty
      # all-green rollup as satisfying CON-32(a), so a check created early under
      # ANOTHER name -- or through a variable -- certifies the workflow just as
      # effectively as one named `readiness`.
      if step_maps[0...-1].any? { |step| code_of(scalar(step["run"])).include?("check-runs") }
        fail_policy("#{path} job #{job_name} declares :end check creation but touches check-runs before the final step")
      end
      finish_env = mapping(finisher["env"], "#{path} exact-head check env")
      finish_run = code_of(scalar(finisher["run"]))
      # The env var having the right VALUE proves nothing about the POST unless
      # the POST actually passes it, and a check published non-green would make
      # CON-32(a) unsatisfiable for everyone. Assert the payload, not just the
      # environment around it.
      unless scalar(finish_env["HEAD_SHA"]) == "${{ github.event.pull_request.head.sha }}" &&
             finish_run.match?(exact_name) &&
             finish_run.include?('head_sha="$HEAD_SHA"') &&
             finish_run.include?("conclusion=success")
        fail_policy("#{path} job #{job_name} must create #{expected_check_name} in its final step " \
                    "with head_sha=\"$HEAD_SHA\" and conclusion=success")
      end
    end
    # BOUND TO THE FROZEN NAME. Searching every step for the command let the
    # NAMED step be a no-op while the real invocation happened later, with
    # PR-influenced work in between -- a regression introduced when this stopped
    # being a positional index. EXPECTED_STEPS already freezes the name, so use it.
    policy_step_name = "Enforce workflow runner policy from trusted workflow revision"
    policy_step = step_maps.find { |step| scalar(step["name"]) == policy_step_name }
    fail_policy("#{path} job #{job_name} has no #{policy_step_name.inspect} step") unless policy_step
    unless scalar(policy_step["run"])&.include?('ruby .trusted/scripts/workflow_runner_policy_check.rb --self-test "$PWD"')
      fail_policy("#{path} job #{job_name} must invoke the trusted workflow policy before project work")
    end
    step_maps.each do |step|
      run = scalar(step["run"])
      if run&.match?(/(?:bash|ruby|source)\s+["']?(?:\.\/)?scripts\//)
        fail_policy("#{path} job #{job_name} executes a PR-root script instead of trusted code")
      end
    end
    # Generalised from a single hardcoded basename + positional index: EVERY
    # workflow that carries the pin step is held to sourcing it from trusted data.
    pin_step = step_maps.find { |step| scalar(step["name"]) == TRUSTED_PIN_STEP }
    if pin_step && !code_of(scalar(pin_step["run"])).include?(".trusted/nen/contract.json")
      fail_policy("#{path} must source its executable dependency pin from trusted workflow data")
    end
    # EVERY executable reference to a decision-bearing taxonomy file must be
    # .trusted/-prefixed, in EVERY step. This is what actually closes the bypass:
    # it is not enough that the trusted path appears somewhere, it must be the
    # case that no UNTRUSTED path appears anywhere executable.
    step_maps.each do |step|
      code_of(scalar(step["run"])).lines.each do |line|
        TRUSTED_ONLY_DATA.each do |data|
          offset = 0
          while (index = line.index(data, offset))
            offset = index + data.length
            prefix = line[0...index]
            # A DIAGNOSTIC IS NOT A READ -- but only within its OWN command. See
            # `diagnostic_at?`: a whole-line test would exempt
            # `echo ok; cat nen/gates.json`.
            next if diagnostic_at?(line, index)
            token = prefix[/\S*\z/].to_s
            # CANONICAL FORMS, NOT A SUFFIX. `token.end_with?(".trusted/")` also
            # accepted `attacker.trusted/nen/contract.json` and
            # `../.trusted/nen/contract.json` -- a PR-controlled sibling directory
            # and a traversal, both of which yield a token ending in `.trusted/`
            # and neither of which is the trusted checkout.
            next if token =~ TRUSTED_PREFIX
            fail_policy("#{path} step #{scalar(step["name"]).inspect} reads #{token}#{data} " \
                        "outside the trusted checkout; a pull_request_target job's cwd is the PR head")
          end
        end
      end
    end
    # A RELATIVE `.trusted/` ONLY MEANS SOMETHING IF THE CWD CANNOT MOVE. Without
    # this, a step may `cd` into a PR-controlled directory -- or create its own
    # `.trusted/` -- and every lexical check above still passes while reading
    # PR-supplied data. None of these workflows needs to change directory, so the
    # honest guard is to forbid it outright rather than to model it.
    # CONSERVATIVE, NOT POSITIONAL. Enumerating the places a `cd` can appear has
    # now been wrong twice -- `if cd evil; then` sits behind a keyword the
    # position list did not have. These workflows have no legitimate use for any
    # of these words, so ANY occurrence in executable code is refused. A blunt
    # rule that cannot be sidestepped beats a precise one that can.
    step_maps.each do |step|
      next unless code_of(scalar(step["run"])) =~ /\b(cd|pushd|popd|chdir)\b/
      fail_policy("#{path} step #{scalar(step["name"]).inspect} mentions a directory-changing " \
                  "command; the trusted-path checks are relative and a moved cwd defeats them")
    end
    # `working-directory` does the same thing declaratively, at THREE levels, and
    # was entirely unchecked.
    if root.key?("defaults")
      fail_policy("#{path} sets workflow defaults, which can carry working-directory")
    end
    # A workflow- or job-level `env:` reaches every step, so `BASH_ENV: ./x.sh`
    # there makes bash source a PR-checkout file before even a frozen run body.
    # No workflow here uses either level; each step names its own env.
    fail_policy("#{path} sets workflow-level env, which reaches every step (BASH_ENV)") if root.key?("env")
    jobs.each_value do |node|
      job_map = mapping(node, "#{path} job")
      fail_policy("#{path} job sets working-directory") if job_map.key?("defaults")
      fail_policy("#{path} job sets job-level env, which reaches every step (BASH_ENV)") if job_map.key?("env")
      steps_node = job_map["steps"]
      next unless steps_node.is_a?(Psych::Nodes::Sequence)
      steps_node.children.each do |step_node|
        step_map = mapping(step_node, "#{path} step")
        fail_policy("#{path} step #{scalar(step_map["name"]).inspect} sets working-directory") if step_map.key?("working-directory")
        refuse_env_writes(path, step_map)
        refuse_run_expressions(path, step_map)
      end
    end
    REQUIRED_STEP_ARGS.fetch(File.basename(path), {}).each do |step_name, spec|
      step = step_maps.find { |candidate| scalar(candidate["name"]) == step_name }
      fail_policy("#{path} has no step named #{step_name.inspect}") unless step
      # Logical commands: continuation lines joined, so a flag on its own
      # continuation still belongs to the invocation it continues.
      # SEGMENTS, NOT PHYSICAL LINES. `nen pr ready --gates "..."; nen pr ready`
      # is two invocations on one line and only the first carries the flag, so a
      # line-level test passes while the second call falls back to the PR's gates
      # file. Continuations are joined first, then each line is split on the same
      # command separators used elsewhere.
      commands = code_of(scalar(step["run"])).gsub(/\\\n/, " ")
                                             .lines
                                             .flat_map { |line| line.split(/\|\||&&|[;|&]/) }
      # The invocation is matched as a COMMAND, with a boundary, so `pr ready-fake`
      # is not mistaken for `pr ready`.
      invocation = /#{Regexp.escape(spec[:invocation])}(?:\s|\z)/
      invoking = commands.select do |command|
        command =~ invocation && !(command =~ /\A\s*(echo|printf)\b/)
      end
      if invoking.empty?
        fail_policy("#{path} step #{step_name.inspect} does not invoke #{spec[:invocation].inspect}")
      end
      invoking.each do |command|
        next if command.include?(spec[:argument])
        fail_policy("#{path} step #{step_name.inspect} invokes #{spec[:invocation].inspect} " \
                    "without #{spec[:argument]}; nen falls back to <cwd>/nen/gates.json, " \
                    "which in this job is the PR head checkout")
      end
    end
    if creation == :start
      unless scalar(finisher["if"]) == "${{ always() && steps.head_check.outputs.id != '' }}" && scalar(finisher["run"])&.include?("check-runs/${CHECK_ID}") && scalar(finisher["run"])&.include?("status=completed")
        fail_policy("#{path} job #{job_name} must always publish its final exact-head conclusion")
      end
      require_frozen_step(finisher, EXACT_HEAD_FINISH, "#{path} #{scalar(finisher["name"]).inspect}")
    else
      unless scalar(finisher["if"]) == "${{ always() }}" && scalar(finisher["run"])&.include?("status=completed")
        fail_policy("#{path} job #{job_name} must always publish a completed exact-head check, even when an earlier step failed")
      end
    end
    head_checkout = false
    trusted_checkout = false
    step_maps.each_with_index do |step, index|
      next unless scalar(step["uses"])&.start_with?("actions/checkout@")
      with = mapping(step["with"], "#{path} checkout step #{index + 1} with")
      fail_policy("#{path} checkout step #{index + 1} must set persist-credentials: false") unless scalar(with["persist-credentials"]) == "false"
      ref = scalar(with["ref"])
      head_checkout ||= ref == "${{ github.event.pull_request.head.sha }}"
      trusted_checkout ||= trusted_refs_for(triggers.keys.sort).include?(ref)
    end
    fail_policy("#{path} job #{job_name} must checkout the exact event head SHA") unless head_checkout
    unless trusted_checkout
      fail_policy("#{path} job #{job_name} must checkout a trusted revision " \
                  "(#{trusted_refs_for(triggers.keys.sort).join(" or ")}); on a review event " \
                  "github.sha is the PR branch's merge commit and is PR-controlled")
    end
  end
end

def validate_repo(root, announce: true)
  paths = Dir.glob(File.join(root, ".github/workflows/*.{yml,yaml}")).sort
  fail_policy("#{root} has no workflows") if paths.empty?
  basenames = paths.map { |path| File.basename(path) }
  missing = PORTABLE_HOSTED_WORKFLOWS - basenames
  fail_policy("#{root} is missing required workflows: #{missing.join(', ')}") unless missing.empty?
  unknown = basenames - KNOWN_WORKFLOWS
  fail_policy("#{root} carries undeclared workflow(s): #{unknown.join(', ')} — every workflow under .github/workflows/ needs a declared policy entry before it can be trusted") unless unknown.empty?
  paths.each do |path|
    if BUILDER_WORKFLOWS.include?(File.basename(path))
      validate_builder_workflow(path)
    else
      validate_workflow(path, hatsu: File.file?(File.join(root, "templates/pr-readiness.yml")))
    end
  end
  # Printed only when explicitly announced (the final, real invocation
  # outside self-test): self-test's OWN internal validate_repo(tmp) calls run
  # against a scratch copy mid-mutation, before the negative fixtures below
  # have even run, so a pass line from one of them read as the script's
  # verdict -- and, on a File.read encoding crash further down self_test, as
  # a pass line printed just before the process died with no verdict at all
  # (QA-21).
  puts "workflow-runner-policy: #{paths.length} workflows structurally valid" if announce
end

# --- validate_builder_workflow PATH -----------------------------------------
# The lighter pipeline for a push-to-main / workflow_dispatch BUILDER
# (currently only surface-mirror-regenerate.yml). It shares no PR checkout
# with a pull request, so it carries none of `validate_workflow`'s
# `.trusted/`-split machinery — there is no untrusted copy to defend against,
# because this job's cwd is `main` itself, checked out directly. What it MUST
# still prove: an exact, frozen trigger/permission/step shape; a bounded,
# non-cancelling concurrency group; and that it never pushes straight to
# `main` — every change to `surfaces/` reaches `main` only through the pull
# request this job opens, which `surface-mirror-check` then judges exactly
# like any other.
def validate_builder_workflow(path)
  document = Psych.parse_file(path)
  reject_duplicate_keys(document.root, path)
  root = mapping(document.root, path)
  basename = File.basename(path)

  triggers = mapping(root.fetch("on") { fail_policy("#{path} has no on mapping") }, "#{path} on")
  expected_triggers = BUILDER_TRIGGERS.fetch(basename)
  fail_policy("#{path} trigger set changed") unless triggers.keys.sort == expected_triggers.keys.sort
  expected_triggers.each do |event, expected|
    trigger_node = triggers[event]
    if expected.nil?
      empty = trigger_node.is_a?(Psych::Nodes::Mapping) && trigger_node.children.empty?
      empty ||= trigger_node.is_a?(Psych::Nodes::Scalar) && scalar(trigger_node).nil?
      fail_policy("#{path} #{event} must declare nothing") unless empty
      next
    end
    trigger = mapping(trigger_node, "#{path} #{event}")
    fail_policy("#{path} #{event} has unexpected keys") unless trigger.keys.sort == expected.keys.sort
    expected.each do |key, expected_value|
      actual_value = sequence(trigger.fetch(key) { fail_policy("#{path} #{event} has no #{key}") }, "#{path} #{event} #{key}")
      fail_policy("#{path} #{event} #{key} changed") unless actual_value == expected_value
    end
  end

  permissions = mapping(root.fetch("permissions") { fail_policy("#{path} has no permissions mapping") }, "#{path} permissions")
  expected_permissions = BUILDER_PERMISSIONS.fetch(basename)
  fail_policy("#{path} permissions changed") unless permissions.keys.sort == expected_permissions.keys.sort
  expected_permissions.each do |name, level|
    fail_policy("#{path} permissions.#{name} must be #{level}") unless scalar(permissions[name]) == level
  end

  validate_concurrency(path, root)

  jobs = mapping(root.fetch("jobs") { fail_policy("#{path} has no jobs mapping") }, "#{path} jobs")
  expected_job = EXPECTED_JOBS.fetch(basename)
  fail_policy("#{path} job id must be exactly #{expected_job}") unless jobs.keys == [expected_job]
  job = mapping(jobs[expected_job], "#{path} job #{expected_job}")

  # NO same-repository guard: `github.event.pull_request` does not exist on
  # `push`/`workflow_dispatch`, so the PR-targeting guard is not merely absent
  # here, it is inapplicable — a job condition referencing it would be null on
  # every event and therefore always skip.
  fail_policy("#{path} job #{expected_job} must not carry an if guard") if job.key?("if")

  runner = scalar(job.fetch("runs-on") { fail_policy("#{path} job #{expected_job} has no runs-on") })
  fail_policy("#{path} job #{expected_job} uses an unapproved runner #{runner.inspect}") unless runner == HOSTED_RUNNER

  fail_policy("#{path} job #{expected_job} must inherit workflow permissions") if job.key?("permissions")

  validate_timeout(path, expected_job, job)

  steps_node = job.fetch("steps") { fail_policy("#{path} job #{expected_job} has no steps") }
  fail_policy("#{path} job #{expected_job} steps must be a sequence") unless steps_node.is_a?(Psych::Nodes::Sequence)
  step_maps = steps_node.children.each_with_index.map { |node, index| mapping(node, "#{path} job #{expected_job} step #{index + 1}") }
  step_names = step_maps.map { |step| scalar(step["name"]) }
  fail_policy("#{path} job #{expected_job} step set or order changed") unless ALLOWED_STEP_SHAPES.fetch(basename).include?(step_names)
  refuse_unadmitted_step_shapes(path, expected_job, job, step_maps, BUILDER_JOB_KEYS)
  begin
    # Every step but the pull request step, in its one admitted form
    # (REGENERATE_FROZEN_STEPS, zheref/hatsu#190), the cleanup step included.
    # The digest step selects its bootstrap's form (hanten on #230): beside it
    # the bootstrap prints only the path, and a version printed there is the
    # old order, the binary run before it was checked.
    digest_name, digest_frozen = NEN_DIGEST_STEPS.fetch(basename)
    carries_digest = step_names.include?(digest_name)
    bootstrap_step = step_maps.find { |step| scalar(step["name"]).to_s.start_with?("Bootstrap nen at ") }
    if carries_digest && bootstrap_step && scalar(bootstrap_step["run"]).to_s.include?("--version")
      fail_policy("#{path} step #{scalar(bootstrap_step["name"]).inspect} runs the bootstrapped nen (--version) before #{digest_name.inspect} has checked it")
    end
    frozen_steps = REGENERATE_FROZEN_STEPS
    frozen_steps = frozen_steps.merge(scalar(bootstrap_step["name"]) => NEN_BOOTSTRAP_NEXT) if carries_digest && bootstrap_step
    frozen_steps.each do |name, frozen|
      require_frozen_step(step_maps.find { |step| scalar(step["name"]) == name }, frozen, "#{path} #{name.inspect}")
    end
    if carries_digest
      require_frozen_step(step_maps.find { |step| scalar(step["name"]) == digest_name }, digest_frozen, "#{path} #{digest_name.inspect}")
    end
    pr_with_id = step_maps.find { |step| scalar(step["name"]) == "Open a pull request with the regenerated mirrors" }
    unless pr_with_id && scalar(pr_with_id["id"]) == REGENERATE_PR_STEP_ID
      fail_policy("#{path} the pull request step must carry id: #{REGENERATE_PR_STEP_ID} for the cleanup condition to read")
    end
    # continue-on-error on the PR step keeps the job green when it fails, so
    # `failure()` never holds and the cleanup never runs: the branch strands
    # silently, the toggle unnamed (hanten, Nobunaga N25).
    if pr_with_id.key?("continue-on-error")
      fail_policy("#{path} the pull request step must not carry continue-on-error, which keeps the cleanup step from ever running")
    end
  end

  fail_policy("#{path} sets workflow defaults, which can carry working-directory") if root.key?("defaults")
  fail_policy("#{path} job sets working-directory") if job.key?("defaults")
  fail_policy("#{path} sets workflow-level env, which reaches every step (BASH_ENV)") if root.key?("env")
  fail_policy("#{path} job sets job-level env, which reaches every step (BASH_ENV)") if job.key?("env")
  step_maps.each do |step|
    code = code_of(scalar(step["run"]))
    fail_policy("#{path} step #{scalar(step["name"]).inspect} sets working-directory") if step.key?("working-directory")
    refuse_env_writes(path, step)
    refuse_run_expressions(path, step)
    if code =~ /\bgit\s+push\b/
      fail_policy("#{path} step #{scalar(step["name"]).inspect} pushes directly with git — this builder must only open a pull request onto bot/surface-mirror-regenerate")
    end
    if code =~ /\b(cd|pushd|popd|chdir)\b/
      fail_policy("#{path} step #{scalar(step["name"]).inspect} mentions a directory-changing command")
    end
  end

  pr_step_name = "Open a pull request with the regenerated mirrors"
  pr_step = step_maps.find { |step| scalar(step["name"]) == pr_step_name }
  fail_policy("#{path} has no #{pr_step_name.inspect} step") unless pr_step
  uses = scalar(pr_step["uses"])
  fail_policy("#{path} #{pr_step_name.inspect} must pin peter-evans/create-pull-request by a full 40-character commit SHA") unless uses =~ %r{\Apeter-evans/create-pull-request@[0-9a-f]{40}\z}
  fail_policy("#{path} #{pr_step_name.inspect} must run only when drift was detected") unless scalar(pr_step["if"]) == "steps.drift.outputs.dirty == 'true'"
  pr_with = mapping(pr_step["with"], "#{path} #{pr_step_name} with")
  fail_policy("#{path} #{pr_step_name.inspect} must target bot/surface-mirror-regenerate, never main") unless scalar(pr_with["branch"]) == "bot/surface-mirror-regenerate"
  fail_policy("#{path} #{pr_step_name.inspect} may carry only #{REGENERATE_PR_KEYS.join(", ")}") unless pr_step.keys.sort == REGENERATE_PR_KEYS.sort
  unless pr_with.keys.sort == REGENERATE_PR_WITH.keys.sort
    fail_policy("#{path} #{pr_step_name.inspect} with must carry exactly #{REGENERATE_PR_WITH.keys.join(", ")}")
  end
  REGENERATE_PR_WITH.each do |input, want|
    value = scalar(pr_with[input])
    next if want.nil? ? value.is_a?(String) : value == want
    fail_policy("#{path} #{pr_step_name.inspect} with #{input} must be exactly the frozen form")
  end

  checkout_steps = step_maps.select { |step| scalar(step["uses"])&.start_with?("actions/checkout@") }
  fail_policy("#{path} must checkout main") unless checkout_steps.any? { |step| scalar(mapping(step["with"], "#{path} checkout with")["ref"]) == "main" }
end

def self_test(root)
  # fail_policy prints PR-controlled names escaped: no raw newline can start a
  # log line with a workflow command (hanten on step two, Feitan SEC-7).
  begin
    real_stderr = $stderr
    $stderr = StringIO.new
    begin
      fail_policy("x\n::warning title=forged::y.yml\r")
    rescue SystemExit
      nil
    end
    printed = $stderr.string
  ensure
    $stderr = real_stderr
  end
  fail_policy("self-test: fail_policy printed a raw control character") unless printed.lines.length == 1 && !printed.chomp.match?(/[\x00-\x1f]/)
  # fixture_code against the quoting that hides a comment: each input as bash
  # reads it, the comment's text dropped and its `#` kept (hanten on #136).
  {
    %q{echo "a # b" # c} => %q{echo "a # b" #},
    %q{echo $'it\'s' # c} => %q{echo $'it\'s' #},
    %Q{cat <<'EOF'\nit's # data\nEOF\n# c\ntrue} => %Q{cat <<'EOF'\nit's # data\nEOF\n#\ntrue},
    %Q{cat <<-EOF\n\tit's\n\tEOF\necho ok # c} => %Q{cat <<-EOF\n\tit's\n\tEOF\necho ok #},
    %q{cat <<< "it's" # c} => %q{cat <<< "it's" #},
    %q{x=${#y} # c} => %q{x=${#y} #}
  }.each do |input, want|
    got = fixture_code(input)
    fail_policy("self-test: fixture_code read #{input.inspect} as #{got.inspect}, not #{want.inspect}") unless got == want
  end
  fail_policy("same-repository predicate rejected owner head") unless same_repository?("zheref/hatsu", "zheref/hatsu")
  fail_policy("same-repository predicate admitted fork") if same_repository?("zheref/hatsu", "fork/hatsu")
  fail_policy("same-repository predicate admitted missing head repository") if same_repository?("zheref/hatsu", nil)
  fail_policy("same-repository predicate admitted another repository") if same_repository?("other/repo", "other/repo")

  Dir.mktmpdir("hatsu-workflow-policy") do |tmp|
    FileUtils.mkdir_p(File.join(tmp, ".github/workflows"))
    Dir.glob(File.join(root, ".github/workflows/*.{yml,yaml}")).each { |path| FileUtils.cp(path, File.join(tmp, ".github/workflows")) }
    validate_repo(tmp, announce: false)
    # A workflow registered ahead of its file (PENDING_HOSTED_WORKFLOWS) is
    # staged at templates/<name> and judged there as if installed, so the pull
    # request that installs it meets a policy that already admits it
    # (docs/GATE-CONFIGURATION.md, the new-workflow rule).
    PENDING_HOSTED_WORKFLOWS.each do |name|
      staged = File.join(root, "templates", name)
      installed = File.join(tmp, ".github/workflows", name)
      next unless File.file?(staged) && !File.file?(installed)
      FileUtils.cp(staged, installed)
      validate_repo(tmp, announce: false)
      FileUtils.rm(installed)
    end

    plugin = File.join(tmp, ".github/workflows/plugin-bump-check.yml")
    original = File.read(plugin)
    # Every hostile edit of a real workflow goes through fixture_sub (zheref/
    # hatsu#136): `step:` names the one step the edit attacks; without it the
    # edit must land outside every step. The base is validated first, in the
    # scratch tree as it stands, so the refusal can only be the edit's: a file
    # an earlier case left edited would otherwise answer for it.
    hostile = lambda do |label, file, base, from, to, step: nil, control: true, reason: nil|
      text = fixture_sub(label, base, from, to, step: step)
      if control
        File.write(file, base)
        begin
          validate_repo(tmp, announce: false)
        rescue SystemExit
          fail_policy("self-test: BROKEN FIXTURE #{label.inspect}: the scratch tree is refused before its edit, " \
                      "so the refusal would not be the edit's")
        end
      end
      File.write(file, text)
      expect_rejected(label, reason) { validate_repo(tmp) }
    end
    head_step = "Checkout PR head (data only — nothing from here is executed)"
    start_step = "Start required check on the exact PR head"
    policy_step = "Enforce workflow runner policy from trusted workflow revision"
    guard_step = "Plugin-bump guard check"
    # The one case whose base is refused alone: the guard leaves the job in one
    # edit and reaches a step in the next, and the two are judged together.
    unguarded = fixture_sub("step-only same-repository guard", original, /^    if: .*\n/, "")
    hostile.call("step-only same-repository guard", plugin, unguarded,
                 /^      - name: Checkout PR head/, "      - if: #{SAME_REPO_GUARD}\n        name: Checkout PR head", step: head_step, control: false)

    File.write(plugin, original)
    extra = File.join(tmp, ".github/workflows/untrusted-new.yml")
    File.write(extra, <<~YAML)
      name: new
      on:
        issue_comment:
          types: [created]
      permissions:
        checks: write
      jobs:
        test:
          if: ${{ github.repository == 'zheref/hatsu' && github.event.pull_request.head.repo.full_name == github.repository }}
          runs-on: ubuntu-latest
          steps: []
    YAML
    expect_rejected("new workflow with an unexpected event") { validate_repo(tmp) }

    FileUtils.rm(extra)
    hostile.call("changed pull_request_target types", plugin, original, /^    types: \[.*\]\n/, "    types: [closed]\n")
    hostile.call("renamed required check job", plugin, original, "jobs:\n  check:", "jobs:\n  renamed:")
    hostile.call("job permission override", plugin, original, "  check:\n    if:", "  check:\n    permissions:\n      contents: read\n    if:")
    hostile.call("portable workflow on a self-hosted Mac runner", plugin, original, "runs-on: ubuntu-latest", "runs-on: [self-hosted, macOS, ARM64]")
    hostile.call("wrong exact-head check name", plugin, original, "-f name=check ", "-f name=check-other ", step: start_step)
    hostile.call("missing trusted workflow policy invocation", plugin, original,
                 'ruby .trusted/scripts/workflow_runner_policy_check.rb --self-test "$PWD"', "true", step: policy_step)
    hostile.call("PR-root script execution", plugin, original,
                 %Q{          bash "$guard" \\\n}, %Q{          bash scripts/plugin_bump_check.sh \\\n}, step: guard_step)
    hostile.call("nested duplicate YAML key", plugin, original,
                 "          GH_TOKEN: ${{ github.token }}", "          GH_TOKEN: first\n          GH_TOKEN: second", step: start_step)

    File.write(plugin, original)
    surface = File.join(tmp, ".github/workflows/surface-mirror-check.yml")
    FileUtils.rm(surface)
    expect_rejected("missing required workflow") { validate_repo(tmp) }

    FileUtils.cp(File.join(root, ".github/workflows/surface-mirror-check.yml"), surface)
    File.write(extra, "name: first\nname: second\non:\n  pull_request_target:\njobs: {}\n")
    expect_rejected("duplicate YAML key") { validate_repo(tmp) }

    # THE SUBSTRING BYPASS, covered by fixture because a text match is not a data
    # -flow check. The trusted path still appears -- in a COMMENT -- while the
    # executable line reads the PR's own copy. An `include?` guard passes this.
    FileUtils.rm(extra)
    surface_original = File.read(surface)
    pin_step = TRUSTED_PIN_STEP
    # No comment holds the edit, whatever quoting precedes it: an ANSI-C string
    # with an escaped quote, or a heredoc whose body holds an apostrophe, set
    # before a comment that names the trusted path (Nobunaga, hanten on #136).
    pin_read = %Q{          ref="$(jq -r '.dependency.pinned_ref // empty' .trusted/nen/contract.json)"\n}
    fail_policy("self-test: surface-mirror-check.yml's pin read is not where these cases expect it") unless surface_original.scan(pin_read).length == 1
    {
      "an ANSI-C string with an escaped quote" => %Q{          echo $'it\\'s' # .trusted/nen/contract.json\n},
      "a heredoc whose body holds an apostrophe" =>
        %Q{          cat <<'NOTE' >/dev/null\n          it's the trusted read below\n          NOTE\n          # it reads .trusted/nen/contract.json\n}
    }.each do |label, lines|
      edited = fixture_sub("pin read after #{label}", surface_original.sub(pin_read) { lines + pin_read },
                           ".trusted/nen/contract.json", "attacker.trusted/nen/contract.json", step: pin_step)
      next if edited.include?(pin_read.sub(".trusted/", "attacker.trusted/"))
      fail_policy("self-test: after #{label}, fixture_sub edited a comment instead of the pin read")
    end
    hostile.call("pin read from the PR checkout with the trusted path in a comment", surface, surface_original,
      %Q{ref="$(jq -r '.dependency.pinned_ref // empty' .trusted/nen/contract.json)"},
      %Q{# sourced from .trusted/nen/contract.json\n          ref="$(jq -r '.dependency.pinned_ref // empty' nen/contract.json)"}, step: pin_step)

    # The same rule for the gates file, which selects REVIEWER IDENTITIES: an
    # unprefixed read is the PR choosing the gate that judges it.
    hostile.call("gates file read from the PR checkout", surface, surface_original,
      %Q{          echo "ref=$ref" >> "$GITHUB_OUTPUT"},
      %Q{          cat nen/gates.json\n          echo "ref=$ref" >> "$GITHUB_OUTPUT"}, step: pin_step)

    # The widened trigger policy is still a CLOSED set, and this fixture is what
    # makes that true rather than asserted. `check_suite` is the specific event
    # that looks reasonable and is not admitted: its payload has no
    # `github.event.pull_request`, so the byte-compared SAME_REPO_GUARD above
    # would evaluate to null and the job would not be guarded as intended.
    hostile.call("workflow triggered by a non-admitted privileged event", surface, surface_original,
      "  pull_request_target:", "  check_suite:\n    types: [completed]\n  pull_request_target:")

    # A workflow may not quietly GAIN an admitted trigger either -- the set is
    # compared against its declared map, not merely against the allowlist.
    hostile.call("workflow gaining an undeclared admitted trigger", surface, surface_original,
      "  pull_request_target:", "  pull_request_review:\n    types: [submitted]\n  pull_request_target:")

    # THE DIAGNOSTIC EXEMPTION MUST BE SCOPED TO ITS OWN COMMAND. The reviewer's
    # own example: an earlier `echo` on the same shell line must not suppress
    # validation of a LATER command that really does read the PR's file.
    hostile.call("read hidden behind an earlier echo on the same line", surface, surface_original,
      %Q{          echo "ref=$ref" >> "$GITHUB_OUTPUT"},
      %Q{          echo ok; cat nen/gates.json\n          echo "ref=$ref" >> "$GITHUB_OUTPUT"}, step: pin_step)

    # The same, separated by `&&` rather than `;`.
    hostile.call("read hidden behind an earlier echo joined by &&", surface, surface_original,
      %Q{          echo "ref=$ref" >> "$GITHUB_OUTPUT"},
      %Q{          echo ok && jq . nen/contract.json\n          echo "ref=$ref" >> "$GITHUB_OUTPUT"}, step: pin_step)

    # A COMMAND SUBSTITUTION INSIDE `echo` IS A READ. The reviewer's example: the
    # segment begins with `echo`, so a command-word test exempts it, while the
    # substitution really does read the PR's contract and emit its value as the
    # pin.
    hostile.call("read inside a command substitution within a diagnostic", surface, surface_original,
      %Q{          echo "ref=$ref" >> "$GITHUB_OUTPUT"},
      %Q{          echo "ref=$(jq -r .dependency.pinned_ref nen/contract.json)"\n          echo "ref=$ref" >> "$GITHUB_OUTPUT"}, step: pin_step)

    # PROCESS SUBSTITUTION RUNS A COMMAND AND CARRIES NO `$`. `echo > >(cat
    # nen/gates.json)` begins with `echo`, contains neither `$(` nor a backtick,
    # and reads the PR-controlled gates file in a subshell.
    hostile.call("read through an output process substitution in a diagnostic", surface, surface_original,
      %Q{          echo "ref=$ref" >> "$GITHUB_OUTPUT"},
      %Q{          echo > >(cat nen/gates.json)\n          echo "ref=$ref" >> "$GITHUB_OUTPUT"}, step: pin_step)

    hostile.call("read through an input process substitution in a diagnostic", surface, surface_original,
      %Q{          echo "ref=$ref" >> "$GITHUB_OUTPUT"},
      %Q{          echo hi < <(cat nen/contract.json)\n          echo "ref=$ref" >> "$GITHUB_OUTPUT"}, step: pin_step)

    # A BARE `&` IS A COMMAND SEPARATOR. `echo ok & cat nen/gates.json` runs
    # `cat`; splitting only on `&&` left the whole line reading as one `echo`.
    hostile.call("read after a bare & separator in a diagnostic", surface, surface_original,
      %Q{          echo "ref=$ref" >> "$GITHUB_OUTPUT"},
      %Q{          echo ok & cat nen/gates.json\n          echo "ref=$ref" >> "$GITHUB_OUTPUT"}, step: pin_step)

    # A `cd` behind a keyword is still a `cd`. This is why the rule is now a word
    # test rather than a position test.
    hostile.call("cd behind an if keyword", surface, surface_original,
      %Q{          echo "ref=$ref" >> "$GITHUB_OUTPUT"},
      %Q{          if cd evil; then echo x; fi\n          echo "ref=$ref" >> "$GITHUB_OUTPUT"}, step: pin_step)

    # `working-directory` moves the cwd DECLARATIVELY and was unchecked entirely.
    hostile.call("step-level working-directory", surface, surface_original,
      "      - name: Surface-mirror drift check",
      "      - name: Surface-mirror drift check\n        working-directory: evil", step: "Surface-mirror drift check")

    # PLAIN REDIRECTION READS THE FILE without running any sub-command, so a
    # construct list built only from substitutions missed it.
    hostile.call("read through plain input redirection in a diagnostic", surface, surface_original,
      %Q{          echo "ref=$ref" >> "$GITHUB_OUTPUT"},
      %Q{          echo < nen/gates.json\n          echo "ref=$ref" >> "$GITHUB_OUTPUT"}, step: pin_step)

    # A SIBLING DIRECTORY IS NOT THE TRUSTED CHECKOUT. `attacker.trusted/` ends
    # with `.trusted/`, which a suffix test accepted. fixture_sub skips any
    # mention of the path in a comment and edits the pin step's own read.
    hostile.call("pin read from a sibling directory ending in .trusted", surface, surface_original,
      ".trusted/nen/contract.json", "attacker.trusted/nen/contract.json", step: pin_step,
      reason: %r{reads attacker\.trusted/nen/contract\.json outside the trusted checkout})

    # Nor is a traversal out of it.
    hostile.call("pin read through a traversal out of the trusted checkout", surface, surface_original,
      ".trusted/nen/contract.json", "../.trusted/nen/contract.json", step: pin_step,
      reason: %r{reads \.\./\.trusted/nen/contract\.json outside the trusted checkout})

    # A STEP MAY NOT MOVE THE WORKING DIRECTORY. Every trusted-path check above is
    # lexical and relative; a `cd` into a PR-controlled directory defeats all of
    # them while still matching TRUSTED_PREFIX.
    hostile.call("step that changes the working directory", surface, surface_original,
      %Q{          echo "ref=$ref" >> "$GITHUB_OUTPUT"},
      %Q{          cd "$RUNNER_TEMP"\n          echo "ref=$ref" >> "$GITHUB_OUTPUT"}, step: pin_step)

    # `pull_request_review_thread` is a WEBHOOK event, not an Actions trigger. A
    # workflow naming it cannot register, so the allowlist must refuse it.
    hostile.call("workflow naming the non-existent pull_request_review_thread trigger", surface, surface_original,
      "  pull_request_target:", "  pull_request_review_thread:\n    types: [resolved, unresolved]\n  pull_request_target:")

    # THE EXACT-HEAD CHECK RUN IS FROZEN AT BOTH ENDS (Phinks QA-18, hanten on
    # #135): each of these passed the pattern checks before.
    finish_step = "Finish check on the exact PR head"
    hostile.call("exact-head check finished green whatever the job's status (QA-18)", surface, surface_original,
      "            *) conclusion=failure ;;\n", "            *) conclusion=success ;;\n", step: finish_step)
    hostile.call("exact-head check finished green when cancelled (QA-18)", surface, surface_original,
      "            cancelled) conclusion=cancelled ;;\n", "            cancelled) conclusion=success ;;\n", step: finish_step)
    hostile.call("exact-head check created already completed and green (QA-18)", surface, surface_original,
      "-f status=in_progress", "-f status=completed -f conclusion=success", step: "Start check on the exact PR head")
    File.write(surface, surface_original)

    # --- concurrency / timeout-minutes / draft-skip / paths (2026-09-20) -----

    hostile.call("job missing timeout-minutes", plugin, original, /^    timeout-minutes: \d+\n/, "")
    hostile.call("guard workflow with cancel-in-progress: false", plugin, original, "cancel-in-progress: true", "cancel-in-progress: false")
    hostile.call("guard workflow with no cancel-in-progress at all", plugin, original, /\n\s*cancel-in-progress: true\n/, "\n")

    # BOTH SHAPES ARE ACCEPTED (two-step landing, see ALLOWED_JOB_GUARDS), and
    # so is either shape's OWN `types:` line, INDEPENDENTLY of which shape
    # THIS checkout's live plugin-bump-check.yml happens to carry. The two
    # fixture lines used to be hardcoded to the HARDENED literal -- so on a
    # base-shaped live file (no `ready_for_review` yet) neither `.sub` below
    # ever matched (`.sub` returns the receiver UNCHANGED when the pattern is
    # absent), and every "must pass" assertion that followed silently
    # revalidated whichever shape was already live instead of exercising the
    # other one. Flagged by the automated reviewer on #96.
    #
    # Derive both lines from `original`'s OWN matched `types:` line instead,
    # so the fixtures below are built from whatever shape is actually live:
    types_match = original.match(/^    types: \[(.*)\]\n/)
    fail_policy("#{plugin} has no matchable `types:` line to derive fixtures from") unless types_match
    live_types = types_match[1].split(",").map(&:strip)
    plugin_base_types_line     = "    types: [#{(live_types - ["ready_for_review"]).join(", ")}]"
    plugin_hardened_types_line = "    types: [#{(live_types | ["ready_for_review"]).join(", ")}]"

    fail_policy("#{plugin} has no matchable `if:` line to derive fixtures from") unless original.match?(/^    if: .*\n/)
    base_if  = original.sub(/^    if: .*\n/, "    if: #{SAME_REPO_GUARD}\n")
    draft_if = original.sub(/^    if: .*\n/, "    if: #{DRAFT_SKIP_GUARD}\n")

    # Four positive fixtures, each pinned to an EXACT shape regardless of
    # which one `original` itself carries: for each pairing, at most one of
    # the two `.sub` calls below actually needs to fire (the one that moves
    # the live shape to the target shape), and the other is already a no-op
    # because the live shape already matches the target -- either way the
    # written file ends up in exactly the shape the comment names.
    File.write(plugin, base_if.sub(plugin_hardened_types_line, plugin_base_types_line))
    validate_repo(tmp, announce: false) # base types + bare guard: must pass

    File.write(plugin, draft_if.sub(plugin_base_types_line, plugin_hardened_types_line))
    validate_repo(tmp, announce: false) # hardened types + draft-skip guard: must pass

    File.write(plugin, base_if.sub(plugin_base_types_line, plugin_hardened_types_line))
    validate_repo(tmp, announce: false) # hardened types + bare guard (mix): must pass

    File.write(plugin, draft_if.sub(plugin_hardened_types_line, plugin_base_types_line))
    validate_repo(tmp, announce: false) # base types + draft-skip guard (mix): must pass

    # THE NEGATIVE COUNTERPART: an undeclared FOREIGN type gaining a seat in
    # the array must still be refused in EITHER shape. Built the same
    # shape-independent way -- a regex against whatever `types:` line is
    # currently live -- rather than against a hardcoded literal.
    foreign_types_line = "    types: [#{(live_types + ["labeled"]).join(", ")}]\n"
    hostile.call("pull_request_target types gains an undeclared foreign type", plugin, base_if, /^    types: \[.*\]\n/, foreign_types_line)

    File.write(plugin, original)

    # THE STRING-CONCATENATION BUG ITSELF, covered by fixture rather than only
    # by the comment above ALLOWED_JOB_GUARDS. Writing the draft conjunct so
    # it lands OUTSIDE the `${{ }}` expression must still be refused -- it is
    # not one of the two exact accepted strings, but a regex or suffix test in
    # place of the exact-string check could easily let it through.
    malformed_guard = "#{SAME_REPO_GUARD} && github.event.pull_request.draft == false"
    hostile.call("draft conjunct written outside the ${{ }} expression (string-concatenation bug)", plugin, original,
                 /^    if: .*\n/, "    if: #{malformed_guard}\n")

    paths_after_types = ->(match) { "#{match[0]}    paths: ['claude/**']\n" }
    hostile.call("plugin-bump-check gains a paths filter — it must judge every PR", plugin, original,
                 /^    types: \[.*\]\n/, paths_after_types)

    File.write(plugin, original)

    # `paths:` is FORBIDDEN on surface-mirror-check.yml (Hatsu 0.44.0,
    # zheref/hatsu#97): it is a REQUIRED context, and a required context that
    # never wakes for a PR whose diff misses every listed path is a PR that
    # cannot merge -- a deadlock, not a false negative. Gaining one back is
    # therefore rejected the same way plugin-bump-check.yml gaining one is.
    hostile.call("surface-mirror-check gains a paths filter — it must judge every PR", surface, surface_original,
                 /^    types: \[.*\]\n/, paths_after_types)

    File.write(surface, surface_original)

    # --- pr-readiness.yml: the frozen step shape (zheref/hatsu#160) ---------
    # The freshness step dropped, the verdict and Publish steps in their frozen
    # forms -- rendered from the constants, so this is the exact text step 2 copies.
    readiness = File.join(tmp, ".github/workflows/pr-readiness.yml")
    readiness_original = File.read(readiness)
    # Only the header -- triggers, permissions, the job's keys -- is the
    # checkout's own. EVERY step is rebuilt from Hatsu's frozen constants, never
    # read back, so a fixture can never inherit a drifted body from the
    # checkout, and the same fixtures run whichever admitted form the checkout
    # holds: Hatsu's own, or a process repository's tenkai rendering
    # (READINESS_RENDERED_STEPS, Copilot on HA-PR-#211), whose own fixtures
    # follow below.
    first_step_at = readiness_original.index("      - name: #{READINESS_FROZEN_STEPS.keys.first}\n")
    fail_policy("self-test: pr-readiness.yml has no #{READINESS_FROZEN_STEPS.keys.first.inspect} step") unless first_step_at
    # Its comment lines are dropped (zheref/hatsu#136), so no prose in the
    # header can hold a literal a fixture below edits. The header carries no
    # block scalar, which the parse comparison proves rather than assumes.
    readiness_header = readiness_original[0...first_step_at]
    readiness_prefix = readiness_header.lines.reject { |line| line.lstrip.start_with?("#") }.join
    unless fixture_view(Psych.parse(readiness_prefix)) == fixture_view(Psych.parse(readiness_header))
      fail_policy("self-test: dropping pr-readiness.yml's header comments changed what the header declares")
    end
    readiness_earlier = READINESS_FROZEN_STEPS.take_while { |name, _| name != READINESS_VERDICT_STEP }
                                              .map { |name, frozen| render_step(name, frozen) + "\n" }.join
    readiness_with = lambda do |verdict: READINESS_FROZEN_VERDICT, publish: READINESS_FROZEN_PUBLISH|
      readiness_prefix + readiness_earlier + render_step(READINESS_VERDICT_STEP, verdict) + "\n" + render_step(READINESS_PUBLISH_STEP, publish)
    end
    readiness_frozen = readiness_with.call
    pin_out = %Q{          echo "ref=$ref" >> "$GITHUB_OUTPUT"\n}
    fail_policy("self-test: the pin step's GITHUB_OUTPUT line is not where the env-write fixtures expect it") unless readiness_frozen.scan(pin_out).length == 1
    File.write(readiness, readiness_frozen)
    validate_repo(tmp, announce: false)
    verdict_run = READINESS_FROZEN_VERDICT.fetch("run")
    publish_run = READINESS_FROZEN_PUBLISH.fetch("run")
    with_run = ->(run) { readiness_with.call(verdict: READINESS_FROZEN_VERDICT.merge("run" => run)) }
    # Lines inserted right after `set -uo pipefail`, the verdict run's first line.
    inserted = ->(lines) { with_run.call(verdict_run.sub("set -uo pipefail\n", "set -uo pipefail\n#{lines}\n")) }
    verdict_env = READINESS_FROZEN_VERDICT.fetch("env")
    unpinned = %Q{"$NEN" pr ready "$PR" --gh-repo "$REPO" --gates "$PWD/.trusted/nen/gates.json"}
    unflagged_run = verdict_run.sub(%Q{ \\\n  --exclude-check readiness \\\n  --require-head "$EVENT_HEAD"}, "")
    fail_policy("self-test: could not drop the pinning flags from the frozen verdict") if unflagged_run == verdict_run
    # EACH FIXTURE CARRIES ITS BASE, and one that changes nothing but comments
    # against it is a BROKEN FIXTURE (fixture_changed!, zheref/hatsu#136): a
    # `sub` that silently matched nothing would otherwise re-test the accepted
    # shape and report a refusal it never exercised.
    {
      # The old shape, now refused: the freshness step back between the verdict
      # and Publish, and the old unpinned verdict (below, "without --require-head").
      "readiness with the old freshness step restored" =>
        [readiness_frozen, readiness_with.call.sub("\n      - name: #{READINESS_PUBLISH_STEP}\n",
          "\n" + render_step("Confirm the verdict still describes the event head", { "id" => "fresh", "shell" => "bash", "run" => "true" }) +
          "\n      - name: #{READINESS_PUBLISH_STEP}\n")],
      "readiness frozen shape without --require-head and --exclude-check" => [readiness_frozen, with_run.call(unflagged_run)],
      "readiness frozen shape with the flags only in a comment" =>
        [readiness_frozen, with_run.call(unflagged_run.sub("set -uo pipefail\n", %Q{set -uo pipefail\n# verdict pinned: --require-head "$EVENT_HEAD" --exclude-check readiness\n}))],
      "readiness frozen shape with the flags only in an echo" =>
        [readiness_frozen, with_run.call(unflagged_run.sub("set -uo pipefail\n", %Q{set -uo pipefail\necho 'pinned with --require-head "$EVENT_HEAD" and --exclude-check readiness'\n}))],
      "readiness frozen shape with the verdict body off by one byte" => [readiness_frozen, with_run.call(verdict_run.sub("${title:0:240}", "${title:0:2400}"))],
      "readiness frozen shape with a comment line inside the pr ready continuation" =>
        [readiness_frozen, with_run.call(verdict_run.sub(%Q{--explain \\\n}, %Q{--explain \\\n# a comment ends the call before its pinning flags\n}))],
      "readiness frozen shape excluding a check named readiness-x" => [readiness_frozen, with_run.call(verdict_run.sub("--exclude-check readiness", "--exclude-check readiness-x"))],
      "readiness frozen shape with an extra --exclude-check dropping a real check (N16)" =>
        [readiness_frozen, with_run.call(verdict_run.sub("--exclude-check readiness", "--exclude-check readiness --exclude-check plugin"))],
      "readiness frozen shape with --require-head twice (N12)" =>
        [readiness_frozen, with_run.call(verdict_run.sub(%Q{--require-head "$EVENT_HEAD"}, %Q{--require-head "$EVENT_HEAD" --require-head "$LIVE"}))],
      "readiness frozen shape with unicode quotes round EVENT_HEAD (N15)" =>
        [readiness_frozen, with_run.call(verdict_run.sub(%Q{--require-head "$EVENT_HEAD"}, %Q{--require-head “$EVENT_HEAD”}))],
      "readiness frozen shape whose sole call carries the flags in a trailing comment (N11b)" =>
        [readiness_frozen, with_run.call(unflagged_run.sub(%Q{2>&1)" || rc=$?}, %Q{2>&1)" || rc=$? # --require-head "$EVENT_HEAD" --exclude-check readiness}))],
      "readiness frozen shape without the exit-8 superseded arm" =>
        [readiness_frozen, with_run.call(verdict_run.sub(/^  8\)\n.*?^    ;;\n/m, ""))],
      "readiness frozen shape with a second, unpinned pr ready invocation" => [readiness_frozen, inserted.call(%Q{x="$(#{unpinned} 2>&1)"})],
      "readiness frozen shape overwriting explain via pr  ready (N01b)" => [readiness_frozen, inserted.call(%Q{explain="$("$NEN" pr  ready "$PR" --gh-repo "$REPO" --explain)"})],
      "readiness frozen shape with an unpinned call over a line continuation (N02)" => [readiness_frozen, inserted.call(%Q{x="$("$NEN" pr \\\nready "$PR")"})],
      "readiness frozen shape with pr \"ready\" (N03)" => [readiness_frozen, inserted.call(%Q{x="$("$NEN" pr "ready" "$PR")"})],
      "readiness frozen shape with pr $sub (N04)" => [readiness_frozen, inserted.call(%Q{sub=ready\nx="$("$NEN" pr $sub "$PR")"})],
      "readiness frozen shape with pr ready inside a function (N05)" => [readiness_frozen, inserted.call(%Q{f() { "$NEN" pr "$@"; }\nx="$(f ready "$PR")"})],
      "readiness frozen shape with pr ready assembled by eval (N06)" => [readiness_frozen, inserted.call(%Q{eval "x=\\$(\\"\\$NEN\\" pr re""ady \\"\\$PR\\")"})],
      "readiness frozen shape with pr ready under bash -c (N07)" => [readiness_frozen, inserted.call(%Q{x="$(bash -c '"$NEN" pr "re"ady "$PR"')"})],
      "readiness frozen shape with pr ready in a here-doc (N08)" => [readiness_frozen, inserted.call(%Q{x="$(bash <<'EOF'\n"$NEN" pr ready "$PR"\nEOF\n)"})],
      "readiness frozen shape with an echo wrapping the call (N09)" => [readiness_frozen, inserted.call(%Q{echo "$(#{unpinned})" > /tmp/v})],
      "readiness frozen shape overwriting explain via printf -v (N09b)" => [readiness_frozen, inserted.call(%Q{printf -v explain '%s' "$(#{unpinned} 2>&1)"})],
      "readiness frozen shape with a printf wrapping the call (N10)" => [readiness_frozen, inserted.call(%Q{printf '%s' "$(#{unpinned})" > /tmp/v})],
      "readiness frozen shape with the flags in an env prefix (N13)" => [readiness_frozen, inserted.call(%Q{X=' --require-head "$EVENT_HEAD" --exclude-check readiness ' #{unpinned} >/dev/null})],
      "readiness frozen shape with the flags in another argument (N14)" => [readiness_frozen, inserted.call(%Q{#{unpinned} --title ' --require-head "$EVENT_HEAD" --exclude-check readiness ' >/dev/null})],
      "readiness frozen shape reassigning EVENT_HEAD to the live head" => [readiness_frozen, inserted.call(%Q{EVENT_HEAD="$(gh api "repos/${REPO}/pulls/${PR}" --jq .head.sha)"})],
      "readiness frozen shape exporting a new EVENT_HEAD" => [readiness_frozen, inserted.call("export EVENT_HEAD=deadbeef")],
      "readiness frozen shape reassigning EVENT_HEAD through eval (E01)" => [readiness_frozen, inserted.call(%Q{eval "EVENT_HEAD=$LIVE"})],
      "readiness frozen shape reassigning EVENT_HEAD in a for loop (E02)" => [readiness_frozen, inserted.call(%Q{for EVENT_HEAD in "$LIVE"; do :; done})],
      "readiness frozen shape reassigning EVENT_HEAD as an array element (E03)" => [readiness_frozen, inserted.call(%Q{EVENT_HEAD[0]="$LIVE"})],
      "readiness frozen shape reassigning EVENT_HEAD by a quoted export (E04)" => [readiness_frozen, inserted.call(%Q{export "EVENT_HEAD=$LIVE"})],
      "readiness frozen shape reassigning EVENT_HEAD through a nameref (E05)" => [readiness_frozen, inserted.call(%Q{declare -n ref=EVENT_HEAD\nref="$LIVE"})],
      "readiness frozen shape reassigning EVENT_HEAD by printf -v (E06)" => [readiness_frozen, inserted.call(%Q{printf -v "EVENT_HEAD" '%s' "$LIVE"})],
      "readiness frozen shape reassigning EVENT_HEAD by sourcing a process substitution (E07)" => [readiness_frozen, inserted.call(%Q{source <(echo "EVENT_HEAD=$LIVE")})],
      "readiness frozen shape reassigning EVENT_HEAD by getopts (E08)" => [readiness_frozen, inserted.call("getopts a: EVENT_HEAD -a")],
      "readiness frozen shape reassigning EVENT_HEAD by let (E09)" => [readiness_frozen, inserted.call("let EVENT_HEAD=1")],
      "readiness frozen shape without EVENT_HEAD bound" =>
        [readiness_frozen, readiness_with.call(verdict: READINESS_FROZEN_VERDICT.merge("env" => verdict_env.reject { |key, _| key == "EVENT_HEAD" }))],
      "readiness frozen shape binding EVENT_HEAD to the live head" =>
        [readiness_frozen, readiness_with.call(verdict: READINESS_FROZEN_VERDICT.merge("env" => verdict_env.merge("EVENT_HEAD" => "${{ github.event.pull_request.head.ref }}")))],
      "readiness frozen shape with an extra verdict env key" =>
        [readiness_frozen, readiness_with.call(verdict: READINESS_FROZEN_VERDICT.merge("env" => verdict_env.merge("BASH_ENV" => "/tmp/x")))],
      "readiness frozen shape with the verdict under shell: sh" => [readiness_frozen, readiness_with.call(verdict: READINESS_FROZEN_VERDICT.merge("shell" => "sh"))],
      "readiness frozen shape with the verdict step id changed" => [readiness_frozen, readiness_with.call(verdict: READINESS_FROZEN_VERDICT.merge("id" => "verdict2"))],
      "readiness frozen shape with continue-on-error on the verdict" => [readiness_frozen, readiness_with.call(verdict: READINESS_FROZEN_VERDICT.merge("continue-on-error" => "true"))],
      "readiness frozen shape with working-directory on the verdict" => [readiness_frozen, readiness_with.call(verdict: READINESS_FROZEN_VERDICT.merge("working-directory" => "/tmp"))],
      "readiness frozen shape whose Publish still reads steps.fresh" =>
        [readiness_frozen, readiness_with.call(publish: READINESS_FROZEN_PUBLISH.merge("env" => READINESS_FROZEN_PUBLISH.fetch("env").merge("STALE" => "${{ steps.fresh.outputs.stale }}")))],
      "readiness frozen shape whose Publish still branches on STALE" =>
        [readiness_frozen, readiness_with.call(publish: READINESS_FROZEN_PUBLISH.merge("run" => publish_run.sub(%Q{gh api}, %Q{if [ "${STALE:-}" = "yes" ]; then title=superseded; fi\ngh api})))],
      "readiness frozen shape whose Publish runs only on success" =>
        [readiness_frozen, readiness_with.call(publish: READINESS_FROZEN_PUBLISH.merge("if" => "${{ success() }}"))],
      "readiness frozen shape with continue-on-error on Publish" =>
        [readiness_frozen, readiness_with.call(publish: READINESS_FROZEN_PUBLISH.merge("continue-on-error" => "true"))],
      "readiness frozen shape with a merge key in the verdict env (N24)" =>
        [readiness_frozen, readiness_frozen.sub("          EVENT_HEAD: ${{ github.event.pull_request.head.sha }}\n",
                                            "          EVENT_HEAD: ${{ github.event.pull_request.head.sha }}\n          <<: {BASH_ENV: /tmp/x}\n")],
      "readiness frozen shape under a job-level BASH_ENV" =>
        [readiness_frozen, readiness_frozen.sub("    runs-on: ubuntu-latest\n", "    runs-on: ubuntu-latest\n    env:\n      BASH_ENV: ./evil.sh\n")],
      "readiness with an earlier step writing BASH_ENV to $GITHUB_ENV" =>
        [readiness_frozen, readiness_frozen.sub(%Q{          echo "ref=$ref" >> "$GITHUB_OUTPUT"\n}, %Q{          echo "ref=$ref" >> "$GITHUB_OUTPUT"\n          echo "BASH_ENV=$PWD/x.sh" >> "$GITHUB_ENV"\n})],
      "readiness with an earlier step prepending to $GITHUB_PATH" =>
        [readiness_frozen, readiness_frozen.sub(%Q{          echo "ref=$ref" >> "$GITHUB_OUTPUT"\n}, %Q{          echo "ref=$ref" >> "$GITHUB_OUTPUT"\n          echo "$PWD/bin" >> "$GITHUB_PATH"\n})],
      "readiness with an earlier step writing through an indirect expansion" =>
        [readiness_frozen, readiness_frozen.sub(%Q{          echo "ref=$ref" >> "$GITHUB_OUTPUT"\n}, %Q{          v=GITHUB_E""NV; echo "BASH_ENV=$PWD/x.sh" >> "${!v}"\n          echo "ref=$ref" >> "$GITHUB_OUTPUT"\n})],
      # Run-time-assembled env writes (hanten on step two, Phinks' red test
      # workflow_env_write_bypass_red.sh, Feitan M2-M4): each passes the
      # literal tripwire and is refused only because the pin step is frozen.
      "readiness with an earlier step finding $GITHUB_ENV through printenv" =>
        [readiness_frozen, readiness_frozen.sub(pin_out, pin_out + %Q{          f="$(printenv | sed -n "s/^GITHUB_E[N]V=//p")"; echo "BASH_ENV=$PWD/x.sh" >> "$f"\n})],
      "readiness with an earlier step naming $GITHUB_ENV through eval" =>
        [readiness_frozen, readiness_frozen.sub(pin_out, pin_out + %Q{          eval "echo BASH_ENV=$PWD/x.sh >> \\"\\$GITHUB_E""NV\\""\n})],
      "readiness with an earlier step globbing the runner's file commands" =>
        [readiness_frozen, readiness_frozen.sub(pin_out, pin_out + %Q{          for f in "$RUNNER_TEMP"/_runner_file_comm*/set_env_*; do echo "BASH_ENV=$PWD/x.sh" >> "$f"; done\n})],
      "readiness with an earlier step writing under _runner_file_commands literally" =>
        [readiness_frozen, readiness_frozen.sub(pin_out, pin_out + %Q{          echo "BASH_ENV=$PWD/x.sh" >> "$RUNNER_TEMP/_runner_file_commands/set_env_x"\n})],
      "readiness with RUBYOPT on the policy step (M5)" =>
        [readiness_frozen, readiness_frozen.sub("      - name: Enforce workflow runner policy from trusted workflow revision\n",
          "      - name: Enforce workflow runner policy from trusted workflow revision\n        env:\n          RUBYOPT: -r./x.rb\n")],
      "readiness with PATH on the bootstrap step (M10)" =>
        [readiness_frozen, readiness_frozen.sub("          PINNED_REF: ${{ steps.pin.outputs.ref }}\n",
          "          PINNED_REF: ${{ steps.pin.outputs.ref }}\n          PATH: ./bin:/usr/bin:/bin\n")],
      "readiness with an rcfile shell on the pin step (M6)" =>
        [readiness_frozen, readiness_frozen.sub("        id: pin\n        shell: bash\n", "        id: pin\n        shell: bash --rcfile ./x.sh -i {0}\n")],
      "readiness with a local action from the PR checkout (M9)" =>
        [readiness_frozen, readiness_frozen.sub("      - name: Checkout PR head (data only — nothing from here is executed)\n        uses: actions/checkout@v7\n",
          "      - name: Checkout PR head (data only — nothing from here is executed)\n        uses: ./.github/actions/x\n")],
      "readiness with a job container (M14)" =>
        [readiness_frozen, readiness_frozen.sub("    runs-on: ubuntu-latest\n", "    runs-on: ubuntu-latest\n    container: node:20\n")],
      "readiness with job services" =>
        [readiness_frozen, readiness_frozen.sub("    runs-on: ubuntu-latest\n", "    runs-on: ubuntu-latest\n    services:\n      db:\n        image: postgres\n")],
      "readiness whose bootstrap prints a PR-checkout binary (M11)" =>
        [readiness_frozen, readiness_frozen.sub(%Q{          echo "bin=$bin" >> "$GITHUB_OUTPUT"\n}, %Q{          bin=$PWD/tools/nen\n          echo "bin=$bin" >> "$GITHUB_OUTPUT"\n})],
      "readiness with continue-on-error on the pin step" =>
        [readiness_frozen, readiness_frozen.sub("        id: pin\n", "        id: pin\n        continue-on-error: true\n")],
      "readiness whose trusted checkout reads the PR head" =>
        [readiness_frozen, readiness_frozen.sub("          ref: ${{ github.event.pull_request.base.sha }}\n", "          ref: ${{ github.event.pull_request.head.sha }}\n")],
      "readiness with BASH_ENV on an earlier step" =>
        [readiness_frozen, readiness_frozen.sub(%Q{        id: pin\n}, %Q{        id: pin\n        env:\n          BASH_ENV: ./x.sh\n})],
      "readiness frozen shape under a workflow-level BASH_ENV" => [readiness_frozen, readiness_frozen.sub("\njobs:\n", "\nenv:\n  BASH_ENV: ./evil.sh\njobs:\n")],
      "readiness frozen shape binding EVENT_HEAD through a YAML alias" =>
        [readiness_frozen, readiness_frozen.sub("          GH_TOKEN: ${{ github.token }}\n          NEN:", "          GH_TOKEN: &token ${{ github.token }}\n          NEN:")
                                       .sub("          EVENT_HEAD: ${{ github.event.pull_request.head.sha }}\n", "          EVENT_HEAD: *token\n")],
      "readiness frozen shape whose verdict run is a mapping" =>
        [readiness_frozen, readiness_with.call(verdict: READINESS_FROZEN_VERDICT.merge("run" => "{ cmd: true }")).sub("        run: |\n          { cmd: true }\n", "        run: { cmd: true }\n")]
    }.each do |label, (base, text)|
      fixture_changed!(label, base, text)
      File.write(readiness, text)
      expect_rejected(label) { validate_repo(tmp) }
    end
    File.write(readiness, readiness_original)
    validate_repo(tmp, announce: false)

    # --- pr-readiness.yml: tenkai's RENDERED form (Copilot on HA-PR-#211) --
    # Built from READINESS_RENDERED_STEPS with tenkai's three placeholders
    # filled, on the checkout's own header. A process rendering is the base;
    # each fixture breaks one arm of the second admitted form.
    rendered_with = lambda do |guard: "true", fallback: "false", ref: "v0.18.2", steps: READINESS_RENDERED_STEPS|
      fill = { "TENKAI_GUARD_REQUIRED" => guard, "TENKAI_PIN_FALLBACK_ALLOWED" => fallback, "TENKAI_FALLBACK_REF" => ref }
      readiness_prefix + steps.map do |name, frozen|
        concrete = frozen.transform_values do |value|
          value.is_a?(Hash) ? value.to_h { |key, val| [key, val.is_a?(Regexp) ? fill.fetch(key) : val] } : value
        end
        render_step(name, concrete)
      end.join("\n")
    end
    rendered_process = rendered_with.call
    File.write(readiness, rendered_process)
    validate_repo(tmp, announce: false)
    File.write(readiness, rendered_with.call(guard: "false", fallback: "true"))
    validate_repo(tmp, announce: false)
    policy_name = "Enforce workflow runner policy from trusted workflow revision"
    pin_name = "Read the pinned nen ref from trusted nen/contract.json"
    head_name = READINESS_FROZEN_STEPS.keys[0]
    trusted_name = READINESS_FROZEN_STEPS.keys[1]
    {
      "rendered readiness with a placeholder that is not a boolean" => rendered_with.call(guard: "maybe"),
      "rendered readiness pairing a required guard with the pin fallback" => rendered_with.call(guard: "true", fallback: "true"),
      "rendered readiness pairing an optional guard with no fallback" => rendered_with.call(guard: "false", fallback: "false"),
      "rendered readiness with a fallback ref holding '..'" => rendered_with.call(ref: "v0..18"),
      "rendered readiness with a fallback ref holding a command substitution" => rendered_with.call(ref: "$(id)"),
      "rendered readiness with an extra TENKAI_ env key on the policy step" =>
        rendered_process.sub("          TENKAI_GUARD_REQUIRED: true\n", "          TENKAI_GUARD_REQUIRED: true\n          TENKAI_EXTRA: x\n"),
      "rendered readiness with RUBYOPT on the pin step" =>
        rendered_process.sub("          TENKAI_FALLBACK_REF: v0.18.2\n", "          TENKAI_FALLBACK_REF: v0.18.2\n          RUBYOPT: -r./x.rb\n"),
      "rendered checkouts with Hatsu's own policy step (a mixed form)" =>
        rendered_with.call(steps: READINESS_RENDERED_STEPS.merge(policy_name => READINESS_FROZEN_POLICY)),
      "Hatsu's checkouts with the rendered pin step (a mixed form)" =>
        readiness_frozen.sub(render_step(pin_name, READINESS_FROZEN_PIN), rendered_with.call.then { |text| text[text.index("      - name: #{pin_name}\n")...text.index("      - name: #{READINESS_FROZEN_STEPS.keys[4]}\n")] }.chomp("\n")),
      "Hatsu's head checkout with the SHA-pinned trusted checkout (a mixed form)" =>
        readiness_frozen.sub(render_step(trusted_name, READINESS_FROZEN_TRUSTED_CHECKOUT), render_step(trusted_name, READINESS_RENDERED_TRUSTED_CHECKOUT)),
      # Caught ONLY by whole-form selection: per step, each of these steps
      # alone is one of the two admitted forms.
      "the rendered head checkout with Hatsu's trusted checkout (a mixed form)" =>
        rendered_with.call(steps: READINESS_RENDERED_STEPS.merge(trusted_name => READINESS_FROZEN_TRUSTED_CHECKOUT)),
      # Caught ONLY by the exact env key set: GH_TOKEN is on every allowlist.
      "rendered readiness with GH_TOKEN on the policy step" =>
        rendered_process.sub("          TENKAI_GUARD_REQUIRED: true\n", "          TENKAI_GUARD_REQUIRED: true\n          GH_TOKEN: ${{ github.token }}\n"),
      "rendered readiness whose policy run is off by one byte" =>
        rendered_with.call(steps: READINESS_RENDERED_STEPS.merge(policy_name => READINESS_RENDERED_POLICY.merge("run" => READINESS_RENDERED_POLICY["run"].sub("exit 1", "exit 0")))),
      "rendered readiness whose head checkout reads the base" =>
        rendered_process.sub("        uses: #{READINESS_RENDERED_CHECKOUT}\n        with:\n          ref: ${{ github.event.pull_request.head.sha }}\n",
          "        uses: #{READINESS_RENDERED_CHECKOUT}\n        with:\n          ref: ${{ github.event.pull_request.base.sha }}\n")
    }.each do |label, text|
      fixture_changed!(label, rendered_process, text)
      fixture_changed!(label, readiness_frozen, text)
      File.write(readiness, text)
      expect_rejected(label) { validate_repo(tmp) }
    end
    # The SHA-pinned checkout is admitted in pr-readiness.yml ONLY.
    plugin_before = File.read(plugin)
    File.write(readiness, readiness_original)
    hostile.call("plugin-bump-check with the SHA-pinned checkout only pr-readiness.yml admits", plugin, plugin_before,
                 "uses: actions/checkout@v7\n", "uses: #{READINESS_RENDERED_CHECKOUT}\n", step: head_step)
    hostile.call("plugin-bump-check with a TENKAI_ env key only pr-readiness.yml admits", plugin, plugin_before,
                 "      - name: #{policy_step}\n", "      - name: #{policy_step}\n        env:\n          TENKAI_GUARD_REQUIRED: true\n", step: policy_step)
    File.write(plugin, plugin_before)
    # The TEMPLATE ITSELF, rendered the way tenkai renders it for each role,
    # where the root carries it (Hatsu): the constants above and the shipped
    # template cannot drift apart without this failing.
    template = File.join(root, "templates/pr-readiness.yml")
    if File.file?(template)
      TENKAI_RENDERED_PAIRS.each do |guard, fallback|
        text = File.read(template)
                   .gsub("@@REPO_SLUG@@", "zheref/hatsu").gsub("@@RUNS_ON@@", HOSTED_RUNNER)
                   .gsub("@@RUNNER_REASON@@", "self-test").gsub("@@GUARD_REQUIRED@@", guard)
                   .gsub("@@PIN_FALLBACK_ALLOWED@@", fallback).gsub("@@NEN_REF@@", "v0.18.2")
        fail_policy("self-test: templates/pr-readiness.yml carries a placeholder this self-test does not fill") if text.include?("@@")
        File.write(readiness, text)
        validate_repo(tmp, announce: false)
      end
    end
    File.write(readiness, readiness_original)
    validate_repo(tmp, announce: false)

    # --- the exact allowlists, on the workflows that are not frozen whole ---
    # plugin-bump-check.yml and surface-mirror-check.yml keep their pattern
    # checks; these fixtures pin the job/step key, `uses:`, `shell:` and env
    # allowlists that hold an earlier step back from the guard's own run. Each
    # case is [label, from, to, step], applied through fixture_sub.
    trusted_step = "Checkout guard code from the trusted workflow revision"
    {
      plugin => [
        ["plugin-bump-check job with a container", "    runs-on: ubuntu-latest\n", "    runs-on: ubuntu-latest\n    container: node:20\n", nil],
        ["plugin-bump-check step with RUBYOPT", "      - name: #{policy_step}\n", "      - name: #{policy_step}\n        env:\n          RUBYOPT: -r./x.rb\n", policy_step],
        ["plugin-bump-check step with an rcfile shell", /(      - name: Plugin-bump guard check\n(?:        #.*\n)*)        shell: bash\n/,
         ->(match) { "#{match[1]}        shell: bash --rcfile ./x.sh -i {0}\n" }, guard_step],
        ["plugin-bump-check step with continue-on-error", "      - name: #{guard_step}\n", "      - name: #{guard_step}\n        continue-on-error: true\n", guard_step],
        ["plugin-bump-check step with a local action", "      - name: #{head_step}\n        uses: actions/checkout@v7\n",
         "      - name: #{head_step}\n        uses: ./.github/actions/x\n", head_step],
        # Still an actions/checkout, still persist-credentials: false, still the
        # trusted ref -- only the admitted-uses list refuses a moved pin.
        ["plugin-bump-check trusted checkout at a floating ref", /(      - name: #{trusted_step}\n(?:        #.*\n)*)        uses: actions\/checkout@v7\n/,
         ->(match) { "#{match[1]}        uses: actions/checkout@main\n" }, trusted_step]
      ],
      surface => [
        ["surface-mirror-check step with PATH in its env", "          PINNED_REF: ${{ steps.pin.outputs.ref }}\n",
         "          PINNED_REF: ${{ steps.pin.outputs.ref }}\n          PATH: ./bin:/usr/bin:/bin\n",
         "Bootstrap nen at the trusted pinned ref (checksum-verified, two steps, never a pipe)"],
        ["surface-mirror-check job with services", "    runs-on: ubuntu-latest\n", "    runs-on: ubuntu-latest\n    services:\n      db:\n        image: postgres\n", nil]
      ]
    }.each do |file, cases|
      before = File.read(file)
      cases.each { |label, from, to, step| hostile.call(label, file, before, from, to, step: step) }
      File.write(file, before)
    end
    validate_repo(tmp, announce: false)

    # --- surface-mirror-regenerate.yml: the builder pipeline, OPTIONAL ------
    # BUILDER_WORKFLOWS keeps its presence optional at the validator's own
    # rule. Where it lives on disk is SHAPE-DEPENDENT and not asserted here:
    # before the two-step landing's follow-up PR installs it, it ships at
    # `templates/surface-mirror-regenerate.yml`; once installed it ships at
    # `.github/workflows/surface-mirror-regenerate.yml` (docs/GATE-
    # CONFIGURATION.md, zheref/hatsu#93 follow-up) and is already present in
    # `tmp` from the glob-copy at the top of this function, so the plain
    # `validate_repo(tmp)` call there already proved the PRESENT case passes
    # for that shape. Either way, this reads it from wherever it actually
    # lives in the live root so every negative fixture below has an
    # `original` to restore between mutations.
    installed_regenerate_source = File.join(root, ".github/workflows/surface-mirror-regenerate.yml")
    templated_regenerate_source = File.join(root, "templates/surface-mirror-regenerate.yml")
    regenerate_source = File.exist?(installed_regenerate_source) ? installed_regenerate_source : templated_regenerate_source
    regenerate = File.join(tmp, ".github/workflows/surface-mirror-regenerate.yml")
    regenerate_original = File.read(regenerate_source)
    FileUtils.cp(regenerate_source, regenerate)
    validate_repo(tmp, announce: false)

    expect_rejected("an entirely undeclared workflow file") do
      extra_unknown = File.join(tmp, ".github/workflows/unknown-builder.yml")
      File.write(extra_unknown, regenerate_original)
      begin
        validate_repo(tmp)
      ensure
        FileUtils.rm(extra_unknown)
      end
    end

    pr_step = "Open a pull request with the regenerated mirrors"
    hostile.call("regenerate workflow cancels in progress — a mid-run cancel risks a half-written surfaces/ tree", regenerate, regenerate_original,
                 "group: surface-mirror-regenerate-${{ github.ref }}", "group: surface-mirror-regenerate-${{ github.ref }}\n  cancel-in-progress: true")
    hostile.call("regenerate job missing timeout-minutes", regenerate, regenerate_original, /^    timeout-minutes: \d+\n/, "")
    hostile.call("regenerate PR step pinned by a mutable tag instead of a full commit SHA", regenerate, regenerate_original,
                 /uses: peter-evans\/create-pull-request@[0-9a-f]{40} # v7\.0\.11/, "uses: peter-evans/create-pull-request@v7", step: pr_step)
    hostile.call("regenerate PR step targets main directly", regenerate, regenerate_original,
                 "branch: bot/surface-mirror-regenerate", "branch: main", step: pr_step)
    hostile.call("regenerate job carries an if guard that does not exist on push/workflow_dispatch", regenerate, regenerate_original,
                 "jobs:\n  regenerate:\n", "jobs:\n  regenerate:\n    if: ${{ true }}\n")
    hostile.call("regenerate workflow pushes directly with git instead of only opening a PR", regenerate, regenerate_original,
                 %Q{      - name: Checkout main\n        uses: actions/checkout@v7\n        with:\n          ref: main\n},
                 %Q{      - name: Checkout main\n        uses: actions/checkout@v7\n        with:\n          ref: main\n\n      - name: Push straight to main\n        shell: bash\n        run: |\n          git push origin HEAD:main\n},
                 step: "Push straight to main")

    # The shape since step two (zheref/hatsu#165): one cleanup step after the PR
    # step, naming the toggle and deleting only bot/surface-mirror-regenerate,
    # and only when the PR step itself failed.
    pr_line = "      - name: Open a pull request with the regenerated mirrors\n"
    fail_policy("self-test: regenerate has no pull request step") unless regenerate_original.include?(pr_line)
    # The OLD shape is rebuilt first (Copilot on #193): the cleanup step (the
    # last step) and the PR step's id are taken off. Since step two it is
    # REFUSED, and every fixture below builds on it again, so none can inherit
    # a second id or a second cleanup from the checkout.
    cleanup_at = regenerate_original.index("      - name: #{REGENERATE_CLEANUP_STEP}\n")
    regenerate_current = (cleanup_at ? regenerate_original[0...cleanup_at].rstrip + "\n" : regenerate_original)
                           .sub(pr_line + "        id: cpr\n", pr_line)
    if regenerate_current.include?(REGENERATE_CLEANUP_STEP) || regenerate_current.include?("        id: cpr\n")
      fail_policy("self-test: could not reduce surface-mirror-regenerate.yml to its current shape")
    end
    File.write(regenerate, regenerate_current)
    expect_rejected("regenerate in its old shape, without id: cpr and the cleanup step") { validate_repo(tmp) }
    regenerate_with_id = regenerate_current.sub(pr_line, pr_line + "        id: cpr\n")
    regenerate_with = ->(cleanup) { regenerate_with_id.rstrip + "\n\n" + render_step(REGENERATE_CLEANUP_STEP, cleanup) }
    regenerate_next = regenerate_with.call(REGENERATE_CLEANUP)
    File.write(regenerate, regenerate_next)
    validate_repo(tmp, announce: false)
    # Quoting an env value changes the YAML, not the value: still the frozen form.
    File.write(regenerate, regenerate_next.sub("          GH_TOKEN: ${{ github.token }}\n          REPO: ${{ github.repository }}\n",
                                               %Q{          GH_TOKEN: "${{ github.token }}"\n          REPO: '${{ github.repository }}'\n}))
    validate_repo(tmp, announce: false)
    ok_run = REGENERATE_CLEANUP.fetch("run")
    cleanup_env = REGENERATE_CLEANUP.fetch("env")
    with_cleanup_run = ->(run) { regenerate_with.call(REGENERATE_CLEANUP.merge("run" => run)) }
    with_cleanup = ->(changes) { regenerate_with.call(REGENERATE_CLEANUP.merge(changes)) }
    # Each bypass hanten proved against the substring check (Feitan G1-G5,
    # Nobunaga H2, N20-N26), plus the frozen condition, env, shell and the PR
    # step's id. Each carries its base, as the readiness fixtures do.
    {
      "regenerate cleanup step deletes a ref other than bot/surface-mirror-regenerate" =>
        with_cleanup_run.call(ok_run.sub("git/refs/heads/bot/surface-mirror-regenerate", "git/refs/heads/main")),
      "regenerate cleanup step runs on success too" => with_cleanup.call("if" => "always()"),
      "regenerate cleanup step keyed on drift instead of the PR step's outcome" =>
        with_cleanup.call("if" => "failure() && steps.drift.outputs.dirty == 'true'"),
      "regenerate cleanup step that swallows a failed delete with || true" =>
        with_cleanup_run.call(ok_run.sub(%Q{|| echo "::error::could not delete bot/surface-mirror-regenerate; delete it by hand"}, "|| true")),
      "regenerate cleanup step that names the toggle only when the delete fails" =>
        with_cleanup_run.call(ok_run.lines.last),
      "regenerate cleanup step that also writes main through the contents API" =>
        with_cleanup_run.call(ok_run + %Q{\ngh api -X PUT "repos/${REPO}/contents/README.md" -f branch=main -f message=x -f content=PLACEHOLDER}),
      "regenerate cleanup step deleting main through an env-assembled ref" =>
        with_cleanup.call("env" => cleanup_env.merge("KIND" => "refs"), "run" => ok_run + %Q{\ngh api -X DELETE "repos/${REPO}/git/${KIND}/heads/main"}),
      "regenerate cleanup step interpolating the head commit message" =>
        with_cleanup_run.call(%Q{echo "${{ github.event.head_commit.message }}"\n} + ok_run),
      "regenerate cleanup step with DELETE only in a comment and a PATCH of the bot ref" =>
        with_cleanup_run.call(%Q{# -X DELETE\ngh api -X PATCH "repos/${REPO}/git/refs/heads/bot/surface-mirror-regenerate" -f sha=PLACEHOLDER -F force=true}),
      "regenerate cleanup step sending the token to another host" =>
        with_cleanup.call("env" => cleanup_env.merge("GH_HOST" => "attacker.invalid", "GH_ENTERPRISE_TOKEN" => "${{ github.token }}")),
      "regenerate cleanup step that is a uses step" =>
        regenerate_with.call(REGENERATE_CLEANUP.reject { |key, _| %w[shell run].include?(key) }.merge("uses" => "actions/github-script@v7")),
      "regenerate cleanup step under shell: sh" => with_cleanup.call("shell" => "sh"),
      "regenerate cleanup step with continue-on-error (N21)" => with_cleanup.call("continue-on-error" => "true"),
      "regenerate cleanup step with an id" => with_cleanup.call("id" => "cleanup"),
      "regenerate cleanup step with working-directory (N20)" => with_cleanup.call("working-directory" => "/tmp"),
      "regenerate cleanup step twice (N26)" => regenerate_next + "\n" + render_step(REGENERATE_CLEANUP_STEP, REGENERATE_CLEANUP),
      "regenerate cleanup step while the pull request step has no id: cpr" =>
        regenerate_current.rstrip + "\n\n" + render_step(REGENERATE_CLEANUP_STEP, REGENERATE_CLEANUP)
    }.each do |label, text|
      fixture_changed!(label, regenerate_next, text)
      File.write(regenerate, text)
      expect_rejected(label) { validate_repo(tmp) }
    end
    # The same refusals reached by editing the workflow's own text, each
    # [label, from, to, step] through fixture_sub (zheref/hatsu#136).
    [
      ["regenerate cleanup step with its two lines folded into one (N22)", "        run: |\n", "        run: >-\n", REGENERATE_CLEANUP_STEP],
      ["regenerate cleanup step with a merge key in its env (N24)", "          REPO: ${{ github.repository }}\n        shell: bash",
       "          REPO: ${{ github.repository }}\n          <<: {GH_HOST: attacker.invalid}\n        shell: bash", REGENERATE_CLEANUP_STEP],
      ["regenerate cleanup step behind a pull request step with continue-on-error (N25)", "        id: cpr\n", "        id: cpr\n        continue-on-error: true\n", pr_step],
      ["regenerate cleanup step under a job-level BASH_ENV", "    runs-on: ubuntu-latest\n", "    runs-on: ubuntu-latest\n    env:\n      BASH_ENV: ./evil.sh\n", nil],
      ["regenerate cleanup step under a workflow-level BASH_ENV", "\njobs:\n", "\nenv:\n  BASH_ENV: ./evil.sh\njobs:\n", nil],
      ["regenerate with ENV set on an earlier step", %Q{        id: stamp\n}, %Q{        id: stamp\n        env:\n          ENV: ./x.sh\n}, "Read the plugin stamp"],
      ["regenerate job with a container", "    runs-on: ubuntu-latest\n", "    runs-on: ubuntu-latest\n    container: node:20\n", nil],
      ["regenerate step with NODE_OPTIONS in its env", "          NEN_BIN: ${{ steps.nen.outputs.bin }}\n",
       "          NEN_BIN: ${{ steps.nen.outputs.bin }}\n          NODE_OPTIONS: --require ./x.js\n", "Verify the regenerated tree passes its own drift check"]
    ].each { |label, from, to, step| hostile.call(label, regenerate, regenerate_next, from, to, step: step) }

    # --- every builder step but the pull request step, frozen (zheref/hatsu#190)
    # Each edit below passed main's lexical checks before the freeze: P0 is
    # Feitan's (`git -C .` keeps `git` and `push` apart), the rest reach a ref,
    # the checkout, a step's env or its exit status the same way.
    generate_step = "Regenerate every surface"
    drift_step = "Detect drift"
    [
      ["regenerate step pushing a tag through git -C (Feitan P0)", %Q{          echo "value=$stamp" >> "$GITHUB_OUTPUT"\n},
       %Q{          echo "value=$stamp" >> "$GITHUB_OUTPUT"\n          git -C . push origin HEAD:refs/tags/v9.9.9\n}, "Read the plugin stamp"],
      ["regenerate step deleting another branch through the API", %Q{            echo "dirty=false" >> "$GITHUB_OUTPUT"\n},
       %Q{            echo "dirty=false" >> "$GITHUB_OUTPUT"\n            gh api -X DELETE "repos/${GITHUB_REPOSITORY}/git/refs/heads/release"\n}, drift_step],
      ["regenerate step interpolating the head commit message into its run", "          set -euo pipefail\n          for surface in",
       %Q{          set -euo pipefail\n          echo "${{ github.event.head_commit.message }}"\n          for surface in}, generate_step],
      ["regenerate step with the head commit message in a comment line of its run", "          set -euo pipefail\n          for surface in",
       "          set -euo pipefail\n          # ${{ github.event.head_commit.message }}\n          for surface in", generate_step],
      ["regenerate step with a comment line in its run", %Q{          curl -fsSL "$url" -o "${RUNNER_TEMP}/nen-bootstrap.sh"\n},
       %Q{          # fetched to a file, never piped\n          curl -fsSL "$url" -o "${RUNNER_TEMP}/nen-bootstrap.sh"\n},
       "Bootstrap nen at the pinned ref (checksum-verified, two steps, never a pipe)"],
      ["regenerate pin step off by one byte", %Q{          echo "pinned nen ref: $ref"\n}, %Q{          echo "pinned nen ref:  $ref"\n},
       "Read the pinned nen ref from nen/contract.json"],
      ["regenerate step with GH_TOKEN added to its env", "          STAMP: ${{ steps.stamp.outputs.value }}\n",
       "          STAMP: ${{ steps.stamp.outputs.value }}\n          GH_TOKEN: ${{ github.token }}\n", generate_step],
      ["regenerate step running a binary from the checkout as NEN", "          NEN: ${{ steps.nen.outputs.bin }}\n", "          NEN: ./bin/nen\n", generate_step],
      ["regenerate drift step gaining an if", "        id: drift\n", "        id: drift\n        if: always()\n", drift_step],
      ["regenerate verify step that swallows a failed check", %Q{          bash scripts/surface_mirror_check.sh "$PWD"\n},
       %Q{          bash scripts/surface_mirror_check.sh "$PWD" || true\n}, "Verify the regenerated tree passes its own drift check"],
      ["regenerate checkout of another repository's main", "          ref: main\n", "          ref: main\n          repository: attacker/hatsu\n", "Checkout main"],
      # The pull request step, held short of frozen (REGENERATE_PR_WITH).
      ["regenerate PR step gaining a with input", "          delete-branch: true\n", "          delete-branch: true\n          add-paths: .github/workflows\n", pr_step],
      ["regenerate PR step with an input's value changed", "          delete-branch: true\n", "          delete-branch: false\n", pr_step],
      ["regenerate PR step gaining a step key", "        id: cpr\n", "        id: cpr\n        env:\n          GH_TOKEN: ${{ github.token }}\n", pr_step]
    ].each { |label, from, to, step| hostile.call(label, regenerate, regenerate_original, from, to, step: step) }
    # `body` is the one free input: its prose may change.
    File.write(regenerate, fixture_sub("regenerate PR step with its body reworded", regenerate_original,
                                       "regeneration — no hand edits.", "regeneration, and no hand edits.", step: pr_step))
    validate_repo(tmp, announce: false)
    File.write(regenerate, regenerate_original)

    # The expression rule on its own, in the steps no freeze holds: a `${{ }}`
    # in a run is refused in every workflow, a bash comment line included.
    hostile.call("plugin-bump-check step interpolating the PR title into its run", plugin, original,
                 %Q{          echo "guard script: $guard"\n},
                 %Q{          echo "guard script: $guard"\n          echo "checking ${{ github.event.pull_request.title }}"\n}, step: guard_step)
    File.write(plugin, original)
    hostile.call("surface-mirror-check step with the PR body in a comment line of its run", surface, surface_original,
                 "          guard=.trusted/scripts/surface_mirror_check.sh\n",
                 "          # PR: ${{ github.event.pull_request.body }}\n          guard=.trusted/scripts/surface_mirror_check.sh\n",
                 step: "Surface-mirror drift check")
    File.write(surface, surface_original)
    validate_repo(tmp, announce: false)

    # --- the nen digest step (zheref/hatsu#230) ------------------------------
    # Every workflow that bootstraps nen carries the digest step right after
    # its bootstrap, which prints only the path while the digest step prints
    # the version last, after the match. Without the step, moved, in the old
    # order or with any edit below, each is refused, and tenkai's rendered
    # form carries none.
    fail_policy("self-test: NEN_BOOTSTRAP_NEXT still runs the binary") if NEN_BOOTSTRAP_NEXT.fetch("run").include?("--version")
    unless REGENERATE_FROZEN_STEPS.fetch("Bootstrap nen at the pinned ref (checksum-verified, two steps, never a pipe)") == NEN_BOOTSTRAP_NEXT
      fail_policy("self-test: the builder's bootstrap is not NEN_BOOTSTRAP_NEXT")
    end
    digest_block = ->(name) { /^      - name: #{Regexp.escape(name)}\n.*?(?=^      - name: )/m }
    version_line = "          #{NEN_BOOTSTRAP_VERSION_LINE}\n"
    output_line = %Q{          echo "bin=$bin" >> "$GITHUB_OUTPUT"\n}
    bootstrap_of = ->(text) { text[/^      - name: (Bootstrap nen at [^\n]*)\n/, 1] }
    digest_into = lambda do |label, base, before_step, name, frozen|
      next base if base.include?("      - name: #{name}\n")
      unprinted = fixture_sub("#{label}, its bootstrap printing only the path", base, version_line, "", step: bootstrap_of.call(base))
      fixture_sub(label, unprinted, "      - name: #{before_step}\n", render_step(name, frozen) + "\n      - name: #{before_step}\n", step: name)
    end
    surface_digest = digest_into.call("surface-mirror-check with the nen digest step", surface_original,
                                      "Surface-mirror drift check", NEN_DIGEST_STEP, NEN_DIGEST_FROZEN)
    readiness_digest = digest_into.call("pr-readiness with the nen digest step", readiness_frozen,
                                        READINESS_VERDICT_STEP, NEN_DIGEST_STEP, NEN_DIGEST_FROZEN)
    regenerate_digest = digest_into.call("surface-mirror-regenerate with the nen digest step", regenerate_original,
                                         "Read the plugin stamp", REGENERATE_NEN_DIGEST_STEP, REGENERATE_NEN_DIGEST_FROZEN)
    [[surface, surface_digest, surface_original], [readiness, readiness_digest, readiness_original],
     [regenerate, regenerate_digest, regenerate_original]].each do |file, text, restore|
      File.write(file, text)
      validate_repo(tmp, announce: false)
      File.write(file, restore)
    end
    digest_mismatch = %Q{expected sha256 ${expected}, observed ${observed}."\n            exit 1\n}
    digest_first = %Q{          set -euo pipefail\n          [ -f "$NEN_BIN" ]}
    bootstrap_then_digest = /^(      - name: Bootstrap nen at the trusted pinned ref[^\n]*\n.*?)(^      - name: #{Regexp.escape(NEN_DIGEST_STEP)}\n.*?)(?=^      - name: )/m
    [
      # The old order: the bootstrap running the binary beside the digest step.
      ["surface-mirror-check bootstrap running nen before the digest step checks it", surface, surface_digest,
       output_line, output_line + version_line, bootstrap_of.call(surface_digest)],
      ["pr-readiness bootstrap running nen before the digest step checks it", readiness, readiness_digest,
       output_line, output_line + version_line, bootstrap_of.call(readiness_digest)],
      ["surface-mirror-regenerate bootstrap running nen before the digest step checks it", regenerate, regenerate_digest,
       output_line, output_line + version_line, bootstrap_of.call(regenerate_digest)],
      ["nen digest step running nen before its match", surface, surface_digest,
       digest_first, %Q{          set -euo pipefail\n          "$NEN_BIN" --version\n          [ -f "$NEN_BIN" ]}, NEN_DIGEST_STEP],
      ["surface-mirror-check without the nen digest step", surface, surface_digest, digest_block.call(NEN_DIGEST_STEP), "", NEN_DIGEST_STEP],
      ["pr-readiness without the nen digest step", readiness, readiness_digest, digest_block.call(NEN_DIGEST_STEP), "", NEN_DIGEST_STEP],
      ["surface-mirror-regenerate without the nen digest step", regenerate, regenerate_digest,
       digest_block.call(REGENERATE_NEN_DIGEST_STEP), "", REGENERATE_NEN_DIGEST_STEP],
      ["nen digest step reading the PR head's contract", surface, surface_digest,
       ".trusted/nen/contract.json 2>/dev/null", "nen/contract.json 2>/dev/null", NEN_DIGEST_STEP],
      ["nen digest step comparing the darwin-arm64 digest", readiness, readiness_digest,
       %q{sha256["linux-x64"]}, %q{sha256["darwin-arm64"]}, NEN_DIGEST_STEP],
      ["nen digest step that passes a mismatch", readiness, readiness_digest,
       digest_mismatch, digest_mismatch.sub("exit 1", "exit 0"), NEN_DIGEST_STEP],
      ["nen digest step hashing another file", regenerate, regenerate_digest,
       %Q{sha256sum "$NEN_BIN"}, %Q{sha256sum "$0"}, REGENERATE_NEN_DIGEST_STEP],
      ["nen digest step with GH_TOKEN in its env", regenerate, regenerate_digest,
       "          NEN_BIN: ${{ steps.nen.outputs.bin }}\n        shell: bash\n",
       "          NEN_BIN: ${{ steps.nen.outputs.bin }}\n          GH_TOKEN: ${{ github.token }}\n        shell: bash\n", REGENERATE_NEN_DIGEST_STEP],
      ["nen digest step moved before the bootstrap step it checks", surface, surface_digest,
       bootstrap_then_digest, ->(match) { match[2] + match[1] }, NEN_DIGEST_STEP],
      ["nen digest step in tenkai's rendered readiness form", readiness, rendered_process,
       "      - name: #{READINESS_VERDICT_STEP}\n", render_step(NEN_DIGEST_STEP, NEN_DIGEST_FROZEN) + "\n      - name: #{READINESS_VERDICT_STEP}\n",
       NEN_DIGEST_STEP]
    ].each do |label, file, base, from, to, step|
      hostile.call(label, file, base, from, to, step: step)
      File.write(file, { surface => surface_original, readiness => readiness_original, regenerate => regenerate_original }.fetch(file))
    end

    # The canon-contracts step (zheref/hatsu#223, step one): the shape with the
    # step after the drift step validates in its frozen form; any other place,
    # count or body is refused. The anchor name is held here too: a renamed
    # drift step breaks this fixture before it could collapse the two shapes.
    fail_policy("self-test: CANON_CONTRACTS_AFTER is not a surface-mirror-check.yml step") unless EXPECTED_STEPS.fetch("surface-mirror-check.yml").include?(CANON_CONTRACTS_AFTER)
    canon_after = "#{CANON_CONTRACTS_AFTER}\n"
    canon_block = render_step(CANON_CONTRACTS_STEP, CANON_CONTRACTS_FROZEN)
    finish_step = "Finish check on the exact PR head"
    surface_canon = fixture_sub("surface-mirror-check with the canon-contracts step", surface_original,
                                "      - name: #{finish_step}\n", canon_block + "\n      - name: #{finish_step}\n", step: CANON_CONTRACTS_STEP)
    fail_policy("self-test: the canon-contracts fixture did not insert the step") unless surface_canon.include?("      - name: #{CANON_CONTRACTS_STEP}\n")
    File.write(surface, surface_canon)
    validate_repo(tmp, announce: false)
    File.write(surface, surface_original)
    canon_body = %Q{          NEN="$NEN_BIN" bash "$guard" --root "$PWD" 2>&1 || code=$?\n}
    # Doubled: a second copy of the frozen step is a step-set change, refused by
    # name (fixture_sub cannot express an edit that adds a same-named step).
    doubled = surface_canon.sub("      - name: #{finish_step}\n", canon_block + "\n      - name: #{finish_step}\n")
    fail_policy("self-test: the doubled canon-contracts fixture did not change the text") if doubled == surface_canon
    File.write(surface, doubled)
    expect_rejected("canon-contracts step doubled") { validate_repo(tmp) }
    File.write(surface, surface_original)
    [
      ["canon-contracts step before the drift step", surface, surface_original,
       "      - name: #{canon_after}", canon_block + "\n      - name: #{canon_after}", CANON_CONTRACTS_STEP],
      ["canon-contracts step running the PR head's own script", surface, surface_canon,
       canon_body, %Q{          NEN="$NEN_BIN" bash scripts/canon_contracts_check.sh --root "$PWD" 2>&1 || code=$?\n}, CANON_CONTRACTS_STEP],
      ["canon-contracts step executing the script directly", surface, surface_canon,
       canon_body, %Q{          NEN="$NEN_BIN" ./scripts/canon_contracts_check.sh --root "$PWD" 2>&1 || code=$?\n}, CANON_CONTRACTS_STEP],
      ["canon-contracts step judging the trusted tree instead of the PR's", surface, surface_canon,
       canon_body, %Q{          NEN="$NEN_BIN" bash "$guard" 2>&1 || code=$?\n}, CANON_CONTRACTS_STEP],
      ["canon-contracts step on a bare nen from PATH", surface, surface_canon,
       canon_body, %Q{          bash "$guard" --root "$PWD" 2>&1 || code=$?\n}, CANON_CONTRACTS_STEP],
      ["canon-contracts step without the output fence", surface, surface_canon,
       %Q{          echo "::stop-commands::${stop}"\n#{canon_body}}, canon_body, CANON_CONTRACTS_STEP],
      ["canon-contracts step with GH_TOKEN in its env", surface, surface_canon,
       "          NEN_BIN: ${{ steps.nen.outputs.bin }}\n        shell: bash\n        run: |\n          set -uo pipefail\n          guard=.trusted/scripts/canon_contracts_check.sh",
       "          NEN_BIN: ${{ steps.nen.outputs.bin }}\n          GH_TOKEN: ${{ github.token }}\n        shell: bash\n        run: |\n          set -uo pipefail\n          guard=.trusted/scripts/canon_contracts_check.sh", CANON_CONTRACTS_STEP],
      ["canon-contracts step passing a refusal", surface, surface_canon,
       %Q{nen/labels.json) — see the guard output above."; exit 1 ;;}, %Q{nen/labels.json) — see the guard output above."; exit 0 ;;}, CANON_CONTRACTS_STEP]
    ].each do |label, file, base, from, to, step|
      hostile.call(label, file, base, from, to, step: step)
      File.write(file, surface_original)
    end
    validate_repo(tmp, announce: false)
    # Hatsu's own repository carries only its own readiness form (Feitan,
    # hanten on #230): with templates/pr-readiness.yml at the root, its own form
    # passes and tenkai's rendering of it is refused.
    marker = File.join(tmp, "templates", "pr-readiness.yml")
    FileUtils.mkdir_p(File.dirname(marker))
    File.write(marker, "# marks this scratch root as Hatsu's own\n")
    validate_repo(tmp, announce: false)
    File.write(readiness, rendered_process)
    expect_rejected("tenkai's rendered readiness form in Hatsu's own repository", /carries only its own form/) { validate_repo(tmp) }
    File.delete(marker)
    Dir.rmdir(File.dirname(marker))
    File.write(readiness, readiness_original)
    validate_repo(tmp, announce: false)

    # --- the digest step RUNS as frozen (zheref/hatsu#230, criterion 3) -----
    # The one place this self-test executes shell, and only its own constants,
    # never a workflow's text: each body under bash as Actions runs it, against
    # a scratch binary and contract, in a clean environment. The recorded
    # digest passes, and only then is the binary run, for its version; every
    # other case fails closed -- a tampered digest naming both, a missing or
    # malformed key (a trailing newline included), a missing contract, a missing
    # binary, a hash that fails -- and never runs it. jq and sha256sum are what
    # the step runs: without them these cases cannot run, which is a failure
    # here, never a skip.
    %w[bash jq sha256sum].each do |tool|
      found = ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, tool)) }
      fail_policy("self-test: the nen digest step's runtime cases need #{tool} on PATH") unless found
    end
    [[NEN_DIGEST_STEP, NEN_DIGEST_FROZEN, ".trusted/nen/contract.json"],
     [REGENERATE_NEN_DIGEST_STEP, REGENERATE_NEN_DIGEST_FROZEN, "nen/contract.json"]].each do |name, frozen, contract_path|
      Dir.mktmpdir("hatsu-nen-digest") do |dir|
        binary = File.join(dir, "nen-linux-x64")
        File.write(binary, "#!/bin/sh\necho 0.0.0-digest-fixture\n")
        File.chmod(0o755, binary)
        recorded = Digest::SHA256.file(binary).hexdigest
        failing_hash = File.join(dir, "failing-hash")
        FileUtils.mkdir_p(failing_hash)
        File.write(File.join(failing_hash, "sha256sum"), "#!/bin/sh\nexit 1\n")
        File.chmod(0o755, File.join(failing_hash, "sha256sum"))
        tampered = Digest::SHA256.hexdigest("a binary that moved under its tag\n")
        contract = File.join(dir, contract_path)
        FileUtils.mkdir_p(File.dirname(contract))
        [
          ["the recorded digest", { "linux-x64" => recorded }, binary, 0, ["matches", "nen: 0.0.0-digest-fixture at #{binary}"]],
          ["a digest with a trailing newline", { "linux-x64" => "#{recorded}\n" }, binary, 1, ["::error::", "observed #{recorded}"]],
          ["a tampered digest", { "linux-x64" => tampered }, binary, 1, ["::error::", "expected sha256 #{tampered}", "observed #{recorded}"]],
          ["no linux-x64 key", { "darwin-arm64" => recorded }, binary, 1, ["::error::", "found ''", "observed #{recorded}"]],
          ["an uppercase digest", { "linux-x64" => recorded.upcase }, binary, 1, ["::error::", "observed #{recorded}"]],
          ["a digest that is an object", { "linux-x64" => { "sha256" => recorded } }, binary, 1, ["::error::", "observed #{recorded}"]],
          ["sha256 that is a string", recorded, binary, 1, ["::error::", "observed #{recorded}"]],
          ["a digest carrying a workflow command", { "linux-x64" => "#{recorded}\n::warning::forged" }, binary, 1, ["::error::", "???warning??"]],
          ["no contract at all", nil, binary, 1, ["::error::", "nen/contract.json to read the expected sha256 from"]],
          ["no binary at the printed path", { "linux-x64" => recorded }, File.join(dir, "absent"), 1, ["::error::"]],
          ["a hash that fails", { "linux-x64" => recorded }, binary, 1, ["::error::could not hash the bootstrapped nen binary"], failing_hash]
        ].each do |label, sha256, bin, want_status, want_text, path_first|
          FileUtils.rm_f(contract)
          File.write(contract, JSON.generate("dependency" => { "bootstrap" => { "sha256" => sha256 } })) unless sha256.nil?
          path = [path_first, ENV.fetch("PATH")].compact.join(File::PATH_SEPARATOR)
          out, status = Open3.capture2e({ "PATH" => path, "NEN_BIN" => bin }, "bash", "--noprofile", "--norc", "-eo", "pipefail",
                                        "-c", frozen.fetch("run"), chdir: dir, unsetenv_others: true)
          ran = out.include?("0.0.0-digest-fixture")
          ok = status.exitstatus == want_status && want_text.all? { |text| out.include?(text) } &&
               out.lines.none? { |line| line.start_with?("::warning") } && (want_status.zero? || !ran)
          fail_policy("self-test: #{name.inspect} with #{label} exited #{status.exitstatus}, printing #{out.strip.inspect}") unless ok
        end
      end
    end

    # --- prose-size-check.yml (zheref/hatsu#135) ----------------------------
    # Installed, and required to be: its absence is refused. A checkout
    # without it (a process repository without Hatsu's prose guard) is refused
    # for the missing file already, so these cases have no workflow to judge
    # there.
    prose_source = File.join(root, ".github/workflows", PROSE_WORKFLOW)
    if File.file?(prose_source)
      prose = File.join(tmp, ".github/workflows", PROSE_WORKFLOW)
      prose_installed = File.file?(prose)
      prose_original = File.read(prose_source)
      File.write(prose, prose_original)
      validate_repo(tmp, announce: false)
      FileUtils.rm(prose)
      expect_rejected("#{PROSE_WORKFLOW} missing") { validate_repo(tmp) }
      File.write(prose, prose_original)
      prose_offender = %Q{Diet the file; ceilings are not raised (zheref/hatsu#119)."\n              exit 1\n}
      [
        ["prose guard run from the PR checkout", "guard=.trusted/scripts/prose_size_check.sh", "guard=scripts/prose_size_check.sh", PROSE_GUARD_STEP],
        ["prose guard that passes an offender", prose_offender, prose_offender.sub("exit 1", "exit 0"), PROSE_GUARD_STEP],
        ["prose guard printing PR file names unfenced", %Q{          echo "::stop-commands::${stop}"\n}, "", PROSE_GUARD_STEP],
        ["prose-size-check creating its check under another name", "-f name=prose-size-check ", "-f name=prose ", "Start check on the exact PR head"],
        ["prose-size-check under a paths filter", /^    types: \[.*\]\n/, ->(match) { "#{match[0]}    paths: ['claude/**']\n" }, nil],
        ["prose-size-check with the bare same-repository guard", /^    if: .*\n/, "    if: #{SAME_REPO_GUARD}\n", nil],
        ["prose-size-check on a self-hosted runner", "runs-on: ubuntu-latest", "runs-on: [self-hosted, macOS, ARM64]", nil]
      ].each { |label, from, to, step| hostile.call(label, prose, prose_original, from, to, step: step) }
      File.write(prose, prose_original)

      # The guard step RUNS as frozen: its own constant under bash as Actions
      # runs it, the trusted guard beside this validator measuring a scratch
      # Hatsu-shaped tree built from that guard's own diet list and ceiling,
      # never the pull request's tree. Within every ceiling it passes; a
      # dieted skill one byte over fails the step, its offender named inside
      # the fence (the row's own format is prose-guard's fixture's to hold); a
      # token that is not fresh fails before anything is measured; a root that
      # is no Hatsu checkout fails as wiring. Without the guard or its tools
      # these cases cannot run, a failure here, never a skip.
      guard_script = File.join(__dir__, "prose_size_check.sh")
      fail_policy("self-test: #{PROSE_WORKFLOW} runs scripts/prose_size_check.sh, which is not beside this validator") unless File.file?(guard_script)
      %w[bash sh perl openssl awk].each do |tool|
        found = ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, tool)) }
        fail_policy("self-test: the prose guard step's runtime cases need #{tool} on PATH") unless found
      end
      guard_text = File.read(guard_script)
      dieted = guard_text[/^DIETED_SKILLS="([^"]*)"/m, 1].to_s.split
      skill_max = guard_text[/^SKILL_MAX=(\d+)$/, 1].to_i
      fail_policy("self-test: could not read DIETED_SKILLS and SKILL_MAX from scripts/prose_size_check.sh") if dieted.empty? || skill_max.zero?
      Dir.mktmpdir("hatsu-prose-guard") do |dir|
        FileUtils.mkdir_p(File.join(dir, ".trusted/scripts"))
        FileUtils.cp(guard_script, File.join(dir, ".trusted/scripts/prose_size_check.sh"))
        FileUtils.mkdir_p(File.join(dir, "claude/agents"))
        agent = File.join(dir, "claude/agents/scout.md")
        File.write(agent, "a scratch agent\n")
        dieted.each do |skill|
          FileUtils.mkdir_p(File.join(dir, "claude/skills", skill))
          File.write(File.join(dir, "claude/skills", skill, "SKILL.md"), "a scratch skill\n")
        end
        skill = File.join(dir, "claude/skills", dieted.first, "SKILL.md")
        fence = /^::stop-commands::(stop_[0-9a-f]{32})\n.*^::\1::$/m
        stand_in = lambda do |name, body|
          bin = File.join(dir, name)
          FileUtils.mkdir_p(bin)
          File.write(File.join(bin, "openssl"), body)
          File.chmod(0o755, File.join(bin, "openssl"))
          bin
        end
        failing = stand_in.call("openssl-fails", "#!/bin/sh\nexit 1\n")
        silent = stand_in.call("openssl-silent", "#!/bin/sh\nexit 0\n")
        # [label, arrange, a PATH entry first, exit, texts, the fenced text -- nil where no fence may print]
        [
          ["every file within its ceiling", -> {}, nil, 0, ["prose ok", "every measured file is within its prose ceiling."], ""],
          ["a dieted skill one byte over", -> { File.write(skill, "x" * (skill_max + 1)) }, nil, 1,
           ["::error::a file is over its prose ceiling"], "claude/skills/#{dieted.first}/SKILL.md"],
          ["an openssl that fails", -> { File.write(skill, "a scratch skill\n") }, failing, 1, ["::error::could not draw a fresh token"], nil],
          ["an openssl that prints nothing", -> {}, silent, 1, ["::error::could not draw a fresh token"], nil],
          ["a root that is no Hatsu checkout", -> { FileUtils.mv(File.join(dir, "claude/skills"), File.join(dir, "skills-moved")) }, nil, 1,
           ["::error::the prose guard could not run (exit 2), a wiring refusal"], ""]
        ].each do |label, arrange, path_first, want_status, want_text, fenced|
          arrange.call
          path = [path_first, ENV.fetch("PATH")].compact.join(File::PATH_SEPARATOR)
          out, status = Open3.capture2e({ "PATH" => path }, "bash", "--noprofile", "--norc", "-eo", "pipefail",
                                        "-c", PROSE_FROZEN_GUARD.fetch("run"), chdir: dir, unsetenv_others: true)
          fence_ok = if fenced.nil?
                       !out.include?("::stop-commands::")
                     else
                       (match = out.match(fence)) && match[0].include?(fenced)
                     end
          ok = status.exitstatus == want_status && want_text.all? { |text| out.include?(text) } && fence_ok
          fail_policy("self-test: #{PROSE_GUARD_STEP.inspect} with #{label} exited #{status.exitstatus}, printing #{out.strip.inspect}") unless ok
        end
      end
      prose_installed ? File.write(prose, prose_original) : FileUtils.rm(prose)
      validate_repo(tmp, announce: false)
    end

    # Remove the builder again: the ABSENT case must still validate after all
    # of this file's churn, confirming its optionality one more time.
    FileUtils.rm(regenerate)
    validate_repo(tmp, announce: false)

    # And the control: a DIAGNOSTIC naming the file is not a read. This workflow
    # already carries `echo "::error::nen/contract.json carries no ..."`, mid-line
    # inside a `|| { ... }` guard, and it must keep validating.
    File.write(surface, surface_original)
    validate_repo(tmp, announce: false)
  end
  puts "workflow-runner-policy: negative fixtures passed"
end

root = File.expand_path(ARGV.last && ARGV.last != "--self-test" ? ARGV.last : File.join(__dir__, ".."))
self_test(root) if ARGV.include?("--self-test")
validate_repo(root)
