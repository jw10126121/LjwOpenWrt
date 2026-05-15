#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/Packages.sh"

extract_function() {
	local fn="$1"

	awk -v name="$fn" '
		$0 ~ "^" name "\\(\\) \\{" { printing=1 }
		printing { print }
		printing && /^}/ { exit }
	' "$TARGET_SCRIPT"
}

COMMON_BODY=$(awk '
	/^apply_common_package_overrides\(\) \{/ { printing=1; next }
	printing && /^}/ { exit }
	printing { print }
' "$TARGET_SCRIPT")

POST_FIX_BODY=$(awk '
	/^apply_post_update_fixes\(\) \{/ { printing=1; next }
	printing && /^}/ { exit }
	printing { print }
' "$TARGET_SCRIPT")

printf '%s\n' "$COMMON_BODY" | grep -q 'UPDATE_PACKAGE "luci-app-openclash" "vernesong/OpenClash" "master" "pkg"'

if printf '%s\n' "$COMMON_BODY" | grep -q 'UPDATE_PACKAGE "luci-app-openclash" "vernesong/OpenClash" "dev" "pkg"'; then
	echo "OpenClash override should no longer track the dev branch" >&2
	exit 1
fi

printf '%s\n' "$COMMON_BODY" | grep -q 'pin_easytier_binary_version'
printf '%s\n' "$COMMON_BODY" | grep -q 'update_package_list "luci-app-easytier easytier easytier-noweb" "EasyTier/luci-app-easytier" "main"'
printf '%s\n' "$COMMON_BODY" | grep -q "local easytier_release_version='2.6.4'"
printf '%s\n' "$COMMON_BODY" | grep -q 'pin_easytier_binary_version "." "${easytier_release_version}"'
if printf '%s\n' "$POST_FIX_BODY" | grep -q 'preload_homeproxy_resources'; then
	echo "Packages.sh should not preload HomeProxy resources in the default post-update fix chain" >&2
	exit 1
fi

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

FUNCTIONS_FILE="$TMPDIR/functions.sh"
extract_function "pin_easytier_binary_version" > "$FUNCTIONS_FILE"

TEST_REPO="$TMPDIR/package"
mkdir -p "$TEST_REPO/easytier" "$TEST_REPO/easytier-noweb" "$TEST_REPO/luci-app-easytier"
cat > "$TEST_REPO/easytier/Makefile" <<'EOF'
PKG_VERSION:=$(or $(EASYTIER_VERSION),2.6.2)
EOF
cat > "$TEST_REPO/easytier-noweb/Makefile" <<'EOF'
PKG_VERSION:=$(or $(EASYTIER_VERSION),2.6.2)
EOF
cat > "$TEST_REPO/luci-app-easytier/Makefile" <<'EOF'
PKG_VERSION:=$(or $(EASYTIER_VERSION),2.6.2)
EOF

# shellcheck disable=SC1090
. "$FUNCTIONS_FILE"
pin_easytier_binary_version "$TEST_REPO"

grep -q '2.6.2' "$TEST_REPO/easytier/Makefile"
grep -q '2.6.2' "$TEST_REPO/easytier-noweb/Makefile"
grep -q '2.6.2' "$TEST_REPO/luci-app-easytier/Makefile"

pin_easytier_binary_version "$TEST_REPO" "2.6.4"

grep -q '^PKG_VERSION:=2.6.4$' "$TEST_REPO/easytier/Makefile"
grep -q '^PKG_VERSION:=2.6.4$' "$TEST_REPO/easytier-noweb/Makefile"
grep -Fxq 'PKG_VERSION:=$(or $(EASYTIER_VERSION),2.6.2)' "$TEST_REPO/luci-app-easytier/Makefile"

for config_file in \
	"$SCRIPT_DIR/../Config/CMIOT-AX18-NOWIFI-FW3.txt" \
	"$SCRIPT_DIR/../Config/CMIOT-AX18-NOWIFI-MINI-FW3.txt" \
	"$SCRIPT_DIR/../Config/IPQ60XX-NOWIFI-FW3.txt" \
	"$SCRIPT_DIR/../Config/IPQ60XX-NOWIFI-MINI-FW3.txt" \
	"$SCRIPT_DIR/../Config/IPQ60XX-NOWIFI_full.txt" \
	"$SCRIPT_DIR/../Config/JD-AX1800PRO-WIFI-FW3.txt" \
	"$SCRIPT_DIR/../Config/MIR3G-WIFI-MINI-FW3.txt" \
	"$SCRIPT_DIR/../Config/MT6000-WIFI-FW3.txt" \
	"$SCRIPT_DIR/../Config/MT6000-WIFI-MINI-FW3.txt"
do
	grep -q 'CONFIG_PACKAGE_easytier-noweb=y\|^# CONFIG_PACKAGE_easytier-noweb is not set$' "$config_file"
	! grep -q '^CONFIG_PACKAGE_easytier=y$' "$config_file"
	! grep -q '^# CONFIG_EASYTIER_INCLUDE_WEBCONSOLE is not set$' "$config_file"
done

echo "test_packages_openclash_easytier_versions: ok"
