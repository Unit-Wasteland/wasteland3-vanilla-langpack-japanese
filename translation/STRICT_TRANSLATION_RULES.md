# 厳格な翻訳作業ルール (Strict Translation Rules)

**作成日:** 2025-10-29
**バージョン:** 3.0 (完全やり直し - 2回目)

## 目的

このドキュメントは、構造破壊を絶対に防止し、ゲームの動作を保証するための**厳格な翻訳ルール**を定義します。

---

## Phase 0: 前提条件

### 参照ファイル

1. **英語ソース（構造の基準）:**
   - `translation/source/v1.6.9.420.309496/en_US/StringTableData_English-CAB-*.txt`
   - 総行数: 530,425行
   - 総エントリ数: 169,712エントリ

2. **スペイン語ソース（翻訳可否の判断基準）:**
   - `translation/source/v1.6.9.420.309496/es_ES/StringTableData_Spanish-CAB-*.txt`
   - スペイン語で翻訳されている → 日本語でも翻訳可能
   - スペイン語で英語のまま / 空文字列 → 日本語でも英語のまま / 翻訳禁止

3. **用語集:**
   - `translation/nouns_glossary.json`
   - 固有名詞、技術用語の一貫した翻訳のため

---

## Part 1: Unity StringTable構造の完全理解

### 1.1 基本構造

```
string data = "content"
```

**重要:** `string data = ` の後の引用符 `"` は文字列デリミタです。

### 1.2 引用符のパターン

Unity StringTable形式では、引用符の数が意味を持ちます：

#### パターンA: 引用符2個（シンプルなテキスト）

```
string data = "Simple text"
```

- 最初の `"` = 文字列の開始デリミタ
- 最後の `"` = 文字列の終了デリミタ
- 内容に引用符は含まれない

**例:**
```
string data = "Script Node 65"
string data = "End the call."
string data = "::screams::"
```

#### パターンB: 引用符4個（引用符で囲まれたテキスト）

```
string data = ""Quoted text""
```

- 1番目の `"` = 文字列の開始デリミタ
- 2番目の `"` = テキスト内の開始引用符（エスケープ）
- 3番目の `"` = テキスト内の終了引用符（エスケープ）
- 4番目の `"` = 文字列の終了デリミタ

**例:**
```
string data = ""Hey, cowboys, it's Dead Red talkin' at you again.""
string data = ""I'll bet.""
string data = ""...""
```

#### パターンC: 引用符6個以上（複雑なケース）

```
string data = "::static:: "... Come in..." ::static:: "... This is..." ::static::"
```

複数の引用符付きセグメントが含まれるケース。各セグメントの引用符ペアを正確に保持する必要があります。

---

## Part 2: 翻訳可否の厳格な判断基準

### 2.1 絶対に翻訳してはいけないもの

以下は**ゲームプログラムで使用される技術的な文字列**であり、変更するとゲームが動作しなくなります：

#### 禁止1: スクリプトノード識別子

```
❌ 翻訳禁止: string data = "Script Node 65"
✅ そのまま: string data = "Script Node 65"
```

**理由:** スペイン語版でも英語のまま（または空文字列）

#### 禁止2: デバッグマーカー

```
❌ 翻訳禁止: string data = "[DEBUG} Get Module?"
✅ そのまま: string data = "[DEBUG} Get Module?"
```

**理由:** スペイン語版で空文字列

#### 禁止3: ゲーム変数・ID

```
❌ 翻訳禁止: [Global: A1001_GeneralMerchantDiscounrt]
❌ 翻訳禁止: [Dropset: DRP_Reward_o2101_QuarexHellaciousJourney]
✅ そのまま: [Global: A1001_GeneralMerchantDiscounrt]
✅ そのまま: [Dropset: DRP_Reward_o2101_QuarexHellaciousJourney]
```

**理由:** ゲーム内部で使用される変数名・ID

#### 禁止4: HTML/XMLタグ

```
❌ 翻訳禁止: <i>text</i>
✅ 保持: <i>翻訳されたテキスト</i>
```

