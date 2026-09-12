# mruby Code Reading Guide

初見のエンジニアが mruby コードベースを理解するための読了順序ガイド

## 最初に読む5ファイル（Critical）

### 1. README.md
**ファイル**: `/home/user/mruby/README.md`

**理由**:
- プロジェクトの目的と利用例が簡潔に書かれている
- ビルド方法の概要がある

**注目する部分**:
- Line 31-35: mruby の定義（軽量実装、ISO標準対応、バイトコード）
- Line 37-42: ツール群の説明（mruby, mirb, mrbc, mrbtest）
- Line 47-62: インストール方法

---

### 2. include/mruby.h
**ファイル**: `/home/user/mruby/include/mruby.h`

**理由**:
- C API の全体像
- 主要なデータ型、マクロ、関数宣言
- mruby を埋め込む際の入り口

**構成**（約 1500 行）:
- Line 50-100: インクルード、基本マクロ
- Line 200-400: 値表現（mrb_value, mrb_type）
- Line 600-800: mrb_state 構造体定義
- Line 1200-1400: 主要 API 宣言
  - `mrb_open()`, `mrb_close()`
  - `mrb_load_string()`, `mrb_load_file()`
  - `mrb_funcall()`, `mrb_yield()`
  - `mrb_define_class()`, `mrb_define_method()`

**注目する関数**:
```c
// ライフサイクル
mrb_state* mrb_open(void);
void mrb_close(mrb_state *mrb);

// コード実行
mrb_value mrb_load_string(mrb_state *mrb, const char *code);
mrb_value mrb_funcall(mrb_state *mrb, mrb_value obj, const char *method, ...);

// クラス・メソッド定義
struct RClass* mrb_define_class(mrb_state *mrb, const char *name, struct RClass *super);
void mrb_define_method(mrb_state *mrb, struct RClass *c, const char *name, mrb_func_t func, mrb_aspec aspec);

// 値操作
mrb_value mrb_str_new_cstr(mrb_state *mrb, const char *s);
mrb_value mrb_ary_new(mrb_state *mrb);
mrb_value mrb_hash_new(mrb_state *mrb);
```

---

### 3. include/mruby/internal.h
**ファイル**: `/home/user/mruby/include/mruby/internal.h`

**理由**:
- コア構造体の詳細定義
- mrb_state, RBasic, RObject, RClass の完全な定義
- 内部実装の全体像

**構成**（43KB）:
- VM コンテキスト構造体
- メモリ管理構造体
- クラス・オブジェクト構造体
- ハッシュテーブル定義

**注目する構造体**:
```c
struct mrb_state {
  mrb_allocf allocf;             // メモリアロケータ
  mrb_gc gc;                     // GC 状態
  struct RClass *object_class;   // Object クラス
  // ... 多くのフィールド
};

struct RBasic {
  uint32_t tt:8;                 // Type tag
  uint32_t flags:24;             // フラグ
};

struct RClass {
  struct RBasic basic;
  struct RClass *super;          // 親クラス
  struct khash_t(name) *iv_tbl;  // インスタンス変数テーブル
  struct khash_t(mt) *mt;        // メソッドテーブル
};
```

---

### 4. src/vm.c（最初の 500 行）
**ファイル**: `/home/user/mruby/src/vm.c`

**理由**:
- 仮想マシンの実行エンジンの入り口
- バイトコード実行の中心ロジック
- コンテキスト・スタック・フレーム管理

**読み順**:
1. Line 1-100: マクロ定義、定数
2. Line 250-350: `mrb_vm_exec()` 関数の開始（メインループ）
3. Line 400-500: オペコード処理の例（OP_MOVE, OP_LOADCONST等）

**注目する関数**:
```c
// メイン実行ループ
mrb_value mrb_vm_exec(mrb_state *mrb, const mrb_irep *irep, mrb_value *regs);

// 呼び出しスタック
#define CALL_MAXARGS 15
struct mrb_callinfo {
  const mrb_irep *irep;          // バイトコード
  mrb_value *stackent;           // スタックポインタ
  mrb_code *pc;                  // プログラムカウンタ
  struct RProc *proc;            // Proc オブジェクト
  // ...
};
```

---

### 5. Rakefile（最初の 50 行）
**ファイル**: `/home/user/mruby/Rakefile`

**理由**:
- ビルドシステムの全体構成
- タスク依存性の理解
- ビルドフロー

**構成**:
- Line 1-10: 基本設定（MRUBY_ROOT, MRUBY_BUILD_HOST_IS_CYGWIN）
- Line 11-20: `require "mruby/build"` でビルドシステムロード
- Line 20-45: 設定ファイル読み込み
- Line 50-70: タスク定義（:all, :test, :clean）

