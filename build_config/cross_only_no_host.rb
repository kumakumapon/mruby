# Strict test: NO MRuby::Build.new call at all (no 'host' target defined).
# Only a MRuby::CrossBuild with an external mrbcfile.
#
# Per lib/mruby/build.rb CrossBuild#initialize:
#   unless mrbcfile_external? || MRuby.targets['host']
#     MRuby::Build.new('host') { ... }   # minimal host, mrbc-only
#   end
#
# Setting conf.mrbcfile here should make mrbcfile_external? true,
# so this implicit minimal 'host' build must NOT be created.
#
# Usage: MRUBY_CONFIG=cross_only_no_host rake

MRuby::CrossBuild.new('cross-test') do |conf|
  conf.toolchain :gcc

  # External, pre-built mrbc (native to this machine), located OUTSIDE build/
  conf.mrbcfile = "/tmp/external_mrbc/mrbc"

  # CrossBuild doesn't auto-detect ports (effective_ports returns [] unless
  # set), so mruby-io needs an explicit HAL port to link successfully.
  conf.ports :posix

  conf.gembox 'default'
end
