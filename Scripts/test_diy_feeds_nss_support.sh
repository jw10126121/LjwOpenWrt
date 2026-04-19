#!/bin/bash

# 说明：验证 NSS 相关 feed 只对“IPQ + 支持 NSS 的源码风味”启用。
# 当前 lean 风味下关闭；VIKINGYFY 的 IPQ 目标允许开启。

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
	local device=$2
	local flavor=$3
	local case_dir="$TMPDIR/$case_name"
	mkdir -p "$case_dir"

	cat > "$case_dir/feeds.conf.default" <<'EOF'
#src-git helloworld https://example.com/helloworld.git
EOF

	(
		cd "$case_dir"
		PATH="$TEST_BIN:$PATH" \
		WRT_DEVICE="$device" \
		WRT_SOURCE_FLAVOR="$flavor" \
		bash "$TARGET_SCRIPT"
	)
}

run_case ipq_lean IPQ60XX-NOWIFI lean
run_case ipq_vikingyfy IPQ60XX-NOWIFI VIKINGYFY
run_case mt6000_lean MT6000-WIFI lean

grep -q '^src-git helloworld ' "$TMPDIR/ipq_vikingyfy/feeds.conf.default"
grep -q 'src-git nss_packages https://github.com/qosmio/nss-packages.git' "$TMPDIR/ipq_vikingyfy/feeds.conf.default"
grep -q 'src-git sqm_scripts_nss https://github.com/qosmio/sqm-scripts-nss.git' "$TMPDIR/ipq_vikingyfy/feeds.conf.default"

grep -q '^src-git helloworld ' "$TMPDIR/ipq_lean/feeds.conf.default"
if grep -q 'qosmio/nss-packages.git' "$TMPDIR/ipq_lean/feeds.conf.default"; then
	echo "lean IPQ build should not enable nss-packages feed" >&2
	exit 1
fi
if grep -q 'qosmio/sqm-scripts-nss.git' "$TMPDIR/ipq_lean/feeds.conf.default"; then
	echo "lean IPQ build should not enable sqm-scripts-nss feed" >&2
	exit 1
fi

grep -q '^src-git helloworld ' "$TMPDIR/mt6000_lean/feeds.conf.default"
if grep -q 'qosmio/nss-packages.git' "$TMPDIR/mt6000_lean/feeds.conf.default"; then
	echo "MT6000 should not enable nss-packages feed" >&2
	exit 1
fi
if grep -q 'qosmio/sqm-scripts-nss.git' "$TMPDIR/mt6000_lean/feeds.conf.default"; then
	echo "MT6000 should not enable sqm-scripts-nss feed" >&2
	exit 1
fi

echo "test_diy_feeds_nss_support: ok"
