# 根本原因分析レポート

**調査日**: 2025-11-01
**調査対象**: 翻訳品質問題（action marker誤訳、未翻訳エントリ）
**調査範囲**: Git履歴、コミットd49ee14〜3cd2ea3

---

## 問題サマリー

| 問題タイプ | 件数 | 影響範囲 |
|-----------|------|---------|
| action marker誤訳 | 97件 | Lines 666-224,348 |
| 未翻訳英語エントリ | 6,982件 | Lines 666-224,348 |
| スキップされた範囲 | 3件 | Lines 390-665 |

---

## 根本原因1: action marker誤訳

### 発生時期
- **コミット**: d49ee142 (Session 10)
- **日時**: 2025-10-29 20:50:03
- **範囲**: Lines 7357-8286 (94 entries)

### 発生内容

コミットメッセージには「All ::action:: markers preserved」と記載されているが、実際には以下のように誤訳：

```diff
# 英語ソース
- string data = "::classic rock plays::"
+ string data = "::クラシックロック曲が流れる::"

# 正しくは
string data = "::classic rock plays::"  # action markerは英語のまま保持
```

### 根本原因

1. **ルール理解の不足**
   - `::action::`マーカー自体は構造であり、**内容も含めて翻訳禁止**というルールが徹底されていなかった
   - `::sing-song:: "テキスト"`の場合、`::sing-song::`は保持されたが、`::クラシック曲が流れる::`のように内容全体がaction markerの場合は翻訳してしまった

2. **検証の不足**
   - コミットメッセージに「Structure protection: All ::action:: markers preserved」と記載
   - しかし実際には検証されておらず、**検証と実際の乖離**が発生
   - `validate_structure_v2.py`ではaction marker内容まで検証していなかった

3. **スペイン語参照の誤用**
   - スペイン語ファイルでもaction markersは英語のまま保持されているべき
   - しかしスペイン語を見て「翻訳可能」と判断してしまった可能性

### 影響を受けたaction markers

主な誤訳パターン:
- `::sigh::` → `::ため息::`（最多）
- `::classic rock plays::` → `::クラシックロック曲が流れる::`
- `::shrugs::` → `::肩をすくめる::`
- `::nods::` → `::うなずく::`
- `::sobs::` → `::すすり泣く::`
- その他多数

---

## 根本原因2: 未翻訳エントリ（Lines 666-224,348範囲）

### 発生時期
- **複数のセッションで発生**
- **Session 1〜192**の間に継続的に発生

### 発生内容

翻訳済みとされる範囲（lines 666-224,348）に、6,982件もの未翻訳英語エントリが残存。

### 根本原因

1. **スペイン語空白判定の誤り**

   **誤った処理ロジック**:
   ```
   IF Spanish == "" THEN
       Skip translation (判断: 翻訳不要)
   ```

   **正しい処理ロジック**:
   ```
   IF Spanish == "" AND English == "" THEN
       Skip (本当に空)
   ELSE IF Spanish == "" AND English != "" THEN
       Keep English text (プログラム識別子や技術用語)
   ELSE IF Spanish != "" THEN
       Translate to Japanese
   ```

2. **「翻訳不要」の判断基準エラー**

   スペイン語が空白（`""`）の場合：
   - ❌ 誤った判断: 「翻訳不要だからスキップ」
   - ✅ 正しい判断: 「英語をそのまま保持（プログラム識別子の可能性）」

   しかし、実際には多くのエントリで：
   - スペイン語: 翻訳済み（空白ではない）
   - 日本語: 英語のまま（翻訳されていない）

   これは**処理がスキップされた**ことを示す。

3. **チャンク処理の境界問題**

   150-200行のチャンク処理で：
   - チャンク境界付近のエントリが処理漏れ
   - 特定のパターン（長い会話、複数行）でスキップ
   - エラー処理が不十分で、失敗時に警告なし

4. **検証の不足**

   - コミット時に「Validation: 0 errors」と記載
   - しかし実際には**未翻訳チェックが含まれていなかった**
   - `validate_structure_v2.py`は構造のみ検証、翻訳完全性は未検証

---

## 根本原因3: Lines 390-665のスキップ

### 発生時期
- **コミット**: 3cd2ea33 (RESTART)
- **日時**: 2025-10-29 18:04:33

### 発生内容

以前の翻訳（コミット1207587）では、lines 390-392が正しく日本語化されていた：

```
Line 390: "もしもし、レンジャーズ? アナンダ・ラビンドラナスです..."
Line 392: "話し合った通り、ビザールに平和が訪れた今..."
```

