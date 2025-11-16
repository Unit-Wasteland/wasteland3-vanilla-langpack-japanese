# 自動化システム - Wasteland 3 日本語翻訳プロジェクト

このディレクトリには、翻訳作業を自動化するスクリプトが含まれています。

**現在の自動化タスク**: ベースゲームの未翻訳エントリ20,952個を自動修正中

---

## 📊 現在の状況（2025年11月16日）

| 項目 | 状態 |
|------|------|
| **ベースゲーム進捗** | 87.7% (148,757/169,712) |
| **未翻訳エントリ** | 20,952個 |
| **自動修正** | 実行中 |
| **DLC1/DLC2** | 未開始（ベース完了後） |

---

## 🚀 未翻訳エントリ自動修正システム

### システム概要

2025年11月16日、検証スクリプトの改善により、これまで見逃されていた**20,952個の未翻訳エントリ**が検出されました。これらを自動的に修正するシステムが稼働中です。

**検出された未翻訳の原因:**
1. **シングルクォート形式の見逃し** (`string data = "content"` 形式が未対応だった)
2. **ゲーム内"Debug"セリフの誤除外** (開発用デバッグと誤認識)
3. **固有名詞の英語残存** (日本語テキスト内の英語固有名詞を検出できず)

**対策:**
- validate_translation_quality.py を改善（両形式対応、固有名詞検出追加）
- 自動修正プロセスで全エントリを順次処理

---

## 🔧 利用可能なスクリプト

### 1. generate-untranslated-list.sh

未翻訳エントリを検出し、修正対象の行番号リストを生成します。

```bash
# 未翻訳エントリを検出
bash automation/generate-untranslated-list.sh
```

**生成ファイル:**
- `automation/.untranslated_lines.txt` - 未翻訳行番号リスト（1行1番号）
- `automation/.untranslated_report.txt` - 詳細レポート（検証結果全文）

**検出ロジック:**
- validate_translation_quality.py を使用
- ダブルクォート両形式対応 (`""content""` と `"content"`)
- 開発デバッグメッセージ除外（`^DEBUG -`, `^Test`）
- 固有名詞の英語残存検出（nouns_glossary.json参照）

### 2. auto-fix-untranslated.sh

未翻訳エントリを自動的に修正します（完全無人実行）。

```bash
# 自動修正を開始
bash automation/auto-fix-untranslated.sh

# バックグラウンド実行（推奨）
PROTECTED_CLAUDE_PID=$(pgrep claude | head -1) \
  nohup bash automation/auto-fix-untranslated.sh > automation/.auto-fix-bg.log 2>&1 &
```

**動作の仕組み:**

1. **初期化**
   - `.untranslated_lines.txt` から修正対象を読み込み
   - 排他ロック取得（重複実行防止）

2. **セッション実行**
   - 20エントリずつ処理
   - Claude Code を自動起動
   - Read + Edit ツールで1エントリずつ翻訳（CLAUDE.mdルール厳守）
   - メモリ監視（30秒ごと、上限5000MB）

3. **検証とコミット**
   - 構造検証（validate_structure_v2.py）
   - 品質検証（validate_translation_quality.py）
   - 両方パスで自動 git commit + push
   - 検証失敗時は警告（作業は保存）

4. **進捗管理**
   - 未翻訳リストを再生成（修正済みを除外）
   - 3連続ゼロ修正で停止（手動介入が必要）
   - 完了まで自動継続

**パラメータ（スクリプト内変数）:**
```bash
MAX_MEMORY_MB=5000        # メモリ上限（6GB RAM - 1GB margin）
ENTRIES_PER_SESSION=20    # 1セッションあたりの処理数
MAX_SESSIONS=1050         # 最大セッション数（安全装置）
```

**所要時間:**
- 総エントリ数: 20,952個
- 予想セッション数: 約1,048セッション
- 1セッション平均: 5-10分
- **完了予想: 3-7日**

### 3. check-auto-fix-status.sh

自動修正プロセスのステータスを確認します。

```bash
# ステータス確認
bash automation/check-auto-fix-status.sh
```

**表示内容:**
- ✅ プロセス実行状況（PID、稼働時間）
- 📈 進捗状況（修正済み/残り件数、進捗率）
- 📝 最新ログ（直近10行）
- 📁 ログファイルサイズ
- 🔧 監視コマンド一覧

---

## 📖 使い方

### クイックスタート（自動修正）

