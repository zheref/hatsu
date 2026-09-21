#!/usr/bin/env ruby
# Structural, offline regression guard for Hatsu's workflow runner policy.
require "psych"
require "tmpdir"
require "fileutils"

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
PORTABLE_HOSTED_WORKFLOWS = %w[plugin-bump-check.yml surface-mirror-check.yml pr-readiness.yml].freeze

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
KNOWN_WORKFLOWS = (PORTABLE_HOSTED_WORKFLOWS + BUILDER_WORKFLOWS).freeze

EXPECTED_JOBS = {
  "plugin-bump-check.yml" => "check",
  "surface-mirror-check.yml" => "surface-mirror-check",
  "pr-readiness.yml" => "readiness",
  "surface-mirror-regenerate.yml" => "regenerate"
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
  "pr-readiness.yml" => [SAME_REPO_GUARD, DRAFT_SKIP_GUARD].freeze
}.freeze

# `cancel-in-progress` is a PR-GUARD property, not a builder one. A guard
# superseded by a newer push has nothing left worth finishing, so cancelling
# it is free; a REGENERATION superseded mid-run could leave `surfaces/` half
# written when the `git status --porcelain` check below runs, so it is
# FORBIDDEN there instead — the second push queues behind the first rather
# than racing it.
CANCEL_IN_PROGRESS_REQUIRED = %w[plugin-bump-check.yml surface-mirror-check.yml pr-readiness.yml].freeze
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
  "pr-readiness.yml" => :end
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
    "Readiness verdict",
    # The freshness confirmation is a DECLARED step rather than an implementation
    # detail: it is what stops an in-flight older run publishing a verdict about a
    # head that has since moved, so removing it must fail the guard.
    "Confirm the verdict still describes the event head",
    "Publish the check on the exact PR head"
  ],
  "surface-mirror-regenerate.yml" => [
    "Checkout main",
    "Read the pinned nen ref from nen/contract.json",
    "Bootstrap nen at the pinned ref (checksum-verified, two steps, never a pipe)",
    "Read the plugin stamp",
    "Regenerate every surface",
    "Detect drift",
    "Verify the regenerated tree passes its own drift check",
    "Open a pull request with the regenerated mirrors"
  ]
}.freeze

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

def fail_policy(message)
  warn "workflow-runner-policy: #{message}"
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

def reject_duplicate_keys(node, context = "workflow")
  case node
  when Psych::Nodes::Mapping
    seen = {}
    node.children.each_slice(2) do |key, value|
      fail_policy("#{context} repeats key #{key.value.inspect}") if seen[key.value]
      seen[key.value] = true
      reject_duplicate_keys(value, "#{context}.#{key.value}")
    end
  when Psych::Nodes::Sequence
    node.children.each_with_index { |child, index| reject_duplicate_keys(child, "#{context}[#{index}]") }
  end
end

def scalar(node)
  node&.value
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

def expect_rejected(label)
  rejected = false
  begin
    yield
  rescue SystemExit => error
    raise unless error.status == 1
    rejected = true
  end
  fail_policy("#{label} was accepted") unless rejected
end

