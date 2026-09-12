# mruby Development Guide

mruby 開発に参加するための実践ガイド

## Requirements

### OS・ツール チェックリスト

```bash
# 必須
- GCC 4.8+, Clang 3.4+ (C99 サポート)
- Ruby 2.4+（ビルドシステムが Rake ベース）
- Rake
- POSIX シェル (bash, zsh等)

# 推奨
- Git
- Docker / docker-compose
- prek (pre-commit hook)

# オプション
- Doxygen (C API ドキュメント生成)
- YARD (Ruby ドキュメント生成)
- Clang analyzer (静的解析)
```

**インストール確認**:

```bash
# コンパイラ確認
gcc --version        # 4.8 以上
clang --version      # 3.4 以上

# Ruby & Rake 確認
ruby --version       # 2.4 以上
rake --version

# Git 確認（推奨）
git --version
```

## Setup

### 1. リポジトリクローン

```bash
git clone https://github.com/mruby/mruby.git
cd mruby
```

### 2. 依存ライブラリインストール

```bash
# Gemfile から開発ツール インストール
bundle install

# または、個別インストール
gem install rake yard yard-coderay yard-mruby

# prek (pre-commit hook) インストール（推奨）
# https://github.com/j178/prek に従う
# または Homebrew: brew install prek
```

### 3. Pre-commit Hook セットアップ（オプション）

```bash
prek install

# フックが正常に設定されたか確認
prek run --all-files

# または Makefile で実行
make checkinstall
```

## Environment Variables

### ビルド時環境変数

| 変数 | 説明 | 例 |
|------|------|-----|
| `MRUBY_CONFIG` | ビルド設定ファイル | `debug`, `host-m32`, etc. |
| `CC` | C コンパイラ | `gcc`, `clang` |
| `CXX` | C++ コンパイラ | `g++`, `clang++` |
| `LD` | リンカ | `gcc`, `clang` |
| `CFLAGS` | C コンパイルフラグ | `-O2 -Wall` |
| `LDFLAGS` | リンカフラグ | `-L/path/to/lib` |

### 例

```bash
# デバッグビルド
MRUBY_CONFIG=host-debug rake all test

# 最小構成
MRUBY_CONFIG=minimal rake

# Clang でビルド
CC=clang CXX=clang++ rake all test

# カスタムフラグ
CFLAGS="-O3 -march=native" rake
```

## Database Setup

mruby は DB を使用しません。

ただし、Gem 経由で SQLite 等を統合することは可能。

## Migration

mruby のバージョンアップ時は NEWS.md を確認：

```bash
# API の破壊的変更を確認
head -100 NEWS.md
```

## Run

### 基本的なビルド

```bash
# 全ビルド（デフォルト設定）
rake all

# ビルド + テスト
rake all test

# テストのみ（ビルド済み前提）
rake test

# クリーン
rake clean
```

### 成功時の出力

```
$ rake all test
[ビルド出力]
...
Build summary:
  host  (-o build/host/bin/mruby)
  
Run tests ...

[テスト結果]
...
Tests: 123 OK, Failures: 0, Errors: 0
```

### ビルドアーティファクト確認

```bash
# バイナリ確認
ls -la build/host/bin/
# 出力例:
# -rwxr-xr-x  mruby
# -rwxr-xr-x  mrbc
# -rwxr-xr-x  mirb
# -rwxr-xr-x  mrdb

# ライブラリ確認
ls -la build/host/lib/
# 出力例:
# -rw-r--r--  libmruby.a
```

### インタラクティブシェル

```bash
# REPL 起動
./build/host/bin/mirb

# 実行例
mirb> [1, 2, 3].each { |x| puts x }
1
2
3
=> nil
mirb> puts "Hello"
Hello
=> nil
mirb> exit
```

### Ruby スクリプト実行

```bash
# Ruby スクリプト作成
cat > hello.rb << 'EOF'
puts "Hello, mruby!"
[1, 2, 3].each do |x|
  puts x * 2
end
EOF

# 実行
./build/host/bin/mruby hello.rb
# 出力:
# Hello, mruby!
# 2
# 4
# 6
```

### バイトコード コンパイル

```bash
# コンパイル
./build/host/bin/mrbc -o hello.mrb hello.rb

# 実行
./build/host/bin/mruby hello.mrb

# C ソース出力（埋め込み用）
./build/host/bin/mrbc -o hello.c hello.rb
cat hello.c  # 埋め込み可能な C コード
```

### Docker で実行

