#!/bin/bash
# install.sh - Install or uninstall the code-smells toolkit
# Usage: curl -fsSL https://raw.githubusercontent.com/byronsalty/code-smells/main/install.sh | bash
# Uninstall: curl -fsSL https://raw.githubusercontent.com/byronsalty/code-smells/main/install.sh | bash -s -- --uninstall

set -euo pipefail

REPO="byronsalty/code-smells"
INSTALL_DIR="$HOME/.local/bin/code-smells"
BIN_DIR="$HOME/.local/bin"
SYMLINK="$BIN_DIR/csmells"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}==>${NC} $1"; }
warn() { echo -e "${YELLOW}Warning:${NC} $1"; }
error() { echo -e "${RED}Error:${NC} $1" >&2; }

uninstall() {
    info "Uninstalling code-smells..."

    if [[ -L "$SYMLINK" ]]; then
        rm "$SYMLINK"
        info "Removed symlink: $SYMLINK"
    fi

    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
        info "Removed directory: $INSTALL_DIR"
    fi

    echo -e "${GREEN}code-smells has been uninstalled.${NC}"
    exit 0
}

install() {
    info "Installing code-smells..."

    # Check for required tools
    if ! command -v git &> /dev/null; then
        error "git is required but not installed."
        exit 1
    fi

    # Create bin directory if needed
    mkdir -p "$BIN_DIR"

    # Remove existing installation
    if [[ -d "$INSTALL_DIR" ]]; then
        info "Removing existing installation..."
        rm -rf "$INSTALL_DIR"
    fi

    # Clone the repository
    info "Downloading from GitHub..."
    git clone --depth 1 "https://github.com/$REPO.git" "$INSTALL_DIR" 2>/dev/null

    # Remove git directory to save space
    rm -rf "$INSTALL_DIR/.git"

    # Make scripts executable
    chmod +x "$INSTALL_DIR/code-smells"
    chmod +x "$INSTALL_DIR/lib/"*.sh

    # Create symlink
    if [[ -L "$SYMLINK" ]]; then
        rm "$SYMLINK"
    fi
    ln -s "$INSTALL_DIR/code-smells" "$SYMLINK"
    info "Created symlink: $SYMLINK"

    # Check if bin directory is in PATH
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        warn "$BIN_DIR is not in your PATH"
        echo ""
        echo "Add this to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
        echo ""
        echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo ""
    fi

    echo ""
    echo -e "${GREEN}code-smells has been installed!${NC}"
    echo ""
    echo "Usage:"
    echo "    csmells                    # Analyze current directory"
    echo "    csmells /path/to/project   # Analyze specific project"
    echo "    csmells --help             # Show all options"
    echo ""
}

# Parse arguments
case "${1:-}" in
    --uninstall|-u)
        uninstall
        ;;
    --help|-h)
        echo "Usage: install.sh [OPTIONS]"
        echo ""
        echo "Options:"
        echo "    --uninstall, -u    Remove code-smells from your system"
        echo "    --help, -h         Show this help message"
        echo ""
        echo "Install:"
        echo "    curl -fsSL https://raw.githubusercontent.com/byronsalty/code-smells/main/install.sh | bash"
        echo ""
        echo "Uninstall:"
        echo "    curl -fsSL https://raw.githubusercontent.com/byronsalty/code-smells/main/install.sh | bash -s -- --uninstall"
        ;;
    *)
        install
        ;;
esac
