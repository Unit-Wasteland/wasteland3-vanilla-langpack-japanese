# Base Game 翻訳再開計画

**作成日**: 2025-11-11
**優先度**: 🔴 CRITICAL - 最優先
**状態**: DLC1作業一時停止、Base game完了まで専念

## 現状サマリー

### 検証済み進捗状況 (2025-11-11)

**Base game**:
- **実際の完了率**: 67.2% (28,567/42,499 non-empty entries)
- **未翻訳**: 11,711 エントリ (27.6%)
- **部分翻訳**: 574 エントリ (1.4%)
- **合計問題数**: 12,285 エントリ

**DLC1** (作業一時停止):
- 完了率: 64.8% (7,586/11,710)
- 問題数: 3,488 エントリ
- 状態: PAUSED_FOR_BASE_GAME

**全体**:
- 完了率: 46.1% (36,153/78,361)
- 残り問題: 15,773 エントリ

## 作業方針

### 優先順位 (STRICT)

1. **Base game 12,285エントリ完了** ← 最優先
2. validate_completion.py で100%検証
3. その後DLC1再開
4. 最後にDLC2

### Base game作業アプローチ

#### Option A: 未翻訳エントリリストから順次処理 (推奨)

**利点**:
- 明確な進捗追跡
- 漏れがない
- 効率的

**実施方法**:
1. `translation/base_game_untranslated_entries.txt` を使用
2. リストの上から順に処理
3. 150-200行チャンクで翻訳
4. 各チャンク後に検証実施

**作業量見積もり**:
- 12,285 エントリ / 500 エントリ/session ≈ **25 sessions**
- 想定期間: 2-3日（自動化スクリプト使用時）

#### Option B: ファイル全体を再スキャン

**利点**:
- コンテキストを保ちやすい
- 周辺の翻訳との整合性確保

**欠点**:
- 既翻訳部分も読み込むため非効率
- メモリ使用量が大きい

### 推奨: Option A (リストベース)

理由:
- 12,285エントリに集中できる
- 進捗が明確
- メモリ効率が良い
- 完了判定が容易

## 作業手順 (詳細)

### ステップ1: 準備

```bash
# 1. 未翻訳エントリリストの確認
head -50 translation/base_game_untranslated_entries.txt

# 2. English source file の準備（参照用）
# translation/source/v1.6.9.420.309496/en_US/StringTableData_English-CAB-*.txt

# 3. Spanish reference file の準備（翻訳判定用）
# translation/source/v1.6.9.420.309496/es_ES/StringTableData_Spanish-CAB-*.txt

# 4. Glossary の確認
# translation/nouns_glossary.json
```

### ステップ2: 翻訳実行 (1セッションあたり)

**対象**: 500エントリ (リストの上から順に)

**プロセス**:
1. リストから次の500エントリの行番号を取得
2. 各行番号について:
   - Target fileの該当行を読み込み
   - English sourceから元テキスト確認
   - Spanish referenceで翻訳判定
   - Glossaryで固有名詞確認
   - 日本語翻訳を適用
   - Structure protection (""マーカー保持)

3. 編集後、即座に検証:
   ```bash
   # Structure validation
   python3 translation/validate_structure_v2.py <target> --source <source> --detailed

   # Quality validation (該当範囲のみ)
   python3 translation/validate_translation_quality.py <target> \
     --start-line <first_line> --end-line <last_line>

   # Action marker check
   grep -o '::[^:]*[ぁ-ゖァ-ヾ一-龯][^:]*::' <target>
   # Expected: 空出力（何も表示されない）
   ```

4. 検証パス後、コミット:
   ```bash
   git add <target_file> translation/base_game_untranslated_entries.txt
   git commit -m "Base game: Translated 500 entries (lines X-Y)"
   ```

5. 進捗更新 (.retranslation_progress.json):
   - entries_translated を更新
   - entries_untranslated を更新
   - completion_rate を再計算

### ステップ3: セッション完了後の検証

**毎セッション終了時**:
```bash
# 残り未翻訳数の確認
python3 translation/validate_completion.py \
  translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-*.txt
```

**期待する出力の変化**:
- Session 1終了後: 11,711 → 11,211 (500減少)
- Session 2終了後: 11,211 → 10,711 (500減少)
- ...
- Session 25終了後: 211 → 0 (**完了**)

### ステップ4: 完了確認 (CRITICAL)

**100%完了と主張する前に、以下を必ず実行**:

```bash
# 1. Completion validation (MUST PASS)
python3 translation/validate_completion.py \
  translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-*.txt

# Expected output:
# ✅ PASS: File is 100% complete!
# Exit code: 0

# 2. Structure validation (MUST PASS)
python3 translation/validate_structure_v2.py \
  translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-*.txt \
  --source translation/source/v1.6.9.420.309496/en_US/StringTableData_English-CAB-*.txt \
  --detailed

# Expected output:
# Total errors: 0

# 3. Quality validation (MUST PASS)
python3 translation/validate_translation_quality.py \
  translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-*.txt \
  --start-line 1 --end-line 999999 \
  --glossary translation/nouns_glossary.json

# Expected output:
# Total issues found: 0
```

**すべての検証がPASS (0 errors, 0 issues, exit code 0) の場合のみ**:
- 進捗ファイル更新: status → "completed"
- コミット: "Base game 100% VERIFIED complete"

## 作業中の注意事項

### 翻訳ルール (厳守)

