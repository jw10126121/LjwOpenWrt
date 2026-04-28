#!/bin/bash

# 说明：约束 LuCI 中文语言包与对应主包写在同一份配置文件中，
# 且配置值保持一致，避免主包与语言包分散在不同层级里维护。

set -eu

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$REPO_ROOT"

python3 - <<'PY'
import pathlib
import re
import sys

root = pathlib.Path("Config")
pattern_pkg = re.compile(r'^CONFIG_PACKAGE_([A-Za-z0-9+._-]+)=(y|m|n)(?:\s+#.*)?$', re.M)
pattern_i18n = re.compile(r'^CONFIG_PACKAGE_luci-i18n-([A-Za-z0-9+._-]+)-zh-cn=(y|m|n)(?:\s+#.*)?$', re.M)

special_candidates = {
    "base": ["luci-base"],
}

errors = []

for path in sorted(root.rglob("*.txt")):
    if path.name.endswith("_full.txt"):
        continue

    packages = {}
    for line in path.read_text().splitlines():
        m = pattern_pkg.match(line.strip())
        if m:
            packages[m.group(1)] = m.group(2)

    for name, value in pattern_i18n.findall(path.read_text()):
        candidates = special_candidates.get(name, [f"luci-app-{name}", f"luci-theme-{name}"])
        matched = [(candidate, packages[candidate]) for candidate in candidates if candidate in packages]
        if not matched:
            errors.append(f"{path}: luci-i18n-{name}-zh-cn 缺少同文件主包配置")
            continue
        candidate, pkg_value = matched[0]
        if pkg_value != value:
            errors.append(
                f"{path}: luci-i18n-{name}-zh-cn={value} 与 {candidate}={pkg_value} 不一致"
            )

if errors:
    for item in errors:
        print(item, file=sys.stderr)
    sys.exit(1)

print("test_luci_i18n_collocation: ok")
PY
