# Cross-compilation configuration that skips host build
# by using an external mrbc.
#
# This configuration demonstrates:
# 1. Using external mrbc to prevent host build creation
# 2. Setting up cross-compilation for a different target
#
# Usage: MRUBY_CONFIG=cross_skip_host rake
#
# Prerequisites:
# - An existing mrbc executable (from a previous full build)
#   Path can be: build/host/mrbc/bin/mrbc (after 'rake all')

# First, set up the external mrbc for the main build
MRuby::Build.new do |conf|
  conf.toolchain :gcc

  # Specify the external mrbc path
  # This prevents the implicit host build from being created
  # The mrbc must already exist - typically from a prior build
  external_mrbc = "#{MRUBY_ROOT}/build/host/mrbc/bin/mrbc"

  if File.exist?(external_mrbc)
    conf.mrbcfile = external_mrbc
    puts "[skip_host_build] Using external mrbc: #{external_mrbc}"
  else
    puts "[skip_host_build] WARNING: External mrbc not found at #{external_mrbc}"
    puts "[skip_host_build] Run 'rake all' first to create mrbc, then use this config"
  end

  conf.gembox 'default'
  conf.enable_test
  conf.enable_bintest
end

# Cross-compile target: 32-bit x86
# This demonstrates how the external mrbc is inherited by cross builds
MRuby::CrossBuild.new('cross-32bit') do |conf|
  conf.toolchain :gcc

  # 32-bit cross-compilation flags
  conf.cc.flags << '-m32'
  conf.linker.flags << '-m32'

  conf.gembox 'default'
  conf.enable_test
end

# Cross-compile target: ARM (example)
# Uncomment and modify for actual ARM builds
# MRuby::CrossBuild.new('arm-linux') do |conf|
#   conf.toolchain :gcc
#
#   conf.cc.flags << '--target=arm-linux-gnueabihf'
#   conf.cc.flags << '-march=armv7-a'
#   conf.linker.flags << '--target=arm-linux-gnueabihf'
#
#   conf.gembox 'default'
#   conf.enable_test
# end