しかしコミット3cd2ea33でリセットが実行され、英語ソースをコピーしたため、**以前の翻訳が失われた**。

### 根本原因

1. **リセット時の範囲確認不足**

   リセットコミットメッセージ:
   ```
   RESTART: Complete retranslation from English source (2nd restart)
   - Copied English source as new clean base
   - Sequential translation from line 1  ← 宣言
   ```

   しかし実際には：
   - Line 666から開始（line 1ではない）
   - Lines 390-665がスキップされた

2. **翻訳開始行の誤認識**

   - `.retranslation_progress.json`で`"current_line": 666`と記録
   - 実際の翻訳可能範囲はline 390から開始
   - **276行（3エントリ）が最初からスキップ**

3. **ドキュメント記載の誤り**

   CLAUDE.md:
   ```
   ### Translation Process Rules
   1. Sequential Translation (Most Important)
      - Translate files from top to bottom in order
      - Complete each section sequentially before moving to the next
   ```

   しかし実際には：
   - "top to bottom"と書かれているが、実際の開始行が明記されていない
   - Line 666を開始点として誤認識

---

## 検証システムの不備

### 現在の検証スクリプトの問題

**validate_structure_v2.py**の検証範囲:
- ✅ Line count matching
- ✅ Quote count per line
- ✅ Game variables preservation
- ✅ HTML tags preservation
- ❌ **action marker内容の検証なし**
- ❌ **翻訳完全性の検証なし**
- ❌ **英語残存の検出なし**

### コミットメッセージの信頼性問題

多くのコミットで以下のように記載：
```
Validation: 0 errors, 0 warnings
Structure protection:
- All ::action:: markers preserved
```

しかし実際には：
- action markersが誤訳されている
- 未翻訳エントリが大量に存在
- **検証内容と実態の乖離**

---

## 再発防止策

### 1. ルール明確化

**CRITICAL_RULES.md** (新規作成):

```markdown
## ::action:: マーカーの取り扱い（絶対厳守）

### 定義
`::action::`形式のマーカーは、ゲームエンジンが認識する**制御命令**です。

### 絶対ルール

❌ **絶対に禁止**:
- action marker内容の翻訳
- action markerの削除
- action markerの形式変更

✅ **必ず守る**:
- action markerは**英語のまま完全に保持**
- 1文字たりとも変更しない
- スペイン語ファイルでも英語のまま保持されている

### 例

正しい:
```
英語: string data = "::sigh:: "I don't know...""
日本語: string data = "::sigh:: "わからない...""
                     ^^^^^^^^ 英語のまま保持
```

間違い:
```
❌ string data = "::ため息:: "わからない...""
❌ string data = "::sighs:: "わからない...""  (複数形化も不可)
❌ string data = ""わからない...""  (削除も不可)
```

### 検証方法

翻訳後、必ず以下を確認:
1. `grep -n '::[^:]*::' TARGET_FILE` で全action markersを抽出
2. 日本語文字が含まれていないか目視確認
3. 英語ソースと1対1で一致するか確認
```

### 2. 検証強化

**validate_translation_quality.py** (作成済み):
- action marker誤訳の検出
- 未翻訳英語の検出
- コミット前に必ず実行

**チェックリスト** (新規作成):

```markdown
## 翻訳前チェックリスト

□ スペイン語ファイルを開いている
□ 英語ソースファイルを開いている
□ glossary.jsonを確認済み
□ 翻訳対象行番号を確認済み

## 翻訳中チェックリスト（各エントリ）

□ スペイン語で翻訳されているか確認
□ ::action::マーカーを英語のまま保持
□ 構造マーカー（""、[]、<>）を保持
□ 技術用語（Script Node等）を保持

## 翻訳後チェックリスト（コミット前必須）

□ validate_structure_v2.py 実行 → 0 errors
□ validate_translation_quality.py 実行 → 0 issues
□ git diff で変更内容を目視確認
□ action markerが全て英語か確認
□ 未翻訳エントリがないか確認
```

### 3. ワークフロー改善

**翻訳開始前**:
```bash
# 1. 翻訳可能範囲を確認
grep -n 'string data = ""[^"][^"]*[^"]""' SOURCE_FILE | head -1

# 2. 進捗ファイルで開始行を確認
cat .retranslation_progress.json | grep current_line

# 3. 不一致がある場合は手動で確認
```

**翻訳中** (各エントリごと):
```bash
# 1. スペイン語参照チェック
#    - Spanish != "" → 翻訳する
#    - Spanish == "" → 英語を保持

# 2. 翻訳実施
#    - action markersは英語のまま
#    - 構造は完全に保持

# 3. 即時検証
python3 validate_structure_v2.py TARGET_FILE --line START END
```

