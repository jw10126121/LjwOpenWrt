# OpenWrt Cache Strategy Design

**Date:** 2026-04-23

**Status:** Proposed

**Goal**

让当前 GitHub Actions 编译流程在“同设备、小改动反复试编”的场景下尽量复用已有缓存，重点缩短后续编译时间，同时避免引入高风险的脏产物复用。

本次设计的目标不是覆盖所有缓存可能性，而是先把当前已经存在但效果不稳定的缓存链修成三件事：

- 能稳定恢复
- 能稳定保存
- 小改动时能持续命中

## Current State

当前 workflow 已经有两层缓存：

- [`toolchain` 缓存](/Users/lin/Documents/Git/Linjw/LjwOpenWrt/.github/workflows/CORE-ALL.yml:240)
  - 路径为 `staging_dir/host*` 与 `staging_dir/tool*`
- [`ccache` 缓存](/Users/lin/Documents/Git/Linjw/LjwOpenWrt/.github/workflows/CORE-ALL.yml:249)
  - 路径为 `.ccache`

但现状有三个问题：

1. `toolchain` key 绑定 `REPO_GIT_hash_simple`
   - 同设备的小改动会频繁 miss
   - 实际上与用户想要的“尽量复用”目标冲突

2. 当前缓存使用 `actions/cache` 单步 restore/save
   - 在一次 run 结束时容易遇到 `Unable to reserve cache`，导致首次编译虽然产出了缓存内容，但没有真正保存成功

3. 缺少 `dl` 缓存
   - `make download` 不是最大瓶颈，但仍然会重复消耗几分钟

日志证据已经表明问题集中在命中和保存策略，而不是缓存路径本身：

- `toolchain` miss：`toolchain-Linux-ipq60xx-lede-master-195fd0ec`
- `ccache` miss：`ccache-Linux-ipq60xx-lede-master`
- `.ccache` 在编译结束时已有 `775M`
- 结束时保存失败：
  - `Failed to save: Unable to reserve cache with key ccache-Linux-ipq60xx-lede-master`
  - `Failed to save: Unable to reserve cache with key toolchain-Linux-ipq60xx-lede-master-195fd0ec`

## Requirements

### Functional Requirements

1. 同设备、小改动的后续编译应尽量命中缓存
2. 首次编译完成后应能稳定把缓存保存下来
3. workflow 新增 `dl` 缓存
4. 需要保留手动整体失效缓存的入口
5. 不改变现有 OpenWrt 编译命令和固件产物逻辑

### Non-Functional Requirements

1. 不缓存高风险目录，例如 `build_dir` 和 `staging_dir/target-*`
2. 不能因为宽复用而跨架构、跨包管理格式错误命中
3. key 规则应可读、可解释、可手动失效
4. 需要有脚本测试约束 workflow 中的关键缓存策略

## Design Decision

采用“**三层缓存 + restore/save 分离 + 手动 epoch 失效**”的策略。

三层缓存分别为：

1. `dl`
2. `toolchain`
3. `ccache`

同时明确不缓存：

- `build_dir`
- `staging_dir/target-*`
- `bin`
- `tmp`

这是当前目标下最稳的折中方案，因为它：

- 保留 `toolchain` 的加速价值，但不把边界扩展到 target 产物
- 允许 `ccache` 在同设备小改动中持续复用
- 用 restore/save 分离规避首次编译结束时的 cache reserve 冲突

## Architecture

### 1. Global Cache Version Knob

在 workflow 顶层环境变量中新增：

- `CACHE_EPOCH: v1`

它是唯一的手动全局失效旋钮。

当出现以下情况时，只需提升这个值，例如从 `v1` 改到 `v2`：

- 上游源码线发生明显变化
- toolchain 复用开始不稳定
- 需要主动放弃旧缓存重新种一套

这样比把 `commit hash` 永久塞进 key 更适合“小改动尽量复用”的目标。

### 2. dl Cache

#### Path

- `$OPENWRT_PATH/dl`

#### Key

- 主 key：
  - `dl-${{ runner.os }}-${{ env.WRT_VER }}-${{ env.WRT_USE_APK }}-${{ env.CACHE_EPOCH }}`
