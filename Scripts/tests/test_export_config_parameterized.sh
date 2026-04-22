#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
EXPORT_SCRIPT="$SCRIPT_DIR/export_config.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

mkdir -p "$TMPDIR/overlays"
mkdir -p "$TMPDIR/device-overlays" "$TMPDIR/variants"

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

cat > "$TMPDIR/variants/MINI-SERVICE.txt" <<'EOF'
CONFIG_VARIANT=mini
CONFIG_FEATURE=module
EOF

cat > "$TMPDIR/variants/MINI-FW4.txt" <<'EOF'
CONFIG_VARIANT_FW=mini-fw4
EOF

cat > "$TMPDIR/DEVICE-A.txt" <<'EOF'
CONFIG_DEVICE=device-a
EOF

cat > "$TMPDIR/DEVICE-A-MINI-FW3.txt" <<'EOF'
CONFIG_DEVICE=device-a-mini
# >>> SERVICE-BEGIN
CONFIG_VARIANT=device-mini
# <<< SERVICE-END
# >>> FW3-BEGIN
CONFIG_FEATURE=device-override
# <<< FW3-END
# >>> FW4-BEGIN
# CONFIG_FEATURE=device-fw4-override
# CONFIG_VARIANT_FW=device-mini-fw4
# <<< FW4-END
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

OUT_MINI="$TMPDIR/merged-mini.txt"

bash "$EXPORT_SCRIPT" \
	--config-dir "$TMPDIR" \
	--device "DEVICE-A-MINI" \
	--fw "fw4" \
	--output "$OUT_MINI"

grep -q '^CONFIG_DEVICE=device-a-mini$' "$OUT_MINI"
grep -q '^CONFIG_VARIANT=device-mini$' "$OUT_MINI"
grep -q '^CONFIG_VARIANT_FW=device-mini-fw4$' "$OUT_MINI"
grep -n '^CONFIG_FEATURE=' "$OUT_MINI" | tail -n 1 | grep -q 'CONFIG_FEATURE=device-fw4-override'
if grep -q '^CONFIG_VARIANT=mini$' "$OUT_MINI"; then
	echo "mini export should skip MINI-SERVICE variant when device file embeds service config" >&2
	exit 1
fi
if grep -q '^CONFIG_VARIANT_FW=mini-fw4$' "$OUT_MINI"; then
	echo "mini export should skip MINI-FW4 variant when device file embeds fw config" >&2
	exit 1
fi

echo "test_export_config_parameterized: ok"
