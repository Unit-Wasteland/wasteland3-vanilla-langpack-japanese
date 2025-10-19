# Wasteland 3 Japanese Translation - Automated Translation Script
# This script runs Claude Code in a loop, automatically restarting sessions
# when memory usage gets too high, enabling unattended translation work.

param(
    [int]$MaxMemoryMB = 7000,           # Restart when Claude Code uses this much memory
    [int]$EntriesPerSession = 2500,     # Target entries per session
    [int]$MaxSessions = 100,            # Maximum number of sessions to run (safety limit)
    [string]$WorkingDir = "/home/user/project_claude/game_wasteland/wasteland3-vanilla-langpack-japanese"
)

# Configuration
$ErrorActionPreference = "Continue"
$SessionCount = 0
$TotalEntriesTranslated = 0

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
translation/.translation_progress.json を読み込んで、CLAUDE.mdのルールに従って翻訳作業を継続してください。

目標: 約${EntriesPerSession}エントリを翻訳して、コミット・プッシュしてから進捗を報告してください。

処理完了後、必ず以下を報告してください:
1. 翻訳完了エントリ数
2. 最新のコミットハッシュ
3. 次に翻訳するセクション名

メモリ管理のため、${EntriesPerSession}エントリ完了後は一旦作業を終了してください。
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
