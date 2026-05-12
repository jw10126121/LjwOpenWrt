#!/bin/bash

normalize_overlay_name() {
	local overlay_name=${1:-}

	printf '%s' "$overlay_name" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

resolve_overlay_file() {
	local config_root=$1
	local overlay_name=$2

	printf '%s/overlays/%s.txt\n' "$config_root" "$(printf '%s' "$overlay_name" | tr '[:lower:]' '[:upper:]')"
}

read_overlay_group() {
	local overlay_file=$1
	local overlay_group

	overlay_group=$(sed -n 's/^#[[:space:]]*OVERLAY_GROUP[[:space:]]*=[[:space:]]*\([^[:space:]]\{1,\}\)[[:space:]]*$/\1/p' "$overlay_file" | sed -n '1p')
	printf '%s' "$overlay_group" | tr '[:upper:]' '[:lower:]'
}

normalize_overlay_list() {
	local config_root=$1
	local overlay_csv=${2:-}
	local old_ifs overlay_name overlay_file overlay_group existing_name existing_group joined_list
	local i
	local -a normalized_names=()
	local -a normalized_groups=()
	local -a kept_names=()
	local -a kept_groups=()

	[ -n "$overlay_csv" ] || {
		printf '\n'
		return 0
	}

	old_ifs=$IFS
	IFS=','
	set -- $overlay_csv
	IFS=$old_ifs

	for overlay_name in "$@"; do
		overlay_name=$(normalize_overlay_name "$overlay_name")
		[ -n "$overlay_name" ] || continue

		overlay_file=$(resolve_overlay_file "$config_root" "$overlay_name")
		if [ ! -f "$overlay_file" ]; then
			echo "缺少 overlay 配置：$overlay_file" >&2
			return 1
		fi

		overlay_group=$(read_overlay_group "$overlay_file")
		if [ -n "$overlay_group" ]; then
			kept_names=()
			kept_groups=()
			i=0
			if [ ${#normalized_names[@]} -gt 0 ]; then
				for existing_name in "${normalized_names[@]}"; do
					existing_group=${normalized_groups[$i]}
					if [ "$existing_group" != "$overlay_group" ]; then
						kept_names+=("$existing_name")
						kept_groups+=("$existing_group")
					fi
					i=$((i + 1))
				done
			fi
			if [ ${#kept_names[@]} -gt 0 ]; then
				normalized_names=("${kept_names[@]}")
				normalized_groups=("${kept_groups[@]}")
			else
				normalized_names=()
				normalized_groups=()
			fi
		fi

		normalized_names+=("$overlay_name")
		normalized_groups+=("$overlay_group")
	done

	joined_list=''
	if [ ${#normalized_names[@]} -gt 0 ]; then
		for overlay_name in "${normalized_names[@]}"; do
			if [ -n "$joined_list" ]; then
				joined_list="${joined_list},${overlay_name}"
			else
				joined_list=$overlay_name
			fi
		done
	fi

	printf '%s\n' "$joined_list"
}
