# 设备级 FW4 独立主配置拆分设计

## 目标

将当前 6 份同类设备配置从“`FW3` 主文件内嵌 `FW4` 注释段”的模式，统一为“独立 `FW3` 主文件 + 独立 `FW4` 主文件”的模式，降低单文件长度和维护复杂度。

本次统一的设备范围：

- `CMIOT-AX18-NOWIFI`
- `CMIOT-AX18-NOWIFI-MINI`
- `IPQ60XX-NOWIFI`
- `IPQ60XX-NOWIFI-MINI`
- `JD-AX1800PRO-WIFI`
- `JD-AX1800PRO-NOWIFI`

## 背景

当前这批设备主配置都采用同一模式：

- `...-FW3.txt` 作为主文件
- `FW4` 差异以内嵌注释段维护
- `export_config.sh --fw fw4` 通过预处理激活 `FW4` 段
- 个别设备额外保留 `device-overlays/*-FW4.txt`

这种模式在早期有利于避免文件数量膨胀，但随着共享服务项、平台项和代理项不断增加，单个 `FW3` 文件已经过长。继续把 `FW4` 维护在同一文件内，会带来几个问题：

- `FW3` / `FW4` 两套配置边界不清晰
- 变更时容易漏掉某一套防火墙栈
- 设备文件越来越长，阅读和 diff 成本高
- `FW4` 注释段与测试期望出现偏差时，不容易第一时间发现

## 设计目标

1. 每个设备文件只表达一套防火墙栈的完整配置。
2. `export_config.sh` 保持现有解析优先级，不为此次拆分新增特殊逻辑。
3. 迁移后导出的最终 `fw3` / `fw4` 配置语义保持稳定，只修正已经明确要收口的 `FW4` 行为。
4. 同类设备统一模式，避免仓库内同时长期存在两种维护方式。

## 非目标

本次改动不包括：

- 重做 `GENERAL.txt` / `GENERAL-SERVICE.txt` / `GENERAL-FW3.txt` / `GENERAL-FW4.txt` 的仓库级分层
- 将所有设备都统一为独立 `FW3` / `FW4` 文件
- 重写 `export_config.sh` 的整体架构
- 借机调整无关服务包的默认开关

## 目标文件结构

每个设备最终都采用以下结构：

- `Config/<DEVICE>-FW3.txt`
- `Config/<DEVICE>-FW4.txt`

对于这 6 份设备：

- `-FW3.txt` 只保留 `FW3` 下的完整配置
- `-FW4.txt` 只保留 `FW4` 下的完整配置
- `-FW3.txt` 中删除 `# >>> FW4-BEGIN` / `# <<< FW4-END` 整段
- 若 `device-overlays/<DEVICE>-FW4.txt` 只是空占位，则删除

## 导出逻辑

现有 `export_config.sh` 已经具备需要的文件选择顺序：

1. 优先找 `Config/<DEVICE>-FW4.txt`
2. 找不到则回退到 `Config/<DEVICE>.txt`
3. 再找不到则回退到 `Config/<DEVICE>-FW3.txt`

因此，本次拆分后：

- `--fw fw3` 继续命中 `-FW3.txt`
- `--fw fw4` 直接命中新增的 `-FW4.txt`

这意味着不需要为了支持独立 `FW4` 主文件去改 `resolve_device_config()`。

## 迁移规则

### 总体规则

每个 `-FW4.txt` 从对应 `-FW3.txt` 演化而来，但不是简单复制后长期双写，而是迁移完成后成为独立主文件。

迁移步骤的逻辑应当是：

1. 以现有 `-FW3.txt` 为基底创建 `-FW4.txt`
2. 将原内嵌 `FW4` 段里的有效配置解开并写入 `-FW4.txt`
3. 删除 `-FW4.txt` 中不再适用于 `FW4` 的 `FW3` 项
4. 删除 `-FW3.txt` 中整段 `FW4` 注释块
5. 保留设备平台、服务层、无线能力、profile 选择等公共内容在两份文件中各自完整存在

### FW4 行为收口

本次迁移不是纯文件搬运，还要同步收口已经明确的 `FW4` 默认行为：

- `firewall4=y`
- `firewall=n`
- `iptables` / `ip6tables` / `ip6tables-extra` / `ip6tables-mod-nat` 关闭
- `iptables-mod-fullconenat` / `kmod-ipt-fullconenat` 关闭
- 启用 `nftables`、`kmod-nft-core`、`kmod-nft-nat`、`kmod-nft-offload` 等 `FW4` 栈核心项
- `luci-app-turboacc=n`
- `luci-i18n-turboacc-zh-cn=n`
- `luci-app-homeproxy=y`
- `luci-app-openclash` 保持设备当前约定的 `FW4` 目标值
- `luci-app-adguardhome=n`

