# Agent 协作全流程指南

> 描述「分发任务给低 tier agent → 等待完成并 push → Opus review」的端到端操作手册。
> 所有操作在 main 分支上进行，不拉分支。

---

## 1. 全流程总览

```
┌─────────────────────────────────────────────────────────────────┐
│                     单任务执行循环                                │
│                                                                 │
│  ① Dispatch ──→ ② Agent 执行 ──→ ③ Verify ──→ ④ Opus Review    │
│                                       │              │          │
│                                       │         ✅ 通过         │
│                                       │              │          │
│                                       │         下一个任务 ──→ ① │
│                                       │                         │
│                                       │         ❌ 打回          │
│                                       │              │          │
│                                       │         ⑤ Fix Agent ──→ │
│                                       │              │          │
│                                       │         新 commit ──→ ③  │
└─────────────────────────────────────────────────────────────────┘
```

**时间线：**

```
main ── [L0-T01] ── review✅ ── [L0-T02] ── review✅ ── [L0-T03] ── review❌ ── [L0-T03-fix] ── review✅ ── ...
```

---

## 2. 模型分配速查表

| 编号 | 任务名 | 模型 | 粒度 | 前置 | 理由 |
|------|--------|------|------|------|------|
| T01 | 项目脚手架与核心常量 | **Haiku** | S | 无 | 机械性目录创建和枚举定义 |
| T02 | EventBus 全局事件总线 | **Haiku** | S | T01 | 照表声明 signal，无逻辑 |
| T03 | TickManager 节拍管理器 | **Sonnet** | M | T01,T02 | Timer + 三阶段 tick 有一定逻辑 |
| T04 | GridWorld 网格世界管理器 | **Opus** | L | T01,T02 | 核心架构，move_entity 回调链复杂 |
| T05 | GridEntity 万物基类 | **Haiku** | M | T01,T04 | 基类模板，字段和虚方法按文档抄写 |
| T06 | Snake 实体与移动系统 | **Opus** | XL | T02~T05 | 最复杂系统，碰撞检测+事件交互 |
| T07 | LengthSystem 长度系统 | **Sonnet** | M | T02,T06 | 单系统，增减逻辑+死亡触发 |
| T08 | Food 食物系统 | **Haiku** | M | T04,T05 | 简单实体+管理器，生成逻辑机械 |
| T09 | 静止敌人与基础战斗 | **Sonnet** | M | T02,T04,T05,T07 | 战斗判定+事件编排有一定复杂度 |
| T10 | 游戏场景组装与视觉层 | **Opus** | L | T01~T09 | 集成任务，需要理解全部子系统 |
| T11 | GameManager 与游戏循环 | **Sonnet** | L | T02,T10 | 状态机+UI 管理，逻辑有深度 |

**执行顺序：** T01 → T02 → T03+T04(可并行) → T05 → T06+T08(可并行) → T07 → T09 → T10 → T11

---

## 3. 阶段一：Dispatch（分发任务）

### 3.1 通用规则

- 每次只分发**一个任务**
- Agent 完成后必须 **commit + push** 到 main
- Commit 消息格式：`[L0-T{xx}] {任务名}`

### 3.2 Dispatch Prompt 模板 — Opus 级

用于 T04、T06、T10。

````
你是一个 Godot 4.6 + GDScript 开发者。

### 项目路径
F:/GreedySnake

### 你的任务
完成任务 [L0-T{xx}]。

### 必读文档（请在开始编码前全部阅读）
1. 任务描述：`Tasks/L0/TaskPool/Task_L0_{xx}.md`
2. 技术指引：`TechDocs/ScriptingLeading.md`（重点阅读 §1 架构总纲、§2 核心抽象层、以及与本任务直接相关的章节）
3. 项目现有代码：先 `git pull` 确保最新，然后浏览 `Project/` 目录了解已有实现

### 编码要求
- 严格遵循 ScriptingLeading.md 的目录结构和命名约定
- 系统间通信只通过 EventBus，不直接引用其他系统
- 使用 GDScript 4.x 语法（@onready, @export, typed arrays, signal name(param: Type)）
- 所有 GridEntity 子类通过 place_on_grid() / remove_from_grid() 管理位置
- queue_free() 前必须先 remove_from_grid()

### 完成后
1. 确认所有验收标准已满足
2. 运行 `git add` 添加新建/修改的文件
3. 运行 `git commit -m "[L0-T{xx}] {任务名}"`
4. 运行 `git push`

### 禁止事项
- 不要修改与本任务无关的已有文件（除非任务描述明确要求）
- 不要修改 project.godot 的 autoload 设置（除非任务描述明确要求）
- 不要删除 Test/ 目录下的测试文件
- 不要引入任何第三方插件
````

### 3.3 Dispatch Prompt 模板 — Sonnet 级

用于 T03、T07、T09、T11。

````
你是一个 Godot 4.6 + GDScript 开发者。

### 项目路径
F:/GreedySnake

