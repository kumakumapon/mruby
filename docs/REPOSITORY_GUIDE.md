# mruby Repository Guide

## 1. 一言でいうと

**mruby** は Ruby 言語の軽量実装で、組み込みシステムや IoT デバイス、エッジコンピューティング向けに設計された C言語で実装された Ruby インタプリタです。通常の Ruby よりもメモリフットプリントが小さく、バイトコードにコンパイル可能で、C アプリケーションに埋め込むことができます。

## 2. このシステムが解決する問題

- **メモリ制限環境での Ruby 実行**: 組み込みシステム、マイコン、IoT デバイス上で Ruby スクリプトを実行したい
- **C/C++ との統合**: C/C++ 実装をホストアプリケーションに埋め込み、Ruby で拡張・制御したい
- **ポータビリティ**: 複数のプラットフォーム（Linux、macOS、Windows、Arduino、Nintendo Switch など）で同じ Ruby コードを実行したい
- **パフォーマンス**: 標準 Ruby より高速な実行やコンパイル済みバイナリ化による実行高速化

## 3. 主な利用者

- 組み込みシステム開発者（マイコン、IoT、センサーデバイス）
- ゲーム開発者（ゲームロジックのスクリプト化）
- C/C++ エンジニア（スクリプティング機能の追加）
- ルーテッドやロボット制御のプログラマー
- Linux カーネルモジュール開発者（カーネル空間での Ruby スクリプト実行）

## 4. 主な機能

| 機能 | 説明 |
|------|------|
| **Ruby 4.x 互換インタプリタ** | Ruby 4.x の構文とセマンティクスに準拠、ISO 15.3 標準に対応 |
| **バイトコード コンパイル** | `mrbc` により Ruby スクリプトを .mrb (RiteBinary) 形式にコンパイル |
| **C API** | mruby_state を介して C/C++ から Ruby オブジェクトを操作可能 |
| **Gem パッケージ管理** | mrbgems による拡張ライブラリ（C/Ruby 混在可能） |
| **対話シェル** | `mirb` により REPL 環境を提供 |
| **デバッガ** | `mrdb` によるステップ実行、ブレークポイント設定 |
| **クロスコンパイル対応** | 複数プラットフォーム向けビルド設定を持つ |
| **単一ファイル化** | Amalgamation により mruby.c と mruby.h の単一ファイルに統合可能 |

## 5. システム全体像

```
┌─────────────────────────────────────────────────────────────┐
│                    ホストアプリケーション                    │
│  (C/C++ で実装、mruby ライブラリをリンク)                    │
└────────────┬────────────────────────────────────────────────┘
             │ C API (mrb_open, mrb_load, etc.)
┌────────────▼────────────────────────────────────────────────┐
│                   mruby インタプリタ                          │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  src/vm.c - 仮想マシン (レジスタベース)               │   │
│  │  src/gc.c - ガベージコレクション (mark & sweep)       │   │
│  │  src/class.c - クラス/モジュールシステム             │   │
│  │  src/array.c, hash.c, string.c - 基本クラス実装    │   │
│  └──────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  mrblib/ - Ruby で実装されたメソッド (loop, enum等)  │   │
│  │  mrbgems/ - 拡張ライブラリ                           │   │
│  └──────────────────────────────────────────────────────┘   │
└────────────┬────────────────────────────────────────────────┘
             │ 実行
      ┌──────▼──────────────────────┐
      │  Ruby スクリプト (.rb/.mrb)  │
      └──────────────────────────────┘
```

## 6. 使用技術

| 分類 | 技術 | このプロジェクトでの役割 |
|------|------|--------|
| **実装言語** | C99 | コア VM、GC、標準クラス実装 |
| **スクリプト言語** | Ruby | 標準メソッド、テストケース記述 |
| **ビルドシステム** | Rake（Ruby） | ビルド、テスト、ドキュメント生成 |
| **パーサー** | Prism (C言語) | Ruby コードの構文解析、AST 生成 |
| **コンパイラ** | mruby-compiler | Ruby → バイトコード (IREP) コンパイル |
| **ドキュメント** | YARD | C/Ruby API ドキュメント生成 |
| **CI/CD** | GitHub Actions | 複数OS/コンパイラでの自動テスト |
| **コード品質** | prek (pre-commit hook) | リント、フォーマット、YAML 検証 |
| **ファジング** | libFuzzer (OSS-Fuzz) | セキュリティテスト |

## 7. ディレクトリ構成

