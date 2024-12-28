# Openwrt-CI


如需自定义, 请fork.

只编译: 

    CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_cmiot_ax18=y         # 和目AX18、兆能M2

可编译: 

    CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_glinet_gl-ax1800=y   # gl-ax1800
    CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_glinet_gl-axt1800=y  # l-axt1800
    CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-ss-01=y   # 京东云亚瑟
    CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-cs-02=y   # 京东云雅典娜
    CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-cs-07=y   # 京东云太乙
    CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_linksys_mr7350=y     # MR7350
    CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_qihoo_360v6=y        # 360V6
    CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_redmi_ax5-jdcloud=y  # 京东云红米AX5
    CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_xiaomi_rm1800=y      # 小米AX1800、红米AX5



## 云编译OpenWRT固件
[![CUSTOM](https://github.com/jw10126121/LjwOpenWrt/actions/workflows/CUSTOM.yml/badge.svg)](https://github.com/jw10126121/LjwOpenWrt/actions/workflows/CUSTOM.yml)

## 编译时间
手动编译

## 固件信息
### LEDE: 
    带NSS的6.1内核固件，默认主题为Argon；默认使用iptable防火墙（fw3）。
    默认管理地址：192.168.0.1 默认用户：root 无默认密码

## 固件下载
只编译LEDE，如需OWRT、LibWRT,请前往对应的仓库下载.

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


## 软件包
<details><summary>CONFIG_PACKAGE_luci-app-xxx=y</summary>
    
    ```
    CONFIG_PACKAGE_luci-app-ssr-plus=y       # SSR-Plus
    # CONFIG_PACKAGE_luci-app-advancedplus=y   # 高级设置
    CONFIG_PACKAGE_luci-app-alist=y          # Alist网络服务
    CONFIG_PACKAGE_luci-app-cpufreq=y        # CPU频率策略控制
    CONFIG_PACKAGE_luci-app-ddns=y           # 动态DNS客户端
    CONFIG_PACKAGE_luci-app-openvpn-server=y # OpenVPN服务器
    CONFIG_PACKAGE_luci-app-samba4=y         # Samba文件共享
    CONFIG_PACKAGE_luci-app-socat=y          # Socat端口转发工具
    CONFIG_PACKAGE_luci-app-ttyd=y           # Web终端
    CONFIG_PACKAGE_luci-app-wol=y            # 网络唤醒
    # CONFIG_PACKAGE_luci-app-wolplus=y        # 网络唤醒
    CONFIG_PACKAGE_luci-app-zerotier=y       # ZeroTier虚拟网络
    CONFIG_PACKAGE_luci-theme-argon=y        # Argon主题
    ```

</details>
<details><summary>CONFIG_PACKAGE_luci-app-xxx=n</summary>
    
    ```
    
    ```

</details>




## 感谢

ftkey | VIKINGYFY | LiBwrt-op | ZqinKing | laipeng668 | ImmortalWRT | LEDE | MORE AND MORE

## 特别提示
本人不对任何人因使用本固件所遭受的任何理论或实际的损失承担责任！
本固件禁止用于任何商业用途，请务必严格遵守国家互联网使用相关法律规定！