- restore 前缀：
  - `dl-${{ runner.os }}-${{ env.WRT_VER }}-${{ env.WRT_USE_APK }}-`

#### Rationale

`dl` 中的源码包和工具包主要受源码线与包管理模式影响，与具体设备配置关联较弱，因此适合宽复用。

### 3. toolchain Cache

#### Path

- `$OPENWRT_PATH/staging_dir/host*`
- `$OPENWRT_PATH/staging_dir/tool*`

#### Key

- 主 key：
  - `toolchain-${{ runner.os }}-${{ env.WRT_VER }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_USE_APK }}-${{ env.CACHE_EPOCH }}`
- restore 前缀：
  - `toolchain-${{ runner.os }}-${{ env.WRT_VER }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_USE_APK }}-`

#### Rationale

`toolchain` 需要保留子目标和包格式边界，避免跨架构和跨 `ipk/apk` 误命中，但不再绑定单个源码 commit。

这意味着：

- 同一源码线、同一设备子目标的小改动可以命中
- 真正需要整体失效时，通过 `CACHE_EPOCH` 处理

### 4. ccache Cache

#### Path

- `$OPENWRT_PATH/.ccache`

#### Restore Key Strategy

- restore 前缀：
  - `ccache-${{ runner.os }}-${{ env.WRT_VER }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_USE_APK }}-`

#### Save Key Strategy

- save key：
  - `ccache-${{ runner.os }}-${{ env.WRT_VER }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_USE_APK }}-${{ github.run_id }}-${{ github.run_attempt }}`

#### Rationale

`ccache` 的目标是尽量宽恢复，因为它本身已经会按源码内容、编译参数和头文件决定命中与否。

这里不应再用固定 save key，否则首次构建完成后容易遇到：

- 当前 job 想保存
- 另一个 job 已占用相同 key
- 整次缓存写回失败

改成“宽 restore、唯一 save”后：

- 后续 run 仍能从旧缓存前缀恢复
- 当前 run 保存时不会抢同一个固定 key

### 5. Cache Action Structure

当前 workflow 使用 `actions/cache@v5` 单步完成 restore/save。本次改为显式分离：

1. 构建前使用 `actions/cache/restore`
2. 构建后使用 `actions/cache/save`

每一层缓存都遵循这个模式：

- restore 阶段尽早恢复
- save 阶段只在路径存在时写回

这样可以让 workflow 行为更可预测，也更容易从日志中判断：

- 是否恢复成功
- 是否实际生成了缓存内容
- 是否保存成功

## Commit Hash Policy

本次设计明确不把 `commit hash` 作为 `toolchain` 和 `ccache` 的默认 key 维度。

### Why Not Use Commit Hash By Default

如果把 `commit hash` 固定放进 key：

- `toolchain` 会在同设备小改动时频繁 miss
- `ccache` 会失去“跨相近改动复用”的主要价值

这与本次目标相反。

### When Commit Hash Would Be Appropriate

`commit hash` 只适合以下场景：

1. 需要严格隔离某一版源码对应的 `toolchain`
2. 调试缓存污染问题，需要缩小变量范围
3. 临时验证某一批上游变更是否破坏了缓存复用

这些都属于例外情况，不应作为本次默认设计。

## External Reference Notes

本次设计额外参考了 `sbwml/builder` 的公开 workflow：

