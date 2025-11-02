#!/bin/bash
#
# Git Hooks Installer
#
# Installs pre-commit hook for action marker validation
# Run from project root: ./automation/git-hooks/install-hooks.sh
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOKS_DIR="$PROJECT_ROOT/.git/hooks"

echo "📦 Installing Git hooks..."

# Check if .git directory exists
if [ ! -d "$PROJECT_ROOT/.git" ]; then
    echo "❌ Error: Not a git repository"
    echo "   Make sure you run this script from the project root"
    exit 1
fi

# Install pre-commit hook
echo "  → Installing pre-commit hook..."
cp "$SCRIPT_DIR/pre-commit" "$HOOKS_DIR/pre-commit"
chmod +x "$HOOKS_DIR/pre-commit"

# Fix line endings (convert CRLF to LF if needed)
sed -i 's/\r$//' "$HOOKS_DIR/pre-commit" 2>/dev/null || true

echo "✅ Git hooks installed successfully!"
echo ""
echo "Installed hooks:"
echo "  - pre-commit: Action marker validation"
echo ""
echo "The hooks will automatically run before each commit."