```
mruby/
├── src/                    # コア実装（C）
│   ├── vm.c               # 仮想マシン、実行エンジン
│   ├── gc.c               # ガベージコレクション
│   ├── class.c            # クラス・モジュール
│   ├── array.c, hash.c    # 基本データ構造
│   ├── string.c           # 文字列実装
│   ├── numeric.c          # 数値型
│   ├── object.c           # オブジェクト基盤
│   ├── kernel.c           # Kernel メソッド
│   ├── error.c            # 例外処理
│   └── ...                # その他モジュール
├── include/               # ヘッダファイル
│   ├── mruby.h            # メインAPI
│   ├── mruby/             # サブディレクトリ
│   │   ├── value.h        # 値表現（Boxing戦略）
│   │   ├── object.h       # オブジェクト構造
│   │   ├── gc.h           # GC インタフェース
│   │   ├── compile.h      # コンパイル API
│   │   ├── array.h, hash.h, string.h
│   │   └── ...
│   └── mrbconf.h          # ビルド時設定
├── mrblib/                # Ruby 実装（スタンダードライブラリ）
│   ├── array.rb, hash.rb  # 基本クラスメソッド
│   ├── enum.rb            # Enumerable 実装
│   ├── string.rb          # String メソッド
│   ├── kernel.rb          # Kernel モジュール
│   └── ...
├── mrbgems/               # 拡張ライブラリシステム
│   ├── default.gembox     # デフォルト Gem セット
│   ├── stdlib/            # 標準ライブラリ Gem
│   ├── mruby-bin-*/       # バイナリツール Gem
│   │   ├── mruby-bin-mruby/   # mruby インタプリタ
│   │   ├── mruby-bin-mrbc/    # mrbc コンパイラ
│   │   ├── mruby-bin-mirb/    # mirb REPL シェル
│   │   └── mruby-bin-debugger/ # mrdb デバッガ
│   ├── mruby-compiler/    # コンパイラ Gem
│   ├── mruby-io/          # I/O Gem
│   ├── mruby-fiber/       # ファイバー実装
│   └── ...
├── lib/mruby/             # ビルドシステム（Ruby）
│   ├── build.rb           # ビルド設定・実行
│   ├── gem.rb             # Gem 管理システム
│   ├── amalgam.rb         # 単一ファイル化
│   └── ...
├── build_config/          # ビルド設定ファイル
│   ├── default.rb         # デフォルト設定
│   ├── host-*.rb          # ホストビルド
│   ├── cross-*.rb         # クロスコンパイル
│   ├── ci/                # CI 用設定
│   └── ...
├── tasks/                 # Rake タスク
│   ├── core.rake          # コアビルド
│   ├── mrbgems.rake       # Gem ビルド
│   ├── bin.rake           # バイナリビルド
│   ├── test.rake          # テスト
│   └── ...
├── test/                  # テスト
│   ├── t/                 # 個別テストケース（Ruby）
│   │   ├── array.rb, hash.rb, string.rb
│   │   └── ...            # 47+ テストファイル
│   ├── assert.rb          # テストフレームワーク
│   └── bintest.rb         # バイナリテスト
├── examples/              # 使用例
├── doc/                   # ドキュメント
│   ├── guides/            # ガイド類
│   │   ├── capi.md        # C API
│   │   ├── compile.md     # ビルド方法
│   │   ├── mrbgems.md     # Gem 開発
│   │   └── ...
│   └── internal/          # 内部実装資料
├── tools/                 # ビルドツール
├── .github/               # GitHub設定
│   └── workflows/         # CI/CD
└── Makefile, Rakefile, ...  # ビルド定義
```

## 8. 起動から動作開始まで

### 8.1 ビルド

```bash
# 基本的なビルド
rake all

# テスト付きビルド
rake all test

# 特定のビルド設定を使用
MRUBY_CONFIG=debug rake

# Docker で実行
docker-compose run test
```

### 8.2 起動フロー

**mruby インタプリタの起動**：

```
$ mruby script.rb
  ↓
mrbgems/mruby-bin-mruby/tools/mruby/mruby.c:main()
  ↓
mrb_open() - mruby_state 初期化（GC、クラスシステム、VM）
  ↓
parse_args() - コマンドライン引数解析（-e, -b, -c, -r など）
  ↓
ARGVグローバル定数設定
  ↓
-r オプションでライブラリをロード
  ↓
スクリプトをコンパイル & 実行
  ↓
mrb_close() - クリーンアップ・メモリ解放
  ↓
終了
```

### 8.3 C からの組み込み

```c
#include <mruby.h>
#include <mruby/compile.h>

int main() {
  // mruby_state を開く
  mrb_state *mrb = mrb_open();
  
  // Ruby コードを実行
  const char *code = "puts 'Hello'";
  mrb_load_string(mrb, code);
  
  // クローズ
  mrb_close(mrb);
}
```

