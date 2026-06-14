#!/usr/bin/env bash
set -euo pipefail

REPO="woshare/CalendarNoticeBanner"
APP_NAME="MeetBell"
INSTALL_DIR="/Applications"

echo "==> Fetching latest release info..."
LATEST=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest")
TAG=$(echo "$LATEST" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
ZIP_URL=$(echo "$LATEST" | grep '"browser_download_url"' | grep '\.zip"' | head -1 | sed 's/.*"browser_download_url": *"\([^"]*\)".*/\1/')

if [ -z "$ZIP_URL" ]; then
  echo "ERROR: Could not find a .zip asset in the latest release." >&2
  exit 1
fi

echo "==> Installing ${APP_NAME} ${TAG}..."

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

echo "==> Downloading ${ZIP_URL}..."
curl -fsSL "$ZIP_URL" -o "${TMP_DIR}/${APP_NAME}.zip"

echo "==> Extracting..."
unzip -q "${TMP_DIR}/${APP_NAME}.zip" -d "$TMP_DIR"

APP_BUNDLE=$(find "$TMP_DIR" -maxdepth 2 -name "${APP_NAME}.app" | head -1)
if [ -z "$APP_BUNDLE" ]; then
  echo "ERROR: ${APP_NAME}.app not found in zip." >&2
  exit 1
fi

if [ -d "${INSTALL_DIR}/${APP_NAME}.app" ]; then
  echo "==> Removing existing ${APP_NAME}.app..."
  rm -rf "${INSTALL_DIR}/${APP_NAME}.app"
fi

echo "==> Copying to ${INSTALL_DIR}..."
cp -R "$APP_BUNDLE" "${INSTALL_DIR}/"

# Remove quarantine attribute so macOS doesn't block launch
xattr -dr com.apple.quarantine "${INSTALL_DIR}/${APP_NAME}.app" 2>/dev/null || true

echo ""
echo "✓ ${APP_NAME} ${TAG} installed to ${INSTALL_DIR}/${APP_NAME}.app"
echo "  Open it from Finder or run: open '${INSTALL_DIR}/${APP_NAME}.app'"
