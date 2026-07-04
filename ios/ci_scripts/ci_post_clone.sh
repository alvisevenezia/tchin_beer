#!/bin/sh

# Xcode Cloud post-clone script for a Flutter app.
# Installs Flutter, fetches Dart/CocoaPods dependencies so the Runner
# workspace can be built by Xcode Cloud.

# Fail this script if any subcommand fails.
set -e

# The default execution directory of this script is the ci_scripts directory.
# CI_PRIMARY_REPOSITORY_PATH is the root of the cloned repo (the Flutter project).
cd "$CI_PRIMARY_REPOSITORY_PATH"

# Install Flutter (stable channel).
git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
export PATH="$PATH:$HOME/flutter/bin"

# Install Flutter artifacts for iOS.
flutter precache --ios

# Install Flutter dependencies (also generates ios/Flutter/Generated.xcconfig).
flutter pub get

# Inject compile-time Dart defines read by lib/config.dart.
# API_BASE_URL is set as an environment variable in the Xcode Cloud workflow.
# DART_DEFINES expects comma-separated base64-encoded key=value pairs.
if [ -n "$API_BASE_URL" ]; then
  echo "DART_DEFINES=$(printf %s "API_BASE_URL=$API_BASE_URL" | base64)" >> ios/Flutter/Generated.xcconfig
fi

# Install CocoaPods using Homebrew.
HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_AUTO_UPDATE
brew install cocoapods

# Install CocoaPods dependencies.
cd ios && pod install

exit 0
