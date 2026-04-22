# OpenWrt-CI

lean-only 的 OpenWrt 云编译仓库，源码固定为 [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede)，默认分支 `master`。

## 支持目标

- `IPQ60XX-NOWIFI`
- `IPQ60XX-NOWIFI-MINI`
- `MT6000-WIFI`
- `MT6000-WIFI-MINI`

如需调整具体机型勾选项，直接修改对应配置文件中的 `CONFIG_TARGET_DEVICE_*`。

## GitHub Actions

[![CUSTOM](https://github.com/jw10126121/LjwOpenWrt/actions/workflows/CUSTOM.yml/badge.svg)](https://github.com/jw10126121/LjwOpenWrt/actions/workflows/CUSTOM.yml)
[![DEFAULT](https://github.com/jw10126121/LjwOpenWrt/actions/workflows/DEFAULT.yml/badge.svg)](https://github.com/jw10126121/LjwOpenWrt/actions/workflows/DEFAULT.yml)

手动运行 `DEFAULT` 时，主要输入项如下：

- `WRT_DEVICE`：设备型号
- `WRT_FIREWALL`：防火墙栈，`fw3` 或 `fw4`
- `WRT_OVERLAYS`：可选差异层，逗号分隔，例如 `frps,apk`
- `WRT_LUCI_BRANCH`：可选 LuCI feed 分支，例如 `openwrt-23.05`、`23.05`、`2305`
- `WRT_SOURCE_HASH_INFO`：可选 commit hash，用于固定到指定 lean 提交

说明：

- 源码仓库固定为 `https://github.com/coolsnowwolf/lede`
- 源码分支固定为 `master`
- `WRT_LUCI_BRANCH` 留空时使用源码默认 LuCI feed
- `apk` 与 `ipk` overlay 互斥

## 配置组织

当前配置按以下顺序叠加：

- `Config/GENERAL.txt`
- `Config/GENERAL-SERVICE.txt`
- `Config/GENERAL-FW3.txt` 或 `Config/GENERAL-FW4.txt`
- `Config/<设备名>-FW3.txt`
- `Config/device-overlays/<设备名>-<FW>.txt`（若存在）
- `Config/overlays/<overlay>.txt`（按 `WRT_OVERLAYS` 顺序叠加）

当前主维护文件：

- `IPQ60XX-NOWIFI`：`Config/IPQ60XX-NOWIFI-FW3.txt`
- `MT6000-WIFI`：`Config/MT6000-WIFI-FW3.txt`
- `MT6000-WIFI-MINI`：`Config/MT6000-WIFI-MINI-FW3.txt`

这些主文件已经直接承接服务层与防火墙差异，导出时由脚本按段落标记选择，不再额外拆散维护。

## Overlay 约定

- 自定义 overlay 放到 `Config/overlays/`，例如 `Config/overlays/MYVPN.txt`
- `WRT_OVERLAYS=myvpn` 会映射到 `Config/overlays/MYVPN.txt`
- 后面的 overlay 会覆盖前面的同名配置

## 固件默认值

- 默认主题：Argon
- 默认 LAN：`192.168.0.1`
- 默认用户：`root`
- 默认密码：空密码

## 下载与源码

- 固件发布页：[LjwOpenWrt Releases](https://github.com/jw10126121/LjwOpenWrt/releases)
- 上游源码：[coolsnowwolf/lede](https://github.com/coolsnowwolf/lede)

## 刷机说明

适用于当前 lean 固件：

- Hugo U-Boot + 原厂 CDT + 双分区 GPT
- U-Boot 刷 `squashfs-recovery.bin`
- LuCI 刷 `squashfs-sysupgrade.bin`

## 提示

本仓库仅供学习与交流使用，请自行评估刷机风险并遵守相关法律法规。
