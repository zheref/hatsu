#!/usr/bin/env ruby
# Run the base revision's pull_request_target guards before opening a PR.
require 'psych'
require 'open3'
require 'tmpdir'
require 'fileutils'
require 'pathname'
require 'digest'
require 'json'
require 'shellwords'

# Every guard's output is UTF-8 (the lint's summary carries a middle dot). Under LANG unset or C --
# macOS's default outside an interactive shell -- Ruby 2.6 tags Open3's strings US-ASCII and a
# regexp match over them raises ArgumentError (invalid byte sequence), as workflow_runner_policy_check.rb
# records for its own reads. Set both defaults here, once, before any guard runs.
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

def fail_preflight(message, code = 2)
  warn "trusted-guard-preflight: #{message}"
  exit code
end

def command!(*argv)
  out, err, status = Open3.capture3(*argv)
  fail_preflight("#{argv.first} failed: #{err.strip}", 2) unless status.success?
  out
end

NOT_BEFORE_PR = {
  'readiness_ci_verdict.mts' => "formats the open PR's live nen pr ready verdict; there is no PR before creation"
}.freeze

NEN_CANON_LINT = 'nen-canon-lint'.freeze
NEN_CANON_PREFIX = ['$NEN_BIN', 'canon', 'lint'].freeze
NEN_CANON_ARGS = ['--root', '$PWD', '--rules', '$PWD/$rules',
                  '--baseline', 'contracts/prose.lint.baseline.json',
                  '--base-baseline', '$PWD/$base', '--skill-paths'].freeze

VERDICT_LINES = {
  NEN_CANON_LINT => /^canon lint: /,
  'prose_ambiguity_check.mts' => /^canon-lint: /,
  'plugin_bump_api_retry.mts' => /^changed files: 1$/
}.freeze

def derive_guards(root)
  workflows = Dir[File.join(root, '.github', 'workflows', '*.{yml,yaml}')].sort
  fail_preflight('no workflows to inspect') if workflows.empty?
  guards = {}
  workflows.each do |workflow|
    data = Psych.safe_load(File.read(workflow, encoding: 'UTF-8'), aliases: false)
    next unless data.is_a?(Hash) && (data['on'] || data[true]).is_a?(Hash)
    next unless (data['on'] || data[true]).key?('pull_request_target')
    (data['jobs'] || {}).each_value do |job|
      next unless job.is_a?(Hash)
      (job['steps'] || []).each do |step|
        next unless step.is_a?(Hash) && step['run'].is_a?(String)
        run = step['run']
        if File.basename(workflow) == 'prose-ambiguity-check.yml' && step['name'] == 'Canon prose lint' &&
           run.include?('"$NEN_BIN" canon lint')
          guards[NEN_CANON_LINT] = [File.basename(workflow)]
        end
        run.scan(%r{\.trusted/scripts/([A-Za-z0-9_.-]+\.(?:sh|rb|mts|ts))}) do |match|
          guards[match.first] ||= []
          guards[match.first] << File.basename(workflow)
        end
      end
    end
  end
  fail_preflight('no trusted guards derived from pull_request_target workflows') if guards.empty?
  guards
end

