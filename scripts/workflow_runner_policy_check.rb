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
  root = mapping(document.root, path)
  triggers = mapping(root.fetch("on") { fail_policy("#{path} has no on mapping") }, "#{path} on")
  fail_policy("#{path} trigger set must be exactly pull_request_target") unless triggers.keys == ["pull_request_target"]
  targets_pr = true
  reject_write_permissions(root["permissions"], "#{path} permissions")
  if targets_pr && scalar(mapping(root["permissions"], "#{path} permissions")["checks"]) != "write"
    fail_policy("#{path} needs only checks: write to publish the exact-head result")
  end

  jobs = mapping(root.fetch("jobs") { fail_policy("#{path} has no jobs mapping") }, "#{path} jobs")
  fail_policy("#{path} has no jobs") if jobs.empty?
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

    reject_write_permissions(job["permissions"], "#{path} job #{job_name} permissions")

    next unless targets_pr
    steps_node = job.fetch("steps") { fail_policy("#{path} job #{job_name} has no steps") }
    fail_policy("#{path} job #{job_name} steps must be a sequence") unless steps_node.is_a?(Psych::Nodes::Sequence)
    steps = steps_node.children
    step_maps = steps.each_with_index.map { |node, index| mapping(node, "#{path} job #{job_name} step #{index + 1}") }
    starter = step_maps.first
    finisher = step_maps.last
    expected_check_name = File.basename(path) == "plugin-bump-check.yml" ? "check" : job_name
    start_env = mapping(starter["env"], "#{path} exact-head check env")
    unless scalar(starter["id"]) == "head_check" && scalar(start_env["HEAD_SHA"]) == "${{ github.event.pull_request.head.sha }}" && scalar(starter["run"])&.include?("-f name=#{expected_check_name}")
      fail_policy("#{path} job #{job_name} must create #{expected_check_name} on the exact event head before other work")
    end
    unless scalar(finisher["if"]) == "${{ always() && steps.head_check.outputs.id != '' }}" && scalar(finisher["run"])&.include?("check-runs/${CHECK_ID}") && scalar(finisher["run"])&.include?("status=completed")
      fail_policy("#{path} job #{job_name} must always publish its final exact-head conclusion")
    end
    head_checkout = false
    base_checkout = false
    step_maps.each_with_index do |step, index|
      next unless scalar(step["uses"])&.start_with?("actions/checkout@")
      with = mapping(step["with"], "#{path} checkout step #{index + 1} with")
      fail_policy("#{path} checkout step #{index + 1} must set persist-credentials: false") unless scalar(with["persist-credentials"]) == "false"
      ref = scalar(with["ref"])
      head_checkout ||= ref == "${{ github.event.pull_request.head.sha }}"
      base_checkout ||= ref == "${{ github.event.pull_request.base.sha }}"
    end
    fail_policy("#{path} job #{job_name} must checkout the exact event head SHA") unless head_checkout
    fail_policy("#{path} job #{job_name} must checkout the trusted event base SHA") unless base_checkout
  end
end

def validate_repo(root)
  paths = Dir.glob(File.join(root, ".github/workflows/*.{yml,yaml}")).sort
  fail_policy("#{root} has no workflows") if paths.empty?
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
      jobs:
        test:
          if: ${{ github.repository == 'zheref/hatsu' && github.event.pull_request.head.repo.full_name == github.repository }}
          runs-on: ubuntu-latest
          steps: []
    YAML
    expect_rejected("new workflow with an unexpected event") { validate_repo(tmp) }

    File.write(extra, "name: first\nname: second\non:\n  pull_request_target:\njobs: {}\n")
    expect_rejected("duplicate YAML key") { validate_repo(tmp) }
  end
  puts "workflow-runner-policy: negative fixtures passed"
end

root = File.expand_path(ARGV.last && ARGV.last != "--self-test" ? ARGV.last : File.join(__dir__, ".."))
self_test(root) if ARGV.include?("--self-test")
validate_repo(root)
