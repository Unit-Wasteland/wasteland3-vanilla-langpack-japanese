# 翻訳漏れ再発防止策

**作成日**: 2025-11-09
**問題**: Session R3-202で1つのエントリ（line 202826）が翻訳されずに残っていた
**影響**: 自動化システムが品質検証で停止、手動修正が必要に

---

## 実施した再発防止策

### 1. 自動修正システムの強化

#### 1.1 翻訳漏れ自動修正スクリプトの追加

**新規ファイル**: `automation/auto-fix-untranslated.py`

**機能**:
- 翻訳されていないエントリを自動検出
- 用語集（nouns_glossary.json）を使用して自動翻訳
- 複雑な対話は「manual fix needed」と報告

**使用方法**:
```bash
python3 automation/auto-fix-untranslated.py TARGET_FILE SOURCE_FILE REFERENCE_FILE \
  --start-line 390 --end-line CURRENT_LINE \
  --glossary translation/nouns_glossary.json
```

**戻り値**:
- `0`: 全て自動修正成功
- `1`: 翻訳漏れなし（何もしない）
- `2`: 一部手動修正が必要（複雑な対話など）

#### 1.2 auto-fix-errors.shの拡張

**変更内容**:
- `fix_untranslated_entries()` 関数を追加
- メインルーチンに翻訳漏れ修正を統合
- アクションマーカー修正と並列して実行

**実行順序**:
1. アクションマーカー修正
2. **翻訳漏れ修正**（NEW）
3. 構造エラー分析（将来実装予定）

### 2. セッション内検証の強化

#### 2.1 コマンドファイルの改善

**ファイル**: `automation/auto-retranslate.sh` (行459-490)

**強化内容**:

**各編集後の検証** (MANDATORY - ENHANCED 2025-11-09):

a) **構造検証** (既存):
```bash
python3 translation/validate_structure_v2.py TARGET_FILE --source SOURCE_FILE --detailed
```
→ エラー数: 0 を確認

b) **アクションマーカー検証** (既存):
```bash
grep -o '::[^:]*[ぁ-ゖァ-ヾ一-龯][^:]*::' TARGET_FILE
```
→ 結果が空であることを確認

c) **品質検証** (**NEW - 2025-11-09追加**):
```bash
python3 translation/validate_translation_quality.py TARGET_FILE \
  --reference REFERENCE_FILE \
  --start-line START_LINE \
  --end-line END_LINE \
  --glossary translation/nouns_glossary.json
```
→ **Total issues found: 0** を確認
→ 特に **"Untranslated English entries: 0"** を厳格に確認

**重要なルール**:
- ✅ **全ての検証が合格するまでコミットしない**
- ✅ **検証を1つでもスキップしてはならない**
- ✅ **「たぶん大丈夫」という推測は禁止**
- ✅ **必ず実際にスクリプトを実行して確認**

### 3. 自動化スクリプトの検証フロー改善

#### 3.1 品質検証の実行タイミング

**ファイル**: `automation/auto-retranslate.sh` (行638-700)

**フロー**:
1. セッション完了
2. **構造検証** → 失敗時: auto-fix実行
3. **品質検証** → 失敗時: auto-fix実行（**NEW**）
4. 両方合格 → git push

**auto-fix失敗時の動作**:
- バックアップファイルを保持
- 自動化を停止
- ログファイルに詳細を記録
- 手動介入を促す

---

## 期待される効果

### 即時効果
1. **簡単な翻訳漏れは自動修正**
   - 用語集にある固有名詞
   - 簡単な語句

2. **複雑な対話は早期検出**
   - セッション終了後すぐに検出
   - 手動修正を即座に促す

### 長期効果
1. **品質の向上**
   - 翻訳漏れゼロを目指す
   - 検証の徹底

2. **作業効率の向上**
   - 自動修正で手動作業を削減
   - 早期検出で手戻りを最小化

---

## 今後の課題

### 1. より高度な自動翻訳

**現状**: 用語集マッチングのみ

**改善案**:
- Claude APIを使用した自動翻訳
- セッション内で即座に修正
- より複雑な対話も自動処理

### 2. 構造エラーの自動修正

**現状**: 検出のみ、修正は手動

**改善案**:
- 引用符数の自動修正
- エスケープシーケンスの自動修正
- より堅牢な修正アルゴリズム

### 3. リアルタイム検証

**現状**: 編集後にスクリプト実行

**改善案**:
- 編集中にリアルタイム検証
- エラーを即座にフィードバック
- プレコミットフックの活用

---

## テスト結果

### テストケース: line 202826 (Session R3-202エラー)

**エントリ内容**:
```
EN: "One moment. One moment. Well, either you made an incredibly lucky guess,
     or you are who you say you are. All right, I guess I'll have to trust you."
ES: "Un momento. Un momento. O bien habéis tenido mucha suerte,
     o sois quienes decís ser. Bueno, supongo que debo confiar en vosotros."
JA: (翻訳漏れ) → 手動修正済み
```

**auto-fix結果**:
- ❌ 用語集マッチなし（複雑な対話のため）
- ✅ "needs manual fix" として正しく報告
- ✅ バックアップ保持、システム停止、手動介入促す

**結論**:
- 自動修正は期待通り動作（簡単なものだけ修正、複雑なものは報告）
- セッション終了後の検証で確実に検出
- 手動修正のワークフローが正常に機能

---

## 運用ガイドライン

### 自動化実行時
1. `./automation/auto-retranslate.sh` を実行
2. ログを監視: `tail -f automation/retranslation-automation.log`
3. エラー発生時: `.session_*_output.log` を確認
4. auto-fix失敗時: 手動修正を実施

### 手動修正時
1. 検証スクリプトで問題箇所を特定
2. エントリを手動翻訳
3. 全ての検証を再実行（構造・品質・アクションマーカー）
4. 合格後、git commit & push

### 検証コマンド（手動実行時）
```bash
# 構造検証
python3 translation/validate_structure_v2.py TARGET_FILE \
  --source SOURCE_FILE --detailed

# 品質検証
python3 translation/validate_translation_quality.py TARGET_FILE \
  --reference REFERENCE_FILE \
  --start-line 390 --end-line CURRENT_LINE \
  --glossary translation/nouns_glossary.json

# アクションマーカー検証
grep -o '::[^:]*[ぁ-ゖァ-ヾ一-龯][^:]*::' TARGET_FILE
```

---

## まとめ

**2025-11-09実施の再発防止策**:
1. ✅ 翻訳漏れ自動修正スクリプト作成
2. ✅ auto-fix-errors.shに統合
3. ✅ セッション内検証を強化
4. ✅ コマンドファイルに品質検証を追加
5. ✅ 運用ガイドライン整備

**期待される結果**:
- 翻訳漏れの早期検出・自動修正
- 手動介入の最小化
- 翻訳品質の向上
- 作業効率の向上

**次のアクション**:
- 自動化を再開: `./automation/auto-retranslate.sh`
- ログを監視してシステムが正常に動作することを確認
- 今後のセッションで再発がないことを検証
