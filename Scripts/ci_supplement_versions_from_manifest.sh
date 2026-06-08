#!/bin/bash
# 说明：
# 编译后从 manifest 文件中读取包版本号，补充到 upload/ 下的 readme/config 文件中。
# readme.sh 在编译前运行，部分包的版本号可能缺失；manifest 包含实际编译的版本信息。

set -euo pipefail

upload_dir="${OPENWRT_PATH:?OPENWRT_PATH is required}/upload"

# 找到 manifest 文件（通常只有一个）
manifest_file=$(find "${upload_dir}" -maxdepth 1 -type f -iname "*manifest*" | head -n1)
if [ -z "${manifest_file}" ]; then
    echo "【Lin】未找到 manifest 文件，跳过版本补充"
    exit 0
fi

echo "【Lin】读取 manifest: ${manifest_file}"

# 解析 manifest 为关联数组：包名 -> 版本
declare -A pkg_versions
while IFS= read -r line; do
    # 跳过空行
    [ -z "${line}" ] && continue
    # 格式：package_name - version
    pkg_name=$(printf '%s' "${line}" | sed 's/ - .*$//')
    pkg_version=$(printf '%s' "${line}" | sed 's/^.* - //')
    [ -n "${pkg_name}" ] && [ -n "${pkg_version}" ] && pkg_versions["${pkg_name}"]="${pkg_version}"
done < "${manifest_file}"

echo "【Lin】manifest 中共 ${#pkg_versions[@]} 个包"

# 扫描 upload/ 下的 readme 和 config 文件，补充缺失版本号
supplemented=0
for target_file in "${upload_dir}"/readme_*.txt "${upload_dir}"/config_*.txt; do
    [ -f "${target_file}" ] || continue

    tmp_file=$(mktemp)
    while IFS= read -r line; do
        # 跳过空行、标题行、分隔线、HTML 标签、已有版本号（含括号）的行
        if [ -z "${line}" ] \
            || printf '%s' "${line}" | grep -qE '^#{1,4} ' \
            || printf '%s' "${line}" | grep -qE '^---' \
            || printf '%s' "${line}" | grep -qE '^<' \
            || printf '%s' "${line}" | grep -qE ' \(' \
            || printf '%s' "${line}" | grep -qE '编译说明|其他说明|集成的|安装包|支持目标|配置组织|Overlay|固件默认|下载与源码|刷机说明'; then
            printf '%s\n' "${line}" >> "${tmp_file}"
            continue
        fi

        # 行内容就是纯包名（如 luci-app-ssr-plus），尝试查找版本
        trimmed=$(printf '%s' "${line}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        if [ -n "${pkg_versions[${trimmed}]+_}" ]; then
            printf '%s (%s)\n' "${line}" "${pkg_versions[${trimmed}]}" >> "${tmp_file}"
            supplemented=$((supplemented + 1))
        else
            printf '%s\n' "${line}" >> "${tmp_file}"
        fi
    done < "${target_file}"

    mv -f "${tmp_file}" "${target_file}"
done

echo "【Lin】从 manifest 补充了 ${supplemented} 个包的版本号"
