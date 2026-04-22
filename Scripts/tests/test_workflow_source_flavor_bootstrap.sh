#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

assert_contains() {
	local file="$1"
	local pattern="$2"
	local message="$3"

	if ! grep -Fq -- "$pattern" "$file"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Missing pattern: ${pattern}" >&2
		echo "In file: ${file}" >&2
		exit 1
	fi
}

assert_not_contains() {
	local file="$1"
	local pattern="$2"
	local message="$3"

	if grep -Fq -- "$pattern" "$file"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Unexpected pattern: ${pattern}" >&2
		echo "In file: ${file}" >&2
		exit 1
	fi
}

core_all_workflow="${repo_root}/.github/workflows/CORE-ALL.yml"
metadata_workflow="${repo_root}/.github/workflows/TEST-METADATA.yml"

assert_not_contains "$core_all_workflow" 'SOURCE_FLAVOR_RESOLVER=' "CORE-ALL should not keep a source flavor resolver anymore"
assert_not_contains "$core_all_workflow" '. "$SOURCE_FLAVOR_RESOLVER"' "CORE-ALL should not source a resolver anymore"
assert_not_contains "$core_all_workflow" 'resolve_source_selection(' "CORE-ALL should not keep the resolver function inline"
assert_not_contains "$core_all_workflow" 'Set Timezone (设置时区)' "CORE-ALL should merge timezone setup into initialization"
assert_contains "$core_all_workflow" "sudo timedatectl set-timezone 'Asia/Shanghai'" "CORE-ALL should still set timezone"
assert_not_contains "$core_all_workflow" '- name: Read Variables (读取变量)' "CORE-ALL should not keep standalone metadata read steps"
assert_contains "$core_all_workflow" 'WRT_REPO_URL="https://github.com/coolsnowwolf/lede"' "CORE-ALL should pin the source repo directly"
assert_contains "$core_all_workflow" 'WRT_REPO_BRANCH="master"' "CORE-ALL should pin the source branch directly"

assert_not_contains "$metadata_workflow" 'SOURCE_FLAVOR_RESOLVER=' "TEST-METADATA should not keep a source flavor resolver anymore"
assert_not_contains "$metadata_workflow" '. "$SOURCE_FLAVOR_RESOLVER"' "TEST-METADATA should not source a resolver anymore"
assert_not_contains "$metadata_workflow" 'resolve_source_selection(' "TEST-METADATA should not keep the resolver function inline"
assert_contains "$metadata_workflow" 'WRT_REPO_URL: https://github.com/coolsnowwolf/lede' "TEST-METADATA should pin the source repo directly"
assert_contains "$metadata_workflow" 'WRT_REPO_BRANCH: master' "TEST-METADATA should pin the source branch directly"

echo "test_workflow_source_flavor_bootstrap: ok"
