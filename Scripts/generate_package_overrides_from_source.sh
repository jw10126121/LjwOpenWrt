#!/bin/bash

# 说明：
# 1. 从 OpenWrt 源码树的 Makefile 元数据生成 Organize_Packages.sh 可消费的覆盖规则。
# 2. 递归解析 LuCI 主包的 DEPENDS / LUCI_DEPENDS，以及 Package/<pkg>/config 里的 select PACKAGE_*。
# 3. 默认只为“主包 + 中文包”之外还存在额外依赖闭包的 luci-app / luci-theme 输出规则。

set -eu

SOURCE_ROOT=${1:-}
CONFIG_PATH=${2:-}
PACKAGE_LIST_PATH=${3:-}
OUTPUT_PATH=${4:-}

[ -z "$SOURCE_ROOT" ] && echo "Usage: $0 <source-root> <config-path> [package-list-path] [output-path]" >&2 && exit 1
[ ! -d "$SOURCE_ROOT" ] && echo "Source root not found: $SOURCE_ROOT" >&2 && exit 1
[ -z "$CONFIG_PATH" ] && echo "Config path is required" >&2 && exit 1
[ ! -f "$CONFIG_PATH" ] && echo "Config file not found: $CONFIG_PATH" >&2 && exit 1
[ -n "$PACKAGE_LIST_PATH" ] && [ ! -f "$PACKAGE_LIST_PATH" ] && echo "Package list not found: $PACKAGE_LIST_PATH" >&2 && exit 1

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

META_FILE="$TMPDIR/meta.tsv"
OUTPUT_FILE=${OUTPUT_PATH:-$TMPDIR/generated_overrides.txt}
PARSED_FILES_FILE="$TMPDIR/parsed_makefiles.txt"
MISSING_PACKAGES_FILE="$TMPDIR/missing_packages.txt"

: > "$META_FILE"
: > "$OUTPUT_FILE"
: > "$PARSED_FILES_FILE"
: > "$MISSING_PACKAGES_FILE"

append_unique() {
	local target_file=$1
	local value=$2

	[ -z "$value" ] && return 0
	grep -Fxq "$value" "$target_file" 2>/dev/null || printf '%s\n' "$value" >> "$target_file"
}

normalize_package_ref() {
	local raw_ref=$1
	local pkg_name=${2:-}

	if [ -n "$pkg_name" ]; then
		raw_ref=${raw_ref//'$(PKG_NAME)'/$pkg_name}
		raw_ref=${raw_ref//'${PKG_NAME}'/$pkg_name}
	fi

	printf '%s\n' "$raw_ref"
}

record_package() {
	local package_name=$1

	[ -z "$package_name" ] && return 0
	printf 'PKG\t%s\n' "$package_name" >> "$META_FILE"
}

record_edge() {
	local package_name=$1
	local dep_name=$2

	[ -z "$package_name" ] && return 0
	[ -z "$dep_name" ] && return 0
	printf 'EDGE\t%s\t%s\n' "$package_name" "$dep_name" >> "$META_FILE"
}

is_base_dependency() {
	case "$1" in
		libc|libgcc1|libpthread|zlib|libstdcpp6|librt|libatomic1|busybox|base-files|kernel)
			return 0
			;;
		lua|uci|ubus|rpcd|cgi-io)
			return 0
			;;
		libubox*|libubus*|libuci*|liblua*|luci-base|luci-compat|luci-lib-*|luci-mod-*|luci-proto-*|rpcd-mod-*|uhttpd|uhttpd-mod-*|procd*|jshn|jsonfilter)
			return 0
			;;
	esac

	return 1
}

