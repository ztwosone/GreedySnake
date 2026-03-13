## [L0-T02] EventBus 全局事件总线

### 元信息

| 字段 | 值 |
|------|-----|
| **阶段** | L0-MVP |
| **优先级** | P0(阻塞) |
| **前置任务** | L0-T01 |
| **预估粒度** | S(< 1h) |
| **分配职能** | 引擎程序 |

### 概述

创建全局事件总线单例，声明 L0-MVP 阶段所需的所有信号。这是系统间解耦通信的唯一通道。

### 上下文

| 文档 | 章节/位置 |
|------|----------|
| `TechDocs/ScriptingLeading.md` | §2.3 EventBus |
| `TechDocs/ScriptingLeading.md` | §4 事件目录 Event Catalog（完整事件列表） |

### 任务详细

1. 创建 `Project/autoloads/event_bus.gd`
2. 在 `project.godot` 中注册为 Autoload，名称 `EventBus`
3. 声明以下 MVP 所需的全部信号（分组注释）

**需要创建的文件：**
- `Project/autoloads/event_bus.gd`

**需要修改的文件：**
- `Project/project.godot` — 添加 EventBus Autoload

### 信号清单（MVP 范围）

按类别分组声明，每个信号附带注释说明参数。

**Tick 生命周期：**

| 信号名 | 参数 | 说明 |
|--------|------|------|
| `tick_pre_process` | `tick_index: int` | Tick 开始前 |
| `tick_input_collected` | `tick_index: int` | 输入收集完毕，触发蛇移动 |
| `tick_post_process` | `tick_index: int` | Tick 结算完毕 |

**蛇相关：**

| 信号名 | 参数 | 说明 |
|--------|------|------|
| `snake_moved` | `data: Dictionary` | 蛇完成一步移动。data = `{ body, direction, head_pos, old_tail_pos }` |
| `snake_turned` | `data: Dictionary` | 蛇改变方向。data = `{ old_dir, new_dir }` |
| `snake_hit_boundary` | `data: Dictionary` | 蛇头撞墙。data = `{ position, direction }` |
| `snake_hit_self` | `data: Dictionary` | 蛇头撞自身。data = `{ position, segment_index }` |
| `snake_hit_enemy` | `data: Dictionary` | 蛇头撞敌人。data = `{ enemy, position }` |
| `snake_food_eaten` | `data: Dictionary` | 蛇吃到食物。data = `{ food, position, food_type }` |
| `snake_died` | `data: Dictionary` | 蛇死亡。data = `{ cause }` |

**长度相关：**

| 信号名 | 参数 | 说明 |
|--------|------|------|
| `snake_length_increased` | `data: Dictionary` | 长度增加。data = `{ amount, source, new_length }` |
| `snake_length_decreased` | `data: Dictionary` | 长度减少。data = `{ amount, source, new_length }` |
| `length_decrease_requested` | `data: Dictionary` | 请求减少长度。data = `{ amount, source }` |
| `length_grow_requested` | `data: Dictionary` | 请求增长。data = `{ amount }` |

**敌人相关：**

| 信号名 | 参数 | 说明 |
|--------|------|------|
| `enemy_killed` | `data: Dictionary` | 敌人被击杀。data = `{ enemy_def, position, method }` |
| `enemy_spawned` | `data: Dictionary` | 敌人生成。data = `{ enemy_def, position }` |

**GridWorld 通用：**

| 信号名 | 参数 | 说明 |
|--------|------|------|
| `entity_moved` | `data: Dictionary` | 实体移动。data = `{ entity, from, to }` |
| `entity_placed` | `data: Dictionary` | 实体放置。data = `{ entity, position }` |
| `entity_removed` | `data: Dictionary` | 实体移除。data = `{ entity, position }` |

**游戏流程：**

| 信号名 | 参数 | 说明 |
|--------|------|------|
| `game_started` | 无 | 游戏开始 |
| `game_over` | `data: Dictionary` | 游戏结束。data = `{ cause, final_length }` |
| `game_restart_requested` | 无 | 请求重新开始 |

### 技术约束

- EventBus 继承 `Node`
- 所有信号使用 `data: Dictionary` 作为唯一参数（保持签名统一，方便扩展）
- 信号命名：`{主语}_{对象}_{动词过去分词}`，小写下划线分隔
- EventBus **只声明信号，不包含任何游戏逻辑**
- 用注释分组：`# === Tick Lifecycle ===`、`# === Snake ===` 等

### 验收标准

- [ ] `event_bus.gd` 存在且包含上述所有信号声明
- [ ] 每个信号有分组注释和参数说明注释
- [ ] `project.godot` 中 `EventBus` 已注册为 Autoload
- [ ] Godot 编辑器打开项目无报错
- [ ] 在任意脚本中可通过 `EventBus.snake_moved.connect(...)` 和 `EventBus.snake_moved.emit(...)` 正常使用

### 备注

- 后续阶段（L1+）会往 EventBus 中追加更多信号（状态效果、鳞片、地图等），但 MVP 阶段只需上述信号
- 所有参数使用 Dictionary 传递而非多参数，这样添加新字段时不会破坏已有监听者的签名
