#!/bin/bash

# 说明：验证 append_default_settings_snippet 现在把首次开机片段写入
# package/base-files/files/etc/uci-defaults/99-setup_config，而不是 lean 的 zzz-default-settings。

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
} > "$FUNCTIONS_FILE"

CASE_DIR="$TMPDIR/case"
SETUP_CONFIG="$CASE_DIR/package/base-files/files/etc/uci-defaults/99-setup_config"
PATCH_TEMPLATE="$CASE_DIR/patch/99-setup_config.txt"
mkdir -p "$CASE_DIR"
mkdir -p "$(dirname "$PATCH_TEMPLATE")"
cat > "$PATCH_TEMPLATE" <<'EOF'
#!/bin/sh

# setup_config hooks
exit 0
EOF

(
	cd "$CASE_DIR"
	file_default_settings="$SETUP_CONFIG"
	file_setup_config="$SETUP_CONFIG"
	current_script_dir="$CASE_DIR"
	setup_config_template="$PATCH_TEMPLATE"
	PATH="$TEST_BIN:$PATH"
	# shellcheck disable=SC1090
	. "$FUNCTIONS_FILE"
	append_default_settings_snippet "# setup_config hooks" "uci set system.@system[0].zonename='Asia/Shanghai'" "uci set system.@system[0].zonename='Asia/Shanghai'"
)

grep -q '^#!/bin/sh$' "$SETUP_CONFIG"
grep -q '^# setup_config hooks$' "$SETUP_CONFIG"
grep -q "^uci set system.@system\\[0\\].zonename='Asia/Shanghai'$" "$SETUP_CONFIG"
tail -n 1 "$SETUP_CONFIG" | grep -q '^exit 0$'

if grep -q 'zzz-default-settings' "$SETUP_CONFIG"; then
	echo "setup config should not reference zzz-default-settings" >&2
	exit 1
fi

echo "test_diy_config_setup_config: ok"
