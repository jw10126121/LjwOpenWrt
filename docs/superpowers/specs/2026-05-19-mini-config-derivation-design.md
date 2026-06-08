# MINI 设备配置派生设计

## 目标

将仓库中的 `*-MINI` 设备配置从“独立维护整份主配置文件”统一收敛为：

- 基础设备主配置
- 通用 `MINI` 派生规则
- 必要时叠加少量 `MINI` 设备 overlay

本次目标设备范围：

- `CMIOT-AX18-NOWIFI-MINI`
- `IPQ60XX-NOWIFI-MINI`
- `GL-MT6000-WIFI-MINI`
- `MIR3G-WIFI-MINI`

## 背景

当前仓库中的 `MINI` 设备以独立设备名存在，直接对应完整配置文件，例如：

- `Config/CMIOT-AX18-NOWIFI-MINI-FW3.txt`
- `Config/IPQ60XX-NOWIFI-MINI-FW3.txt`
- `Config/GL-MT6000-WIFI-MINI-FW3.txt`
- `Config/MIR3G-WIFI-MINI-FW3.txt`

这类文件大多来自对应普通设备配置的裁剪版本，核心规律是：

- 大部分软件包仅把 `=m` 统一降级为 `=n`
- 少量设备会保留少数 `y` 或 `m` 的特例
- 设备平台、目标 profile、无线能力、FW 栈等大段内容与基础设备完全相同或高度相似

继续维护整份 `MINI` 主配置会带来几个问题：

- 普通版和 `MINI` 版的大量重复内容需要双写
- 新增或调整普通版服务项时，容易漏同步 `MINI`
- `MINI` 设备之间已经出现“纯裁剪”和“带少量特例”两种模式，结构不统一
- 读 diff 时很难快速分辨哪些是 `MINI` 语义，哪些只是普通版同步遗漏

## 设计目标

1. `MINI` 设备继续保留当前显式入口名，如 `CMIOT-AX18-NOWIFI-MINI`。
2. `MINI` 默认语义统一为“在基础设备配置上把所有有效 `CONFIG_*=m` 降为 `CONFIG_*=n`”。
3. 个别不满足纯裁剪规则的设备，通过小型 `device-overlays/<DEVICE>-MINI-<FW>.txt` 表达特例。
4. 普通设备导出逻辑保持稳定，不因为 `MINI` 派生机制改变现有非 `MINI` 行为。
5. 删除可以被派生机制替代的 `Config/*-MINI-FW3.txt` / `Config/*-MINI-FW4.txt` 整文件维护。

## 非目标

本次改动不包括：

- 重做 `GENERAL.txt` 或 overlay 全局分层规则
- 改变 `MINI` 设备在 workflow、README、脚本中的显示名字
- 为 `MINI` 设备新增新的包裁剪策略，超出“`m -> n` + 显式特例”范围
- 修改普通设备的默认包选择
- 将 `MINI` 语义扩展到非 `-MINI` 命名的其他设备

## 目标结构

迁移后，`MINI` 设备的配置表达分为两层。

第一层是基础设备主配置：

- `Config/CMIOT-AX18-NOWIFI-FW3.txt`
- `Config/CMIOT-AX18-NOWIFI-FW4.txt`
- `Config/IPQ60XX-NOWIFI-FW3.txt`
- `Config/IPQ60XX-NOWIFI-FW4.txt`
- `Config/GL-MT6000-WIFI-FW3.txt`
- `Config/GL-MT6000-WIFI-FW4.txt`
- `Config/MIR3G-WIFI-FW3.txt`

其中 `MIR3G-WIFI-MINI` 当前没有公开的非 `MINI` 对应设备文件，因此需要先补一个仅供维护和派生使用的基础文件：

- `Config/MIR3G-WIFI-FW3.txt`

它不需要成为新的 workflow 手动入口，只作为 `MIR3G-WIFI-MINI` 的派生基底。

第二层是可选的 `MINI` 特例 overlay：