**注意:** タグ自体は保持し、タグ内のテキストのみ翻訳

### 2.2 翻訳してもよいもの

スペイン語版で翻訳されているものは、日本語でも翻訳可能です：

#### 翻訳可能1: 通常の会話文・説明文

```
EN: string data = ""Hey, cowboys, it's Dead Red talkin' at you again.""
ES: string data = ""Eh, vaqueros, aquí Rojo Muerto al habla.""
✅ JA: string data = ""よう、カウボーイたち。デッド・レッドだ。""
```

#### 翻訳可能2: ユーザー向けラベル

```
EN: string data = "[Ranger Allegiance: ...]"
ES: string data = "[Lealtad de Ranger: ...]"
✅ JA: string data = "[レンジャーとの同盟: ...]"
```

**注意:** ラベル部分のみ翻訳、変数名（[Global:...]など）は英語のまま

#### 翻訳可能3: アクションマーカー

```
EN: string data = "::sighs:: "I'll bet.""
ES: string data = "::suspira:: "Desde luego"."
✅ JA: string data = "::sigh:: "だろうな""
```

**注意:** アクションマーカー自体は英語のまま推奨（::sighs::）

### 2.3 重要: スペイン語が空の場合の処理

**⚠️ CRITICAL RULE - 構造破壊の主要原因**

スペイン語参照ファイルで該当エントリが空文字列 (`string data = ""`) の場合の処理:

#### ❌ 絶対禁止: 日本語ファイルも空にする

```
EN: string data = ""We arrested him. He's in our custody.""  (4個の引用符)
ES: string data = ""  (2個の引用符 - 空)
❌ JA: string data = ""  (2個の引用符 - 空) → 構造破壊！引用符の数が不一致
```

**理由:**
- スペイン語が空 = 「翻訳不要」を意味する
- しかし、**空にする = テキストを削除する** ではない
- 引用符の数が変わるため構造検証エラーになる

#### ✅ 正解: 英語テキストをそのまま保持

```
EN: string data = ""We arrested him. He's in our custody.""  (4個の引用符)
ES: string data = ""  (2個の引用符 - 空)
✅ JA: string data = ""We arrested him. He's in our custody.""  (4個の引用符 - 英語保持)
```

**理由:**
- 引用符の数が英語ソースと一致（4個 → 4個）
- テキスト内容は英語のままだが、構造は保持される
- ゲームは正常に動作し、英語テキストが表示される

#### 判断フロー

```
スペイン語ファイルを確認
  ├─ 翻訳されている → 日本語でも翻訳する
  ├─ 英語のまま → 日本語でも英語のまま保持
  └─ 空文字列 ("") → 日本語でも英語のまま保持（削除しない！）
```

#### 実際の例（Session 125のエラーケース）

```bash
# Line 134280のケース
EN: string data = ""We arrested him. He's in our custody, and that's where he's going to stay.""
ES: string data = ""

# ❌ 誤った対応（構造破壊）
JA: string data = ""
→ 引用符: EN=4個、JA=2個 → QUOTE_COUNT_MISMATCH エラー

# ✅ 正しい対応（構造保持）
JA: string data = ""We arrested him. He's in our custody, and that's where he's going to stay.""
→ 引用符: EN=4個、JA=4個 → 検証成功
```

**教訓:**
- **スペイン語が空 ≠ テキストを削除する**
- **翻訳しない = 英語テキストを保持する**
- **構造（引用符の数）を絶対に変更しない**

---

## Part 3: 作業手順（絶対厳守）

### 3.1 作業開始前の準備

#### ステップ1: 英語ソースから完全コピー

```bash
# 現在のtargetをバックアップ
cp -r translation/target/v1.6.9.420.309496/ja_JP/ /tmp/backup_before_restart_$(date +%Y%m%d_%H%M%S)/

# 英語ソースを完全コピー
cp translation/source/v1.6.9.420.309496/en_US/StringTableData_English-CAB-*.txt \
   translation/target/v1.6.9.420.309496/ja_JP/

# 行数を検証
wc -l translation/source/v1.6.9.420.309496/en_US/*.txt
wc -l translation/target/v1.6.9.420.309496/ja_JP/*.txt
# → 必ず一致すること（530,425行）
```

