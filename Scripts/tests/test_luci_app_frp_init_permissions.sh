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

grep -q '^ensure_luci_app_frp_init_permissions() {' "$TARGET_SCRIPT"

POST_FIX_BODY=$(awk '
	/^apply_post_update_fixes\(\) \{/ { printing=1; next }
	printing && /^}/ { exit }
	printing { print }
' "$TARGET_SCRIPT")

printf '%s\n' "$POST_FIX_BODY" | grep -q '^    ensure_luci_app_frp_init_permissions$'

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

FUNCTIONS_FILE="$TMPDIR/functions.sh"
extract_function "ensure_luci_app_frp_init_permissions" > "$FUNCTIONS_FILE"

TEST_REPO="$TMPDIR/package"
mkdir -p "$TEST_REPO/luci-app-frpc/root/etc/init.d" "$TEST_REPO/luci-app-frps/root/etc/init.d"

cat > "$TEST_REPO/luci-app-frpc/root/etc/init.d/frpc" <<'EOF'
#!/bin/sh /etc/rc.common
exit 0
EOF

cat > "$TEST_REPO/luci-app-frps/root/etc/init.d/frps" <<'EOF'
#!/bin/sh /etc/rc.common
exit 0
EOF

chmod 0644 "$TEST_REPO/luci-app-frpc/root/etc/init.d/frpc" "$TEST_REPO/luci-app-frps/root/etc/init.d/frps"

(
	cd "$TEST_REPO"
	# shellcheck disable=SC1090
	. "$FUNCTIONS_FILE"
	ensure_luci_app_frp_init_permissions
)

test -x "$TEST_REPO/luci-app-frpc/root/etc/init.d/frpc"
test -x "$TEST_REPO/luci-app-frps/root/etc/init.d/frps"

MODE_FRPC=$(stat -f '%A' "$TEST_REPO/luci-app-frpc/root/etc/init.d/frpc")
MODE_FRPS=$(stat -f '%A' "$TEST_REPO/luci-app-frps/root/etc/init.d/frps")
[ "$MODE_FRPC" = "755" ]
[ "$MODE_FRPS" = "755" ]

cp "$TEST_REPO/luci-app-frpc/root/etc/init.d/frpc" "$TMPDIR/frpc.once"
cp "$TEST_REPO/luci-app-frps/root/etc/init.d/frps" "$TMPDIR/frps.once"

(
	cd "$TEST_REPO"
	# shellcheck disable=SC1090
	. "$FUNCTIONS_FILE"
	ensure_luci_app_frp_init_permissions
)

cmp -s "$TEST_REPO/luci-app-frpc/root/etc/init.d/frpc" "$TMPDIR/frpc.once"
cmp -s "$TEST_REPO/luci-app-frps/root/etc/init.d/frps" "$TMPDIR/frps.once"

echo "test_luci_app_frp_init_permissions: ok"
