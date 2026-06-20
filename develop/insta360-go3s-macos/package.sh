#!/usr/bin/env bash
# Build Insta360 GO 3S Import.app with bundled Python CLI and optional DMG.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
CLI_SRC="$(cd "$ROOT/../insta360-go3s-wifi" && pwd)"
APP_NAME="Insta360 GO 3S Import"
EXEC_NAME="Insta360GO3SImport"
BUNDLE_ID="com.insta360.go3s.import"
VERSION="1.0.0"
BUILD_DIR="$ROOT/.build/release"
DIST_DIR="$ROOT/dist"
APP_DIR="$DIST_DIR/${APP_NAME}.app"
RES_CLI="$APP_DIR/Contents/Resources/insta360-go3s-wifi"
DMG_PATH="$DIST_DIR/${APP_NAME}.dmg"

echo "==> Swift release build"
cd "$ROOT"
swift build -c release

if [[ ! -x "$CLI_SRC/.venv/bin/python" ]]; then
  echo "ERROR: Python venv missing at $CLI_SRC/.venv"
  echo "Run: cd \"$CLI_SRC\" && python3 -m venv .venv && .venv/bin/pip install -e '.[dev]'"
  exit 1
fi

echo "==> Prepare .app bundle"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/$EXEC_NAME" "$APP_DIR/Contents/MacOS/$EXEC_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$EXEC_NAME"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${EXEC_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.photography</string>
</dict>
</plist>
PLIST

echo "==> Bundle Python CLI (this may take a minute)"
rsync -a \
  --exclude '.pytest_cache' \
  --exclude '__pycache__' \
  --exclude '*.pyc' \
  --exclude '.git' \
  --exclude 'tests' \
  "$CLI_SRC/" "$RES_CLI/"

echo "==> Verify bundled CLI with system Python"
export PYTHONPATH="$RES_CLI/src:$RES_CLI/.venv/lib/python3.9/site-packages"
if /usr/bin/python3 -c "import insta360_go3s_wifi" 2>/dev/null; then
  echo "CLI import OK (/usr/bin/python3)"
else
  echo "WARN: bundled CLI import failed — recipients need macOS Command Line Tools (python3)"
fi

echo "==> Ad-hoc code sign (Gatekeeper: right-click → Open on first launch)"
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || echo "WARN: codesign skipped (install Xcode CLT for signing)"

if [[ "${1:-}" == "--dmg" || "${1:-}" == "--all" ]]; then
  echo "==> Create DMG"
  rm -f "$DMG_PATH"
  STAGE="$DIST_DIR/dmg-stage"
  rm -rf "$STAGE"
  mkdir -p "$STAGE"
  cp -R "$APP_DIR" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG_PATH"
  rm -rf "$STAGE"
  echo ""
  echo "DMG: $DMG_PATH"
fi

echo ""
echo "App bundle: $APP_DIR"
echo "Install: drag to /Applications, or open directly from dist/"
echo "First launch: if blocked, right-click the app → Open"
