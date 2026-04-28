#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
EXPORT_SCRIPT="$SCRIPT_DIR/export_config.sh"
OUTPUT_CONFIG=$(mktemp)

cleanup() {
	rm -f "$OUTPUT_CONFIG"
}
trap cleanup EXIT

test -f "$REPO_ROOT/Config/MT6000-WIFI-MINI-FW3.txt"

bash "$EXPORT_SCRIPT" \
	--config-dir "$REPO_ROOT/Config" \
	--device "MT6000-WIFI-MINI" \
	--fw "fw3" \
	--output "$OUTPUT_CONFIG"

grep -Eq '^CONFIG_PACKAGE_luci-app-frpc=y([[:space:]]*#.*)?$' "$OUTPUT_CONFIG"
grep -Eq '^CONFIG_PACKAGE_luci-app-frps=m([[:space:]]*#.*)?$' "$OUTPUT_CONFIG"

echo "test_mt6000_mini_fw3_export: ok"