### 你的任务
完成任务 [L0-T{xx}]。

### 必读文档（请在开始编码前全部阅读）
1. 任务描述：`Tasks/L0/TaskPool/Task_L0_{xx}.md`（包含完整的步骤、代码片段和验收标准）
2. 技术指引：`TechDocs/ScriptingLeading.md`（重点阅读与本任务相关的章节）
3. 运行 `git pull` 确保代码最新

### 编码要求
- 严格按照任务描述中的代码片段实现，不要自行发挥或过度设计
- 遵循 ScriptingLeading.md 的目录结构（autoloads/, core/, systems/, entities/, scenes/, ui/）
- 系统间通信只通过 EventBus 事件，不直接引用其他系统
- GDScript 4.x 语法要求：
  - `@onready var` 而非 `onready var`
  - `@export var` 而非 `export var`
  - `signal name(param: Type)` 而非 `signal name`
  - 函数返回值类型：`func foo() -> int:`
  - 类型化数组：`var arr: Array[Type] = []`
- 枚举引用格式：`Constants.EntityType.FOOD`（不是 `EntityType.FOOD`）

### 完成后
1. 对照任务描述中的验收标准逐项确认
2. 运行 `git add` 添加新建/修改的文件
3. 运行 `git commit -m "[L0-T{xx}] {任务名}"`
4. 运行 `git push`

### 禁止事项
- 不要修改与本任务无关的已有文件
- 不要修改 project.godot 的 autoload 设置（除非任务描述明确要求）
- 不要引入任何第三方插件
- 不要添加任务描述中未要求的额外功能
````

### 3.4 Dispatch Prompt 模板 — Haiku 级

用于 T01、T02、T05、T08。Haiku 对 GDScript 4.x 语法掌握较弱，需附加语法参考。

````
你是一个 Godot 4.6 + GDScript 开发者。

### 项目路径
F:/GreedySnake

### 你的任务
完成任务 [L0-T{xx}]。

### 必读文档
1. 任务描述：`Tasks/L0/TaskPool/Task_L0_{xx}.md`
2. 技术指引：`TechDocs/ScriptingLeading.md`（阅读与本任务相关的章节）
3. 运行 `git pull` 确保代码最新

### ⚠️ GDScript 4.x 语法速查（必须严格遵守）

```gdscript
# ---- 变量声明 ----
@onready var label: Label = $Label          # 不是 onready var
@export var speed: float = 1.0              # 不是 export var
var items: Array[String] = []               # 类型化数组
var grid: Dictionary = {}                   # Dictionary 不支持泛型

# ---- 信号声明 ----
signal my_signal(data: Dictionary)          # 不是 signal my_signal
signal game_started                          # 无参信号

# ---- 枚举 ----
enum Direction { UP, DOWN, LEFT, RIGHT }    # 枚举定义
Constants.Direction.UP                       # 跨脚本引用枚举

# ---- 函数 ----
func get_value() -> int:                    # 必须声明返回值类型
    return 42

func _ready() -> void:                     # 生命周期函数也要标返回值
    EventBus.my_signal.connect(_on_my_signal)

# ---- 常见错误 ❌ ----
# onready var x = $Node           → 应为 @onready var x = $Node
# export var x = 1                → 应为 @export var x = 1
# yield(...)                       → 4.x 中已移除，使用 await
# connect("signal", self, "func") → 应为 signal.connect(func)
```

### 编码要求
- **严格按照任务描述中的代码片段实现**，逐行对照，不要自行修改
- 目录结构遵循 ScriptingLeading.md（autoloads/, core/, systems/, entities/）
- 系统间通信只通过 EventBus
- 枚举引用必须带完整路径：`Constants.EntityType.FOOD`

### 完成后
1. 对照任务描述中的验收标准逐项确认
2. 运行 `git add` 添加新建/修改的文件
3. 运行 `git commit -m "[L0-T{xx}] {任务名}"`
4. 运行 `git push`

### 禁止事项
- 不要修改与本任务无关的已有文件
- 不要修改 project.godot 的 autoload 设置（除非任务描述明确要求）
- 不要引入任何第三方插件
- 不要使用 GDScript 3.x 的旧语法
- 不要添加任务描述中未要求的额外功能
````

---

## 4. 阶段二：Verify（确认提交）

Agent 完成任务后，在本地终端执行以下命令确认：

```bash
# 1. 拉取最新代码
cd F:/GreedySnake
git pull

# 2. 检查最新 commit 消息格式是否正确
git log --oneline -3

# 期望看到类似：
# a1b2c3d [L0-T01] 项目脚手架与核心常量

# 3. 检查改动的文件列表是否合理
git diff HEAD~1 --stat

# 4. 如果 commit 消息格式不对或文件有问题，让 agent 修复后重新 commit
```

**检查清单：**

- [ ] Commit 消息格式为 `[L0-T{xx}] {任务名}`
- [ ] 改动的文件在预期目录下
- [ ] 没有意外修改无关文件
- [ ] 没有提交敏感信息或临时文件