- [sbwml/builder build-release.yml](https://github.com/sbwml/builder/blob/main/.github/workflows/build-release.yml)

参考结论不是“整体迁移到 sbwml 的构建方式”，而是只提取对当前仓库有直接价值的缓存经验。

### Worth Borrowing

1. `ccache` 恢复优先于复杂的 toolchain 加速技巧
   - `sbwml` 的公开 workflow 明确把 `.ccache` 恢复作为加速入口之一
   - 这说明在 OpenWrt 的反复试编场景里，`.ccache` 的收益通常稳定且容易观察

2. restore/save 分离比单步 `actions/cache` 更可控
   - 公开 workflow 已使用 `actions/cache/restore`
   - 这与本设计优先解决“首次编译后缓存未成功写回”的方向一致

3. cache 需要可观察性
   - 参考 workflow 在恢复 `.ccache` 后会输出缓存体积
   - 当前仓库也应补上 restore 后和编译后的 cache 体积日志，必要时输出 `ccache -s`

### Not Worth Copying Directly

1. 不直接照搬其全部构建加速开关
   - 公开 workflow 中的 `BUILD_FAST`、`ENABLE_MOLD`、`USE_GCC15`、`ENABLE_LTO` 等开关，真正行为依赖远端脚本
   - 仅从 YAML 入口无法证明这些选项对当前 lean 流程安全且有效

2. 不把当前仓库直接改成“只依赖 `.ccache`”
   - 当前仓库已经存在 `toolchain` 缓存结构
   - 本次目标仍然是保留 `toolchain + ccache + dl` 三层缓存，而不是退回单层缓存

3. 不在第一阶段引入 release asset 作为主要缓存介质
   - `sbwml` 的某些 `.ccache` 恢复逻辑依赖 release 资产
   - 这可以作为后续备选方案，但不应替代当前基于 `actions/cache` 的第一阶段实现

### Impact On This Design

外部参考不会改变本设计的主决策，但会补充两条实现建议：

1. 在 `ccache` restore/save 步骤中增加显式体积日志
2. 如果 GitHub Actions cache 对 `.ccache` 的稳定性仍不足，再单独评估“release asset 恢复 `.ccache`”作为第二阶段方案

## Out of Scope

以下内容不属于本次设计范围：

- 缓存 `build_dir`
- 缓存 `staging_dir/target-*`
- 缓存 `bin`、`logs`、`upload`
- 重新设计 OpenWrt 编译步骤
- 引入第三方自定义缓存 action 替代 `actions/cache`

## Testing Plan

需要更新和新增的测试分为两类。

### 1. Update Existing Cache Key Test

更新 [`Scripts/tests/test_workflow_cache_keys.sh`](/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Scripts/tests/test_workflow_cache_keys.sh:1)，使其覆盖：

1. `toolchain` key 不再包含 `REPO_GIT_hash_simple`
2. `toolchain` key 包含 `CACHE_EPOCH`
3. `ccache` 改为 restore/save 分离
4. `ccache restore` 使用宽前缀
5. `ccache save` 使用 `github.run_id` 与 `github.run_attempt`

### 2. Add dl Cache Test

新增一条 workflow 测试，覆盖：

1. 存在 `dl` restore step
2. 存在 `dl` save step
3. `dl` key 包含 `WRT_VER`、`WRT_USE_APK`、`CACHE_EPOCH`
4. `dl` 不按设备 commit 精确绑定

## Rollout Plan

第一阶段：

1. 在 workflow 顶层新增 `CACHE_EPOCH`
2. 引入 `dl` 缓存
3. 把 `toolchain`、`ccache` 从单步 `cache` 改为 restore/save 分离

第二阶段：

1. 调整 `toolchain` key 为“设备子目标 + 源码线 + 包格式 + epoch”
2. 调整 `ccache` 为“宽 restore、唯一 save”
3. 保留现有 `Refresh Cache Metadata` 逻辑，验证其仍然适配新的缓存结构

第三阶段：

1. 更新现有 workflow cache 测试
2. 新增 `dl` cache 测试
3. 在真实 workflow 中观察至少两次连续构建：
   - 第一次成功保存
   - 第二次命中 restore

## Risks

1. `toolchain` 宽复用后，如果上游 host/tool 变化较大，可能需要通过 `CACHE_EPOCH` 手动失效
2. `actions/cache/save` 的路径存在性判断若处理不当，可能在无内容时产生无效步骤
3. `ccache` 前缀恢复后缓存条目会逐步积累，需要后续观察 GitHub cache 配额

## Recommendation

按以下顺序实现：

1. 先改 `actions/cache` 的 restore/save 结构，优先解决“首次编译后没有把缓存种下去”的问题
2. 再调整 `toolchain` 和 `ccache` key 粒度，匹配“小改动尽量复用”的目标
3. 最后补齐 workflow 测试，并通过连续两次 CI 运行验证实际命中效果
