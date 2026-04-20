#!/bin/bash

resolve_luci_feed_branch() {
	local feeds_file="${1:-./feeds.conf.default}"
	local line
	local branch

	[ -f "${feeds_file}" ] || {
		printf '%s\n' 'unknown'
		return 0
	}

	line=$(grep -E '^[[:space:]]*src-git[[:space:]]+luci[[:space:]]+' "${feeds_file}" | head -n 1)
	[ -n "${line}" ] || {
		printf '%s\n' 'unknown'
		return 0
	}

	branch=$(printf '%s\n' "${line}" | sed -n 's#.*;\([^;[:space:]]*\)[[:space:]]*$#\1#p')
	if [ -n "${branch}" ]; then
		printf '%s\n' "${branch}"
	else
		printf '%s\n' 'default'
	fi
}

is_lean_luci_feed_25_12() {
	[ "$(resolve_luci_feed_branch "${1:-./feeds.conf.default}")" = "openwrt-25.12" ]
}
