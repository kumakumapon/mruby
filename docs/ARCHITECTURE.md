# mruby Architecture

## System Context Diagram

```
┌────────────────────────────────────────────────────────────────┐
│                      External World                             │
│  (File System, Network, OS, Host Application)                  │
└────────────────────────────────────────────────────────────────┘
                              △
                              │ (File I/O, System Calls, Linking)
                              │
┌────────────────────────────────────────────────────────────────┐
│                          mruby VM                               │
│                    (C言語 + Ruby実装)                           │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │ Public C API: include/mruby.h                            │  │
│  │ - mrb_open/mrb_close: ライフサイクル                    │  │
│  │ - mrb_load_string: Rubyコードロード                     │  │
│  │ - mrb_funcall: メソッド呼び出し                         │  │
│  │ - mrb_define_class/method: クラス・メソッド定義        │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │ Runtime Layer (src/)                                     │  │
│  │                                                           │  │
│  │  ┌─────────────────────────────────────────────────┐   │  │
│  │  │ VM Core (vm.c)                                  │   │  │
│  │  │ - レジスタベース仮想マシン                       │   │  │
│  │  │ - バイトコード実行エンジン                       │   │  │
│  │  │ - スタック・コンテキスト管理                     │   │  │
│  │  └──┬───────────────────────────────────────────┬──┘   │  │
│  │     │                                           │       │  │
│  │  ┌──▼──────────────────┐   ┌──────────────────▼──┐    │  │
│  │  │ GC (gc.c)           │   │ Class System        │    │  │
│  │  │ - Mark & Sweep      │   │ (class.c)           │    │  │
│  │  │ - Arena管理         │   │ - クラス・モジュール │    │  │
│  │  │ - Finalization      │   │ - インスタンス変数   │    │  │
│  │  └─────────────────────┘   │ - メソッド解決       │    │  │
│  │                             └────────────────────┘    │  │
│  │                                                         │  │
│  │  ┌──────────────────────────────────────────────┐    │  │
│  │  │ Standard Types (array.c, hash.c, string.c)   │    │  │
│  │  │ - Array, Hash, String, Symbol, Numeric      │    │  │
│  │  │ - Range, Proc, Time                          │    │  │
│  │  └──────────────────────────────────────────────┘    │  │
│  │                                                         │  │
│  │  ┌──────────────────────────────────────────────┐    │  │
│  │  │ Core Modules (kernel.c, object.c, error.c)  │    │  │
│  │  │ - Kernel, Object, Enumerable, Comparable    │    │  │
│  │  │ - Exception handling, Error reporting       │    │  │
│  │  └──────────────────────────────────────────────┘    │  │
│  │                                                         │  │
│  │  ┌──────────────────────────────────────────────┐    │  │
│  │  │ Compiler & Parser (mrbgems/mruby-compiler) │    │  │
│  │  │ - Prism Parser (C) → AST                     │    │  │
│  │  │ - Code Generation → Bytecode (IREP)         │    │  │
│  │  │ - Symbol management (presym.rb)             │    │  │
│  │  └──────────────────────────────────────────────┘    │  │
│  │                                                         │  │
│  │  ┌──────────────────────────────────────────────┐    │  │
│  │  │ Standard Library (mrblib/*.rb)               │    │  │
│  │  │ - Array#each, Hash#map, String methods      │    │  │
│  │  │ - Enumerable, Comparable実装                │    │  │
│  │  └──────────────────────────────────────────────┘    │  │
│  │                                                         │  │
│  │  ┌──────────────────────────────────────────────┐    │  │
│  │  │ Extension System (lib/mruby/gem.rb)          │    │  │
│  │  │ - Gem management, linker_attrs               │    │  │
│  │  │ - C/Ruby mixed extensions                    │    │  │
│  │  └──────────────────────────────────────────────┘    │  │
│  └─────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────┘
                              △
                              │
                              │ (Ruby Scripts, C Functions)
                              │
                ┌─────────────┴──────────────┐
                │                            │
       ┌────────▼─────────┐        ┌────────▼─────────┐
       │ Ruby Programs    │        │ C Programs       │
       │ (.rb / .mrb)     │        │ (Embedding)      │
       └──────────────────┘        └──────────────────┘
```

## Core Components

### 1. Virtual Machine (src/vm.c)