---

## 5. 阶段三：Review（Opus 审查）

### 5.1 操作步骤

1. 确保本地代码已是最新（`git pull`）
2. 启动一个 **Opus** 级 Claude Code 会话
3. 发送以下 Review prompt（将 `{xx}` 替换为任务编号）

### 5.2 Review Prompt

直接复制 `Tasks/ReviewTemplate.md` 中的「Review 指令」部分，替换 `{xx}` 后发送即可。

完整指令见 `Tasks/ReviewTemplate.md`，核心步骤为：

1. `git diff HEAD~1` 查看改动
2. 阅读 `Tasks/L0/TaskPool/Task_L0_{xx}.md`
3. 阅读 `TechDocs/ScriptingLeading.md` 相关章节
4. 按 5 个维度检查：任务完整性、架构合规性、GDScript 正确性、事件契约、边界安全

### 5.3 Review 输出

Opus 会输出结构化的 Review 结果，包含：

- **总结果：** ✅ 通过 / ❌ 打回
- **各维度评分表**
- **Blocking 修改**（必须修复）
- **Non-blocking 建议**（可选修复）
- **可选优化**（不影响验收）

---

## 6. 阶段四：Resolve（处理结果）

### 6.1 ✅ 通过

直接进入下一个任务的 Dispatch 阶段（回到第 3 节）。

### 6.2 ❌ 打回

需要让原 agent（或同级 agent）修复 Blocking 问题。

#### Fix Prompt 模板

将 `{BLOCKING_ITEMS}` 替换为 Opus Review 输出的「必须修改」原文：

````
你是一个 Godot 4.6 + GDScript 开发者。

### 项目路径
F:/GreedySnake

### 背景
任务 [L0-T{xx}] 的代码已提交，但 Code Review 发现以下必须修改的问题。

### 必须修改的问题

{BLOCKING_ITEMS}

### 修复要求
1. 运行 `git pull` 确保代码最新
2. 阅读任务描述：`Tasks/L0/TaskPool/Task_L0_{xx}.md`
3. 逐项修复上述问题
4. 确认修复后不引入新问题
5. 运行 `git add` 添加修改的文件
6. 运行 `git commit -m "[L0-T{xx}-fix] 修复 review 问题"`
7. 运行 `git push`

### 禁止事项
- 只修复上述列出的问题，不要做额外改动
- 不要修改与修复无关的文件
````

Fix commit 提交后，回到阶段二（Verify）重新走一遍 Verify → Review 流程。

---

## 7. L0 执行检查表

按顺序执行，每完成一个任务勾选：

| 序号 | 任务 | 模型 | Dispatch | Verify | Review | 状态 |
|------|------|------|----------|--------|--------|------|
| 1 | T01 项目脚手架与核心常量 | Haiku | [ ] | [ ] | [ ] | ⬜ |
| 2 | T02 EventBus 全局事件总线 | Haiku | [ ] | [ ] | [ ] | ⬜ |
| 3a | T03 TickManager 节拍管理器 | Sonnet | [ ] | [ ] | [ ] | ⬜ |
| 3b | T04 GridWorld 网格世界管理器 | Opus | [ ] | [ ] | [ ] | ⬜ |
| 4 | T05 GridEntity 万物基类 | Haiku | [ ] | [ ] | [ ] | ⬜ |
| 5a | T06 Snake 实体与移动系统 | Opus | [ ] | [ ] | [ ] | ⬜ |
| 5b | T08 Food 食物系统 | Haiku | [ ] | [ ] | [ ] | ⬜ |
| 6 | T07 LengthSystem 长度系统 | Sonnet | [ ] | [ ] | [ ] | ⬜ |
| 7 | T09 静止敌人与基础战斗 | Sonnet | [ ] | [ ] | [ ] | ⬜ |
| 8 | T10 游戏场景组装与视觉层 | Opus | [ ] | [ ] | [ ] | ⬜ |
| 9 | T11 GameManager 与游戏循环 | Sonnet | [ ] | [ ] | [ ] | ⬜ |

**状态图例：** ⬜ 未开始 | 🔄 进行中 | ✅ Review 通过 | ❌ 被打回修复中

**注意：** 3a/3b 可并行执行，5a/5b 可并行执行。其余必须串行。

---

## 8. 快速参考

### 一句话流程

```
Dispatch prompt → Agent 写代码 commit push → git pull 验证 → Opus review → 通过则下一个 / 打回则 fix
```

### 关键文件路径

| 用途 | 路径 |
|------|------|
| 任务描述 | `Tasks/L0/TaskPool/Task_L0_{xx}.md` |
| 技术指引 | `TechDocs/ScriptingLeading.md` |
| Review 模板 | `Tasks/ReviewTemplate.md` |
| 任务总览 | `Tasks/L0/L0_Overview.md` |
| 本文档 | `Tasks/AgentWorkflow.md` |
