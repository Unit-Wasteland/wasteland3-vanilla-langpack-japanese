# Re-translation Workflow (翻訳やり直しワークフロー)

## 概要

このドキュメントは、構造破壊が発生したファイルを修正し、全翻訳をやり直すためのワークフローを定義します。

### 背景

自動翻訳処理の結果、Unity StringTableの構造マーカー（`""`）が日本語括弧（`「」`, `『』`）に変換され、ファイルがゲームにインポート不可能になりました。

**問題の例:**
- 破損: `string data = "「日本語テキスト」"`
- 正常: `string data = ""日本語テキスト""`

### 解決方針

1. **英語ファイルを新しいベース**として使用（構造保証）
2. **backup_brokenから日本語訳を抽出**（既存作業の活用）
3. **構造マーカーを厳格に保護**（再発防止）
4. **未翻訳分を新規翻訳**（完全な日本語化）
5. **完全自動化で実行**（人的エラー排除）

## ファイル構成

```
translation/
├── source/v1.6.9.420.309496/
│   ├── en_US/              # 英語ソース（新ベース用）
│   │   ├── StringTableData_English-CAB-*.txt (530,425行)
│   │   ├── DLC1/StringTableData_English-CAB-*.txt (120,559行)
│   │   └── DLC2/StringTableData_English-CAB-*.txt (77,353行)
│   └── es_ES/              # スペイン語（参考用、未使用）
├── target/v1.6.9.420.309496/ja_JP/
│   ├── StringTableData_English-CAB-*.txt  # 作業対象ファイル
│   ├── DLC1/
│   └── DLC2/
├── backup_broken/          # 壊れた日本語訳（参照元）
│   ├── StringTableData_English-CAB-*.txt
│   ├── DLC1/
│   └── DLC2/
├── nouns_glossary.json     # 用語集（英語→日本語）
├── .retranslation_progress.json  # 進捗管理ファイル（NEW）
└── STRUCTURE_PROTECTION_RULES.md  # 構造保護ルール
```

## ワークフローステップ

### Phase 0: 環境準備（手動実行、1回のみ）

