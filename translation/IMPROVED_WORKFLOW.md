# 改善された翻訳ワークフロー

## 概要

以前のワークフローでは、各セクション完了後のチェックが不十分で、未翻訳箇所が散在する問題がありました。
この改善されたワークフローは、**必須の検証ステップ**を導入し、100%の完了を保証します。

## 問題点の分析（2025-10-29）

### 発見された問題
- 本体ファイル: **10,457件の未翻訳箇所**が散在（完了率93.8%）
- 未翻訳の89%が**行300,001-450,000に集中**
- DLCに本体完了前に着手（手戻り発生）
- 進捗記録が実態と乖離（記録: 51,853エントリ、実際: 169,752エントリ）

### 根本原因
1. **検証の欠如**: 翻訳後の自動検証を実施していなかった
2. **散在する未翻訳**: 大きなセクションではなく、数エントリずつの見落とし
3. **進捗管理の不正確**: エントリ数のカウント方法が不適切
4. **優先順位の誤り**: 本体完了前にDLC着手

## 改善されたワークフロー

### Phase 1: 準備

1. **進捗状況の確認**
   ```bash
   cat translation/.retranslation_progress.json
   ```

2. **現在の処理位置の確認**
   - 現在: **行51,540から継続**（セクション2進行中）
   - アプローチ: **先頭から順次処理、各セクション100%完了してから次へ**

### Phase 2: 翻訳実施（厳格化）

#### ステップ1: セクション翻訳

**セクションサイズ**: 150-200行ずつ処理

```bash
# 重要: 先頭から順次処理（優先箇所にジャンプしない）
# 現在: 行51,540から継続
# 1. backup_brokenファイルから日本語を抽出
# 2. targetファイルに構造保護しながら適用
# 3. 未翻訳エントリは新規翻訳
```

#### ステップ2: 構造検証（即座実行）

翻訳完了後、**即座に**以下を確認：

```bash
# 行数が一致しているか
wc -l target_file
wc -l source_file

# 構造マーカーが壊れていないか
grep -n '「」\|『』' target_file  # これらが見つかったらNG
```

#### ステップ3: 未翻訳検証（必須）

**必ず実行**（このステップをスキップしてはいけない）：

```bash
# セクション全体を検証
./translation/validate_translation.py \
  translation/target/.../ja_JP/StringTableData_*.txt \
  --start-line 300001 \
  --end-line 300200 \
  --detailed
```

**合格基準**:
- 未翻訳: **0件**
- 完了率: **100%**

**不合格の場合**:
- 検証スクリプトが表示した未翻訳箇所をすべて修正
- ステップ2から再実行
- 合格するまで次のセクションに進まない

#### ステップ4: コミット（500エントリごと）

```bash
# 500エントリ完了時にコミット
git add translation/target/.../ja_JP/StringTableData_*.txt
git add translation/.retranslation_progress.json

git commit -m "Retranslation: base_game lines 300001-302000 complete (XXX entries)

- Translated XXX entries in section mission_XXXX
- Validation: 100% complete, 0 untranslated
- Structure markers preserved

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

#### ステップ5: 進捗更新

```json
// .retranslation_progress.json を更新
{
  "files": {
    "base_game": {
      "current_line": 302000,
      "entries_translated": 159500,  // 更新
      "entries_untranslated": 10257,  // 更新
      "completion_rate": 94.0  // 更新
    }
  }
}
```

### Phase 3: セクション完了後の全体検証

大きなセクション（50,000行）完了後、**全体を再検証**：

```bash
# 行1-50000の全体検証
./translation/validate_translation.py \
  translation/target/.../ja_JP/StringTableData_*.txt \
  --start-line 1 \
  --end-line 50000 \
  --detailed \
  --export untranslated_section1.txt
```

未翻訳が見つかった場合:
1. エクスポートされたリストを確認
2. すべての未翻訳箇所を修正
3. 再度全体検証を実行
4. 100%完了を確認してから次へ

### Phase 4: ファイル完了確認

本体ファイル全体完了前に、**最終検証**を実施：

```bash
# ファイル全体の最終検証
./translation/validate_translation.py \
  translation/target/.../ja_JP/StringTableData_*.txt \
  --detailed \
  --export final_untranslated.txt
```

**本体ファイル完了の条件**:
- 未翻訳: **0件**
- 完了率: **100.0%**
- 行数: source と target が一致

この条件を満たすまで、DLCには着手しない。

## 検証スクリプトの使用方法

### 基本的な使用

```bash
# ファイル全体を検証
./translation/validate_translation.py target_file.txt

# セクションを指定して検証
./translation/validate_translation.py target_file.txt --start-line 300001 --end-line 350000

# 詳細表示（未翻訳箇所をリスト）
./translation/validate_translation.py target_file.txt --detailed

# 未翻訳箇所をエクスポート
./translation/validate_translation.py target_file.txt --export untranslated.txt
```

### 出力の見方

```
============================================================
翻訳検証結果
============================================================
総エントリ数: 15,000
  - 翻訳済み: 14,800
  - 未翻訳: 200
  - 空文字列: 5,000
  - 技術用語: 500

完了率: 98.67%

⚠️  警告: 200件の未翻訳箇所があります

未翻訳エントリ一覧（最初の50件）:
------------------------------------------------------------
 305123: This is untranslated dialogue.
 307456: Another untranslated entry.
...
============================================================
```

## 自動化スクリプトへの統合

`automation/auto-retranslate.sh` に検証ステップを追加：

```bash
# 翻訳実施後、コミット前に検証
python3 translation/validate_translation.py \
  "$TARGET_FILE" \
  --start-line $START_LINE \
  --end-line $END_LINE

# 検証失敗（未翻訳あり）の場合は終了
if [ $? -ne 0 ]; then
  echo "❌ 検証失敗: 未翻訳箇所があります"
  exit 1
fi

# 検証成功の場合のみコミット
git commit -m "..."
```

## 品質保証チェックリスト

各コミット前に確認：

- [ ] 検証スクリプトを実行した
- [ ] 未翻訳: 0件
- [ ] 行数: source と target が一致
- [ ] 構造マーカー: `""`, `[]`, `<>`, `::action::` が壊れていない
- [ ] 日本語括弧: `「」`, `『』` が構造部分に混入していない
- [ ] 進捗ファイル: current_line, entries_translated, entries_untranslated を更新

## 優先順位

### 現在の作業順序（2025-10-29時点）- 修正版

**重要: 優先順位は廃止。先頭から順次処理のみ。**

1. **セクション1（行1-50,000）**: ✅ 完了（開発メッセージ5件を除く）
2. **セクション2（行50,001-100,000）**: 🔄 進行中（50/342件翻訳済み）
   - 次の処理開始位置: 行51,540
3. **セクション3-11**: 順次処理予定
   - セクション2が100%完了してから着手
4. **DLC1, DLC2**: 保留
   - 本体ファイルが100%完了するまで着手しない

## まとめ

**改善の核心**:
- **検証を必須化**: 翻訳後、必ず検証スクリプトを実行
- **100%ルール**: 未翻訳0件を確認してから次へ進む
- **自動化**: 検証を自動化スクリプトに組み込む

この改善されたワークフローにより、未翻訳箇所の見落としを防ぎ、高品質な翻訳を保証します。
