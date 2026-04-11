# AI 开发指引

## 强制工作流：设计先行

**任何不符合当前设计文档的代码修改，必须遵循以下流程：**

1. **识别冲突** — 发现代码修改会偏离设计文档中的描述
2. **暂停编码** — 不要直接写代码
3. **向用户确认** — 明确说明"这个修改与设计文档 X 的 Y 部分不一致，是否要修改设计？"
4. **用户确认后，先改设计** — 更新对应的设计文档
5. **再改代码** — 设计文档更新完毕后，才开始编写/修改代码
6. **同步事实摘要** — 设计文档和代码改完后，更新 `TechDocs/QuickReference.md`

**绝不允许：** 代码已经改了但设计文档还是旧的。设计文档是项目的 single source of truth。

## 环境路径同步

项目环境路径统一记录在 `EnvPath.json`。**任何改动涉及以下内容时，必须同步更新 `EnvPath.json`：**

- Godot 版本升级或可执行文件路径变更
- 项目目录结构调整（工程根目录、测试入口等）
- 新增/移除外部工具（MCP、插件等）
- 配置文件路径变更（game_config.json 等）

## 文档体系

| 层级 | 路径 | 用途 |
|------|------|------|
| 设计文档（source of truth） | `Designs/` + `TechDocs/ScriptingLeading.md` | 完整系统设计与技术架构 |
| 事实摘要（速查） | `TechDocs/QuickReference.md` | 当前实现状态的精简索引 |
| 每日日志 | `DailyLogs/` | 每日开发记录 |
| 任务总览 | `Tasks/` | 里程碑任务分解（L0-L2） |
| SpecKit 规格 | `.specify/specs/` | L3+ 功能规格与任务 |

## 开发规范

- TDD 流程：先写失败测试（Red）→ 最小实现（Green）→ 重构（Refactor）→ 全量回归
- 系统间通过 EventBus 通信，不直接持有引用
- 所有数值配置走 JSON，不硬编码
- GDScript 命名用 snake_case，类名用 PascalCase

## SpecKit 工作流（L3+）

新功能开发遵循 SpecKit 六阶段流程：
1. `/speckit-specify` — 定义需求规格
2. `/speckit-clarify` — 澄清歧义点（可选）
3. `/speckit-plan` — 技术方案设计
4. `/speckit-tasks` — 任务分解
5. `/speckit-implement` — 逐任务实现
6. `/speckit-checklist` — 质量验证（可选）

规格文件在 `.specify/specs/` 下按 Feature 组织。项目宪法在 `.specify/memory/constitution.md`。

L0-L2 历史设计和任务保留在 `Designs/` 和 `Tasks/`，不迁移。

## 快捷命令

| 命令 | 用途 |
|------|------|
| `/test` | 运行测试套件 |
| `/ship <msg>` | 测试 + 提交 + 推送 |
| `/dailylog` | 生成每日开发日志 |
| `/uid` | 补全缺失 .uid 文件 |
| `/syncdocs` | 同步 QuickReference 和 L2_Overview |
| `/speckit-specify` | SpecKit: 创建功能规格 |
| `/speckit-plan` | SpecKit: 技术方案 |
| `/speckit-tasks` | SpecKit: 任务分解 |
| `/speckit-implement` | SpecKit: 逐任务实现 |
