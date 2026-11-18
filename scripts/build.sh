#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p out
sdk="$(xcrun --sdk iphoneos --show-sdk-path)"
xcrun --sdk iphoneos clang -arch arm64 -isysroot "$sdk" \
  -miphoneos-version-min=16.0 -fobjc-arc -fblocks -O2 \
  -Wall -Wextra -Werror -Wno-unused-parameter -Wno-deprecated-declarations \
  -dynamiclib -Wl,-install_name,@rpath/RiseInsta-1.2.1.dylib \
  RIRuntime.m RICommon.m RIDownloader.m RIMediaResolver.m RIMedia.m Menu.m Tweak.m \
  -framework Foundation -framework UIKit -framework Photos \
  -framework UniformTypeIdentifiers -framework QuartzCore -framework CoreGraphics -o out/RiseInsta-1.2.1.dylib
codesign --force --sign - out/RiseInsta-1.2.1.dylib
codesign --verify --verbose out/RiseInsta-1.2.1.dylib
python3 scripts/verify_macho.py out/RiseInsta-1.2.1.dylib
python3 scripts/verify_signature.py out/RiseInsta-1.2.1.dylib
xcrun --version > out/toolchain.txt
xcrun --sdk iphoneos --show-sdk-version >> out/toolchain.txt
xcrun --sdk iphoneos clang --version >> out/toolchain.txt
shasum -a 256 out/RiseInsta-1.2.1.dylib > out/SHA256SUMS
