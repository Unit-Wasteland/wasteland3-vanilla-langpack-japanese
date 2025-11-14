# 未翻訳箇所の翻訳ワークフロー

## 概要

このドキュメントは、未翻訳箇所を正確に検知し、Editツールで逐次翻訳するワークフローを説明します。

## ステップ1: 未翻訳箇所の検知

```bash
python3 translation/detect_untranslated.py
```

このスクリプトは：
- `nouns_glossary.json`のdo_not_translateリストをチェック
- スペイン語版を参照して翻訳すべきかを判断
- 英語==日本語（未翻訳）のエントリを検出
- 技術マーカー、アクションマーカーのみ、空文字列を除外

### 出力ファイル

1. `translation/untranslated_entries.json` - 全未翻訳エントリの詳細
2. `translation/untranslated_lines.txt` - 行番号のみのリスト

## ステップ2: 翻訳対象の確認

```bash
# 検出結果の確認
cat translation/untranslated_entries.json | jq '.[0:10]'  # 最初の10件

# 特定の行範囲の確認（例: 300,000～310,000行）
cat translation/untranslated_entries.json | \
  jq '.[] | select(.line >= 300000 and .line <= 310000)'
```

## ステップ3: 翻訳実施

### 重要なルール（CLAUDE.md準拠）

1. **スクリプトによる一括処理は禁止**
2. **Editツールで1エントリずつ翻訳**
3. **必ずnouns_glossary.jsonで固有名詞を確認**
4. **::action::マーカーは英語のまま保持**
5. **行数を保持（530,425行）**

### 翻訳手順（Claude Codeで実行）

#### 3-1. Readツールでファイル読み込み

対象行の前後を読み込む（Editツールの前提条件）

#### 3-2. 固有名詞の確認

```bash
# glossaryで確認
grep -i "keyword" translation/nouns_glossary.json
```

#### 3-3. Editツールで翻訳

- old_stringに英語の元テキストを**完全一致**で指定
- new_stringに日本語訳を記述
- 固有名詞はglossaryに従う
- ::action::マーカーは保持

#### 3-4. 翻訳後の確認

- 行数: 530,425行を維持
- action marker検証: 日本語が混入していないか

```bash
# action markerに日本語がないか確認
grep -o '::[^:]*[ぁ-ゖァ-ヾ一-龯][^:]*::' \
  translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-....txt
# 出力が空 = OK
```

## ステップ4: コミット

```bash
git add translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-....txt
git commit -m "Translate entries (lines X-Y)"
git push origin main
```

## 現状の未翻訳箇所

### 検知スクリプト実行結果（最新）

```
UNTRANSLATED ENTRIES FOUND: 10,726

Summary by line range:
  Lines 100001-150000:    3 entries
  Lines 150001-200000:    1 entries
  Lines 200001-300000:   28 entries
  Lines 300001-530425: 10,694 entries  ← ほとんどがデバッグモード
```

### 推奨アプローチ

1. **優先度高**: 100,001～300,000行（通常の会話・説明文、32エントリ）
2. **優先度中**: 300,001行以降のうち、ゲームプレイで表示されるもの
3. **優先度低**: デバッグモード専用テキスト

## トラブルシューティング

### 問題: Editツールで"String to replace not found"エラー

**原因**: old_stringが完全一致していない（空白、改行、特殊文字の違い）

**解決策**:
```bash
# 正確な文字列を確認
sed -n '行番号p' ファイルパス | cat -A
```

### 問題: 固有名詞の訳が不明

**解決策**:
```bash
# glossaryを検索
grep -i "キーワード" translation/nouns_glossary.json

# glossaryにない場合、スペイン語版を参照
sed -n '行番号p' translation/source/.../es_ES/StringTableData_Spanish-....txt
```

## 参照

- `CLAUDE.md` - プロジェクト全体のルール
- `nouns_glossary.json` - 固有名詞・用語集
- `detect_untranslated.py` - 未翻訳箇所検知スクリプト