**責務**：Ruby バイトコード実行エンジン

```
入力: IREP (Intermediate Representation)
  ↓
バイトコード(mrb_code) の逐次実行
  ↓
レジスタ vm->regs[] を使用
  ↓
スタックフレーム management (ci: call info)
  ↓
出力: Ruby 値 (mrb_value)
```

**主要関数**：

- `mrb_vm_exec()` - メインループ（バイトコード実行）
- `mrb_funcall()` - メソッド呼び出し
- `mrb_yield()` - ブロック実行
- `OP_JMP, OP_JMPIF, OP_JMPNOT` - 条件分岐

**データ構造** (include/mruby/value.h):

```c
typedef mrb_int mrb_code;           // バイトコード
typedef uint32_t mrb_aspec;         // 引数仕様
struct mrb_context {                // 実行コンテキスト
  mrb_value *stack;                 // レジスタ
  mrb_callinfo *ci;                 // 呼び出し情報
  // ...
};
```

### 2. Garbage Collector (src/gc.c)

**責務**：メモリ自動管理

```
確保: mrb_malloc() → ヒープブロック
  ↓
参照: 変数・スタック
  ↓
[GC トリガ]
  ↓
Mark フェーズ: 参照可能なオブジェクトをマーク
  ↓
Sweep フェーズ: 未マークオブジェクトを回収
  ↓
Arena: 確保したオブジェクトを一時保護
```

**GC 戦略**：

- **Mark & Sweep**: 世代別 GC ではなく、全体スイープ
- **Arena 保護**: C API で確保したオブジェクトを GC から保護
- **MRB_GC_STRESS**: テスト用、毎アロケーションで GC
- **MRB_GC_FIXED_ARENA**: リアルタイム向け、Arena サイズ固定

**主要 API**:

```c
mrb_gc_arena_save(mrb)           // Arena ポイント保存
mrb_gc_arena_restore(mrb, idx)   // Arena ポイント復元
mrb_malloc(mrb, size)            // メモリ確保
mrb_free(mrb, ptr)               // メモリ解放
```

### 3. Class System (src/class.c)

**責務**：オブジェクト指向サポート

```
Class 定義
  ├─ Methods: mrb_define_method()
  ├─ Class Variables
  ├─ Instance Variables
  └─ Inheritance Chain

Module
  ├─ Methods (Mixin)
  └─ Constants

Instance
  ├─ Class reference
  ├─ Instance variables (@var)
  └─ Data (C 構造体 or Ruby 値)
```

**データ構造** (include/mruby/class.h):

```c
struct RClass {
  struct RBasic basic;
  struct RClass *super;       // 親クラス
  struct RClass *iv_tbl;      // インスタンス変数テーブル
  struct RClass *mt;          // メソッドテーブル
  // ...
};

struct RObject {
  struct RBasic basic;
  struct RClass *c;           // クラス
  struct iv_tbl *iv;          // インスタンス変数
};
```

**メソッド解決**：

```
obj.method()
  ↓
obj->c (Class)
  ↓
Method Lookup: c->mt (Method Table)
  ↓
見つからない → c->super
  ↓
Method Not Found → NoMethodError
```

### 4. Standard Types

#### 4.1 Array (src/array.c)

- 動的配列（C の `mrb_value*`）
- `[], []=, <<, push, pop, each` 等

#### 4.2 Hash (src/hash.c)

- Khash（高速ハッシュテーブル、include/mruby/khash.h）
- キー・値: `mrb_value`
- `[], []=, keys, values, each` 等

#### 4.3 String (src/string.c)

- UTF-8 対応（src/unicase.c で大文字・小文字処理）
- Rope データ構造（コンパイルオプション）
- `[], []=, +, *, length, upcase, downcase` 等

#### 4.4 Numeric (src/numeric.c)

- `mrb_int` (fixnum, 通常 int32_t or int64_t)
- `mrb_float` (IEEE 754 double)
- `mrb_value` は Boxing で統一表現

#### 4.5 Symbol (src/symbol.c)

- Interned strings
- Presym による事前割り当て
- `mrb_intern()` でシンボル作成

#### 4.6 Range (src/range.c)

- `start..end` (inclusive)
- `start...end` (exclusive)

#### 4.7 Proc (src/proc.c)

- Lambda、Proc、ブロック
- 環境キャプチャ（Closure）

