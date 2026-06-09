#!/bin/bash

# 说明：manifest 里有实际编译出来的包版本号，应补到 artifact readme、
# 通知 readme 和 release notes 中缺失版本的插件行，并保留 release 的 <br>。

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
target_script="${repo_root}/Scripts/ci_supplement_versions_from_manifest.sh"

TMPDIR="$(mktemp -d)"
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

OPENWRT_PATH="$TMPDIR/openwrt"
mkdir -p "$OPENWRT_PATH/upload" "$OPENWRT_PATH/config_mine"

cat > "$OPENWRT_PATH/upload/test.manifest" <<'EOF'
luci-app-accesscontrol - 1.0.1
luci-app-adguardhome - 2026.06.09
luci-app-ddns - 2.3.4
EOF

cat > "$OPENWRT_PATH/upload/readme_test.txt" <<'EOF'
#### --- 集成的插件 --- ####
luci-app-accesscontrol (1.0.1)
luci-app-adguardhome
EOF

cat > "$OPENWRT_PATH/config_mine/readme.txt" <<'EOF'
#### --- 集成的插件 --- ####
luci-app-accesscontrol (1.0.1)
luci-app-adguardhome
EOF

cat > "$OPENWRT_PATH/readme_release.txt" <<'EOF'
<details><summary>--- 集成的插件 ---</summary>
luci-app-accesscontrol (1.0.1)<br>
luci-app-adguardhome<br>
</details>

<details><summary>--- 安装包插件 ---</summary>
luci-app-ddns<br>
</details>
EOF

OPENWRT_PATH="$OPENWRT_PATH" bash "$target_script" >/dev/null

grep -q '^luci-app-accesscontrol (1.0.1)$' "$OPENWRT_PATH/upload/readme_test.txt"
grep -q '^luci-app-adguardhome (2026.06.09)$' "$OPENWRT_PATH/upload/readme_test.txt"

grep -q '^luci-app-accesscontrol (1.0.1)$' "$OPENWRT_PATH/config_mine/readme.txt"
grep -q '^luci-app-adguardhome (2026.06.09)$' "$OPENWRT_PATH/config_mine/readme.txt"

grep -q '^luci-app-accesscontrol (1.0.1)<br>$' "$OPENWRT_PATH/readme_release.txt"
grep -q '^luci-app-adguardhome (2026.06.09)<br>$' "$OPENWRT_PATH/readme_release.txt"
grep -q '^luci-app-ddns (2.3.4)<br>$' "$OPENWRT_PATH/readme_release.txt"

echo "test_ci_supplement_versions_from_manifest: ok"
