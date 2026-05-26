#!/bin/bash

# 说明：只有 CMIOT-AX18-NOWIFI 应把 qca-nss-ecm 的默认 accel_delay_pkts
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

run_case() {
	local case_name=$1
	local wrt_target=$2
	local config_body=$3
	local expected_value=$4
	local case_dir="$TMPDIR/$case_name"
	local op_config="$case_dir/.config"
	local ecm_init="$case_dir/package/qca/qca-nss-ecm/files/qca-nss-ecm.init"

	mkdir -p "$(dirname "$ecm_init")"

	printf '%s\n' "$config_body" > "$op_config"

	cat > "$ecm_init" <<'EOF'
load_ecm() {
	[ -d /sys/module/ecm ] || {
		insmod ecm front_end_selection=$(get_front_end_mode)
		echo 1 > /sys/kernel/debug/ecm/ecm_classifier_default/accel_delay_pkts
	}
}
EOF

	(
		cd "$case_dir"
		op_config="$op_config"
		WRT_TARGET="$wrt_target"
		PATH="$TEST_BIN:$PATH"
		# shellcheck disable=SC1090
		. "$FUNCTIONS_FILE"
		configure_ecm_accel_delay_fix >/dev/null
	)

	grep -q "^		echo ${expected_value} > /sys/kernel/debug/ecm/ecm_classifier_default/accel_delay_pkts$" "$ecm_init"
}

run_case \
	"ax18" \
	"CMIOT-AX18-NOWIFI" \
	"CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_cmiot_ax18=y" \
	"16"
run_case \
	"ax18_fw3" \
	"CMIOT-AX18-NOWIFI-FW3" \
	"CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_cmiot_ax18=y" \
	"16"
run_case \
	"ax18_fw4" \
	"CMIOT-AX18-NOWIFI-FW4" \
	"CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_cmiot_ax18=y" \
	"16"
run_case \
	"ax18_wrong_config" \
	"CMIOT-AX18-NOWIFI-FW3" \
	"CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_glinet_gl-mt6000=y" \
	"16"
run_case \
	"ax18_mini" \
	"CMIOT-AX18-NOWIFI-MINI" \
	"CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_cmiot_ax18=y" \
	"16"
run_case \
	"other_target" \
	"MT6000-WIFI-FW3" \
	"CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_glinet_gl-mt6000=y" \
	"16"

echo "test_diy_config_ecm_accel_delay_fix: ok"