**コミット前** (必須):
```bash
# 1. 構造検証
python3 validate_structure_v2.py TARGET_FILE --detailed

# 2. 品質検証（新規追加）
python3 validate_translation_quality.py TARGET_FILE \
  --start-line START --end-line END

# 3. 両方とも0エラーの場合のみコミット許可
```

### 4. 進捗管理改善

**.retranslation_progress.json**に追加:

```json
{
  "translation_range": {
    "first_translatable_line": 390,
    "first_entry_start_line": 666,
    "note": "Lines 390-665 contain 3 entries that need translation"
  },
  "validation_mandatory": {
    "structure": "validate_structure_v2.py",
    "quality": "validate_translation_quality.py",
    "both_must_pass": true
  }
}
```

### 5. 自動化スクリプトの改善

**automation/auto-retranslate.sh**に追加:

```bash
# コミット前に品質検証を追加
echo "Running quality validation..."
python3 translation/validate_translation_quality.py \
  "$TARGET_FILE" \
  --start-line $START_LINE \
  --end-line $END_LINE

if [ $? -ne 0 ]; then
    echo "❌ Quality validation failed! Aborting commit."
    exit 1
fi
```

---

## 優先度付き修正計画

### Phase 1: 緊急修正（優先度: 最高）

**対象**: action marker誤訳 97件

**理由**: ゲームエンジンがaction markersを認識できず、キャラクター動作が正しく表示されない重大な問題

**方法**:
1. 英語ソースから正しいaction markerを取得
2. 手動で1件ずつ修正（10-20件/セッション）
3. 各セッション後に検証・コミット

**推定時間**: 5-10セッション（1-2日）

### Phase 2: 重要修正（優先度: 高）

**対象**: Lines 390-665の翻訳（3エントリ）

**理由**: 翻訳範囲の最初がスキップされており、ゲーム開始時に未翻訳テキストが表示される

**方法**:
1. スペイン語参照確認
2. 手動翻訳
3. 検証・コミット

**推定時間**: 1セッション（30分）

### Phase 3: 段階的修正（優先度: 中）

**対象**: 未翻訳エントリ 6,982件

**理由**: ユーザー体験の低下（日本語モードで英語が表示）

**方法**:
1. セクション単位で特定（無線通信、会話など）
2. 優先度付け（メインクエスト > サブクエスト > その他）
3. 手動翻訳（50-100件/セッション）
4. 各セッション後に検証・コミット

**推定時間**: 70-140セッション（7-14日）

---

## 教訓

### ❌ やってはいけないこと

1. **コミットメッセージを信用しすぎる**
   - 「Validation: 0 errors」でも実際には問題がある
   - 必ず自分で検証スクリプトを実行

2. **検証範囲の限定**
   - 構造だけでなく、翻訳内容も検証必須
   - action markers、未翻訳エントリも自動検出

3. **暗黙の仮定**
   - 「line 666から開始」という仮定が誤りだった
   - 必ず実際のファイルを確認

4. **バッチ処理の誘惑**
   - 問題が発生しても気づきにくい
   - 1件ずつ手動処理が最も確実

### ✅ これからやるべきこと

1. **二重検証**
   - 構造検証 + 品質検証の両方必須
   - コミット前に必ず両方実行

2. **明示的な確認**
   - スペイン語参照を必ず目視確認
   - action markersを必ず目視確認
   - 翻訳後にdiffを必ず目視確認

3. **段階的進行**
   - 小規模チャンク（10-20エントリ）
   - 各チャンク後に検証・コミット
   - 問題の早期発見・早期修正

4. **ドキュメント更新**
   - 発見した問題を即座に文書化
   - 再発防止策を明記
   - チェックリストの更新

---

## 結論

今回の品質問題は、以下の3つの要因が複合的に作用した結果です：

1. **ルール理解の不足**: action marker内容も翻訳禁止というルールが徹底されていなかった
2. **検証の不足**: 構造のみ検証し、翻訳内容の検証が欠けていた
3. **処理ロジックの問題**: スペイン語空白時の判断ミス、チャンク境界問題

再発防止には、以下が必須です：

- ✅ ルールの明確化（CRITICAL_RULES.md）
- ✅ 検証の強化（validate_translation_quality.py）
- ✅ ワークフローの改善（チェックリスト）
- ✅ 段階的修正（10-20エントリ/セッション）

**最重要**: バッチ処理は禁止。1件ずつ手動で確実に。
