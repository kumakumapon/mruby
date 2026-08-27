# Build configuration that skips building the host target
# by specifying an external mrbc path.
#
# This demonstrates using conf.mrbcfile to avoid implicit host build generation.
# Usage: MRUBY_CONFIG=skip_host_build rake

MRuby::Build.new do |conf|
  # Standard toolchain setup
  conf.toolchain

  # Key: Specify external mrbc path to skip host build
  # This prevents the implicit MRuby::Build.new('host') from being created
  # by setting mrbcfile_external = true
  conf.mrbcfile = "#{MRUBY_ROOT}/build/host/mrbc/bin/mrbc"

  # Use default gembox
  conf.gembox 'default'

  # Enable testing
  conf.enable_bintest
  conf.enable_test
end
