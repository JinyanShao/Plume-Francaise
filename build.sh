#!/bin/bash

xcodebuild -version
clang -v
rm -rf /tmp/JinyanShaoFrenchInputMethod

xcodebuild clean -workspace JinyanShaoFrenchInputMethod.xcworkspace/ -scheme JinyanShaoFrenchInputMethod

xcodebuild -workspace JinyanShaoFrenchInputMethod.xcworkspace/ -scheme JinyanShaoFrenchInputMethod -destination "generic/platform=macOS,name=Any Mac" -configuration "Release" CONFIGURATION_BUILD_DIR=/tmp/JinyanShaoFrenchInputMethod/build/release BUILD_LIBRARY_FOR_DISTRIBUTION=YES
