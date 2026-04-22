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

	if grep -Fq "$pattern" "$workflow_file"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Unexpected pattern: ${pattern}" >&2
		exit 1
	fi
}

assert_contains "OPENWRT_PATH: '/builder/openwrt'" "OPENWRT_PATH should default to /builder/openwrt"
assert_contains "build-mount-path: /builder" "free-disk should mount build space at /builder"
assert_contains 'git clone --depth=1 --single-branch --branch $WRT_REPO_BRANCH $WRT_REPO_URL $OPENWRT_PATH' "source clone should target OPENWRT_PATH directly"
assert_contains 'git clone --depth=1 --single-branch --branch $change_branceh $WRT_REPO_URL $OPENWRT_PATH' "fallback source clone should also target OPENWRT_PATH directly"
assert_not_contains 'git clone --depth=1 --single-branch --branch $WRT_REPO_BRANCH $WRT_REPO_URL openwrt' "workflow should no longer clone into a workspace-local openwrt directory"

echo "test_core_all_builder_mount: ok"