```bash
# イメージビルド
docker-compose build test

# テスト実行
docker-compose run test rake all test

# 対話的実行
docker-compose run test /bin/bash
# コンテナ内:
root@xxxx# rake all test
```

## Test

### 全テスト実行

```bash
rake test
```

**出力例**:

```
Run mruby tests ...
mrbtest started.
  assert ... ok
  class ... ok
  ...
  [150+ tests]
Tests: 150 OK, Failures: 0, Errors: 0
```

### 特定の Gem のテスト

```bash
# mruby-io テスト
rake test:mruby-io

# mruby-fiber テスト
rake test:mruby-fiber
```

### テスト対象範囲

| テストタイプ | コマンド | ファイル | 内容 |
|----------|---------|---------|------|
| **ユニット** | `rake test` | test/t/*.rb | 各クラス/モジュール別 |
| **バイナリ** | `rake bintest` | mrbgems/*/bintest/ | CLI ツール |
| **統合** | `rake test` | test/t/ | 複数モジュール連携 |

### 新しいテストの追加

**例**: Array#sum メソッドのテスト

ファイル: `test/t/array.rb` に追加

```ruby
assert('Array#sum') do
  assert_equal(6, [1, 2, 3].sum)
  assert_equal(10, [1, 2, 3].sum(4))
end
```

実行:

```bash
rake test
# または個別実行
rake test:array
```

### テストフレームワーク (test/assert.rb)

**基本アサーション**:

```ruby
assert('説明', 'ISO番号') do
  # テストコード
  assert_equal(expected, actual)
  assert_true(condition)
  assert_false(condition)
  assert_nil(value)
  assert_kind_of(Class, value)
  assert_raise(ExceptionClass) { code }
  assert_nothing_raised { code }
end
```

**テスト実行環境**:

- 各テストは独立した mruby_state で実行
- GC テストでは MRB_GC_STRESS が有効
- Fixture は `test/t/*.rb` 内で定義

## Lint / Format

### prek (pre-commit hook) で自動チェック

```bash
# 全ファイル対象
prek run --all-files

# 特定のフックのみ
prek run --all-files prettier
prek run --all-files clang-format

# スキップ
SKIP=prettier git commit -m "message"
```

### 個別チェック

```bash
# C コード フォーマット (clang-format)
clang-format -i src/*.c include/*.h

# YAML 検証 (yamllint)
yamllint .github/workflows/*.yml

# Markdown リント (markdownlint)
mdl *.md doc/**/*.md

# Shell スクリプト (shellcheck)
shellcheck scripts/*.sh
```

## Build

### カスタムビルド設定

**build_config/ に新しい設定ファイルを作成**:

ファイル: `build_config/my-config.rb`

```ruby
MRuby::Build.new do |conf|
  conf.toolchain  # デフォルトツールチェーン

  # Gem を追加
  conf.gembox 'default'
  conf.gem :core => 'mruby-eval'

  # コンパイラ設定
  conf.cc do |cc|
    cc.flags << '-O3'      # 最適化
    cc.defines << 'NDEBUG' # デバッグ情報削除
  end

  conf.enable_test
end
```

**ビルド実行**:

```bash
MRUBY_CONFIG=my-config rake all test
```

### Amalgamation (単一ファイル化)

```bash
# 単一 mruby.c, mruby.h を生成
rake amalgam

# 出力
ls build/host/amalgam/
# mruby.c (400KB+)
# mruby.h

# コンパイル
gcc -I./build/host/amalgam your_app.c ./build/host/amalgam/mruby.c -o your_app -lm
```

### ドキュメント生成

```bash
# C API + Ruby API ドキュメント
rake doc

# C API のみ (Doxygen)
rake doc:capi

# Ruby API のみ (YARD)
rake doc:api

# ブラウザで表示
rake view_api   # Ruby API
rake view_capi  # C API
```

## Debug

### デバッガで実行

```bash
# Ruby スクリプトデバッグ
./build/host/bin/mrdb hello.rb

# デバッガコマンド
(mrdb) break 5          # 5行目にブレークポイント
(mrdb) continue         # 実行継続
(mrdb) step             # ステップ実行
(mrdb) print variable   # 変数表示
(mrdb) quit             # 終了
```

### GDB でデバッグ

```bash
# C 実装をデバッグ
gdb ./build/host/bin/mruby
(gdb) break mrb_vm_exec
(gdb) run hello.rb
(gdb) next/step
(gdb) print *mrb
```

### デバッグビルド

```bash
MRUBY_CONFIG=host-debug rake all test

# ビルド時オプション
# - MRB_DEBUG マクロ有効
# - デバッグシンボル含入
# - MRB_GC_STRESS 有効
```

