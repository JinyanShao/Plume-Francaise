#!/usr/bin/env bash

set -euo pipefail

if [ ! -f "Pods/Target Support Files/Pods-PlumeFrancaise/Pods-PlumeFrancaise.debug.xcconfig" ]; then
  pod install
fi

arch=$(uname -m)

# The installed input method (if running) binds the same preferences-server port the test
# target uses (see WebServer.m). If it wins that race, tests silently hit the old installed
# binary instead of the freshly built one - passing tests included, since the server just
# logs a bind failure rather than crashing.
pkill -f "Plume-Francaise.app/Contents/MacOS/PlumeFrancaise" 2>/dev/null || true

xcodebuild test \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  ONLY_ACTIVE_ARCH=YES \
  -workspace PlumeFrancaise.xcworkspace/ \
  -scheme PlumeFrancaise \
  -destination "platform=macOS,arch=${arch}"