**注目する部分**:
```ruby
# ビルド設定ファイルロード
MRUBY_CONFIG = MRuby::Build.mruby_config_path  # デフォルト: build_config/default.rb
load MRUBY_CONFIG

# ビルドターゲット定義
MRuby.each_target do |build|
  build.define_rules
end

# タスク読み込み
load "#{MRUBY_ROOT}/tasks/core.rake"
load "#{MRUBY_ROOT}/tasks/mrbgems.rake"
load "#{MRUBY_ROOT}/tasks/test.rake"
```

---

## 次に読むファイル（Important）

### エントリーポイント (Project)

| ツール | ファイル | 説明 | 重要度 |
|--------|---------|------|--------|
| **mruby** | mrbgems/mruby-bin-mruby/tools/mruby/mruby.c | インタプリタ | Critical |
| **mirb** | mrbgems/mruby-bin-mirb/tools/mirb/ | REPL | Important |
| **mrbc** | mrbgems/mruby-bin-mrbc/tools/mrbc/ | コンパイラ | Important |

### コア実装 (VM & GC)

| ファイル | 行数 | 説明 | 重要度 |
|---------|------|------|--------|
| src/vm.c | 3000+ | 仮想マシン実行エンジン | **Critical** |
| src/gc.c | 800+ | ガベージコレクション | **Critical** |
| src/class.c | 4000+ | クラス・モジュールシステム | **Critical** |
| include/mruby/value.h | 500+ | 値表現（Boxing） | Important |

### 標準型実装

| ファイル | 説明 | 重要度 |
|---------|------|--------|
| src/array.c | 配列実装 | Important |
| src/hash.c | ハッシュ実装 | Important |
| src/string.c | 文字列実装 | Important |
| src/numeric.c | 数値型実装 | Important |
| src/object.c | オブジェクト基盤 | Important |
| src/kernel.c | Kernel メソッド | Important |

### 標準ライブラリ (Ruby)

| ファイル | 説明 | 重要度 |
|---------|------|--------|
| mrblib/enum.rb | Enumerable 実装 | Important |
| mrblib/array.rb | Array メソッド補完 | Reference |
| mrblib/hash.rb | Hash メソッド補完 | Reference |
| mrblib/string.rb | String メソッド補完 | Reference |

### コンパイラ・パーサー

| パッケージ | ファイル | 説明 | 重要度 |
|----------|---------|------|--------|
| mruby-compiler | mrbgems/mruby-compiler/ | Prism パーサー+コード生成 | Critical |
| (presym) | lib/mruby/presym.rb | シンボル事前割り当て | Important |
| (codegen) | mrbgems/mruby-compiler/core/codegen.c | IREP 生成 | Important |

### ビルドシステム

| ファイル | 説明 | 重要度 |
|---------|------|--------|
| lib/mruby/build.rb | ビルド設定・実行 | Important |
| lib/mruby/gem.rb | Gem 管理 | Important |
| lib/mruby/source.rb | ソースコンパイル | Reference |

---

## エントリーポイント

### 1. mruby インタプリタ

**ファイル**: `mrbgems/mruby-bin-mruby/tools/mruby/mruby.c`

**流れ**:

```c
int main(int argc, char **argv)
  ├─ Line 286-300: mrb_open() → mruby_state 初期化
  ├─ Line 301: parse_args() → 引数解析
  ├─ Line 308-316: ARGV グローバル定数設定
  ├─ Line 335-360: -r オプションでライブラリロード
  ├─ Line 380-420: スクリプトをロード・実行
  │  ├─ mrb_stream_is_unreadable() → ファイル存在確認
  │  ├─ mrb_extension_p() → .mrb ファイル判定
  │  ├─ mrb_load_irep_file_cxt() → .mrb ロード (バイトコード)
  │  └─ mrb_load_detect_file_cxt() → .rb ロード (コンパイル)
  └─ Line 430-450: mrb_close() → クリーンアップ
```

**主要処理**:
- Line 23-36: `struct _args` 定義（コマンド引数保持）
- Line 46-67: usage() → ヘルプ表示
- Line 69-77: mrb_extension_p() → .mrb 判定
- Line 200-280: parse_args() → 引数パース実装

**注目する呼び出し**:
```c
// src/state.c で定義
mrb_state *mrb_open(void);

// src/load.c で定義
mrb_value mrb_load_irep_file_cxt(mrb_state *mrb, FILE *f, mrb_ccontext *c);
mrb_value mrb_load_detect_file_cxt(mrb_state *mrb, FILE *f, mrb_ccontext *c);

// src/error.c で定義
void mrb_print_error(mrb_state *mrb);
```

### 2. mirb（対話シェル）