对 `SSR Plus`，本次按“`FW4` 下由 `HomeProxy` 取代”的方向统一收口：

- `luci-app-ssr-plus=n`
- `luci-i18n-ssr-plus-zh-cn=n`

其中 `CMIOT-AX18-NOWIFI` 当前测试已经要求 `FW4` 下 `SSR Plus` 为 `n`，因此这是修正实现与测试不一致，而不是新增策略。

## 设备覆盖原则

虽然这 6 份设备会统一为同一种结构，但不强制所有 `FW4` 文件拥有完全相同的软件组合。仍然允许：

- `NOWIFI` 与 `WIFI` 机型保留各自硬件差异
- `MINI` 机型保留裁剪后的服务项
- 某些代理或服务包在不同设备上继续保留 `y` / `m` 差异

统一的是文件组织方式，不是把所有设备抹平成同一份包清单。

## 测试设计

### 现有测试调整

继续保留并更新当前基于导出结果的测试，重点覆盖：

- `Scripts/tests/test_cmiot_ax18_fw4_packages.sh`
- 同模式设备现有 `fw4` 导出相关测试

这些测试不应依赖“`FW4` 必须来自内嵌段”这一前提，而应只验证最终导出结果。

### 新增测试

新增一类轻量测试，验证独立 `FW4` 主文件会被优先命中：

- 目标：证明 `export_config.sh --fw fw4` 不再依赖 `-FW3.txt` 内嵌段
- 方法：直接检查导出的 `fw4` 结果来自独立 `-FW4.txt` 所表达的值

建议覆盖的核心断言：

- `CONFIG_PACKAGE_firewall4=y`
- `CONFIG_PACKAGE_firewall=n`
- `CONFIG_PACKAGE_iptables=n`
- `CONFIG_PACKAGE_nftables=y`
- `CONFIG_PACKAGE_luci-app-homeproxy=y`
- `CONFIG_PACKAGE_luci-app-turboacc=n`
- `CONFIG_PACKAGE_luci-app-ssr-plus=n`

### 兼容性验证

还需要确认以下兼容性：

- `--fw fw3` 仍然能正常导出
- `--fw fw4` 能在新增主文件后正常导出
- 删除空的 `device-overlays/*-FW4.txt` 不影响导出结果

## 风险

### 风险 1：迁移时遗漏某个 `FW4` 项

如果只是机械复制，再手工删改，容易漏掉某些内嵌 `FW4` 覆盖项，造成 `FW4` 文件实际上仍保留 `FW3` 值。

缓解方式：

- 逐设备迁移
- 每迁移一份就跑对应测试
- 用导出后的最终 `.config` 做断言，而不是只看源文件文本

### 风险 2：空 overlay 删除后隐藏真实依赖

当前 `device-overlays/*-FW4.txt` 看起来像空占位，但删除前仍应确认没有测试或脚本硬编码依赖这些路径存在。

缓解方式：

- 先确认 overlay 文件内容为空且未被逻辑强制要求存在
- 使用导出测试验证删除后无行为变化

### 风险 3：同类设备统一时引入跨设备误改

这 6 份设备结构相似，但不是完全相同。批量替换时可能把某台设备独有的 `y/m/n` 差异覆盖掉。

缓解方式：

- 逐文件迁移，不做正则批量改全仓库
- 保留每个设备自己的完整主文件
- 测试按设备分别断言关键值

## 推荐实施顺序

1. 先迁移 `CMIOT-AX18-NOWIFI`
2. 同步修正其 `FW4` 下 `SSR Plus=n`，让现有测试恢复一致
3. 复制同样模式到 `CMIOT-AX18-NOWIFI-MINI`
4. 再迁移 `IPQ60XX-NOWIFI` / `IPQ60XX-NOWIFI-MINI`
5. 最后迁移 `JD-AX1800PRO-WIFI` / `JD-AX1800PRO-NOWIFI`
6. 删除已确认无用的空 `device-overlays/*-FW4.txt`
7. 跑完整的设备级 `fw4` 导出测试

## 结论

对这批同类设备，独立 `FW4` 主文件比在 `FW3` 文件中长期维护内嵌 `FW4` 段更清晰，也更符合 `export_config.sh` 已有的解析优先级。此次改动应聚焦于设备级结构统一和明确的 `FW4` 行为收口，不扩大到仓库级配置分层重构。
