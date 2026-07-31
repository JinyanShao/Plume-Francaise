#!/bin/bash

xcodebuild -version
clang -v
rm -rf /tmp/PlumeFrancaise

xcodebuild clean -workspace PlumeFrancaise.xcworkspace/ -scheme PlumeFrancaise

xcodebuild -workspace PlumeFrancaise.xcworkspace/ -scheme PlumeFrancaise -destination "generic/platform=macOS,name=Any Mac" -configuration "Release" CONFIGURATION_BUILD_DIR=/tmp/PlumeFrancaise/build/release BUILD_LIBRARY_FOR_DISTRIBUTION=YES
