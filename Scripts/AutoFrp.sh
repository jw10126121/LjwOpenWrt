#!/bin/bash

# 该脚本用于通过 IPQ60XX-NOWIFI-FW3.txt 生成 IPQ60XX-NOWIFI-FW3-FRPS-override.txt
# 核心逻辑：只提取并翻转 frpc / frps 相关配置项，生成可叠加的小型覆盖文件。

# 输入文件和输出文件
input_file="../Config/IPQ60XX-NOWIFI-FW3.txt"
output_file="../Config/IPQ60XX-NOWIFI-FW3-FRPS-override.txt"

# 检查输入文件是否存在
if [ ! -f "$input_file" ]; then
    echo "输入文件 $input_file 不存在！"
    exit 1
fi

# 清空或创建输出文件
cat > "$output_file" <<'EOF'
# ------------------------------------------------------------------------
#  说明
# ------------------------------------------------------------------------
# 该覆盖文件由 AutoFrp.sh 自动生成。
# 仅保留 FRP 客户端 / 服务端的差异项，用于叠加到 IPQ60XX-NOWIFI-FW3.txt。

# ------------------------------------------------------------------------
#  FRP 差异覆盖
# ------------------------------------------------------------------------
EOF

# 逐行处理输入文件，仅翻转并输出 FRP 相关选项。
while IFS= read -r line; do
    # 检查是否是需要反转值的配置项
    if [[ "$line" =~ ^(CONFIG_PACKAGE_frpc|CONFIG_PACKAGE_luci-app-frpc|CONFIG_PACKAGE_luci-i18n-frpc-zh-cn|CONFIG_PACKAGE_luci-app-frps|CONFIG_PACKAGE_luci-i18n-frps-zh-cn|CONFIG_PACKAGE_frps)= ]]; then
        # 反转值
        if [[ "$line" == *=y ]]; then
            echo "${line/=y/=m}" >> "$output_file"
        else
            echo "${line/=m/=y}" >> "$output_file"
        fi
    fi
done < "$input_file"

echo "生成文件 $output_file 完成！"
