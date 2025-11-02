# Auto-Recovery System

## 概要

自動翻訳システムにエラーが発生した場合、自動的にエラーを調査・修正して処理を継続する機能です。

**追加日**: 2025-11-02
**目的**: Session 7で発生したアクションマーカー翻訳エラーのような問題を自動的に修正し、手動介入なしで翻訳を継続

---

## アーキテクチャ

### システム構成

```
auto-retranslate.sh (メインスクリプト)
    ↓
    ├─ Session実行
    ↓
    ├─ Validation (Structure)
    │   ├─ PASS → 次へ
    │   └─ FAIL → auto-fix-errors.sh 呼び出し
    │       ├─ SUCCESS → Commit → 次へ
    │       └─ FAIL → 停止 (手動介入必要)
    ↓
    ├─ Validation (Quality)
    │   ├─ PASS → 次へ
    │   └─ FAIL → auto-fix-errors.sh 呼び出し
    │       ├─ SUCCESS → Commit → 次へ
    │       └─ FAIL → 停止 (手動介入必要)
    ↓
    └─ Git Push & 次のセッション
```

### 関連スクリプト

| スクリプト | 役割 | 言語 |
|-----------|------|------|
| `auto-retranslate.sh` | メイン自動翻訳スクリプト | Bash |
| `auto-fix-errors.sh` | エラー自動修正統合スクリプト | Bash |
| `auto-fix-action-markers.py` | アクションマーカー修正 | Python |

---

## 自動修正可能なエラー

### 1. アクションマーカーの日本語翻訳

**問題**:
```
誤: string data = "::ため息:: "わからない...""
正: string data = "::sigh:: "わからない...""
```

**検出方法**:
```bash
grep -o '::[^:]*[ぁ-ゖァ-ヾ一-龯][^:]*::' TARGET_FILE
```

**修正方法**:
1. 英語ソースファイルから正しいアクションマーカーを取得
2. 日本語マーカーを英語マーカーに置換
3. Validation再実行

**実装**: `auto-fix-action-markers.py`

**成功率**: 高（100%自動修正可能）

---

### 2. 構造エラー（将来実装予定）

**問題例**:
- Quote count不一致
- Line count不一致
- Missing structure markers

**修正方法** (現在は未実装):
- ソースファイルと比較
- 構造を復元

**成功率**: 未知（実装後に評価）

---

## エラーハンドリングフロー

### Structure Validation失敗時

```bash
# 1. Validation実行
bash validate-structure.sh

# 2. 失敗時
log "WARN" "✗ Structure validation FAILED!"
log "WARN" "  Attempting auto-fix..."

# 3. Auto-fix実行
bash auto-fix-errors.sh

# 4. 成功時
log "INFO" "✓ Auto-fix completed - retrying validation"

# 5. 再Validation
bash validate-structure.sh

# 6a. 成功 → Commit → 処理継続
git commit -m "Auto-fix: Structure errors (Session #N)"

# 6b. 失敗 → 停止
log "ERROR" "✗ Structure validation still failing after auto-fix"
exit 1
```

### Quality Validation失敗時

```bash
# 1. Validation実行
python3 validate_translation_quality.py

# 2. 失敗時
log "WARN" "✗ Quality validation FAILED!"
log "WARN" "  Attempting auto-fix..."

# 3. Auto-fix実行
bash auto-fix-errors.sh

# 4. 成功時
log "INFO" "✓ Auto-fix completed - retrying validation"

# 5. 再Validation
python3 validate_translation_quality.py

# 6a. 成功 → Commit → 処理継続
git commit -m "Auto-fix: Quality errors (Session #N)"

# 6b. 失敗 → 停止
log "ERROR" "✗ Quality validation still failing after auto-fix"
exit 1
```

---

## 使用方法

### 自動実行（推奨）

```bash
# 通常の自動翻訳を実行
./automation/auto-retranslate.sh

# エラーが発生しても自動的に修正を試みます
# 修正成功 → 処理継続
# 修正失敗 → 停止（ログ確認が必要）
```

### 手動修正実行

エラー修正のみを単独で実行する場合:

```bash
# 自動修正を実行
./automation/auto-fix-errors.sh automation/retranslation-automation.log

# Exit code:
#   0 = 修正成功
#   1 = 修正不要 or 修正失敗
```

### アクションマーカー修正のみ

```bash
# Dry-runモード（変更なし、プレビューのみ）
python3 automation/auto-fix-action-markers.py \
  translation/target/.../StringTableData_English-CAB-...txt \
  translation/source/.../StringTableData_English-CAB-...txt \
  --dry-run

# 実際の修正を実行
python3 automation/auto-fix-action-markers.py \
  translation/target/.../StringTableData_English-CAB-...txt \
  translation/source/.../StringTableData_English-CAB-...txt
```

---

## バックアップ戦略

### 自動バックアップ

修正実行時、以下のバックアップが自動的に作成されます:

1. **Full backup** (タイムスタンプ付き):
   ```
   TARGET_FILE.backup_20251102_195730
   ```

2. **Auto-fix backup** (修正単位):
   ```
   TARGET_FILE.autofix.bak
   ```

### 復元方法

