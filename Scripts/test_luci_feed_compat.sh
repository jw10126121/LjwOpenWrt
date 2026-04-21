#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

. "$SCRIPT_DIR/lib/luci_feed_compat.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

FEEDS_25="$TMPDIR/feeds-25.12.conf"
cat > "$FEEDS_25" <<'EOF'
src-git packages https://github.com/coolsnowwolf/packages
src-git luci https://github.com/coolsnowwolf/luci.git;openwrt-25.12
EOF

FEEDS_23="$TMPDIR/feeds-23.05.conf"
cat > "$FEEDS_23" <<'EOF'
src-git packages https://github.com/coolsnowwolf/packages
src-git luci https://github.com/coolsnowwolf/luci.git;openwrt-23.05
EOF

FEEDS_25_SHORT="$TMPDIR/feeds-25.12-short.conf"
cat > "$FEEDS_25_SHORT" <<'EOF'
src-git packages https://github.com/coolsnowwolf/packages
src-git luci https://github.com/coolsnowwolf/luci.git;25.12
EOF

[ "$(resolve_luci_feed_branch "$FEEDS_25")" = "openwrt-25.12" ]
[ "$(resolve_luci_feed_branch "$FEEDS_23")" = "openwrt-23.05" ]
[ "$(resolve_luci_feed_branch "$FEEDS_25_SHORT")" = "openwrt-25.12" ]
[ "$(resolve_luci_feed_branch "$TMPDIR/missing.conf")" = "unknown" ]
is_luci_feed_25_12 "$FEEDS_25"
is_luci_feed_25_12 "$FEEDS_25_SHORT"
is_lean_luci_feed_25_12 "$FEEDS_25"
if is_luci_feed_25_12 "$FEEDS_23"; then
	echo "23.05 should not be treated as 25.12 by the generic helper" >&2
	exit 1
fi
if is_lean_luci_feed_25_12 "$FEEDS_23"; then
	echo "23.05 should not be treated as 25.12" >&2
	exit 1
fi

echo "test_luci_feed_compat: ok"