```bash
# 1. 未翻訳エントリを検出
bash automation/generate-untranslated-list.sh

# 2. 自動修正を開始（バックグラウンド）
PROTECTED_CLAUDE_PID=$(pgrep claude | head -1) \
  nohup bash automation/auto-fix-untranslated.sh > automation/.auto-fix-bg.log 2>&1 &

# 3. ステータス確認
bash automation/check-auto-fix-status.sh

# 4. リアルタイム監視
tail -f automation/untranslated-fix-automation.log
```

### プロセス保護について

**PROTECTED_CLAUDE_PID の役割:**

バックグラウンド実行時、自動化スクリプトは独自のClaude Codeセッションを起動します。現在のClaude Codeセッション（対話用）を誤って終了しないよう、PIDを保護します。

```bash
# 現在のClaude CodeセッションのPIDを取得
PROTECTED_CLAUDE_PID=$(pgrep claude | head -1)

# このPIDは終了せず、新しく起動されたClaude Codeのみを制御
nohup bash automation/auto-fix-untranslated.sh > automation/.auto-fix-bg.log 2>&1 &
```

**プロセス独立性:**
- `nohup` により親プロセス（現在のシェル）から独立
- 対話セッションを終了してもバックグラウンドプロセスは継続
- 別のClaude Codeセッションで状態確認可能

### リアルタイム監視

```bash
# メインログ（推奨）
tail -f automation/untranslated-fix-automation.log

# バックグラウンドログ
tail -f automation/.auto-fix-bg.log

# 未翻訳残数確認
wc -l automation/.untranslated_lines.txt

# 次に処理される行番号（先頭20件）
head -20 automation/.untranslated_lines.txt
```

### プロセス制御

```bash
# 状態確認
ps aux | grep auto-fix-untranslated

# 停止（正常終了）
kill <PID>

# 強制停止
kill -9 <PID>
```

---

## 🛠️ トラブルシューティング

### プロセスが停止している

**診断:**
```bash
# ログで原因確認
tail -50 automation/untranslated-fix-automation.log

# よくある原因:
# - 3連続ゼロ修正（手動介入が必要）
# - メモリ超過（ENTRIES_PER_SESSION を減らす）
# - git push 失敗3連続（ネットワーク確認）
```

**対処:**
1. 最新ログを確認: `tail -50 automation/untranslated-fix-automation.log`
2. git status 確認: `git status`（未コミット作業があれば手動コミット）
3. 再起動: `bash automation/auto-fix-untranslated.sh`（自動的に続きから再開）

### 進捗が遅い

```bash
# メモリ使用量確認
tail -f automation/untranslated-fix-automation.log | grep "Memory usage"

# セッション完了時間確認
grep "Session #" automation/untranslated-fix-automation.log | tail -5
```

**対策:**
- メモリ使用量が常に高い（>3GB）→ ENTRIES_PER_SESSION を減らす
- セッション時間が長い（>15分）→ ネットワーク遅延の可能性

### 検証失敗が頻発する

```bash
# 詳細な検証レポートを確認
cat automation/.untranslated_report.txt | tail -100

# 特定の行を手動で確認
grep "行番号" translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-*.txt
```

**対策:**
- 構造検証エラー → 手動でダブルクォート形式を確認
- 品質検証エラー → action marker翻訳や固有名詞の確認

### 未翻訳リストを再生成

```bash
# 現在の状態で再検出
bash automation/generate-untranslated-list.sh

# 再生成後の件数確認
wc -l automation/.untranslated_lines.txt
```

---

## 📝 ログファイル

| ファイル | 内容 |
|---------|------|
| `automation/untranslated-fix-automation.log` | メインログ（セッション詳細、進捗、検証結果） |
| `automation/.auto-fix-bg.log` | バックグラウンド起動ログ |
| `automation/.fix_untranslated_output.log` | 各Claude Codeセッション出力 |
| `automation/.untranslated_lines.txt` | 未翻訳行番号リスト（処理対象） |
| `automation/.untranslated_report.txt` | 検証スクリプト完全レポート |

---

## 🔍 検証システム

自動修正後、2種類の検証を必ず実施します。

### 1. 構造検証（validate_structure_v2.py）

Unity StringTable形式の構造を保護します。

```bash
python3 translation/validate_structure_v2.py \
  translation/target/v1.6.9.420.309496/ja_JP/FILENAME.txt \
  --source translation/source/v1.6.9.420.309496/en_US/FILENAME.txt \
  --detailed
```

