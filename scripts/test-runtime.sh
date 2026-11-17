#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build-tests
xcrun --sdk macosx clang -fobjc-arc -fblocks -Wall -Wextra -Werror \
  -Wno-unused-parameter RIRuntime.m tests/runtime.m -framework Foundation \
  -o .build-tests/runtime
.build-tests/runtime