def validate_workflow(path)
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
      fail_policy("#{path} job #{job_name} needs the same-repository job guard, bare or with the draft-skip conjunction")
    end

    validate_timeout(path, job_name, job)

    runner_node = job.fetch("runs-on") { fail_policy("#{path} job #{job_name} has no runs-on") }
    runner = runner_node.is_a?(Psych::Nodes::Sequence) ? sequence(runner_node, "runs-on") : scalar(runner_node)
    allowed = runner == MAC_RUNNER || runner == WINDOWS_RUNNER || runner == HOSTED_RUNNER
    fail_policy("#{path} job #{job_name} uses an unapproved runner #{runner.inspect}") unless allowed
    if PORTABLE_HOSTED_WORKFLOWS.include?(File.basename(path)) && runner != HOSTED_RUNNER
      fail_policy("#{path} is portable and must use GitHub-hosted ubuntu-latest")
    end

    fail_policy("#{path} job #{job_name} must inherit workflow permissions") if job.key?("permissions")

    next unless targets_pr
    steps_node = job.fetch("steps") { fail_policy("#{path} job #{job_name} has no steps") }
    fail_policy("#{path} job #{job_name} steps must be a sequence") unless steps_node.is_a?(Psych::Nodes::Sequence)
    steps = steps_node.children
    step_maps = steps.each_with_index.map { |node, index| mapping(node, "#{path} job #{job_name} step #{index + 1}") }
    step_names = step_maps.map { |step| scalar(step["name"]) }
    fail_policy("#{path} job #{job_name} step set or order changed") unless step_names == EXPECTED_STEPS.fetch(File.basename(path))
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
    jobs.each_value do |node|
      job_map = mapping(node, "#{path} job")
      fail_policy("#{path} job sets working-directory") if job_map.key?("defaults")
      steps_node = job_map["steps"]
      next unless steps_node.is_a?(Psych::Nodes::Sequence)
      steps_node.children.each do |step_node|
        step_map = mapping(step_node, "#{path} step")
        fail_policy("#{path} step #{scalar(step_map["name"]).inspect} sets working-directory") if step_map.key?("working-directory")
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
      validate_workflow(path)
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
  fail_policy("#{path} job #{expected_job} step set or order changed") unless step_names == EXPECTED_STEPS.fetch(basename)

  fail_policy("#{path} sets workflow defaults, which can carry working-directory") if root.key?("defaults")
  fail_policy("#{path} job sets working-directory") if job.key?("defaults")
  step_maps.each do |step|
    code = code_of(scalar(step["run"]))
    fail_policy("#{path} step #{scalar(step["name"]).inspect} sets working-directory") if step.key?("working-directory")
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

  checkout_steps = step_maps.select { |step| scalar(step["uses"])&.start_with?("actions/checkout@") }
  fail_policy("#{path} must checkout main") unless checkout_steps.any? { |step| scalar(mapping(step["with"], "#{path} checkout with")["ref"]) == "main" }
end

