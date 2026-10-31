#!/bin/sh
#
# Builds an UNSIGNED Release .ipa of Youtube adless lite for the App
# Store-less distribution path: run this on a Mac with Xcode installed,
# then sign the resulting ipa yourself (Sideloadly, AltStore, Xcode, or
# codesign).
#
# Usage:  ./make-ipa.sh
# Result: build/Youtube Adless Lite-<version>.ipa
#

set -e
cd "$(dirname "$0")"

xcodebuild \
    -project "Youtube adless lite.xcodeproj" \
    -scheme "Youtube adless lite" \
    -configuration Release \
    -sdk iphoneos \
    build \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    CONFIGURATION_BUILD_DIR=build

APP_PLIST="build/Youtube adless lite.app/Info.plist"
version="$(plutil -extract CFBundleShortVersionString raw "$APP_PLIST")"
build="$(plutil -extract CFBundleVersion raw "$APP_PLIST")"
ipa_name="Youtube Adless Lite-$version.ipa"

rm -rf build/Payload
mkdir -p build/Payload
cp -R "build/Youtube adless lite.app" "build/Payload/"

rm -f "build/$ipa_name"
(cd build && zip -qry "$ipa_name" Payload)

echo
echo "Unsigned ipa ready: build/$ipa_name (version $version, build $build)"
