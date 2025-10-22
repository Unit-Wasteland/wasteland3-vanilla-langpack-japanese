# Structure Protection Rules (構造保護ルール)

## 概要

このドキュメントは、Unity StringTableファイルの構造を保護するための厳格なルールを定義します。
これらのルールに違反すると、ファイルがゲームにインポート不可能になります。

## 絶対に変更してはいけない記号とパターン

### 1. Unity構造マーカー（最優先）

**`""` (ダブルクォーテーション2つ):**
- Unity StringTableの文字列開始/終了マーカー
- **絶対に `「」` `『』` `""` などに変換してはいけない**
- 正しい形式: `string data = ""Japanese text here""`
- 誤った形式: `string data = "「Japanese text here」"`

**例:**
```
✅ 正常: string data = ""こんにちは、カウボーイ。""
❌ 破損: string data = "「こんにちは、カウボーイ。」"
❌ 破損: string data = ""こんにちは、カウボーイ。""
```

### 2. 特殊フォーマットマーカー

**`[ ]` (角括弧):**
- ラジオ周波数、スクリプトノード、特殊指示などに使用
- 括弧内の内容も含めて変更禁止（翻訳対象外）
- 例: `[Switch to 27.065 Megahertz]`, `[Script Node 14]`

**例:**
```
✅ 正常: string data = "[Switch to 27.065 Megahertz] ""Message here"""
❌ 破損: string data = "【27.065メガヘルツに切り替え】 "Message here""
```

**`' '` (シングルクォーテーション):**
- 引用や固有名詞の強調に使用
- **絶対に `'` `'` や `「」` に変換してはいけない**
- 例: `'The Night Has a Thousand Eyes'`

**例:**
```
✅ 正常: ""You know that old song, 'The Night Has a Thousand Eyes?'""
❌ 破損: ""You know that old song, '夜には千の目がある?'""
```

### 3. アクションマークアップ（ゲームエンジン処理用）

**`::action::` 形式:**
- キャラクターの動作・感情を示すゲームエンジンマーカー
- **絶対に翻訳してはいけない**
- **`::`（ダブルコロン）の形式を変更してはいけない**

**翻訳禁止のアクションマークアップ例:**
```
::sings::      歌う
::laughs::     笑う
::coughs::     咳をする
::whispers::   ささやく
::shouts::     叫ぶ
::cries::      泣く
::sighs::      ため息をつく
::groans::     うめく
::screams::    絶叫する
::mutters::    つぶやく
```

**例:**
```
✅ 正常: string data = ""::laughs:: That's hilarious!""
          → ""::laughs:: それは面白い！""
❌ 破損: string data = ""【笑い】 それは面白い！""
❌ 破損: string data = ""：：笑う：： それは面白い！""
```

### 4. HTML/XMLタグ

**`< >` (山括弧):**
- HTMLタグ、変数プレースホルダーなどに使用
- タグ名と構造を変更してはいけない
- 例: `<color=red>`, `<b>`, `</b>`, `{variable_name}`

**例:**
```
✅ 正常: string data = ""<color=red>Warning!</color> Message here""
❌ 破損: string data = ""＜color=red＞警告！＜/color＞ Message here""
```

### 5. 技術用語（翻訳禁止）

**`Script Node` + 数字:**
- ゲームエンジン内部の識別子
- **絶対に翻訳してはいけない**

**例:**
```
✅ 正常: string data = ""Script Node 14""
❌ 破損: string data = ""スクリプトノード 14""
```

## 正規表現パターン（検証用）

### 破損パターンの検出

```bash
# 壊れた構造マーカー（日本語括弧）の検出
grep 'string data = "「' file.txt
grep 'string data = "『' file.txt

# 壊れたアクションマークアップの検出
grep 'string data = ""【.*】' file.txt
grep 'string data = ""：：.*：：' file.txt

# 壊れた角括弧の検出
grep 'string data = ""【.*】' file.txt

# 翻訳されたScript Nodeの検出
grep 'string data = ""スクリプトノード' file.txt
```

### 正常パターンの確認

```bash
# 正常な構造マーカー（日本語テキスト含む）
grep 'string data = "".*[ぁ-ん].*""' file.txt

# 正常なアクションマークアップ
grep 'string data = ""::[a-z]*::' file.txt

# 正常な角括弧（英語のまま）
grep 'string data = ""\[.*\]' file.txt
```

## チェックリスト（コミット前に必ず確認）

- [ ] `""` マーカーが全て保持されている（`「」` に変換されていない）
- [ ] `[ ]` 内の技術用語が英語のまま保持されている
- [ ] `::action::` 形式が全て英語のまま保持されている
- [ ] `< >` タグが壊れていない
- [ ] `Script Node` が翻訳されていない
- [ ] ファイルの行数が元ファイルと一致している
- [ ] 中国語（簡体字）が混入していない

## エラー例と修正方法

### エラー1: 構造マーカーの破損

```
❌ 誤り:
   string data = "「よう、カウボーイたち。デッド・レッドだ。」"

✅ 修正:
   string data = ""よう、カウボーイたち。デッド・レッドだ。""
```

### エラー2: アクションマークアップの翻訳

```
❌ 誤り:
   string data = ""【笑い】 それは面白い！""

✅ 修正:
   string data = ""::laughs:: それは面白い！""
```

### エラー3: 角括弧内の翻訳

```
❌ 誤り:
   string data = "【27.065メガヘルツに切り替え】 "ニュースは聞いたと思うが""

✅ 修正:
   string data = "[Switch to 27.065 Megahertz] "ニュースは聞いたと思うが""
```

### エラー4: 入れ子引用符の処理

```
❌ 誤り:
   string data = ""「『夜には千の目がある』って古い歌を知ってるか？」""

✅ 修正:
   string data = ""'夜には千の目がある'って古い歌を知ってるか？""
```

## 自動化スクリプトへの注意

**スクリプトによる一括変換は禁止:**
- 過去に何度も修復不可能な構造破壊が発生
- 必ず50-100行のチャンク処理で手動確認
- 正規表現による一括置換は危険

**安全な処理方法:**
1. backup_brokenから日本語テキストを抽出
2. 構造マーカーは英語ファイルから保持
3. テキスト部分のみを慎重に置換
4. 各チャンクごとに検証
5. 100エントリごとにコミット

## 参考資料

- Unity StringTable公式ドキュメント
- `nouns_glossary.json` の `do_not_translate` セクション
- `translation/FORMAT_FIX_CLAUDE.md`
