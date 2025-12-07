#!/bin/bash
# devInstall.sh - Link development version for local testing

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
SYMLINK="$BIN_DIR/csmells"

mkdir -p "$BIN_DIR"

# Remove existing install (either symlink or directory)
[[ -L "$SYMLINK" ]] && rm "$SYMLINK"
[[ -d "$BIN_DIR/code-smells" ]] && rm -rf "$BIN_DIR/code-smells"

# Link directly to dev version
ln -s "$SCRIPT_DIR/code-smells" "$SYMLINK"

echo "Linked $SYMLINK -> $SCRIPT_DIR/code-smells"
echo "Edits are now live. Run 'csmells' to test."