### 5. Compiler & Parser

**構成**：

```
Ruby Source (.rb)
  ↓ (Prism: mrbgems/mruby-compiler/core/mrbgems/mruby-compiler/ccontext.c)
Abstract Syntax Tree (AST)
  ↓ (codegen.c)
Bytecode (IREP: src/dump.c に定義)
  ↓ (Write as .mrb if requested)
RiteBinary (.mrb)
```

**主要クラス** (mrbgems/mruby-compiler):

- `mrb_parser_new()` - パーサー初期化
- `mrb_parse_string()` - コード解析
- `mrb_generate_code()` - コード生成
- `mrb_dump_irep()` - .mrb 出力

**IREP 構造** (include/mruby/irep.h):

```c
struct mrb_irep {
  uint8_t *iseq;              // バイトコード列
  mrb_irep **ireps;           // ネストされた IREP
  mrb_sym *syms;              // シンボルテーブル
  mrb_value *pool;            // リテラル値 (Constant pool)
  // ...
};
```

### 6. Standard Library (mrblib/)

Ruby で実装された拡張メソッド：

| ファイル | 内容 |
|---------|------|
| 10error.rb | Exception, NameError, NoMethodError |
| array.rb | Array#each, Array#map (部分) |
| enum.rb | Enumerable#each_with_index, select 等 |
| hash.rb | Hash#each, Hash#select 等 |
| string.rb | String#each_char, String#split 等 |
| compar.rb | Comparable モジュール |
| kernel.rb | Kernel#loop |

これらは C 実装のメソッドを補完し、Ruby で可読性高く実装。

### 7. Extension System (mrbgems)

**Gem 構造**：

```
mrbgems/your-gem/
├── mrbgem.rake           # ビルド定義
├── mrbgem.yml            # メタデータ
├── src/                  # C 実装
├── lib/                  # Ruby 実装
├── test/                 # テスト
├── tools/                # コマンドラインツール
└── bintest/              # バイナリテスト
```

**ビルド統合** (lib/mruby/gem.rb):

- Gem 依存性解決
- C/Ruby ファイルコンパイル
- リンク設定（linker_attrs）
- テスト統合

### 8. Tools (mrbgems/mruby-bin-*)

#### mruby (mruby-bin-mruby/tools/mruby/mruby.c)

- Ruby スクリプト実行
- コマンド引数: `-e`, `-b` (mrb実行), `-c` (チェック), `-r` (ライブラリロード)

#### mirb (mruby-bin-mirb)

- 対話型シェル (REPL)
- 各行をコンパイル・実行

#### mrbc (mruby-bin-mrbc)

- Ruby → .mrb (RiteBinary) コンパイル
- `-o` でファイル出力
- `-B` でバイナリ埋め込み用 C コード生成

#### mrdb (mruby-bin-debugger)

- デバッガ
- ステップ実行、ブレークポイント、ウォッチポイント

## Dependency Direction

```
User Code / C Program
  ↓
mruby.h (Public API)
  ↓
src/vm.c (Execution)
  ↑
src/gc.c (Memory)
  ↑
src/class.c (Object System)
  ↑
src/array.c, src/hash.c, ... (Types)
  ↑
mrblib/ (Standard Library)
  ↑
mrbgems/ (Extensions)
```

**循環依存なし**: クリーンな層状アーキテクチャ

## Runtime Flow: "Hello, World" Example

### Scenario: `mruby hello.rb`

```
1. mrbgems/mruby-bin-mruby/tools/mruby/mruby.c:main()
   ├─ mrb_open()
   │  ├─ mrb_state 割り当て
   │  ├─ GC 初期化 (src/gc.c:mrb_gc_init)
   │  ├─ Class System 初期化 (src/class.c)
   │  └─ VM 初期化
   │
   ├─ parse_args() - "hello.rb" を検出
   │
   ├─ mrb_load_detect_file_cxt()
   │  ├─ ファイルを開く
   │  ├─ Prism parser で AST 作成
   │  ├─ Code generation → IREP
   │  └─ src/vm.c:mrb_vm_exec() で実行
   │     ├─ OP_SEND: puts メソッド呼び出し
   │     ├─ OP_LOADCONST: "Hello, World" 文字列読み込み
   │     ├─ Stack: 値を積む
   │     └─ Return: 結果をレジスタに格納
   │
   └─ mrb_close()
      ├─ 全オブジェクトをマーク
      ├─ GC sweep
      └─ メモリ解放

2. Output: "Hello, World"
```

