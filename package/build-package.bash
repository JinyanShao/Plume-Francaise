#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
PROJECT_ROOT=$(cd "${SCRIPT_DIR}/.."; pwd)
BUILD_ROOT="${BUILD_ROOT:-/tmp/JinyanShaoFrenchInputMethod-package}"
OUTPUT_DIR="${OUTPUT_DIR:-${PROJECT_ROOT}/..}"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${PROJECT_ROOT}/Info.plist")
APP_NAME="JinyanShao-FrenchInputMethod.app"

rm -rf "${BUILD_ROOT}"
mkdir -p "${BUILD_ROOT}/root" "${OUTPUT_DIR}"

xcodebuild \
    -workspace "${PROJECT_ROOT}/JinyanShaoFrenchInputMethod.xcworkspace" \
    -scheme JinyanShaoFrenchInputMethod \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "${BUILD_ROOT}/DerivedData" \
    'ARCHS=arm64 x86_64' \
    ONLY_ACTIVE_ARCH=NO \
    MACOSX_DEPLOYMENT_TARGET=13.5 \
    CODE_SIGNING_ALLOWED=NO \
    build

ditto \
    "${BUILD_ROOT}/DerivedData/Build/Products/Release/JinyanShaoFrenchInputMethod.app" \
    "${BUILD_ROOT}/root/${APP_NAME}"
xattr -cr "${BUILD_ROOT}/root/${APP_NAME}"
codesign --force --deep --sign - "${BUILD_ROOT}/root/${APP_NAME}"
xattr -cr "${BUILD_ROOT}/root/${APP_NAME}"

POSTINSTALL_ACTION="${PKG_POSTINSTALL_ACTION:-none}"
sed "s/__POSTINSTALL_ACTION__/${POSTINSTALL_ACTION}/" \
    "${SCRIPT_DIR}/PackageInfo" > "${BUILD_ROOT}/PackageInfo"

pkgbuild \
    --info "${BUILD_ROOT}/PackageInfo" \
    --root "${BUILD_ROOT}/root" \
    --identifier "github.jinyanshao.inputmethod.JinyanShaoFrenchInputMethod" \
    --version "${VERSION}" \
    --install-location "/Library/Input Methods" \
    --scripts "${SCRIPT_DIR}/scripts" \
    "${OUTPUT_DIR}/JinyanShao-FrenchInputMethod-${VERSION}.pkg"

codesign --verify --deep --strict --verbose=2 "${BUILD_ROOT}/root/${APP_NAME}"
lipo -archs "${BUILD_ROOT}/root/${APP_NAME}/Contents/MacOS/JinyanShaoFrenchInputMethod"
pkgutil --check-signature "${OUTPUT_DIR}/JinyanShao-FrenchInputMethod-${VERSION}.pkg" || true
