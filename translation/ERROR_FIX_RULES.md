# エラー修正時の厳格対応ルール (ERROR FIX RULES)

## 🔴 最重要原則

**エラー修正時は、通常の翻訳作業以上に厳格なルールを適用する**

理由：エラー修正中に新たなルール違反を犯しやすい（効率重視、一括処理の誘惑）

---

## ❌ 絶対禁止事項（ZERO TOLERANCE）

### 1. 一括修正スクリプトの使用
```bash
# ❌ 絶対にやってはいけない
sed -i 's/pattern/replacement/g' file.txt
awk '{gsub(/pattern/, "replacement")}' file.txt
python bulk_fix.py
```

**理由：**
- 構造破壊のリスク（予期しない置換）
- 検証を飛ばす可能性
- 新たなエラー発生の温床

**正しい方法：**
- Editツールで1行ずつ修正
- 各修正後に検証実行
- 進捗をTodoWriteで追跡

### 2. バッチ処理（複数エントリの同時修正）
```python
# ❌ 絶対にやってはいけない
for line in error_lines:
    fix_line(line)  # ループで一括修正
```

**正しい方法：**
```
1つ目のエラーを読む → 修正 → 検証 → 完了マーク
2つ目のエラーを読む → 修正 → 検証 → 完了マーク
...
```

### 3. 検証の省略・遅延
```bash
# ❌ 絶対にやってはいけない
fix_error_1()
fix_error_2()
fix_error_3()
validate_all()  # まとめて検証
```

**正しい方法：**
```
fix_error_1() → validate() → ✓
fix_error_2() → validate() → ✓
fix_error_3() → validate() → ✓
```

### 4. 推測・憶測による修正
```
# ❌ たぶんこうだろう → 修正 → エラー再発
```

**正しい方法：**
```
1. ソースファイルを読んで正確な内容を確認
2. エラーメッセージを正確に理解
3. 修正内容を検証
4. Editツールで修正
5. 検証スクリプトで確認
```

---

## ✅ 必須手順（MANDATORY WORKFLOW）

### Step 1: エラー内容の完全把握
```bash
# 検証スクリプトを実行し、全エラーを確認
python3 translation/validate_structure_v2.py TARGET_FILE \
  --source SOURCE_FILE --detailed > /tmp/errors.txt

# エラー数を確認
grep "Total errors:" /tmp/errors.txt

# エラー詳細を確認（全件）
cat /tmp/errors.txt
```

**チェックポイント：**
- [ ] 総エラー数を把握
- [ ] エラーの種類を分類（QUOTE_COUNT_MISMATCH, LINE_COUNT_MISMATCH, etc.）
- [ ] 各エラーの行番号をリスト化
- [ ] 各エラーのソース・ターゲット比較を確認

### Step 2: TodoWriteで修正計画を作成
```json
[
  {"content": "Fix line 168460 quote mismatch", "status": "pending"},
  {"content": "Fix line 168586 quote mismatch", "status": "pending"},
  {"content": "Fix line 168598 quote mismatch", "status": "pending"},
  ...
]
```

**ルール：**
- 1エラー = 1タスク
- 具体的な行番号を記載
- エラー種別を記載

### Step 3: 1つずつ手動修正
```
For each error:
  1. Read SOURCE_FILE at error line (確認)
  2. Read TARGET_FILE at error line (現状確認)
  3. Identify exact problem (問題特定)
  4. Prepare correct text (修正内容準備)
  5. Edit TARGET_FILE with correct text (修正実行)
  6. Run validation on modified line (検証)
  7. Mark todo as completed (完了マーク)
```

**1修正あたりの制限時間：なし（正確性 > 速度）**

### Step 4: 修正後の全体検証
```bash
# 全エラーが0になるまで繰り返す
python3 translation/validate_structure_v2.py TARGET_FILE \
  --source SOURCE_FILE --detailed

# 期待される出力
Total errors: 0
```

**合格基準：**
- Total errors: 0（厳密にゼロ）
- 警告も0が望ましい

### Step 5: 品質検証
```bash
python3 translation/validate_translation_quality.py TARGET_FILE \
  --start-line START --end-line END \
  --spanish-reference SPANISH_FILE \
  --glossary translation/nouns_glossary.json

# 期待される出力
Total issues found: 0
```