1. **Structure protection**:
   - `""` マーカーは絶対に変更しない
   - 日本語括弧 `「」`、`『』` に変換しない
   - `\n`, `\r`, `\t` は保持

2. **Action markers**:
   - `::action::` は英語のまま（日本語に翻訳しない）
   - 編集後必ず確認: `grep '::[^:]*[ぁ-ゖァ-ヾ一-龯]' <file>`

3. **Technical terms**:
   - "Script Node" は翻訳しない
   - nouns_glossary.json の do_not_translate リストを遵守

4. **Glossary遵守**:
   - 固有名詞は必ずglossaryを参照
   - 一貫性を保つ（例: Rangers = "レンジャー"）

5. **Spanish reference**:
   - Spanish == "" または Spanish == English の場合でも翻訳する
   - Do_not_translate リストにない限り翻訳

### 自動化スクリプト使用（推奨）

既存の `automation/auto-retranslate.sh` は使用不可（DLC1用に設定済み）。

Base game用の自動化は手動セッションで実施するか、専用スクリプトを作成。

**手動セッションの場合**:
- 1セッションあたり500エントリを目標
- メモリ制限: 5000MB
- 定期的にgit commit (500エントリごと)

## 進捗追跡

### 進捗ファイル更新頻度

- **毎セッション終了時**: .retranslation_progress.json 更新
- **毎500エントリ**: git commit
- **毎日**: 進捗レポート確認

### 進捗確認コマンド

```bash
# 現在の完了率
python3 translation/validate_completion.py \
  translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-*.txt \
  | grep "completion_rate"

# 残り未翻訳数
grep "❌ English only:" translation/base_game_completion_report.txt

# 進捗ファイル確認
jq '.files.base_game.completion_rate' translation/.retranslation_progress.json
```

## 完了基準 (再発防止)

### 100%完了の定義

以下の**すべて**を満たす場合のみ100%完了:

1. ✅ `validate_completion.py` → Exit code 0
2. ✅ `validate_structure_v2.py` → Total errors: 0
3. ✅ `validate_translation_quality.py` → Total issues: 0
4. ✅ 手動確認: git diff で構造変更なし
5. ✅ 手動確認: action markerに日本語なし

**一つでも失敗したら100%ではない。**

### コミットメッセージ形式

**途中経過**:
```
Base game: Translated 500 entries (lines 1462-5832)

Session details:
- Entries: 500 (Asphalt G dialogue, radio calls, mission briefings)
- Lines: 1462-5832
- Validations: Structure 0 errors, Quality 0 issues
- Progress: 29,067/42,499 (68.4%)
- Remaining: 11,211 untranslated

🤖 Generated with [Claude Code](https://claude.com/claude-code)
Co-Authored-By: Claude <noreply@anthropic.com>
```

**完了時**:
```
Base game: 100% VERIFIED complete (42,499/42,499 entries)

VERIFICATION RESULTS (2025-11-XX):
✅ validate_completion.py: PASS (exit code 0)
✅ validate_structure_v2.py: 0 errors
✅ validate_translation_quality.py: 0 issues
✅ Action markers: All preserved in English
✅ Glossary: All terms consistent

Translation summary:
- Total entries: 42,499
- Japanese only: 42,499 (100%)
- Untranslated: 0
- Issues: 0

Next phase: DLC1 resumption (currently 64.8% complete)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
Co-Authored-By: Claude <noreply@anthropic.com>
```

## タイムライン

### 想定スケジュール

**自動化使用時**:
- 12,285 エントリ / 500 エントリ/session ≈ 25 sessions
- 想定期間: 2-3日

**手動セッション**:
- 1セッション: 500エントリ (約60分)
- 25セッション × 60分 = 1,500分 (25時間)
- 想定期間: 3-5日（1日5時間作業の場合）

### マイルストーン

1. **25%完了** (3,071エントリ): ~6 sessions
2. **50%完了** (6,143エントリ): ~12 sessions
3. **75%完了** (9,214エントリ): ~18 sessions
4. **100%完了** (12,285エントリ): ~25 sessions ← **ゴール**

## リスク管理

### 潜在的リスク

1. **メモリ不足**:
   - 対策: 150-200行チャンク処理
   - モニタリング: 30秒ごとにメモリチェック

2. **検証失敗**:
   - 対策: 各チャンク後に即座に検証
   - 失敗時: 即座に修正、再検証

3. **進捗追跡ミス**:
   - 対策: 自動検証スクリプト使用
   - 手動カウント廃止

4. **翻訳品質低下**:
   - 対策: Glossary厳守
   - Spanish reference活用
   - Quality validation必須

## 次のステップ

### 即座に開始

1. ✅ 進捗ファイル修正完了
2. ✅ 検証スクリプト作成完了
3. ✅ 未翻訳エントリリスト作成完了
4. ⏭️ **翻訳作業開始**

### 開始コマンド

```bash
# セッション開始
cd /path/to/wasteland3-vanilla-langpack-japanese

# 未翻訳リスト確認
head -500 translation/base_game_untranslated_entries.txt

# 最初のバッチ（Line 1462から開始）
# 英語ソース、スペイン語参照、Glossaryを参照しながら翻訳
# ...

# 検証
python3 translation/validate_completion.py \
  translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-*.txt

# コミット（検証パス後）
git add .
git commit -m "Base game: Translated 500 entries (lines 1462-XXXX)"
```

---

**このプランに従い、Base game 100%完了を最優先で達成します。**

**作成者**: Claude Code (Sonnet 4.5)
**承認**: ユーザー指示 (Base game最優先)
