#!/bin/bash

# 说明：验证 LuCI feed 分支只读取 WRT_LUCI_BRANCH，
# 并支持短写法；未识别时保持 feeds.conf.default 原样不动。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/diy_feeds.sh"

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

run_case() {
	local case_name=$1
	local luci_branch=$2
	local case_dir="$TMPDIR/$case_name"
	mkdir -p "$case_dir"

	cat > "$case_dir/feeds.conf.default" <<'EOF'
#src-git helloworld https://example.com/helloworld.git
src-git luci https://github.com/coolsnowwolf/luci.git;openwrt-25.12
EOF

	(
		cd "$case_dir"
		PATH="$TEST_BIN:$PATH" \
		WRT_DEVICE="IPQ60XX-NOWIFI" \
		WRT_LUCI_BRANCH="$luci_branch" \
		bash "$TARGET_SCRIPT"
	)
}

run_case default ''
run_case branch_full 'openwrt-23.05'
run_case branch_short '23.05'
run_case branch_compact '2305'
run_case branch_25_short '25.12'
run_case branch_25_compact '2512'
run_case unknown_branch 'foo'

grep -q 'src-git luci https://github.com/coolsnowwolf/luci.git;openwrt-25.12' "$TMPDIR/default/feeds.conf.default"

grep -q 'src-git luci https://github.com/coolsnowwolf/luci.git;openwrt-23.05' "$TMPDIR/branch_full/feeds.conf.default"
if grep -q 'openwrt-25.12' "$TMPDIR/branch_full/feeds.conf.default"; then
	echo "full WRT_LUCI_BRANCH should switch LuCI feed from 25.12 to 23.05" >&2
	exit 1
fi

grep -q 'src-git luci https://github.com/coolsnowwolf/luci.git;openwrt-23.05' "$TMPDIR/branch_short/feeds.conf.default"
grep -q 'src-git luci https://github.com/coolsnowwolf/luci.git;openwrt-23.05' "$TMPDIR/branch_compact/feeds.conf.default"
if grep -q 'openwrt-25.12' "$TMPDIR/branch_compact/feeds.conf.default"; then
	echo "compact WRT_LUCI_BRANCH should switch LuCI feed from 25.12 to 23.05" >&2
	exit 1
fi

grep -q 'src-git luci https://github.com/coolsnowwolf/luci.git;openwrt-25.12' "$TMPDIR/branch_25_short/feeds.conf.default"
grep -q 'src-git luci https://github.com/coolsnowwolf/luci.git;openwrt-25.12' "$TMPDIR/branch_25_compact/feeds.conf.default"

grep -q 'src-git luci https://github.com/coolsnowwolf/luci.git;openwrt-25.12' "$TMPDIR/unknown_branch/feeds.conf.default"
if grep -q 'src-git luci https://github.com/coolsnowwolf/luci.git;foo' "$TMPDIR/unknown_branch/feeds.conf.default"; then
	echo "unknown WRT_LUCI_BRANCH should not rewrite feeds.conf.default" >&2
	exit 1
fi
grep -q '^src-git helloworld ' "$TMPDIR/unknown_branch/feeds.conf.default"

echo "test_diy_feeds_luci23_overlay: ok"
