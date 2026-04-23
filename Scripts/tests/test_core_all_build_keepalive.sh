#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
workflow_file="${repo_root}/.github/workflows/CORE-ALL.yml"

assert_not_contains() {
	local pattern="$1"
	local message="$2"

	if grep -Fq "$pattern" "$workflow_file"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Unexpected pattern: ${pattern}" >&2
		exit 1
	fi
}

assert_contains() {
	local pattern="$1"
	local message="$2"

	if ! grep -Fq "$pattern" "$workflow_file"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Missing pattern: ${pattern}" >&2
		exit 1
	fi
}

assert_not_contains 'run_build_with_keepalive() {' "compile step should no longer define the keepalive wrapper"
assert_not_contains 'KEEPALIVE_PID=$!' "compile step should not track a keepalive background process"
assert_not_contains 'echo "【Lin】编译仍在进行中：$(date' "compile step should not emit heartbeat logs during make"
assert_contains 'make -j"$(nproc)" || make -j1 V=s' "compile step should call make directly again"

echo "test_core_all_build_keepalive: ok"