## 9. 主要ユースケース

| ユースケース | エントリーポイント | 主要モジュール | 説明 |
|------------|------------|------------|------|
| **Ruby スクリプト実行** | mruby.c:main() | src/vm.c, src/load.c | コマンドラインから .rb スクリプトを実行 |
| **バイトコード実行** | mruby.c:main(-b) | src/load.c, src/dump.c | コンパイル済み .mrb ファイルを実行 |
| **対話型実行** | mirb.c | src/vm.c, src/compile.c | REPL シェルで Ruby コードを実行 |
| **C から Ruby 呼び出し** | C API: mrb_funcall() | include/mruby.h | C/C++ コードから Ruby メソッドを呼び出し |
| **Ruby から C 呼び出し** | mrbgem.rake | lib/mruby/gem.rb | Gem 内の C 関数を Ruby から呼び出し |
| **バイトコード生成** | mrbc.c:main() | src/compile.c | Ruby スクリプトを .mrb にコンパイル |
| **スクリプト検証** | mruby.c:main(-c) | src/compile.c | Ruby スクリプトの文法チェック |
| **クラス定義・拡張** | src/class.c | include/mruby/class.h | C から Ruby クラスを定義・拡張 |
| **文字列・配列操作** | src/string.c, src/array.c | include/mruby/value.h | Ruby オブジェクトの生成・操作 |
| **例外処理** | src/error.c | include/mruby/error.h | Ruby 例外のスロー・キャッチ |

## 10. データの流れ

```
┌─────────────────┐
│  入力ソース      │
│ (Ruby .rb) │
└────────┬────────┘
         │
    ┌────▼──────────────────────────┐
    │ コンパイル                      │
    │ (Prism → AST → バイトコード)   │
    │ src/compile.c, mrbgems/        │
    │ mruby-compiler/                │
    └────┬───────────────────────────┘
         │
    ┌────▼──────────────────────────┐
    │ IREP (中間表現)                │
    │ 実行可能なバイトコード          │
    │ (src/dump.c で保存可能)        │
    └────┬───────────────────────────┘
         │
    ┌────▼──────────────────────────┐
    │ 仮想マシン実行                  │
    │ src/vm.c - レジスタ VM         │
    │ (GC、メモリ管理)               │
    └────┬───────────────────────────┘
         │
    ┌────▼──────────────────────────┐
    │ Ruby オブジェクト             │
    │ (Array, Hash, String等)       │
    │ ヒープに格納                    │
    │ (GC: src/gc.c)                 │
    └────┬───────────────────────────┘
         │
    ┌────▼──────────────────────────┐
    │ C API 経由での操作             │
    │ (ホストアプリケーション)       │
    └──────────────────────────────┘
```

## 11. 外部サービス

### 11.1 直接の外部依存

mruby はコアに直接の外部サービス依存がありません。ただし、**Gem** を通じて以下の機能を追加可能：

- **mruby-io**: ファイルI/O、パイプ等
- **mruby-socket**: ネットワークソケット（別 Gem）
- **mruby-json**: JSON パース（別 Gem）
- **mruby-uri**: URI パース（別 Gem）

### 11.2 組込先アプリケーション次第

mruby が埋め込まれるホストアプリケーションの機能に依存：

- ファイルシステム
- ネットワーク
- DB アクセス
- グラフィックス、I/O

これらは Gem や C API を通じて拡張される。

## 12. 設定・環境変数

### 12.1 ビルド時設定

| 環境変数/設定 | 用途 | デフォルト |
|-------------|------|--------|
| `MRUBY_CONFIG` | ビルド設定ファイル選択 | build_config/default.rb |
| `CC` | C コンパイラ | gcc |
| `CXX` | C++ コンパイラ | g++ |
| `LD` | リンカ | gcc |
| `CFLAGS` | C コンパイルフラグ | 空 |
| `LDFLAGS` | リンカフラグ | 空 |
| `MRB_COMPILER_PRISM` | Prism コンパイラ使用 | no |

### 12.2 実行時設定（build_config 内）

