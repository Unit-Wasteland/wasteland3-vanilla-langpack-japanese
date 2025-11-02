# Git Hooks

This directory contains Git hooks for the Wasteland 3 Japanese translation project.

## Available Hooks

### pre-commit

**Purpose**: Prevents commits containing action markers translated to Japanese

**What it does**:
- Checks if translation file is being committed
- Scans for Japanese characters inside `::action::` markers
- Blocks the commit if any violations are found
- Provides clear error messages with line numbers

**Why it's important**:
- Action markers control game animations, sounds, and effects
- Translating them breaks game functionality
- This hook provides the last line of defense before code enters the repository

**Added**: 2025-11-02 (Prevention measure for Session 7 error - 3 instances found and fixed)

## Installation

### Quick Install (Recommended)

Run the installer script from the project root:

```bash
./automation/git-hooks/install-hooks.sh
```

This will:
- Copy the pre-commit hook to `.git/hooks/`
- Set correct permissions
- Fix line endings (CRLF → LF)

### Manual Install

```bash
# From project root
cp automation/git-hooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
sed -i 's/\r$//' .git/hooks/pre-commit
```

## Verification

After installation, test the hook:

```bash
# This should show the hook is active
git commit --allow-empty -m "Test commit"
# Expected output: "✅ Pre-commit validation passed"
```

## Hook Behavior

### When translation file is NOT staged

```
🔍 Running pre-commit validation...
  → Target file not staged, skipping validation
✅ Pre-commit validation passed
```

### When translation file IS staged (no errors)

```
🔍 Running pre-commit validation...
  → Validating action markers in: translation/target/.../StringTableData_English-CAB-...txt
  ✅ Action marker validation passed
✅ Pre-commit validation passed
```

### When errors are found

```
🔍 Running pre-commit validation...
  → Validating action markers in: translation/target/.../StringTableData_English-CAB-...txt

❌ ERROR: Action markers contain Japanese characters!

Found the following action markers with Japanese:
::ため息::
::笑う::
::電気的な鼾::

Action markers MUST remain in English. Please fix before committing.

To find the exact lines, run:
  grep -n '::[^:]*[ぁ-ゖァ-ヾ一-龯][^:]*::' translation/target/.../StringTableData_English-CAB-...txt
```

## Bypassing the Hook (NOT RECOMMENDED)

If you absolutely need to bypass the hook (for debugging purposes only):

```bash
git commit --no-verify -m "Your message"
```

**WARNING**: Only use `--no-verify` if you are certain the action markers are correct. Bypassing this check can break game functionality.

## Troubleshooting

### Hook not running

**Problem**: Git doesn't execute the hook

**Solution**:
1. Check if hook file exists: `ls -la .git/hooks/pre-commit`
2. Check if it's executable: `chmod +x .git/hooks/pre-commit`
3. Check shebang line: `head -1 .git/hooks/pre-commit` (should be `#!/bin/bash`)
4. Check line endings: `file .git/hooks/pre-commit` (should be "Bourne-Again shell script, ASCII text executable")

### Hook shows "No such file or directory"

**Problem**: CRLF line endings in hook file

**Solution**:
```bash
sed -i 's/\r$//' .git/hooks/pre-commit
```

### Hook gives false positives

**Problem**: Hook blocks valid commits

**Solution**:
1. Verify the flagged lines actually contain Japanese in action markers
2. Run manual check: `grep -o '::[^:]*[ぁ-ゖァ-ヾ一-龯][^:]*::' translation/target/.../StringTableData_English-CAB-...txt`
3. If false positive, report the issue

## Updating Hooks

When hooks are updated in the repository:

```bash
# Re-run the installer
./automation/git-hooks/install-hooks.sh
```

Or manually copy the new version:

```bash
cp automation/git-hooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
sed -i 's/\r$//' .git/hooks/pre-commit
```

## Related Documentation

- **ACTION_MARKER_PREVENTION.md**: Comprehensive prevention strategy
- **CLAUDE.md**: Project guidelines including action marker rules
- **STRUCTURE_PROTECTION_RULES.md**: All structure protection rules

---

**Created**: 2025-11-02
**Last Updated**: 2025-11-02
**Maintainer**: Claude Code Automation