### ストレステスト

```bash
# GC ストレスを有効にしてテスト
MRUBY_CONFIG=full-debug rake test

# 結果: 全アロケーションごとに GC が走るため、
# メモリリークやダブルフリーが検出されやすい
```

---

## よくある変更

### 新しい API を追加する

**例**: `mrb_awesome_new()` を追加

**ステップ**:

1. **ヘッダに宣言を追加** (`include/mruby.h`):

```c
MRB_API mrb_value mrb_awesome_new(mrb_state *mrb, const char *data);
```

2. **実装を追加** (`src/awesome.c`):

```c
mrb_value
mrb_awesome_new(mrb_state *mrb, const char *data)
{
  struct RAwesome *obj = mrb_obj_alloc(mrb, MRB_TT_OBJECT, 
                                       mrb->object_class);
  // 初期化コード
  return mrb_obj_value(obj);
}
```

3. **テストを追加** (`test/t/awesome.rb`):

```ruby
assert('mrb_awesome_new') do
  # C API から呼び出す場合は bintest を使用
end
```

4. **ドキュメントを更新**:

```markdown
doc/guides/capi.md に API ドキュメント追加
```

5. **ビルド・テスト**:

```bash
rake clean
rake all test
```

### DB フィールドを追加する

**例**: String に `encoding` フィールドを追加

**ステップ**:

1. **構造体定義を更新** (`include/mruby/string.h`):

```c
struct RString {
  struct RBasic basic;
  int len;
  char *ptr;
  int encoding;  // 新規フィールド
};
```

2. **初期化コード更新** (`src/string.c`):

```c
mrb_str_new(mrb_state *mrb, const char *p, size_t len)
{
  struct RString *s = STR_NEW(mrb, p, len);
  s->encoding = MRB_ENCODING_UTF8;  // デフォルト
  return mrb_str_value(s);
}
```

3. **アクセサメソッド追加** (`src/string.c`):

```c
static mrb_value
mrb_str_encoding(mrb_state *mrb, mrb_value self)
{
  struct RString *s = mrb_str_ptr(self);
  return mrb_fixnum_value(s->encoding);
}

// クラス定義時に登録
mrb_define_method(mrb, c, "encoding", mrb_str_encoding, MRB_ARGS_NONE());
```

4. **テスト追加**:

```ruby
assert('String#encoding') do
  s = "hello"
  assert_equal(0, s.encoding)  # MRB_ENCODING_UTF8 = 0
end
```

5. **GC マーク関数を更新** (`src/string.c`):

```c
static void
string_mark(mrb_state *mrb, void *p)
{
  // encoding は integer なので追加マーク不要
}
```

6. **ビルド・テスト**:

```bash
rake clean
rake all test
```

### ビジネスロジックを変更する

**例**: Array#push の挙動を変更

**ステップ**:

1. **実装を更新** (`src/array.c`):

```c
static mrb_value
mrb_ary_push_m(mrb_state *mrb, mrb_value self)
{
  // 既存のロジック
  // ↓ 変更
}
```

2. **テストを更新** (`test/t/array.rb`):

```ruby
assert('Array#push (modified)') do
  a = [1]
  a.push(2)
  assert_equal([1, 2], a)
  # 新しい動作テスト
end
```

3. **テスト実行**:

```bash
rake test:array
```

4. **他への影響を確認**:

```bash
rake test  # 全テスト
```

### 外部サービスを追加する

**例**: `mruby-http` Gem を作成

**ステップ**:

1. **Gem ディレクトリ作成**:

```bash
mkdir -p mrbgems/mruby-http/src
mkdir -p mrbgems/mruby-http/test
touch mrbgems/mruby-http/mrbgem.rake
```

2. **mrbgem.rake を作成**:

```ruby
MRuby::Gem::Specification.new('mruby-http') do |spec|
  spec.description = 'HTTP client for mruby'
  spec.version = '0.1.0'
  spec.license = 'MIT'
  spec.author = 'Your Name'

  spec.add_dependency('mruby-socket') if build.cc.command =~ /clang/
end
```

3. **C 実装を作成** (`src/http.c`):

```c
#include <mruby.h>

static mrb_value
http_get(mrb_state *mrb, mrb_value self)
{
  const char *url;
  mrb_get_args(mrb, "z", &url);
  
  // HTTP GET 実装
  return mrb_str_new_cstr(mrb, "response");
}

void
mrb_mruby_http_gem_init(mrb_state *mrb)
{
  struct RClass *c = mrb_define_module(mrb, "HTTP");
  mrb_define_module_function(mrb, c, "get", http_get, MRB_ARGS_REQ(1));
}

void
mrb_mruby_http_gem_final(mrb_state *mrb)
{
  // cleanup if needed
}
```