def nen_canon_adapter(trusted, root, wiring_only: false)
  workflow = File.join(trusted, '.github/workflows/prose-ambiguity-check.yml')
  data = Psych.safe_load(File.read(workflow, encoding: 'UTF-8'), aliases: false)
  step = data.dig('jobs', 'canon-lint', 'steps')&.find { |row| row['name'] == 'Canon prose lint' }
  line = step&.fetch('run', '')&.lines&.find { |text| text.start_with?('"$NEN_BIN" canon lint ') }
  argv = Shellwords.split(line.to_s.split(' 2>&1 || code=', 2).first.to_s)
  skill_paths = argv.last
  unless argv[0...-1] == NEN_CANON_PREFIX + NEN_CANON_ARGS && skill_paths && !skill_paths.empty?
    return [nil, 'trusted canon prose lint has an unsupported invocation']
  end

  rules, baseline = %w[prose.lint.json prose.lint.baseline.json].map do |name|
    path = File.join(trusted, 'contracts', name)
    return [nil, "trusted revision has no contracts/#{name} for the canon lint"] unless File.file?(path)
    path
  end
  host = case RUBY_PLATFORM
         when /arm64-darwin/, /aarch64-darwin/ then 'darwin-arm64'
         when /x86_64-linux/ then 'linux-x64'
         when /x64-mingw/, /x64-mswin/ then 'windows-x64'
         end
  contract = JSON.parse(File.read(File.join(trusted, 'nen/contract.json'), encoding: 'UTF-8'))
  digest = contract.dig('dependency', 'bootstrap', 'sha256', host)
  return [nil, "trusted revision has no valid Nen digest for #{host || RUBY_PLATFORM}"] unless digest.to_s.match?(/\A[0-9a-f]{64}\z/)

  # CI runs this check on the candidate while its ordinary Nen comes from the PR base.
  return [nil, nil] if wiring_only

  base_binary = ENV['HATSU_TRUSTED_BASE_NEN']
  if base_binary && !Pathname.new(base_binary).absolute?
    return [nil, 'HATSU_TRUSTED_BASE_NEN must name an absolute executable path']
  end
  command = base_binary || ENV.fetch('NEN', ENV.fetch('NEN_BIN', 'nen'))
  paths = command.include?(File::SEPARATOR) ? [command] : ENV.fetch('PATH', '').split(File::PATH_SEPARATOR).map { |dir| File.join(dir, command) }
  binary = paths.find { |path| File.file?(path) && File.executable?(path) }
  return [nil, "no executable Nen at #{command}; set HATSU_TRUSTED_BASE_NEN to the exact PR-base binary"] unless binary
  binary = File.realpath(binary)
  unless Digest::SHA256.file(binary).hexdigest == digest
    return [nil, "selected Nen does not match the trusted #{host} digest; set HATSU_TRUSTED_BASE_NEN to the exact PR-base binary"]
  end

  [[binary, 'canon', 'lint', '--root', root, '--rules', rules, '--baseline', 'contracts/prose.lint.baseline.json',
    '--base-baseline', baseline, '--skill-paths', skill_paths], nil]
rescue SystemCallError, JSON::ParserError, Psych::Exception, ArgumentError => error
  [nil, "trusted Nen canon lint wiring: #{error.message}"]
end

def local_adapters(trusted, root, temporary, base_sha: nil, changed: nil, draft_body: nil, lint_contracts: nil)
  {
    'workflow_runner_policy_check.rb' => ['ruby', File.join(trusted, 'scripts/workflow_runner_policy_check.rb'), '--self-test', root],
    'surface_mirror_check.sh' => ['bash', File.join(trusted, 'scripts/surface_mirror_check.sh'), root],
    'surface_link_check.sh' => ['bash', File.join(trusted, 'scripts/surface_link_check.sh'), root],
    'prose_size_check.sh' => ['bash', File.join(trusted, 'scripts/prose_size_check.sh'), root],
    'private_name_check_fixture.sh' => ['bash', File.join(trusted, 'scripts/private_name_check_fixture.sh')],
    'plugin_bump_api_retry.mts' => [
      { 'GH_TOKEN' => 'fixture-token', 'GITHUB_TOKEN' => '', 'NODE_OPTIONS' => nil },
      'node', '--import', File.join(temporary, 'plugin-bump-fetch.mjs'),
      File.join(trusted, 'scripts/plugin_bump_api_retry.mts'), '--repo', 'fixture/hatsu',
      '--pr', '1', '--base-sha', base_sha, '--changed-files', File.join(temporary, 'api-changed-files.txt'),
      '--base-manifest', File.join(temporary, 'api-base-manifest.json')
    ],
    'plugin_bump_check.sh' => ['bash', File.join(trusted, 'scripts/plugin_bump_check.sh'), changed,
                                File.join(trusted, '.claude-plugin/plugin.json'),
                                File.join(root, '.claude-plugin/plugin.json'), draft_body],
    'canon_contracts_check.sh' => [{ 'NEN' => ENV.fetch('NEN', ENV.fetch('NEN_BIN', 'nen')) },
                                   'bash', File.join(trusted, 'scripts/canon_contracts_check.sh'), '--root', root],
    # A PR targeting a pre-migration branch still runs that revision's Node guard.
    'prose_ambiguity_check.mts' => ['node', File.join(trusted, 'scripts/prose_ambiguity_check.mts'), '--root', root,
                                     '--rules', File.join(lint_contracts.to_s, 'prose.lint.json'),
                                     '--base-baseline', File.join(lint_contracts.to_s, 'prose.lint.baseline.json')],
    'direct_matrix_ci_check.mts' => ['node', File.join(trusted, 'scripts/direct_matrix_ci_check.mts'), root],
    'branch_authorship_check.sh' => ['sh', File.join(trusted, 'scripts/branch_authorship_check.sh'),
                                      '--repo', root, '--base', base_sha,
                                      '--forbid-trailers-from', File.join(trusted, 'nen/workflow.json'), '--forbidden-only']
  }
end

