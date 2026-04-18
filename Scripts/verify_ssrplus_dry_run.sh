#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ORGANIZE_SCRIPT="$SCRIPT_DIR/Organize_Packages.sh"
SOURCE_DIR=${1:-}

[ -z "$SOURCE_DIR" ] && echo "Usage: $0 <packages-dir>" >&2 && exit 1
[ ! -d "$SOURCE_DIR" ] && echo "Source directory not found: $SOURCE_DIR" >&2 && exit 1

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

PACKAGE_MAP="$TMPDIR/package_map.tsv"
META_INDEX="$TMPDIR/meta_index.tsv"
STAGED_FEATURES="$TMPDIR/staged_features.txt"
STAGED_PACKAGES="$TMPDIR/staged_packages.txt"
ALL_PACKAGES="$TMPDIR/all_packages.txt"
EXTERNAL_DEPS="$TMPDIR/external_deps.txt"
MISSING_DEPS="$TMPDIR/missing_deps.txt"
STAGE_DIR="$TMPDIR/stage"
SSRPLUS_DIR="$STAGE_DIR/luci-app-ssr-plus"

mkdir -p "$STAGE_DIR"
: > "$PACKAGE_MAP"
: > "$META_INDEX"
: > "$STAGED_FEATURES"
: > "$STAGED_PACKAGES"
: > "$ALL_PACKAGES"
: > "$EXTERNAL_DEPS"
: > "$MISSING_DEPS"

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

normalize_dep_list() {
	normalize_csv_list "$1" | sed 's/ (.*)//'
}

while IFS= read -r package_path; do
	[ -z "$package_path" ] && continue
	package_base=$(basename "$package_path")
	printf '%s\t%s\n' "$package_base" "$package_path" >> "$PACKAGE_MAP"
	: > "$STAGE_DIR/$package_base"

	control_text=$(extract_control "$package_path" || true)
	[ -z "$control_text" ] && continue

	package_name=$(printf '%s\n' "$control_text" | sed -n 's/^Package: //p' | head -n1)
	[ -z "$package_name" ] && continue
	printf 'PACKAGE\t%s\t%s\n' "$package_base" "$package_name" >> "$META_INDEX"
	append_unique "$ALL_PACKAGES" "$package_name"

	provides_line=$(printf '%s\n' "$control_text" | sed -n 's/^Provides: //p' | head -n1)
	while IFS= read -r provide_name; do
		[ -z "$provide_name" ] && continue
		printf 'PROVIDE\t%s\t%s\n' "$package_base" "$provide_name" >> "$META_INDEX"
		append_unique "$ALL_PACKAGES" "$provide_name"
	done <<EOF
$(normalize_csv_list "$provides_line")
EOF

	depends_line=$(printf '%s\n' "$control_text" | sed -n 's/^Depends: //p' | head -n1)
	while IFS= read -r dep_name; do
		[ -z "$dep_name" ] && continue
		printf 'DEPEND\t%s\t%s\n' "$package_name" "$dep_name" >> "$META_INDEX"
	done <<EOF
$(normalize_dep_list "$depends_line")
EOF
done <<EOF
$(find "$SOURCE_DIR" -type f \( -name '*.ipk' -o -name '*.apk' \) | sort)
EOF

SOURCE_COUNT=$(wc -l < "$PACKAGE_MAP" | tr -d ' ')
[ "$SOURCE_COUNT" -eq 0 ] && echo "No .ipk or .apk files found under: $SOURCE_DIR" >&2 && exit 1

bash "$ORGANIZE_SCRIPT" "$STAGE_DIR" >/dev/null
[ ! -d "$SSRPLUS_DIR" ] && echo "Dry run did not produce: $SSRPLUS_DIR" >&2 && exit 1

while IFS= read -r staged_path; do
	[ -z "$staged_path" ] && continue
	staged_base=$(basename "$staged_path")
	append_unique "$STAGED_FEATURES" "$staged_base"

	while IFS=$'\t' read -r _ meta_base meta_value; do
		[ "$meta_base" = "$staged_base" ] || continue
		append_unique "$STAGED_PACKAGES" "$meta_value"
	done <<EOF
$(grep "^PACKAGE	" "$META_INDEX" 2>/dev/null || true)
$(grep "^PROVIDE	" "$META_INDEX" 2>/dev/null || true)
EOF
done <<EOF
$(find "$SSRPLUS_DIR" -maxdepth 1 -type f | sort)
EOF

while IFS= read -r staged_pkg; do
	[ -z "$staged_pkg" ] && continue
	while IFS=$'\t' read -r _ dep_pkg dep_expr; do
		[ "$dep_pkg" = "$staged_pkg" ] || continue

		dep_satisfied=0
		while IFS= read -r dep_option; do
			dep_option=$(printf '%s\n' "$dep_option" | sed 's/^ *//;s/ *$//')
			[ -z "$dep_option" ] && continue
			if grep -Fxq "$dep_option" "$STAGED_PACKAGES" 2>/dev/null; then
				dep_satisfied=1
				break
			fi
		done <<EOF
$(printf '%s\n' "$dep_expr" | tr '|' '\n')
EOF

		[ "$dep_satisfied" -eq 1 ] && continue
		dep_available=0
		while IFS= read -r dep_option; do
			dep_option=$(printf '%s\n' "$dep_option" | sed 's/^ *//;s/ *$//')
			[ -z "$dep_option" ] && continue
			if grep -Fxq "$dep_option" "$ALL_PACKAGES" 2>/dev/null; then
				dep_available=1
				break
			fi
		done <<EOF
$(printf '%s\n' "$dep_expr" | tr '|' '\n')
EOF
		if [ "$dep_available" -eq 1 ]; then
			append_unique "$EXTERNAL_DEPS" "$dep_pkg -> $dep_expr"
		else
			append_unique "$MISSING_DEPS" "$dep_pkg -> $dep_expr"
		fi
	done <<EOF
$(grep "^DEPEND	" "$META_INDEX" 2>/dev/null || true)
EOF
done <<EOF
$(sort -u "$STAGED_PACKAGES")
EOF

echo "Source directory: $SOURCE_DIR"
echo "Staged package files: $SOURCE_COUNT"
echo "SSR Plus directory files: $(wc -l < "$STAGED_FEATURES" | tr -d ' ')"
echo "SSR Plus files:"
sed 's/^/  /' "$STAGED_FEATURES"
echo "Dependency check:"
if [ -s "$EXTERNAL_DEPS" ]; then
	echo "Available in source pool but not bundled into SSR Plus:"
	sed 's/^/  external: /' "$EXTERNAL_DEPS"
fi
if [ -s "$MISSING_DEPS" ]; then
	echo "Not found anywhere in source pool:"
	sed 's/^/  missing: /' "$MISSING_DEPS"
fi
if [ ! -s "$EXTERNAL_DEPS" ] && [ ! -s "$MISSING_DEPS" ]; then
	echo "All direct dependencies satisfied within staged SSR Plus set."
else
	echo "Dependency check complete."
fi
