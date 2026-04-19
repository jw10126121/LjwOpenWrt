#!/bin/bash

# 说明：验证 diy_config.sh 在 apk 模式下会修补 package/Makefile，
# 使空的目标包 feed 不会因为 `*.apk` 无匹配而让 apk mkndx 失败。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/diy_config.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

extract_function() {
	local function_name=$1
	awk -v name="$function_name" '
		$0 ~ "^" name "\\(\\) *\\{" { printing=1 }
		printing { print }
		printing && $0 == "}" { exit }
	' "$TARGET_SCRIPT"
}

FUNCTIONS_FILE="$TMPDIR/functions.sh"
extract_function "patch_apk_empty_feed_indexing" > "$FUNCTIONS_FILE"

create_makefile() {
	local target_file=$1
	cat > "$target_file" <<'EOF'
define Package/merge-index
	(cd $(PACKAGE_DIR) && $(STAGING_DIR_HOST)/bin/apk mkndx \
		--root $(TOPDIR) \
		--keys-dir $(TOPDIR) \
		--allow-untrusted \
		--sign $(BUILD_KEY) \
		--output packages.adb \
		*.apk; \
	)
endef
EOF
}

APK_MAKEFILE="$TMPDIR/apk-package.mk"
create_makefile "$APK_MAKEFILE"

(
	package_manager='apk'
	# shellcheck disable=SC1090
	. "$FUNCTIONS_FILE"
	patch_apk_empty_feed_indexing "$APK_MAKEFILE"
)

grep -q 'set -- \*\.apk; \\' "$APK_MAKEFILE"
grep -q 'if \[ "\$\$1" = '\''\*\.apk'\'' \]; then \\' "$APK_MAKEFILE"
grep -q '\$\$@; \\' "$APK_MAKEFILE"
grep -q '^[[:space:]]*); \\$' "$APK_MAKEFILE"
awk '
	/^\t\); \\$/ { close_line=NR }
	/^\tfi$/ { fi_line=NR }
	END {
		if (!close_line || !fi_line || fi_line <= close_line) {
			exit 1
		}
	}
' "$APK_MAKEFILE"

SYNTAX_CHECK_SH="$TMPDIR/apk-index-check.sh"
sed -n '/set -- \*\.apk; \\/,/^\tfi$/p' "$APK_MAKEFILE" \
	| sed \
		-e 's/\$(PACKAGE_DIR)/package_dir/g' \
		-e 's/\$(STAGING_DIR_HOST)/staging_dir_host/g' \
		-e 's/\$(TOPDIR)/topdir/g' \
		-e 's/\$(BUILD_KEY)/build_key/g' \
		-e 's/\$\$/\$/g' \
	> "$SYNTAX_CHECK_SH"
bash -n "$SYNTAX_CHECK_SH"

cp "$APK_MAKEFILE" "$TMPDIR/apk-package.mk.once"
(
	package_manager='apk'
	# shellcheck disable=SC1090
	. "$FUNCTIONS_FILE"
	patch_apk_empty_feed_indexing "$APK_MAKEFILE"
)
cmp -s "$APK_MAKEFILE" "$TMPDIR/apk-package.mk.once"

IPK_MAKEFILE="$TMPDIR/ipk-package.mk"
create_makefile "$IPK_MAKEFILE"
cp "$IPK_MAKEFILE" "$TMPDIR/ipk-package.mk.orig"
(
	package_manager='ipk'
	# shellcheck disable=SC1090
	. "$FUNCTIONS_FILE"
	patch_apk_empty_feed_indexing "$IPK_MAKEFILE"
)
cmp -s "$IPK_MAKEFILE" "$TMPDIR/ipk-package.mk.orig"

echo "test_diy_config_apk_index_patch: ok"