```bash
# 1. 現在のtargetファイルをbackup_brokenに移動（完了済み）
# mkdir -p translation/backup_broken
# mv translation/target/v1.6.9.420.309496/ja_JP/* translation/backup_broken/

# 2. 英語ファイルを新しいベースとしてコピー
cp -r translation/source/v1.6.9.420.309496/en_US/* \
      translation/target/v1.6.9.420.309496/ja_JP/

# 3. 進捗管理ファイルの初期化
cat > translation/.retranslation_progress.json << 'EOF'
{
  "workflow_version": "2.0",
  "workflow_name": "retranslation",
  "start_date": "2025-10-22",
  "base_language": "en_US",
  "target_language": "ja_JP",
  "total_files": 3,
  "files": {
    "base_game": {
      "source_file": "translation/source/v1.6.9.420.309496/en_US/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt",
      "target_file": "translation/target/v1.6.9.420.309496/ja_JP/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt",
      "backup_file": "translation/backup_broken/StringTableData_English-CAB-83ff0546f42d84e747fefe7ae7126de0--1617434765046421955.txt",
      "total_lines": 530425,
      "total_entries_estimated": 51853,
      "current_line": 666,
      "entries_completed": 0,
      "status": "in_progress"
    },
    "dlc1": {
      "source_file": "translation/source/v1.6.9.420.309496/en_US/DLC1/StringTableData_English-CAB-01cf4ea31238681a8e1bd9559c0f3f3e--5815625736905989241.txt",
      "target_file": "translation/target/v1.6.9.420.309496/ja_JP/DLC1/StringTableData_English-CAB-01cf4ea31238681a8e1bd9559c0f3f3e--5815625736905989241.txt",
      "backup_file": "translation/backup_broken/DLC1/StringTableData_English-CAB-01cf4ea31238681a8e1bd9559c0f3f3e--5815625736905989241.txt",
      "total_lines": 120559,
      "total_entries_estimated": 12785,
      "current_line": 0,
      "entries_completed": 0,
      "status": "pending"
    },
    "dlc2": {
      "source_file": "translation/source/v1.6.9.420.309496/en_US/DLC2/StringTableData_English-CAB-6a212d8a4482b263f057ec8756825864-4193932453415687559.txt",
      "target_file": "translation/target/v1.6.9.420.309496/ja_JP/DLC2/StringTableData_English-CAB-6a212d8a4482b263f057ec8756825864-4193932453415687559.txt",
      "backup_file": "translation/backup_broken/DLC2/StringTableData_English-CAB-6a212d8a4482b263f057ec8756825864-4193932453415687559.txt",
      "total_lines": 77353,
      "total_entries_estimated": 7354,
      "status": "pending"
    }
  },
  "last_commit_hash": "",
  "total_entries_completed": 0,
  "estimated_total_entries": 71992,
  "next_action": "Process base_game starting from line 666"
}
EOF

# 4. gitコミット
git add translation/target/v1.6.9.420.309496/ja_JP/ \
         translation/.retranslation_progress.json \
         translation/RETRANSLATION_WORKFLOW.md \
         translation/STRUCTURE_PROTECTION_RULES.md
git commit -m "Initialize retranslation workflow: copy English files as new base

Preparation for complete retranslation with structure protection:
- Copied en_US files to ja_JP as new base (preserves structure)
- Created .retranslation_progress.json for progress tracking
- Added RETRANSLATION_WORKFLOW.md with detailed workflow
- Added STRUCTURE_PROTECTION_RULES.md with strict rules

Total scope: 71,992 entries (base game + DLC1 + DLC2)
Strategy: Extract Japanese from backup_broken, apply with structure protection

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Phase 1: 翻訳処理（自動実行）

**処理方式:**
1. **backup_brokenから日本語テキストを抽出**
   - 破損した構造マーカーを除去
   - 純粋な日本語テキストのみ取得

2. **英語ベースファイルの構造を保持**
   - `""` マーカーを維持
   - `[ ]`, `< >`, `::action::` を保持
   - 技術用語（Script Nodeなど）を保持

3. **テキスト部分のみ置換**
   - 構造部分は絶対に触らない
   - 日本語テキストを安全に適用

4. **未翻訳エントリの処理**
   - backup_brokenに日本語がない場合
   - 英語→日本語に新規翻訳
   - nouns_glossary.json参照

**具体的な処理ロジック（Claude Codeが実行）:**

```
FOR each file in [base_game, dlc1, dlc2]:
  WHILE current_line < total_lines:
    # 1. 50行チャンクを読み込み
    backup_chunk = Read(backup_file, offset=current_line, limit=50)
    target_chunk = Read(target_file, offset=current_line, limit=50)

    # 2. 各エントリを処理
    FOR each line in chunk:
      IF line contains 'string data = ':
        # backup_brokenから日本語テキストを抽出
        japanese_text = extract_japanese(backup_chunk[line])

        IF japanese_text exists and is_valid_japanese(japanese_text):
          # 構造を保持して日本語を適用
          english_structure = extract_structure(target_chunk[line])
          new_line = apply_japanese_with_structure(english_structure, japanese_text)
        ELSE:
          # 未翻訳の場合は新規翻訳
          english_text = extract_text(target_chunk[line])
          japanese_text = translate_with_glossary(english_text)
          new_line = apply_japanese_with_structure(english_structure, japanese_text)

        # 3. 構造検証
        ASSERT verify_structure_markers(new_line)
        ASSERT verify_line_count(target_file)

    # 4. チャンクを保存
    Edit(target_file, old_chunk, new_chunk)
    entries_completed += count_entries_in_chunk
    current_line += 50

    # 5. 100エントリごとにコミット
    IF entries_completed % 100 == 0:
      git_commit_with_progress()
      update_progress_file()

    # 6. メモリチェック
    IF memory_usage > 4GB:
      WARNING("Memory approaching limit")
      commit_immediately()

    IF memory_usage > 6GB:
      ERROR("Memory limit reached - restart required")
      EXIT
  END WHILE
