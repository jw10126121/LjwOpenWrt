#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
EXPORT_SCRIPT="$SCRIPT_DIR/export_config.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

mkdir -p "$TMPDIR/devices" "$TMPDIR/overlays"
mkdir -p "$TMPDIR/device-overlays"

cat > "$TMPDIR/GENERAL.txt" <<'EOF'
CONFIG_COMMON=y
CONFIG_FRP_ROLE=client
CONFIG_PKG_FORMAT=ipk
EOF

cat > "$TMPDIR/GENERAL-SERVICE.txt" <<'EOF'
CONFIG_SERVICE=y
EOF

cat > "$TMPDIR/GENERAL-FW3.txt" <<'EOF'
CONFIG_FW=fw3
EOF

cat > "$TMPDIR/GENERAL-FW4.txt" <<'EOF'
CONFIG_FW=fw4
EOF

cat > "$TMPDIR/devices/DEVICE-A.txt" <<'EOF'
CONFIG_DEVICE=device-a
EOF

cat > "$TMPDIR/device-overlays/DEVICE-A-FW3.txt" <<'EOF'
CONFIG_DEVICE_FW=device-a-fw3
CONFIG_FRP_ROLE=device-default
EOF

cat > "$TMPDIR/overlays/FRPS.txt" <<'EOF'
CONFIG_FRP_ROLE=server
EOF

cat > "$TMPDIR/overlays/APK.txt" <<'EOF'
CONFIG_PKG_FORMAT=apk
EOF

OUT="$TMPDIR/merged.txt"

bash "$EXPORT_SCRIPT" \
	--config-dir "$TMPDIR" \
	--device "DEVICE-A" \
	--fw "fw3" \
	--overlay "frps,apk" \
	--output "$OUT"

grep -q '^CONFIG_COMMON=y$' "$OUT"
grep -q '^CONFIG_SERVICE=y$' "$OUT"
grep -q '^CONFIG_FW=fw3$' "$OUT"
grep -q '^CONFIG_DEVICE=device-a$' "$OUT"
grep -q '^CONFIG_DEVICE_FW=device-a-fw3$' "$OUT"
grep -n '^CONFIG_FRP_ROLE=' "$OUT" | tail -n 1 | grep -q 'CONFIG_FRP_ROLE=server'
grep -n '^CONFIG_PKG_FORMAT=' "$OUT" | tail -n 1 | grep -q 'CONFIG_PKG_FORMAT=apk'

echo "test_export_config_parameterized: ok"
