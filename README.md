# Openwrt-CI


如需自定义, 请fork后修改相应配置。

目前支持配置：IPQ60XX-NOWIFI、IPQ60XX-NOWIFI_lite、MT6000

如需修改机型配置，请查看配置文件并修改，例：

只编译: 

    CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_cmiot_ax18=y         # 和目AX18、兆能M2

可编译: 

    CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_glinet_gl-ax1800=y   # gl-ax1800
    CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_glinet_gl-axt1800=y  # gl-axt1800
    CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-ss-01=y   # 京东云亚瑟
    CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-cs-02=y   # 京东云雅典娜
    CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-cs-07=y   # 京东云太乙
    CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_linksys_mr7350=y     # MR7350
    CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_qihoo_360v6=y        # 360V6
    CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_redmi_ax5-jdcloud=y  # 京东云红米AX5
    CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_xiaomi_rm1800=y      # 小米AX1800、红米AX5


## 云编译OpenWRT固件
[![CUSTOM](https://github.com/jw10126121/LjwOpenWrt/actions/workflows/CUSTOM.yml/badge.svg)](https://github.com/jw10126121/LjwOpenWrt/actions/workflows/CUSTOM.yml)
[![DEFAULT](https://github.com/jw10126121/LjwOpenWrt/actions/workflows/DEFAULT.yml/badge.svg)](https://github.com/jw10126121/LjwOpenWrt/actions/workflows/DEFAULT.yml)

### GitHub Actions 配置组合方式
在 GitHub Actions 页面手动点击 `Run workflow` 时，配置组合改为参数化输入：

- `WRT_DEVICE`：选择设备型号，例如 `IPQ60XX-NOWIFI`、`MT6000-WIFI`
- `WRT_FIREWALL`：选择防火墙栈，`fw3` 或 `fw4`
- `WRT_OVERLAYS`：可选 overlays，逗号分隔，例如 `frps`、`apk`、`frps,apk`

### GitHub Actions 源码与配置层说明

- `WRT_REPO_URL`：决定使用哪个上游源码仓库
- `WRT_REPO_BRANCH`：决定拉取哪个源码分支；留空时按仓库默认分支处理
- `WRT_SOURCE_HASH_INFO`：推荐只填 commit hash；旧格式 `hash|url|branch` 仍兼容，但不再推荐
- `WRT_FIREWALL`：只表示功能配置层，不再隐含绑定特定源码
- `WRT_GENERAL_CONFIG`：可选手工基础配置组合；一般不需要填写
- `WRT_OVERLAYS`：叠加可选差异层；`apk` 与 `ipk` 互斥

脚本内部会根据 `WRT_REPO_URL` 自动解析 `source_flavor=lean|VIKINGYFY|generic`，未显式传源码时默认使用 `lean`。如果 `WRT_REPO_BRANCH` 留空，会自动选择默认分支：`lean -> master`，`VIKINGYFY -> main`。

当前配置目录按以下层级组合：

- `Config/GENERAL.txt`
- `Config/GENERAL-SERVICE.txt`
- `Config/GENERAL-FW3.txt` 或 `Config/GENERAL-FW4.txt`
- `Config/devices/<设备名>.txt`
- `Config/device-overlays/<设备名>-<FW>.txt`（如果存在则自动叠加）
- `Config/overlays/<overlay>.txt`（按 `WRT_OVERLAYS` 顺序叠加）

## 编译时间
手动编译

## 固件信息(更新信息请看固件下载页)
### LEDE: 
    带NSS的6.1内核固件：
    默认主题为Argon；
    默认使用iptable防火墙（fw3）
    默认管理地址：192.168.0.1 
    默认用户：root 
    默认密码：无 | password

## 固件下载
当前仓库默认以本仓库发布页为主；其它上游如需直接下载成品固件，可前往各自发布页。

### LEDE: 

<https://github.com/jw10126121/LjwOpenWrt/releases>
    
### OWRT: 
<https://github.com/VIKINGYFY/OpenWRT-CI/releases>
    
### LibWRT: 
<https://github.com/breeze303/openwrt-ci/releases>
    
### 固件源码(带NSS) 
    LEDE: https://github.com/coolsnowwolf/lede.git     
    OWRT: https://github.com/VIKINGYFY/immortalwrt.git 
    LibWRT: https://github.com/LiBwrt-op/openwrt-6.x.git 

## 刷机方法:
### LEDE:
    Hugo Uboot + 原厂CDT + 双分区GPT
    Uboot 刷入squashfs-recovery.bin #第一次刷完5分钟,之后重启15秒开机。
    Luci 刷入squashfs-sysupgrade.bin #不保留配置开机1分钟开机。

### LibWRT & OWRT & QWRT:
    Hugo Uboot + 原厂CDT + 单/双分区GPT
    Uboot 刷入squashfs-factory.bin #第一次刷完5分钟,之后重启15秒开机。
    Luci 刷入squashfs-sysupgrade.bin #不保留配置开机1分钟开机。

## 感谢

ftkey | VIKINGYFY | LiBwrt-op | ZqinKing | laipeng668 | ImmortalWRT | LEDE | MORE AND MORE

## 特别提示
本人不对任何人因使用本固件所遭受的任何理论或实际的损失承担责任！
本固件禁止用于任何商业用途，请务必严格遵守国家互联网使用相关法律规定！