#### ステップ2: 用語集の確認

`translation/nouns_glossary.json` を確認し、固有名詞・技術用語の翻訳を統一します。

### 3.2 翻訳作業の手順（1エントリごと）

#### ステップ1: 英語ソースを読む

```bash
# 例: 行666を翻訳する場合
sed -n '666p' translation/source/v1.6.9.420.309496/en_US/StringTableData_English-CAB-*.txt
```

#### ステップ2: スペイン語ソースで翻訳可否を確認

```bash
# 同じ行番号で確認
sed -n '666p' translation/source/v1.6.9.420.309496/es_ES/StringTableData_Spanish-CAB-*.txt
```

- スペイン語で翻訳されている → 翻訳可能
- スペイン語で英語のまま / 空 → 翻訳禁止

#### ステップ3: 引用符の数を確認

```bash
# 引用符の数をカウント
sed -n '666p' translation/source/v1.6.9.420.309496/en_US/StringTableData_English-CAB-*.txt | tr -cd '"' | wc -c
```

- 2個 → シンプルなテキスト
- 4個 → 引用符で囲まれたテキスト
- 6個以上 → 複雑なケース（各引用符ペアを保持）

#### ステップ4: Edit操作で翻訳

**重要:** `old_string` と `new_string` で**引用符の数を絶対に変更しない**

**正しい例（引用符4個 → 4個）:**
```python
old_string = '        1 string data = ""Hey, cowboys, it\'s Dead Red talkin\' at you again.""'
new_string = '        1 string data = ""よう、カウボーイたち。デッド・レッドだ。""'
#                                      ↑↑                                      ↑↑
#                                      引用符4個を保持
```

**誤った例（引用符4個 → 2個）:**
```python
❌ new_string = '        1 string data = "よう、カウボーイたち。デッド・レッドだ。"'
#                                        ↑                                    ↑
#                                        引用符2個に減少 → 構造破壊！
```

#### ステップ5: 即座に検証

Edit操作の**直後**に以下を確認：

```bash
# 1. 行数が変わっていないか
wc -l translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-*.txt
# → 530,425行を維持

# 2. 引用符の数が変わっていないか
sed -n '666p' translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-*.txt | tr -cd '"' | wc -c
# → 元の英語と同じ数を維持（例: 4個）

# 3. git diffで確認
git diff translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-*.txt | grep -A2 -B2 "^@@.*666"
```

---

## Part 4: 検証方法（各段階で必須）

### 4.1 各Edit操作後の即時検証（必須）

```bash
# スクリプトを使用
python3 translation/validate_structure.py \
    translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-*.txt \
    --source translation/source/v1.6.9.420.309496/en_US/StringTableData_English-CAB-*.txt
```

**エラーが1件でもあれば即座に修正**

### 4.2 10エントリごとの検証（必須）

```bash
# 引用符の数を全行で比較
cat << 'EOF' > /tmp/verify_quotes.sh
#!/bin/bash
EN="/home/claude/work/project-claude/wasteland3-vanilla-langpack-japanese/translation/source/v1.6.9.420.309496/en_US/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt"
JA="/home/claude/work/project-claude/wasteland3-vanilla-langpack-japanese/translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt"

grep -n 'string data = ' "$EN" | while IFS=: read -r line_num line_content; do
    en_quotes=$(echo "$line_content" | tr -cd '"' | wc -c)
    ja_line=$(sed -n "${line_num}p" "$JA")
    ja_quotes=$(echo "$ja_line" | tr -cd '"' | wc -c)

    if [ "$en_quotes" -ne "$ja_quotes" ]; then
        echo "ERROR Line $line_num: EN=$en_quotes quotes, JA=$ja_quotes quotes"
        echo "  EN: $line_content"
        echo "  JA: $ja_line"
    fi
done
EOF

bash /tmp/verify_quotes.sh
```

