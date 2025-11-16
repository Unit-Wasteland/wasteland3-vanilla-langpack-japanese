# Wasteland 3 Japanese Language Pack (Vanilla)

Wasteland 3の非公式日本語化プロジェクトです。ゲームの全テキストを英語から日本語に翻訳し、日本のプレイヤーがこのポストアポカリプスRPGを楽しめるようにすることを目指しています。

[![Translation Progress](https://img.shields.io/badge/Base_Game-87.7%25-green)]()
[![Untranslated](https://img.shields.io/badge/Remaining-20%2C952_entries-orange)]()
[![License](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc-sa/4.0/)

## 📊 プロジェクト概要

### ゲーム情報
- **ゲーム名**: Wasteland 3
- **開発元**: inXile Entertainment
- **対象バージョン**: v1.6.9.420.309496
- **翻訳対象**:
  - ベースゲーム: 530,425行 (169,712エントリ)
  - DLC1 (Battle of Steeltown): 120,559行 (38,554エントリ)
  - DLC2 (Cult of the Holy Detonation): 77,353行 (24,152エントリ)
  - **合計**: 728,337行 (232,418エントリ)

### 翻訳進捗（2025年11月16日時点）

| 項目 | 進捗 | 状態 |
|------|------|------|
| **ベースゲーム** | 148,757 / 169,712 | 🟢 **87.7%** |
| 未翻訳エントリ | 20,952 残り | 🟡 自動修正中 |
| **DLC1** | 0 / 38,554 | ⏳ 未開始 |
| **DLC2** | 0 / 24,152 | ⏳ 未開始 |
| **合計進捗** | 148,757 / 232,418 | **64.0%** |

**現在の作業:**
- ✅ ベースゲーム本体の翻訳完了（87.7%）
- 🔄 **未翻訳エントリ修正中**（自動プロセス実行中）
- ⏳ DLC1/DLC2はベースゲーム完了後に開始

## 🚀 翻訳作業の開始方法

### 必要なもの
- [Claude Code](https://claude.com/claude-code) - AI翻訳エンジン
- Git - バージョン管理
- Linux/WSL環境（推奨）またはWindows PowerShell

### 方法1: 自動修正プロセス（推奨）

**現在実行中のタスク**: 検出された20,952個の未翻訳エントリを自動的に修正

#### クイックスタート

```bash
# 1. リポジトリをクローン
git clone https://github.com/Unit-Wasteland/wasteland3-vanilla-langpack-japanese.git
cd wasteland3-vanilla-langpack-japanese

# 2. 未翻訳エントリを検出
bash automation/generate-untranslated-list.sh

# 3. 自動修正を開始
bash automation/auto-fix-untranslated.sh
```

#### バックグラウンド実行

```bash
# Claude Codeセッションを保護しながらバックグラウンド実行
PROTECTED_CLAUDE_PID=$(pgrep claude | head -1) \
  nohup bash automation/auto-fix-untranslated.sh > automation/.auto-fix-bg.log 2>&1 &

# ステータス確認
bash automation/check-auto-fix-status.sh

# リアルタイムログ監視
tail -f automation/untranslated-fix-automation.log
```

#### 自動修正プロセスの特徴

- **完全自動**: 人間の介入なしで24時間連続実行
- **安全**: 各エントリを個別に処理（一括処理なし）
- **検証**: 全ての修正後に構造・品質検証を実施
- **自動保存**: git commit + push を自動実行
- **再開可能**: セッション間で進捗を自動保持

詳細は [`automation/README.md`](automation/README.md) を参照してください。

### 方法2: 手動翻訳

Claude Codeを対話的に使用して翻訳作業を行います。

```bash
# Claude Codeを起動
claude

# プロンプト
> translation/.retranslation_progress.json を読み込んで、
> translation/STRICT_TRANSLATION_RULES.md に従って
> 厳格翻訳作業を継続してください。
```

**手動翻訳のメリット:**
- ✅ 各ステップを確認しながら進められる
- ✅ 翻訳判断を人間が監督できる
- ✅ 学習目的に最適

詳細は [`CLAUDE.md`](CLAUDE.md) の「Translation Workflow」セクションを参照してください。

## 📖 ドキュメント構成

プロジェクトの情報は以下のドキュメントに集約されています：

### メインドキュメント

| ファイル | 対象 | 内容 |
|---------|------|------|
| **README.md** | 人間 | プロジェクト概要・使い方（このファイル） |
| **CLAUDE.md** | AI | 完全な翻訳ルール・ワークフロー |
| **automation/README.md** | 人間 | 自動化システムの完全ガイド |

### 補足ドキュメント

| ファイル | 内容 |
|---------|------|
| `automation/AUTO_FIX_README.md` | 自動修正プロセスのクイックリファレンス |
| `translation/STRICT_TRANSLATION_RULES.md` | 厳格翻訳ルール（CLAUDE.mdの補足） |
| `translation/STRUCTURE_PROTECTION_RULES.md` | 構造保護ルール（CLAUDE.mdの補足） |
| `translation/RETRANSLATION_WORKFLOW.md` | 再翻訳ワークフロー（CLAUDE.mdの補足） |

## 🛠️ 技術詳細

### ファイル構成

```
translation/
├── source/v1.6.9.420.309496/
│   ├── en_US/           # 英語ソース（翻訳元）
│   ├── es_ES/           # スペイン語参照（翻訳可否判定）
│   ├── DLC1/            # Battle of Steeltown DLC
│   └── DLC2/            # Cult of the Holy Detonation DLC
├── target/v1.6.9.420.309496/ja_JP/
│   └── *.txt            # 日本語翻訳（同一構造）
├── nouns_glossary.json  # 固有名詞用語集
├── .retranslation_progress.json  # 進捗管理
└── validate_*.py        # 検証スクリプト

automation/
├── auto-fix-untranslated.sh      # 未翻訳自動修正
├── generate-untranslated-list.sh # 未翻訳検出
├── check-auto-fix-status.sh      # ステータス確認
└── *.log                         # ログファイル
```

### Unity StringTable形式

このプロジェクトで扱うファイルは、Unity StringTable形式を使用しています。

**重要な形式ルール:**
```
string data = ""日本語テキスト""    ← 正しい形式（ダブルダブルクォート）
string data = "English text"       ← 正しい形式（シングルクォート）

❌ string data = "\"日本語\""        ← 間違い（エスケープ禁止）
❌ string data = "「日本語」"        ← 間違い（日本語括弧禁止）
```

詳細は `CLAUDE.md` の「File Format」セクションを参照してください。

### 検証システム

翻訳後、2種類の検証を自動実行：

#### 1. 構造検証（validate_structure_v2.py）
- ✅ 行数一致
- ✅ クォート数一致
- ✅ 構造マーカー保護（`""`, `[]`, `<>`, `::action::`）

#### 2. 品質検証（validate_translation_quality.py）
- ✅ アクションマーカー翻訳検出
- ✅ 未翻訳エントリ検出
- ✅ 用語集違反検出
- ✅ 技術用語保護検証

**2025年11月16日の改善:**
- ダブルクォート両形式対応（`""content""` と `"content"`）
- 開発デバッグメッセージ除外（`DEBUG -`, `Test`）
- 固有名詞英語残存検出

## 📈 進捗履歴

| 日付 | マイルストーン |
|------|--------------|
| 2025-10-19 | プロジェクト開始、自動翻訳システム構築 |
| 2025-10-29 | 厳格翻訳ルール確立、構造保護強化 |
| 2025-11-01 | アクションマーカー保護ルール追加 |
| 2025-11-06 | 統一翻訳判断ロジック確立 |
| 2025-11-14 | ベースゲーム翻訳完了（従来の検証基準） |
| **2025-11-16** | **検証スクリプト改善、20,952未翻訳検出** |
| **2025-11-16** | **自動修正プロセス開始** |

## ⚠️ 既知の問題と対策

### 未翻訳エントリの原因

検証ロジックの欠陥により、以下が見逃されていました：

1. **シングルクォート形式** (`string data = "content"`)
   - 約35,249行が検出対象外だった
   - **対策**: 両形式対応に改善

2. **ゲーム内"Debug"セリフ**
   - "DEBUG"キーワード全体を除外していた
   - **対策**: 開発メッセージのみ除外

3. **固有名詞の英語残存**
   - 日本語テキスト内の英語固有名詞を検出できず
   - **対策**: 用語集ベース検出を追加

### 現在の修正状況

- ✅ 検証スクリプト改善完了
- 🔄 自動修正プロセス実行中（20,952エントリ）
- 📅 完了予想: 3-7日後

## 🤝 貢献方法

### Issue報告
- バグ報告
- 翻訳の改善提案
- 新機能の提案

### Pull Request
1. Fork このリポジトリ
2. 翻訳作業を実施
3. 検証スクリプトでエラー0を確認
4. Pull Request作成

## 📄 ライセンス

このプロジェクトは [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/) ライセンスの下で公開されています。

**注意**: Wasteland 3は inXile Entertainment の商標です。このプロジェクトは非公式なファンプロジェクトであり、開発元とは一切関係ありません。

## 🔗 関連リンク

- [Wasteland 3 公式サイト](https://wasteland.inxile-entertainment.com/)
- [Claude Code](https://claude.com/claude-code)
- [GitHub Issues](https://github.com/Unit-Wasteland/wasteland3-vanilla-langpack-japanese/issues)

---

**最終更新**: 2025年11月16日
**プロジェクト開始**: 2025年10月19日
**現在のフェーズ**: ベースゲーム未翻訳修正中
