# Wasteland 3 Japanese Translation - Automated Translation Script
# This script runs Claude Code in a loop, automatically restarting sessions
# when memory usage gets too high, enabling unattended translation work.

param(
    [int]$MaxMemoryMB = 7000,           # Restart when Claude Code uses this much memory
    [int]$EntriesPerSession = 2500,     # Target entries per session
    [int]$MaxSessions = 100,            # Maximum number of sessions to run (safety limit)
    [string]$WorkingDir = ""            # Auto-detect if not specified
)

# Configuration
$ErrorActionPreference = "Continue"
$SessionCount = 0
$TotalEntriesTranslated = 0

# Auto-detect working directory if not specified
if ([string]::IsNullOrEmpty($WorkingDir)) {
    $ScriptDir = Split-Path -Parent $PSCommandPath
    $WorkingDir = Split-Path -Parent $ScriptDir
}

# Logging function
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    Write-Host $LogMessage
    Add-Content -Path "$WorkingDir/automation/translation-automation.log" -Value $LogMessage
}

# Function to get Claude Code process memory usage
function Get-ClaudeMemoryUsage {
    $Process = Get-Process -Name "claude" -ErrorAction SilentlyContinue
    if ($Process) {
        return [math]::Round($Process.WorkingSet64 / 1MB, 2)
    }
    return 0
}

# Function to read translation progress
function Get-TranslationProgress {
    $ProgressFile = "$WorkingDir/translation/.translation_progress.json"
    if (Test-Path $ProgressFile) {
        $Progress = Get-Content $ProgressFile | ConvertFrom-Json
        return $Progress
    }
    return $null
}

# Function to update translation progress
function Update-TranslationProgress {
    param([int]$SessionNumber, [int]$TotalEntries)

    $ProgressFile = "$WorkingDir/translation/.translation_progress.json"
    if (Test-Path $ProgressFile) {
        $Progress = Get-Content $ProgressFile | ConvertFrom-Json
        $Progress.session_number = $SessionNumber
        $Progress.total_entries_completed = $TotalEntries
        $Progress.last_updated = (Get-Date -Format "o")
        $Progress | ConvertTo-Json -Depth 10 | Set-Content $ProgressFile
    }
}

# Main automation loop
Write-Log "=== Wasteland 3 Translation Automation Started ==="
Write-Log "Max Memory: ${MaxMemoryMB}MB, Entries/Session: $EntriesPerSession, Max Sessions: $MaxSessions"
Write-Log "Working Directory: $WorkingDir"

