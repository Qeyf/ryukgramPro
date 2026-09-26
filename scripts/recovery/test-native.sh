#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
if ! command -v xcrun >/dev/null; then
  echo "Apple Foundation tests require macOS and Xcode Command Line Tools." >&2
  exit 77
fi
recovery_test_dir=$(mktemp -d)
trap 'rm -rf "$recovery_test_dir"' EXIT
xcrun --sdk macosx clang -fobjc-arc -fblocks -Wall -Wextra -I src \
  -framework Foundation src/SCIDashParser.m src/ActionButton/SCIMediaMetadata.m \
  tests/recovery/RecoveryTests.m -o "$recovery_test_dir/RecoveryTests"
"$recovery_test_dir/RecoveryTests"
