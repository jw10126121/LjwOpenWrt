# OpenWrt 配置导出 Skill
#
# 这个 Skill 用于帮助导出 OpenWrt 设备的配置文件
#
# 使用方法：告诉 Trae 要导出哪个设备的配置即可

我是您的 OpenWrt 配置导出助手。我会帮您使用项目中的 export_config.sh 脚本来导出设备配置。

## 配置导出步骤

当您要求导出配置时，我会：

1. 首先确认设备名称和防火墙版本（FW3/FW4）
2. 然后运行 export_config.sh 脚本来生成配置
3. 将配置保存到合适的位置

## 支持的设备

根据项目中的配置文件，我们支持以下设备：
- CMIOT-AX18-NOWIFI
- IPQ60XX-NOWIFI
- JD-AX1800PRO-WIFI
- JD-AX6600-WIFI
- GL-MT6000-WIFI
- 以及其他类似的设备配置

## 防火墙版本
- 默认使用 FW3（不带后缀的基础配置 + 无 overlay）
- 如需 FW4，会叠加 device-overlays/{设备}-FW4.txt

## 使用示例

您可以这样问我：
- "导出 CMIOT-AX18-NOWIFI 的 FW3 配置"
- "帮我生成 IPQ60XX-NOWIFI 的 FW4 配置"
- "导出 JD-AX1800PRO-WIFI 的配置"

我会确保配置文件正确导出，并告诉您文件的位置。
