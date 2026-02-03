#!/bin/sh
# wt installer - downloads pre-compiled binary from GitHub releases
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/amiller68/wt/main/install.sh | sh
#
# Or with a specific version:
#   curl -fsSL https://raw.githubusercontent.com/amiller68/wt/main/install.sh | sh -s -- v0.4.0
#
# Environment variables:
#   INSTALL_DIR - where to install (default: ~/.local/bin)

set -e

REPO="amiller68/wt"
BINARY_NAME="wt"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info() {
    printf "${CYAN}info:${NC} %s\n" "$1"
}

success() {
    printf "${GREEN}success:${NC} %s\n" "$1"
}

warn() {
    printf "${YELLOW}warn:${NC} %s\n" "$1"
}

error() {
    printf "${RED}error:${NC} %s\n" "$1" >&2
    exit 1
}

detect_os() {
    case "$(uname -s)" in
        Linux*)  echo "linux" ;;
        Darwin*) echo "darwin" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *)       error "Unsupported OS: $(uname -s)" ;;
    esac
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)  echo "x86_64" ;;
        aarch64|arm64) echo "aarch64" ;;
        *)             error "Unsupported architecture: $(uname -m)" ;;
    esac
}

get_latest_version() {
    if command -v curl >/dev/null 2>&1; then
        curl -sS "https://api.github.com/repos/${REPO}/releases/latest" | \
            grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "https://api.github.com/repos/${REPO}/releases/latest" | \
            grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
    else
        error "curl or wget required"
    fi
}

download() {
    url="$1"
    output="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$output"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$url" -O "$output"
    else
        error "curl or wget required"
    fi
}

main() {
    VERSION="${1:-}"
    if [ -z "$VERSION" ]; then
        info "Fetching latest version..."
        VERSION=$(get_latest_version)
        if [ -z "$VERSION" ]; then
            error "Could not determine latest version"
        fi
    fi

    case "$VERSION" in
        v*) ;;
        *)  VERSION="v$VERSION" ;;
    esac

    OS=$(detect_os)
    ARCH=$(detect_arch)

    info "Installing wt $VERSION for $OS-$ARCH"

    # Archive naming: wt-<version>-<arch>-<os>.tar.gz
    if [ "$OS" = "windows" ]; then
        ARCHIVE="${BINARY_NAME}-${VERSION}-${ARCH}-${OS}.zip"
    else
        ARCHIVE="${BINARY_NAME}-${VERSION}-${ARCH}-${OS}.tar.gz"
    fi

    URL="https://github.com/${REPO}/releases/download/${VERSION}/${ARCHIVE}"

    TMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TMP_DIR"' EXIT

    info "Downloading $URL"
    if ! download "$URL" "$TMP_DIR/$ARCHIVE"; then
        error "Download failed. Check the version exists at: https://github.com/${REPO}/releases"
    fi

    info "Extracting..."
    cd "$TMP_DIR"
    if [ "$OS" = "windows" ]; then
        unzip -q "$ARCHIVE"
    else
        tar -xzf "$ARCHIVE"
    fi

    if [ "$OS" = "windows" ]; then
        BINARY="$TMP_DIR/${BINARY_NAME}.exe"
    else
        BINARY="$TMP_DIR/${BINARY_NAME}"
    fi

    if [ ! -f "$BINARY" ]; then
        error "Binary not found in archive"
    fi

    mkdir -p "$INSTALL_DIR"
    mv "$BINARY" "$INSTALL_DIR/$BINARY_NAME"
    chmod +x "$INSTALL_DIR/$BINARY_NAME"

    success "wt $VERSION installed to $INSTALL_DIR/$BINARY_NAME"

    # Check PATH
    case ":$PATH:" in
        *":$INSTALL_DIR:"*) ;;
        *)
            echo ""
            warn "$INSTALL_DIR is not in your PATH"
            echo ""
            echo "Add to your shell profile:"
            echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
            echo ""
            ;;
    esac

    # Shell integration
    echo ""
    info "For shell integration (wt open changes directory):"
    echo ""
    echo "  # bash (~/.bashrc)"
    echo "  eval \"\$(wt shell-init bash)\""
    echo ""
    echo "  # zsh (~/.zshrc)"
    echo "  eval \"\$(wt shell-init zsh)\""
    echo ""
}

main "$@"
