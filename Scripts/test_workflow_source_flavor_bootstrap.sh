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

for workflow in \
	"${repo_root}/.github/workflows/CORE-ALL.yml" \
	"${repo_root}/.github/workflows/TEST-METADATA.yml"
do
	assert_contains "$workflow" 'SOURCE_FLAVOR_RESOLVER=' "workflow should export a prepared source flavor resolver path"
	assert_contains "$workflow" 'repo_resolver="$GITHUB_WORKSPACE/Scripts/lib/source_flavor.sh"' "workflow should look for the repo helper before falling back"
	assert_contains "$workflow" "cat > \"\${resolver_path}\" <<'EOF_RESOLVER'" "workflow should embed a fallback resolver"
	assert_contains "$workflow" '. "$SOURCE_FLAVOR_RESOLVER"' "workflow should source the prepared resolver path"
	assert_not_contains "$workflow" '. "$GITHUB_WORKSPACE/Scripts/lib/source_flavor.sh"' "workflow should not source the repo helper directly anymore"
done

echo "test_workflow_source_flavor_bootstrap: ok"