- `Config/device-overlays/IPQ60XX-NOWIFI-MINI-FW3.txt`
- `Config/device-overlays/IPQ60XX-NOWIFI-MINI-FW4.txt`
- `Config/device-overlays/GL-MT6000-WIFI-MINI-FW3.txt`
- `Config/device-overlays/GL-MT6000-WIFI-MINI-FW4.txt`
- `Config/device-overlays/MIR3G-WIFI-MINI-FW3.txt`

对于没有特例的设备，不创建 `MINI` overlay：

- `CMIOT-AX18-NOWIFI-MINI`

如果某个 `MINI` 设备未来再次出现偏离通用规则的项，只在对应 `device-overlays` 中追加，不恢复整份 `MINI` 主配置。

## 导出逻辑

### 入口兼容

`export_config.sh` 仍然接受当前设备名：

- `CMIOT-AX18-NOWIFI-MINI`
- `IPQ60XX-NOWIFI-MINI`
- `GL-MT6000-WIFI-MINI`
- `MIR3G-WIFI-MINI`

workflow、README、脚本调用方式不变。

### 解析顺序

当 `--device` 不是 `-MINI` 设备时，保持现有解析逻辑：

1. 优先找 `Config/<DEVICE>-<FW>.txt`
2. 找不到再回退到 `Config/<DEVICE>.txt`
3. 再找不到回退到 `Config/<DEVICE>-FW3.txt`

当 `--device` 是 `-MINI` 设备时，导出逻辑调整为：

1. 去掉设备名尾部的 `-MINI`，得到基础设备名
2. 按当前 `fw` 选择基础设备配置文件
3. 先执行已有的服务层 / `FW3` / `FW4` 预处理
4. 对预处理后的有效配置执行 `MINI` 变换：把所有 `CONFIG_*=m` 改为 `CONFIG_*=n`
5. 若存在 `Config/device-overlays/<MINI-DEVICE>-<FW>.txt`，则在最后叠加
6. 再叠加显式 `--overlay` 列表

这样 `MINI` 派生发生在基础设备配置和最终 overlay 之间，确保：

- 通用裁剪先统一生效
- 设备特例可以覆盖通用裁剪结果
- 用户手动指定的 overlay 仍保留最高优先级

### `MINI` 变换规则

`MINI` 变换只处理有效配置行：

- `CONFIG_*=m` 改为 `CONFIG_*=n`
- `CONFIG_*=y` 保持不变
- `CONFIG_*=n` 保持不变
- 注释行保持不变
- 被注释掉的 `# CONFIG_* is not set` 或 `#CONFIG_*=` 行保持不变

这条规则只表达“模块包在 `MINI` 中默认不编译”，不主动把任何项提升为 `y`。

## 设备特例原则

### 纯派生设备

`CMIOT-AX18-NOWIFI-MINI` 满足当前通用规则，可直接由：

- `CMIOT-AX18-NOWIFI-FW3.txt`
- `CMIOT-AX18-NOWIFI-FW4.txt`

派生得到，不再维护独立 `MINI` 主配置文件。

### 带特例 overlay 的设备

`IPQ60XX-NOWIFI-MINI`、`GL-MT6000-WIFI-MINI`、`MIR3G-WIFI-MINI` 允许保留少量显式特例。例如：

- 某些 `MINI` 设备仍需保留少量页面或后端为 `y`
- 个别项需要保留 `m`，而不是被通用规则降为 `n`

这些差异必须放在 `device-overlays/<DEVICE>-MINI-<FW>.txt` 中，且遵守：

- 只写偏离基础设备 `MINI` 规则的项
- 不复制基础设备中未变化的值
- 不把 overlay 扩张成另一份完整配置

## README 与维护说明

README 中的 `MINI` 设备入口保留，但“主维护文件”说明需要改为：

- 普通设备仍指向各自主配置文件
- `MINI` 设备说明为“由基础设备主配置派生，必要时叠加 `device-overlays/<DEVICE>-MINI-<FW>.txt`”

这样可以让后续维护者明确知道：

- 新增普通包时先改基础设备
- 只有当 `MINI` 需要偏离通用规则时才改 overlay

## 测试设计

### 现有测试调整

