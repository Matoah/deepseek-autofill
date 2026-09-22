#!/usr/bin/env bash
# 构建 快问.app（macOS WKWebView 版，英文名 AI Autofill）
# 用法：./build.sh [Debug|Release]，默认 Release
set -euo pipefail
cd "$(dirname "$0")"

CONFIG="${1:-Release}"
APP_PATH="$(pwd)/build/快问.app"

xcodebuild \
  -project AutofillApp.xcodeproj \
  -scheme AutofillApp \
  -configuration "$CONFIG" \
  -derivedDataPath build/DerivedData \
  CONFIGURATION_BUILD_DIR="$(pwd)/build" \
  build

# 清理旧英文名产物，避免 build/ 下同时出现两个 App
rm -rf "$(pwd)/build/AI Autofill.app" "$(pwd)/build/AI Autofill.app.dSYM"

echo
echo "✅ 构建完成：$APP_PATH"
echo
echo "使用方式："
echo "  直接打开：      open \"$APP_PATH\""
echo "  命令行传参：    open \"$APP_PATH\" --args --platform deepseek --message \"你的问题\""
echo "  URL scheme：    open 'aiautofill://send?platform=chatgpt&q=URL编码后的问题'"