extract_dep_names() {
	local dep_blob=$1
	local token cleaned

	for token in $dep_blob; do
		cleaned=$token
		cleaned=${cleaned##*,}
		cleaned=${cleaned#+}
		cleaned=${cleaned#|}
		cleaned=$(printf '%s\n' "$cleaned" | sed 's/([^)]*)//g')
		[ -z "$cleaned" ] && continue

		case "$cleaned" in
			@*|*\%*|*=*|*\<*|*\>*|*\[*|*\]*)
				continue
				;;
		esac
		if printf '%s\n' "$cleaned" | grep -Eq '\$\(|\|\||&&'; then
			continue
		fi

		if printf '%s\n' "$cleaned" | grep -q ':'; then
			cleaned=${cleaned##*:}
		fi

		cleaned=$(printf '%s\n' "$cleaned" | sed 's/^ *//;s/ *$//')
		cleaned=$(printf '%s\n' "$cleaned" | sed 's/^[!+@]*//')
		[ -z "$cleaned" ] && continue
		printf '%s\n' "$cleaned" | grep -q '\$' && continue
		case "$cleaned" in
			*'$('*|*')'*)
				continue
				;;
		esac

		printf '%s\n' "$cleaned"
	done
}

record_dep_blob() {
	local package_name=$1
	local dep_blob=$2
	local dep_name

	record_package "$package_name"
	while IFS= read -r dep_name; do
		[ -z "$dep_name" ] && continue
		record_edge "$package_name" "$dep_name"
	done <<EOF
$(extract_dep_names "$dep_blob")
EOF
}

record_config_selects() {
	local package_name=$1
	local block_content=$2
	local select_target

	record_package "$package_name"
	while IFS= read -r select_target; do
		[ -z "$select_target" ] && continue
		select_target=$(printf '%s\n' "$select_target" | sed 's/^PACKAGE_//')
		record_edge "$package_name" "$select_target"
	done <<EOF
$(printf '%s\n' "$block_content" | awk '
/^[[:space:]]*config[[:space:]]+PACKAGE_/ {
	current = $2
	sub(/^PACKAGE_/, "", current)
	next
}
/^[[:space:]]*config[[:space:]]+/ {
	current = ""
	next
}
/^[[:space:]]*select[[:space:]]+PACKAGE_/ {
	print $2
	next
}
current != "" && /^[[:space:]]*default[[:space:]]+y([[:space:]]|$)/ {
	if (current ~ /-/ || current !~ /_/) {
		print "PACKAGE_" current
	}
}
')
EOF
}

process_package_block() {
	local block_name=$1
	local block_content=$2

	[ -z "$block_name" ] && return 0

	case "$block_name" in
		*/config)
			record_config_selects "${block_name%/config}" "$block_content"
			return 0
			;;
	esac

	record_package "$block_name"
	while IFS= read -r dep_blob; do
		[ -z "$dep_blob" ] && continue
		record_dep_blob "$block_name" "$dep_blob"
	done <<EOF
$(printf '%s\n' "$block_content" | sed -n 's/^[[:space:]]*DEPENDS:=\(.*\)$/\1/p; s/^[[:space:]]*EXTRA_DEPENDS:=\(.*\)$/\1/p')
EOF
}

parse_makefile() {
	local makefile_path=$1
	local normalized_path="$TMPDIR/normalized.mk"
	local pkg_name=''
	local line block_name block_content
	local in_block=0

	awk '
		{
			line = $0
			while (sub(/\\$/, "", line)) {
				if (getline next_line <= 0) {
					break
				}
				sub(/^[[:space:]]+/, "", next_line)
				line = line " " next_line
			}
			print line
		}
	' "$makefile_path" > "$normalized_path"

	while IFS= read -r line || [ -n "$line" ]; do
		if printf '%s\n' "$line" | grep -Eq '^[[:space:]]*PKG_NAME:='; then
			pkg_name=$(printf '%s\n' "$line" | sed 's/^[[:space:]]*PKG_NAME:=//')
		fi

		if [ "$in_block" -eq 1 ]; then
			if [ "$line" = 'endef' ]; then
				process_package_block "$block_name" "$block_content"
				in_block=0
				block_name=''
				block_content=''
				continue
			fi
			block_content="${block_content}${line}
"
			continue
		fi

		if printf '%s\n' "$line" | grep -Eq '^define Package/'; then
			block_name=$(printf '%s\n' "$line" | sed 's/^define Package\///')
			block_name=$(normalize_package_ref "$block_name" "$pkg_name")
			block_content=''
			in_block=1
			continue
		fi

		if printf '%s\n' "$line" | grep -Eq '^[[:space:]]*LUCI_DEPENDS:='; then
			record_dep_blob "$pkg_name" "$(printf '%s\n' "$line" | sed 's/^[[:space:]]*LUCI_DEPENDS:=//')"
		fi
	done < "$normalized_path"
}

get_package_edges() {
	grep -F "$(printf 'EDGE\t%s\t' "$1")" "$META_FILE" 2>/dev/null | cut -f3 | sort -u
}

package_exists() {
	grep -Fqx "$(printf 'PKG\t%s' "$1")" "$META_FILE" 2>/dev/null
}

find_makefile_for_package() {
	local package_name=$1
	local cache_file="$TMPDIR/find_${package_name//\//_}.txt"
	local package_regex

	if [ -f "$cache_file" ]; then
		cat "$cache_file"
		return 0
	fi

	package_regex=$(printf '%s\n' "$package_name" | sed 's/[.[\*^$()+?{|]/\\&/g')
	rg -l -m1 -g 'Makefile' "^[[:space:]]*PKG_NAME:=${package_regex}\$|^define Package/${package_regex}(/config)?\$" "$SOURCE_ROOT" 2>/dev/null | head -n1 > "$cache_file" || true
	if [ ! -s "$cache_file" ]; then
		find "$SOURCE_ROOT" -type f -path "*/${package_name}/Makefile" | head -n1 > "$cache_file" || true
	fi
	cat "$cache_file"
}

ensure_package_loaded() {
	local package_name=$1
	local makefile_path

	package_exists "$package_name" && return 0
	grep -Fxq "$package_name" "$MISSING_PACKAGES_FILE" 2>/dev/null && return 1

	makefile_path=$(find_makefile_for_package "$package_name" || true)
	if [ -z "$makefile_path" ]; then
		append_unique "$MISSING_PACKAGES_FILE" "$package_name"
		return 1
	fi

	if ! grep -Fxq "$makefile_path" "$PARSED_FILES_FILE" 2>/dev/null; then
		parse_makefile "$makefile_path"
		append_unique "$PARSED_FILES_FILE" "$makefile_path"
	fi

	package_exists "$package_name"
}

iter_root_packages() {
	if [ -n "$PACKAGE_LIST_PATH" ]; then
		sed '/^$/d' "$PACKAGE_LIST_PATH"
		return 0
	fi

	grep -E '^CONFIG_PACKAGE_luci-(app|theme)-.*=[my]$' "$CONFIG_PATH" | sed 's/^CONFIG_PACKAGE_//' | sed 's/=[my]$//'
}

while IFS= read -r root_pkg; do
	[ -z "$root_pkg" ] && continue
	case "$root_pkg" in
		luci-app-*|luci-theme-*)
			;;
		*)
			continue
			;;
	esac

	ensure_package_loaded "$root_pkg" || continue

	if printf '%s\n' "$root_pkg" | grep -q '^luci-app-'; then
		i18n_pkg="luci-i18n-${root_pkg#luci-app-}-zh-cn"
	else
		i18n_pkg="luci-i18n-${root_pkg#luci-theme-}-zh-cn"
	fi

	queue_file="$TMPDIR/queue_${root_pkg//\//_}.txt"
	seen_file="$TMPDIR/seen_${root_pkg//\//_}.txt"
	prefixes_file="$TMPDIR/prefixes_${root_pkg//\//_}.txt"
	: > "$queue_file"
	: > "$seen_file"
	: > "$prefixes_file"

	append_unique "$queue_file" "$root_pkg"
	append_unique "$seen_file" "$root_pkg"
	append_unique "$prefixes_file" "${root_pkg}_"
	append_unique "$prefixes_file" "${i18n_pkg}_"

	queue_index=1
	queue_count=$(wc -l < "$queue_file" | tr -d ' ')
	while [ "$queue_index" -le "$queue_count" ]; do
		current_pkg=$(sed -n "${queue_index}p" "$queue_file")
		queue_index=$((queue_index + 1))
		[ -z "$current_pkg" ] && continue

		while IFS= read -r dep_pkg; do
			[ -z "$dep_pkg" ] && continue
			is_base_dependency "$dep_pkg" && continue

			append_unique "$prefixes_file" "${dep_pkg}_"

			if ensure_package_loaded "$dep_pkg" && ! grep -Fxq "$dep_pkg" "$seen_file" 2>/dev/null; then
				append_unique "$seen_file" "$dep_pkg"
				append_unique "$queue_file" "$dep_pkg"
				queue_count=$(wc -l < "$queue_file" | tr -d ' ')
			fi
		done <<EOF
$(get_package_edges "$current_pkg")
EOF
	done

	prefix_count=$(wc -l < "$prefixes_file" | tr -d ' ')
	[ "$prefix_count" -le 2 ] && continue

	printf '%s|' "$root_pkg" >> "$OUTPUT_FILE"
	tr '\n' ' ' < "$prefixes_file" | sed 's/ *$//' >> "$OUTPUT_FILE"
	printf '\n' >> "$OUTPUT_FILE"
done <<EOF
$(iter_root_packages)
EOF

if [ -z "${OUTPUT_PATH:-}" ]; then
	cat "$OUTPUT_FILE"
fi
