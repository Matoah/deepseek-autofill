#!/bin/bash
# 本地构建并运行 Safari 版扩展（ad-hoc 签名，仅供本机调试）
#
# 注意：ad-hoc 构建的扩展属于"未签名扩展"，需要在 Safari 中开启
# "允许未签名扩展"后才会加载（详见 README.md）。
# 若要长期使用或分发，请用 Xcode 打开工程，配置开发者账号后构建。
set -euo pipefail

cd "$(dirname "$0")/AI Autofill"

xcodebuild -project "AI Autofill.xcodeproj" \
  -scheme "AI Autofill" \
  -configuration Debug \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGN_STYLE=Manual \
  build

echo "构建完成，正在启动应用..."
open "build/Build/Products/Debug/AI Autofill.app"
