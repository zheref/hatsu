# Bashcov's SimpleCov settings for scripts/shell_coverage.mts (zheref/hatsu#148): one LCOV file per
# focused lane, written under that lane's own coverage directory so two lanes never share a resultset.
# The pin comes from scripts/shell_coverage.mts (project.toolchain); run outside it, this refuses.
gem 'simplecov-lcov', ENV.fetch('HATSU_SIMPLECOV_LCOV_VERSION')
require 'simplecov-lcov'
SimpleCov.coverage_dir(ENV.fetch('HATSU_COVERAGE_DIR', 'coverage'))
SimpleCov::Formatter::LcovFormatter.config.report_with_single_file = true
SimpleCov::Formatter::LcovFormatter.config.single_report_path = ENV.fetch('HATSU_COVERAGE_PATH', 'coverage/lcov.info')
SimpleCov.formatter = SimpleCov::Formatter::LcovFormatter
