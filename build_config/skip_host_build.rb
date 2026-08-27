# Skip building a 'host' target entirely.
#
# mruby's Rakefile builds a 'host' target whenever MRuby::Build.new is
# called (its default name is 'host'). If your config cross-compiles with
# MRuby::CrossBuild and doesn't provide conf.mrbcfile, CrossBuild#initialize
# auto-adds an implicit *minimal* 'host' build (mrbc only, libmruby
# disabled) so it has something to compile mrblib with -- see
# lib/mruby/build.rb:
#
#   unless mrbcfile_external? || MRuby.targets['host']
#     MRuby::Build.new('host') { conf.toolchain; conf.build_mrbc_exec; conf.disable_libmruby }
#   end
#
# To avoid a 'host' target -- full or minimal -- entirely:
#   1. Do NOT call MRuby::Build.new anywhere in the config file.
#   2. Set conf.mrbcfile on the CrossBuild to a pre-built mrbc executable.
#
# Requirements for that mrbc:
#   - It must run natively on the machine doing the build (not the cross
#     target) -- an ARM mrbc will not run on an x86_64 build host.
#   - It must be compatible with this mruby source tree/version.
#   - Point at a copy outside build/, since `rake clean` removes build/.
#
# Usage:
#   EXTERNAL_MRBC=/path/to/mrbc MRUBY_CONFIG=skip_host_build rake
#
# To produce that mrbc once: run a normal `rake` first, then copy
# build/host/mrbc/bin/mrbc somewhere outside build/.

external_mrbc = ENV['EXTERNAL_MRBC']
unless external_mrbc && File.exist?(external_mrbc)
  fail "skip_host_build: set EXTERNAL_MRBC to a pre-built, host-native mrbc " \
       "executable (copy build/host/mrbc/bin/mrbc from a prior full build to " \
       "a location outside build/, since 'rake clean' removes build/)"
end

MRuby::CrossBuild.new('skip-host-example') do |conf|
  conf.toolchain :gcc

  conf.mrbcfile = external_mrbc

  # CrossBuild doesn't auto-detect a HAL port (effective_ports returns []
  # unless set); mruby-io needs one to link. :posix is used here only
  # because this example still targets the local machine -- pick whatever
  # port matches your real cross-compilation target.
  conf.ports :posix

  conf.gembox 'default'
end
