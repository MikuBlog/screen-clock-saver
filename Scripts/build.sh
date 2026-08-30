#!/bin/bash
#
# build.sh —— 不依赖 xcodebuild（无需 sudo 同意 Xcode 许可），
# 直接调用工具链 swiftc 编译并组装：
#   dist/ScreenClock.saver                屏保包（可双击安装）
#   dist/ScreenClockStudio.app            设置应用（已内嵌屏保）
#   dist/翻页时钟.dmg                      分发包
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DEVELOPER="/Applications/Xcode.app/Contents/Developer"
TC="$DEVELOPER/Toolchains/XcodeDefault.xctoolchain/usr/bin"
SDK="$DEVELOPER/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
SWIFTC="$TC/swiftc"
LIPO="$TC/lipo"

ARCHS=(arm64 x86_64)
DEPLOYMENT_TARGET="14.0"

OBJ="$ROOT/build/obj"
DIST="$ROOT/build/dist"
DMG_STAGE="$ROOT/build/dmgstage"

SHARED_SOURCES=(Shared/ClockSettings.swift Shared/ClockFont.swift Shared/Theme.swift Shared/SettingsStore.swift Shared/FlipClockView.swift Shared/AnalogClockView.swift)
SAVER_SOURCES=("${SHARED_SOURCES[@]}" Saver/ScreenClockSaverView.swift)
APP_SOURCES=("${SHARED_SOURCES[@]}" Studio/AppModel.swift Studio/StudioApp.swift Studio/ContentView.swift Studio/ClockPreview.swift Studio/SaverInstaller.swift)

rm -rf "$OBJ" "$DIST" "$DMG_STAGE"
mkdir -p "$OBJ"

# ---------------------------------------------------------------- 编译（双架构）
for ARCH in "${ARCHS[@]}"; do
  echo "==> 编译屏保 $ARCH"
  "$SWIFTC" -swift-version 5 -target "$ARCH-apple-macosx$DEPLOYMENT_TARGET" -sdk "$SDK" -O \
    "${SAVER_SOURCES[@]}" \
    -framework ScreenSaver -framework AppKit -framework QuartzCore \
    -Xlinker -bundle -o "$OBJ/ScreenClock-$ARCH.bundle"

  echo "==> 编译设置应用 $ARCH"
  "$SWIFTC" -swift-version 5 -target "$ARCH-apple-macosx$DEPLOYMENT_TARGET" -sdk "$SDK" -O \
    "${APP_SOURCES[@]}" \
    -framework SwiftUI -framework AppKit -framework QuartzCore \
    -o "$OBJ/ScreenClockStudio-$ARCH"
done

# ---------------------------------------------------------------- 合并通用二进制
echo "==> lipo 合并通用二进制"
"$LIPO" -create $(for A in "${ARCHS[@]}"; do echo "$OBJ/ScreenClock-$A.bundle"; done) -output "$OBJ/ScreenClock"
"$LIPO" -create $(for A in "${ARCHS[@]}"; do echo "$OBJ/ScreenClockStudio-$A"; done) -output "$OBJ/ScreenClockStudio"
file "$OBJ/ScreenClock" "$OBJ/ScreenClockStudio"

# ---------------------------------------------------------------- 组装 .saver
SAVER_BUNDLE="$DIST/ScreenClock.saver"
mkdir -p "$SAVER_BUNDLE/Contents/MacOS"
cp "$OBJ/ScreenClock" "$SAVER_BUNDLE/Contents/MacOS/ScreenClock"
sed -e 's/$(EXECUTABLE_NAME)/ScreenClock/g' \
    -e 's/$(PRODUCT_NAME)/ScreenClock/g' \
    -e 's/$(PRODUCT_BUNDLE_IDENTIFIER)/com.doubao.screenclock.saver/g' \
    Saver/Info.plist > "$SAVER_BUNDLE/Contents/Info.plist"
chmod +x "$SAVER_BUNDLE/Contents/MacOS/ScreenClock"

# ---------------------------------------------------------------- 组装 .app（内嵌 saver）
APP_BUNDLE="$DIST/ScreenClockStudio.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$OBJ/ScreenClockStudio" "$APP_BUNDLE/Contents/MacOS/ScreenClockStudio"
cp -R "$SAVER_BUNDLE" "$APP_BUNDLE/Contents/Resources/ScreenClock.saver"
sed -e 's/$(EXECUTABLE_NAME)/ScreenClockStudio/g' \
    -e 's/$(PRODUCT_NAME)/ScreenClockStudio/g' \
    -e 's/$(PRODUCT_BUNDLE_IDENTIFIER)/com.doubao.screenclock.studio/g' \
    Studio/Info.plist > "$APP_BUNDLE/Contents/Info.plist"
chmod +x "$APP_BUNDLE/Contents/MacOS/ScreenClockStudio"

# ---------------------------------------------------------------- 临时签名（ad-hoc）
echo "==> ad-hoc 代码签名"
codesign --force --sign - "$APP_BUNDLE/Contents/Resources/ScreenClock.saver"
codesign --force --sign - "$APP_BUNDLE"
codesign --force --sign - "$SAVER_BUNDLE"

# ---------------------------------------------------------------- DMG
echo "==> 制作 DMG"
mkdir -p "$DMG_STAGE/翻页时钟"
cp -R "$APP_BUNDLE" "$DMG_STAGE/翻页时钟/ScreenClockStudio.app"
cp -R "$SAVER_BUNDLE" "$DMG_STAGE/翻页时钟/ScreenClock.saver"
ln -s /Applications "$DMG_STAGE/翻页时钟/Applications"
DMG_PATH="$DIST/翻页时钟.dmg"
rm -f "$DMG_PATH"
hdiutil create -volname "翻页时钟" -srcfolder "$DMG_STAGE/翻页时钟" -ov -format UDZO "$DMG_PATH" >/dev/null

echo ""
echo "✅ 构建完成："
echo "   $SAVER_BUNDLE"
echo "   $APP_BUNDLE"
echo "   $DMG_PATH"
