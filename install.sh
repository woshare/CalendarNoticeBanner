#!/bin/bash
set -e

APP_NAME="MeetBell"
REPO="woshare/CalendarNoticeBanner"
INSTALL_DIR="/Applications"

echo "📦 正在安装 $APP_NAME..."

# 获取最新 release 下载链接
DOWNLOAD_URL=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
  | grep "browser_download_url" \
  | grep "\.zip" \
  | cut -d '"' -f 4)

if [ -z "$DOWNLOAD_URL" ]; then
  echo "❌ 获取下载链接失败，请检查网络或手动下载"
  exit 1
fi

echo "⬇️  下载中：$DOWNLOAD_URL"

TMP_DIR=$(mktemp -d)
ZIP_PATH="$TMP_DIR/$APP_NAME.zip"

curl -fsSL "$DOWNLOAD_URL" -o "$ZIP_PATH"

echo "📂 解压中..."
unzip -q "$ZIP_PATH" -d "$TMP_DIR"

if [ -d "$INSTALL_DIR/$APP_NAME.app" ]; then
  echo "🔄 覆盖已有版本..."
  rm -rf "$INSTALL_DIR/$APP_NAME.app"
fi

mv "$TMP_DIR/$APP_NAME.app" "$INSTALL_DIR/"

echo "🔓 解除 Gatekeeper 限制..."
xattr -cr "$INSTALL_DIR/$APP_NAME.app"

rm -rf "$TMP_DIR"

echo ""
echo "✅ 安装完成！"
echo "   请前往 /Applications 打开 $APP_NAME"
echo "   首次运行需授权日历访问权限"
