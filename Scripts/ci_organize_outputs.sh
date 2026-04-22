#!/bin/bash
# 说明：
# 1. 在 CI 末尾整理编译产物、README、配置文件和安装包归档。
# 2. 会调用 readme.sh 与 Organize_Packages.sh 生成最终上传目录。

set -euo pipefail

# 这些路径都由 GitHub Actions 在运行时注入。
# openwrt_path 指向真正的 OpenWrt 源码工作目录；
# scripts_dir 指向当前仓库里的 Scripts 目录，方便复用仓库脚本。
openwrt_path="${OPENWRT_PATH:?OPENWRT_PATH is required}"
scripts_dir="${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}/${WRT_DIR_SCRIPTS:?WRT_DIR_SCRIPTS is required}"

cd "${openwrt_path}"
# upload/ 是最终给 artifact / release 使用的统一出口目录：
# - configs/ 保留配置类文件
# - packages/ 只是中间过程目录，后面会清理掉
mkdir -p ./upload ./upload/packages ./upload/configs

# 先删除旧的 readme.txt，避免本次生成结果与上一次残留混在一起。
rm -f ./config_mine/readme.txt
readme_script="${scripts_dir}/readme.sh"
[ -f "${readme_script}" ] && chmod +x "${readme_script}"

# system_content 由前序元数据步骤生成，包含源码风味、FW、FRP、设备等摘要信息。
# 这里把它作为 readme.sh 的“系统说明正文”输入。
to_my_say_detail="${system_content:-}"

# 生成两份说明文件：
# 1. config_mine/readme.txt：面向 artifact / 本地查看的普通文本版；
# 2. readme_release.txt：面向 GitHub Release 的发布说明版。
[ -f "${readme_script}" ] && bash "${readme_script}" -c "./.config" -o "./config_mine/readme.txt" -s "${to_my_say_detail}" -a "${WRT_MINE_SAY:-}" -r 'false'
[ -f "${readme_script}" ] && bash "${readme_script}" -c "./.config" -o "./readme_release.txt" -s "${to_my_say_detail}" -a "${WRT_MINE_SAY:-}" -r 'true'

readme_desc_file="${openwrt_path}/config_mine/readme.txt"
release_desc_file="${openwrt_path}/readme_release.txt"

# build_name_prefix 是所有导出文件共享的命名前缀。
# 调整为“平台 / 设备 / 源码风味+FW+FRP / 版本 / 编译开始时间”，
# 让同平台同设备的产物在目录和发布页里更容易聚在一起。
build_name_prefix="${DEVICE_SUBTARGET:?DEVICE_SUBTARGET is required}_${DEVICE_NAME_LIST_LIAN:?DEVICE_NAME_LIST_LIAN is required}_${BUILD_VARIANT_TAG:?BUILD_VARIANT_TAG is required}_${WRT_VER:?WRT_VER is required}_${START_TIME:?START_TIME is required}"

# 导出配置说明与 README 到 upload/ 根目录。
cp -f ./my_config.txt "./upload/config_${build_name_prefix}.txt"
cp -f "${readme_desc_file}" "./upload/readme_${build_name_prefix}.txt"

tmp_dir="$(mktemp -d)"
# 先把分散在 bin/ 下的所有 ipk/apk 收拢到临时目录，再统一重组和压缩。
find ./bin/packages/ -type f \( -name "*.ipk" -o -name "*.apk" \) -exec mv -f {} "${tmp_dir}" \;
find ./bin/targets/ -type f \( -name "*.ipk" -o -name "*.apk" \) -exec mv -f {} "${tmp_dir}" \;
find ./bin/targets/ -iregex ".*\(buildinfo\|json\|manifest\|sha256sums\|packages\)$" -exec rm -rf {} +
find ./bin/targets/ -iregex ".*\(initramfs-uImage\).*" -exec rm -rf {} +
find ./bin/targets/ -iregex ".*\(-imagebuilder-\).*" -exec rm -rf {} +

# 按手工维护的包分组规则整理安装包目录，再打成一个压缩包给用户下载。
# 这里保留压缩包而不是原始目录，是为了减少 artifact / release 中文件数量。
bash "${scripts_dir}/Organize_Packages.sh" "${tmp_dir}" "./.config"
tar -zcf "./upload/Packages_${build_name_prefix}.tar.gz" -C "${tmp_dir}" --transform 's,^./,,' .
rm -rf "${tmp_dir}"
rm -rf ./upload/packages

# 固件镜像文件按“子平台_设备名_源码风味_FW_FRP_版本_开始时间”重命名，方便发布页辨认。
# type 来自 DEVICE_NAME_LIST，例如 cmiot_ax18 / glinet_gl-mt6000。
# 对每个设备，扫描 bin/targets 下属于该设备的镜像文件并统一改名后放进 upload/。
for type in ${DEVICE_NAME_LIST:-}; do
    while IFS= read -r file; do
        [ -z "${file}" ] && continue

        # 保留原始扩展名，例如 bin / img.gz / itb。
        ext="$(basename "${file}" | cut -d '.' -f 2-)"
        # 从原始文件名中提取“设备名起始后的剩余主体”，
        # 例如 cmiot_ax18-squashfs-sysupgrade，用于保留镜像种类信息。
        name="$(basename "${file}" | cut -d '.' -f 1 | grep -io "\(${type}\).*")"
        new_file="${DEVICE_SUBTARGET:?DEVICE_SUBTARGET is required}_${name}_${BUILD_VARIANT_TAG:?BUILD_VARIANT_TAG is required}_${WRT_VER:?WRT_VER is required}_${START_TIME:?START_TIME is required}.${ext}"
        mv -f "${file}" "./upload/${new_file}"
    done < <(find ./bin/targets/ -type f -iname "*${type}*.*")
done

# 兜底搬运剩余目标文件。
# 上面的循环主要处理“带设备名”的正式镜像；这里把 bin/targets 下其余目标文件
# 一并搬到 upload/，避免漏掉某些不含设备名但仍有价值的产物。
find ./bin/targets/ -type f -not -name '*openwrt-imagebuilder*' -exec mv -f {} ./upload/ \;

# 告诉 workflow 这一步整理完成，后续可以安全上传 upload/ 目录。
echo "status=success" >> "${GITHUB_OUTPUT}"
