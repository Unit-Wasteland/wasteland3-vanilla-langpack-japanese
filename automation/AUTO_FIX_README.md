# Auto-Fix Untranslated - クイックリファレンス

## 📊 ステータス確認（次のセッションで最初に実行）

```bash
bash automation/check-auto-fix-status.sh
```

このコマンドで以下が確認できます：
- ✅ プロセスの実行状況（PID、稼働時間）
- 📈 進捗状況（修正済み/残り件数、進捗率）
- 📝 最新のログ（直近10行）
- 📁 ログファイルのサイズ

---

## 🔍 リアルタイム監視

### メインログ（推奨）
```bash
tail -f automation/untranslated-fix-automation.log
```

表示内容：
- セッション開始/終了
- メモリ使用量（30秒ごと）
- 処理済みエントリ数
- バリデーション結果
- git push 結果

### バックグラウンドログ
```bash
tail -f automation/.auto-fix-bg.log
```

---

## 📈 進捗詳細確認

### 未翻訳残数
```bash
wc -l automation/.untranslated_lines.txt
```

### 次に処理される行番号（先頭20件）
```bash
head -20 automation/.untranslated_lines.txt
```

### 最新の未翻訳スキャン結果
```bash
cat automation/.untranslated_report.txt | tail -50
```

---

## 🛑 プロセス制御

### 状態確認
```bash
ps aux | grep auto-fix-untranslated
```

### 停止（正常終了）
```bash
# 1. PIDを確認
bash automation/check-auto-fix-status.sh | grep "PID:"

# 2. 停止
kill <PID>
```

### 強制停止
```bash
kill -9 <PID>
```

### 再開（停止している場合）
```bash
# 現在のClaude Code PIDを保護しながら起動
PROTECTED_CLAUDE_PID=$(pgrep claude | head -1) \
  nohup bash automation/auto-fix-untranslated.sh > automation/.auto-fix-bg.log 2>&1 &

# または簡易スクリプト使用
bash /tmp/start-auto-fix.sh
```

---

## 🎯 現在の設定

- **1セッションあたりの処理数**: 20エントリ
- **メモリ上限**: 5000MB (5GB)
- **監視間隔**: 30秒
- **最大セッション数**: 1050セッション

### 予想完了時間
- **総エントリ数**: 20,952個
- **予想セッション数**: 約1,048セッション
- **1セッション平均時間**: 5-10分
- **完了予想**: 3-7日

---

## ⚠️ トラブルシューティング

### プロセスが停止している
```bash
# ログで原因確認
tail -50 automation/untranslated-fix-automation.log

# よくある原因：
# - 3連続ゼロ修正（→ ログ確認、手動介入）
# - メモリ超過（→ ENTRIES_PER_SESSION を減らす）
# - git push 失敗3連続（→ ネットワーク確認）
```

### 進捗が遅い
```bash
# メモリ使用量確認
tail -f automation/untranslated-fix-automation.log | grep "Memory usage"

# セッション完了時間確認
grep "Session #" automation/untranslated-fix-automation.log | tail -5
```

### 未翻訳リストを再生成
```bash
bash automation/generate-untranslated-list.sh
```

---

## 📝 ログファイルの場所

| ファイル | 内容 |
|---------|------|
| `automation/untranslated-fix-automation.log` | メインログ（セッション詳細） |
| `automation/.auto-fix-bg.log` | バックグラウンド起動ログ |
| `automation/.fix_untranslated_output.log` | 各Claude Codeセッション出力 |
| `automation/.untranslated_lines.txt` | 未翻訳行番号リスト |
| `automation/.untranslated_report.txt` | 検証スクリプト完全レポート |

---

## 🔄 このセッションを終了しても大丈夫？

**✅ はい、大丈夫です！**

自動修正プロセスは：
- `nohup` で起動（親プロセスから独立）
- 独自のClaude Codeセッションを起動
- このセッション終了後も継続実行
- ログファイルに全て記録

次のセッションで再開時：
```bash
# ステータス確認
bash automation/check-auto-fix-status.sh
```

---

**作成日**: 2025-11-16
**バージョン**: 1.0
