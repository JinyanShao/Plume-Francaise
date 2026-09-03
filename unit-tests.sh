#!/usr/bin/env bash

set -euo pipefail

if [ ! -f "Pods/Target Support Files/Pods-PlumeFrancaise/Pods-PlumeFrancaise.debug.xcconfig" ]; then
  pod install
fi

arch=$(uname -m)

xcodebuild test \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  ONLY_ACTIVE_ARCH=YES \
  -workspace PlumeFrancaise.xcworkspace/ \
  -scheme PlumeFrancaise \
  -destination "platform=macOS,arch=${arch}"
