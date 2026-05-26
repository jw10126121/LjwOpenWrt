#!/bin/bash

# 说明：qualcommax 目标应把 qca-nss-ecm 的默认 accel_delay_pkts
# 从 1 调整为 16，避免微信朋友圈因过早进入加速而异常。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/diy_config.sh"

TMPDIR=$(mktemp -d)
TEST_BIN="$TMPDIR/test-bin"
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

mkdir -p "$TEST_BIN"
cat > "$TEST_BIN/sed" <<'EOF'
#!/bin/sh

if [ "$1" = "-i" ]; then
	shift
	exec /usr/bin/sed -i '' "$@"
fi

exec /usr/bin/sed "$@"
EOF
chmod +x "$TEST_BIN/sed"

extract_function() {
	local function_name=$1
	awk -v name="$function_name" '
		$0 ~ "^" name "\\(\\) *\\{" { printing=1 }
		printing { print }
		printing && $0 == "}" { exit }
	' "$TARGET_SCRIPT"
}

FUNCTIONS_FILE="$TMPDIR/functions.sh"
extract_function "configure_ecm_accel_delay_fix" > "$FUNCTIONS_FILE"

CASE_DIR="$TMPDIR/case"
OP_CONFIG="$CASE_DIR/.config"
ECM_INIT="$CASE_DIR/package/qca/qca-nss-ecm/files/qca-nss-ecm.init"
mkdir -p "$(dirname "$ECM_INIT")"

cat > "$OP_CONFIG" <<'EOF'
CONFIG_TARGET_qualcommax=y
EOF

cat > "$ECM_INIT" <<'EOF'
load_ecm() {
	[ -d /sys/module/ecm ] || {
		insmod ecm front_end_selection=$(get_front_end_mode)
		echo 1 > /sys/kernel/debug/ecm/ecm_classifier_default/accel_delay_pkts
	}
}
EOF

(
	cd "$CASE_DIR"
	op_config="$OP_CONFIG"
	PATH="$TEST_BIN:$PATH"
	# shellcheck disable=SC1090
	. "$FUNCTIONS_FILE"
	configure_ecm_accel_delay_fix >/dev/null
)

grep -q '^		echo 16 > /sys/kernel/debug/ecm/ecm_classifier_default/accel_delay_pkts$' "$ECM_INIT"

if grep -q '^		echo 1 > /sys/kernel/debug/ecm/ecm_classifier_default/accel_delay_pkts$' "$ECM_INIT"; then
	echo "ecm init should no longer keep accel_delay_pkts at 1" >&2
	exit 1
fi

echo "test_diy_config_ecm_accel_delay_fix: ok"
