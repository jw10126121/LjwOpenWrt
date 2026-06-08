# OpenWrt 项目概述 Skill
#
# 这个 Skill 提供 OpenWrt 项目的快速概述和导航

我是您的 OpenWrt 项目导航助手。我会帮您快速了解项目结构和找到需要的文件。

## 项目概述

这是一个 OpenWrt 固件编译配置项目，专注于多个路由器设备的配置管理，特别是支持 FW3 和 FW4 防火墙版本。

## 目录结构

### 主要目录
- `Config/` - 设备配置文件
  - `device-overlays/` - 设备特定的配置覆盖层（主要是 FW4）
  - `overlays/` - 功能覆盖层（APK、USB、FRP等）
- `Scripts/` - 项目脚本
  - `lib/` - 脚本库
  - `patch/` - 补丁文件
  - `tests/` - 测试脚本
- `.github/` - GitHub Actions 工作流

### 关键脚本
- `Scripts/export_config.sh` - 导出设备配置
- `Scripts/merge_configs.sh` - 合并配置文件
- `Scripts/diy_config.sh` - DIY配置脚本

## 配置文件命名规则

### 新结构（推荐）
- `Config/{设备名}.txt` - FW3 基础配置（默认）
- `Config/device-overlays/{设备名}-FW4.txt` - FW4 差异配置

### 旧结构（保留兼容）
- `Config/{设备名}-FW3.txt` - 完整 FW3 配置
- `Config/{设备名}-FW4.txt` - 完整 FW4 配置

## 支持的设备（部分）
- CMIOT-AX18-NOWIFI
- IPQ60XX-NOWIFI
- JD-AX1800PRO-WIFI
- JD-AX6600-WIFI
- GL-MT6000-WIFI
- 以及更多...

## 常见操作

1. **导出配置**
   - 使用 `export_config.sh` 脚本
   - 选择设备和防火墙版本

2. **添加新配置**
   - 创建基础配置文件
   - 创建FW4 overlay（如需要）

3. **自定义固件**
   - 使用 overlays 添加特定功能
   - 支持 APK包管理器、USB支持、FRP等

## 如何使用这个项目

1. 选择您的设备
2. 选择防火墙版本（FW3 或 FW4）
3. 应用所需的 overlays
4. 导出配置
5. 开始编译！

有什么我可以帮您快速定位或了解的吗？
