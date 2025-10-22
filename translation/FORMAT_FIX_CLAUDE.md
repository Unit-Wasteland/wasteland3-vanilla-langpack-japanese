# FORMAT_FIX_CLAUDE.md

このファイルは、Wasteland 3 日本語翻訳ファイルのフォーマット修正作業の完全なガイドです。

## 📋 作業概要

### 問題の詳細

翻訳作業中に、Unity StringTableフォーマットの構造化記号（`""`）が日本語の括弧（`「」`、`『』`）に変換されてしまい、ゲームへのインポートが失敗する問題が発生しました。

**問題の例:**
```
❌ 誤った形式（ゲームにインポート不可）:
   string data = "「よう、カウボーイたち。デッド・レッドだ。」"

✅ 正しい形式:
   string data = ""よう、カウボーイたち。デッド・レッドだ。""
```

### 解決方針

1. **sourceの英語ファイルをコピー** → 新しい翻訳ファイルの基礎とする
2. **テキスト部分のみ置換** → 翻訳済みファイルから日本語テキストを抽出し、英語テキスト部分だけを置き換え
3. **構造は完全保持** → `""`やその他の構造化記号（`'`, `[...]`など）は一切変更しない

---

## 📊 修正対象

### ファイルと対象エントリ数

| ファイル | 翻訳済みエントリ | 総エントリ数 | 処理単位 | 推定処理回数 |
|---------|----------------|-------------|---------|-------------|
| **ベースゲーム** | 51,853 | 169,711 | 100 | 約519回 |
| **DLC1** | 12,785 | 38,553 | 100 | 約128回 |
| **DLC2** | 7,354 | 24,153 | 100 | 約74回 |
| **合計** | **71,992** | **232,417** | - | **約721回** |

---

## 🔧 修正プロセス

### ステップ1: 準備作業（完了）

✅ 破損した翻訳ファイルをバックアップ
```bash
translation/backup_broken/
├── StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt
├── DLC1/StringTableData_English-CAB-01cf4ea31238681a8e1bd9559c0f3f3e--5815625736905989241.txt
└── DLC2/StringTableData_English-CAB-6a212d8a4482b263f057ec8756825864-4193932453415687559.txt
```

✅ sourceの英語ファイルをtargetにコピー（新しいベース）
```bash
translation/target/v1.6.9.420.309496/ja_JP/
├── StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt (英語ベース)
├── DLC1/StringTableData_English-CAB-01cf4ea31238681a8e1bd9559c0f3f3e--5815625736905989241.txt (英語ベース)
└── DLC2/StringTableData_English-CAB-6a212d8a4482b263f057ec8756825864-4193932453415687559.txt (英語ベース)
```

### ステップ2: エントリ置換プロセス

**1エントリあたりの処理:**

1. **バックアップファイルから日本語テキストを読み込む**
   - 例: `"「よう、カウボーイたち。」"` → `よう、カウボーイたち。`

2. **新しいベースファイル（英語）から対応エントリを読み込む**
   - 例: `""Hey, cowboys.""`

3. **英語テキスト部分のみを日本語に置き換え**
   - 置換前: `""Hey, cowboys.""`
   - 置換後: `""よう、カウボーイたち。""`
   - 構造（`""`）は完全保持

4. **Editツールで更新**

5. **検証**
   - 行数が変わっていないか
   - 構造が保持されているか

### ステップ3: バッチ処理

- **処理単位**: 100エントリ/回
- **コミット頻度**: 500エントリごと、または10回の処理ごと
- **進捗保存**: 各コミット後に進捗ファイル更新

---

## 📈 進捗管理

### 進捗ファイル

`translation/.format_fix_progress.json`

```json
{
  "last_updated": "2025-10-22T12:00:00+09:00",
  "current_file": "base_game | DLC1 | DLC2",
  "current_line_offset": 0,
  "entries_processed": 0,
  "total_entries_to_process": 71992,
  "last_commit_hash": "",
  "status": "in_progress | paused | completed"
}
```

### 進捗確認コマンド

```bash
# 現在の進捗を確認
cat translation/.format_fix_progress.json

# 処理済みエントリ数を確認
grep -c 'string data = ""' translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt
```

---

## 🔄 中断・再開手順

### 作業を中断する場合

1. **現在の処理を完了させる**
   - 進行中のバッチ処理（100エントリ）を完了

2. **変更をコミット**
   ```bash
   git add translation/target/
   git commit -m "フォーマット修正: [開始行]-[終了行] ([処理エントリ数]エントリ)"
   ```

3. **進捗ファイルを更新**
   ```json
   {
     "status": "paused",
     "current_line_offset": <次回開始行番号>,
     "entries_processed": <これまでの処理済み数>,
     "last_commit_hash": "<コミットハッシュ>"
   }
   ```

4. **進捗ファイルをコミット**
   ```bash
   git add translation/.format_fix_progress.json
   git commit -m "進捗保存: <処理済みエントリ数>エントリ完了"
   ```

### 作業を再開する場合

1. **進捗ファイルを確認**
   ```bash
   cat translation/.format_fix_progress.json
   ```

