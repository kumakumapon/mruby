# Cross Compiling configuration for generic arm64 (aarch64) Linux,
# e.g. Raspberry Pi OS 64-bit, Debian/Ubuntu arm64, using glibc.
#
# On Debian/Ubuntu, install the cross toolchain with:
#   sudo apt install gcc-aarch64-linux-gnu g++-aarch64-linux-gnu
#
# Usage: rake MRUBY_CONFIG=aarch64-linux
#
# Note: this builds a *host* mrbc too (implicitly, since no conf.mrbcfile
# is set), because CrossBuild needs a native mrbc to compile mrblib. The
# resulting build/aarch64-linux/bin/* binaries are the aarch64 ones; only
# build/host/* is native to the build machine.

MRuby::CrossBuild.new('aarch64-linux') do |conf|
  conf.toolchain :gcc

  conf.cc.command = 'aarch64-linux-gnu-gcc'
  conf.cxx.command = 'aarch64-linux-gnu-g++'
  conf.linker.command = conf.cc.command
  conf.archiver.command = 'aarch64-linux-gnu-ar'

  # CrossBuild doesn't auto-detect a HAL port (effective_ports returns []
  # unless set); mruby-io/mruby-socket need the posix port to link, since
  # the target is a standard glibc Linux userland.
  conf.ports :posix

  conf.gembox 'default'
  conf.enable_test

  # Optional: run mrbtest under qemu-user so `rake MRUBY_CONFIG=aarch64-linux test`
  # works without real arm64 hardware.
  #   sudo apt install qemu-user-static
  if (qemu = `which qemu-aarch64-static 2>/dev/null`.strip) && !qemu.empty?
    conf.test_runner.command = qemu
    conf.test_runner.flags << ['-L', '/usr/aarch64-linux-gnu']
  end
end