```bash
# 最新の自動バックアップから復元
cp translation/target/.../StringTableData_English-CAB-...txt.backup_YYYYMMDD_HHMMSS \
   translation/target/.../StringTableData_English-CAB-...txt

# Gitから復元
git restore translation/target/.../StringTableData_English-CAB-...txt
```

---

## ログ出力

### 成功時のログ例

```
[2025-11-02 19:57:30] [WARN] ✗ Quality validation FAILED!
[2025-11-02 19:57:30] [WARN]   Attempting auto-fix...
[2025-11-02 19:57:30] [INFO] =========================================
[2025-11-02 19:57:30] [INFO] Auto-Fix Errors: Starting
[2025-11-02 19:57:30] [INFO] =========================================
[2025-11-02 19:57:30] [INFO] ⚠ Validation failed - attempting auto-fix
[2025-11-02 19:57:30] [INFO] 📦 Full backup created: ...backup_20251102_195730
[2025-11-02 19:57:30] [INFO] 🔧 Fixing action markers translated to Japanese...
[2025-11-02 19:57:31] [INFO]   Line 232532: Found 1 Japanese action marker(s)
[2025-11-02 19:57:31] [INFO]     → ::静かに鼻歌を歌う::
[2025-11-02 19:57:31] [INFO]     ✓ Fixed with: ::hums quietly::
[2025-11-02 19:57:31] [INFO]   ✓ Fixed 3 action marker(s)
[2025-11-02 19:57:31] [INFO]   ✓ Action markers fixed successfully
[2025-11-02 19:57:31] [INFO] 🔍 Re-validating after fixes...
[2025-11-02 19:57:32] [INFO] =========================================
[2025-11-02 19:57:32] [INFO] ✅ Auto-fix SUCCESSFUL
[2025-11-02 19:57:32] [INFO] =========================================
[2025-11-02 19:57:32] [INFO] ✓ Auto-fix completed - retrying validation
[2025-11-02 19:57:32] [INFO] ✓ Quality validation passed after auto-fix
[2025-11-02 19:57:32] [INFO] Committing auto-fix changes...
[2025-11-02 19:57:33] [INFO] ✓ Auto-fix changes committed
```

### 失敗時のログ例

```
[2025-11-02 20:00:00] [WARN] ✗ Quality validation FAILED!
[2025-11-02 20:00:00] [WARN]   Attempting auto-fix...
[2025-11-02 20:00:01] [ERROR] ✗ Auto-fix failed - cannot recover automatically
[2025-11-02 20:00:01] [ERROR]   Session output: automation/.session_8_output.log
[2025-11-02 20:00:01] [ERROR]   Stopping automation - manual intervention required
```

---

## エラー統計

### 想定される自動修正率

| エラータイプ | 自動修正率 | 手動介入必要率 |
|-------------|-----------|--------------|
| アクションマーカー翻訳 | **100%** | 0% |
| 構造エラー (quote count) | 未実装 | 100% (現在) |
| その他の品質エラー | 0% | 100% |

### 期待効果

- **ダウンタイム削減**: エラー発生から修正完了まで 即時（数秒）
- **人的介入削減**: アクションマーカーエラーは100%自動修正
- **安定性向上**: 修正失敗時のみ停止、それ以外は継続

---

## トラブルシューティング

### Q: Auto-fixが実行されない

**A**: ログを確認してください:

```bash
tail -100 automation/retranslation-automation.log | grep "auto-fix"
```

### Q: Auto-fix後も validation が失敗する

**A**: 以下を確認:

1. **修正内容を確認**:
   ```bash
   git diff
   ```

2. **Validation出力を確認**:
   ```bash
   # Structure validation
   python3 translation/validate_structure_v2.py TARGET_FILE --source SOURCE_FILE --detailed

   # Quality validation
   python3 translation/validate_translation_quality.py TARGET_FILE --reference SPANISH_FILE --start-line 390 --end-line CURRENT_LINE
   ```

3. **手動修正が必要**:
   - エラー内容を確認
   - 手動で修正
   - Commit & Push
   - 自動翻訳を再開

### Q: Backupから復元したい

**A**: 最新のbackupファイルを特定して復元:

```bash
# Backup一覧表示
ls -lt translation/target/.../StringTableData_English-CAB-*.backup_* | head

# 復元
cp BACKUP_FILE translation/target/.../StringTableData_English-CAB-...txt

# Git status確認
git status
git diff
```

---

## 今後の改善予定

### Phase 1: 完了済み (2025-11-02)

- ✅ アクションマーカー自動修正
- ✅ Validation失敗時の自動retry
- ✅ 修正内容の自動commit
- ✅ Backup自動作成

### Phase 2: 予定

- ⏳ 構造エラー自動修正（quote count, line count）
- ⏳ より詳細なエラー分類
- ⏳ 修正履歴の統計レポート

### Phase 3: 検討中

- ⏳ 機械学習ベースのエラー予測
- ⏳ エラーパターンの学習・自動改善

---

## 関連ドキュメント

- **ACTION_MARKER_PREVENTION.md**: アクションマーカーエラー再発防止策
- **CLAUDE.md**: プロジェクト全体のガイドライン
- **automation/README.md**: 自動化システム全般のドキュメント

---

**作成日**: 2025-11-02
**最終更新**: 2025-11-02
**バージョン**: 1.0
**メンテナ**: Claude Code Automation
