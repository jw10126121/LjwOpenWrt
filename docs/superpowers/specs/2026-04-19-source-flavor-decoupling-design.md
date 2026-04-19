# 源码风味解耦设计

## 背景

当前仓库把三类概念混在了一起：

1. 固件功能层选择，例如 `FW3`、`FW4`
2. 上游源码选择，例如 `coolsnowwolf/lede`、`VIKINGYFY/immortalwrt`
3. 脚本里针对不同源码目录结构的文件修改

这个问题在 `Scripts/diy_config.sh` 和 `Scripts/Packages.sh` 里最明显。现在脚本通过 `package/lean/default-settings/files/zzz-default-settings` 这类目录特征去推断是否是 `lean`，再据此决定是否执行通用逻辑或源码专属逻辑。workflow 层已经有显式源码输入，但 shell 脚本层仍然依赖本地目录结构做反推，导致同一个概念在不同层里的定义并不一致。

本次改动的目标，是把“源码选择”和“固件功能层选择”解耦，并让 `VIKINGYFY` 成为仓库里的一等源码风味，同时保持现有入口脚本不变。

## 目标

- 以 `WRT_REPO_URL` 作为源码类型判定的唯一可信输入
- 引入稳定的源码风味值：`lean`、`VIKINGYFY`、`generic`
- 保持现有脚本入口和 workflow 入口大体不变
- 将 OpenWrt 通用逻辑与源码专属逻辑拆开
- 保持现有 `FW3`、`FW4` 配置层语义不变
- 为源码风味解析和新的脚本边界补充测试

## 非目标

- 一次性重写所有包替换逻辑
- 把所有 ImmortalWrt 分支都抽象成统一风味
- 改变现有 `FW3`、`FW4` 配置文件的含义
- 移除当前 workflow 对手工指定源码的支持

## 源码选择模型

源码风味只根据显式上游元数据解析，不再依赖本地目录结构。

解析规则如下：

- 未显式传入源码时：默认使用 `lean`
- `lean`：`WRT_REPO_URL` 匹配 `coolsnowwolf/lede`
- `VIKINGYFY`：`WRT_REPO_URL` 匹配 `VIKINGYFY/immortalwrt`
- `generic`：其它所有非 `lean` 源码

这套解析逻辑需要通过一个共享 helper 暴露给脚本层使用，避免 workflow 层和 shell 层各自实现一套规则，后续再漂移。

## `diy_config.sh` 设计

`Scripts/diy_config.sh` 继续作为入口脚本，但内部行为改成按源码风味分层：

- `common`：源码无关的通用逻辑
- `lean`：只包含依赖 `lean` 目录结构的逻辑
- `VIKINGYFY`：只包含 `VIKINGYFY/immortalwrt` 的专属差异
- `generic`：除 `lean` 和 `VIKINGYFY` 外的非 `lean` 兜底逻辑

### 通用层

通用层只负责与上游目录结构无关的行为，例如：

- 默认 LAN IP 和主机名修改
- 默认主题选择
- `ipk` / `apk` 包管理器切换
- 基于公共 feed 路径的 LuCI 菜单调整
- OpenVPN 默认项修补
- `.config` 开关维护
- 其它不依赖 `lean` 专属目录的 feed 或包开关

### `lean` 层

`lean` 层只保留明确依赖 `lean` 目录布局的逻辑，例如：

- `package/lean/default-settings/files/zzz-default-settings`
- `package/lean/autocore/...`
- `package/base-files/luci2/bin/config_generate`
- 任何只因为 `lean` 提供这些路径才成立的首次启动注入逻辑

### `VIKINGYFY` 层

`VIKINGYFY` 层会在这次重构中先建立边界，即使开始时内容接近空实现也可以。只有在某个行为被确认确实只适用于 `VIKINGYFY/immortalwrt`，且不适合放入通用层时，才进入这一层。

这样可以避免继续沿用当前“非 `lean` 全都塞进一个分支”的方式，让特例悄悄堆积回通用路径。

### `generic` 层