while ($SessionCount -lt $MaxSessions) {
    $SessionCount++
    Write-Log "=== Starting Session #$SessionCount ===" "SESSION"

    # Get current progress
    $Progress = Get-TranslationProgress
    if ($Progress) {
        $StartEntries = $Progress.total_entries_completed
        Write-Log "Resuming from $StartEntries entries completed"
    } else {
        $StartEntries = 0
        Write-Log "Starting fresh translation session"
    }

    # Prepare Claude Code command
    $ClaudeCommand = @"
translation/.translation_progress.json を読み込んで、CLAUDE.mdおよびTRANSLATION_WORKFLOW.mdのルールに厳格に従って翻訳作業を継続してください。

⚠️ **自動実行モード - 重要な制約**:
- **サブエージェントは使用しない** - メインセッションで直接翻訳
- ファイル編集権限を含む全ての権限リクエストは自動承認
- ユーザーへの質問や確認なしで作業を進める

⚠️ **CRITICAL: CLAUDE.mdの厳格なルール - 絶対に遵守**:

1. **Unity StringTable形式の保持（最重要）**:
   - 通常のテキスト: ``string data = """"日本語テキスト""""""``（ダブルダブルクォート）
   - 空文字列: ``string data = """"""``
   - **英語版の構造を完全に保持**: 英語版のダブルクォート数と完全一致させる
   - テキスト内に ``""`` がある場合、そのまま保持（エスケープしない）
   - **絶対禁止**: ``\""`` エスケープ、日本語括弧 ``「」`` ``『』``、全角クォート ``""""`` ``''''``

2. **::action:: マーカーの厳格な保持**:
   - **絶対に翻訳しない**: ``::sigh::``, ``::laughs::``, ``::static::`` など
   - 英語のまま文字単位で完全保持
   - 翻訳後、必ず検証: ``grep -o '::[^:]*[ぁ-ゖァ-ヾ一-龯][^:]*::' TARGET_FILE`` → 出力なし = OK

3. **固有名詞の一貫性（必須）**:
   - **必ず nouns_glossary.json を参照**してから翻訳
   - 例: ""Rangers"" → ""レンジャー""（""レンジャーズ""は誤り）
   - 例: ""Patriarch"" → ""パトリアーク""

4. **do_not_translate リストの遵守**:
   - ""Script Node"", ""[Global:]"", ""[Switch to]"" などは翻訳しない
   - nouns_glossary.json の do_not_translate セクションを確認

5. **スペイン語版参照ルール**:
   - スペイン語版が翻訳されている → 日本語にも翻訳
   - スペイン語版が空 or 英語と同じ → do_not_translate リストを確認
     - リストにある → 翻訳しない
     - リストにない → 文脈で判断（通常は翻訳）

6. **翻訳手順（Edit tool必須、スクリプト禁止）**:
   - Readツールでファイル読み込み
   - nouns_glossary.json で固有名詞確認
   - Editツールで1エントリずつ翻訳（スクリプト一括処理は絶対禁止）
   - old_stringは英語版と完全一致させる
   - 行数を保持（530,425行）

7. **メモリ管理（6GB RAM環境）**:
   - 各Read/Edit操作: 最大200行
   - コミット頻度: 500エントリまたはセクション完了時（少ない方）
   - 大きなファイルは複数回のRead/Edit操作に分割

8. **処理順序（必須）**:
   - ファイルを先頭から順次処理
   - スキップ、優先順位付け、バッチ処理は禁止
   - セクション完了後、次のセクションへ

⚠️ **目標**: 約${EntriesPerSession}エントリを翻訳して、コミット・プッシュしてから進捗を報告

処理完了後、以下の形式で報告してください:
- 翻訳完了エントリ数: XXXX
- 最新コミットハッシュ: XXXXXXX
- 次のセクション: section_name

この報告後、セッションを終了してください。
"@

    # Create temporary command file
    $TempCommandFile = "$WorkingDir/automation/.current_command.txt"
    $ClaudeCommand | Out-File -FilePath $TempCommandFile -Encoding UTF8

    Write-Log "Command prepared: Translate ~${EntriesPerSession} entries"

    # Execute Claude Code with command via stdin
    try {
        Write-Log "Launching Claude Code..."

        # Change to working directory and run Claude Code
        # --dangerously-skip-permissions: Bypass all permission checks for automated execution
        # yes: Automatically answer 'y' to any interactive permission prompts
        $ClaudeProcess = Start-Process -FilePath "wsl" -ArgumentList @(
            "bash", "-c",
            "cd '$WorkingDir' && yes | cat automation/.current_command.txt | claude --dangerously-skip-permissions 2>&1 | tee automation/.session_${SessionCount}_output.log"
        ) -NoNewWindow -Wait -PassThru

        Write-Log "Claude Code session completed with exit code: $($ClaudeProcess.ExitCode)"

        # Check memory usage (in case process is still running)
        $MemoryUsage = Get-ClaudeMemoryUsage
        Write-Log "Memory usage at end: ${MemoryUsage}MB"

        # Parse output to get progress
        $OutputFile = "$WorkingDir/automation/.session_${SessionCount}_output.log"
        if (Test-Path $OutputFile) {
            $Output = Get-Content $OutputFile -Raw

            # Try to extract entry count from output (simple pattern matching)
            if ($Output -match "(\d+)\s*entries") {
                $EntriesThisSession = [int]$matches[1]
                Write-Log "Detected $EntriesThisSession entries translated this session"
                $TotalEntriesTranslated += $EntriesThisSession
            }
        }

        # Update progress file
        Update-TranslationProgress -SessionNumber $SessionCount -TotalEntries ($StartEntries + $TotalEntriesTranslated)

        # Check if we should continue
        $Progress = Get-TranslationProgress
        if ($Progress -and $Progress.next_action -match "complete|finished|done") {
            Write-Log "Translation appears to be complete!" "SUCCESS"
            break
        }

        # Brief pause before next session
        Write-Log "Waiting 10 seconds before starting next session..."
        Start-Sleep -Seconds 10

    } catch {
        Write-Log "Error in session: $_" "ERROR"
        Write-Log "Waiting 30 seconds before retry..."
        Start-Sleep -Seconds 30
    }
}

Write-Log "=== Translation Automation Completed ===" "SUCCESS"
Write-Log "Total Sessions: $SessionCount"
Write-Log "Total Entries Translated: $TotalEntriesTranslated"
Write-Log "Check translation/.translation_progress.json for final status"