4. **テストを追加** (`test/http.rb`):

```ruby
assert('HTTP.get') do
  # mock 実装でテスト
  result = HTTP.get("http://example.com")
  assert_equal(String, result.class)
end
```

5. **build_config で有効化** (`build_config/default.rb`):

```ruby
conf.gem :path => '../mrbgems/mruby-http'
```

6. **ビルド・テスト**:

```bash
MRUBY_CONFIG=default rake all test
```

### テストを追加する

**例**: 新機能 `Array#flatten` のテスト

ファイル: `test/t/array.rb` に追加

```ruby
assert('Array#flatten') do
  a = [1, [2, 3], [4, [5]]]
  assert_equal([1, 2, 3, 4, 5], a.flatten)
  assert_equal([1, 2, 3, 4, [5]], a.flatten(1))
end

assert('Array#flatten with block') do
  assert_raise(ArgumentError) do
    [1, 2].flatten { |x| x }  # ブロック不可
  end
end
```

実行:

```bash
rake test
# または
rake test:array
```

---

## 開発時の注意事項

### 1. GC Arena の管理（C API 使用時）

```c
// 間違い: オブジェクトが GC で破棄される可能性
mrb_value arr = mrb_ary_new(mrb);
// ... 他のアロケーション
// arr がスコープを出る前に GC が走り、破棄されるかも

// 正解: Arena で保護
int ai = mrb_gc_arena_save(mrb);
mrb_value arr = mrb_ary_new(mrb);
// ... 操作
mrb_gc_arena_restore(mrb, ai);  // 復元
```

### 2. 破壊的変更は慎重に

```c
// API 変更は NEWS.md に明記
// 既存コードの互換性を最優先
// 破壊的変更が必要な場合は、メジャーバージョン更新時
```

### 3. クロスプラットフォーム対応

```c
// プラットフォーム固有コードは #ifdef で保護
#ifdef _WIN32
  // Windows のみ
#elif __APPLE__
  // macOS のみ
#else
  // Linux/POSIX
#endif
```

### 4. メモリリークテスト

```bash
# GC ストレスでメモリリーク検出
MRUBY_CONFIG=full-debug rake test

# または Valgrind
valgrind ./build/host/bin/mruby script.rb
```

### 5. パフォーマンス測定

```bash
# ベンチマーク
rake benchmark

# 結果: build/benchmark/
```

### 6. セキュリティチェック

```bash
# CodeQL 分析
# (GitHub Actions で自動実行)

# または 手動実行
clang --analyze src/*.c

# OSS-Fuzz
# (Docker で実行)
```

---

## トラブルシューティング

### ビルドエラー: `Rake::FileNotFoundError`

**原因**: Gemfile のパッケージがインストールされていない

**解決**:

```bash
bundle install
rake all
```

### テスト失敗: `Tests: 123 OK, Failures: 1`

**確認手順**:

```bash
# テスト詳細表示
rake test VERBOSE=1

# 特定のテストのみ
rake test:array

# ログ確認
less mrbtest.log
```

### ビルド時間が長い

**原因**: 全リビルド

**高速化**:

```bash
# キャッシュを活用
rake test           # 前回のビルドを利用

# 最小構成でビルド
MRUBY_CONFIG=minimal rake
```

### Docker でのビルドエラー

**確認**:

```bash
docker-compose build --no-cache test
docker-compose run test rake all test
```

---

## CI/CD パイプライン

### GitHub Actions で自動テスト

`.github/workflows/build.yml` で実行:

- 複数 OS: Ubuntu, macOS, Windows
- 複数コンパイラ: GCC, Clang
- クロスコンパイル: i686, armhf
- 複数 Ruby バージョン

**PR 提出時に自動実行**

---

## リソース

| リソース | URL/ファイル |
|---------|-------------|
| **公式サイト** | https://mruby.org |
| **GitHub リポジトリ** | https://github.com/mruby/mruby |
| **C API ドキュメント** | doc/guides/capi.md |
| **Gem 開発ガイド** | doc/guides/mrbgems.md |
| **ビルド設定** | doc/guides/compile.md |
| **言語機能** | doc/guides/language.md |
| **NEWS** | NEWS.md (変更履歴) |
| **CONTRIBUTING** | CONTRIBUTING.md |

---

**開発準備完了！小規模な変更からお試しください。**
