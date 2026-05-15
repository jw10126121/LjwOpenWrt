#!/bin/bash

# 说明：首次启动脚本不应再为 frpc/frps 注入运行时 chmod，
# 否则会触发 overlay copy-up，把内置二进制和 init 脚本复制到 overlay。

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
{
	extract_function "append_file_snippet"
	echo
	extract_function "ensure_setup_config_script"
	echo
	extract_function "append_default_settings_snippet"
	echo
	extract_function "build_disable_feed_cmd"
	echo
	extract_function "apply_lean_runtime_customizations"
} > "$FUNCTIONS_FILE"

CASE_DIR="$TMPDIR/case"
DEFAULT_SETTINGS="$CASE_DIR/package/lean/default-settings/files/zzz-default-settings"
SETUP_CONFIG="$CASE_DIR/package/base-files/files/etc/uci-defaults/99-setup_config"
PATCH_TEMPLATE="$CASE_DIR/patch/99-setup_config.txt"
mkdir -p "$(dirname "$DEFAULT_SETTINGS")"
mkdir -p "$(dirname "$PATCH_TEMPLATE")"
touch "$DEFAULT_SETTINGS"
cat > "$PATCH_TEMPLATE" <<'EOF'
#!/bin/sh

# setup_config hooks
uci commit system
helloworld
exit 0
EOF

(
	cd "$CASE_DIR"
	file_default_settings="$DEFAULT_SETTINGS"
	file_setup_config="$SETUP_CONFIG"
	current_script_dir="$CASE_DIR"
	setup_config_template="$PATCH_TEMPLATE"
	package_manager='ipk'
	PATH="$TEST_BIN:$PATH"
	# shellcheck disable=SC1090
	. "$FUNCTIONS_FILE"
	apply_lean_runtime_customizations >/dev/null
)

grep -q '^uci set luci.apply.holdoff=3$' "$SETUP_CONFIG"
grep -q '^uci set dhcp.@dnsmasq\[0\].sequential_ip=1$' "$SETUP_CONFIG"

if grep -qE '/(usr/bin/frpc|usr/bin/frps|etc/init\.d/frpc|etc/init\.d/frps)' "$SETUP_CONFIG"; then
	echo "frp runtime chmod should not be injected into setup_config" >&2
	exit 1
fi

echo "test_diy_config_frp_permissions: ok"
