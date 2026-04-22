#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
core_workflow="${repo_root}/.github/workflows/CORE-ALL.yml"

assert_contains() {
	local file="$1"
	local pattern="$2"
	local message="$3"

	if ! grep -Fq "$pattern" "$file"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Missing pattern: ${pattern}" >&2
		exit 1
	fi
}

assert_not_contains() {
	local file="$1"
	local pattern="$2"
	local message="$3"

	if grep -Fq "$pattern" "$file"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Unexpected pattern: ${pattern}" >&2
		exit 1
	fi
}

for workflow in \
	"${repo_root}/.github/workflows/CORE-ALL.yml" \
	"${repo_root}/.github/workflows/main.yml" \
	"${repo_root}/.github/workflows/TEST-METADATA.yml" \
	"${repo_root}/.github/workflows/TEST-ORGANIZE.yml" \
	"${repo_root}/.github/workflows/TEST-NOTIFY.yml"
do
	assert_contains "$workflow" "runs-on: ubuntu-24.04" "$(basename "$workflow") should run on ubuntu-24.04"
	assert_not_contains "$workflow" "runs-on: ubuntu-22.04" "$(basename "$workflow") should no longer use ubuntu-22.04"
done

assert_contains "$core_workflow" "uses: sbwml/actions@openwrt-build-setup" "CORE-ALL should use sbwml build setup on ubuntu-24.04"
assert_contains "$core_workflow" "sudo timedatectl set-timezone 'Asia/Shanghai'" "CORE-ALL should set timezone to Asia/Shanghai explicitly"
assert_contains "$core_workflow" "uses: sbwml/actions@install-llvm" "CORE-ALL should wire in the optional LLVM setup step"
assert_contains "$core_workflow" "if: env.INSTALL_LLVM == 'true'" "LLVM setup should stay optional behind INSTALL_LLVM"

echo "test_workflow_ubuntu24_setup: ok"
