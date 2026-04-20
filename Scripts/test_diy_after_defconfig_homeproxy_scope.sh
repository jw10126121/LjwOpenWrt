#!/bin/bash

# 说明：验证 diy_after_defconfig 里的 HomeProxy 资源预置只在实际启用 luci-app-homeproxy 时执行。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/diy_after_defconfig.sh"

TMPDIR=$(mktemp -d)
TEST_BIN="$TMPDIR/test-bin"
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

mkdir -p "$TEST_BIN"

cat > "$TEST_BIN/git" <<'EOF'
#!/bin/sh
case "$1" in
clone)
	target_dir="${@: -1}"
	mkdir -p "$target_dir"
	printf 'IP-CIDR,1.1.1.0/24\n' > "$target_dir/cncidr.txt"
	printf '.example.cn\n' > "$target_dir/direct.txt"
	printf '.example.com\n' > "$target_dir/gfw.txt"
	echo "git-clone-called" >> "$HOME_PROXY_GIT_MARKER"
	exit 0
	;;
log)
	echo "20260420"
	exit 0
	;;
*)
	echo "git-other-called" >> "$HOME_PROXY_GIT_MARKER"
	exit 0
	;;
esac
EOF
chmod +x "$TEST_BIN/git"

extract_homeproxy_block() {
	awk '
		/^choose_type_homeproxy=/ { printing=1 }
		printing { print }
		printing && /^fi$/ { exit }
	' "$TARGET_SCRIPT"
}

BLOCK_FILE="$TMPDIR/homeproxy_block.sh"
extract_homeproxy_block > "$BLOCK_FILE"

run_case() {
	local mode=$1
	local case_dir="$TMPDIR/$mode"
	local homeproxy_dir="$case_dir/package/feeds/luci/luci-app-homeproxy"
	local marker="$case_dir/git.marker"

	mkdir -p "$homeproxy_dir/root/etc/homeproxy/scripts" "$homeproxy_dir/root/etc/homeproxy/resources"
	printf '#!/bin/sh\nexit 0\n' > "$homeproxy_dir/root/etc/homeproxy/scripts/test.sh"
	chmod +x "$homeproxy_dir/root/etc/homeproxy/scripts/test.sh"

	cat > "$case_dir/.config" <<EOF
CONFIG_PACKAGE_luci-app-homeproxy=$([ "$mode" = enabled ] && echo y || echo n)
EOF

	(
		cd "$case_dir"
		openwrt_workdir="$case_dir"
		export HOME_PROXY_GIT_MARKER="$marker"
		PATH="$TEST_BIN:$PATH"
		# shellcheck disable=SC1090
		. "$BLOCK_FILE"
	)
}

run_case disabled

if [ -f "$TMPDIR/disabled/git.marker" ]; then
	echo "HomeProxy preload should not run when luci-app-homeproxy is disabled" >&2
	exit 1
fi

run_case enabled

grep -Fq 'git-clone-called' "$TMPDIR/enabled/git.marker"

echo "test_diy_after_defconfig_homeproxy_scope: ok"