`generic` 层是所有非 `lean` 且非 `VIKINGYFY` 源码的兜底层。它应继续使用现有 `uci-defaults/99-lin-defaults` 这种非 `lean` 首次运行脚本方式，但不能夹带实际上只适用于 `VIKINGYFY` 的逻辑。

## `Packages.sh` 设计

`Scripts/Packages.sh` 继续作为入口脚本，保留现有通用包管理函数，但把源码相关的包替换清单拆到各自风味层。

### 共享函数

共享函数继续负责：

- 删除已有包目录
- 克隆包仓库
- 从大仓库抽取子包
- 安全替换与失败回滚
- 版本更新工具函数

### 按风味拆分包清单

按风味拆分后的区域只负责各自源码真正需要的包覆盖项：

- `lean`：只放 `coolsnowwolf/lede` 需要的包覆盖
- `VIKINGYFY`：只放 `VIKINGYFY/immortalwrt` 需要的包覆盖
- `generic`：只放其它源码的最小兜底行为

当前基于本地目录存在性判断 `is_code_lean` 的逻辑要移除。`Packages.sh` 应改为接收或解析显式源码元数据，再得出 `source_flavor`。

## Workflow 设计

workflow 需要把两条轴明确拆开：

- 配置层：`FW3`、`FW4`、overlay、基础配置组合
- 源码层：只由 `WRT_REPO_URL` 决定

需要调整的点如下：

- 把当前二元的 `WRT_IS_LEAN` 判定改成 `SOURCE_FLAVOR`
- 保留按 `FW3` / `FW4` 自动解析基础配置组合的逻辑
- 不再暗示 `FW3` 或 `FW4` 会决定上游源码仓库
- 向 shell 脚本显式传递源码风味信息

迁移期间可以保留 `WRT_IS_LEAN` 作为兼容变量，但真正可信的值要变成 `SOURCE_FLAVOR`。

## 测试计划

本次重构至少补齐以下测试：

1. 新增源码风味解析测试，覆盖：
   - `coolsnowwolf/lede` -> `lean`
   - `VIKINGYFY/immortalwrt` -> `VIKINGYFY`
   - 其它仓库 -> `generic`
2. 更新 `Scripts/test_diy_config_structure.sh`，让它断言新的风味边界函数存在
3. 现有 `apk` / `ipk` 包管理器测试保持不动
4. 如果 `Packages.sh` 的整包覆盖逻辑暂时不适合全面测试，至少补一个轻量的风味解析测试

## 迁移顺序

1. 新增共享的源码风味解析 helper
2. 重构 `diy_config.sh`，改为依赖显式源码风味输入
3. 把现有 `lean` 专属路径修改从通用流程中移出去
4. 把当前非 `lean` 兜底逻辑收敛进 `generic`
5. 建立空或近乎空实现的 `VIKINGYFY` 层
6. 用同一 helper 重构 `Packages.sh`
7. 更新 workflow，输出并传递 `SOURCE_FLAVOR`
8. 修改 `README`，明确源码由 `WRT_REPO_URL` 决定，而不是由 `FW3` / `FW4` 决定
9. 跑完结构测试和源码风味测试

## 风险与控制

- 风险：通用逻辑里仍然误引用 `lean` 专属路径
  控制：把依赖目录结构的修改全部集中到风味函数里，并为这些边界补测试

- 风险：workflow 和 shell 的判定规则迁移后再次分叉
  控制：统一通过一套源码风味解析规则生成并传递结果

- 风险：非 `lean` 现有行为在迁移时被无意改坏
  控制：先把原来的非 `lean` 逻辑完整收进 `generic`，再逐步增加 `VIKINGYFY` 差异

## 预期结果

重构完成后，`FW3` 和 `FW4` 继续只表示功能配置组合，而源码行为完全由 `WRT_REPO_URL` 派生出的 `source_flavor=lean|VIKINGYFY|generic` 控制。

这样就能在不继续把 `lean` 假设埋进共享路径的前提下，为 `VIKINGYFY/immortalwrt` 提供稳定支持。
