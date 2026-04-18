#!/bin/bash
# bootstrap.sh — download and run the encrypted host provisioner
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/mkembel33/pub/main/bootstrap.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/mkembel33/pub/main/bootstrap.sh | bash -s -- --bashrc
#
# Flags are passed through to the installer (--bashrc, --tailscale, etc.)

set -euo pipefail

REPO_URL="https://raw.githubusercontent.com/mkembel33/pub/main"

echo ""
echo "============================================"
echo "  Host Provisioning Bootstrap"
echo "============================================"
echo ""

# ─── Install age if not present ──────────────────────────────────────────────
if command -v age >/dev/null 2>&1; then
    echo "✅ age $(age --version 2>&1 | head -1)"
else
    echo "Installing age encryption tool..."
    if command -v brew >/dev/null 2>&1; then
        brew install age
    elif command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update -y && sudo apt-get install -y age
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y age
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm age
    else
        echo "❌ Cannot install age — install manually: https://github.com/FiloSottile/age"
        exit 1
    fi
    echo "✅ age installed"
fi

# ─── Download encrypted installer ───────────────────────────────────────────
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

echo ""
echo "Downloading encrypted installer..."
if ! curl -fsSL "$REPO_URL/installmysoftware.sh.age" -o "$WORK_DIR/installer.age"; then
    echo "❌ Failed to download installer"
    exit 1
fi
echo "✅ Downloaded"

# ─── Layer 1: Decrypt installer ─────────────────────────────────────────────
echo ""
echo "🔐 Enter the installer password:"
if ! age -d -o "$WORK_DIR/installer.sh" "$WORK_DIR/installer.age"; then
    echo ""
    echo "❌ Wrong password or corrupt file"
    exit 1
fi
chmod +x "$WORK_DIR/installer.sh"

echo ""
echo "✅ Installer decrypted — launching..."
echo ""

# ─── Run installer (pass through any flags) ─────────────────────────────────
bash "$WORK_DIR/installer.sh" "$@"
