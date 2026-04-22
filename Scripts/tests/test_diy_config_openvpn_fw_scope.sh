#!/bin/bash

# 说明：验证 configure_openvpn_defaults 会按防火墙栈分别生成 FW3/FW4 对应的 NAT 规则。

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
extract_function "configure_openvpn_defaults" > "$FUNCTIONS_FILE"

run_case() {
	local mode=$1
	local case_dir="$TMPDIR/$mode"
	local config_path="$case_dir/.config"
	local firewall_user="$case_dir/package/network/config/firewall/files/firewall.user"
	local openvpn_config="$case_dir/package/feeds/luci/luci-app-openvpn-server/root/etc/config/openvpn"
	local nft_rule="$case_dir/package/base-files/files/usr/share/nftables.d/chain-post/srcnat/99-openvpn-masq.nft"

	mkdir -p "$(dirname "$firewall_user")" "$(dirname "$openvpn_config")" "$(dirname "$nft_rule")"
	cat > "$config_path" <<EOF
CONFIG_PACKAGE_firewall=$([ "$mode" = fw3 ] && echo y || echo n)
CONFIG_PACKAGE_firewall4=$([ "$mode" = fw4 ] && echo y || echo n)
EOF
	printf '# firewall user\n' > "$firewall_user"
	printf "config openvpn 'sample'\n\toption server '10.8.0.0 255.255.255.0'\n" > "$openvpn_config"

	(
		cd "$case_dir"
		WRT_IP="192.168.10.1"
		op_config="$config_path"
		PATH="$TEST_BIN:$PATH"
		# shellcheck disable=SC1090
		. "$FUNCTIONS_FILE"
		configure_openvpn_defaults >/dev/null
	)
}

run_case fw3
run_case fw4

grep -Fq 'iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o br-lan -j MASQUERADE' "$TMPDIR/fw3/package/network/config/firewall/files/firewall.user"
if [ -f "$TMPDIR/fw3/package/base-files/files/usr/share/nftables.d/chain-post/srcnat/99-openvpn-masq.nft" ]; then
	echo "FW3 should not generate an fw4 nftables NAT snippet" >&2
	exit 1
fi
if grep -Fq 'iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o br-lan -j MASQUERADE' "$TMPDIR/fw4/package/network/config/firewall/files/firewall.user"; then
	echo "FW4 should not inject iptables MASQUERADE rules into firewall.user" >&2
	exit 1
fi
grep -Fq 'ip saddr 10.8.0.0/24 oifname "br-lan" masquerade' "$TMPDIR/fw4/package/base-files/files/usr/share/nftables.d/chain-post/srcnat/99-openvpn-masq.nft"

echo "test_diy_config_openvpn_fw_scope: ok"
