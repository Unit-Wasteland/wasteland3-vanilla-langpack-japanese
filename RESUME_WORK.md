# 作業再開手順 - 自動化停止後のリカバリー

**状況**: 自動化スクリプトがSession #147で「3連続0エントリ」検出により停止
**原因**: 修正作業が「進捗なし」と誤判定された（詳細: AUTOMATION_ISSUE_REPORT.md参照）
**実態**: Sessions #145-147はすべて成功（84+ エントリ修正完了）

---

## 🎯 即座に実行可能な再開手順

### Option 1: 手動セッションで修正作業を継続（最も確実）

#### Step 1: 現状確認
```bash
cd /home/claude/work/project-claude/wasteland3-vanilla-langpack-japanese

# 現在の進捗を確認
cat translation/.retranslation_progress.json | jq '.files.dlc2 | {current_line, entries_completed, status}'

# 構造検証
python3 translation/validate_structure_v2.py \
  translation/target/v1.6.9.420.309496/ja_JP/DLC2/StringTableData_English-CAB-6a212d8a4482b263f057ec8756825864-4193932453415687559.txt \
  --source translation/source/v1.6.9.420.309496/en_US/DLC2/StringTableData_English-CAB-6a212d8a4482b263f057ec8756825864-4193932453415687559.txt

# 期待: "Total errors: 0"
```

#### Step 2: Claude Codeセッション開始
```bash
claude
```