现有直接读取 `Config/*-MINI-FW3.txt` 的测试需要改为验证导出结果，而不是硬编码要求 `MINI` 主配置文件存在。

重点调整范围：

- `Scripts/tests/test_packages_openclash_easytier_versions.sh`
- `Scripts/tests/test_mini_fw3_module_scope.sh`
- `Scripts/tests/test_gl_mt6000_mini_fw3_export.sh`
- `Scripts/tests/test_ipq60xx_mini_fw3_export.sh`
- 其他直接断言 `Config/*-MINI-*.txt` 存在的测试

### 新增测试

需要覆盖三类场景：

1. 纯派生 `MINI`
2. 带特例 overlay 的 `MINI`
3. 非 `MINI` 设备回归

建议新增或调整的核心断言包括：

- `CMIOT-AX18-NOWIFI-MINI` 导出结果中，不再保留基础配置里的 `=m`
- `IPQ60XX-NOWIFI-MINI` 导出结果中，通用 `m -> n` 已生效，但 overlay 指定保留的项仍为目标值
- `GL-MT6000-WIFI-MINI` 导出结果中，允许的模块包仍只来自显式特例
- `MIR3G-WIFI-MINI` 可通过新增的 `MIR3G-WIFI-FW3.txt` 基础文件正常派生
- 非 `MINI` 设备导出结果不受影响
- 当 `MINI` 主配置文件不存在时，`export_config.sh` 仍能通过基础设备成功导出

### 兼容性验证

还需要验证：

- `--device <BASE-DEVICE>` 行为不变
- `--device <BASE-DEVICE>-MINI` 对 `fw3` / `fw4` 都可正常导出
- `device-overlays/<MINI-DEVICE>-<FW>.txt` 缺失时，纯派生设备仍能正常导出
- 显式 `--overlay` 仍能覆盖 `MINI` 派生结果

## 风险

### 风险 1：`MINI` 变换误伤注释或无效配置

如果 `m -> n` 规则写得过宽，可能会改坏注释行、文档行或未启用配置。

缓解方式：

- 只匹配有效 `CONFIG_*=m` 行
- 对注释和空行保持原样
- 用参数化测试覆盖最小样例

### 风险 2：设备特例迁移不完整

如果把现有 `MINI` 主配置删除后，漏掉少量需要保留为 `y` 或 `m` 的项，`MINI` 行为会发生回归。

缓解方式：

- 先对比普通版与 `MINI` 版的真实差异，再提取 overlay
- 每台设备迁移后跑对应导出测试
- 对允许保留的少量模块包写精确断言

### 风险 3：README 与测试仍假定 `MINI` 主文件必须存在

仓库当前已有若干测试和文档直接引用 `Config/*-MINI-FW3.txt`。

缓解方式：

- 统一改成验证设备入口和导出结果
- 只在确实需要时断言 `device-overlays/<MINI-DEVICE>-<FW>.txt` 是否存在

## 推荐实施顺序

1. 在 `export_config.sh` 中加入 `-MINI` 基础设备映射与 `m -> n` 变换
2. 为参数化导出补一组最小测试，证明 `MINI` 派生和特例 overlay 顺序正确
3. 提取 `IPQ60XX-NOWIFI-MINI` 的 `FW3` / `FW4` 特例 overlay
4. 提取 `GL-MT6000-WIFI-MINI` 的 `FW3` / `FW4` 特例 overlay
5. 为 `MIR3G-WIFI-MINI` 补 `MIR3G-WIFI-FW3.txt` 基础文件，并提取它的特例 overlay；若无特例则不创建
6. 删除可被派生替代的 `Config/*-MINI-FW3.txt` / `Config/*-MINI-FW4.txt`
7. 更新 README 和现有测试
8. 跑 `MINI` 导出、包选择、workflow 入口相关测试

## 结论

对当前仓库而言，`MINI` 更适合被建模为“基础设备配置的受控裁剪入口”，而不是另一份长期双写的完整主配置。采用“基础配置 + 通用 `m -> n` 规则 + 小型特例 overlay”之后，既能保留现有设备入口和行为，也能显著降低 `MINI` 配置的维护成本。
