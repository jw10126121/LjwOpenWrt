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

printf '%s\n' "$COMMON_BODY" | grep -q 'UPDATE_PACKAGE "luci-app-openclash" "vernesong/OpenClash" "master" "pkg"'

if printf '%s\n' "$COMMON_BODY" | grep -q 'UPDATE_PACKAGE "luci-app-openclash" "vernesong/OpenClash" "dev" "pkg"'; then
	echo "OpenClash override should no longer track the dev branch" >&2
	exit 1
fi

printf '%s\n' "$COMMON_BODY" | grep -q 'prepare_easytier_version_file'
printf '%s\n' "$COMMON_BODY" | grep -q 'update_package_list "luci-app-easytier easytier" "EasyTier/luci-app-easytier" "main" "version.mk"'
printf '%s\n' "$COMMON_BODY" | grep -q "local easytier_release_version='2.6.4'"
printf '%s\n' "$COMMON_BODY" | grep -q 'prepare_easytier_version_file "." "${easytier_release_version}"'

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

FUNCTIONS_FILE="$TMPDIR/functions.sh"
extract_function "prepare_easytier_version_file" > "$FUNCTIONS_FILE"

TEST_REPO="$TMPDIR/package"
mkdir -p "$TEST_REPO/easytier" "$TEST_REPO/luci-app-easytier"
cat > "$TEST_REPO/version.mk" <<'EOF'
# EasyTier Version Configuration
EASYTIER_VERSION=2.6.2
EOF
cat > "$TEST_REPO/easytier/Makefile" <<'EOF'
-include $(dir $(lastword $(MAKEFILE_LIST)))../version.mk
EOF
cat > "$TEST_REPO/luci-app-easytier/Makefile" <<'EOF'
-include $(dir $(lastword $(MAKEFILE_LIST)))../version.mk
EOF

# shellcheck disable=SC1090
. "$FUNCTIONS_FILE"
prepare_easytier_version_file "$TEST_REPO"

grep -q '^EASYTIER_VERSION=2.6.2$' "$TEST_REPO/easytier-version.mk"
grep -q '\.\./easytier-version.mk' "$TEST_REPO/easytier/Makefile"
grep -q '\.\./easytier-version.mk' "$TEST_REPO/luci-app-easytier/Makefile"

prepare_easytier_version_file "$TEST_REPO" "2.6.4"

grep -q '^EASYTIER_VERSION=2.6.4$' "$TEST_REPO/easytier-version.mk"

echo "test_packages_openclash_easytier_versions: ok"