#### Step 3: 以下のプロンプトを使用
```
DLC2の開発者デバッグテキスト修正を継続してください。

**現在地点**: Line 45138
**次のセクション**: e4001_sleeperroom_podempty06以降

**作業内容**:
1. Lines 45138-45338 (200行チャンク)を読み込み
   - 英語ソース
   - スペイン語参照
   - 日本語ターゲット

2. スペイン語参照が空（string data = ""）で、日本語が英語と異なるエントリを特定

3. 該当エントリを英語に戻す（統一翻訳判定ロジックに従う）
   - 例: " 立ち去る" → " Walk away."（スペイン語が空の場合）

4. **MANDATORY: 各編集後に検証実行**:
   ```bash
   # 構造検証
   python3 translation/validate_structure_v2.py TARGET_FILE \
     --source SOURCE_FILE --detailed

   # 品質検証
   python3 translation/validate_translation_quality.py TARGET_FILE \
     --start-line 45138 --end-line 45338 \
     --glossary translation/nouns_glossary.json
   ```

5. 両方の検証が0エラーになったらコミット:
   ```bash
   git add translation/target/v1.6.9.420.309496/ja_JP/DLC2/*.txt
   git add translation/.retranslation_progress.json
   git commit -m "DLC2 translation: Session R3-346 - Developer debug text corrections (lines 45138-45338)"
   ```

6. 次の200行チャンクに進む（可能なら50-100エントリ目標）

**修正対象**: 51+ entries in lines 45138-50000
**目標**: Lines 45138-46500 の修正完了（約10-20 chunks）

**重要**:
- 統一翻訳判定ロジック適用: Spanish == "" → 英語保持
- 両検証（構造 + 品質）必須
- 50-100エントリごとにコミット
```

#### Step 4: 作業完了後の確認
```bash
# 最新コミットを確認
git log -1 --oneline

# Gitプッシュ（任意 - 安全のため推奨）
git push origin main
```

---

### Option 2: 自動化スクリプトを改善して再実行

#### Step 1: 自動化スクリプトにGitコミット検出を追加

**ファイル**: `automation/auto-retranslate.sh`（ユーザーのサーバー上）

**追加する改善ロジック**:
```bash
# Before session
COMMIT_BEFORE=$(git rev-parse HEAD)

# Run Claude Code session
run_claude_code_session

# After session
COMMIT_AFTER=$(git rev-parse HEAD)

# Progress detection (IMPROVED)
if [ "$COMMIT_BEFORE" != "$COMMIT_AFTER" ]; then
    # Git commit detected = progress made (including correction work)
    CONSECUTIVE_ZERO=0
    ENTRIES_THIS_SESSION=$(git diff "$COMMIT_BEFORE" "$COMMIT_AFTER" --numstat | \
        grep "translation/.retranslation_progress.json" | \
        awk '{print $1}')
    log "INFO" "Session completed: Git commit detected (corrections or translations)"
    log "INFO" "  New translations: $ENTRIES_TRANSLATED"
    log "INFO" "  Git changes detected: YES"
elif [ $ENTRIES_TRANSLATED -eq 0 ]; then
    # No commit + no entries = true stuck state
    CONSECUTIVE_ZERO=$((CONSECUTIVE_ZERO + 1))
    log "WARN" "Zero entries completed (consecutive: $CONSECUTIVE_ZERO / 3)"
    log "WARN" "  No git commit detected - possible stuck state"
    if [ $CONSECUTIVE_ZERO -ge 3 ]; then
        log "ERROR" "3 consecutive sessions with no progress - stopping"
        exit 1
    fi
else
    # New translations
    CONSECUTIVE_ZERO=0
fi
```

**メリット**:
- ✅ 修正作業も「進捗」として認識
- ✅ 本当のスタック状態のみ検出
- ✅ 誤検知を防止

#### Step 2: ロックファイル解除
```bash
cd /home/claude/work/project-claude/wasteland3-vanilla-langpack-japanese

# オプション1: 自動化スクリプトのunlock機能使用
./automation/auto-retranslate.sh --unlock

# オプション2: unlock専用スクリプト使用
./automation/unlock-retranslation.sh

# オプション3: 手動で解除
rm -f automation/.retranslation.lock
```

#### Step 3: 自動化再実行
```bash
./automation/auto-retranslate.sh
```

---

### Option 3: カウンターをリセットして現行スクリプトを再実行（一時的対応）

**注意**: これは一時的な対応です。Option 2の恒久的改善を推奨します。

#### Step 1: 自動化スクリプトの一時的パッチ

**ファイル**: `automation/auto-retranslate.sh`

**追加箇所**: セッション完了判定の直前
```bash
# Temporary fix: Reset counter if git commit detected
COMMIT_BEFORE=$(git rev-parse HEAD)
# ... run session ...
COMMIT_AFTER=$(git rev-parse HEAD)

if [ "$COMMIT_BEFORE" != "$COMMIT_AFTER" ]; then
    log "INFO" "Git commit detected - resetting consecutive zero counter"
    CONSECUTIVE_ZERO=0
fi
```

#### Step 2: 実行
```bash
./automation/auto-retranslate.sh --unlock
./automation/auto-retranslate.sh
```

---

## 📊 作業範囲の見積もり

### 残存修正対象（確認済み）

| 範囲 | 修正必要数 | 推定セッション数 |
|------|----------|----------------|
| Lines 45138-50000 | 51 entries | 1-2 sessions |
| Lines 50001-55000 | ~40 entries (推定) | 1 session |
| Lines 55001-60000 | ~30 entries (推定) | 1 session |
| Lines 60001-77353 | ~60 entries (推定) | 1-2 sessions |

**合計推定**: 180-200 entries, 4-6 sessions (各session 50-100 entries)

### 修正完了後の作業

修正作業完了後、通常の翻訳作業に移行:
- DLC2残り: 19,447 untranslated entries
- 推定セッション数: 39 sessions (500 entries/session)

---

## ✅ 成功判定基準

### 各セッション完了時
- ✅ 構造検証: 0 errors
- ✅ 品質検証: 0 issues
- ✅ Gitコミット成功
- ✅ 進捗ファイル更新

### 修正フェーズ完了時
- ✅ DLC2全体で開発者デバッグテキストが英語に統一
- ✅ スペイン語空エントリで日本語が混入しているケース: 0
- ✅ 全ファイル検証パス

### 最終完了時
- ✅ Base game: 169,712 entries (100%)
- ✅ DLC1: 38,554 entries (100%)
- ✅ DLC2: 24,152 entries (100%)
- ✅ 合計: 232,418 entries (100%)

---

## 🔧 トラブルシューティング

### Q1: 「どのエントリを修正すればいいか分からない」

**A1**: 以下のPythonスクリプトで特定:
```bash
cd translation
python3 -c "
import sys

en_file = 'source/v1.6.9.420.309496/en_US/DLC2/StringTableData_English-CAB-6a212d8a4482b263f057ec8756825864-4193932453415687559.txt'
es_file = 'source/v1.6.9.420.309496/es_ES/DLC2/StringTableData_Spanish-CAB-6a212d8a4482b263f057ec8756825864-6420464141808439591.txt'
ja_file = 'target/v1.6.9.420.309496/ja_JP/DLC2/StringTableData_English-CAB-6a212d8a4482b263f057ec8756825864-4193932453415687559.txt'

with open(en_file, 'r', encoding='utf-8') as f: en_lines = f.readlines()
with open(es_file, 'r', encoding='utf-8') as f: es_lines = f.readlines()
with open(ja_file, 'r', encoding='utf-8') as f: ja_lines = f.readlines()

start_line = 45138
end_line = 50000

for i in range(start_line-1, min(end_line, len(en_lines))):
    if 'string data = ' in en_lines[i]:
        if es_lines[i].strip() == '1 string data = \"\"' and \
           en_lines[i].strip() != '1 string data = \"\"' and \
           ja_lines[i] != en_lines[i] and \
           any(ord(c) > 0x3000 for c in ja_lines[i]):
            print(f'Line {i+1}: {ja_lines[i].strip()}')
            print(f'  → Should be: {en_lines[i].strip()}')
            print()
" | head -30
```

### Q2: 「修正後も検証でエラーが出る」

**A2**: 以下を確認:
1. 引用符の数が一致しているか（2個 or 4個）
2. 行数が変わっていないか
3. エスケープシーケンス（`\n`, `\r`）を保持しているか
4. アクションマーカー（`::action::`）が英語のままか

### Q3: 「自動化スクリプトの改善方法が分からない」

**A3**: AUTOMATION_ISSUE_REPORT.md の「改善提案」セクション参照。
主な変更点:
- Gitコミット検出を追加
- 複数の進捗指標を使用
- 修正作業も「進捗」として認識

---

## 📞 サポート情報

**問題が解決しない場合**:

1. **ログ確認**:
   ```bash
   # 最新セッションログ
   cat automation/.session_147_output.log

   # 自動化ログ
   tail -100 automation/retranslation-automation.log
   ```

2. **進捗ファイル確認**:
   ```bash
   cat translation/.retranslation_progress.json | jq .
   ```

3. **Git状態確認**:
   ```bash
   git status
   git log --oneline -10
   ```

4. **関連ドキュメント**:
   - `AUTOMATION_ISSUE_REPORT.md` - 問題の詳細分析
   - `CLAUDE.md` - プロジェクト全体のガイド
   - `translation/RETRANSLATION_WORKFLOW.md` - 翻訳ワークフロー

---

**最終更新**: 2025-11-10
**次回見直し**: 修正フェーズ完了時
