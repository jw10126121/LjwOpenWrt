#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
workflow_file="${repo_root}/.github/workflows/CORE-ALL.yml"

assert_contains() {
	local pattern="$1"
	local message="$2"

	if ! grep -Fq -- "$pattern" "$workflow_file"; then
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

assert_toolchain_has_no_restore_keys() {
	if awk '/Restore Toolchain Cache/,/Restore ccache Cache/' "$workflow_file" | grep -Fq -- 'restore-keys:'; then
		echo "ASSERT FAILED: toolchain cache should not restore older prefixes" >&2
		exit 1
	fi
}

assert_contains '- name: Restore Toolchain Cache' "workflow should restore toolchain cache explicitly"
assert_contains 'uses: actions/cache/restore@v5' "workflow should use cache restore actions"
assert_contains '- name: Save Toolchain Cache' "workflow should save toolchain cache explicitly"
assert_contains 'uses: actions/cache/save@v5' "workflow should use cache save actions"
assert_contains 'key: toolchain-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}-${{ env.REPO_GIT_hash_simple }}' "toolchain cache key should still include the source commit hash"
assert_toolchain_has_no_restore_keys

assert_contains '- name: Restore ccache Cache' "workflow should restore ccache explicitly"
assert_contains '- name: Save ccache Cache' "workflow should save ccache explicitly"
assert_contains 'key: ccache-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}' "ccache key should no longer include commit hash"
assert_contains 'restore-keys: |' "ccache restore step should still keep restore-keys"
assert_contains 'ccache-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}-' "ccache restore prefix should remain unchanged"

assert_contains '- name: Cache Diagnostics After Restore' "workflow should log cache state after restore"
assert_contains '- name: Cache Diagnostics Before Save' "workflow should log cache state before save"
assert_contains '- name: Initialize Build Observability' "workflow should initialize build timing observability"
assert_contains 'echo "PREP_STAGE_START_TS=$(date +%s)" >> "$GITHUB_ENV"' "workflow should record the prep stage start timestamp"
assert_contains '- name: Report ccache Stats Before Build' "workflow should print ccache stats before compilation"
assert_contains '- name: Report ccache Stats After Build' "workflow should print ccache stats after compilation"
assert_contains 'ccache -s || true' "workflow should tolerate ccache stats collection failures"
assert_contains '【Lin】prep stage duration:' "workflow should log prep stage duration"
assert_contains '【Lin】download stage duration:' "workflow should log download stage duration"
assert_contains '【Lin】compile stage duration:' "workflow should log compile stage duration"
assert_not_contains '- name: Restore dl Cache' "workflow should not introduce dl cache in this change"
assert_not_contains '- name: Save dl Cache' "workflow should not introduce dl cache in this change"

echo "test_workflow_cache_keys: ok"
