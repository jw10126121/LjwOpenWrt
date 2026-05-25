# 编译通知与配置 Artifact 收敛设计

## 目标

收敛 `CORE-ALL` 工作流中的“配置快照 + 配置 Artifact + 最终通知复用快照”链路，解决两个问题：

- 编译完成推送中出现两次 `编译开始`
- 编译前上传配置文件到 Artifact 的步骤已不再需要

## 当前问题

当前实现中，`.github/workflows/CORE-ALL.yml` 会在编译前执行一段“缓存配置文件”逻辑：

- 生成 `config_mine/` 目录
- 导出 `.config`、`seed.config`、`my_config.txt`
- 调用 `scripts/readme.sh` 生成 `config_mine/readme.txt`
- 将这份正文保存到 `system_content_note`
- 再把整个 `config_mine/` 上传到 GitHub Actions Artifact

编译结束后的通知由 `scripts/ci_create_notifications.sh` 生成，但它优先复用 `system_content_note` 或 `readme_desc_file`。由于 `system_content_note` 本身已经包含一行 `编译开始`，脚本末尾又追加一次：

- `编译开始：${START_TIME}`

因此最终推送会出现两次相同的开始时间。

这条链路的问题不只是重复文案，还包括职责耦合：

- 最终通知依赖编译前落盘的中间文件
- 配置 Artifact 只是为了顺带保留通知快照
- `Check Config` 步骤同时承担“导出配置”“生成开始通知”“为结束通知准备正文”三种职责

## 设计目标

1. 删除编译前配置快照文件与配置 Artifact 上传逻辑。
2. 最终通知不再依赖 `config_mine/readme.txt`、`readme_desc_file`、`system_content_note`。
3. 成功/失败通知仍保留现有核心信息：
   - 下载地址
   - 编译说明
   - 插件清单
   - 编译状态
   - 开始/结束时间
4. 最终推送中只能出现一次 `编译开始`。

## 非目标

本次改动不包括：

- 修改发布产物命名规则
- 调整 DingTalk 发送方式
- 重写 `scripts/readme.sh` 的插件解析逻辑
- 删除编译结束后用于 release / artifact 的固件整理逻辑

## 方案

### 1. 删除前置配置快照链路

从 `.github/workflows/CORE-ALL.yml` 中移除以下行为：

- 生成 `config_mine/`
- 拷贝 `.config`、`seed.config`、`my_config.txt`
- 调用 `scripts/readme.sh` 生成 `config_mine/readme.txt`
- 写入 `readme_desc_file`
- 写入 `system_content_note`
- `Upload Config (上传配置文件)` 步骤

开始编译前的 DingTalk 通知仍可直接基于 `system_content` 发送，不再依赖 `readme.txt` 文件。

### 2. 最终通知改为独立生成

`scripts/ci_create_notifications.sh` 不再优先读取：

- `system_content_note`
- `readme_desc_file`

最终通知正文改为从编译结束后的稳定来源生成。推荐优先顺序：

1. 若存在编译结束后生成的发布说明文件，则直接读取该文件正文。
2. 若不存在，则回退到 `system_content`。

这样最终通知依赖的是“编译结束后的整理结果”，而不是编译前临时快照。

### 3. 去掉重复的开始时间追加

最终通知正文如果来自已包含开始时间的正文模板，则脚本末尾不应再次无条件追加 `编译开始`。

实现上应确保：

- 正文主体只保留一处 `编译开始`
- 脚本仍追加 `编译状态` 与 `编译结束`
- `编译开始` 由正文主体负责，避免正文与尾部同时写入

## 数据流

调整后的数据流：

1. 编译前：
   - workflow 组装 `system_content`
   - 直接发送开始通知
2. 编译中：
   - 正常编译、整理产物
3. 编译后：
   - `scripts/ci_organize_outputs.sh` / 现有产物整理逻辑生成最终说明文件
   - `scripts/ci_create_notifications.sh` 读取最终说明文件或 `system_content`
   - 拼接下载地址、编译状态、开始/结束时间
   - 发送完成通知

## 测试设计

更新 `scripts/tests/test_notification_format.sh`，覆盖以下断言：

- 成功通知包含 `Artifact下载地址`
- 成功通知只出现一次 `编译开始：<START_TIME>`
- 成功通知包含插件清单
- 成功通知不再依赖 `readme_desc_file` 或 `system_content_note`
- 失败通知不包含下载地址
- 失败通知仍包含编译说明、状态、开始/结束时间

如有必要，可补一个 workflow 级测试，断言 `CORE-ALL.yml` 中已不存在 `Upload Config (上传配置文件)` 步骤。

## 风险与控制

### 风险 1：去掉 `readme.txt` 后最终通知丢失插件列表

控制方式：

- 优先复用编译结束后已有的发布说明文件
- 如果该文件不是当前稳定来源，再把插件清单生成逻辑迁到结束阶段，而不是继续依赖前置快照

### 风险 2：失败通知来源变化导致内容缩水

控制方式：

- 失败场景回退到 `system_content`
- 通过测试显式锁定失败通知仍包含编译说明与时间字段

### 风险 3：工作流删除步骤后残留环境变量引用

控制方式：

- 一并清理 `readme_desc_file`、`system_content_note`、`config_upload` 等无用引用
- 用脚本测试和文本检索确认没有残留依赖