2. **現在のファイルと行番号を確認**
   - `current_file`: 処理中のファイル
   - `current_line_offset`: 次回開始行番号

3. **Claude Codeセッションで再開**
   ```
   「translation/.format_fix_progress.json を読み込んで、
    FORMAT_FIX_CLAUDE.md に従ってフォーマット修正作業を継続してください。」
   ```

4. **検証**
   - 行数が一致しているか確認
   - 最後のコミットから変更がないか確認

---

## 📝 処理例

### 単純な会話文

**バックアップ（破損）:**
```
string data = "「よう、カウボーイたち。」"
```

**英語ベース:**
```
string data = ""Hey, cowboys.""
```

**修正後:**
```
string data = ""よう、カウボーイたち。""
```

### 特殊マーカー付き

**バックアップ（破損）:**
```
string data = "[27.065メガヘルツに切り替え] 「ニュースは聞いたと思うが」"
```

**英語ベース:**
```
string data = "[Switch to 27.065 Megahertz] "So I guess you heard the news.""
```

**修正後:**
```
string data = "[27.065メガヘルツに切り替え] "ニュースは聞いたと思うが""
```

### ネストされた引用符

**バックアップ（破損）:**
```
string data = "「『夜には千の目がある』って古い歌を知ってるか？」"
```

**英語ベース:**
```
string data = ""You know that old song, 'The Night Has a Thousand Eyes?'""
```

**修正後:**
```
string data = ""'夜には千の目がある'って古い歌を知ってるか？""
```

### 空のエントリ

**バックアップ:**
```
string data = ""
```

**英語ベース:**
```
string data = ""
```

**修正後:**
```
string data = ""
```
（変更なし）

---

## ⚠️ 重要な注意事項

### 絶対に変更してはいけないもの

1. **構造化記号**
   - `""` (ダブルクォートのエスケープ)
   - `'` (シングルクォート - 引用符として使用されている場合)
   - `[...]` (特殊マーカー)
   - `::action::` (アクションマークアップ)

2. **ファイル構造**
   - 行数
   - インデント
   - 配列サイズ
   - エントリID

3. **技術用語**
   - `Script Node` (後に数字が続く)
   - `do_not_translate` リストの用語

### 記号の扱い

- ✅ 全角記号を使用: `！？`
- ❌ 半角記号に変換しない: `!?`

---

## 🔍 検証手順

### 各バッチ処理後

1. **行数確認**
   ```bash
   wc -l translation/source/v1.6.9.420.309496/en_US/StringTableData_English-CAB-*.txt \
        translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-*.txt
   ```

2. **フォーマット確認**
   ```bash
   # 日本語エントリが正しいフォーマットか確認
   grep 'string data = "".*""' translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-*.txt | head -10

   # 誤った形式がないか確認（あってはならない）
   grep 'string data = "「' translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-*.txt
   ```

### 最終検証

1. **全ファイルの行数一致**
2. **破損した括弧がないこと**
3. **git diff で構造変更がないこと**
4. **翻訳テキストが正しく置き換えられていること**

---

## 🐛 トラブルシューティング

### Q: Edit時に "File has been unexpectedly modified" エラー

**A:** ファイルを再度Readしてから、Editを実行してください。

### Q: 行数が一致しない

**A:** 修正を中止し、最後のコミットまで戻ってください。
```bash
git reset --hard <last_commit_hash>
```

### Q: メモリ不足エラー

**A:** 処理単位を100エントリから50エントリに減らしてください。

### Q: 進捗ファイルが見つからない

**A:** 手動で作成してください。
```bash
cat > translation/.format_fix_progress.json << 'EOF'
{
  "last_updated": "2025-10-22T12:00:00+09:00",
  "current_file": "base_game",
  "current_line_offset": 0,
  "entries_processed": 0,
  "total_entries_to_process": 71992,
  "last_commit_hash": "",
  "status": "in_progress"
}
EOF
```

---

## 📊 処理状況の目安

| ファイル | 翻訳済みエントリ | 推定処理時間 |
|---------|----------------|-------------|
| ベースゲーム | 51,853 | 3-5時間 |
| DLC1 | 12,785 | 1-2時間 |
| DLC2 | 7,354 | 1時間 |
| **合計** | **71,992** | **5-8時間** |

※ 処理時間は目安です。実際の時間は環境や負荷により変動します。

---

## ✅ 完了条件

1. ✅ 全71,992エントリの置き換え完了
2. ✅ 全ファイルの行数一致確認
3. ✅ フォーマット検証完了（`「」`が残っていないこと）
4. ✅ git diffで構造変更がないこと確認
5. ✅ 最終コミット完了

---

## 📝 コミットメッセージの形式

```
フォーマット修正: [ファイル名] line [開始]-[終了] ([処理エントリ数]エントリ)

- バックアップから日本語テキストを抽出
- 英語ベースファイルのテキスト部分のみを置換
- 構造（""など）は完全保持
```

**例:**
```
フォーマット修正: base_game line 666-1165 (100エントリ)

- バックアップから日本語テキストを抽出
- 英語ベースファイルのテキスト部分のみを置換
- 構造（""など）は完全保持
```
