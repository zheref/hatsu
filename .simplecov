# Bashcov's SimpleCov settings for scripts/shell_coverage.mts (zheref/hatsu#148): one LCOV file per
# focused lane, written under that lane's own coverage directory so two lanes never share a resultset.
gem 'simplecov-lcov', ENV.fetch('HATSU_SIMPLECOV_LCOV_VERSION', '>= 0')
require 'simplecov-lcov'
SimpleCov.coverage_dir(ENV.fetch('HATSU_COVERAGE_DIR', 'coverage'))
SimpleCov::Formatter::LcovFormatter.config.report_with_single_file = true
SimpleCov::Formatter::LcovFormatter.config.single_report_path = ENV.fetch('HATSU_COVERAGE_PATH', 'coverage/lcov.info')
SimpleCov.formatter = SimpleCov::Formatter::LcovFormatter
