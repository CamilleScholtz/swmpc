#!/bin/sh

# Xcode Cloud has no UI to approve Swift macros, so skip fingerprint
# validation for macros and build tool plugins (AnyLanguageModelMacros).
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES
defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidation -bool YES
