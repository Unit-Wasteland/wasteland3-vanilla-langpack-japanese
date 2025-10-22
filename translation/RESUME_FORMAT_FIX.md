# フォーマット修正作業の再開手順

このファイルは、フォーマット修正作業を中断した後に再開するための手順書です。

## 🔄 再開手順

### 1. 進捗状況の確認

```bash
# 進捗ファイルを確認
cat translation/.format_fix_progress.json

# 現在のgitステータスを確認
git status

# 最後のコミットを確認
git log -1
```

### 2. Claude Codeセッションを開始

```bash
claude
```

### 3. 作業再開の指示

Claude Codeセッションで以下のように指示してください:

```
translation/.format_fix_progress.json を読み込んで、
translation/FORMAT_FIX_CLAUDE.md に従ってフォーマット修正作業を継続してください。
```

### 4. 自動再開

Claude Codeは以下の処理を自動的に実行します:

1. **進捗ファイルの読み込み**
   - 現在のファイル: `current_file`
   - 現在の行番号: `current_line_offset`
   - 処理済みエントリ数: `entries_processed`

2. **現在位置から処理を再開**
   - バックアップファイルから日本語テキストを読み込み
   - 新しいベースファイルの該当箇所を更新
   - 100エントリごとに処理

3. **進捗の自動保存**
   - 500エントリごとにコミット
   - 進捗ファイルを更新

---

## 📊 進捗確認コマンド

### 処理済みエントリ数を確認

```bash
# ベースゲームファイルの日本語エントリ数
grep -c 'string data = "".*[ぁ-ん]' translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt

# DLC1ファイルの日本語エントリ数
grep -c 'string data = "".*[ぁ-ん]' translation/target/v1.6.9.420.309496/ja_JP/DLC1/StringTableData_English-CAB-01cf4ea31238681a8e1bd9559c0f3f3e--5815625736905989241.txt

# DLC2ファイルの日本語エントリ数
grep -c 'string data = "".*[ぁ-ん]' translation/target/v1.6.9.420.309496/ja_JP/DLC2/StringTableData_English-CAB-6a212d8a4482b263f057ec8756825864-4193932453415687559.txt
```

### 残りの破損エントリ数を確認

```bash
# ベースゲームファイルの残存「」エントリ数（0であるべき）
grep -c 'string data = "「' translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt

# DLC1ファイルの残存「」エントリ数（0であるべき）
grep -c 'string data = "「' translation/target/v1.6.9.420.309496/ja_JP/DLC1/StringTableData_English-CAB-01cf4ea31238681a8e1bd9559c0f3f3e--5815625736905989241.txt

# DLC2ファイルの残存「」エントリ数（0であるべき）
grep -c 'string data = "「' translation/target/v1.6.9.420.309496/ja_JP/DLC2/StringTableData_English-CAB-6a212d8a4482b263f057ec8756825864-4193932453415687559.txt
```

---

## ⚠️ トラブルシューティング

### 進捗ファイルが壊れている場合

手動で修正してください:

```bash
nano translation/.format_fix_progress.json
```

最低限必要な情報:
- `current_file`: "base_game" | "DLC1" | "DLC2"
- `current_line_offset`: 次に処理する行番号
- `entries_processed`: これまでに処理したエントリ数

### 中断前のコミットに戻す場合

```bash
# 最近のコミットを確認
git log --oneline -10

# 特定のコミットまで戻す（作業内容は破棄される）
git reset --hard <commit_hash>
```

### 処理が遅い場合

処理単位を減らしてください:

```json
{
  "processing_strategy": {
    "batch_size": 50,  // 100 → 50 に変更
    "commit_frequency": 250  // 500 → 250 に変更
  }
}
```

---

## 📝 手動再開の場合

もしClaude Codeが自動再開できない場合、手動で以下を実行:

### 1. 現在の進捗ファイルから情報を取得

```bash
cat translation/.format_fix_progress.json
```

### 2. Claude Codeに詳細指示

```
以下の情報に基づいてフォーマット修正作業を継続してください:

ファイル: <current_file_path>
バックアップ: <backup_file_path>
開始行: <current_line_offset>
処理済み: <entries_processed>エントリ

FORMAT_FIX_CLAUDE.md に従って、100エントリずつ処理してください。
```

---

## ✅ 再開確認チェックリスト

再開前に以下を確認してください:

- [ ] 進捗ファイル（.format_fix_progress.json）が存在する
- [ ] git statusが clean、または未コミットの変更がない
- [ ] バックアップファイルが存在する
- [ ] 新しいベースファイルが存在する
- [ ] 行数が一致している（source = target）

---

## 📞 サポート

問題が発生した場合:

1. **進捗ファイルを確認**: `cat translation/.format_fix_progress.json`
2. **最後のコミットを確認**: `git log -1`
3. **ファイルの整合性を確認**: `wc -l translation/source/.../file.txt translation/target/.../file.txt`
4. **Claude Codeに状況を説明**: 詳細な状況を提供してください

---

**最終更新**: 2025-10-22
