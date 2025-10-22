# Automated Translation Scripts

このディレクトリには、Wasteland 3の翻訳作業を完全自動で実行するスクリプトが含まれています。

---

## ⚠️ 重大なセキュリティ警告 - 必読

> **🚨 このスクリプトは実験的機能であり、重大なリスクを伴います**
>
> ### 危険性の理解
>
> このスクリプトは以下の2つの危険な機能を使用します：
>
> 1. **`--dangerously-skip-permissions`フラグ**
>    - Claude Codeの内部権限チェックを完全にバイパス
>    - すべてのファイル操作が無条件で実行されます
>
> 2. **`yes`コマンド**
>    - すべての対話的プロンプトに自動的に「y」を回答
>    - ファイル削除、システム変更など、すべての確認を自動承認
>
> ### リスク
>
> - ⛔ **システムファイルの破壊**: 誤動作時にOS重要ファイルが削除される可能性
> - ⛔ **データ損失**: 意図しないファイルの上書き・削除
> - ⛔ **セキュリティ侵害**: 予期しないコード実行
> - ⛔ **リカバリ不可能**: 自動承認により、警告なく破壊的操作が実行される
>
> ### 実行可能な条件（すべて必須）
>
> このスクリプトは、以下の**すべての条件を満たす上級ユーザーのみ**が実行してください：
>
> - ✅ Bashシェルスクリプトの動作原理を完全に理解している
> - ✅ パイプライン（`|`）とリダイレクトの仕組みを理解している
> - ✅ Gitのコミット、プッシュ、ロールバック操作に精通している
> - ✅ `yes`コマンドと`--dangerously-skip-permissions`のリスクを理解している
> - ✅ セキュリティインシデント発生時に対処できる技術力がある
> - ✅ サンドボックス環境（VM/コンテナ）を構築できる
>
> ### 必須の実行環境
>
> - **✅ 専用の仮想マシン（Virtualbox、VMware、Hyper-Vなど）**
> - **✅ Dockerコンテナなどの隔離環境**
> - **✅ このプロジェクト専用の環境**
>
> ### 絶対に実行してはいけない環境
>
> - ❌ **メインPC・本番システム**
> - ❌ **重要なファイルが含まれるマシン**
> - ❌ **共有開発環境**
> - ❌ **バックアップなしの環境**
>
> ### 🔰 初心者・中級者の方へ
>
> **このスクリプトは使用しないでください。**
>
> 代わりに以下の安全な方法を使用してください：
>
> 1. **手動翻訳**: Claude Codeを対話的に使用（各操作を手動で確認）
>    - 詳細: [`../translation/RESUME_TRANSLATION.md`](../translation/RESUME_TRANSLATION.md)
>
> 2. **質問**: 不明な点は[GitHub Issues](https://github.com/Unit-Wasteland/wasteland3-vanilla-langpack-japanese/issues)で質問
>
> 3. **学習**: まずBashとGitの基礎を学習してから、このスクリプトを理解する
>
> **わからないまま実行すると、システムが破壊される可能性があります。**

---

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

**⚠️ 再確認: リスクを理解していますか？**
- `--dangerously-skip-permissions` は全ての権限チェックをバイパスします
- `yes` コマンドは全ての対話的プロンプトに自動的に「y」を回答します
- **これは名前に「dangerously（危険に）」が含まれている理由を理解してください**
- **サンドボックス環境（VM/コンテナ）での実行が必須です**
- **メインPCや本番環境では絶対に実行しないでください**
- インターネットアクセスが制限された環境での使用を強く推奨します
- Gitブランチでの実行を推奨（変更の確認・ロールバックが容易）
- 実行前に必ず重要なデータのバックアップを取得してください

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

### ロックファイルエラー（Retranslation自動化のみ）

**症状:** "Another retranslation session is already running" エラーが表示される

**原因:**
- 以前の自動化セッションが異常終了（kill -9、システムクラッシュなど）してロックファイルが残っている
- 別のセッションが既に実行中

**解決方法:**

1. **ロック状態を確認:**
   ```bash
   ls -la automation/.retranslation.lock
   ```

2. **実行中のプロセスを確認:**
   ```bash
   ps aux | grep auto-retranslate
   ps aux | grep claude
   ```

3. **ロックを解除（3つの方法）:**

   **方法1: 自動化スクリプトの --unlock オプション（推奨）**
   ```bash
   ./automation/auto-retranslate.sh --unlock
   ```
   - 古いロックのみ安全に削除（プロセスが実行中の場合は警告）

   **方法2: 専用のロック解除スクリプト**
   ```bash
   ./automation/unlock-retranslation.sh         # 通常モード
   ./automation/unlock-retranslation.sh --force # 強制削除モード
   ```
   - カラー出力で状態を明確に表示
   - --force: プロセスが実行中でも強制削除（要注意）

   **方法3: 手動削除（最終手段）**
   ```bash
   # まず実行中のプロセスを終了
   kill <PID>  # または kill -9 <PID>

   # ロックファイルを削除
   rm automation/.retranslation.lock
   ```

**ロック機構について:**
- 2025年10月に追加された安全機能
- 複数の自動化セッションの同時実行を防止
- 正常終了時は自動的に削除される
- Ctrl+Cでも自動削除される（trapで処理）
- kill -9やシステムクラッシュでは残る可能性あり

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