END FOR
```

### Phase 2: 品質検証（自動実行）

**検証項目:**

```bash
# 1. 行数一致確認
wc -l translation/source/v1.6.9.420.309496/en_US/*.txt \
      translation/target/v1.6.9.420.309496/ja_JP/*.txt

# 2. 構造マーカー検証（破損チェック）
# 破損パターンが存在しないことを確認
! grep 'string data = "「' translation/target/v1.6.9.420.309496/ja_JP/*.txt
! grep 'string data = "『' translation/target/v1.6.9.420.309496/ja_JP/*.txt

# 3. 正常パターン確認
grep -c 'string data = "".*[ぁ-ん].*""' translation/target/v1.6.9.420.309496/ja_JP/*.txt

# 4. 中国語混入チェック
# （簡体字の範囲: \u4e00-\u9fa5 のうち日本語で使われないもの）
# 手動で確認が必要

# 5. アクションマークアップ検証
grep 'string data = ""::' translation/target/v1.6.9.420.309496/ja_JP/*.txt | \
  grep -v '::[a-z]*::' && echo "ERROR: Invalid action markup found"

# 6. Script Node検証（翻訳されていないことを確認）
! grep 'string data = ""スクリプトノード' translation/target/v1.6.9.420.309496/ja_JP/*.txt
```

## メモリ管理戦略

### チャンクサイズとコミット頻度

| 設定項目 | 値 | 理由 |
|---------|---|-----|
| **read_chunk_size** | 50行 | 2025-10-22のheap OOM後、安全側に調整 |
| **max_chunk_size** | 100行 | 絶対に超えてはいけない上限 |
| **batch_size** | 50エントリ | 処理サイクルあたりの処理数 |
| **commit_frequency** | 100エントリ | コミット間隔（メモリ圧力軽減） |
| **memory_warning** | 4GB | 警告閾値（チャンクサイズ縮小） |
| **memory_limit** | 6GB | 強制再起動閾値 |

### セッション再起動戦略

自動化スクリプト（`automation/auto-retranslate.sh`）が処理:
- 2,000-3,000エントリごとにメモリチェック
- 4GB到達で警告、チャンクサイズを25行に縮小
- 6GB到達でセッション再起動
- 進捗ファイルから自動復帰

## 自動化スクリプト

### 起動方法

```bash
# 完全自動実行（推奨）
./automation/auto-retranslate.sh

# 手動セッション（テスト・デバッグ用）
claude
# 以下を入力:
# translation/.retranslation_progress.json を読み込んで、
# translation/RETRANSLATION_WORKFLOW.md に従って翻訳やり直し作業を継続してください。
```

### スクリプト動作

```bash
# 疑似コード
while true; do
  # 1. Claude Codeセッション起動
  start_claude_session_with_permissions()

  # 2. 進捗ファイル読み込みと処理実行
  execute_retranslation_workflow()

  # 3. 進捗確認
  entries_completed_this_session = check_progress()

  # 4. 完了判定
  if all_files_completed; then
    echo "✅ 全翻訳やり直し完了！"
    exit 0
  fi

  # 5. エラー検出
  if entries_completed_this_session == 0; then
    consecutive_zero_sessions++
    if consecutive_zero_sessions >= 3; then
      echo "❌ エラー: 3連続で進捗なし"
      exit 1
    fi
  else
    consecutive_zero_sessions=0
  fi

  # 6. メモリチェックと再起動
  sleep 60  # 次セッション前のクールダウン
done
```

## トラブルシューティング

### 問題1: 構造マーカーが破損している

**検出方法:**
```bash
grep 'string data = "「' translation/target/v1.6.9.420.309496/ja_JP/*.txt
```

**原因:**
- 構造保護ロジックの不具合
- Claude Codeが意図せず日本語括弧を使用

**解決方法:**
1. 該当セクションのgit revert
2. 構造保護ルールを再確認
3. より小さいチャンク（25行）で再実行

### 問題2: メモリ不足でクラッシュ

**検出方法:**
- Node.js heap out of memory エラー
- セッションが応答しなくなる

**解決方法:**
1. 進捗ファイルから最後の成功点を確認
2. チャンクサイズを25行に縮小
3. コミット頻度を50エントリに増加
4. セッション再起動

### 問題3: 翻訳品質が低い

**検出方法:**
- 中国語（簡体字）が混入
- 用語集と異なる訳語が使用されている

**解決方法:**
1. nouns_glossary.jsonを確認・更新
2. 該当エントリを手動修正
3. git commitで記録

### 問題4: 進捗が停止している

**検出方法:**
```bash
tail -100 automation/retranslation-automation.log
```

**原因:**
- 3連続でentries_completed == 0
- 権限承認でブロック
- 予期しないエラー

**解決方法:**
1. ログファイルで原因特定
2. 手動セッションでデバッグ
3. 問題解決後、自動化スクリプト再起動

## 進捗の確認

```bash
# 現在の進捗状況
cat translation/.retranslation_progress.json | jq '.total_entries_completed, .estimated_total_entries'

# 完了率計算
echo "scale=2; $(jq '.total_entries_completed' translation/.retranslation_progress.json) * 100 / $(jq '.estimated_total_entries' translation/.retranslation_progress.json)" | bc

# 最近のコミット
git log --oneline --grep="retranslation" -10

# ファイルごとの進捗
cat translation/.retranslation_progress.json | jq '.files'
```

## 完了後の確認事項

- [ ] 全ファイルの行数が元ファイルと一致
- [ ] 破損した構造マーカーが0件
- [ ] 正常な日本語エントリ数が71,992件（またはそれに近い）
- [ ] 中国語混入なし
- [ ] アクションマークアップが全て英語のまま
- [ ] Script Nodeが翻訳されていない
- [ ] Git履歴に全コミットが記録されている
- [ ] nouns_glossary.jsonに準拠した訳語が使用されている

## 関連ドキュメント

- `translation/STRUCTURE_PROTECTION_RULES.md` - 構造保護の厳格なルール
- `translation/nouns_glossary.json` - 用語集
- `automation/README.md` - 自動化システムの詳細
- `CLAUDE.md` - プロジェクト全体の概要
