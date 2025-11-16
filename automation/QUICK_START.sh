#!/bin/bash
# クイックスタートスクリプト - 次回セッション用

echo "=================================================="
echo "  Wasteland 3 未翻訳エントリ修正 - クイックスタート"
echo "=================================================="
echo ""

# 1. 状態確認
echo "【1】現在の状態を確認中..."
echo ""
echo "Git状態:"
git status --short
echo ""
echo "最新コミット:"
git log --oneline -3
echo ""
echo "未翻訳エントリ数:"
wc -l automation/.untranslated_lines.txt
echo ""
echo "実行中のプロセス:"
ps aux | grep auto-fix | grep -v grep || echo "  なし（停止中）"
echo ""

# 2. 選択肢を表示
echo "【2】次のアクションを選択してください:"
echo ""
echo "  A) バックグラウンドで自動修正を再開（推奨）"
echo "  B) フォアグラウンドで自動修正を再開"
echo "  C) 進捗状況のみ確認"
echo "  D) 何もしない（手動で作業）"
echo ""
read -p "選択 (A/B/C/D): " choice

case $choice in
  [Aa]*)
    echo ""
    echo "バックグラウンドで再開します..."
    CURRENT_PID=$(pgrep -f "node.*claude" | head -1)
    if [ -z "$CURRENT_PID" ]; then
      echo "警告: Claude Code PIDが見つかりません。保護なしで起動します。"
      nohup bash automation/auto-fix-untranslated.sh > automation/.auto-fix-bg.log 2>&1 &
    else
      echo "Claude Code PID: $CURRENT_PID を保護します"
      bash -c "export PROTECTED_CLAUDE_PID=$CURRENT_PID && nohup bash automation/auto-fix-untranslated.sh > automation/.auto-fix-bg.log 2>&1 &"
    fi
    sleep 2
    echo ""
    echo "✓ バックグラウンドで起動しました"
    echo ""
    echo "モニタリング方法:"
    echo "  bash automation/check-auto-fix-status.sh"
    echo "  tail -f automation/untranslated-fix-automation.log"
    ;;
  [Bb]*)
    echo ""
    echo "フォアグラウンドで再開します..."
    echo "（Ctrl+C で停止できます）"
    echo ""
    sleep 2
    bash automation/auto-fix-untranslated.sh
    ;;
  [Cc]*)
    echo ""
    bash automation/check-auto-fix-status.sh
    ;;
  [Dd]*)
    echo ""
    echo "何もしません。手動で作業を続けてください。"
    ;;
  *)
    echo ""
    echo "無効な選択です。"
    ;;
esac

echo ""
echo "クイックスタート完了"
echo "=================================================="
