#!/bin/bash

# 说明：为源码树模式构造最小可复现样例，验证会递归展开 LuCI 包依赖，
# 并识别 Package/<pkg>/config 里的 select PACKAGE_* 隐式依赖。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
GENERATE_SCRIPT="$SCRIPT_DIR/generate_package_overrides_from_source.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

SOURCE_ROOT="$TMPDIR/openwrt"
PACKAGE_DIR="$SOURCE_ROOT/package/test"
CONFIG_FILE="$TMPDIR/.config"
PACKAGE_LIST="$TMPDIR/package-list.txt"
OUTPUT_FILE="$TMPDIR/generated_overrides.txt"

mkdir -p \
	"$PACKAGE_DIR/luci-app-demo" \
	"$PACKAGE_DIR/luci-app-basic" \
	"$PACKAGE_DIR/demo-core" \
	"$PACKAGE_DIR/demo-helper" \
	"$PACKAGE_DIR/demo-leaf" \
	"$PACKAGE_DIR/demo-default" \
	"$PACKAGE_DIR/demo-default-leaf" \
	"$PACKAGE_DIR/demo-selected" \
	"$PACKAGE_DIR/demo-selected-leaf"

cat > "$PACKAGE_DIR/luci-app-demo/Makefile" <<'EOF'
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-demo

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)/config
	config PACKAGE_demo-default
		default y if PACKAGE_$(PKG_NAME)
	config PACKAGE_demo-selected
		default y if PACKAGE_$(PKG_NAME)
		select PACKAGE_demo-selected
endef

define Package/$(PKG_NAME)
	CATEGORY:=LuCI
	TITLE:=Demo
	DEPENDS:=+demo-core +luci-base
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
EOF

cat > "$PACKAGE_DIR/luci-app-basic/Makefile" <<'EOF'
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-basic
LUCI_DEPENDS:=+luci-base

include $(TOPDIR)/feeds/luci/luci.mk
EOF

cat > "$PACKAGE_DIR/demo-core/Makefile" <<'EOF'
include $(TOPDIR)/rules.mk

define Package/demo-core
	TITLE:=Demo Core
	DEPENDS:=+demo-helper +libc
endef
EOF

cat > "$PACKAGE_DIR/demo-helper/Makefile" <<'EOF'
include $(TOPDIR)/rules.mk

define Package/demo-helper
	TITLE:=Demo Helper
	DEPENDS:=+demo-leaf +libpthread
endef
EOF

cat > "$PACKAGE_DIR/demo-leaf/Makefile" <<'EOF'
include $(TOPDIR)/rules.mk

define Package/demo-leaf
	TITLE:=Demo Leaf
endef
EOF

cat > "$PACKAGE_DIR/demo-default/Makefile" <<'EOF'
include $(TOPDIR)/rules.mk

define Package/demo-default
	TITLE:=Demo Default
	DEPENDS:=+demo-default-leaf
endef
EOF

cat > "$PACKAGE_DIR/demo-default-leaf/Makefile" <<'EOF'
include $(TOPDIR)/rules.mk

define Package/demo-default-leaf
	TITLE:=Demo Default Leaf
endef
EOF

cat > "$PACKAGE_DIR/demo-selected/Makefile" <<'EOF'
include $(TOPDIR)/rules.mk

define Package/demo-selected
	TITLE:=Demo Selected
	DEPENDS:=+demo-selected-leaf
endef
EOF

cat > "$PACKAGE_DIR/demo-selected-leaf/Makefile" <<'EOF'
include $(TOPDIR)/rules.mk

define Package/demo-selected-leaf
	TITLE:=Demo Selected Leaf
endef
EOF

cat > "$CONFIG_FILE" <<'EOF'
CONFIG_PACKAGE_luci-app-demo=m
CONFIG_PACKAGE_luci-app-basic=m
EOF

cat > "$PACKAGE_LIST" <<'EOF'
luci-app-demo
luci-app-basic
EOF

bash "$GENERATE_SCRIPT" "$SOURCE_ROOT" "$CONFIG_FILE" "$PACKAGE_LIST" "$OUTPUT_FILE"

demo_line=$(grep '^luci-app-demo|' "$OUTPUT_FILE")
[ -n "$demo_line" ]
for token in \
	luci-app-demo_ \
	luci-i18n-demo-zh-cn_ \
	demo-core_ \
	demo-default_ \
	demo-default-leaf_ \
	demo-helper_ \
	demo-leaf_ \
	demo-selected_ \
	demo-selected-leaf_; do
	printf '%s\n' "$demo_line" | grep -q "$token"
done
if grep -q '^luci-app-basic|' "$OUTPUT_FILE"; then
	echo "Unexpected override generated for luci-app-basic" >&2
	exit 1
fi

echo "test_generate_package_overrides_from_source: ok"
