# Testing: Skip the 'host' Build Entirely

This is the verified test procedure for `build_config/skip_host_build.rb`.
See `SKIP_HOST_BUILD_ANALYSIS.md` for why the mechanism must be applied to
a `MRuby::CrossBuild` and never combined with `MRuby::Build.new` in the
same config -- combining the two does **not** skip the host build (that
was an error in an earlier version of these docs, corrected here).

## Prerequisites

- A pre-built, host-native `mrbc` executable, copied outside `build/`
  (e.g. from a prior plain `rake` run: `build/host/mrbc/bin/mrbc`).
- Ruby >= 2.5, a C compiler, standard build tools.

## Step 1: Produce an external mrbc once

```bash
rake clean
rake all                      # produces build/host/mrbc/bin/mrbc
mkdir -p /tmp/external_mrbc
cp build/host/mrbc/bin/mrbc /tmp/external_mrbc/mrbc
/tmp/external_mrbc/mrbc --version   # sanity check it runs standalone
```

## Step 2: Remove all trace of a host build

```bash
rm -rf build
ls build   # should fail: No such file or directory
```

## Step 3: Build with skip_host_build, no host build should appear

```bash
EXTERNAL_MRBC=/tmp/external_mrbc/mrbc \
  MRUBY_CONFIG=skip_host_build rake all
```

Verify:

```bash
ls build/
# Expect only: skip-host-example/
# NOT: host/

[ -d build/host ] && echo "FAIL: build/host exists" || echo "OK: no build/host"
```

## Step 4: Verify the resulting binaries actually work

```bash
build/skip-host-example/bin/mruby -e 'puts 1 + 2'
# => 3

echo 'puts "hi"' > /tmp/t.rb
build/skip-host-example/bin/mrbc -o /tmp/t.mrb /tmp/t.rb
ls -la /tmp/t.mrb
```

## Step 5 (optional): Confirm via the build log

```bash
EXTERNAL_MRBC=/tmp/external_mrbc/mrbc \
  MRUBY_CONFIG=skip_host_build rake clean all 2>&1 | tee /tmp/build.log

grep -c 'build/host' /tmp/build.log   # expect: 0
grep -A2 'Config Name' /tmp/build.log # expect: only "skip-host-example"
```

## Expected Results (all observed when this was last run)

```
$ ls build/
skip-host-example/

$ [ -d build/host ] && echo FAIL || echo "OK: no build/host"
OK: no build/host

$ build/skip-host-example/bin/mruby -e 'puts 1 + 2'
3

$ grep -c 'build/host' /tmp/build.log
0

$ grep -A2 'Config Name' /tmp/build.log
      Config Name: skip-host-example
 Output Directory: build/skip-host-example
         Binaries: mrbc
```

## Negative test: EXTERNAL_MRBC unset fails fast

```bash
unset EXTERNAL_MRBC
MRUBY_CONFIG=skip_host_build rake all
```

Expected: `rake aborted!` with a message telling you to set
`EXTERNAL_MRBC`, rather than silently falling back to building a host
target.

## What This Does NOT Test

This does not test using `conf.mrbcfile` on a plain, named-'host'
`MRuby::Build.new` -- that is a different mechanism (it only skips the
internal `build/host/mrbc` bootstrap sub-build, not the `host` build
itself) and does not belong under "skip the host build". See
`SKIP_HOST_BUILD_ANALYSIS.md` for the distinction and why an earlier
config in this directory (`skip_host_build.rb`, before it was corrected)
demonstrated the wrong mechanism.

## Troubleshooting

### "set EXTERNAL_MRBC..."

`EXTERNAL_MRBC` is unset or points at a missing file. Re-run Step 1.

### Linker errors about `mrb_hal_io_*`

The cross target has no HAL port configured (`conf.ports` unset defaults
to `[]` for `CrossBuild`). Add `conf.ports :posix` (or whatever port
matches your actual target) if the gembox includes `mruby-io`.

### "command not found" / mrbc fails at runtime

The external mrbc is either not executable (`chmod +x`) or was built for
a different architecture than the machine currently running `rake`.
Check with `file /path/to/mrbc` and `uname -m`.
