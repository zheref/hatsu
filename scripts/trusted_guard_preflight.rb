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
        step['run'].scan(%r{\.trusted/scripts/([A-Za-z0-9_.-]+\.(?:sh|rb))}) do |match|
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
  adapters = {
    'workflow_runner_policy_check.rb' => ['ruby', File.join(trusted, 'scripts/workflow_runner_policy_check.rb'), '--self-test', root],
    'surface_mirror_check.sh' => ['bash', File.join(trusted, 'scripts/surface_mirror_check.sh'), root],
    'surface_link_check.sh' => ['bash', File.join(trusted, 'scripts/surface_link_check.sh'), root],
    'prose_size_check.sh' => ['bash', File.join(trusted, 'scripts/prose_size_check.sh'), root],
    'plugin_bump_check.sh' => ['bash', File.join(trusted, 'scripts/plugin_bump_check.sh'), changed,
                                File.join(trusted, '.claude-plugin/plugin.json'),
                                File.join(root, '.claude-plugin/plugin.json'), draft_body],
    'canon_contracts_check.sh' => [{ 'NEN' => ENV.fetch('NEN', ENV.fetch('NEN_BIN', 'nen')) },
                                   'bash', File.join(trusted, 'scripts/canon_contracts_check.sh'), '--root', root],
    'branch_authorship_check.sh' => ['sh', File.join(trusted, 'scripts/branch_authorship_check.sh'),
                                      '--repo', root, '--base', base_sha,
                                      '--forbid-trailers-from', File.join(trusted, 'nen/workflow.json'), '--forbidden-only']
  }
  unknown = guards.keys - adapters.keys
  fail_preflight("no local invocation for trusted guard(s): #{unknown.sort.join(', ')}") unless unknown.empty?
  failed = []
  guards.keys.sort.each do |name|
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
end
