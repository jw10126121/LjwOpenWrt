#!/bin/bash

set -eu

PACKAGE_DIR=${1:-}
CONFIG_PATH=${2:-}
OUTPUT_PATH=${3:-}

[ -z "$PACKAGE_DIR" ] && echo "Usage: $0 <packages-dir> <config-path> [output-path]" >&2 && exit 1
[ ! -d "$PACKAGE_DIR" ] && echo "Packages directory not found: $PACKAGE_DIR" >&2 && exit 1
[ -z "$CONFIG_PATH" ] && echo "Config path is required" >&2 && exit 1
[ ! -f "$CONFIG_PATH" ] && echo "Config file not found: $CONFIG_PATH" >&2 && exit 1

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

META_FILE="$TMPDIR/meta.tsv"
OUTPUT_FILE=${OUTPUT_PATH:-$TMPDIR/generated_overrides.txt}

: > "$META_FILE"
: > "$OUTPUT_FILE"

extract_control() {
	local package_path=$1
	tar -xOf "$package_path" ./control.tar.gz 2>/dev/null | tar -xzO ./control 2>/dev/null
}

append_unique() {
	local target_file=$1
	local value=$2
	[ -z "$value" ] && return 0
	grep -Fxq "$value" "$target_file" 2>/dev/null || printf '%s\n' "$value" >> "$target_file"
}

normalize_csv_list() {
	printf '%s\n' "$1" | tr ',' '\n' | sed 's/^ *//;s/ *$//' | sed '/^$/d'
}

normalize_dep_expr() {
	printf '%s\n' "$1" | sed 's/ (.*//g' | sed 's/^ *//;s/ *$//'
}

get_pkg_basename() {
	awk -F'\t' -v pkg="$1" '$1=="PKG" && $2==pkg { print $3; exit }' "$META_FILE"
}

get_provide_basename() {
	awk -F'\t' -v pkg="$1" '$1=="PROVIDE" && $2==pkg { print $3; exit }' "$META_FILE"
}

get_pkg_name_by_basename() {
	awk -F'\t' -v base="$1" '$1=="PKG" && $3==base { print $2; exit }' "$META_FILE"
}

get_dep_exprs() {
	awk -F'\t' -v pkg="$1" '$1=="DEP" && $2==pkg { print $3 }' "$META_FILE"
}

