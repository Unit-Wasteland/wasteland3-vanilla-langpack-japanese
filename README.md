# Wasteland 3 Japanese Language Pack (Vanilla)

Wasteland 3の非公式日本語化プロジェクトです。ゲームの全テキストを英語から日本語に翻訳し、日本のプレイヤーがこのポストアポカリプスRPGを楽しめるようにすることを目指しています。

[![Translation Progress](https://img.shields.io/badge/Progress-4%2C288%20entries-blue)]()
[![License](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc-sa/4.0/)

## 📊 プロジェクト概要

### ゲーム情報
- **ゲーム名**: Wasteland 3
- **開発元**: inXile Entertainment
- **対象バージョン**: v1.6.9.420.309496
- **翻訳対象**:
  - ベースゲーム: 530,425行
  - DLC1 (Battle of Steeltown): 120,559行
  - DLC2 (Cult of the Holy Detonation): 77,353行
  - **合計**: 約728,337行

### 翻訳進捗
- ✅ **完了エントリ数**: 4,288
- 📍 **現在のファイル**: StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0
- 🎯 **推定完了率**: 4-8%（ベースゲーム）
- 📅 **最終更新**: 2025年10月19日

## 🚀 完全自動化翻訳システム

このプロジェクトは、**Claude Code AI**を活用した完全自動翻訳システムを実装しています。

> **⚠️ 重要な警告 - 実験的機能**
>
> **完全自動化スクリプトは実験的な機能であり、重大なセキュリティリスクを伴います。**
>
> - 🔴 **`--dangerously-skip-permissions`フラグと`yes`コマンドを使用**
> - 🔴 **すべてのファイル操作権限を自動承認します**
> - 🔴 **誤動作時にシステムファイルを破壊する可能性があります**
>
> **自動化スクリプトの実行は、以下のすべてを理解しているユーザーのみが行ってください：**
> - ✅ Bashシェルスクリプトとパイプの動作原理
> - ✅ Git操作とバージョン管理の基礎
> - ✅ セキュリティリスクの評価と対処方法
> - ✅ サンドボックス環境の構築方法
>
> **🔰 初心者の方へ：**
> - 自動化スクリプトは使用せず、**「方法2: 手動翻訳」**を推奨します
> - Claude Codeを対話的に使用する方が安全です
> - わからないことがあれば、まず[Issues](https://github.com/Unit-Wasteland/wasteland3-vanilla-langpack-japanese/issues)で質問してください

### ✨ 特徴

**🤖 完全無人運転**
- ユーザーの介入なしで翻訳作業を継続
- 自動的にセッション再起動・メモリ管理
- 数日〜数週間の連続実行が可能

**🧠 AI駆動翻訳**
- Claude Sonnet 4.5による高品質な日本語翻訳
- ゲームコンテキストを理解した自然な訳文
- 用語統一のための自動グロッサリー管理

**💾 自動進捗管理**
- すべての変更を自動コミット・プッシュ
- セッション間で進捗を自動保持
- エラー回復・再開機能

**🛡️ 品質保証**
- ファイルフォーマットの厳密な検証
- 行数一致の自動チェック
- 中国語混入の自動検出・防止

## 🎮 クイックスタート

### 方法1: 完全自動翻訳（⚠️ 上級者向け）

> **🚨 セキュリティ警告: この方法を実行する前に上記の警告をよく読んでください**
>
> この方法は、**システム管理とセキュリティに関する十分な知識を持つ上級者専用**です。
> 不適切な使用はシステムの破壊やデータ損失につながる可能性があります。
>
> **推奨環境:**
> - 専用の仮想マシン（VM）またはコンテナ
> - サンドボックス環境
> - 本番システムやメインPCでは**絶対に実行しない**
>
> 初めての方は「**方法2: 手動翻訳**」を強く推奨します。

**前提条件:**
- [Claude Code](https://claude.com/claude-code) がインストール済み
- Git設定済み
- WSL/Linux環境またはWindows PowerShell

**ワンコマンド実行:**

```bash
# WSL/Linux環境
cd /path/to/wasteland3-vanilla-langpack-japanese
./automation/auto-translate.sh

# Windows PowerShell
cd C:\path\to\wasteland3-vanilla-langpack-japanese
.\automation\auto-translate.ps1
```

これだけで翻訳作業が完全自動で開始されます！

**オプション設定:**
```powershell
# 1セッションあたり500エントリずつ慎重に翻訳
.\automation\auto-translate.ps1 -EntriesPerSession 500 -MaxSessions 20

# メモリ閾値を5GBに設定
.\automation\auto-translate.ps1 -MaxMemoryMB 5000

# 長時間実行（最大100セッション）
.\automation\auto-translate.ps1 -MaxSessions 100
```

詳細は [`automation/README.md`](automation/README.md) を参照してください。

### 方法2: 手動翻訳（🔰 初心者推奨・安全）

**この方法の利点:**
- ✅ **各操作を手動で確認**できるため安全
- ✅ **学習しながら翻訳**に貢献できる
- ✅ **予期しない動作時に即座に停止**できる
- ✅ **サンドボックス環境が不要**（通常のPCで安全に実行可能）

```bash
# Claude Code起動
claude

# セッション内で以下を実行
translation/.translation_progress.json を読み込んで、CLAUDE.mdのルールに従って翻訳作業を継続してください。
```

Claude Codeが各操作（ファイル編集、Git操作など）を実行する前に確認を求めるため、
**初めての方でも安心して使用できます。**

詳細は [`translation/RESUME_TRANSLATION.md`](translation/RESUME_TRANSLATION.md) を参照してください。

## 📁 プロジェクト構造

```
wasteland3-vanilla-langpack-japanese/
├── README.md                          # このファイル（プロジェクト概要）
├── CLAUDE.md                          # Claude Code用の翻訳ガイドライン
│
├── translation/                       # 翻訳ファイルとリソース
│   ├── source/                        # ソース言語ファイル（参照専用）
│   │   └── v1.6.9.420.309496/
│   │       ├── en_US/                 # 英語テキスト
│   │       │   ├── StringTableData_English-CAB-*.txt
│   │       │   ├── DLC1/              # Battle of Steeltown DLC
│   │       │   └── DLC2/              # Cult of the Holy Detonation DLC
│   │       └── es_ES/                 # スペイン語（参考用）
│   │
│   ├── target/                        # 翻訳先ファイル（編集対象）
│   │   └── v1.6.9.420.309496/
│   │       └── ja_JP/                 # 日本語翻訳
│   │           ├── StringTableData_English-CAB-*.txt
│   │           ├── DLC1/
│   │           └── DLC2/
│   │
│   ├── nouns_glossary.json            # 固有名詞の用語集
│   ├── .translation_progress.json     # 翻訳進捗状態（自動生成）
│   └── RESUME_TRANSLATION.md          # 手動再開手順
│
├── automation/                        # 完全自動化スクリプト
│   ├── auto-translate.sh              # Bash版自動翻訳スクリプト
│   ├── auto-translate.ps1             # PowerShell版自動翻訳スクリプト
│   ├── README.md                      # 自動化システムの詳細ドキュメント
│   └── translation-automation.log     # 自動化実行ログ（自動生成）
│
└── .claude/                           # Claude Code設定
    ├── agents/
    │   └── wasteland3-translator.md   # 翻訳専用AIエージェント定義
    └── settings.local.json            # ローカル設定
```

## 🔧 技術詳細

### ファイルフォーマット

Wasteland 3はUnity StringTableフォーマットを使用しています：

```
MonoBehaviour:                          # Lines 1-9: メタデータ（変更禁止）
  string Filename = "mission_name"      # ミッション/ダイアログ識別子
  Array entryIDs                        # エントリIDリスト
    [0] int data = 12345
    [1] int data = 12346
  Array femaleTexts                     # 女性専用テキスト（多くは空）
    [0] string data = ""
    [1] string data = ""
  Array defaultTexts                    # メインの翻訳対象テキスト
    [0] string data = "Hello, Ranger."
    [1] string data = "Welcome to Colorado."
```

**重要なルール:**
- ✅ `string data = "..."` 内のテキストのみ翻訳
- ❌ ファイル構造、行数、IDは**絶対に**変更しない
- ✅ ソースと翻訳先の行数が完全一致する必要がある

### 翻訳ワークフロー

```
┌─────────────────────────────────────┐
│ 1. 用語集作成                        │
│    - 固有名詞を抽出                  │
│    - nouns_glossary.jsonに登録       │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ 2. 順次翻訳                          │
│    - ファイルの先頭から順番に翻訳    │
│    - 100-200行チャンクで処理         │
│    - 用語集を参照して一貫性を保持    │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ 3. 品質チェック                      │
│    - 行数の一致を確認                │
│    - 中国語文字の混入チェック        │
│    - フォーマットの検証              │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ 4. コミット・プッシュ                │
│    - 約1,000行ごとに自動コミット     │
│    - GitHubに自動プッシュ            │
└─────────────────────────────────────┘
```

### AIエージェントアーキテクチャ

```
┌────────────────────────────────────────────────────────┐
│ 自動化スクリプト (auto-translate.sh/ps1)                │
│  - セッション管理                                       │
│  - メモリ監視                                           │
│  - 自動再起動                                           │
└──────────────────────┬─────────────────────────────────┘
                       │ Claude Code stdin経由で指示
                       ▼
┌────────────────────────────────────────────────────────┐
│ Claude Code メインセッション                            │
│  - 進捗管理                                             │
│  - Git操作                                              │
│  - サブエージェント起動                                 │
└──────────────────────┬─────────────────────────────────┘
                       │ Task toolでサブエージェント起動
                       ▼
┌────────────────────────────────────────────────────────┐
│ wasteland3-translator サブエージェント                  │
│  - 実際の翻訳作業                                       │
│  - ファイル読み書き                                     │
│  - 用語集管理                                           │
│  - チャンク処理（メモリ分離）                           │
└────────────────────────────────────────────────────────┘
```

**メモリ管理の仕組み:**
- メインセッションは6-7GB到達で自動再起動
- サブエージェントはメモリ分離された環境で実行
- 進捗は`.translation_progress.json`に自動保存

## 📚 ドキュメント

### 主要ドキュメント
- [`CLAUDE.md`](CLAUDE.md) - Claude Code用の詳細な翻訳ガイドライン
- [`automation/README.md`](automation/README.md) - 自動化システムの完全ガイド
- [`translation/RESUME_TRANSLATION.md`](translation/RESUME_TRANSLATION.md) - 手動再開手順
- [`.claude/agents/wasteland3-translator.md`](.claude/agents/wasteland3-translator.md) - AIエージェント定義

### 翻訳ガイドライン

**禁止事項:**
- ❌ `Script Node`などの技術用語を翻訳しない
- ❌ `::action::`形式のアクションマークアップを変更しない
- ❌ 中国語（簡体字・繁体字）を使用しない
- ❌ ファイル構造や行数を変更しない

**推奨事項:**
- ✅ 用語集（nouns_glossary.json）を常に参照
- ✅ ポストアポカリプスRPGに適した自然な日本語
- ✅ キャラクターの口調・性格を反映
- ✅ ゲーム世界観に合った訳語選択

## 🤝 コントリビューション

現在、このプロジェクトは主にClaude Code AIによる自動翻訳で進行していますが、以下の貢献を歓迎します：

### 翻訳品質の向上
- 翻訳の校正・改善提案
- 用語集の追加・修正
- ゲーム専門用語の訳語提案

### 技術的改善
- 自動化スクリプトの改良
- 新しい品質チェック機能
- ドキュメントの改善

### 貢献方法
1. このリポジトリをフォーク
2. 変更をコミット
3. プルリクエストを作成

詳細は [CONTRIBUTING.md](CONTRIBUTING.md) を参照してください（今後作成予定）。

## 🐛 問題報告

翻訳の問題や技術的な不具合を発見した場合：

1. [GitHub Issues](https://github.com/Unit-Wasteland/wasteland3-vanilla-langpack-japanese/issues)で報告
2. 以下の情報を含めてください：
   - 問題の具体的な説明
   - 該当ファイル名と行番号（翻訳の場合）
   - 期待される動作と実際の動作

## 📈 進捗追跡

### 現在の翻訳状況

最新の進捗は以下で確認できます：

```bash
# 進捗ファイルを確認
cat translation/.translation_progress.json | jq

# 最近のコミットを確認
git log --oneline -20

# 自動化ログを確認（実行中の場合）
tail -f automation/translation-automation.log
```

### マイルストーン

- [x] プロジェクトセットアップ
- [x] 用語集作成
- [x] 自動化システム実装
- [x] a1001_* セクション完了（Ranger HQ関連）
- [ ] a2001_* セクション完了（Colorado Springs関連）
- [ ] ベースゲーム完了
- [ ] DLC1翻訳
- [ ] DLC2翻訳
- [ ] 全体の品質チェック
- [ ] リリース準備

## ⚖️ ライセンス

このプロジェクトは以下のライセンスの下で提供されています：

- **翻訳データ**: [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/)
- **ソースコード（スクリプト等）**: [MIT License](LICENSE)

**注意**: このプロジェクトは非公式のファンメイド翻訳です。Wasteland 3およびその関連コンテンツの権利はinXile EntertainmentおよびDeep Silverに帰属します。

## 🙏 謝辞

- **inXile Entertainment** - 素晴らしいゲームWasteland 3の開発
- **Claude AI (Anthropic)** - 高品質な翻訳を実現するAI技術
- **コミュニティ** - フィードバックと貢献

## 📞 連絡先

- **GitHubリポジトリ**: https://github.com/Unit-Wasteland/wasteland3-vanilla-langpack-japanese
- **Issues**: https://github.com/Unit-Wasteland/wasteland3-vanilla-langpack-japanese/issues

---

**🎮 Happy Gaming! / 楽しいゲーム体験を！**

このプロジェクトが、日本のWasteland 3プレイヤーの皆様に素晴らしいゲーム体験を提供できることを願っています。
