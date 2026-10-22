#!/usr/bin/env ruby
# Run the base revision's pull_request_target guards before opening a PR.
require 'psych'
require 'open3'
require 'tmpdir'
require 'fileutils'
require 'pathname'

def fail_preflight(message, code = 2)
  warn "trusted-guard-preflight: #{message}"
  exit code
end

def command!(*argv)
  out, err, status = Open3.capture3(*argv)
  fail_preflight("#{argv.first} failed: #{err.strip}", 2) unless status.success?
  out
end

root = Dir.pwd
base = 'origin/main'
body = nil
list_only = false
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
  else fail_preflight("unknown argument #{flag}")
  end
end
root = File.realpath(root)
fail_preflight('root must be a Git checkout') unless command!('git', '-C', root, 'rev-parse', '--show-toplevel').strip == root
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
  workflows = Dir[File.join(trusted, '.github', 'workflows', '*.{yml,yaml}')].sort
  fail_preflight("#{base_sha} has no workflows to inspect") if workflows.empty?
  guards = {}
  workflows.each do |workflow|
    data = Psych.safe_load(File.read(workflow, encoding: 'UTF-8'), aliases: false)
    next unless data.is_a?(Hash) && (data['on'] || data[true]).is_a?(Hash)
    next unless (data['on'] || data[true]).key?('pull_request_target')
    (data['jobs'] || {}).each_value do |job|
      next unless job.is_a?(Hash)
      (job['steps'] || []).each do |step|
        next unless step.is_a?(Hash) && step['run'].is_a?(String)
        step['run'].scan(%r{\.trusted/scripts/([A-Za-z0-9_.-]+\.(?:sh|rb|mts|ts))}) do |match|
          guards[match.first] ||= []
          guards[match.first] << File.basename(workflow)
        end
      end
    end
  end
  fail_preflight('no trusted scripts derived from pull_request_target workflows') if guards.empty?
  guards.each_key do |name|
    fail_preflight("trusted workflow names absent scripts/#{name}") unless File.file?(File.join(trusted, 'scripts', name))
  end
  puts "trusted-guard-preflight: base #{base_sha}; guards derived from pull_request_target workflows:"
  guards.sort.each { |name, sources| puts "  #{name} (#{sources.uniq.sort.join(', ')})" }
  exit 0 if list_only

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
  begin
    if guards.key?('prose_ambiguity_check.mts')
      FileUtils.mkdir_p(File.join(root, '.nen'))
      lint_contracts = Dir.mktmpdir('trusted-guard-preflight-', File.join(root, '.nen'))
      %w[prose.lint.json prose.lint.baseline.json].each do |name|
        source = File.join(trusted, 'contracts', name)
        fail_preflight("trusted revision has no contracts/#{name} for the canon lint") unless File.file?(source)
        FileUtils.cp(source, File.join(lint_contracts, name))
      end
    end
    adapters = {
      'workflow_runner_policy_check.rb' => ['ruby', File.join(trusted, 'scripts/workflow_runner_policy_check.rb'), '--self-test', root],
      'surface_mirror_check.sh' => ['bash', File.join(trusted, 'scripts/surface_mirror_check.sh'), root],
      'surface_link_check.sh' => ['bash', File.join(trusted, 'scripts/surface_link_check.sh'), root],
      'prose_size_check.sh' => ['bash', File.join(trusted, 'scripts/prose_size_check.sh'), root],
      'private_name_check_fixture.sh' => ['bash', File.join(trusted, 'scripts/private_name_check_fixture.sh')],
      'plugin_bump_check.sh' => ['bash', File.join(trusted, 'scripts/plugin_bump_check.sh'), changed,
                                  File.join(trusted, '.claude-plugin/plugin.json'),
                                  File.join(root, '.claude-plugin/plugin.json'), draft_body],
      'canon_contracts_check.sh' => [{ 'NEN' => ENV.fetch('NEN', ENV.fetch('NEN_BIN', 'nen')) },
                                     'bash', File.join(trusted, 'scripts/canon_contracts_check.sh'), '--root', root],
      # The canon prose lint (HR-13): the trusted guard and rules over this tree, growth held
      # against the trusted baseline, as prose-ambiguity-check.yml's frozen step runs it.
      'prose_ambiguity_check.mts' => ['node', File.join(trusted, 'scripts/prose_ambiguity_check.mts'), '--root', root,
                                       '--rules', File.join(lint_contracts.to_s, 'prose.lint.json'),
                                       '--base-baseline', File.join(lint_contracts.to_s, 'prose.lint.baseline.json')],
      'direct_matrix_ci_check.mts' => ['node', File.join(trusted, 'scripts/direct_matrix_ci_check.mts'), root],
      'branch_authorship_check.sh' => ['sh', File.join(trusted, 'scripts/branch_authorship_check.sh'),
                                        '--repo', root, '--base', base_sha,
                                        '--forbid-trailers-from', File.join(trusted, 'nen/workflow.json'), '--forbidden-only']
    }
    # Derived, and named as not run: each reads what only exists once the PR is open.
    not_before_pr = {
      'readiness_ci_verdict.mts' => "formats the open PR's live nen pr ready verdict; there is no PR before creation"
    }
    unknown = guards.keys - adapters.keys - not_before_pr.keys
    fail_preflight("no local invocation for trusted guard(s): #{unknown.sort.join(', ')}") unless unknown.empty?
    failed = []
    (guards.keys & not_before_pr.keys).sort.each { |name| puts "  #{name}: not run (#{not_before_pr.fetch(name)})" }
    (guards.keys - not_before_pr.keys).sort.each do |name|
      output, errors, status = Open3.capture3(*adapters.fetch(name))
      puts "  #{name}: exit #{status.exitstatus}"
      if status.success?
        puts "    #{output.lines.map(&:strip).reject(&:empty?).last}" unless output.empty?
      else
        puts output unless output.empty?
        warn errors unless errors.empty?
        failed << name
      end
    end
    unless failed.empty?
      warn "trusted-guard-preflight: red #{failed.join(', ')}; use the two-step landing in docs/GATE-CONFIGURATION.md § 6 (2026-09-20 and 2026-09-30 rulings): land a guard that accepts both shapes first, then change its input in a follow-up PR."
      exit 1
    end
    puts 'trusted-guard-preflight: every derived trusted guard passed'
  ensure
    FileUtils.rm_rf(lint_contracts) if lint_contracts
  end
end
