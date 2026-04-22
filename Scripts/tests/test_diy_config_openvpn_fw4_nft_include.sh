#!/bin/bash

# 说明：验证 configure_openvpn_defaults 在 FW4 配置下会生成稳定的 nftables NAT drop-in。

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

CASE_DIR="$TMPDIR/fw4"
CONFIG_PATH="$CASE_DIR/.config"
FIREWALL_USER="$CASE_DIR/package/network/config/firewall/files/firewall.user"
OPENVPN_CONFIG="$CASE_DIR/package/feeds/luci/luci-app-openvpn-server/root/etc/config/openvpn"
NFT_RULE="$CASE_DIR/package/base-files/files/usr/share/nftables.d/chain-post/srcnat/99-openvpn-masq.nft"
EXPECTED_RULE='ip saddr 10.8.0.0/24 oifname "br-lan" masquerade comment "OpenVPN server LAN NAT"'

mkdir -p "$(dirname "$FIREWALL_USER")" "$(dirname "$OPENVPN_CONFIG")"
cat > "$CONFIG_PATH" <<'EOF'
CONFIG_PACKAGE_firewall=n
CONFIG_PACKAGE_firewall4=y
EOF
printf '# firewall user\niptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o br-lan -j MASQUERADE\n' > "$FIREWALL_USER"
printf "config openvpn 'sample'\n\toption server '10.8.0.0 255.255.255.0'\n" > "$OPENVPN_CONFIG"

run_once() {
	(
		cd "$CASE_DIR"
		WRT_IP="192.168.10.1"
		op_config="$CONFIG_PATH"
		PATH="$TEST_BIN:$PATH"
		# shellcheck disable=SC1090
		. "$FUNCTIONS_FILE"
		configure_openvpn_defaults >/dev/null
	)
}

run_once
run_once

test -f "$NFT_RULE"
grep -Fxq "$EXPECTED_RULE" "$NFT_RULE"
rule_count=$(grep -Fxc "$EXPECTED_RULE" "$NFT_RULE")
[ "$rule_count" -eq 1 ] || {
	echo "FW4 nftables rule should be written exactly once" >&2
	exit 1
}
if grep -Fq 'iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o br-lan -j MASQUERADE' "$FIREWALL_USER"; then
	echo "FW4 run should remove the legacy iptables OpenVPN NAT rule from firewall.user" >&2
	exit 1
fi

echo "test_diy_config_openvpn_fw4_nft_include: ok"