def self_test(root)
  fail_policy("same-repository predicate rejected owner head") unless same_repository?("zheref/hatsu", "zheref/hatsu")
  fail_policy("same-repository predicate admitted fork") if same_repository?("zheref/hatsu", "fork/hatsu")
  fail_policy("same-repository predicate admitted missing head repository") if same_repository?("zheref/hatsu", nil)
  fail_policy("same-repository predicate admitted another repository") if same_repository?("other/repo", "other/repo")

  Dir.mktmpdir("hatsu-workflow-policy") do |tmp|
    FileUtils.mkdir_p(File.join(tmp, ".github/workflows"))
    Dir.glob(File.join(root, ".github/workflows/*.{yml,yaml}")).each { |path| FileUtils.cp(path, File.join(tmp, ".github/workflows")) }
    validate_repo(tmp, announce: false)

    plugin = File.join(tmp, ".github/workflows/plugin-bump-check.yml")
    original = File.read(plugin)
    File.write(plugin, original.sub(/^    if: .*\n/, "").sub(/^      - name: Checkout PR head/, "      - if: #{SAME_REPO_GUARD}\n        name: Checkout PR head"))
    expect_rejected("step-only same-repository guard") { validate_repo(tmp) }

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
    File.write(plugin, original.sub("types: [opened, synchronize, reopened, edited]", "types: [closed]"))
    expect_rejected("changed pull_request_target types") { validate_repo(tmp) }

    File.write(plugin, original.sub("jobs:\n  check:", "jobs:\n  renamed:"))
    expect_rejected("renamed required check job") { validate_repo(tmp) }

    File.write(plugin, original.sub("  check:\n    if:", "  check:\n    permissions:\n      contents: read\n    if:"))
    expect_rejected("job permission override") { validate_repo(tmp) }

    File.write(plugin, original.sub("runs-on: ubuntu-latest", "runs-on: [self-hosted, macOS, ARM64]"))
    expect_rejected("portable workflow on a self-hosted Mac runner") { validate_repo(tmp) }

    File.write(plugin, original.sub("-f name=check ", "-f name=check-other "))
    expect_rejected("wrong exact-head check name") { validate_repo(tmp) }

    File.write(plugin, original.sub('ruby .trusted/scripts/workflow_runner_policy_check.rb --self-test "$PWD"', "true"))
    expect_rejected("missing trusted workflow policy invocation") { validate_repo(tmp) }

    File.write(plugin, original.sub(%Q{          bash "$guard" \\\n}, %Q{          bash scripts/plugin_bump_check.sh \\\n}))
    expect_rejected("PR-root script execution") { validate_repo(tmp) }

    nested_duplicate = original.sub("          GH_TOKEN: ${{ github.token }}", "          GH_TOKEN: first\n          GH_TOKEN: second")
    File.write(plugin, nested_duplicate)
    expect_rejected("nested duplicate YAML key") { validate_repo(tmp) }

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
    File.write(surface, surface_original.sub(
      %Q{ref="$(jq -r '.dependency.pinned_ref // empty' .trusted/nen/contract.json)"},
      %Q{# sourced from .trusted/nen/contract.json\n          ref="$(jq -r '.dependency.pinned_ref // empty' nen/contract.json)"}))
    expect_rejected("pin read from the PR checkout with the trusted path in a comment") { validate_repo(tmp) }

    # The same rule for the gates file, which selects REVIEWER IDENTITIES: an
    # unprefixed read is the PR choosing the gate that judges it.
    File.write(surface, surface_original.sub(
      %Q{          echo "ref=$ref" >> "$GITHUB_OUTPUT"},
      %Q{          cat nen/gates.json\n          echo "ref=$ref" >> "$GITHUB_OUTPUT"}))
    expect_rejected("gates file read from the PR checkout") { validate_repo(tmp) }

    # The widened trigger policy is still a CLOSED set, and this fixture is what
    # makes that true rather than asserted. `check_suite` is the specific event
    # that looks reasonable and is not admitted: its payload has no
    # `github.event.pull_request`, so the byte-compared SAME_REPO_GUARD above
    # would evaluate to null and the job would not be guarded as intended.
    File.write(surface, surface_original.sub(
      "  pull_request_target:", "  check_suite:\n    types: [completed]\n  pull_request_target:"))
    expect_rejected("workflow triggered by a non-admitted privileged event") { validate_repo(tmp) }

    # A workflow may not quietly GAIN an admitted trigger either -- the set is
    # compared against its declared map, not merely against the allowlist.
    File.write(surface, surface_original.sub(
      "  pull_request_target:", "  pull_request_review:\n    types: [submitted]\n  pull_request_target:"))
    expect_rejected("workflow gaining an undeclared admitted trigger") { validate_repo(tmp) }

    # THE DIAGNOSTIC EXEMPTION MUST BE SCOPED TO ITS OWN COMMAND. The reviewer's
    # own example: an earlier `echo` on the same shell line must not suppress
    # validation of a LATER command that really does read the PR's file.
    File.write(surface, surface_original.sub(
      %Q{          echo "ref=$ref" >> "$GITHUB_OUTPUT"},
      %Q{          echo ok; cat nen/gates.json\n          echo "ref=$ref" >> "$GITHUB_OUTPUT"}))
    expect_rejected("read hidden behind an earlier echo on the same line") { validate_repo(tmp) }

    # The same, separated by `&&` rather than `;`.
    File.write(surface, surface_original.sub(
      %Q{          echo "ref=$ref" >> "$GITHUB_OUTPUT"},
      %Q{          echo ok && jq . nen/contract.json\n          echo "ref=$ref" >> "$GITHUB_OUTPUT"}))
    expect_rejected("read hidden behind an earlier echo joined by &&") { validate_repo(tmp) }

    # A COMMAND SUBSTITUTION INSIDE `echo` IS A READ. The reviewer's example: the
    # segment begins with `echo`, so a command-word test exempts it, while the
    # substitution really does read the PR's contract and emit its value as the
    # pin.
    File.write(surface, surface_original.sub(
      %Q{          echo "ref=$ref" >> "$GITHUB_OUTPUT"},
      %Q{          echo "ref=$(jq -r .dependency.pinned_ref nen/contract.json)"\n          echo "ref=$ref" >> "$GITHUB_OUTPUT"}))
    expect_rejected("read inside a command substitution within a diagnostic") { validate_repo(tmp) }

    # PROCESS SUBSTITUTION RUNS A COMMAND AND CARRIES NO `$`. `echo > >(cat
    # nen/gates.json)` begins with `echo`, contains neither `$(` nor a backtick,
    # and reads the PR-controlled gates file in a subshell.
    File.write(surface, surface_original.sub(
      %Q{          echo "ref=$ref" >> "$GITHUB_OUTPUT"},
      %Q{          echo > >(cat nen/gates.json)\n          echo "ref=$ref" >> "$GITHUB_OUTPUT"}))
    expect_rejected("read through an output process substitution in a diagnostic") { validate_repo(tmp) }

    File.write(surface, surface_original.sub(
      %Q{          echo "ref=$ref" >> "$GITHUB_OUTPUT"},
      %Q{          echo hi < <(cat nen/contract.json)\n          echo "ref=$ref" >> "$GITHUB_OUTPUT"}))
    expect_rejected("read through an input process substitution in a diagnostic") { validate_repo(tmp) }

    # A BARE `&` IS A COMMAND SEPARATOR. `echo ok & cat nen/gates.json` runs
    # `cat`; splitting only on `&&` left the whole line reading as one `echo`.
    File.write(surface, surface_original.sub(
      %Q{          echo "ref=$ref" >> "$GITHUB_OUTPUT"},
      %Q{          echo ok & cat nen/gates.json\n          echo "ref=$ref" >> "$GITHUB_OUTPUT"}))
    expect_rejected("read after a bare & separator in a diagnostic") { validate_repo(tmp) }

    # A `cd` behind a keyword is still a `cd`. This is why the rule is now a word
    # test rather than a position test.
    File.write(surface, surface_original.sub(
      %Q{          echo "ref=$ref" >> "$GITHUB_OUTPUT"},
      %Q{          if cd evil; then echo x; fi\n          echo "ref=$ref" >> "$GITHUB_OUTPUT"}))
    expect_rejected("cd behind an if keyword") { validate_repo(tmp) }

    # `working-directory` moves the cwd DECLARATIVELY and was unchecked entirely.
    File.write(surface, surface_original.sub(
      "      - name: Surface-mirror drift check",
      "      - name: Surface-mirror drift check\n        working-directory: evil"))
    expect_rejected("step-level working-directory") { validate_repo(tmp) }

    # PLAIN REDIRECTION READS THE FILE without running any sub-command, so a
    # construct list built only from substitutions missed it.
    File.write(surface, surface_original.sub(
      %Q{          echo "ref=$ref" >> "$GITHUB_OUTPUT"},
      %Q{          echo < nen/gates.json\n          echo "ref=$ref" >> "$GITHUB_OUTPUT"}))
    expect_rejected("read through plain input redirection in a diagnostic") { validate_repo(tmp) }

    # A SIBLING DIRECTORY IS NOT THE TRUSTED CHECKOUT. `attacker.trusted/` ends
    # with `.trusted/`, which a suffix test accepted.
    File.write(surface, surface_original.sub(
      ".trusted/nen/contract.json", "attacker.trusted/nen/contract.json"))
    expect_rejected("pin read from a sibling directory ending in .trusted") { validate_repo(tmp) }

    # Nor is a traversal out of it.
    File.write(surface, surface_original.sub(
      ".trusted/nen/contract.json", "../.trusted/nen/contract.json"))
    expect_rejected("pin read through a traversal out of the trusted checkout") { validate_repo(tmp) }

    # A STEP MAY NOT MOVE THE WORKING DIRECTORY. Every trusted-path check above is
    # lexical and relative; a `cd` into a PR-controlled directory defeats all of
    # them while still matching TRUSTED_PREFIX.
    File.write(surface, surface_original.sub(
      %Q{          echo "ref=$ref" >> "$GITHUB_OUTPUT"},
      %Q{          cd "$RUNNER_TEMP"\n          echo "ref=$ref" >> "$GITHUB_OUTPUT"}))
    expect_rejected("step that changes the working directory") { validate_repo(tmp) }

    # `pull_request_review_thread` is a WEBHOOK event, not an Actions trigger. A
    # workflow naming it cannot register, so the allowlist must refuse it.
    File.write(surface, surface_original.sub(
      "  pull_request_target:", "  pull_request_review_thread:\n    types: [resolved, unresolved]\n  pull_request_target:"))
    expect_rejected("workflow naming the non-existent pull_request_review_thread trigger") { validate_repo(tmp) }
    File.write(surface, surface_original)

    # --- concurrency / timeout-minutes / draft-skip / paths (2026-09-20) -----

    File.write(plugin, original.sub(/^    timeout-minutes: \d+\n/, ""))
    expect_rejected("job missing timeout-minutes") { validate_repo(tmp) }

    File.write(plugin, original.sub("cancel-in-progress: true", "cancel-in-progress: false"))
    expect_rejected("guard workflow with cancel-in-progress: false") { validate_repo(tmp) }

    File.write(plugin, original.sub(/\n\s*cancel-in-progress: true\n/, "\n"))
    expect_rejected("guard workflow with no cancel-in-progress at all") { validate_repo(tmp) }

    # BOTH SHAPES ARE ACCEPTED (two-step landing, see ALLOWED_JOB_GUARDS): the
    # live `original` file carries the bare guard and BASE_TYPES today, and
    # that must keep validating exactly as-is -- proven already by the plain
    # `validate_repo(tmp)` call at the top of this function. What is proven
    # here is the OTHER shape: swapping in the hardened guard AND the
    # hardened trigger types together must ALSO validate, and independently,
    # swapping only one of the two must ALSO validate -- the two are not
    # required to move together.
    hardened_if = original.sub(/^    if: .*\n/, "    if: #{DRAFT_SKIP_GUARD}\n")
    File.write(plugin, hardened_if)
    validate_repo(tmp, announce: false) # hardened guard only, base types: must pass
    File.write(plugin, hardened_if.sub(
      "    types: [opened, synchronize, reopened, edited]",
      "    types: [opened, synchronize, reopened, edited, ready_for_review]"))
    validate_repo(tmp, announce: false) # both hardened together: must pass

    File.write(plugin, original.sub(
      "    types: [opened, synchronize, reopened, edited]",
      "    types: [opened, synchronize, reopened, edited, ready_for_review]"))
    validate_repo(tmp, announce: false) # hardened types only, bare guard: must pass

    # THE STRING-CONCATENATION BUG ITSELF, covered by fixture rather than only
    # by the comment above ALLOWED_JOB_GUARDS. Writing the draft conjunct so
    # it lands OUTSIDE the `${{ }}` expression must still be refused -- it is
    # not one of the two exact accepted strings, but a regex or suffix test in
    # place of the exact-string check could easily let it through.
    malformed_guard = "#{SAME_REPO_GUARD} && github.event.pull_request.draft == false"
    File.write(plugin, original.sub(/^    if: .*\n/, "    if: #{malformed_guard}\n"))
    expect_rejected("draft conjunct written outside the ${{ }} expression (string-concatenation bug)") { validate_repo(tmp) }

    File.write(plugin, original.sub(
      "    types: [opened, synchronize, reopened, edited]",
      "    types: [opened, synchronize, reopened, edited]\n    paths: ['claude/**']"))
    expect_rejected("plugin-bump-check gains a paths filter — it must judge every PR") { validate_repo(tmp) }

    File.write(plugin, original)

    # `paths:` is FORBIDDEN on surface-mirror-check.yml (Hatsu 0.44.0,
    # zheref/hatsu#97): it is a REQUIRED context, and a required context that
    # never wakes for a PR whose diff misses every listed path is a PR that
    # cannot merge -- a deadlock, not a false negative. Gaining one back is
    # therefore rejected the same way plugin-bump-check.yml gaining one is.
    File.write(surface, surface_original.sub(
      "    types: [opened, synchronize, reopened]",
      "    types: [opened, synchronize, reopened]\n    paths: ['claude/**']"))
    expect_rejected("surface-mirror-check gains a paths filter — it must judge every PR") { validate_repo(tmp) }

    File.write(surface, surface_original)

    # --- surface-mirror-regenerate.yml: the builder pipeline, OPTIONAL ------
    # It ships at `templates/surface-mirror-regenerate.yml`, not under
    # `.github/workflows/`, until the follow-up PR in the two-step landing
    # installs it (docs/GATE-CONFIGURATION.md). The plain `validate_repo(tmp)`
    # calls already run above -- before this workflow is ever copied in --
    # are what prove the ABSENT case passes; everything below proves the
    # PRESENT case: copy the template in, prove the untouched file validates,
    # then run every negative fixture against it exactly as before.
    regenerate = File.join(tmp, ".github/workflows/surface-mirror-regenerate.yml")
    regenerate_source = File.join(root, "templates/surface-mirror-regenerate.yml")
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

    File.write(regenerate, regenerate_original.sub(
      "group: surface-mirror-regenerate-${{ github.ref }}",
      "group: surface-mirror-regenerate-${{ github.ref }}\n  cancel-in-progress: true"))
    expect_rejected("regenerate workflow cancels in progress — a mid-run cancel risks a half-written surfaces/ tree") { validate_repo(tmp) }

    File.write(regenerate, regenerate_original.sub(/^    timeout-minutes: \d+\n/, ""))
    expect_rejected("regenerate job missing timeout-minutes") { validate_repo(tmp) }

    File.write(regenerate, regenerate_original.sub(
      /uses: peter-evans\/create-pull-request@[0-9a-f]{40} # v7\.0\.11/,
      "uses: peter-evans/create-pull-request@v7"))
    expect_rejected("regenerate PR step pinned by a mutable tag instead of a full commit SHA") { validate_repo(tmp) }

    File.write(regenerate, regenerate_original.sub(
      "branch: bot/surface-mirror-regenerate", "branch: main"))
    expect_rejected("regenerate PR step targets main directly") { validate_repo(tmp) }

    File.write(regenerate, regenerate_original.sub(
      /(jobs:\n  regenerate:\n)/, "\\1    if: ${{ true }}\n"))
    expect_rejected("regenerate job carries an if guard that does not exist on push/workflow_dispatch") { validate_repo(tmp) }

    File.write(regenerate, regenerate_original.sub(
      %Q{      - name: Checkout main\n        uses: actions/checkout@v7\n        with:\n          ref: main\n},
      %Q{      - name: Checkout main\n        uses: actions/checkout@v7\n        with:\n          ref: main\n\n      - name: Push straight to main\n        shell: bash\n        run: |\n          git push origin HEAD:main\n}))
    expect_rejected("regenerate workflow pushes directly with git instead of only opening a PR") { validate_repo(tmp) }

    File.write(regenerate, regenerate_original)
    validate_repo(tmp, announce: false)

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