### Scenario: C から Ruby メソッド呼び出し

```c
mrb_state *mrb = mrb_open();

// Ruby クラス・メソッド定義
mrb_define_class(mrb, "MyClass", mrb->object_class);
mrb_define_method(mrb, mrb_class_get(mrb, "MyClass"),
                  "hello", c_hello, MRB_ARGS_NONE());

// Ruby コード実行
mrb_load_string(mrb, "obj = MyClass.new; obj.hello");

mrb_close(mrb);
```

**Flow**:

```
C: mrb_define_method()
  ↓
Class System: メソッドテーブル登録
  ↓
Ruby: obj.hello
  ↓
VM: メソッド解決 → c_hello() (C 関数)
  ↓
C: c_hello() 実行 → 結果を mrb_value で返す
  ↓
Ruby: 結果を取得
```

## Data Flow

### 1. Value Representation (include/mruby/value.h)

**Boxing Strategy**:

mruby は複数の Boxing 戦略をサポート：

- **Word Boxing**: ポインタと値を統一（1 word）
  - 上位ビット: type tag
  - 下位ビット: value or pointer

- **NaN Boxing**: IEEE 754 double の NaN を活用
  - NaN 値を type tag として利用
  - float と pointer を区別

```c
typedef uint64_t mrb_value;  // Word boxing の例

#define mrb_type(v) (enum mrb_vtype)((v).w >> MRB_VSHIFT)
#define mrb_ptr(v) ((void*)((v).p & ~MRB_IMMEDIATE_MASK))
```

### 2. Object Allocation

```
Request: mrb_obj_alloc(mrb, type, c)
  ↓
GC Check: gc->live_size > gc->threshold ?
  ├─ YES → Mark & Sweep → memory reclaim
  └─ NO → 続行
  ↓
malloc(): ヒープ割り当て
  ↓
Initialize: struct RBasic
  ├─ tt (type tag)
  ├─ c (class pointer)
  └─ flags
  ↓
Return: mrb_obj (wrapped in mrb_value)
```

### 3. Method Call Chain

```
Ruby: obj.method(arg1, arg2)
  ↓
VM: OP_SEND (Bytecode)
  ↓
src/vm.c:mrb_vm_exec()
  ├─ mrb_funcall()
  ├─ Method resolution:
  │  ├─ obj->c (Class)
  │  ├─ Method Lookup
  │  └─ Proc:
  │     ├─ RUBY_METHOD: Ruby メソッド → IREP 実行
  │     └─ MRB_METHOD_CFUNC: C 関数 → ダイレクト実行
  │
  ├─ Arguments push onto stack
  ├─ New Call Frame (mrb_callinfo)
  ├─ Execute (IREP or C)
  └─ Return (stack pop, register に格納)
```

## Database / Persistence

mruby はコアに DB 機能がない。

**Persistence 方法**:

1. **RiteBinary (.mrb)**: Compiled Bytecode
   - `mrbc` で Ruby → .mrb
   - `mruby -b script.mrb` で実行
   - Binary Persistence: src/dump.c

2. **Serialization (Gem)**: ユーザー定義
   - JSON Gem で serialize
   - File I/O Gem でディスク保存

3. **データベース (Gem)**:
   - SQLite, Redis 等の Gem で統合

## External Integrations

### 1. C/C++ Embedding

```c
#include <mruby.h>
#include <mruby/compile.h>

int main() {
  mrb_state *mrb = mrb_open();
  
  // Ruby コード実行
  mrb_load_string(mrb, "puts 42");
  
  // C データ ↔ Ruby
  mrb_value ruby_hash = mrb_hash_new(mrb);
  mrb_hash_set(mrb, ruby_hash, mrb_str_new_cstr(mrb, "key"),
               mrb_fixnum_value(123));
  
  mrb_close(mrb);
}
```

### 2. Gem Integration

Gem で外部ライブラリを統合：

```
C Library (e.g., SQLite)
  ↓ (Gem wrapping)
mruby-sqlite (Gem)
  ↓
C API: mrb_define_method()
  ↓
Ruby: db.execute("SELECT *")
```

### 3. File I/O

