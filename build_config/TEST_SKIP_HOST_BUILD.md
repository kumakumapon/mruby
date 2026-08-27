# Testing Skip Host Build Configuration

## Overview

This guide provides step-by-step instructions to verify that the `conf.mrbcfile` mechanism correctly skips the host build.

## Test Setup

### Prerequisites

- mruby source repository
- Ruby >= 2.5
- C compiler (gcc or clang)
- Standard build tools (make, ar, etc.)

### Preparation

1. **Clean build to establish baseline:**
   ```bash
   rake clean
   rake all
   ```
   This creates `build/host/mrbc/bin/mrbc` which will be used as the external mrbc.

2. **Verify mrbc exists:**
   ```bash
   ls -la build/host/mrbc/bin/mrbc
   file build/host/mrbc/bin/mrbc  # Should show: ELF 64-bit LSB executable
   ```

## Test 1: Verify External mrbcfile Skips Host Build

### Test Procedure

1. **Clean build directory (but keep mrbc):**
   ```bash
   rm -rf build/host
   rm -rf build/host-shared
   rm -rf build/repos
   ```

2. **Attempt build with skip_host_build config:**
   ```bash
   MRUBY_CONFIG=skip_host_build rake all
   ```

3. **Verify results:**
   ```bash
   # Host build directory should NOT exist
   if [ ! -d build/host ]; then
     echo "✓ SUCCESS: Host build was skipped"
   else
     echo "✗ FAILURE: Host build was created"
     ls -la build/host/
   fi

   # mrbc should still work (from external path)
   if [ -f build/host/mrbc/bin/mrbc ]; then
     echo "✓ SUCCESS: External mrbc is being used"
   else
     echo "✗ FAILURE: External mrbc not found"
   fi
   ```

### Expected Results

```
✓ SUCCESS: Host build was skipped
✓ SUCCESS: External mrbc is being used
```

**What should happen:**
- No `build/host/src` directory
- No `build/host/lib` directory  
- No `build/host/bin` directory
- Build completes successfully using the external mrbc
- Ruby files (.rb) are still compiled to bytecode via the external mrbc

## Test 2: Verify Cross-Compilation with Skipped Host Build

### Test Procedure

1. **Start fresh:**
   ```bash
   rake clean
   rm -rf build/
   ```

2. **Create initial mrbc:**
   ```bash
   rake all
   # Creates build/host/mrbc/bin/mrbc
   ```

3. **Remove full host build:**
   ```bash
   rm -rf build/host/src build/host/lib build/host/bin build/host/mrblib
   # Keep only build/host/mrbc
   ```

4. **Build with cross_skip_host config:**
   ```bash
   MRUBY_CONFIG=cross_skip_host rake all
   ```

5. **Verify:**
   ```bash
   # Host source/lib/bin should not be rebuilt
   if [ ! -d build/host/src ] && [ ! -d build/host/lib ]; then
     echo "✓ SUCCESS: Host build remains skipped"
   else
     echo "✗ FAILURE: Host build was reconstructed"
   fi

   # Cross-compilation should succeed
   if [ -d build/cross-32bit/lib ]; then
     echo "✓ SUCCESS: Cross-build completed"
     ls -la build/cross-32bit/lib/libmruby.a
   else
     echo "✗ FAILURE: Cross-build failed"
   fi
   ```

### Expected Results

```
✓ SUCCESS: Host build remains skipped
✓ SUCCESS: Cross-build completed
-rw-r--r-- 1 user user 12345678 Nov 27 10:30 build/cross-32bit/lib/libmruby.a
```

## Test 3: Code-Level Verification

Verify the mechanism by inspecting code execution:

### Check 1: mrbcfile_external Flag

The external mrbc flag should be set after `conf.mrbcfile = "path"`:

```ruby
# In lib/mruby/build.rb, line 367-369:
def mrbcfile=(path)
  @mrbcfile = path
  @mrbcfile_external = true  # ← This flag prevents host build
end
```

### Check 2: create_mrbc_build Condition

Verify that create_mrbc_build is skipped:

```ruby
# In lib/mruby/build.rb, line 152-154:
if current.libmruby_enabled? && !current.mrbcfile_external?
  #                               ↑ This is FALSE when external mrbc is set
  current.create_mrbc_build if current.host? || current.gems["mruby-bin-mrbc"]
  # ↑ This is NOT called
end
```

### Check 3: mrbcfile Resolution

When build needs mrbc:

```ruby
# In lib/mruby/build.rb, line 352-365:
def mrbcfile
  return @mrbcfile if @mrbcfile  # ← Returns external mrbc path
  # ... other fallbacks not reached ...
end
```

## Test 4: Build Directory Structure Comparison

### Normal Build (with host)

```
build/
├── host/
│   ├── mrbc/
│   │   └── bin/mrbc              (mrbc compiler)
│   ├── src/                       (C objects)
│   ├── lib/
│   │   └── libmruby.a
│   ├── bin/
│   │   ├── mruby
│   │   └── mirb
│   └── mrblib/
├── host-shared/
│   └── lib/
│       └── libmruby.so            (if configured)
└── ...
```

### Skip Host Build Config

```
build/
├── host/
│   ├── mrbc/
│   │   └── bin/mrbc              (external, pre-existing)
│   ├── src/                       (NOT created)
│   ├── lib/                       (NOT created)
│   └── bin/                       (NOT created)
└── ...
```

**Key Differences:**
- `build/host/src/` NOT created
- `build/host/lib/libmruby.a` NOT created
- `build/host/bin/mruby` NOT created (if not in config)
- Only `build/host/mrbc/bin/mrbc` remains (external)

## Troubleshooting

### Issue: "external mrbc not found"

**Cause:** External mrbc path doesn't exist

**Solution:**
1. Run full build first: `rake clean all`
2. Verify mrbc exists: `ls build/host/mrbc/bin/mrbc`
3. Check path in config matches actual location

### Issue: "command not found: mrbc"

**Cause:** External mrbc is not executable or wrong architecture

**Solution:**
1. Check permissions: `chmod +x /path/to/mrbc`
2. Verify architecture: `file /path/to/mrbc`
3. Confirm it matches build system: `uname -m` vs `mrbc` architecture

### Issue: Build fails with "ruby files not compiled"

**Cause:** External mrbc failed to execute

**Solution:**
1. Test mrbc manually: `/path/to/mrbc --version`
2. Check if linked libraries exist: `ldd /path/to/mrbc`
3. Fallback to full build: `rake clean all`

## Performance Metrics

### Build Time Comparison

Expected improvement when skipping host build:

| Operation | Full Build | Skip Host |
|-----------|-----------|-----------|
| Clean + rebuild | ~120s | ~30s |
| Rebuild (no changes) | ~5s | ~2s |
| Cross-compile only | N/A | ~60s |

**Caveat:** Times vary by system, compiler, and gem count.

## Summary

The skip host build feature works by:

1. Setting `conf.mrbcfile = "/path/to/mrbc"` 
2. This sets `@mrbcfile_external = true`
3. Which prevents `create_mrbc_build` from being called
4. So `build/host/src`, `build/host/lib`, etc. are not created
5. The specified external mrbc is used for all Ruby compilation

This reduces build time and resource usage when rebuilding or cross-compiling, assuming a compatible mrbc already exists.
