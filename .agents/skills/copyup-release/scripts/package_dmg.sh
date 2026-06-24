#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
用法:
  package_dmg.sh [--repo PATH] [--arch arm64|universal] [--skip-notarization]

默认:
  --arch arm64
  --repo 自动定位到当前 CopyUp 仓库
  启用 Developer ID 签名、公证、staple 和 Gatekeeper 验证

示例:
  package_dmg.sh
  package_dmg.sh --arch universal
  package_dmg.sh --skip-notarization
USAGE
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
ARCH="arm64"
SKIP_NOTARIZATION=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO_ROOT="$2"
      shift 2
      ;;
    --arch)
      ARCH="$2"
      shift 2
      ;;
    --skip-notarization)
      SKIP_NOTARIZATION=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "未知参数: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$ARCH" in
  arm64)
    ARCHS_VALUE="arm64"
    ARCH_SUFFIX="arm64"
    ;;
  universal)
    ARCHS_VALUE="arm64 x86_64"
    ARCH_SUFFIX="universal"
    ;;
  *)
    echo "--arch 只支持 arm64 或 universal" >&2
    exit 2
    ;;
esac

cd "$REPO_ROOT"

PROJECT="CopyUp.xcodeproj"
SCHEME="CopyUp"
CONFIGURATION="Release"
TEAM_ID="LQ97GA8LY8"
NOTARY_PROFILE="copyup"
SIGNING_CERTIFICATE="Developer ID Application"
SIGNING_IDENTITY="Developer ID Application: Fuzhou Beisi Network Technology Co., Ltd. (LQ97GA8LY8)"

INFO_PLIST="CopyUp/Supporting Files/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")
STAMP=$(date +%Y%m%d-%H%M%S)

ARCHIVE_PATH="$REPO_ROOT/.build/Archive/CopyUp-${STAMP}-${ARCH_SUFFIX}.xcarchive"
EXPORT_PATH="$REPO_ROOT/.build/Export-${STAMP}-${ARCH_SUFFIX}"
EXPORT_OPTIONS="$REPO_ROOT/.build/ExportOptions-${STAMP}-${ARCH_SUFFIX}.plist"
DERIVED_DATA="$REPO_ROOT/.build/DerivedData-CopyUp-${ARCH_SUFFIX}-Release"
STAGING="$REPO_ROOT/.build/dmg-staging-${STAMP}-${ARCH_SUFFIX}"
DMG="$REPO_ROOT/.build/dist/CopyUp-${VERSION}-${STAMP}-${ARCH_SUFFIX}.dmg"

mkdir -p "$REPO_ROOT/.build/Archive" "$REPO_ROOT/.build/dist"

echo "==> 检查 Developer ID 证书"
security find-identity -v -p codesigning | grep -F "$SIGNING_IDENTITY" >/dev/null

if [[ "$SKIP_NOTARIZATION" -eq 0 ]]; then
  echo "==> 检查 notarytool profile: $NOTARY_PROFILE"
  xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null
fi

echo "==> Archive: $ARCH_SUFFIX"
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -archivePath "$ARCHIVE_PATH" \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  ARCHS="$ARCHS_VALUE" \
  ONLY_ACTIVE_ARCH=NO

cat > "$EXPORT_OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>export</string>
  <key>method</key>
  <string>developer-id</string>
  <key>signingCertificate</key>
  <string>${SIGNING_CERTIFICATE}</string>
  <key>signingStyle</key>
  <string>manual</string>
  <key>teamID</key>
  <string>${TEAM_ID}</string>
</dict>
</plist>
PLIST

echo "==> Export Developer ID app"
rm -rf "$EXPORT_PATH"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -skipPackagePluginValidation \
  -skipMacroValidation

APP="$EXPORT_PATH/CopyUp.app"
EXECUTABLE="$APP/Contents/MacOS/CopyUp"

echo "==> 检查 App 架构"
file "$EXECUTABLE"
ACTUAL_ARCHS=$(lipo -archs "$EXECUTABLE")
echo "架构: $ACTUAL_ARCHS"
if [[ "$ARCH" == "arm64" && "$ACTUAL_ARCHS" != "arm64" ]]; then
  echo "期望 arm64，实际为: $ACTUAL_ARCHS" >&2
  exit 1
fi

echo "==> 验证 App 签名"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "==> 创建 DMG"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/CopyUp.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create \
  -volname "CopyUp" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  "$DMG"

echo "==> 签名 DMG"
codesign --force --sign "$SIGNING_IDENTITY" "$DMG"
hdiutil verify "$DMG"

if [[ "$SKIP_NOTARIZATION" -eq 0 ]]; then
  echo "==> 提交公证"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait

  echo "==> Staple DMG"
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"

  echo "==> Gatekeeper 验证 DMG"
  spctl -a -vvv -t open --context context:primary-signature "$DMG"
else
  echo "==> 已跳过公证；该 DMG 不适合发给朋友测试"
fi

echo "==> 挂载并验证 App"
MOUNT_OUTPUT=$(hdiutil attach "$DMG" -nobrowse -readonly)
echo "$MOUNT_OUTPUT"
MOUNT_POINT=$(printf '%s\n' "$MOUNT_OUTPUT" | awk '/\/Volumes\// {print substr($0, index($0, "/Volumes/")); exit}')
trap '[[ -n "${MOUNT_POINT:-}" ]] && hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 || true' EXIT

ls -la "$MOUNT_POINT"
file "$MOUNT_POINT/CopyUp.app/Contents/MacOS/CopyUp"
lipo -archs "$MOUNT_POINT/CopyUp.app/Contents/MacOS/CopyUp"
codesign --verify --deep --strict --verbose=2 "$MOUNT_POINT/CopyUp.app"
if [[ "$SKIP_NOTARIZATION" -eq 0 ]]; then
  spctl -a -vvv -t exec "$MOUNT_POINT/CopyUp.app"
fi

hdiutil detach "$MOUNT_POINT"
trap - EXIT

echo
echo "完成:"
echo "DMG_PATH=$DMG"
ls -lh "$DMG"
