#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/Packages.sh"

for fn in resolve_packages_source_flavor apply_lean_package_overrides apply_VIKINGYFY_package_overrides apply_generic_package_overrides; do
    grep -q "^${fn}() {" "$TARGET_SCRIPT"
done

echo "test_packages_source_flavor: ok"
