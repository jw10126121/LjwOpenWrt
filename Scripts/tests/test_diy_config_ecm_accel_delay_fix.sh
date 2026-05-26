#!/bin/bash

# 说明：验证 ECM accel_delay_pkts 调整逻辑已迁出 diy_config.sh，
# 当前这里只负责写出供 diy_after_defconfig.sh 使用的目标 marker。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/diy_config.sh"

if grep -q '^configure_ecm_accel_delay_fix() {' "$TARGET_SCRIPT"; then
	echo "configure_ecm_accel_delay_fix should no longer live in diy_config.sh" >&2
	exit 1
fi

if grep -q 'accel_delay_pkts' "$TARGET_SCRIPT"; then
	echo "diy_config.sh should not patch accel_delay_pkts directly anymore" >&2
	exit 1
fi

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

extract_function() {
	local function_name=$1
	awk -v name="$function_name" '
		$0 ~ "^" name "\\(\\) *\\{" { printing=1 }
		printing { print }
		printing && $0 == "}" { exit }
	' "$TARGET_SCRIPT"
}

FUNCTIONS_FILE="$TMPDIR/functions.sh"
extract_function "write_build_target_marker" > "$FUNCTIONS_FILE"

(
	cd "$TMPDIR"
	config_name='CMIOT-AX18-NOWIFI-FW3'
	# shellcheck disable=SC1090
	. "$FUNCTIONS_FILE"
	write_build_target_marker
)

grep -qx 'CMIOT-AX18-NOWIFI-FW3' "$TMPDIR/.linjw-target-label"

echo "test_diy_config_ecm_accel_delay_fix: ok"