**ファイル**: `mrbgems/mruby-bin-mirb/tools/mirb/mirb.c`

**流れ**:

```
main()
  ├─ mrb_open()
  ├─ REPL ループ
  │  ├─ readline() → ユーザー入力
  │  ├─ mrb_load_string() → コンパイル・実行
  │  ├─ 結果表示
  │  └─ 例外処理
  └─ mrb_close()
```

### 3. mrbc（コンパイラ）

**ファイル**: `mrbgems/mruby-bin-mrbc/tools/mrbc/mrbc.c`

**流れ**:

```
main()
  ├─ mrb_open()
  ├─ Ruby ソース読み込み
  ├─ mrb_parse_string() → AST 作成
  ├─ mrb_generate_code() → IREP 生成
  ├─ mrb_dump_irep() または mrb_dump_irep_cf()
  │  └─ .mrb ファイル出力 または C ソース出力
  └─ mrb_close()
```

---

## リクエスト処理の追い方

### Ruby スクリプト実行フロー

```
script.rb: puts "Hello"
    ↓
mruby script.rb
    ↓
mruby.c:main()
    ↓
1. mrb_open() [src/state.c]
   └─ mrb_state 初期化・GC・クラスシステム
    ↓
2. parse_args() [mruby.c]
   └─ "script.rb" をファイル指定として検出
    ↓
3. mrb_load_detect_file_cxt() [src/load.c]
   ├─ .rb と判定
   ├─ ファイル読み込み
   ├─ mrb_load_cxt() を呼び出し
   │  ├─ Prism parser (mruby-compiler)
   │  │  └─ Ruby → AST
   │  ├─ Code generation
   │  │  └─ AST → IREP (バイトコード)
   │  ├─ mrb_vm_exec() [src/vm.c]
   │  │  ├─ OP_LOADCONST: "Hello" を読み込み
   │  │  ├─ OP_SEND: puts メソッド呼び出し
   │  │  ├─ src/kernel.c:mrb_kernel_puts() 実行
   │  │  └─ 出力: "Hello"
   │  └─ 戻り値を mrb_value で返す
   └─ 結果を返す
    ↓
4. mrb_close() [src/state.c]
   └─ メモリ解放・GC sweep
```

**読むべきファイル順**:
1. mrbgems/mruby-bin-mruby/tools/mruby/mruby.c:main() - エントリーポイント
2. src/load.c:mrb_load_detect_file_cxt() - ファイルロード
3. mrbgems/mruby-compiler/core/codegen.c - コード生成（簡単な例から）
4. src/vm.c:mrb_vm_exec() - バイトコード実行
5. src/kernel.c:mrb_kernel_puts() - 実装例

---

## DB アクセス処理の追い方

### Array 操作例

```ruby
a = [1, 2, 3]
a.each { |x| puts x }
```

**コールチェーン**:

```
Ruby: a.each { ... }
  ↓
VM: OP_SEND "each" [src/vm.c]
  ↓
src/array.c:mrb_ary_each() [C 実装]
  ├─ Array オブジェクト取得
  ├─ 各要素を反復
  ├─ ブロック実行
  │  └─ mrb_yield() [src/vm.c]
  └─ nil を返す
  ↓
出力: 1, 2, 3
```

**読むべきファイル**:
1. src/array.c - Array メソッド実装
2. include/mruby/array.h - Array 構造体定義
3. include/mruby/value.h - mrb_value boxing
4. src/vm.c:mrb_yield() - ブロック実行

### Hash 操作例

```ruby
h = {a: 1, b: 2}
h.each { |k, v| puts "#{k}: #{v}" }
```

**読むべきファイル**:
1. src/hash.c - Hash メソッド実装
2. include/mruby/hash.h - Hash 構造体
3. include/mruby/khash.h - Khash（ハッシュテーブル実装）
4. mrblib/hash.rb - Ruby 補完メソッド

---

## 非同期処理の追い方

### Fiber 実装

mruby コアには async なし。Fiber で Coroutine：

```ruby
f = Fiber.new { |x| Fiber.yield x * 2 }
f.resume(5)  # → 10
```

**読むべきファイル**:
1. mrbgems/mruby-fiber/src/fiber.c - Fiber 実装
2. mrbgems/mruby-fiber/mrbgem.rake - Gem ビルド
3. src/proc.c - Proc（Fiber は Proc ベース）
4. include/mruby/proc.h - Proc/Fiber 構造体

---

## 認証処理の追い方

**mruby コアに認証機構なし**

セキュリティが必要な場合：
1. ホストアプリケーションで認証実装
2. Gem で認証 Gem を追加
3. C API で認証関数を Ruby に公開

**例**:

