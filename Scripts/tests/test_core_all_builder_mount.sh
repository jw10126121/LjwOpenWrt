#!/bin/bash

set -euo pipefail

workflow_file=".github/workflows/CORE-ALL.yml"

assert_contains() {
	local pattern="$1"
	local message="$2"

	if ! grep -Fq "$pattern" "$workflow_file"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Missing pattern: ${pattern}" >&2
		exit 1
	fi
}

assert_not_contains() {
	local pattern="$1"
	local message="$2"

	if grep -Fq -- "$pattern" "$workflow_file"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Unexpected pattern: ${pattern}" >&2
		exit 1
	fi
}

assert_contains "OPENWRT_PATH: '/builder/openwrt'" "OPENWRT_PATH should default to /builder/openwrt"
assert_contains "build-mount-path: /builder" "free-disk should mount build space at /builder"
assert_contains 'git clone --depth=1 --single-branch --branch "$WRT_REPO_BRANCH" "$WRT_REPO_URL" "$OPENWRT_PATH"' "source clone should target OPENWRT_PATH directly"
assert_not_contains 'git clone --depth=1 --single-branch --branch "$WRT_REPO_BRANCH" "$WRT_REPO_URL" openwrt' "workflow should no longer clone into a workspace-local openwrt directory"
assert_not_contains '- name: config git (修改git下载缓冲大小)' "workflow should remove the legacy git buffer tuning step"
assert_not_contains 'http.postBuffer 524288000' "workflow should not override git http.postBuffer anymore"
assert_not_contains 'change_branceh=' "workflow should not keep the legacy branch fallback variable"

echo "test_core_all_builder_mount: ok"
