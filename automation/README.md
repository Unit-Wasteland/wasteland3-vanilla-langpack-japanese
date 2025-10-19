# Automated Translation Scripts

このディレクトリには、Wasteland 3の翻訳作業を完全自動で実行するスクリプトが含まれています。

## 🚀 完全自動翻訳の実行方法

### Windows (PowerShell) から実行

```powershell
cd C:\path\to\wasteland3-vanilla-langpack-japanese
.\automation\auto-translate.ps1
```

**オプションパラメータ:**
```powershell
.\automation\auto-translate.ps1 `
    -MaxMemoryMB 7000 `
    -EntriesPerSession 2500 `
    -MaxSessions 100
```

### WSL/Linux (Bash) から実行

```bash
cd /home/user/project_claude/game_wasteland/wasteland3-vanilla-langpack-japanese
./automation/auto-translate.sh
```

## 📋 動作の仕組み

1. **セッション開始**: Claude Codeを起動
2. **進捗読み込み**: `.translation_progress.json`から前回の続きを読み込み
3. **自動翻訳**: メインセッションで直接翻訳実行（100-200行チャンク、1000エントリごとにコミット）
4. **メモリ監視**: メモリ使用量を監視（30秒ごと）
5. **自動再起動**: 以下の条件でセッションを終了・再起動
   - メモリが閾値（デフォルト7GB）を超えた
   - 目標エントリ数（デフォルト2,500）を達成した
   - タイムアウト（1時間）に達した
6. **ループ継続**: 次のセッションを自動的に開始
7. **完了検出**: 翻訳完了を検出したら自動終了

**重要な変更点（2025-10）:**
- サブエージェントを使用せず、メインセッションで直接翻訳を実行
- **`--dangerously-skip-permissions` フラグ使用**: ファイル編集権限の自動承認を実現
- **`yes` コマンド使用**: 対話的な承認プロンプトを自動承認
- 権限承認の問題を完全に解決し、真の無人実行を実現
- 厳格なメモリ管理（チャンク処理、頻繁なコミット）で安定性を確保

**⚠️ セキュリティ注意事項:**
- `--dangerously-skip-permissions` は全ての権限チェックをバイパスします
- `yes` コマンドは全ての対話的プロンプトに自動的に「y」を回答します
- **サンドボックス環境または信頼できるリポジトリでのみ使用してください**
- インターネットアクセスが制限された環境での使用を推奨します
- Gitブランチでの実行を推奨（変更の確認・ロールバックが容易）

## 🎯 特徴

### ✅ 完全無人運転
- ユーザーの介入なしで数日〜数週間稼働可能
- 夜間や週末に実行してバックグラウンドで翻訳

### ✅ メモリ管理
- メモリ使用量を自動監視
- 閾値超過で自動的にセッション再起動
- Out of Memoryエラーを防止

### ✅ 進捗保存
- すべての進捗を自動保存
- スクリプト中断後も再開可能
- Gitに自動コミット・プッシュ

### ✅ ログ記録
- 詳細なログを`translation-automation.log`に記録
- 各セッションの出力を個別ファイルに保存
- トラブルシューティングが容易

## ⚙️ 設定パラメータ

### PowerShell版 (`auto-translate.ps1`)

| パラメータ | デフォルト | 説明 |
|-----------|----------|------|
| `MaxMemoryMB` | 7000 | メモリ閾値（MB）。この値を超えたらセッション再起動 |
| `EntriesPerSession` | 2500 | セッションあたりの目標翻訳エントリ数 |
| `MaxSessions` | 100 | 最大セッション数（安全装置） |

### Bash版 (`auto-translate.sh`)

スクリプト内の変数を編集:
```bash
MAX_MEMORY_MB=7000
ENTRIES_PER_SESSION=2500
MAX_SESSIONS=100
```

## 📊 進捗確認

### リアルタイムログ監視

**PowerShell:**
```powershell
Get-Content .\automation\translation-automation.log -Wait -Tail 20
```

**Bash:**
```bash
tail -f automation/translation-automation.log
```

### 現在の進捗確認

```bash
cat translation/.translation_progress.json | jq
```

### Git進捗確認

```bash
git log --oneline -20
```

## 🛑 停止方法

### 安全な停止（現在のセッション完了後）
スクリプトは各セッション完了後に自動的にチェックポイントを作成するため、単純に次のセッションが始まる前に停止できます。

**PowerShell:**
```powershell
# スクリプトウィンドウで Ctrl+C
```

**Bash:**
```bash
# スクリプトウィンドウで Ctrl+C
# または別ターミナルから:
pkill -TERM -f auto-translate.sh
```

### 緊急停止

**全Claude Codeプロセスを強制終了:**
```bash
pkill -9 claude
```

## 🔧 トラブルシューティング

### スクリプトが起動しない

1. **Claude Codeがインストールされているか確認:**
   ```bash
   which claude
   claude --version
   ```

2. **作業ディレクトリのパスを確認:**
   スクリプト内の`WORKING_DIR`が正しいか確認

3. **実行権限を確認（Bash版）:**
   ```bash
   chmod +x automation/auto-translate.sh
   ```

### メモリ監視が機能しない

PowerShell版はWSL内のプロセスを直接監視できない場合があります。その場合はBash版の使用を推奨。

### セッションが途中で止まる

- `automation/.session_N_output.log`を確認
- Claude CodeのAPI制限に達している可能性
- ネットワーク接続を確認

### 翻訳が進まない

1. `.translation_progress.json`の`next_action`を確認
2. 最新のコミットを確認: `git log -1`
3. 手動で1セッション実行してエラーを確認

## 📝 注意事項

### API制限
Claude CodeのAPI制限により、連続実行が制限される場合があります。その場合は`ENTRIES_PER_SESSION`を減らすか、セッション間の待機時間を増やしてください。

### ディスク容量
ログファイルとGitリポジトリが増大します。定期的に確認してください：
```bash
du -sh automation/*.log
du -sh .git
```

### バックアップ
重要な変更が自動的にGitにプッシュされますが、定期的にリモートリポジトリの状態を確認してください。

## 🎉 使用例

### 夜間実行
```powershell
# 金曜日の夜に開始、週末中に実行
.\automation\auto-translate.ps1 -MaxSessions 50
```

### 長期実行
```bash
# nohupでバックグラウンド実行（Bash）
nohup ./automation/auto-translate.sh > /dev/null 2>&1 &

# tmuxセッションで実行（推奨）
tmux new-session -s translation
./automation/auto-translate.sh
# Ctrl+B, D でデタッチ
# tmux attach -t translation で再接続
```

### 慎重な実行（少量ずつ）
```powershell
# 1セッションあたり500エントリ、最大10セッション
.\automation\auto-translate.ps1 -EntriesPerSession 500 -MaxSessions 10
```

## 📚 関連ドキュメント

- `CLAUDE.md` - 翻訳ルールとメモリ管理ガイドライン
- `translation/RESUME_TRANSLATION.md` - 手動再開手順
- `translation/.translation_progress.json` - 現在の進捗状態
