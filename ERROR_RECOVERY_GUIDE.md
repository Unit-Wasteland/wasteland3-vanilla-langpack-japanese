# エラー回復ガイド - Heap Out of Memory Error

## 発生したエラー (2025-10-22)

```
FATAL ERROR: Reached heap limit Allocation failed - JavaScript heap out of memory
```

## 即座に実行すべきこと

### 1. 現在の作業を保護

```bash
# 変更を確認（制限付き）
git diff | head -100

# 変更をコミット
git add translation/.format_fix_progress.json
git add translation/target/v1.6.9.420.309496/ja_JP/*.txt
git commit -m "作業保存: メモリエラー発生前の状態 ($(date +%Y%m%d-%H%M%S))"

# リモートにプッシュ（オプション）
git push origin main
```

### 2. 進捗状態を確認

```bash
# 進捗ファイルを確認
cat translation/.format_fix_progress.json

# 最近のコミットを確認
git log --oneline -5

# 処理済みエントリ数を確認
jq -r '.entries_processed' translation/.format_fix_progress.json
```

### 3. セッションを再起動

```bash
# Claude Code を終了（もし起動中なら）
exit

# 新しいセッションを開始
claude

# 作業を再開（改善された設定で）
"translation/.format_fix_progress.json を読み込んで、以下の厳格なメモリ管理ルールで翻訳作業を継続してください:
- チャンクサイズ: 50行（NEVER exceed）
- コミット頻度: 100エントリごと
- git diff は常に head -100 で制限
- 逐次処理のみ（並列処理禁止）"
```

## 再発防止策

### A. 手動翻訳を継続する場合

**厳格なルールに従ってください:**

```bash
# セッション開始時に指示
"translation/.format_fix_progress.json を読み込んで翻訳を継続してください。

CRITICAL MEMORY MANAGEMENT:
- チャンクサイズ: 50行/チャンク (絶対に100行を超えない)
- コミット頻度: 100エントリごと (または各セクション完了時)
- git diff 表示: 常に 'head -100' で制限
- 処理方式: 1チャンクずつ逐次処理（並列禁止）
- メモリ監視: 50-100エントリごとに確認

目標: 500エントリを処理してコミットしてください。"
```

**メモリ監視コマンド:**
```bash
# 別のターミナルで実行（推奨）
watch -n 30 'ps aux | grep claude | awk "{print \$6/1024 \" MB\"}"'

# または定期的に手動実行
ps aux | grep claude | awk '{print $6/1024 " MB"}'
```

**メモリが4GB超えた場合:**
1. 現在のチャンクを完了
2. 即座にコミット
3. セッションを再起動

**メモリが6GB超えた場合:**
1. 作業を即座に停止
2. 現在の変更をコミット（git add . && git commit）
3. セッションを強制終了
4. 新しいセッションで再開

### B. 自動化スクリプトを使用する場合

**改善版スクリプトを使用:**

```bash
# 改善版スクリプトを実行
cd /home/user/project_claudecode/wasteland3-vanilla-langpack-japanese
./automation/auto-translate-improved.sh
```

**改善点:**
- メモリ閾値: 7GB → 6GB（早期再起動）
- 警告レベル: 4GB（積極的メモリ管理）
- エントリ/セッション: 2500 → 1000（小さいバッチ）
- 監視間隔: 30秒 → 15秒（早期検出）
- チャンクサイズ: 50行（保守的）
- コミット頻度: 100エントリ（頻繁）

**ログ監視:**
```bash
# リアルタイムでログを監視
tail -f automation/translation-automation.log

# エラーチェック
grep -i "error\|fatal\|out of memory" automation/.session_*_output.log
```

## トラブルシューティング

### Q1: エラー後に進捗が失われた？

```bash
# バックアップから復元
cp translation/.translation_progress.backup.json \
   translation/.translation_progress.json

# または最後のコミットから復元
git log --oneline --all | grep "進捗ファイル更新"
git show <commit_hash>:translation/.translation_progress.json
```

### Q2: 同じファイルで繰り返しエラーが発生する

**対応:**
1. チャンクサイズをさらに削減: 50行 → 30行
2. コミット頻度を増やす: 100エントリ → 50エントリ
3. ファイルをスキップして次のファイルに進む（進捗ファイルを手動編集）

```bash
# 進捗ファイルを編集してスキップ
jq '.current_file_path = "次のファイルパス" | .current_line_offset = 0' \
   translation/.translation_progress.json > temp.json && \
   mv temp.json translation/.translation_progress.json
```

### Q3: Node.jsのヒープサイズを増やすべき？

**推奨しません。** 理由:
- Claude Code本体のメモリ設定は変更できない
- 問題はメモリサイズではなく、処理方法にある
- チャンクサイズとコミット頻度の最適化が正しい解決策

### Q4: どのくらいの頻度でセッションを再起動すべき？

**ガイドライン:**
- **予防的再起動**: 1000-2000エントリ処理ごと
- **メモリベース**: 4GB到達時（警告）、6GB到達時（必須）
- **時間ベース**: 30-60分ごと（長時間セッションを避ける）

## 改善されたワークフロー

### 理想的な手動翻訳セッション

```
1. セッション開始
   ↓
2. メモリ監視を別ターミナルで起動
   ↓
3. 50行チャンク × 2回 = 100エントリ処理
   ↓
4. コミット（メモリ解放）
   ↓
5. メモリ使用量を確認
   - < 4GB: 続行
   - 4-6GB: コミット後に再起動
   - > 6GB: 即座に再起動
   ↓
6. ステップ3に戻る（または再起動）
```

### 理想的な自動化実行

```bash
# 改善版スクリプトで実行
./automation/auto-translate-improved.sh

# 別ターミナルでログ監視
tail -f automation/translation-automation.log

# 完了まで放置（自動的にメモリ管理される）
```

## 参考資料

- `MEMORY_MANAGEMENT_STRICT.md`: 厳格なメモリ管理ガイドライン
- `CLAUDE.md`: プロジェクト全体の指示
- `automation/auto-translate-improved.sh`: 改善版自動化スクリプト
- `automation/translation-automation.log`: 自動化実行ログ

## 成功の指標

エラーが解決されたことを示す指標:
- ✅ 連続して500エントリ以上を処理できる
- ✅ メモリ使用量が6GB未満で安定
- ✅ セッションが30分以上クラッシュせずに実行
- ✅ コミットログに「heap out of memory」が記録されない
- ✅ 自動化スクリプトが複数セッションを完了できる

## 最終チェックリスト

エラー回復後に確認:
- [ ] 変更がgitにコミットされている
- [ ] 進捗ファイルが最新状態である
- [ ] バックアップファイルが作成されている
- [ ] 次回の再開ポイントが明確である
- [ ] メモリ管理ルールが適用されている
- [ ] チャンクサイズが50行以下に設定されている
- [ ] コミット頻度が100-200エントリ以下である
