# Skipping the 'host' Build: Analysis

## Overview

This document explains how (and how not) to avoid building a 'host'
target in mruby, using `conf.mrbcfile`.

## Two different things named "host build"

mruby's build system has two related but distinct concepts, and mixing
them up produces a config that looks like it skips the host build but
doesn't:

1. **The 'host' target itself** -- created by calling `MRuby::Build.new`
   (its default `name` is `'host'`, see `lib/mruby/build.rb`). If your
   config calls this at all, a full host build (`build/host/src`,
   `build/host/lib`, `build/host/bin`, ...) is compiled, full stop.
   `conf.mrbcfile` does **not** prevent this -- you asked for this build
   to exist by calling `MRuby::Build.new`.

2. **The implicit minimal 'host' bootstrap build that `CrossBuild` adds
   for you** -- if a config defines only `MRuby::CrossBuild` targets and
   never calls `MRuby::Build.new`, `CrossBuild#initialize` will add a
   *minimal* `MRuby::Build.new('host')` on your behalf (mrbc only,
   `libmruby` disabled), because it needs some mrbc to compile mrblib
   with. This is the one `conf.mrbcfile` can prevent.

## The Mechanism That Actually Skips a 'host' Target

`lib/mruby/build.rb`, `CrossBuild#initialize`:

```ruby
def initialize(name, build_dir=nil, &block)
  @test_runner = Command::CrossTestRunner.new(self)
  super
  unless mrbcfile_external? || MRuby.targets['host']
    # add minimal 'host'
    MRuby::Build.new('host') do |conf|
      conf.toolchain
      conf.build_mrbc_exec
      conf.disable_libmruby
    end
  end
end
```

`mrbcfile_external?` becomes `true` as soon as `conf.mrbcfile = path` is
assigned (`lib/mruby/build.rb`, `Build#mrbcfile=`):

```ruby
def mrbcfile=(path)
  @mrbcfile = path
  @mrbcfile_external = true
end
```

So: **set `conf.mrbcfile` on a `CrossBuild`, and never call
`MRuby::Build.new` anywhere in the same config file** -- then no `host`
target, minimal or full, is created at all.

## What `conf.mrbcfile` Does on a Plain `MRuby::Build.new` (NOT This)

A separate, unrelated mechanism exists inside `Build#initialize`:

```ruby
if current.libmruby_enabled? && !current.mrbcfile_external?
  current.create_mrbc_build if current.host? || current.gems["mruby-bin-mrbc"]
end
```

`create_mrbc_build` builds a small bootstrap sub-target named
`"#{@name}/mrbc"` (e.g. `build/host/mrbc`) used to compile mrblib for
*that same build*. Setting `conf.mrbcfile` on, say, an unnamed
`MRuby::Build.new` (name `'host'`) skips regenerating that bootstrap
sub-target and reuses the external mrbc for it -- but the main `host`
build (`build/host/src`, `lib`, `bin`) still compiles fully, because you
explicitly asked for a `host` target to exist. **This does not skip the
host build.** An earlier version of this document, and a
`build_config/skip_host_build.rb` written this way, made this mistake --
confirmed by testing: it still produced ~66 MB of `build/host/{src,lib,mrbgems}`
output even with `conf.mrbcfile` set.

## Verified Working Configuration

```ruby
# No MRuby::Build.new call anywhere in this file.

external_mrbc = ENV['EXTERNAL_MRBC']
fail "set EXTERNAL_MRBC" unless external_mrbc && File.exist?(external_mrbc)

MRuby::CrossBuild.new('skip-host-example') do |conf|
  conf.toolchain :gcc
  conf.mrbcfile = external_mrbc
  conf.ports :posix   # CrossBuild doesn't auto-detect a HAL port
  conf.gembox 'default'
end
```

See `build_config/skip_host_build.rb` for the full, runnable version.

### Test procedure and result

```console
$ rm -rf build
$ EXTERNAL_MRBC=/tmp/external_mrbc/mrbc \
    MRUBY_CONFIG=skip_host_build rake all
...
$ ls build/
skip-host-example/
$ [ -d build/host ] && echo FAIL || echo "OK: no build/host"
OK: no build/host
$ build/skip-host-example/bin/mruby -e 'puts 1+2'
3
```

- `build/host` was never created (0 references to it in the build log).
- The build summary lists exactly one target: `skip-host-example`.
- The resulting `mruby` and `mrbc` binaries run correctly.

## Requirements for the External mrbc

- Must be a real, executable file.
- Must run **natively on the machine doing the build** (the build host),
  not on the cross-compilation target. A binary compiled for ARM will
  not run to compile mrblib on an x86_64 build machine.
- Must be compatible with the mruby source/version being built (mrbc's
  output format and presym layout must match).
- Should live outside `build/`, since `rake clean` deletes `build/`.

## Requirement Matrix

| Goal | `conf.mrbcfile` on `MRuby::Build.new` | `conf.mrbcfile` on `MRuby::CrossBuild` (no `Build.new` in config) |
|------|:---:|:---:|
| No `build/host` directory at all | ❌ | ✅ |
| Avoid host C compiler use in this build | ❌ | ✅ |
| Reuse an existing host-native mrbc | ✅ (for the bootstrap sub-build only) | ✅ |
| Skip mrbc execution entirely | ❌ | ❌ |
| Zero dependency on any host-native executable | ❌ | ❌ (mrbc itself is still one) |

## Summary

- To reuse an external mrbc for the bootstrap step *within* a `host`
  build: set `conf.mrbcfile` on that `MRuby::Build.new`. The host build
  still fully compiles.
- To avoid a `host` target existing at all: only define
  `MRuby::CrossBuild` targets, never call `MRuby::Build.new`, and set
  `conf.mrbcfile` on the `CrossBuild` to a pre-built, host-native mrbc.
