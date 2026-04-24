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
- `WRT_FIREWALL`：显式选择防火墙栈，`fw3` 或 `fw4`
- `WRT_OVERLAYS`：可选 overlays，逗号分隔；除内置的 `frps`、`apk`、`ipk` 外，也支持你自己新增的 overlay 名，例如 `frps,apk`、`myvpn`
- `WRT_LUCI_BRANCH`：可选 LuCI feed 分支，例如 `openwrt-23.05`、`23.05`、`2305`；留空或未识别时使用源码默认值

### GitHub Actions 源码与配置层说明

- `WRT_SOURCE_FLAVOR`：选择源码风味；当前仅支持 `lean` 与 `VIKINGYFY`
- `WRT_SOURCE_HASH_INFO`：可选指定 commit hash；推荐只填 hash 本身
- `WRT_FIREWALL`：显式选择要导出的防火墙配置段；是否跳过 `GENERAL-SERVICE` / `GENERAL-FW*` 由设备主文件自动决定
- `WRT_OVERLAYS`：叠加可选差异层；会按传入顺序依次覆盖，只有 `apk` 与 `ipk` 互斥
- `WRT_LUCI_BRANCH`：优先控制 LuCI feed 版本；例如传 `openwrt-23.05`、`23.05` 或 `2305` 时，会把 lean 源码中的 LuCI feed 切到 `openwrt-23.05`

脚本内部会根据 `WRT_SOURCE_FLAVOR` 映射固定源码信息：`lean -> https://github.com/coolsnowwolf/lede @ master`，`VIKINGYFY -> https://github.com/VIKINGYFY/immortalwrt @ main`。

当前配置目录按以下层级组合：

- `Config/GENERAL.txt`
- `Config/GENERAL-SERVICE.txt`
- `Config/GENERAL-FW3.txt` 或 `Config/GENERAL-FW4.txt`
- `Config/<设备名>-FW3.txt` 或 `Config/<设备名>.txt`
- `Config/device-overlays/<设备名>-<FW>.txt`（如果存在则自动叠加）
- `Config/overlays/<overlay>.txt`（按 `WRT_OVERLAYS` 顺序叠加；输入时不区分大小写，内部会映射到大写文件名）

当前 `IPQ60XX-NOWIFI` 与 `IPQ60XX-NOWIFI-MINI` 已先收口为单主文件模式：

- 主文件分别使用 `Config/IPQ60XX-NOWIFI-FW3.txt`、`Config/IPQ60XX-NOWIFI-MINI-FW3.txt`
- `GENERAL-SERVICE` 的服务插件也已抽入这个主文件，方便在一个文件内查看自定义插件
- `lean` 现阶段主走 FW3，文件中的 FW3 段落默认生效
- 同一文件中的 FW4 注释段会在导出 `fw4` 时被激活
- 这两个设备导出时都会跳过 `GENERAL-SERVICE.txt` / `GENERAL-FW3.txt` / `GENERAL-FW4.txt`，由主文件自己承接服务层与防火墙栈配置
- `IPQ60XX-NOWIFI-MINI` 的 FW3 不再额外叠加 `device-overlays/IPQ60XX-NOWIFI-MINI-FW3.txt`

当前 `MT6000-WIFI` 与 `MT6000-WIFI-MINI` 也已收口为单主文件模式：

- 主文件分别使用 `Config/MT6000-WIFI-FW3.txt`、`Config/MT6000-WIFI-MINI-FW3.txt`
- 同一文件中的 FW4 注释段会在导出 `fw4` 时被激活
- `MT6000-WIFI-MINI` 还会在主文件内直接承接原先的 `MINI-SERVICE` 与 `MINI-FW4` 差异，不再额外叠加对应 variants 文件

自定义 overlay 的约定：

- 新增一个文件到 `Config/overlays/`，例如 `Config/overlays/MYVPN.txt`
- 在 `WRT_OVERLAYS` 里填写 `myvpn`；脚本会自动映射到 `Config/overlays/MYVPN.txt`
- 可以同时传多个值，例如 `myvpn,frps,apk`
- 后面的 overlay 会覆盖前面同名配置
- 目前唯一内置冲突限制是 `apk` 与 `ipk` 不能同时启用
- 如需切换 LuCI feed，使用 `WRT_LUCI_BRANCH=openwrt-23.05`，也支持 `23.05`、`2305`
- 如果 `WRT_LUCI_BRANCH` 未识别到已知版本线，就保持 `feeds.conf.default` 里原本写好的版本不变

配置维护约定：

- `CONFIG_PACKAGE_luci-app-*`、`CONFIG_PACKAGE_luci-theme-*` 与对应的 `CONFIG_PACKAGE_luci-i18n-*-zh-cn` 应写在同一份配置文件里，避免主包和语言包分散到不同层级
- 只适用于特定防火墙栈的包，应写在 `Config/GENERAL-FW3.txt` 或 `Config/GENERAL-FW4.txt` 中统一控制；不要写在设备层里覆盖，例如 `luci-app-turboacc` 仅允许在 FW3 层启用

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
