#!/bin/bash
# install.sh - Install or uninstall the code-smells CLI (Rust version)
# Usage: curl -fsSL https://raw.githubusercontent.com/byronsalty/code-smells/main/rust/install.sh | bash
# Uninstall: curl -fsSL https://raw.githubusercontent.com/byronsalty/code-smells/main/rust/install.sh | bash -s -- --uninstall

set -euo pipefail

REPO="byronsalty/code-smells"
BIN_DIR="$HOME/.local/bin"
BIN_NAME="code-smells"
SYMLINK="$BIN_DIR/csmells"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}==>${NC} $1"; }
warn() { echo -e "${YELLOW}Warning:${NC} $1"; }
error() { echo -e "${RED}Error:${NC} $1" >&2; }

detect_platform() {
    local os arch

    os="$(uname -s)"
    arch="$(uname -m)"

    case "$os" in
        Linux)  os="unknown-linux-gnu" ;;
        Darwin) os="apple-darwin" ;;
        *)
            error "Unsupported OS: $os"
            exit 1
            ;;
    esac

    case "$arch" in
        x86_64|amd64)  arch="x86_64" ;;
        arm64|aarch64) arch="aarch64" ;;
        *)
            error "Unsupported architecture: $arch"
            exit 1
            ;;
    esac

    echo "${arch}-${os}"
}

get_latest_release() {
    curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" |
        grep '"tag_name":' |
        sed -E 's/.*"([^"]+)".*/\1/'
}

uninstall() {
    info "Uninstalling code-smells..."

    if [[ -L "$SYMLINK" ]]; then
        rm "$SYMLINK"
        info "Removed symlink: $SYMLINK"
    fi

    if [[ -f "$BIN_DIR/$BIN_NAME" ]]; then
        rm "$BIN_DIR/$BIN_NAME"
        info "Removed binary: $BIN_DIR/$BIN_NAME"
    fi

    echo -e "${GREEN}code-smells has been uninstalled.${NC}"
    exit 0
}

install() {
    info "Installing code-smells..."

    # Check for curl
    if ! command -v curl &> /dev/null; then
        error "curl is required but not installed."
        exit 1
    fi

    # Detect platform
    local platform
    platform="$(detect_platform)"
    info "Detected platform: $platform"

    # Get latest release version
    info "Fetching latest release..."
    local version
    version="$(get_latest_release)"
    if [[ -z "$version" ]]; then
        error "Could not determine latest version"
        exit 1
    fi
    info "Latest version: $version"

    # Create bin directory
    mkdir -p "$BIN_DIR"

    # Download binary
    local download_url="https://github.com/$REPO/releases/download/${version}/code-smells-${platform}.tar.gz"
    info "Downloading from $download_url..."

    local tmp_dir
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' EXIT

    if ! curl -fsSL "$download_url" -o "$tmp_dir/code-smells.tar.gz"; then
        error "Failed to download binary. Check if release exists for your platform."
        echo ""
        echo "You can also build from source:"
        echo "    cargo install --git https://github.com/$REPO --path rust"
        exit 1
    fi

    # Extract and install
    tar -xzf "$tmp_dir/code-smells.tar.gz" -C "$tmp_dir"
    mv "$tmp_dir/code-smells" "$BIN_DIR/$BIN_NAME"
    chmod +x "$BIN_DIR/$BIN_NAME"
    info "Installed binary: $BIN_DIR/$BIN_NAME"

    # Create symlink
    if [[ -L "$SYMLINK" ]]; then
        rm "$SYMLINK"
    fi
    ln -s "$BIN_DIR/$BIN_NAME" "$SYMLINK"
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
        echo "    curl -fsSL https://raw.githubusercontent.com/byronsalty/code-smells/main/rust/install.sh | bash"
        echo ""
        echo "Uninstall:"
        echo "    curl -fsSL https://raw.githubusercontent.com/byronsalty/code-smells/main/rust/install.sh | bash -s -- --uninstall"
        echo ""
        echo "Build from source:"
        echo "    cargo install --git https://github.com/byronsalty/code-smells --path rust"
        ;;
    *)
        install
        ;;
esac
