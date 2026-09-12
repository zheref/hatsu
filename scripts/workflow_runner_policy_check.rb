#!/usr/bin/env ruby
# Structural, offline regression guard for Hatsu's workflow runner policy.
require "psych"
require "tmpdir"
require "fileutils"

SAME_REPO_GUARD = "${{ github.repository == 'zheref/hatsu' && github.event.pull_request.head.repo.full_name == github.repository }}"
MAC_RUNNER = %w[self-hosted macOS ARM64].freeze
WINDOWS_RUNNER = %w[self-hosted Windows X64].freeze
HOSTED_RUNNER = "ubuntu-latest"
PORTABLE_MAC_WORKFLOWS = %w[plugin-bump-check.yml surface-mirror-check.yml].freeze
EXPECTED_JOBS = {
  "plugin-bump-check.yml" => "check",
  "surface-mirror-check.yml" => "surface-mirror-check"
}.freeze
EXPECTED_TYPES = {
  "plugin-bump-check.yml" => %w[opened synchronize reopened edited],
  "surface-mirror-check.yml" => %w[opened synchronize reopened]
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
  ]
}.freeze

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
  fail_policy("#{path} trigger set must be exactly pull_request_target") unless triggers.keys == ["pull_request_target"]
  trigger = mapping(triggers["pull_request_target"], "#{path} pull_request_target")
  trigger_types = sequence(trigger.fetch("types") { fail_policy("#{path} pull_request_target has no types") }, "#{path} pull_request_target types")
  expected_types = EXPECTED_TYPES.fetch(File.basename(path)) { fail_policy("#{path} has no declared trigger policy") }
  fail_policy("#{path} pull_request_target types changed") unless trigger.keys == ["types"] && trigger_types == expected_types
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
    if PORTABLE_MAC_WORKFLOWS.include?(File.basename(path)) && runner != MAC_RUNNER
      fail_policy("#{path} is portable and must use the repository-scoped Mac ARM64 pool")
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
    if File.basename(path) == "surface-mirror-check.yml"
      pin_step = step_maps[5]
      unless scalar(pin_step["run"])&.include?(".trusted/nen/contract.json")
        fail_policy("#{path} must source its executable dependency pin from trusted workflow data")
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
  missing = PORTABLE_MAC_WORKFLOWS - basenames
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
  end
  puts "workflow-runner-policy: negative fixtures passed"
end

root = File.expand_path(ARGV.last && ARGV.last != "--self-test" ? ARGV.last : File.join(__dir__, ".."))
self_test(root) if ARGV.include?("--self-test")
validate_repo(root)
