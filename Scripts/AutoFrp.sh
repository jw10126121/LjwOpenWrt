#!/bin/bash

# 该脚本，用于通过 IPQ60XX-NOWIFI-FW3.txt 生成 IPQ60XX-NOWIFI-FW3-FRPS.txt
# 核心逻辑：把 frpc / frps 相关配置项在 y 与 m 之间互换，快速生成另一套构建配置。

# 输入文件和输出文件
input_file="../Config/IPQ60XX-NOWIFI-FW3.txt"
output_file="../Config/IPQ60XX-NOWIFI-FW3-FRPS.txt"

# 检查输入文件是否存在
if [ ! -f "$input_file" ]; then
    echo "输入文件 $input_file 不存在！"
    exit 1
fi

# 清空或创建输出文件
> "$output_file"

# 逐行处理输入文件，仅翻转 FRP 相关选项，其他配置原样保留。
while IFS= read -r line; do
    # 检查是否是需要反转值的配置项
    if [[ "$line" =~ ^(CONFIG_PACKAGE_frpc|CONFIG_PACKAGE_luci-app-frpc|CONFIG_PACKAGE_luci-i18n-frpc-zh-cn|CONFIG_PACKAGE_luci-app-frps|CONFIG_PACKAGE_luci-i18n-frps-zh-cn|CONFIG_PACKAGE_frps)= ]]; then
        # 反转值
        if [[ "$line" == *=y ]]; then
            echo "${line/=y/=m}" >> "$output_file"
        else
            echo "${line/=m/=y}" >> "$output_file"
        fi
    else
        # 其他配置项保持不变
        echo "$line" >> "$output_file"
    fi
done < "$input_file"

echo "生成文件 $output_file 完成！"