- mruby-io Gem: File クラス
- Low-level: fopen(), fread() (C stdlib)

### 4. Network

- mruby-socket Gem (別途インストール)
- socket(), bind(), connect() 等

### 5. Scripting Host

Host Application が mruby を埋め込み：

```
Host App (C/C++)
  ├─ Script 管理 (Ruby)
  ├─ Data 共有 (mrb_value ↔ C struct)
  └─ Event Loop 統合
```

## Authentication / Authorization

mruby コアにセキュリティ機構なし。

**Sandbox化**: Gem で実装可能

- Ruby コード実行時の制限
- Global 変数・定数アクセス制限
- 危険なメソッド呼び出し禁止

## Error Handling

### 1. Ruby 例外

```c
// Ruby コードから:
raise StandardError.new("message")

// C API から:
mrb_raise(mrb, E_RUNTIME_ERROR, "message");
```

### 2. Exception Structure (src/error.c)

```c
struct RException {
  struct RObject obj;
  mrb_value message;       // 例外メッセージ
  mrb_value backtrace;    // スタックトレース
};
```

### 3. Try-Catch in Ruby

```ruby
begin
  risky_operation()
rescue StandardError => e
  puts "Error: #{e.message}"
ensure
  cleanup()
end
```

### 4. Exception Propagation

```
C API: mrb_funcall(mrb, obj, method, ...)
  ↓
mrb->exc が設定される (例外発生時)
  ↓
呼び出し元で if (mrb->exc) チェック
  ↓
Error handling or propagate
```

## Async / Queue / Event Processing

mruby コアに async 機構なし。

### 1. Fiber (Generator)

mrbgems/mruby-fiber で Coroutine：

```ruby
f = Fiber.new do |x|
  puts "Got: #{x}"
  Fiber.yield x * 2
end

f.resume(10)  # "Got: 10" → 20
```

### 2. Host での非同期処理

ホストアプリケーションが Event Loop を管理：

```
Host Event Loop
  ├─ Timer Callback → Ruby コード実行
  ├─ I/O Event → Ruby callback
  └─ Thread → Ruby script in thread
```

### 3. No Built-in Threading

mruby コアにスレッドなし（GVL のような概念もなし）。

別 Gem で Pthread 統合が可能。

## Deployment Architecture

### 1. Standalone

```
mruby (executable)
  ├─ static: src/ をスタティックリンク
  └─ dynamic: libmruby.so をリンク
     ↓
Host System (Linux/macOS/Windows)
```

### 2. Embedded

```
Host C Application
  ├─ Link: libmruby.a (static)
  └─ Ruby scripts (bundled)
     ↓
Embedded System (Arduino/Raspberry Pi/IoT)
```

### 3. Amalgamation (Single-file)

```
rake amalgam
  ↓
build/host/amalgam/
  ├─ mruby.c (全ソース統合)
  └─ mruby.h
     ↓
gcc -o app app.c ./build/host/amalgam/mruby.c
     ↓
Standalone Binary
```

### 4. Docker Deployment

```
Dockerfile
  ├─ mruby build
  ├─ Ruby scripts copy
  └─ mruby interpreter as CMD
     ↓
Docker image (lean container)
```

## Architectural Constraints

### 1. Memory

- No reference counting: GC 依存
- 組込系ではメモリバジェット厳しい
- Arena 機構で Embedded C 使用時のメモリ管理

### 2. Performance

- No JIT: インタプリタのみ
- No lazily evaluated code
- Bytecode キャッシュ (.mrb) で性能向上

### 3. Language Features

- No Threads (core)
- No eval() (mruby-eval Gem 必須)
- No Reflection (限定的)
- No Module Refinement
- No Fiber (mruby-fiber Gem 必須)

### 4. Platform Dependencies

- C99 以上コンパイラ必須
- stdint.h, stddef.h 依存
- Optional: POSIX (unix.h)

### 5. API Stability

- Public API: include/mruby.h
- 後方互換性努力も、VM 内部は変更可能性あり
- Gem は Version に依存し易い

---

**参考資料**:
- src/vm.c: 仮想マシン実装（約 3000+ 行）
- src/gc.c: ガベージコレクション（約 500 行）
- include/mruby/internal.h: 内部データ構造定義（43KB）
- doc/guides/capi.md: C API ドキュメント