### 4.3 コミット前の最終検証（必須）

```bash
# 1. 行数の一致
wc -l translation/source/v1.6.9.420.309496/en_US/*.txt
wc -l translation/target/v1.6.9.420.309496/ja_JP/*.txt
# → 完全一致すること

# 2. 構造検証スクリプト
python3 translation/validate_structure.py \
    translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-*.txt \
    --source translation/source/v1.6.9.420.309496/en_US/StringTableData_English-CAB-*.txt \
    --detailed

# 3. git diffで変更内容を確認
git diff translation/target/v1.6.9.420.309496/ja_JP/ | less
# → 構造（引用符、マーカー）が変更されていないことを確認
```

---

## Part 5: 絶対禁止事項

### 禁止1: 効率化のためのルール簡略化

❌ **絶対禁止:**
- 「長文だけを優先して翻訳」
- 「この部分は後回し」
- 「とりあえずスクリプトで一括処理」

✅ **必須:**
- 1行目から順番に翻訳
- 全てのエントリを同じルールで処理
- スキップせず、完全に翻訳

### 禁止2: スクリプトによる一括処理

❌ **絶対禁止:**
- 自動修正スクリプトの実行
- バッチ処理
- 複数行を一度にEdit

✅ **必須:**
- 1エントリずつ手作業でEdit
- 各Edit後に即座に検証
- 問題があれば即座に修正

### 禁止3: 検証の省略

❌ **絶対禁止:**
- 「まとめて検証」
- 「コミット前にまとめてチェック」
- 「問題なさそうだから検証スキップ」

✅ **必須:**
- 各Edit操作後に即座に検証
- 10エントリごとに構造検証
- コミット前に最終検証

---

## Part 6: エラー発生時の対応

### 6.1 構造エラーを発見した場合

**即座に作業を停止し、以下を実行:**

```bash
# 1. 変更を破棄して英語ソースから再コピー
git checkout -- translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-*.txt

# 2. 英語ソースから再度コピー
cp translation/source/v1.6.9.420.309496/en_US/StringTableData_English-CAB-*.txt \
   translation/target/v1.6.9.420.309496/ja_JP/

# 3. 最初からやり直す
```

### 6.2 引用符の数が合わない場合

**原因の特定:**
1. old_stringとnew_stringで引用符の数が異なる
2. テキスト内の引用符を削除または追加してしまった
3. エスケープシーケンスを誤って変更した

**対処:**
- 該当行を英語ソースから再コピー
- 引用符の数を正確にカウントしてから再Edit

---

## Part 7: 作業記録

### 7.1 コミットメッセージの形式

```
Translation: Lines X-Y (Z entries)

- Translated X entries from line A to line B
- All structure validation passed
- Quote counts match source file
- No game variables modified

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

### 7.2 進捗管理

`translation/.retranslation_progress.json` を更新：

```json
{
  "last_update": "2025-10-29",
  "current_line": 1000,
  "entries_completed": 50,
  "last_validated": "2025-10-29 18:00:00",
  "validation_status": "PASSED",
  "errors_found": 0
}
```

---

## Part 8: チェックリスト

### 各Edit操作後（必須）

- [ ] 行数が変わっていない（530,425行維持）
- [ ] 引用符の数が英語ソースと一致
- [ ] 構造マーカー（[]、<>、::）が保持されている
- [ ] ゲーム変数（[Global:...]など）が変更されていない
- [ ] git diffで変更内容を確認

### 10エントリごと（必須）

- [ ] `validate_structure.py` を実行してエラー0件
- [ ] 引用符の数を全行で比較して一致
- [ ] スペイン語版と比較して翻訳可否が適切

### コミット前（必須）

- [ ] 行数がソースファイルと完全一致
- [ ] 構造検証スクリプトでエラー0件
- [ ] git diffで構造変更がないことを確認
- [ ] 翻訳禁止項目が変更されていないことを確認

---

**このルールは絶対に遵守すること。例外は一切認めません。**

---

作成者: Claude Code
最終更新: 2025-10-29
