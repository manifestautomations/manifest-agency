#!/bin/bash
# Install yq YAML processor on Windows/MINGW64
# Idempotent - safe to run multiple times

set -e

VERSION="v4.44.1"  # Latest stable version as of 2025-01
INSTALL_DIR="/usr/bin"
BINARY_NAME="yq"
DOWNLOAD_URL="https://github.com/mikefarah/yq/releases/download/${VERSION}/yq_windows_amd64.exe"

echo "Checking for existing yq installation..."

if command -v yq &> /dev/null; then
    CURRENT_VERSION=$(yq --version 2>&1 | head -n1 || echo "unknown")
    echo "yq is already installed: $CURRENT_VERSION"
    echo "Skipping installation (already present)"
    exit 0
fi

echo "yq not found. Installing version ${VERSION}..."

# Create temporary download location
TMP_FILE="/tmp/yq_windows_amd64.exe"

# Download binary using curl (more reliable on Windows than wget)
echo "Downloading from ${DOWNLOAD_URL}..."
if command -v curl &> /dev/null; then
    curl -L -o "$TMP_FILE" "$DOWNLOAD_URL"
elif command -v wget &> /dev/null; then
    wget -O "$TMP_FILE" "$DOWNLOAD_URL"
else
    echo "Error: Neither curl nor wget found. Cannot download yq."
    exit 1
fi

# Install to /usr/bin
echo "Installing to ${INSTALL_DIR}/${BINARY_NAME}..."
mv "$TMP_FILE" "${INSTALL_DIR}/${BINARY_NAME}"
chmod +x "${INSTALL_DIR}/${BINARY_NAME}"

# Verify installation
if command -v yq &> /dev/null; then
    INSTALLED_VERSION=$(yq --version 2>&1 | head -n1)
    echo "✓ yq installed successfully: $INSTALLED_VERSION"
else
    echo "Error: yq installation failed"
    exit 1
fi
