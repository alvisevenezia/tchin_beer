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

# Install CocoaPods using Homebrew.
HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_AUTO_UPDATE
brew install cocoapods

# Install CocoaPods dependencies.
cd ios && pod install

exit 0