def missing_script(root, name)
  return if name == NEN_CANON_LINT
  "trusted workflow names absent scripts/#{name}" unless File.file?(File.join(root, 'scripts', name))
end

def adapter_gap(name, adapters)
  'no local invocation' unless adapters.key?(name) || NOT_BEFORE_PR.key?(name)
end

# Exercise the archived API reader's actual CLI with fixed responses and throwaway outputs.
# No PR or credentials are needed. The shell guard still receives Git-derived inputs.
def write_plugin_bump_fixture(temporary, base_sha)
  File.write(File.join(temporary, 'plugin-bump-fetch.mjs'), <<~JS)
    const api = 'https://api.github.com/repos/fixture/hatsu';
    const base = '#{base_sha}';
    const replies = new Map([
      [`${api}/commits/${base}`, { sha: base }],
      [`${api}/pulls/1/files?per_page=100&page=1`, [{ filename: 'README.md' }]],
      [`${api}/contents/.claude-plugin/plugin.json?ref=${base}`, { version: '0.1.0' }],
    ]);
    globalThis.fetch = async (input) => {
      if (!replies.has(input)) throw new Error('unexpected plugin-bump fixture request');
      return Response.json(replies.get(input));
    };
  JS
end

root = Dir.pwd
base = 'origin/main'
body = nil
list_only = false
check_adapters = false
until ARGV.empty?
  flag = ARGV.shift
  case flag
  when '--root', '--base-ref', '--body'
    fail_preflight("#{flag} needs a value") if ARGV.empty?
    value = ARGV.shift
    case flag
    when '--root' then root = value
    when '--base-ref' then base = value
    when '--body' then body = value
    end
  when '--list' then list_only = true
  when '--check-adapters' then check_adapters = true
  else fail_preflight("unknown argument #{flag}")
  end
end
root = File.realpath(root)
fail_preflight('root must be a Git checkout') unless command!('git', '-C', root, 'rev-parse', '--show-toplevel').strip == root
if check_adapters
  fail_preflight('--check-adapters cannot be combined with --list') if list_only
  adapters = local_adapters(root, root, root)
  problems = derive_guards(root).keys.sort.map do |name|
    reason = if name == NEN_CANON_LINT
               nen_canon_adapter(root, root, wiring_only: true).last
             else
               missing_script(root, name) || adapter_gap(name, adapters)
             end
    "#{name}: #{reason}" if reason
  end.compact
  problems.each { |problem| warn "trusted-guard-preflight: #{problem}" }
  exit 2 unless problems.empty?
  puts 'trusted-guard-preflight: all candidate workflow guards have a local invocation or a PR-only reason'
  exit 0
end
fail_preflight('base ref must name an origin branch (the intended PR base)') unless base.match?(%r{\Aorigin/[A-Za-z0-9][A-Za-z0-9._/-]*\z})
branch = base.delete_prefix('origin/')
fail_preflight('base ref is not a valid branch') unless system('git', 'check-ref-format', '--branch', branch, out: File::NULL, err: File::NULL)
base_sha = command!('git', '-C', root, 'rev-parse', '--verify', "#{base}^{commit}").strip

