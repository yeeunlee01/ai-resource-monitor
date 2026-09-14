#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$PWD/.build/module-cache}"
export SWIFTPM_MODULECACHE_OVERRIDE="${SWIFTPM_MODULECACHE_OVERRIDE:-$PWD/.build/module-cache}"
developer_path="$(xcode-select -p)"
if [[ "$developer_path" == */CommandLineTools ]]; then
    # The CLT includes Swift Testing but does not configure its framework search path.
    # Its Foundation cross-import overlay is absent in some CLT releases.
    frameworks="$developer_path/Library/Developer/Frameworks"
    swift test --disable-xctest \
        -Xswiftc -F -Xswiftc "$frameworks" \
        -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays \
        -Xlinker -rpath -Xlinker "$frameworks" "$@"
else
    swift test "$@"
fi
