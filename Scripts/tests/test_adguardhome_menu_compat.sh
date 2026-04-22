#!/bin/bash

# 说明：验证 LuCI 25.12 兼容层会为旧版 luci-app-adguardhome 补齐 menu.d，
# 避免 fallback 到 23.05 后菜单不显示。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/Packages.sh"
TMPDIR=$(mktemp -d)

cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

for fn in \
	ensure_adguardhome_menu_compat \
	fallback_adguardhome_package_25_12; do
	grep -q "^${fn}() {" "$TARGET_SCRIPT"
done

extract_function() {
	local fn="$1"

	awk -v name="$fn" '
		$0 ~ "^" name "\\(\\) \\{" {
			in_fn=1
			brace_depth=1
			print
			next
		}
		in_fn {
			print

			if (!in_heredoc && $0 ~ /<<\x27EOF\x27/) {
				in_heredoc=1
				next
			}

			if (in_heredoc) {
				if ($0 == "EOF") {
					in_heredoc=0
				}
				next
			}

			open_count=gsub(/\{/, "{")
			close_count=gsub(/\}/, "}")
			brace_depth += open_count - close_count
			if (brace_depth == 0) {
				exit
			}
		}
	' "$TARGET_SCRIPT"
}

extract_function "fallback_adguardhome_package_25_12" | grep -q 'ensure_adguardhome_menu_compat'

FUNCTIONS_FILE="$TMPDIR/functions.sh"
extract_function "ensure_adguardhome_menu_compat" > "$FUNCTIONS_FILE"

PACKAGE_DIR="$TMPDIR/package/luci-app-adguardhome"
mkdir -p "$PACKAGE_DIR/root/usr/share/rpcd/acl.d"

(
	cd "$TMPDIR/package"
	# shellcheck disable=SC1090
	. "$FUNCTIONS_FILE"
	ensure_adguardhome_menu_compat >/dev/null
)

MENU_FILE="$PACKAGE_DIR/root/usr/share/luci/menu.d/luci-app-adguardhome.json"
test -f "$MENU_FILE"
grep -q '"admin/services/AdGuardHome"' "$MENU_FILE"
grep -q '"type": "firstchild"' "$MENU_FILE"
grep -q '"admin/services/AdGuardHome/base"' "$MENU_FILE"
grep -q '"type": "cbi"' "$MENU_FILE"
grep -q '"path": "AdGuardHome/base"' "$MENU_FILE"
grep -q '"admin/services/AdGuardHome/log"' "$MENU_FILE"
grep -q '"type": "form"' "$MENU_FILE"
grep -q '"path": "AdGuardHome/log"' "$MENU_FILE"
grep -q '"admin/services/AdGuardHome/manual"' "$MENU_FILE"
grep -q '"path": "AdGuardHome/manual"' "$MENU_FILE"
grep -q '"acl": \[ "luci-app-adguardhome" \]' "$MENU_FILE"
grep -q '"uci": { "AdGuardHome": true }' "$MENU_FILE"

echo "test_adguardhome_menu_compat: ok"