Dir.mktmpdir('hatsu-trusted-guards-') do |temporary|
  # The real path, never the symlinked one mktmpdir hands back (/var -> /private/var on macOS): a
  # TypeScript guard whose entry guard compares its argv path with its resolved module URL runs
  # NOTHING and exits 0 when the two spellings differ -- a false pass, found by the fixture's
  # red-lint case. Every trusted script below is invoked by this path.
  temporary = File.realpath(temporary)
  archive = File.join(temporary, 'trusted.tar')
  File.binwrite(archive, command!('git', '-C', root, 'archive', '--format=tar', base_sha))
  trusted = File.join(temporary, 'trusted')
  Dir.mkdir(trusted)
  command!('tar', '-xf', archive, '-C', trusted)
  guards = derive_guards(trusted)
  puts "trusted-guard-preflight: base #{base_sha}; guards derived from pull_request_target workflows"
  if list_only
    guards.sort.each { |name, sources| puts "  #{name} (#{sources.uniq.sort.join(', ')})" }
    exit 0
  end

  changed = File.join(temporary, 'changed-files.txt')
  # --no-renames preserves BOTH ends of a move. The trusted plugin-bump job
  # reads previous_filename for precisely this case; staged edits count too.
  paths = command!('git', '-C', root, 'diff', '--name-only', '--no-renames', "#{base_sha}...HEAD", '--').lines
  paths += command!('git', '-C', root, 'diff', '--name-only', '--no-renames', '--cached', '--').lines
  paths += command!('git', '-C', root, 'diff', '--name-only', '--no-renames', '--').lines
  paths += command!('git', '-C', root, 'ls-files', '--others', '--exclude-standard').lines
  File.write(changed, paths.map(&:strip).reject(&:empty?).uniq.sort.join("\n") + "\n")
  draft_body = body || File.join(temporary, 'body.md')
  File.write(draft_body, '') unless body
  fail_preflight("body #{draft_body} is unreadable") unless File.file?(draft_body) && File.readable?(draft_body)
  # The canon lint refuses a --rules or --base-baseline path outside --root (its hardening against a
  # link that leaves the tree, exit 2), and `trusted` sits outside it. So where the lint is derived,
  # the trusted contracts are copied under <root>/.nen/ -- git-ignored, and outside the lint's own
  # walk -- for this run only, and removed with it (the ensure below).
  lint_contracts = nil
  unavailable = {}
  begin
    if guards.key?('prose_ambiguity_check.mts')
      FileUtils.mkdir_p(File.join(root, '.nen'))
      lint_contracts = Dir.mktmpdir('trusted-guard-preflight-', File.join(root, '.nen'))
      %w[prose.lint.json prose.lint.baseline.json].each do |name|
        source = File.join(trusted, 'contracts', name)
        unless File.file?(source)
          unavailable['prose_ambiguity_check.mts'] = "trusted revision has no contracts/#{name} for the canon lint"
          break
        end
        FileUtils.cp(source, File.join(lint_contracts, name))
      end
    end
    write_plugin_bump_fixture(temporary, base_sha) if guards.key?('plugin_bump_api_retry.mts')
    adapters = local_adapters(trusted, root, temporary, base_sha: base_sha, changed: changed,
                              draft_body: draft_body, lint_contracts: lint_contracts)
    if guards.key?(NEN_CANON_LINT)
      adapter, unavailable[NEN_CANON_LINT] = nen_canon_adapter(trusted, root)
      adapters[NEN_CANON_LINT] = adapter
    end
    failed = []
    incomplete = false
    guards.keys.sort.each do |name|
      problem = missing_script(trusted, name) || adapter_gap(name, adapters) || unavailable[name]
      reason = problem || NOT_BEFORE_PR[name]
      if reason
        puts "  #{name}: not run (#{reason})"
        incomplete = true if problem
        next
      end

      begin
        output, errors, status = Open3.capture3(*adapters.fetch(name))
      rescue Errno::ENOENT, Errno::EACCES => error
        puts "  #{name}: not run (#{error.message})"
        incomplete = true
        next
      end

      # An entry point that misses its argv path can exit 0 without running anything.
      verdict = VERDICT_LINES[name]
      if status.success? && verdict && !output.match?(verdict)
        puts "  #{name}: not run (exited 0 without its verdict line #{verdict.source})"
        failed << name
        next
      end

      puts "  #{name}: exit #{status.exitstatus || "signal #{status.termsig}"}"
      if status.success?
        puts "    #{output.lines.map(&:strip).reject(&:empty?).last}" unless output.empty?
      else
        puts output unless output.empty?
        warn errors unless errors.empty?
        failed << name
      end
    end
    unless failed.empty?
      # A finding-type guard's red is the author's own prose, not a guard-shape change: its remedy is
      # named instead of the two-step landing (Phinks, hanten round 2 on HA-PR-#420).
      finding_remedies = {
        NEN_CANON_LINT => 'fix the prose or remove the stale baseline row (docs/config/prose.lint.json.md); the baseline never grows (HR-13)',
        'prose_ambiguity_check.mts' => 'fix the prose or remove the stale baseline row (docs/config/prose.lint.json.md); the baseline never grows (HR-13)'
      }
      shape = failed - finding_remedies.keys
      remedies = (failed & finding_remedies.keys).map { |name| "#{name}: #{finding_remedies.fetch(name)}" }
      warn "trusted-guard-preflight: red #{failed.join(', ')}"
      remedies.each { |line| warn "trusted-guard-preflight: #{line}" }
      unless shape.empty?
        warn "trusted-guard-preflight: #{shape.join(', ')}: use the two-step landing in docs/GATE-CONFIGURATION.md § 6 (2026-09-20 and 2026-09-30 rulings): land a guard that accepts both shapes first, then change its input in a follow-up PR."
      end
    end
    if incomplete
      warn 'trusted-guard-preflight: incomplete local wiring; see the not-run results above'
      exit 2
    end
    exit 1 unless failed.empty?
    puts 'trusted-guard-preflight: every runnable trusted guard passed'
  ensure
    FileUtils.rm_rf(lint_contracts) if lint_contracts
  end
end