**合格基準：**
- Total issues: 0（厳密にゼロ）
- 全4カテゴリで0件

### Step 6: コミット
```bash
# 修正内容を明確に記載
git add TARGET_FILE
git commit -m "Fix: Correct [ERROR_TYPE] errors ([N] instances fixed)

- Lines affected: [LINE_RANGE]
- Error type: [QUOTE_MISMATCH/LINE_COUNT/etc.]
- Root cause: [DESCRIPTION]
- Prevention: [MEASURES_TAKEN]

Validation:
- Structure errors: 0
- Quality issues: 0
"
```

---

## 📋 エラー種別ごとの修正ガイド

### QUOTE_COUNT_MISMATCH（引用符数不一致）

**原因パターン：**
1. **テキスト内の`"`を`「」`に変換してしまった**（最頻出）
   ```
   誤: string data = " この標識には「TEXT」と書かれている。"
   正: string data = " この標識には"TEXT"と書かれている。"
   ```

2. Unity StringTableフォーマット破壊
   ```
   誤: string data = "\"TEXT\""  (バックスラッシュエスケープ)
   正: string data = ""TEXT""     (ダブルダブルクォート)
   ```

**修正手順：**
1. ソースファイルで引用符の位置を確認
2. ターゲットで引用符を日本語括弧にしていないか確認
3. **引用符を保持したまま日本語テキストに修正**
4. 引用符の数がソースと一致することを確認

**検証コマンド：**
```bash
# 行番号NNNNNの引用符数をカウント
sed -n 'NNNNNp' SOURCE_FILE | grep -o '"' | wc -l
sed -n 'NNNNNp' TARGET_FILE | grep -o '"' | wc -l
# 両方の数が一致する必要あり
```

### BRACKET_CONTENT_TRANSLATED（括弧マーカー翻訳）

**原因：**
- `[Attack]`, `[Arrest]`, `[Global:]` などを日本語に翻訳

**修正手順：**
1. ソースファイルで元の括弧マーカーを確認
2. 英語のまま保持する
3. do_not_translate リストと照合

### ACTION_MARKER_TRANSLATED（アクションマーカー翻訳）

**原因：**
- `::sigh::`, `::laughs::` などを日本語に翻訳

**修正手順：**
1. ソースファイルで元のマーカーを確認
2. **英語のまま完全一致で保持**
3. 前後の日本語テキストのみ翻訳

---

## 🔍 修正後の必須チェックリスト

各エラー修正後、以下を確認：

- [ ] ソースファイルと行数が一致
- [ ] 引用符の数がソースと一致
- [ ] 括弧マーカー `[...]` が英語のまま
- [ ] アクションマーカー `::...::`が英語のまま
- [ ] HTMLタグ `<i>`, `</i>` が保持されている
- [ ] 変数 `[Global:...]` などが保持されている
- [ ] 日本語テキストに中国語が混入していない
- [ ] `\"` などのエスケープシーケンスを使用していない
- [ ] Structure validation: 0 errors
- [ ] Quality validation: 0 issues

---

## 📊 進捗報告フォーマット

```
エラー修正進捗:
- 総エラー数: 57件
- 修正完了: 10件 (17.5%)
- 残り: 47件
- 現在の作業: Line 168720 QUOTE_COUNT_MISMATCH修正中
- 検証状態: 修正済み10件すべて検証済み（0エラー）
```

---

## ⚠️ よくある失敗パターンと対策

### 失敗1: 「効率化」のために一括処理
**対策:** 「1エラー = 1修正サイクル」を厳守。速度は無視。

### 失敗2: エラーメッセージの誤読
**対策:** エラーメッセージを声に出して読み、ソースと比較。

### 失敗3: 検証を後回し
**対策:** 修正直後に必ず検証。検証なしでは次の修正に進まない。

### 失敗4: 修正内容の記録なし
**対策:** TodoWriteで各修正をマーク。コミットメッセージに詳細記載。

---

## 🎯 成功基準

**エラー修正作業の成功 =**
1. ✅ 全エラーが0
2. ✅ 新たなエラーが0
3. ✅ 全修正が検証済み
4. ✅ コミットメッセージに詳細記載
5. ✅ 再発防止策が文書化

**時間は問わない。正確性がすべて。**