**検証項目:**
- ✅ 行数一致（source == target）
- ✅ クォート数一致（各行ごと）
- ✅ 構造マーカー保護（`""`, `[]`, `<>`, `::action::`）
- ✅ ダブルダブルクォート形式維持

### 2. 品質検証（validate_translation_quality.py）

翻訳内容の品質を確認します。

```bash
python3 translation/validate_translation_quality.py \
  translation/target/v1.6.9.420.309496/ja_JP/FILENAME.txt \
  --start-line 390 \
  --end-line 530425 \
  --glossary translation/nouns_glossary.json
```

**検証項目:**
- ✅ action marker 翻訳検出（`::action::` は英語のまま）
- ✅ 未翻訳エントリ検出（両クォート形式対応）
- ✅ 用語集違反検出（nouns_glossary.json参照）
- ✅ 技術用語保護（Script Node, [Switch to], etc.）

**両検証でゼロエラー/ゼロ問題のみコミット可能です。**

---

## ⚙️ 設定の調整

### メモリ制限の調整（6GB RAM環境）

`auto-fix-untranslated.sh` 内:
```bash
MAX_MEMORY_MB=5000  # デフォルト: 6GB RAM - 1GB margin

# メモリ不足が頻発する場合
MAX_MEMORY_MB=4000  # より保守的な設定

# メモリが十分な場合（8GB+ RAM）
MAX_MEMORY_MB=7000
```

### 処理速度の調整

```bash
ENTRIES_PER_SESSION=20  # デフォルト

# より慎重に処理（メモリ不足時）
ENTRIES_PER_SESSION=10

# より高速に処理（安定稼働時）
ENTRIES_PER_SESSION=30
```

---

## 🔐 セキュリティに関する注意

### --dangerously-skip-permissions フラグ

このスクリプトは `--dangerously-skip-permissions` フラグを使用します。

**これは何か:**
- Claude Code の内部権限チェックを完全にバイパス
- すべてのファイル操作が無条件で実行される

**なぜ必要か:**
- 完全無人実行を実現するため
- 対話的な承認プロンプトを回避

**リスク:**
- システムファイルの破壊
- データ損失
- 予期しないコード実行

**安全な使用方法:**
- ✅ サンドボックス環境（VM/コンテナ）で実行
- ✅ 重要データのバックアップ取得
- ✅ インターネットアクセス制限された環境
- ❌ メインPCや本番環境では絶対に実行しない

---

## 📚 関連ドキュメント

| ファイル | 内容 |
|---------|------|
| **CLAUDE.md** | AI用完全翻訳ルール・ワークフロー |
| **README.md** | プロジェクト概要・使い方（人間用） |
| **AUTO_FIX_README.md** | 自動修正クイックリファレンス |
| **translation/STRICT_TRANSLATION_RULES.md** | 厳格翻訳ルール |
| **translation/STRUCTURE_PROTECTION_RULES.md** | 構造保護ルール |

---

## 🎯 よくある質問

### Q: このセッションを終了してもバックグラウンドプロセスは継続しますか？

**A: はい、継続します。** `nohup` で起動されているため、親プロセス（現在のシェル）から独立しています。別のClaude Codeセッションから `check-auto-fix-status.sh` で状態確認できます。

### Q: 自動修正プロセスはいつ停止しますか？

**A: 以下の条件で停止します:**
1. 全未翻訳エントリの修正完了
2. 3連続でゼロ修正（手動介入が必要）
3. 最大セッション数（1050）に到達
4. git push 3連続失敗（ネットワーク問題）

### Q: 途中で止まった場合、どうすればいいですか？

**A: 単に再実行してください。** 進捗は `.untranslated_lines.txt` で管理されており、修正済みのエントリは自動的にスキップされます。

```bash
# 再起動（自動的に続きから）
bash automation/auto-fix-untranslated.sh
```

### Q: 手動で翻訳したい場合は？

**A: 以下の方法があります:**

```bash
# 1. 未翻訳リストを生成
bash automation/generate-untranslated-list.sh

# 2. Claude Codeを起動
claude

# 3. プロンプト例
> automation/.untranslated_lines.txt に記載された行番号を参照し、
> CLAUDE.mdのルールに従って未翻訳エントリを日本語に翻訳してください。
> 20エントリごとに確認してください。
```

---

**最終更新**: 2025年11月16日
**システムバージョン**: auto-fix-untranslated v1.0
