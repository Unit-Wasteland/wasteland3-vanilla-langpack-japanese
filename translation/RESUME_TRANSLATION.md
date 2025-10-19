# Translation Session Resume Guide

このファイルは、Claude Codeセッションを再開する際の自動化ガイドです。

## 自動再開方法

新しいClaude Codeセッションを開始したら、以下のプロンプトをコピー&ペーストしてください：

```
translation/.translation_progress.json を読み込んで、CLAUDE.mdのルールに従って翻訳作業を継続してください。
```

これだけで、Claude Codeが：
1. 進捗状態ファイルを読み込み
2. 前回の終了位置を確認
3. wasteland3-translatorサブエージェントを起動
4. 翻訳作業を自動的に継続

します。

## 現在の進捗

最終更新日時は `.translation_progress.json` を参照してください。

## メモリ管理

- セッションが6GB以上のメモリを使用したら、セッションを終了して再開することを推奨
- 目安: 2,000-3,000エントリごとにセッション再開
- メモリ確認コマンド: `ps aux | grep claude | awk '{print $6/1024 " MB"}'`

## トラブルシューティング

### Q: 進捗ファイルが見つからない
A: Gitから最新版をpullしてください: `git pull`

### Q: どこから再開すればいいかわからない
A: Git logを確認: `git log --oneline -10`
   最後のコミットメッセージに完了したセクションが記載されています

### Q: メモリエラーが発生する
A: チャンクサイズを50-100行に削減してください（CLAUDE.md参照）
