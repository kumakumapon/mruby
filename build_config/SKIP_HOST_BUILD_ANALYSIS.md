# Skip Host Build Analysis

## Overview

This document explains how to use `conf.mrbcfile` to prevent the implicit host build generation in mruby.

## The Mechanism

### Default Behavior (Host Build Created)

When you use standard build configuration:

```ruby
MRuby::Build.new do |conf|
  conf.toolchain :gcc
end
```

The build system executes the following check in `lib/mruby/build.rb` (lines 152-154):

```ruby
if current.libmruby_enabled? && !current.mrbcfile_external?
  current.create_mrbc_build if current.host? || current.gems["mruby-bin-mrbc"]
end
```

Since `mrbcfile_external?` is `false` (default), `create_mrbc_build` is invoked, which generates:
- Minimal host build (mrbc compiler)
- Stored in `build/host/mrbc/bin/mrbc`

### With External mrbcfile (No Host Build)

When you specify an external mrbc:

```ruby
MRuby::Build.new do |conf|
  conf.toolchain :gcc
  conf.mrbcfile = "/path/to/existing/mrbc"  # ← External mrbc specified
end
```

The `mrbcfile=` method (lines 367-370 in `lib/mruby/build.rb`):

```ruby
def mrbcfile=(path)
  @mrbcfile = path
  @mrbcfile_external = true  # ← This flag prevents host build
end
```

Result:
- `mrbcfile_external?` returns `true`
- The condition `!current.mrbcfile_external?` becomes `false`
- `create_mrbc_build` is **NOT called**
- **No host build directory is created**
- The specified external mrbc is used for .rb → bytecode compilation

## Key Code Paths

### 1. External mrbcfile Detection (lib/mruby/build.rb:152-154)

```ruby
if current.libmruby_enabled? && !current.mrbcfile_external?
  current.create_mrbc_build if current.host? || current.gems["mruby-bin-mrbc"]
end
```

**Condition**: `!current.mrbcfile_external?`
- When `true` (default): create minimal host build
- When `false` (external mrbc set): skip host build creation

### 2. mrbcfile Getter (lib/mruby/build.rb:352-365)

When mrbc is needed during build:

```ruby
def mrbcfile
  return @mrbcfile if @mrbcfile  # Use pre-set external mrbc
  
  if (gem = @gems["mruby-bin-mrbc"])
    @mrbcfile = exefile("#{gem.build.build_dir}/bin/mrbc")
  elsif !host? && (host = MRuby.targets["host"])
    if (gem = host.gems["mruby-bin-mrbc"])
      @mrbcfile = exefile("#{gem.build.build_dir}/bin/mrbc")
    elsif host.mrbcfile_external?
      @mrbcfile = host.mrbcfile
    end
  end
  @mrbcfile || fail("external mrbc or mruby-bin-mrbc gem required")
end
```

### 3. mrbcfile Setter (lib/mruby/build.rb:367-374)

```ruby
def mrbcfile=(path)
  @mrbcfile = path
  @mrbcfile_external = true  # Sets the flag
end

def mrbcfile_external?
  @mrbcfile_external
end
```

## Build Configuration Examples

### Example 1: Skip Host Build (Requires Pre-built mrbc)

```ruby
# build_config/skip_host_build.rb
MRuby::Build.new do |conf|
  conf.toolchain :gcc
  
  # Specify external mrbc (must exist and be host-compatible)
  conf.mrbcfile = "#{MRUBY_ROOT}/build/host/mrbc/bin/mrbc"
  
  conf.gembox 'default'
  conf.enable_bintest
  conf.enable_test
end
```

**Usage:**
```bash
# First build: Create the mrbc
rake clean all

# Subsequent builds: Skip host build, use existing mrbc
MRUBY_CONFIG=skip_host_build rake clean all
```

### Example 2: Cross-Compile with External mrbc

```ruby
# build_config/cross_skip_host.rb
MRuby::Build.new do |conf|
  conf.toolchain :gcc
  conf.mrbcfile = "/usr/local/bin/mrbc"  # System mrbc
end

MRuby::CrossBuild.new('arm-linux') do |conf|
  conf.toolchain :gcc
  conf.cc.flags << '-march=armv7-a'
  conf.cc.flags << '--target=arm-linux-gnueabihf'
  
  # This build still needs mrbc for Ruby file compilation
  # It will look for it in: mruby-bin-mrbc gem, or the host build's mrbc
end
```

## Requirements and Limitations

### What Works (✅)

| Goal | Status |
|------|--------|
| Skip `build/host` directory creation | ✅ |
| Avoid host C compiler invocation | ✅ |
| Reuse existing host-native mrbc | ✅ |
| Use cross-compilation without host build | ✅ |

### What Doesn't Work (❌)

| Goal | Status |
|------|--------|
| Skip mrbc execution entirely | ❌ |
| Eliminate all host dependencies | ❌ |
| Use non-native mrbc | ❌ |

### Critical Requirement

**The specified mrbc must be:**
1. An actual executable file (not a script or symlink to missing file)
2. Native to the build system (e.g., x86_64 binary on x86_64 Linux)
3. Compatible with the mruby version being built
4. Readable and executable by the build process

## When to Use This Approach

Use `conf.mrbcfile` to skip host build when:

- **Goal**: Reduce build time by avoiding redundant compilations
- **Context**: Already have a built mrbc available
- **Constraint**: Host C compiler resources are limited
- **Requirement**: Don't need fresh host binaries

## When This Won't Work

Don't use this approach when:

- Starting from clean repository (no mrbc available)
- Need both host and target binaries in single build
- Building on platform without pre-built mrbc
- Changing compiler/toolchain (incompatible mrbc)

## Code Flow Diagram

```
ビルド設定読み込み
    ↓
conf.mrbcfile = "/path/to/mrbc" 設定?
    ├─ Yes → @mrbcfile_external = true
    │         ↓
    │   create_mrbc_build() スキップ
    │   ↓
    │   build/host ディレクトリは作られない
    │   外部 mrbc をビルド中に使用
    │
    └─ No → @mrbcfile_external = false (デフォルト)
            ↓
         create_mrbc_build() 実行
         ↓
         build/host/mrbc/bin/mrbc 生成
```

## Verification Commands

To verify the external mrbc approach works:

```bash
# 1. Create initial build with host
rake clean all

# 2. Verify host mrbc exists
ls -la build/host/mrbc/bin/mrbc

# 3. Remove host build directory (to test truly external mrbc)
rm -rf build/host

# 4. Build again using skip_host_build config
MRUBY_CONFIG=skip_host_build rake clean all

# 5. Verify host build was NOT created
[ ! -d build/host ] && echo "✓ Host build skipped successfully"
```

## Summary

The `conf.mrbcfile = "path"` mechanism leverages the `@mrbcfile_external` flag to prevent implicit host build generation. This is the most efficient and straightforward way to skip the host build when you have an existing, compatible mrbc executable available.

Key insight: The build system checks `!current.mrbcfile_external?` to decide whether to create the minimal mrbc build. By setting an external mrbc path, this flag becomes `true`, and the host build is skipped.