**build_config/*.rb** で指定:

- `conf.cc` - コンパイラ設定
- `conf.linker` - リンカ設定
- `conf.archiver` - アーカイバ設定
- `conf.gembox` - Gem セット選択
- `conf.gem` - 個別 Gem 追加
- `conf.enable_debug` - デバッグ情報
- `conf.enable_test` - テスト有効化

### 12.3 コンパイル時マクロ

| マクロ | 効果 | 用途 |
|-------|------|------|
| `MRB_GC_STRESS` | 全アロケーション時に GC | メモリリークテスト |
| `MRB_USE_DEBUG_HOOK` | デバッグフック有効 | デバッガ対応 |
| `MRB_GC_FIXED_ARENA` | GC Arena を固定 | リアルタイムシステム |
| `MRB_NO_STDIO` | stdio なしビルド | 組込システム |
| `MRB_NO_GEMS` | Gem 機能無効 | 最小構成 |

## 13. テスト

### 13.1 テスト実行

```bash
# 全テスト実行
rake test

# 特定の Gem のテスト
rake test:mruby-array

# バイナリテスト
rake bintest
```

### 13.2 テスト構成

| テスト種別 | 場所 | 内容 | 実行コマンド |
|----------|------|------|----------|
| **ユニット** | test/t/*.rb | クラス/モジュール毎のテスト | rake test |
| **バイナリ** | mrbgems/*/bintest/ | コマンドラインツール | rake bintest |
| **統合** | test/t/ | 複数モジュール連携 | rake test |
| **Fuzz** | oss-fuzz/ | セキュリティテスト | GitHub Actions |
| **カバレッジ** | (自動計測) | コードカバレッジ | GitHub Actions |

### 13.3 テストフレームワーク

**test/assert.rb** で定義：

```ruby
assert('説明', 'ISO標準番号') do
  assert_true(condition)
  assert_equal(expected, actual)
  assert_raise(ExceptionClass) { ... }
end
```

## 14. 変更時の注意点

### 14.1 新しい API を追加する場合

1. `include/mruby.h` または `include/mruby/*.h` に宣言を追加
2. 実装を `src/*.c` に追加
3. テストを `test/t/*.rb` に追加
4. ドキュメント `doc/guides/capi.md` を更新

### 14.2 新しいメソッドを追加する場合

1. **C実装**: `src/*.c` に `mrb_define_method()` で登録
2. **Ruby実装**: `mrblib/*.rb` でメソッドを定義
3. テストを `test/t/*.rb` に追加

### 14.3 Gem を追加する場合

1. `mrbgems/your-gem/` を作成
2. `mrbgem.rake` にビルド定義を記述
3. `build_config/*.rb` で有効化
4. テストを `mrbgems/your-gem/test/` に記述

### 14.4 クロスプラットフォーム対応

- 各プラットフォーム向けに `build_config/*.rb` を作成
- CI で複数プラットフォームでビルド・テスト（.github/workflows/build.yml）
- プラットフォーム固有コードは `#ifdef` で制御

## 15. 用語集

| 用語 | 説明 |
|------|------|
| **mruby_state** | Ruby インタプリタのグローバル状態。メモリ、GC、クラスシステムを保持 |
| **IREP** | Intermediate Representation（中間表現）。バイトコード形式 |
| **RiteBinary** | .mrb ファイル形式。コンパイル済み IREP |
| **Gem / mrbgem** | mruby の拡張パッケージ。C/Ruby 混在可能 |
| **Boxing** | オブジェクトポインタと値を統一表現すること（NaN boxing等） |
| **GC Arena** | GC 保護領域。C API から確保したオブジェクトを GC から保護 |
| **Mark & Sweep** | GC アルゴリズム。マーク フェーズで参照を辿り、スイープフェーズで未使用メモリを回収 |
| **Presym** | Pre-allocated Symbols。シンボル管理の最適化 |
| **Amalgamation** | 単一ファイル化。全ソースを mruby.c, mruby.h に統合 |
| **Toolchain** | コンパイラ、リンカ、アーカイバ等のツール設定 |

## 16. 不明点・確認が必要なこと

### 推測/確認が必要な項目

1. **メモリ管理アルゴリズムの詳細** - GC の詳細なスケジュール、並行 GC の有無
   - 確認先: doc/guides/gc-arena-howto.md, src/gc.c

2. **パフォーマンス最適化手法** - JIT コンパイルの有無、最適化レベル
   - 確認先: build_config/default.rb, NEWS.md

3. **プラットフォーム固有の実装** - 各プラットフォーム向けのカスタマイズ詳細
   - 確認先: build_config/ 内の各設定ファイル

4. **セキュリティ境界** - サンドボックス化の程度、制限
   - 確認先: SECURITY.md, doc/limitations.md

5. **後方互換性ポリシー** - API 変更時の互換性保証
   - 確認先: CONTRIBUTING.md, NEWS.md

---

**次のステップ**：
- ARCHITECTURE.md で詳細なシステムアーキテクチャを確認
- CODE_READING_GUIDE.md でコード読み順を理解
- DEVELOPMENT_GUIDE.md で開発環境の構築方法を習得
