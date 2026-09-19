#!/usr/bin/env ruby
# Structural, offline regression guard for Hatsu's workflow runner policy.
require "psych"
require "tmpdir"
require "fileutils"

SAME_REPO_GUARD = "${{ github.repository == 'zheref/hatsu' && github.event.pull_request.head.repo.full_name == github.repository }}"
MAC_RUNNER = %w[self-hosted macOS ARM64].freeze
WINDOWS_RUNNER = %w[self-hosted Windows X64].freeze
HOSTED_RUNNER = "ubuntu-latest"
# This constant does DOUBLE DUTY: it is the portable-workflow set (each member
# must run on GitHub-hosted ubuntu-latest) AND the required-PRESENCE list that
# validate_repo checks. pr-readiness.yml joins it HERE, in the same commit that
# adds the file -- which is the second half of the ordering the registration
# commit reserved, and the reason it was withheld until now: naming a file that
# does not exist yet fails every pull request from the other direction.
#
# The consequence is worth stating where it can be read: the CHECK this workflow
# publishes is advisory and is in no ruleset, but the FILE's presence and shape
# are now enforced by a guard that a required check runs. Deleting or reshaping
# it fails a required check even though the check it publishes never can.
PORTABLE_HOSTED_WORKFLOWS = %w[plugin-bump-check.yml surface-mirror-check.yml pr-readiness.yml].freeze
EXPECTED_JOBS = {
  "plugin-bump-check.yml" => "check",
  "surface-mirror-check.yml" => "surface-mirror-check",
  "pr-readiness.yml" => "readiness"
}.freeze
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
EXPECTED_TYPES = {
  "plugin-bump-check.yml" => {
    "pull_request_target" => %w[opened synchronize reopened edited]
  },
  "surface-mirror-check.yml" => {
    "pull_request_target" => %w[opened synchronize reopened]
  },
  "pr-readiness.yml" => {
    # No `edited`: the verdict reads checks, rounds and threads, and none of
    # those changes when the body or title is edited.
    "pull_request_target" => %w[opened synchronize reopened],
    # CON-32(b) / CON-16 -- a reviewer round landing, changing or being dismissed.
    "pull_request_review" => %w[submitted edited dismissed],
    # CON-32(d) -- the unresolved-threads conjunct. Thread resolution has its own
    # event; it is not a review_comment.
    "pull_request_review_thread" => %w[resolved unresolved]
  }
}.freeze