get_prefix_from_basename() {
	local basename_noext=${1%.*}
	printf '%s_\n' "${basename_noext%%_*}"
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

resolve_dep_basename() {
	local dep_expr=$1
	local dep_option

	while IFS= read -r dep_option; do
		dep_option=$(normalize_dep_expr "$dep_option")
		[ -z "$dep_option" ] && continue
		is_base_dependency "$dep_option" && continue

		resolved=$(get_pkg_basename "$dep_option" || true)
		[ -n "$resolved" ] && printf '%s\n' "$resolved" && return 0

		resolved=$(get_provide_basename "$dep_option" || true)
		[ -n "$resolved" ] && printf '%s\n' "$resolved" && return 0
	done <<EOF
$(printf '%s\n' "$dep_expr" | tr '|' '\n')
EOF

	return 1
}

while IFS= read -r package_path; do
	[ -z "$package_path" ] && continue
	package_base=$(basename "$package_path")
	control_text=$(extract_control "$package_path" || true)
	[ -z "$control_text" ] && continue

	package_name=$(printf '%s\n' "$control_text" | sed -n 's/^Package: //p' | head -n1)
	[ -z "$package_name" ] && continue
	printf 'PKG\t%s\t%s\n' "$package_name" "$package_base" >> "$META_FILE"

	provides_line=$(printf '%s\n' "$control_text" | sed -n 's/^Provides: //p' | head -n1)
	while IFS= read -r provide_name; do
		[ -z "$provide_name" ] && continue
		printf 'PROVIDE\t%s\t%s\n' "$provide_name" "$package_base" >> "$META_FILE"
	done <<EOF
$(normalize_csv_list "$provides_line")
EOF

	depends_line=$(printf '%s\n' "$control_text" | sed -n 's/^Depends: //p' | head -n1)
	while IFS= read -r dep_expr; do
		dep_expr=$(normalize_dep_expr "$dep_expr")
		[ -z "$dep_expr" ] && continue
		printf 'DEP\t%s\t%s\n' "$package_name" "$dep_expr" >> "$META_FILE"
	done <<EOF
$(normalize_csv_list "$depends_line")
EOF
done <<EOF
$(find "$PACKAGE_DIR" -maxdepth 1 -type f \( -name '*.ipk' -o -name '*.apk' \) | sort)
EOF

grep -E '^CONFIG_PACKAGE_luci-(app|theme)-.*=[my]$' "$CONFIG_PATH" | \
sed 's/^CONFIG_PACKAGE_//' | \
sed 's/=[my]$//' | \
sort -u | while IFS= read -r package_name; do
	[ -z "$package_name" ] && continue
	main_basename=$(get_pkg_basename "$package_name" || true)
	[ -z "$main_basename" ] && continue

	if echo "$package_name" | grep -q '^luci-app-'; then
		package_suffix=${package_name#luci-app-}
	else
		package_suffix=${package_name#luci-theme-}
	fi

	i18n_name="luci-i18n-${package_suffix}-zh-cn"
	i18n_basename=$(get_pkg_basename "$i18n_name" || true)

	queue_file="$TMPDIR/queue_${package_name//\//_}.txt"
	seen_file="$TMPDIR/seen_${package_name//\//_}.txt"
	prefixes_file="$TMPDIR/prefixes_${package_name//\//_}.txt"
	: > "$queue_file"
	: > "$seen_file"
	: > "$prefixes_file"

	append_unique "$queue_file" "$package_name"
	append_unique "$seen_file" "$package_name"
	append_unique "$prefixes_file" "$(get_prefix_from_basename "$main_basename")"
	if [ -n "$i18n_basename" ]; then
		append_unique "$prefixes_file" "$(get_prefix_from_basename "$i18n_basename")"
	fi

	queue_index=1
	queue_count=$(wc -l < "$queue_file" | tr -d ' ')
	while [ "$queue_index" -le "$queue_count" ]; do
		current_pkg=$(sed -n "${queue_index}p" "$queue_file")
		queue_index=$((queue_index + 1))
		[ -z "$current_pkg" ] && continue
		[ -z "$current_pkg" ] && continue
		while IFS= read -r dep_expr; do
			[ -z "$dep_expr" ] && continue
			dep_basename=$(resolve_dep_basename "$dep_expr" || true)
			[ -z "$dep_basename" ] && continue
			dep_pkg=$(get_pkg_name_by_basename "$dep_basename" || true)
			[ -z "$dep_pkg" ] && continue
			dep_prefix=$(get_prefix_from_basename "$dep_basename")
			append_unique "$prefixes_file" "$dep_prefix"
			if ! grep -Fxq "$dep_pkg" "$seen_file" 2>/dev/null; then
				append_unique "$seen_file" "$dep_pkg"
				append_unique "$queue_file" "$dep_pkg"
				queue_count=$(wc -l < "$queue_file" | tr -d ' ')
			fi
		done <<EOF
$(get_dep_exprs "$current_pkg")
EOF
	done

	prefix_count=$(wc -l < "$prefixes_file" | tr -d ' ')
	[ "$prefix_count" -le 2 ] && continue

	printf '%s|' "$package_name" >> "$OUTPUT_FILE"
	tr '\n' ' ' < "$prefixes_file" | sed 's/ *$//' >> "$OUTPUT_FILE"
	printf '\n' >> "$OUTPUT_FILE"
done

if [ -z "${OUTPUT_PATH:-}" ]; then
	cat "$OUTPUT_FILE"
fi
