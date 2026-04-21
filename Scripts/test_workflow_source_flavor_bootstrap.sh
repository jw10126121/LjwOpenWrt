#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

assert_contains() {
	local file="$1"
	local pattern="$2"
	local message="$3"

	if ! grep -Fq "$pattern" "$file"; then
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

	if grep -Fq "$pattern" "$file"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Unexpected pattern: ${pattern}" >&2
		echo "In file: ${file}" >&2
		exit 1
	fi
}

core_all_workflow="${repo_root}/.github/workflows/CORE-ALL.yml"
metadata_workflow="${repo_root}/.github/workflows/TEST-METADATA.yml"

assert_contains "$core_all_workflow" 'SOURCE_FLAVOR_RESOLVER=' "CORE-ALL should export a prepared source flavor resolver path"
assert_contains "$core_all_workflow" "cat > \"\${resolver_path}\" <<'EOF_RESOLVER'" "CORE-ALL should embed a fallback resolver before checkout"
assert_contains "$core_all_workflow" '. "$SOURCE_FLAVOR_RESOLVER"' "CORE-ALL should source the prepared resolver path"
assert_not_contains "$core_all_workflow" 'repo_resolver="$GITHUB_WORKSPACE/Scripts/lib/source_flavor.sh"' "CORE-ALL should not depend on repo helper before checkout"
assert_not_contains "$core_all_workflow" '. "$GITHUB_WORKSPACE/Scripts/lib/source_flavor.sh"' "CORE-ALL should not source the repo helper directly anymore"

assert_contains "$metadata_workflow" 'SOURCE_FLAVOR_RESOLVER=' "TEST-METADATA should export a prepared source flavor resolver path"
assert_contains "$metadata_workflow" 'repo_resolver="$GITHUB_WORKSPACE/Scripts/lib/source_flavor.sh"' "TEST-METADATA should look for the repo helper before falling back"
assert_contains "$metadata_workflow" "cat > \"\${resolver_path}\" <<'EOF_RESOLVER'" "TEST-METADATA should embed a fallback resolver"
assert_contains "$metadata_workflow" '. "$SOURCE_FLAVOR_RESOLVER"' "TEST-METADATA should source the prepared resolver path"
assert_not_contains "$metadata_workflow" '. "$GITHUB_WORKSPACE/Scripts/lib/source_flavor.sh"' "TEST-METADATA should not source the repo helper directly anymore"

echo "test_workflow_source_flavor_bootstrap: ok"
