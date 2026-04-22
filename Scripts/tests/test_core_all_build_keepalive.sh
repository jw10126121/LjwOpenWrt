#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
workflow_file="${repo_root}/.github/workflows/CORE-ALL.yml"

assert_contains() {
	local pattern="$1"
	local message="$2"

	if ! grep -Fq "$pattern" "$workflow_file"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Missing pattern: ${pattern}" >&2
		exit 1
	fi
}

assert_contains 'KEEPALIVE_PID=$!' "compile step should track the keepalive background process"
assert_contains 'while kill -0 "$BUILD_PID" >/dev/null 2>&1; do' "compile step should emit periodic logs while make is running"
assert_contains 'echo "【Lin】编译仍在进行中：$(date' "compile step should print periodic heartbeat logs"
assert_contains 'wait "$BUILD_PID"' "compile step should return the build status after heartbeat logging"

echo "test_core_all_build_keepalive: ok"