# The only events a privileged job in this repository may be triggered by. All
# run in the BASE repository context with a credential, so this list is the
# trust boundary and widening it again is a maintainer ruling, not an edit.
ALLOWED_TRIGGERS = %w[pull_request_target pull_request_review pull_request_review_thread].freeze
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
    "Start check on the exact PR head",
    "Checkout PR head (data only — nothing from here is executed)",
    "Checkout guard code from the trusted workflow revision",
    "Enforce workflow runner policy from trusted workflow revision",
    "Read the pinned nen ref from trusted nen/contract.json",
    "Bootstrap nen at the trusted pinned ref (checksum-verified, two steps, never a pipe)",
    "Readiness verdict",
    "Finish check on the exact PR head"
  ]
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
REQUIRED_STEP_ARGS = {
  "pr-readiness.yml" => {
    "Readiness verdict" => '--gates "$PWD/.trusted/nen/gates.json"'
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
def diagnostic_at?(line, index)
  start = 0
  line.scan(/\|\||&&|[;|]/) do
    match = Regexp.last_match
    break if match.begin(0) > index
    start = match.end(0)
  end
  # Leading `{`, `(` and whitespace are grouping, not the command word.
  segment = line[start...index].to_s.sub(/\A[\s({]+/, "")
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
  expected_triggers = EXPECTED_TYPES.fetch(File.basename(path)) { fail_policy("#{path} has no declared trigger policy") }
  triggers.keys.each do |event|
    fail_policy("#{path} uses trigger #{event.inspect}, which is not an admitted privileged trigger") unless ALLOWED_TRIGGERS.include?(event)
  end
  fail_policy("#{path} trigger set changed") unless triggers.keys.sort == expected_triggers.keys.sort
  expected_triggers.each do |event, expected_types|
    trigger = mapping(triggers[event], "#{path} #{event}")
    trigger_types = sequence(trigger.fetch("types") { fail_policy("#{path} #{event} has no types") }, "#{path} #{event} types")
    fail_policy("#{path} #{event} types changed") unless trigger.keys == ["types"] && trigger_types == expected_types
  end
  targets_pr = true
  reject_write_permissions(root["permissions"], "#{path} permissions")
  if targets_pr && scalar(mapping(root["permissions"], "#{path} permissions")["checks"]) != "write"
    fail_policy("#{path} needs only checks: write to publish the exact-head result")
  end

  jobs = mapping(root.fetch("jobs") { fail_policy("#{path} has no jobs mapping") }, "#{path} jobs")
  expected_job = EXPECTED_JOBS.fetch(File.basename(path)) { fail_policy("#{path} has no declared job policy") }
  fail_policy("#{path} job id must be exactly #{expected_job}") unless jobs.keys == [expected_job]
  jobs.each do |job_name, job_node|
    job = mapping(job_node, "#{path} job #{job_name}")
    if targets_pr && scalar(job["if"]) != SAME_REPO_GUARD
      fail_policy("#{path} job #{job_name} needs the exact same-repository job guard")
    end

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
    start_env = mapping(starter["env"], "#{path} exact-head check env")
    exact_name = /(?:^|\s)-f name=#{Regexp.escape(expected_check_name)}(?:\s|$)/
    unless scalar(starter["id"]) == "head_check" && scalar(start_env["HEAD_SHA"]) == "${{ github.event.pull_request.head.sha }}" && scalar(starter["run"])&.match?(exact_name)
      fail_policy("#{path} job #{job_name} must create #{expected_check_name} on the exact event head before other work")
    end
    policy_step = step_maps[3]
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
            next if token.end_with?(".trusted/")
            fail_policy("#{path} step #{scalar(step["name"]).inspect} reads #{token}#{data} " \
                        "outside the trusted checkout; a pull_request_target job's cwd is the PR head")
          end
        end
      end
    end
    REQUIRED_STEP_ARGS.fetch(File.basename(path), {}).each do |step_name, required|
      step = step_maps.find { |candidate| scalar(candidate["name"]) == step_name }
      fail_policy("#{path} has no step named #{step_name.inspect}") unless step
      unless code_of(scalar(step["run"])).include?(required)
        fail_policy("#{path} step #{step_name.inspect} must pass #{required} on an executable line")
      end
    end
    unless scalar(finisher["if"]) == "${{ always() && steps.head_check.outputs.id != '' }}" && scalar(finisher["run"])&.include?("check-runs/${CHECK_ID}") && scalar(finisher["run"])&.include?("status=completed")
      fail_policy("#{path} job #{job_name} must always publish its final exact-head conclusion")
    end
    head_checkout = false
    trusted_checkout = false
    step_maps.each_with_index do |step, index|
      next unless scalar(step["uses"])&.start_with?("actions/checkout@")
      with = mapping(step["with"], "#{path} checkout step #{index + 1} with")
      fail_policy("#{path} checkout step #{index + 1} must set persist-credentials: false") unless scalar(with["persist-credentials"]) == "false"
      ref = scalar(with["ref"])
      head_checkout ||= ref == "${{ github.event.pull_request.head.sha }}"
      trusted_checkout ||= ref == "${{ github.sha }}"
    end
    fail_policy("#{path} job #{job_name} must checkout the exact event head SHA") unless head_checkout
    fail_policy("#{path} job #{job_name} must checkout the trusted workflow SHA") unless trusted_checkout
  end
end

def validate_repo(root)
  paths = Dir.glob(File.join(root, ".github/workflows/*.{yml,yaml}")).sort
  fail_policy("#{root} has no workflows") if paths.empty?
  basenames = paths.map { |path| File.basename(path) }
  missing = PORTABLE_HOSTED_WORKFLOWS - basenames
  fail_policy("#{root} is missing required workflows: #{missing.join(', ')}") unless missing.empty?
  paths.each { |path| validate_workflow(path) }
  puts "workflow-runner-policy: #{paths.length} workflows structurally valid"
end

def self_test(root)
  fail_policy("same-repository predicate rejected owner head") unless same_repository?("zheref/hatsu", "zheref/hatsu")
  fail_policy("same-repository predicate admitted fork") if same_repository?("zheref/hatsu", "fork/hatsu")
  fail_policy("same-repository predicate admitted missing head repository") if same_repository?("zheref/hatsu", nil)
  fail_policy("same-repository predicate admitted another repository") if same_repository?("other/repo", "other/repo")

  Dir.mktmpdir("hatsu-workflow-policy") do |tmp|
    FileUtils.mkdir_p(File.join(tmp, ".github/workflows"))
    Dir.glob(File.join(root, ".github/workflows/*.{yml,yaml}")).each { |path| FileUtils.cp(path, File.join(tmp, ".github/workflows")) }
    validate_repo(tmp)

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

    # And the control: a DIAGNOSTIC naming the file is not a read. This workflow
    # already carries `echo "::error::nen/contract.json carries no ..."`, mid-line
    # inside a `|| { ... }` guard, and it must keep validating.
    File.write(surface, surface_original)
    validate_repo(tmp)
  end
  puts "workflow-runner-policy: negative fixtures passed"
end

root = File.expand_path(ARGV.last && ARGV.last != "--self-test" ? ARGV.last : File.join(__dir__, ".."))
self_test(root) if ARGV.include?("--self-test")
validate_repo(root)
