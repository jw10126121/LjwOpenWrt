#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
RESOLVE_SCRIPT="$SCRIPT_DIR/resolve_device_script.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

touch "$TMPDIR/Packages.sh"
touch "$TMPDIR/Packages-JD-AX6600.sh"
touch "$TMPDIR/Packages-MT6000-WIFI.sh"

result=$(bash "$RESOLVE_SCRIPT" "$TMPDIR" "auto" "JD-AX6600-WIFI")
test "$result" = "Packages-JD-AX6600.sh"

result=$(bash "$RESOLVE_SCRIPT" "$TMPDIR" "auto" "MT6000-WIFI")
test "$result" = "Packages-MT6000-WIFI.sh"

result=$(bash "$RESOLVE_SCRIPT" "$TMPDIR" "auto" "CMIOT-AX18-NOWIFI")
test "$result" = "Packages.sh"

result=$(bash "$RESOLVE_SCRIPT" "$TMPDIR" "Packages.sh" "JD-AX6600-WIFI")
test "$result" = "Packages.sh"

PACKAGES_JD_AX6600_SCRIPT="$SCRIPT_DIR/Packages-JD-AX6600.sh"
grep -Fq 'bash "${script_dir}/Packages.sh"' "$PACKAGES_JD_AX6600_SCRIPT"
grep -Fq '继续执行 AX6600 专用包逻辑' "$PACKAGES_JD_AX6600_SCRIPT"

echo "test_resolve_device_script: ok"