```c
// C から認証メソッドを定義
mrb_define_method(mrb, mrb_class_get(mrb, "Auth"),
                  "login", c_login, MRB_ARGS_REQ(2));

// Ruby から呼び出し
Auth.login(username, password)
```

---

## 主要ユースケース別コードマップ

### UC1: Ruby スクリプト実行

```
CLI: mruby script.rb
  ↓
mrbgems/mruby-bin-mruby/tools/mruby/mruby.c:main()
  ↓
src/state.c:mrb_open()
  ↓
src/load.c:mrb_load_detect_file_cxt()
  ↓
mrbgems/mruby-compiler/core/codegen.c [コンパイル]
  ↓
src/vm.c:mrb_vm_exec() [実行]
  ↓
src/kernel.c [メソッド実装]
  ↓
出力・結果
```

### UC2: C から Ruby メソッド呼び出し

```
C: mrb_funcall(mrb, obj, "method_name", ...)
  ↓
src/vm.c:mrb_funcall()
  ↓
Method Resolution: src/class.c:find_method()
  ↓
Method Type Check
  ├─ RUBY_METHOD: IREP 実行 (src/vm.c)
  └─ MRB_METHOD_CFUNC: C 関数ダイレクト実行
  ↓
結果を mrb_value で返す
  ↓
C: mrb_value を C 型に変換
```

### UC3: Gem 統合（C拡張）

```
mrbgems/your-gem/
  ├─ mrbgem.rake [ビルド定義]
  ├─ src/your-gem.c [C 実装]
  │  └─ mrb_gem_init() {
  │       mrb_define_class()
  │       mrb_define_method()
  │     }
  ├─ lib/your-gem.rb [Ruby 補完]
  └─ test/ [テスト]
    ↓
lib/mruby/gem.rb でビルド統合
  ├─ コンパイル: src/*.c
  ├─ リンク: 依存オブジェクト
  └─ テスト実行
```

---

## 構造体・関数の読み順ガイド

### 値表現 (Value Boxing)

```
1. include/mruby/value.h
   ├─ typedef mrb_value
   ├─ enum mrb_vtype (type tag)
   └─ mrb_type(), mrb_ptr() マクロ
    ↓
2. include/mruby/boxing_*.h
   ├─ boxing_nan.h (NaN boxing)
   ├─ boxing_word.h (Word boxing)
   └─ boxing_no.h (No boxing)
    ↓
3. src/value_array.h
   └─ 値配列の実装
```

### クラス・オブジェクト

```
1. include/mruby/class.h
   ├─ struct RClass
   └─ mrb_class_new()
    ↓
2. src/class.c
   ├─ mrb_define_class()
   ├─ mrb_define_method()
   └─ find_method()
    ↓
3. src/object.c
   ├─ mrb_obj_new()
   └─ インスタンス変数管理
```

### VM 実行

```
1. include/mruby/opcode.h
   ├─ enum mrb_code (オペコード)
   └─ 各 OP_* マクロ定義
    ↓
2. src/vm.c
   ├─ mrb_vm_exec() [メインループ]
   ├─ オペコード処理
   └─ スタックフレーム管理
    ↓
3. src/load.c
   ├─ Ruby ロード
   └─ .mrb ロード
```

### GC

```
1. include/mruby/gc.h
   ├─ struct mrb_gc
   └─ GC API
    ↓
2. src/gc.c
   ├─ mrb_gc_mark() [Mark フェーズ]
   ├─ mrb_gc_sweep() [Sweep フェーズ]
   └─ mrb_gc_arena_*() [Arena]
    ↓
3. src/*.c
   └─ 各型で mrb_data_mark() 実装
```

---

## コード読了チェックリスト

- [ ] README.md を読んだ（プロジェクト概要）
- [ ] include/mruby.h を読んだ（API 概要）
- [ ] include/mruby/internal.h を読んだ（構造体定義）
- [ ] src/vm.c を読んだ（VM 基本）
- [ ] src/gc.c を読んだ（GC 基本）
- [ ] src/class.c を読んだ（クラスシステム）
- [ ] src/array.c または src/hash.c を読んだ（標準型）
- [ ] mrbgems/mruby-bin-mruby/tools/mruby/mruby.c を読んだ（エントリーポイント）
- [ ] mrbgems/mruby-compiler を調査した（コンパイラ）
- [ ] test/t/array.rb または test/t/hash.rb を読んだ（テスト例）
- [ ] build_config/default.rb を読んだ（ビルド設定）
- [ ] Rakefile と lib/mruby/build.rb を読んだ（ビルドシステム）

---

**次のステップ**:
- DEVELOPMENT_GUIDE.md で開発環境構築を学ぶ
- 実際にビルド・テストを実行する
- 小規模な機能追加で理解を深める
