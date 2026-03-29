# GreedySnake Roguelite — 技术实现指引

**版本：** 0.1
**对应设计文档：** `Designs/General/snake_roguelite_design.md`
**技术栈：** Godot 4.6 + GDScript
**阅读对象：** 程序开发人员、AI Coding 模型

> **重要：** 本文档是开发指引，不包含具体代码实现。所有开发任务应基于本文档拆分 ticket。
> 本文档假定读者有 Godot 4.x 和 GDScript 基础知识。
> 本文档中所有命名约定使用 `snake_case`（与 GDScript 惯例一致）。

---

## 目录

1. [项目概览 & 架构总纲](#1-项目概览--架构总纲)
2. [核心抽象层](#2-核心抽象层)
3. [系统实现指引](#3-系统实现指引)
4. [事件目录 Event Catalog](#4-事件目录-event-catalog)
5. [数据配置方案](#5-数据配置方案)
6. [MVP 里程碑定义](#6-mvp-里程碑定义)

---

## 1. 项目概览 & 架构总纲

### 1.1 四大核心理念

| 理念 | 含义 | 在本项目中的体现 |
|------|------|----------------|
| **Grid-based** | 所有游戏逻辑在离散网格上运行 | 32×32 像素/格；所有位置用 `Vector2i` 表示；不存在亚格级运动 |
| **Tick-driven** | 游戏按固定节拍推进 | 基础 tick = 0.25s；所有移动、状态结算在 tick 边界发生 |
| **Event-driven** | 系统间通过事件解耦 | 中央 EventBus 单例；系统只监听/发射事件，不直接引用其他系统 |
| **Data-driven** | 内容通过数据定义，不硬编码 | Resource (.tres) 定义实体类型；JSON 文件管理数值调参 |

### 1.2 项目目录结构

```
Project/
├── project.godot
├── autoloads/                  # Autoload 单例脚本
│   ├── event_bus.gd
│   ├── tick_manager.gd
│   ├── grid_world.gd
│   └── game_manager.gd
├── core/                       # 核心抽象层
│   ├── grid_entity.gd          # GridEntity 基类
│   ├── state_machine.gd        # 通用状态机
│   └── helpers/                # 工具函数
├── systems/                    # 游戏系统
│   ├── movement/
│   ├── length/
│   ├── status_effect/
│   ├── snake_parts/            # 蛇头/蛇尾
│   ├── scales/                 # 蛇鳞
│   ├── enemy/
│   ├── map/
│   ├── event_encounter/        # 事件系统（避免与 EventBus 混淆）
│   ├── growth/
│   ├── difficulty/
│   └── meta_growth/
├── entities/                   # 具体实体场景
│   ├── snake/
│   ├── enemies/
│   ├── foods/
│   ├── terrain/
│   └── status_tiles/
├── ui/
├── data/                       # 数据配置
│   ├── resources/              # .tres Resource 文件
│   │   ├── scales/
│   │   ├── enemies/
│   │   ├── snake_heads/
│   │   ├── snake_tails/
│   │   └── status_effects/
│   └── json/                   # JSON 调参文件
│       ├── balance.json
│       ├── reaction_table.json
│       └── loot_tables.json
└── scenes/                     # 场景文件
    ├── main.tscn
    ├── game_world.tscn
    └── rooms/
```

### 1.3 场景树结构

```
Main (Node)
├── GameManager (autoload)
├── EventBus (autoload)
├── TickManager (autoload)
├── GridWorld (autoload)
│
└── GameWorld (Node2D)                    # 当前游戏世界根节点
    ├── Camera2D
    ├── GridVisual (Node2D)               # Grid 视觉层
    │   ├── TerrainLayer (TileMapLayer)   # 地形渲染
    │   └── StatusTileLayer (Node2D)      # 状态格渲染
    ├── EntityContainer (Node2D)          # 所有 GridEntity 的父节点
    │   ├── Snake (Node2D)                # 蛇整体控制器
    │   ├── EnemyContainer (Node2D)
    │   ├── FoodContainer (Node2D)
    │   └── PickupContainer (Node2D)
    ├── EffectsLayer (Node2D)             # 粒子、特效
    └── UI (CanvasLayer)
```

### 1.4 Autoload 单例清单

| 单例名 | 脚本路径 | 职责 |
|--------|---------|------|
| `EventBus` | `autoloads/event_bus.gd` | 全局事件总线，所有系统间通信的唯一通道 |
| `TickManager` | `autoloads/tick_manager.gd` | 管理游戏 tick 节奏，暂停/恢复，速度修改 |
| `GridWorld` | `autoloads/grid_world.gd` | Grid 数据管理，坐标查询，实体注册/查询 |
| `GameManager` | `autoloads/game_manager.gd` | 游戏状态（标题/运行/暂停/死亡），Run 级全局数据 |

---

## 2. 核心抽象层

> **设计哲学：** 因为是 grid-based 游戏，蛇身段、敌人、食物、状态格、地形障碍在本质上都是「占据 Grid 上一个或多个格子的东西」。它们共享位置管理、碰撞标记、视觉表现等通用行为，因此统一继承自 `GridEntity`。

### 2.1 GridEntity — 万物基类

**文件：** `core/grid_entity.gd`
**继承：** `Node2D`

GridEntity 是所有存在于 Grid 上的实体的基类。

**核心属性：**

| 属性 | 类型 | 说明 |
|------|------|------|
| `grid_position` | `Vector2i` | 当前所在格子坐标 |
| `entity_type` | `EntityType` (enum) | SNAKE_SEGMENT / ENEMY / FOOD / TERRAIN / STATUS_TILE / PICKUP / BUILDING |
| `blocks_movement` | `bool` | 是否阻挡其他实体移动到此格 |
| `is_solid` | `bool` | 是否参与碰撞判定（`false` = 可穿过，如虚化状态） |
| `cell_layer` | `int` | 同一格子上的层级（地面效果 < 实体 < 飞行实体） |

**核心方法（虚方法，子类 override）：**

| 方法 | 说明 |
|------|------|
| `_on_entity_enter(other: GridEntity)` | 当另一个实体进入本格时调用 |
| `_on_entity_exit(other: GridEntity)` | 当另一个实体离开本格时调用 |
| `_on_tick()` | 每个 tick 被调用 |
| `_on_stepped_on(stepper: GridEntity)` | 当本实体被另一实体「踩过」时调用 |
| `place_on_grid(pos: Vector2i)` | 将实体放置到 Grid 上（自动注册到 GridWorld） |
| `remove_from_grid()` | 从 Grid 上移除 |

**GridEntity 与 GridWorld 的关系：**
- GridEntity 创建时不自动注册，需显式调用 `place_on_grid()`
- `place_on_grid()` 内部调用 `GridWorld.register_entity(self, pos)`
- 移动时调用 `GridWorld.move_entity(self, old_pos, new_pos)`，GridWorld 负责触发 enter/exit 回调
- 销毁时调用 `remove_from_grid()`，内部调用 `GridWorld.unregister_entity(self)`

### 2.2 GridWorld — Grid 管理器

**文件：** `autoloads/grid_world.gd`
**性质：** Autoload 单例

GridWorld 管理整个 Grid 的数据层。它不负责渲染，只负责「谁在哪」。

**核心数据结构：**

```
cell_map: Dictionary[Vector2i, Array[GridEntity]]
# 每个格子坐标映射到一个实体数组（同一格可有多个实体，如状态格+食物）
```

**核心方法：**

| 方法 | 说明 |
|------|------|
| `register_entity(entity, pos)` | 将实体注册到指定格子 |
| `unregister_entity(entity)` | 移除实体注册 |
| `move_entity(entity, from, to)` | 移动实体，触发 enter/exit 回调链 |
| `get_entities_at(pos) -> Array[GridEntity]` | 查询某格所有实体 |
| `get_entities_of_type(pos, type) -> Array[GridEntity]` | 查询某格特定类型实体 |
| `is_cell_blocked(pos) -> bool` | 某格是否被阻挡实体占据 |
| `is_within_bounds(pos) -> bool` | 是否在地图边界内 |
| `get_neighbors(pos) -> Array[Vector2i]` | 获取四方向相邻格子 |
| `get_neighbors_8(pos) -> Array[Vector2i]` | 获取八方向相邻格子 |
| `find_path(from, to, ...) -> Array[Vector2i]` | 简单 A* 寻路（供敌人 AI 使用） |

**move_entity 的回调链（关键！）：**

当调用 `move_entity(entity, from, to)` 时，按以下顺序执行：

1. 从 `cell_map[from]` 中移除 entity
2. 对 `cell_map[from]` 中剩余实体调用 `_on_entity_exit(entity)`
3. 将 entity 加入 `cell_map[to]`
4. 对 `cell_map[to]` 中已有实体调用 `_on_entity_enter(entity)`
5. 对 entity 调用 `_on_stepped_on()` 如果 to 位置有地面实体
6. 发射 `EventBus.entity_moved` 事件
7. 更新 entity 的 `global_position`（`to * CELL_SIZE`）

> **为什么这个回调链很重要？** 设计文档中大量机制依赖「当某实体进入某格时」触发：蛇踩到状态格获得状态、蛇头碰敌人触发战斗、蛇身经过食物吃掉它……这些全部通过 `_on_entity_enter` / `_on_stepped_on` 回调统一处理。

### 2.3 EventBus — 全局事件总线

**文件：** `autoloads/event_bus.gd`
**性质：** Autoload 单例

EventBus 使用 Godot 的 `signal` 机制实现。所有系统间通信通过 EventBus，系统之间不直接持有引用。

**实现方式：**
- 在 `event_bus.gd` 中声明所有 signal
- 各系统通过 `EventBus.signal_name.connect(callable)` 监听
- 各系统通过 `EventBus.signal_name.emit(args)` 发射

> 完整事件列表见 [第4章 事件目录](#4-事件目录-event-catalog)。

**EventBus 的设计原则：**
1. **只做中转，不做逻辑** — EventBus 本身不包含任何游戏逻辑
2. **信号命名规范** — `{主语}_{动作}_{过去分词}`，如 `snake_food_eaten`、`enemy_killed`
3. **参数传字典** — 复杂事件使用 `Dictionary` 传参，保持信号签名简洁，方便扩展
4. **避免循环** — 事件处理器内不应直接 emit 同一事件

### 2.4 TickManager — 节拍管理器

**文件：** `autoloads/tick_manager.gd`
**性质：** Autoload 单例

TickManager 控制游戏的离散时间推进。

**核心属性：**

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `base_tick_interval` | `float` | `0.25` | 基础 tick 间隔（秒） |
| `tick_speed_modifier` | `float` | `1.0` | 速度修正因子（冰冻等效果修改此值） |
| `is_ticking` | `bool` | `false` | 是否正在 tick |
| `current_tick` | `int` | `0` | 当前 tick 计数 |

**Tick 流程（每个 tick 的执行顺序）：**

```
1. TickManager 计时器到达 → 发射 EventBus.tick_pre_process
2. 收集玩家输入（转向指令） → 发射 EventBus.tick_input_collected
3. 蛇移动 → 发射 EventBus.snake_moved
4. 碰撞判定 & 回调链执行（GridWorld.move_entity 触发）
5. 敌人 AI 决策 & 移动
6. 状态效果结算
7. 发射 EventBus.tick_post_process
8. current_tick += 1
```

> **关键：** 所有 tick 内操作是同步、顺序执行的。不存在同一 tick 内的并发问题。

**暂停机制：**
- 事件建筑物交互、鳞片管理 UI 等触发暂停时，`TickManager.pause()` 停止计时器
- 暂停时 `_process()` 仍然运行（UI 动画等），但不会触发新 tick

### 2.5 StateMachine — 通用状态机

**文件：** `core/state_machine.gd`
**继承：** `Node`

一个轻量级、可复用的有限状态机，用于：
- 敌人 AI 行为（Wander / Chase / Attack / Flee / Stunned）
- 房间状态（FirstVisit / Revisit / Depleted）
- 游戏阶段（Title / Run / Paused / GameOver）

**核心接口：**

| 方法 | 说明 |
|------|------|
| `transition_to(state_name: String)` | 切换到指定状态 |
| `get_current_state() -> String` | 获取当前状态名 |

**State 基类接口：**

| 方法 | 说明 |
|------|------|
| `enter()` | 进入状态时调用 |
| `exit()` | 离开状态时调用 |
| `on_tick()` | 每 tick 调用 |
| `get_name() -> String` | 返回状态名 |

### 2.6 全局常量

**文件：** `core/constants.gd`（建议也注册为 Autoload 或使用 `const`）

| 常量 | 值 | 说明 |
|------|-----|------|
| `CELL_SIZE` | `32` | 格子像素大小 |
| `BASE_TICK_INTERVAL` | `0.25` | 基础 tick 间隔 |
| `GRID_WIDTH` | 可配置 | 地图宽度（格数） |
| `GRID_HEIGHT` | 可配置 | 地图高度（格数） |

### 2.7 坐标系统约定

- **Grid 坐标：** `Vector2i`，(0,0) 为左上角，x 向右增长，y 向下增长
- **世界坐标：** `Vector2`，Grid 坐标 × `CELL_SIZE` = 世界坐标（格子左上角）
- **格子中心：** Grid 坐标 × `CELL_SIZE` + `Vector2(CELL_SIZE/2, CELL_SIZE/2)`
- **转换辅助：** `GridWorld.grid_to_world(grid_pos)` / `GridWorld.world_to_grid(world_pos)`

---

## 3. 系统实现指引

> 各系统按实现优先级排列。每个系统标注优先级等级：
> - 🔴 **P0** — MVP 最小可运行原型（必须先实现）
> - 🟠 **P1** — 战斗可玩最小单元
> - 🟡 **P2** — Build 系统核心
> - 🟢 **P3** — 完整一局可玩
> - 🔵 **P4/P5** — 深度内容与长期可玩性

---

### 3.1 🔴 P0 — 基础移动系统 (MovementSystem)

**对应设计文档：** 系统一（第2章）
**目录：** `systems/movement/`
**职责：** 管理蛇在 Grid 上的移动、转向、碰撞检测

#### 3.1.1 职责边界

| 做 | 不做 |
|----|------|
| 接收玩家输入并缓存转向指令 | 判定战斗伤害（交给 CombatSystem） |
| 每 tick 按当前方向移动蛇头 | 管理蛇身长度变化（交给 LengthSystem） |
| 检测碰撞并发射对应事件 | 处理状态效果（交给 StatusSystem） |
| 管理蛇身队列数据结构 | 渲染蛇的视觉表现 |

#### 3.1.2 核心数据结构：Snake

Snake 不是单个 GridEntity，而是一个**管理多个 GridEntity（蛇身段）的控制器**。

```
Snake:
  body: Array[Vector2i]          # 有序队列，body[0] = 蛇头，body[-1] = 蛇尾
  direction: Vector2i            # 当前移动方向 (1,0) / (-1,0) / (0,1) / (0,-1)
  input_buffer: Vector2i         # 缓存的下一次转向输入
  segments: Array[SnakeSegment]  # 对应的 GridEntity 实例数组

SnakeSegment (extends GridEntity):
  segment_index: int             # 在蛇身中的索引（0=头，N=尾）
  segment_type: SegmentType      # HEAD / BODY / TAIL
  carried_status: String         # 此段独立携带的状态（"fire"/"ice"/"poison"/""）
  # 注：蛇鳞装在抽象槽位中，不对应具体身体段（见 ScaleSystem）
```

#### 3.1.3 Tick 内移动流程

```
1. 从 input_buffer 读取转向指令
2. 验证转向合法性（不允许 180° 反向）
3. 计算新蛇头位置：new_head = body[0] + direction
4. 边界检测：
   - 超出地图 → 发射 EventBus.snake_hit_boundary
5. 自身碰撞检测：
   - new_head 在 body 中 → 发射 EventBus.snake_hit_self
6. 实体碰撞检测（通过 GridWorld.get_entities_at(new_head)）：
   - 有敌人 → 发射 EventBus.snake_hit_enemy { enemy, position }
   - 有食物 → 发射 EventBus.snake_food_eaten { food, position }
   - 有状态格 → 由 GridWorld.move_entity 回调链自动处理
7. 更新蛇身队列：
   - body.push_front(new_head)
   - 如果本 tick 不需要增长 → body.pop_back()（缩尾由 LengthSystem 控制）
8. 同步 GridWorld 注册：
   - 注册新蛇头位置
   - 如果缩尾了则注销旧蛇尾位置
9. 发射 EventBus.snake_moved { body, direction, head_pos, tail_pos }
```

#### 3.1.4 输入处理

- 玩家输入在 `_process()` 或 `_unhandled_input()` 中捕获
- 写入 `input_buffer`，在下一个 tick 的步骤 1 中消费
- 同一 tick 内多次输入，只保留最后一次
- 支持输入队列（可选优化）：允许快速连续转向（如 L 形转弯），最多缓存 2 个指令

#### 3.1.5 关键事件

| 事件（发射） | 触发时机 | 参数 |
|-------------|---------|------|
| `snake_moved` | 蛇完成移动后 | `{ body, direction, head_pos, old_tail_pos }` |
| `snake_turned` | 蛇改变方向时 | `{ old_dir, new_dir }` |
| `snake_hit_boundary` | 蛇头碰到地图边界 | `{ position, direction }` |
| `snake_hit_self` | 蛇头碰到自身 | `{ position, segment_index }` |
| `snake_hit_enemy` | 蛇头碰到敌人 | `{ enemy, position }` |
| `snake_food_eaten` | 蛇头碰到食物 | `{ food, position, food_type }` |

| 事件（监听） | 来源 | 响应 |
|-------------|------|------|
| `tick_input_collected` | TickManager | 执行移动流程 |
| `length_grow_requested` | LengthSystem | 下一个 tick 不缩尾 |

---

### 3.2 🔴 P0 — 长度系统 (LengthSystem)

**对应设计文档：** 系统二（第3章）
**目录：** `systems/length/`
**职责：** 管理蛇的长度增减，作为唯一的「数值单位」

#### 3.2.1 职责边界

| 做 | 不做 |
|----|------|
| 追踪当前长度 | 决定何时应该增减（由其他系统发事件） |
| 响应增减请求并执行 | 渲染长度变化的视觉效果 |
| 判定长度归零 → 死亡 | 管理蛇身段的具体 GridEntity |
| 发射长度变化事件 | |

#### 3.2.2 核心逻辑

```
current_length: int     # 当前长度（= Snake.body.size()）
grow_queue: int         # 待增长的格数（吃到食物时 +1，下个 tick 消费）

on EventBus.snake_food_eaten:
  grow_queue += food.growth_amount

on EventBus.length_decrease_requested { amount, source }:
  实际执行蛇尾缩短 amount 格
  if current_length <= 0:
    发射 EventBus.snake_died { cause: source }
  else:
    发射 EventBus.snake_length_decreased { amount, source, new_length }

on EventBus.snake_moved:
  if grow_queue > 0:
    告知 MovementSystem 本 tick 不缩尾
    grow_queue -= 1
    发射 EventBus.snake_length_increased { amount: 1, source: "growth", new_length }
```

#### 3.2.A No-Body Countdown（L1 新增）

当蛇身段全部丢失（仅剩蛇头）时，启动倒计时。倒计时结束前未恢复身段则判定死亡。

**新增属性：**

| 属性 | 类型 | 说明 |
|------|------|------|
| `no_body_ticks` | `int` | `-1` = 未激活，`>0` = 剩余 tick 数 |
| `no_body_total_ticks` | `int` | 总 tick 数，用于计算比率（HUD 进度条） |
| `no_body_grace_seconds` | `float` | 来自配置 `snake.no_body_grace_seconds`（默认 10） |

**核心流程：**

```
on length_decrease → if body.size() <= 1:
  _start_no_body_countdown()       # no_body_ticks = ceil(grace_seconds / tick_interval)
  发射 EventBus.no_body_countdown_started { total_seconds }

on tick_post_process:
  if no_body_ticks > 0:
    no_body_ticks -= 1
    发射 EventBus.no_body_countdown_tick { remaining_seconds, total_seconds, ratio }
    if no_body_ticks <= 0:
      snake.die("no_body_timeout")

on length_increased → if body.size() > 1:
  取消倒计时，重置 no_body_ticks = -1
  发射 EventBus.no_body_countdown_cancelled
```

**关联配置（game_config.json）：**

```json
"snake": {
  "no_body_grace_seconds": 10
}
```

#### 3.2.3 关键事件

| 事件（发射） | 触发时机 | 参数 |
|-------------|---------|------|
| `snake_length_increased` | 长度增加后 | `{ amount, source, new_length }` |
| `snake_length_decreased` | 长度减少后 | `{ amount, source, new_length }` |
| `snake_died` | 长度归零 | `{ cause }` |
| `length_grow_requested` | 需要增长时 | `{ amount }` |
| `no_body_countdown_started` | 蛇身段全部丢失，倒计时开始 | `{ total_seconds }` |
| `no_body_countdown_tick` | 倒计时每 tick 推进 | `{ remaining_seconds, total_seconds, ratio }` |
| `no_body_countdown_cancelled` | 恢复身段，倒计时取消 | — |

| 事件（监听） | 来源 |
|-------------|------|
| `snake_food_eaten` | MovementSystem |
| `length_decrease_requested` | StatusSystem / CombatSystem / 任何造成伤害的系统 |
| `snake_moved` | MovementSystem |
| `tick_post_process` | TickManager（No-Body Countdown 递减） |

---

### 3.3 🟠 P1 — 状态效果系统 (StatusSystem)

**对应设计文档：** 系统三（第4章）
**目录：** `systems/status_effect/`
**职责：** 管理实体上和地板上的状态效果，处理状态转化和反应

#### 3.3.1 职责边界

| 做 | 不做 |
|----|------|
| 管理实体状态效果的附加/移除/层数 | 直接修改蛇长度（通过事件请求 LengthSystem） |
| 管理空间状态格的生成/消失/蔓延 | 管理具体的敌人行为（交给 EnemySystem） |
| 检测和触发状态反应 | 定义鳞片的具体效果（交给 ScaleSystem） |
| 处理实体↔空间的状态转化 | |

#### 3.3.2 核心数据结构

> **L1 变更：** 状态效果定义已从 Resource (.tres) 迁移至 `game_config.json`，使用 T25 Effect Atom System 的 JSON 驱动模型。蛇身段使用简化的 `carried_status: String` 而非 StatusInstance。

**状态效果定义（game_config.json → status_effects）：**

L1 仅实现 `fire`、`ice`、`poison` 三种状态。每种状态通过 `entity_effects` 和 `tile_effects` 配置 Atom Chain：

```json
"fire": {
  "display_name": "灼烧",
  "entity_effects": [
    { "trigger": "on_interval", "interval": 2.0,
      "atoms": [{ "atom": "damage", "amount_per_layer": 1 }],
      "pattern": "self" }
  ],
  "tile_effects": [
    { "trigger": "on_interval", "interval": 1.0,
      "atoms": [{ "atom": "place_tile", "type": "fire" }],
      "pattern": "neighbors", "chance": 0.2 },
    { "trigger": "on_entity_enter",
      "atoms": [{ "atom": "apply_status", "type": "fire", "layers": 1 }],
      "pattern": "target" }
  ]
}
```

**蛇身段状态模型（L1 简化版）：**

```
SnakeSegment:
  carried_status: String    # "fire" / "ice" / "poison" / ""
  # 每段独立携带一种状态，二值模式（有/无），不使用层数
  # 状态继承：新蛇头自动继承旧蛇头的 carried_status

Enemy:
  carried_status: String    # 敌人也独立携带状态
```

**StatusTile（状态格）：**

```
StatusTile:
  status_type: String       # "fire" / "ice" / "poison"
  # L1 中状态格永久存在，无持续时间递减
  # 同位置异类型状态格互斥：放置时已有不同类型 → 触发反应 + 双方消除
```

> **L2+ 扩展：** 酸(acid)、电(electric)、虚(void) 三种状态定义在设计文档中，待 L2 实现时添加到 game_config.json。

#### 3.3.3 状态反应系统

**反应配置（game_config.json → reactions，L1 仅 3 种）：**

```json
"reactions": {
  "steam":            { "type_a": "fire", "type_b": "ice",    "enemy_damage": 2, "self_hit_count": 1 },
  "toxic_explosion":  { "type_a": "fire", "type_b": "poison", "enemy_damage": 3, "self_hit_count": 2 },
  "frozen_plague":    { "type_a": "ice",  "type_b": "poison", "enemy_damage": 0, "self_hit_count": 0,
                        "apply_poison_layers": 1 }
}
```

> **L1 变更：** 反应配置已内联到 `game_config.json` 的 `reactions` 节，不再使用独立 `reaction_table.json`。原设计的 15 种反应（6×6 矩阵）精简为 3 种，对应 L1 仅有的 fire/ice/poison 状态。

**反应检测时机：**
1. 实体获得新状态时 → 检查该实体身上是否有其他类型状态
2. 实体进入状态格时 → 检查实体状态 vs 地板状态
3. 状态格生成时 → 检查相邻格是否有不同类型状态格

**反应执行流程：**

```
1. 查 reaction_table，获取反应定义
2. 计算伤害 = (层数A + 层数B) × 系数
3. 消耗两种参与反应的状态
4. 应用反应结果效果
5. 发射 EventBus.status_reaction_triggered { type_a, type_b, position, damage, reaction_name }
```

#### 3.3.4 状态格作为 GridEntity

状态格（StatusTile）继承 GridEntity：

```
StatusTile (extends GridEntity):
  entity_type = EntityType.STATUS_TILE
  blocks_movement = false
  is_solid = false
  cell_layer = 0                     # 地面层
  status_def: StatusEffectDef
  remaining_duration: float

  _on_entity_enter(other):
    if other 是实体载体候选（蛇段/敌人）:
      StatusSystem.apply_status(other, status_def)

  _on_tick():
    更新持续时间
    处理蔓延逻辑
    到期后 remove_from_grid()
```

#### 3.3.5 关键事件

| 事件（发射） | 触发时机 | 参数 |
|-------------|---------|------|
| `status_applied` | 实体获得状态 | `{ target, status_type, layers, source }` |
| `status_removed` | 实体失去状态 | `{ target, status_type, reason }` |
| `status_layer_changed` | 状态层数变化 | `{ target, status_type, old_layers, new_layers }` |
| `status_tile_created` | 状态格生成 | `{ position, status_type, duration }` |
| `status_tile_expired` | 状态格消失 | `{ position, status_type }` |
| `status_reaction_triggered` | 状态反应触发 | `{ type_a, type_b, position, damage, reaction_name }` |
| `length_decrease_requested` | 灼烧等伤害性状态 | `{ amount, source: "status_fire" }` |

| 事件（监听） | 来源 |
|-------------|------|
| `entity_moved` | GridWorld（用于检测实体↔空间转化） |
| `tick_post_process` | TickManager（用于状态持续时间递减） |
| `enemy_killed` | EnemySystem（用于死亡时喷溅状态） |

---

### 3.3.A Effect Atom System（T25 架构升级）

**目录：** `systems/atoms/`
**职责：** 将状态效果逻辑从硬编码 GDScript 迁移为 JSON 驱动的可组合原子链

#### 核心概念

| 概念 | 说明 |
|------|------|
| **Atom（原子）** | 最小效果单元（如 damage、modify_speed、place_tile），由 JSON 配置驱动 |
| **EffectChain（效果链）** | trigger + conditions + actions + pattern 的组合，运行时执行单元 |
| **Trigger（触发器）** | 链的激活条件（on_interval、on_applied、on_layer_reach、on_move 等 17 种） |
| **Pattern（范围模式）** | 效果作用的空间范围（self、radius、neighbors、line、cone 等 11 种） |
| **Condition（条件原子）** | if_* 原子，evaluate() 返回 bool，AND 组合后决定是否执行动作 |

#### 数据流

```
game_config.json
    ↓ EffectChainResolver.resolve_all()
EffectChain[] (存储在 StatusEffectData.chains)
    ↓ TriggerManager.register_chains()
EventBus 信号 / interval 计时器
    ↓ TriggerManager._fire_trigger()
AtomExecutor.execute_chain()
    ↓ conditions → chance → PatternResolver → atoms
AtomBase.execute(AtomContext)
```

#### 添加新原子

1. 创建 `systems/atoms/atoms/<category>/<name>_atom.gd`
2. extends AtomBase，实现 execute() 或 evaluate()（条件原子还需 `is_condition() -> true`）
3. 在 `atom_registry.gd` 的 `_register_all()` 中添加一行 `_atoms["name"] = preload(...)`

#### 添加新状态效果（纯 JSON）

在 `game_config.json` 的 `status_effects` 中添加配置，使用已有原子组合：
```json
{
  "entity_effects": [
    { "trigger": "on_interval", "interval": 2.0,
      "atoms": [{ "atom": "damage", "amount_per_layer": 1 }],
      "pattern": "self" }
  ]
}
```

#### 向后兼容

旧 FireEffect/IceEffect/PoisonEffect 作为 shim 保留。`_has_legacy_effects(type)` 判断某类型是否需要旧处理器（仅在无原子链定义时运行）。

---

### 3.4 🟠 P1 — 敌人系统 (EnemySystem)

**对应设计文档：** 系统六（第7章）
**目录：** `systems/enemy/`
**职责：** 管理敌人的生成、AI 行为、战斗判定、死亡

#### 3.4.1 职责边界

| 做 | 不做 |
|----|------|
| 敌人 AI 行为决策 | 管理状态效果（交给 StatusSystem） |
| 敌人移动执行 | 修改蛇长度（通过事件请求） |
| 战斗伤害计算 | 掉落物生成（发射事件由 GrowthSystem 处理） |
| 部位破坏管理（精英/Boss） | 地图生成（交给 MapSystem） |

#### 3.4.2 敌人作为 GridEntity

```
Enemy (extends GridEntity):
  entity_type = EntityType.ENEMY
  blocks_movement = true             # 敌人占据格子
  is_solid = true

  enemy_def: EnemyDef               # 引用的敌人定义 Resource
  hp: int                           # 剩余 HP（用蛇格数衡量）
  state_machine: StateMachine       # 敌人 AI 状态机
  status_response: StatusResponseType  # 回避/无视/趋向/利用/恐惧
  status_effects: Array[StatusInstance]  # 身上的状态效果
```

**EnemyDef (Resource)：**

```
EnemyDef:
  id: StringName
  display_name: String
  tier: EnemyTier                   # BASIC / TACTICAL / SPECIAL / ELITE / BOSS
  base_hp: int
  move_speed: int                   # 每 N tick 移动一次
  status_response: StatusResponseType
  status_response_targets: Array[StringName]  # 响应哪些状态类型
  behavior_config: Dictionary       # AI 行为参数（追踪范围、攻击方式等）
  loot_table: String                # 掉落表引用
  parts: Array[EnemyPartDef]        # 部位定义（精英/Boss 用）
```

#### 3.4.3 敌人 AI — 基于优先级栈

每个 tick，敌人 AI 按优先级栈顺序检查：

```
P1 自我保护: 当前格是危险状态格？→ 向安全格移动
P2 威胁响应: 蛇头在攻击范围内？→ 进入攻击行为
P3 状态响应: 根据 status_response 类型决策
   - 回避型: GridWorld.find_path() 避开状态格
   - 趋向型: GridWorld.find_path() 趋向目标状态格
   - 利用型: 计算最优反应路径
   - 恐惧型: 检查特定状态格 → 进入 Stunned 状态
P4 目标追踪: 向蛇头/指定目标移动
P5 默认行为: 随机移动 / 碰壁反弹
```

**AI 寻路使用 `GridWorld.find_path()`**，传入自定义的 cost 函数以实现不同的状态响应行为。

#### 3.4.4 战斗判定（L1 修订版）

**蛇头吞噬敌人（无消耗）：**
```
on EventBus.snake_hit_enemy { enemy, position }:
  enemy.die()                              # 直接击杀，不消耗蛇身长度
  发射 EventBus.enemy_killed { enemy_def, position, method: "head_strike" }
  # 食物掉落：统一在 enemy_killed 信号处理器中执行
  # 所有击杀方式（蛇头吞噬、火光环、反应伤害）均掉食物
  var drop_count = enemy.drop_food_count   # 来自 enemy_types 配置
  var empty_cells = GridWorld.get_empty_neighbors(position)
  for i in min(drop_count, empty_cells.size()):
    FoodManager.spawn_food_at(empty_cells[i])
```

> **L1 变更：** 蛇身碾压（crush）机制已移除。蛇身段不再主动攻击敌人。敌人改为主动攻击蛇身段（见 3.4.A.3）。`snake_body_crush_enemy` 信号已废弃。

#### 3.4.5 部位系统（精英/Boss 专用，L2+ 未实现）

```
EnemyPartDef:
  id: StringName
  part_type: PartType             # FUNCTIONAL / DANGEROUS / REWARD / CORE
  hp: int
  armor: int                      # 护甲值（攻击消耗增加）
  effect_on_destroy: Dictionary   # 摧毁时效果
  expose_condition: String        # 暴露条件（如"所有护甲摧毁后"）
```

部位信息作为敌人数据的子结构，部位 HP 独立追踪。Boss 战需要所有 CORE 部位摧毁才能击杀。

#### 3.4.6 关键事件

| 事件（发射） | 触发时机 | 参数 |
|-------------|---------|------|
| `enemy_killed` | 敌人死亡 | `{ enemy_def, position, method, killer }` |
| `enemy_spawned` | 敌人生成 | `{ enemy_def, position }` |
| `enemy_part_destroyed` | 部位摧毁 | `{ enemy, part_id, part_type }` |
| `length_decrease_requested` | 战斗消耗 | `{ amount, source: "combat" }` |
| `snake_body_crush_enemy` | 蛇身碾压 | `{ enemy, segment_index }` |

| 事件（监听） | 来源 |
|-------------|------|
| `snake_hit_enemy` | MovementSystem |
| `tick_post_process` | TickManager（敌人 AI 执行） |
| `status_applied` | StatusSystem（部分敌人需要响应自身状态变化） |

---

### 3.4.A L1 Gameplay Loop Redesign

**版本：** L1 里程碑
**职责：** 重新设计战斗循环核心，将状态效果从实体级系统迁移为蛇身段级系统，引入敌人攻击机制

> **背景：** L1 对战斗流做了重大调整——蛇吃掉敌人（而非碰撞消耗长度）、蛇身段携带独立状态、敌人主动攻击蛇身段。以下各子节按改动模块分列。

#### 3.4.A.1 Snake Eats Enemies（EnemyManager 改动）

L1 中蛇头碰撞敌人不再消耗长度，而是**直接击杀敌人**并产出食物：

```
on EventBus.snake_hit_enemy { enemy, position }:
  enemy.die()                                    # 敌人即死，无长度消耗
  发射 EventBus.enemy_killed { enemy_def, position, method: "head_strike" }
  # 掉落食物
  var drop_count = enemy.drop_food_count         # 来自 enemy_types 配置
  var empty_cells = GridWorld.get_empty_neighbors(position)
  for i in min(drop_count, empty_cells.size()):
    FoodManager.spawn_food_at(empty_cells[i])
```

**配置（game_config.json → enemy_types）：**

| 敌人类型 | `drop_food_count` | `attack_cooldown` | `can_attack` |
|---------|-------------------|-------------------|-------------|
| wanderer | 2 | 3 | true |
| chaser | 3 | 2 | true |
| bog_crawler | 4 | 4 | true |

#### 3.4.A.2 Per-Segment Status（SnakeSegment 改动）

蛇身段状态不再由 StatusEffectManager 管理，而是**每个 SnakeSegment 独立携带一种状态**：

```
SnakeSegment:
  carried_status: String = ""     # "fire" / "ice" / "poison" / ""

  set_carried_status(type: String):
    carried_status = type
    _update_visual()              # 更新身段颜色/特效

  clear_carried_status():
    carried_status = ""
    _update_visual()
```

**关键变更：**
- 蛇不再使用 StatusEffectManager（该系统仅用于敌人）
- `Snake._get_effective_speed()` 固定返回 `1.0`（蛇不受状态速度修正）
- 身段状态完全独立——同一条蛇的不同身段可携带不同状态
- **状态继承**：蛇移动时创建新蛇头，自动继承旧蛇头的 `carried_status`，确保状态不因蛇移动丢失
- **蛇基础颜色改为白/灰**（HEAD=0.95, BODY=0.78, TAIL=0.6 灰度），与毒绿色形成对比
- **敌人也有 `carried_status`** + 状态视觉（`set_carried_status_visual` / `_apply_status_visual`），支持覆盖层和边框动画

#### 3.4.A.3 Enemy Attack System（Enemy + EnemyBrain 改动）

敌人获得主动攻击蛇身段的能力：

```
Enemy:
  carried_status: String = ""            # 敌人自身携带的状态
  attack_cooldown_remaining: int = 0     # 攻击冷却剩余 tick

  _attack_segment(segment: SnakeSegment):
    snake.take_hit(damage)
    # 双向状态转移：
    var seg_status = segment.carried_status
    var enemy_status = carried_status
    if seg_status != "" and enemy_status == "":
      set_carried_status_visual(seg_status)       # 敌人沾染蛇段状态
    elif seg_status == "" and enemy_status != "":
      segment.set_carried_status(enemy_status)     # 蛇段获得敌人状态
    elif seg_status != "" and enemy_status != "":
      if seg_status != enemy_status:
        trigger_reaction(enemy_status, seg_status) # 异类 → 反应 + 双方清除
        segment.clear_carried_status()
        clear_carried_status()
```

**EnemyBrain 优先级栈（L1 更新）：**

```
P0 攻击: _find_attackable_segment()    — 搜索 attack_range 内的非 HEAD 身段
P1 自我保护: 当前格是危险状态格？→ 向安全格移动（不变）
P2 威胁响应: 蛇头在威胁范围内？→ 回避（不变）
P3 状态响应: 根据 status_response 类型决策（不变）
P4 目标追踪: chaser 追踪最近蛇身段的相邻空格（更新：不再追踪蛇头）
P5 默认行为: 随机移动 / 碰壁反弹（不变）
```

> **注意：** P0 攻击是 L1 新增的最高优先级行为。敌人在冷却完毕后会优先攻击蛇身段。

#### 3.4.A.4 Hit Counter（Snake 受击计数）

蛇不再因单次攻击直接丢段，而是**累积受击后才丢失身段**：

```
Snake:
  hits_taken: int = 0                    # 已累积受击次数
  hits_per_segment_loss: int = 3         # 来自配置 snake.hits_per_segment_loss

  take_hit(damage: int = 1):
    hits_taken += damage
    if hits_taken >= hits_per_segment_loss:
      hits_taken = 0
      发射 EventBus.length_decrease_requested { amount: 1, source: "body_attack" }
```

**配置（game_config.json → snake）：**

```json
"snake": {
  "hits_per_segment_loss": 3,
  "no_body_grace_seconds": 10
}
```

#### 3.4.A.5 Status Tile Interaction Rewrite（StatusTransferSystem 改动）

状态格交互逻辑从「实体级施加」改为**逐身段检测**：

```
on tick_post_process:
  for segment in snake.segments:
    var tile = StatusTileManager.get_tile_at(segment.grid_position)
    if tile == null:
      continue
    match _get_interaction_type(segment.carried_status, tile.status_type):
      "gain":     segment.set_carried_status(tile.status_type)   # 无状态 → 获得
      "same":     pass                                            # 同状态 → 无变化
      "reaction": _trigger_reaction(segment, tile)                # 异状态 → 反应 + 清除身段状态
```

**关键变更：**
- 每 tick 遍历**所有蛇身段**，检测其所在位置的状态格
- 状态格在 L1 中为**永久存在**（不再有持续时间递减，不再 tick_update）
- **反应清除身段状态 + 消除该位置状态格**（调用 `tile_manager.remove_tile()`）
- **同位置异类型状态格互斥**：`StatusTileManager.place_tile()` 检测到异类已存在时触发反应 + 双方消除，不放置新格子
- 所有 `GridWorld.get_entities_at()` / `cell_map` 遍历均需 `is_instance_valid()` 防护（已被 queue_free 的节点可能残留在 cell_map 中）

#### 3.4.A.6 Segment Effect System（新增：SegmentEffectSystem）

**文件：** `systems/combat/segment_effect_system.gd`
**职责：** 处理蛇身段携带状态的战术效果（火光环、毒轨迹、冰防御）

```
监听: tick_post_process, snake_moved

_process_fire_aura():
  # 火光环：每个携带火状态的身段对相邻敌人造成伤害
  for segment in snake.segments:
    if segment.carried_status == "fire":
      var neighbors = GridWorld.get_neighbors(segment.grid_position)
      for pos in neighbors:
        var enemies = GridWorld.get_entities_of_type(pos, EntityType.ENEMY)
        for enemy in enemies:
          enemy.take_damage(aura_damage)    # aura_damage 来自配置

_process_poison_trail():
  # 毒轨迹：蛇移动时，若被移除的旧尾段携带毒状态，按间隔留毒格
  on snake_moved { vacated_pos, vacated_status }:
    if vacated_status != "poison": return
    _trail_counter += 1
    if _trail_counter >= _trail_interval:   # trail_interval=3 (来自配置)
      _trail_counter = 0
      tile_manager.place_tile(vacated_pos, "poison")

# 冰防御：已合并入双向状态转移（见 3.4.A.3 _attack_segment）
```

#### 3.4.A.7 Reaction System Rewrite（ReactionSystem 改动）

L1 仅保留 3 种反应，全部通过配置驱动 AoE 效果：

| 反应名 | 组合 | `enemy_damage` | `self_hit_count` | 特殊效果 |
|--------|------|---------------|-----------------|---------|
| steam | fire + ice | 2 | 1 | — |
| toxic_explosion | fire + poison | 3 | 2 | — |
| frozen_plague | ice + poison | 0 | 0 | 范围内敌人施加 ice + poison |

```
on EventBus.reaction_triggered { reaction_type, position, radius }:
  var enemies_in_range = GridWorld.get_entities_in_radius(position, radius, EntityType.ENEMY)
  var config = reaction_configs[reaction_type]
  for enemy in enemies_in_range:
    enemy.take_damage(config.enemy_damage)
  if config.self_hit_count > 0:
    snake.take_hit(config.self_hit_count)
  # frozen_plague 特殊处理：施加双状态给范围内敌人
```

#### 3.4.A.8 关键事件

| 事件（发射） | 触发时机 | 参数 |
|-------------|---------|------|
| `snake_body_attacked` | 敌人攻击蛇身段 | `{ position, segment, enemy, enemy_status, seg_status }` |
| `no_body_countdown_started` | 蛇身段全部丢失 | `{ total_seconds }` |
| `no_body_countdown_tick` | 倒计时 tick 推进 | `{ remaining_seconds, total_seconds, ratio }` |
| `no_body_countdown_cancelled` | 恢复身段取消倒计时 | — |
| `reaction_triggered` | 身段状态与状态格/敌人状态触发反应 | `{ reaction_id, position, type_a, type_b }` |

| 事件（监听） | 来源 | 响应 |
|-------------|------|------|
| `snake_hit_enemy` | MovementSystem | 击杀敌人 + 掉落食物 |
| `tick_post_process` | TickManager | 状态格交互检测、火光环、攻击冷却 |
| `snake_moved` | MovementSystem | 毒轨迹处理 |

---

### 3.5 🟡 P2 — 蛇头/蛇尾/蛇鳞统一系统 (SnakePartsSystem)

**对应设计文档：** 系统四（第5章）、系统五（第6章）
**目录：** `systems/snake_parts/`
**职责：** 管理蛇头/蛇尾/蛇鳞的规则改写效果
**L2 修订：** 三套系统统一使用 T25 Effect Atom System，共享同一执行管线

#### 3.5.1 设计关键：统一 Atom Chain 架构

蛇头、蛇尾、蛇鳞**全部使用 T25 Atom Chain 系统**，共享同一执行管线：

```
game_config.json
├── status_effects     → 状态链（已有，T25）
├── reactions          → 反应链（已有，T25）
├── snake_heads        → 蛇头链（新增，复用 T25 管线）
├── snake_tails        → 蛇尾链（新增，复用 T25 管线）
└── snake_scales       → 蛇鳞链（新增，复用 T25 管线 + Build 原子）

所有链 → EffectChainResolver → TriggerManager → AtomExecutor
```

**统一的好处：**
- 状态原子 × 蛇头原子可以交叉组合（如 `if_has_status` 条件可用于蛇尾链）
- 新增蛇头/蛇尾 = JSON 配置 + 可能需要的新原子，不改 Snake 核心代码
- 蛇鳞的 `modify_effect_value` 可增幅蛇头链中 `direct_grow` 的 amount
- 所有效果共享同一条件系统、模式系统和触发器基础设施

#### 3.5.2 新增原子类型（~6 个）

| 原子名 | 类别 | 作用 | 用于 |
|--------|------|------|------|
| `modify_food_drop` | Value | 改写击杀后食物掉落数量 | 蛇头 |
| `direct_grow` | Value | 直接增长蛇身（跳过食物流程） | 蛇头、蛇尾 |
| `steal_status` | Status | 从被吃敌人偷取 carried_status 到蛇头 | 蛇头 |
| `modify_hit_threshold` | Value | 改写 hits_per_segment_loss 上限 | 蛇头 |
| `delay_loss` | Temporal | 延迟丢段 N tick，期间满足条件可取消 | 蛇尾 |
| `grant_invincibility` | Control | N tick 内受击不计入计数器 | 蛇头 |

所有新原子均为标准 `AtomBase` 子类，实现 `execute(ctx)` 即可。注册方式与 T25 已有原子相同。

#### 3.5.3 蛇头配置（JSON + Atom Chain）

```json
// game_config.json → snake_heads
"snake_heads": {
  "hydra": {
    "display_name": "九头蛇",
    "description": "贪婪型：吃敌人直接+长度，但更脆弱",
    "chains": [
      {
        "trigger": "on_applied",
        "atoms": [
          { "atom": "modify_hit_threshold", "value": -1 }
        ]
      },
      {
        "trigger": "on_kill",
        "atoms": [
          { "atom": "modify_food_drop", "amount": 0 },
          { "atom": "direct_grow", "amount": 1 },
          { "atom": "steal_status" }
        ]
      }
    ],
    "level_configs": [
      { "direct_grow_amount": 1 },
      { "direct_grow_amount": 2 },
      { "direct_grow_amount": 2, "echo_bite_range": 1, "echo_bite_damage": 1 }
    ]
  },
  "bai_she": {
    "display_name": "白蛇",
    "description": "稳健型：吃敌人获得安全窗口，但成长慢",
    "chains": [
      {
        "trigger": "on_kill",
        "atoms": [
          { "atom": "modify_food_drop", "amount": -1 },
          { "atom": "grant_invincibility", "ticks": 3 }
        ]
      }
    ],
    "level_configs": [
      { "invincible_ticks": 3, "food_modifier": -1 },
      { "invincible_ticks": 3, "food_modifier": -1, "counter_ice": true },
      { "invincible_ticks": 5, "food_modifier": -1, "counter_ice": true,
        "expire_status_burst": true }
    ]
  }
}
```

#### 3.5.4 蛇尾配置（JSON + Atom Chain）

```json
// game_config.json → snake_tails
"snake_tails": {
  "salamander": {
    "display_name": "再生尾",
    "description": "防守恢复型：丢段后窗口内自动恢复",
    "chains": [
      {
        "trigger": "on_length_decrease",
        "atoms": [
          { "atom": "mark_recovery_window", "duration": 5.0 }
        ]
      },
      {
        "trigger": "on_interval",
        "interval": 5.0,
        "conditions": [
          { "atom": "if_in_recovery_window" }
        ],
        "atoms": [
          { "atom": "direct_grow", "amount": 1 }
        ]
      }
    ],
    "level_configs": [
      { "recover_delay": 5.0 },
      { "recover_delay": 7.0 },
      { "recover_delay": 7.0, "recover_status": "ice" }
    ]
  },
  "lag_tail": {
    "display_name": "时滞尾",
    "description": "进攻取消型：丢段可被击杀取消",
    "chains": [
      {
        "trigger": "on_length_decrease",
        "atoms": [
          { "atom": "delay_loss", "ticks": 3, "cancel_on": "eat_enemy" }
        ]
      }
    ],
    "level_configs": [
      { "delay_ticks": 3, "cancel_on": "eat_enemy" },
      { "delay_ticks": 3, "cancel_on": "eat_enemy", "bonus_counter_reduction": 1 },
      { "delay_ticks": 3, "cancel_on": "any_kill" }
    ]
  }
}
```

#### 3.5.5 蛇头/蛇尾与 Snake 核心代码的对接

Snake 核心代码通过 SnakePartsManager 注册/注销蛇头/蛇尾链：

```gdscript
# SnakePartsManager.gd（伪代码）
func equip_head(head_id: String, level: int) -> void:
    var config = GameConfig.get_snake_head(head_id)
    var chains = EffectChainResolver.resolve_snake_part(config, level)
    TriggerManager.register_chains(snake, chains)

func equip_tail(tail_id: String, level: int) -> void:
    var config = GameConfig.get_snake_tail(tail_id)
    var chains = EffectChainResolver.resolve_snake_part(config, level)
    TriggerManager.register_chains(snake, chains)
```

蛇头/蛇尾的原子通过 `AtomContext` 访问 Snake 实例和所有系统引用，执行时直接修改游戏状态（与状态原子相同模式）。

#### 3.5.6 扩展流程（添加新蛇头）

```
1. 在 game_config.json → snake_heads 中添加新配置（chains + level_configs）
2. 如果需要新行为，创建 systems/atoms/atoms/<category>/new_atom.gd extends AtomBase
3. 在 atom_registry.gd 注册新原子
4. 完成。Snake.gd 和 SnakePartsManager 无需修改。
```

#### 3.5.7 交叉组合能力

```
统一 Atom Chain 的核心价值：不同来源的链共享同一执行器和条件系统

示例 1：状态原子 × 蛇头原子
  蛇吃掉带火的敌人 → steal_status 原子 → 蛇头获得火 → 火的 on_interval 链自动激活

示例 2：条件原子 × 蛇尾链
  if_has_status("ice") 可作为 Salamander 恢复链的额外条件
  → "只有携带冰状态时才能触发自动恢复"

示例 3：蛇鳞增幅蛇头
  蛇鳞 modify_effect_value 原子可增幅蛇头链中 direct_grow 的 amount
  → 贪食鳞 + Hydra = 吃敌人 +2 长度（原本 +1）
```

---

### 3.5.8 🟡 T27 — EffectWindow 时间窗口框架

**对应设计文档：** 12B 节
**目录：** `systems/atoms/`
**职责：** 为 Atom System 提供"持续 N tick 的效果窗口"能力
**前置条件：** T25 Atom System（已完成）
**后续依赖：** T28（L2 新原子）、T29-T30（蛇头/蛇尾系统）

#### 架构分层

```
AtomBase（不变，无状态即时执行器）
    ↓ open_window 原子的 execute() 调用
EffectWindowManager（新增，有状态管理器）
    ↓ 管理 N 个并存窗口实例
EffectWindow（新增，RefCounted 数据对象）
    ↓ tick 递减 / 到期回调 / 条件取消
```

#### 新增文件

| 文件 | 类型 | 职责 |
|------|------|------|
| `systems/atoms/effect_window.gd` | RefCounted | 单个窗口数据 |
| `systems/atoms/effect_window_manager.gd` | Node | 管理所有活跃窗口 |
| `systems/atoms/atoms/temporal/open_window_atom.gd` | AtomBase | 开窗口动作原子 |
| `systems/atoms/atoms/condition/if_in_window_atom.gd` | AtomBase | 窗口查询条件原子 |

#### EffectWindowManager 核心 API

```gdscript
class_name EffectWindowManager
extends Node

func open_window(config: Dictionary, owner: Object) -> void
    # 同 id 已存在 → 刷新 remaining_ticks
func cancel_window(window_id: String) -> void
    # 取消，不触发 on_expire
func is_active(window_id: String) -> bool
func get_rule(window_id: String, rule_key: String, default_value = null)
    # 便捷查询：各系统调用此方法读取窗口规则

func _on_tick(_tick_index: int) -> void
    # tick_post_process 连接：递减所有窗口，到期执行 on_expire 链
```

#### cancel_on 动态信号连接

```gdscript
# open_window 时，如果 cancel_on 非空：
func _connect_cancel(window_id: String, trigger_name: String) -> void:
    # 映射 trigger_name → EventBus 信号
    # 例："on_kill" → EventBus.enemy_killed
    # 连接 callback → cancel_window(window_id)
```

#### AtomContext 变更

```gdscript
# atom_context.gd 新增：
var window_mgr: EffectWindowManager = null
```

TriggerManager._build_context() 注入 window_mgr（与 effect_mgr、tile_mgr 同模式）。

#### EventBus 新增信号

```gdscript
signal window_opened(data: Dictionary)    # { window_id, owner, duration_ticks }
signal window_expired(data: Dictionary)   # { window_id, owner }
signal window_cancelled(data: Dictionary) # { window_id, owner, reason }
```

#### 对接现有系统

| 文件 | 改动 |
|------|------|
| `atom_context.gd` | +1 字段 window_mgr |
| `atom_registry.gd` | 注册 open_window + if_in_window |
| `trigger_manager.gd` | _build_context 注入 window_mgr |
| `game_world.gd` | 实例化 EffectWindowManager |
| `EventBus` | +3 信号 |
| `enemy.gd:_attack_segment` | 查询 ignore_hit_counter 规则 |
| `snake.gd:remove_tail_segment` | 查询 block_segment_loss 规则 |

---

### 3.6 🟡 P2 — 蛇鳞系统 (ScaleSystem)

**对应设计文档：** 系统五（第6章）
**目录：** `systems/scales/`
**职责：** 管理蛇鳞（遗物）的装备、触发、升级、邻接共鸣
**L2 修订：** 蛇鳞是抽象规则修改器，使用 T25 Atom Chain 管线，与 per-segment status 独立

> **架构变更：** 蛇鳞系统已与蛇头/蛇尾统一纳入 T25 Atom Chain 架构（见 3.5 节）。蛇鳞的 Condition / Action 复用 T25 的条件原子和动作原子。

#### 3.6.1 核心概念：抽象槽位 + Atom Chain

蛇鳞装在前段、中段、后段三个**抽象段位**的槽位中。段位决定**什么触发器激活链条**，与蛇身体的物理位置无关。

```
两套独立系统：
  per-segment status（战场层）：每个身体段独立携带 fire/ice/poison → 产生火光环/毒液蔓延/冰防御
  蛇鳞（Build 层）：装在抽象槽位 → 修改规则参数（如"火光环伤害+1"作用于所有火段）

蛇鳞使用 T25 Atom Chain 管线：
  game_config.json → snake_scales → EffectChainResolver → TriggerManager → AtomExecutor
  鳞片效果通过 trigger + conditions + atoms 组合定义，与状态链/蛇头链共享执行器
```

| 段位 | 绑定触发器 | 可被改写者 |
|------|-----------|-----------|
| 前段 | `on_kill`、`on_enter_status_tile` | 蛇头链 |
| 中段 | `on_tick`（被动）、`on_applied` | — |
| 后段 | `on_hit_received`、`on_length_decrease` | 蛇尾链 |

**鳞片效果范围分类：**

| 范围 | 说明 | 例子 |
|------|------|------|
| 全蛇 | 修改整条蛇的某个规则参数 | "受击计数器上限+1"、"火光环范围+1格" |
| 动作 | 修改某个动作的效果 | "吃敌人额外掉1食物"、"毒液蔓延频率+1" |
| 条件 | 满足条件时触发一次性效果 | "被攻击时击退攻击者"、"丢段时反伤" |

#### 3.6.2 核心数据结构

**ScaleDef（JSON 配置，非 Resource）：**

```json
// game_config.json → snake_scales
"snake_scales": {
  "fire_scale": {
    "display_name": "火焰鳞",
    "tags": ["fire"],
    "slot_type": "mid",
    "effect_scope": "whole_snake",
    "chains": [
      {
        "trigger": "on_applied",
        "atoms": [
          { "atom": "modify_rule", "rule": "fire_aura_damage", "modifier": 1 }
        ]
      }
    ],
    "level_configs": [
      { "fire_aura_damage_mod": 1 },
      { "fire_aura_damage_mod": 1 },
      { "fire_aura_range": 2 }
    ],
    "resonance_partners": ["poison_scale"]
  }
}
```

> **关键设计：** 鳞片效果通过 T25 Atom Chain 的 trigger + conditions + atoms 组合定义。条件原子（`if_has_status`、`if_min_length` 等）和动作原子（`modify_rule`、`push`、`damage_area` 等）全部复用 T25 已注册的原子。

#### 3.6.3 内置条件原子（与 T25 共享注册表）

| 原子 | params | 说明 |
|------|--------|------|
| `if_always` | — | 无条件通过 |
| `if_min_length` | `{ value: int }` | 当前长度 ≥ value |
| `if_max_length` | `{ value: int }` | 当前长度 ≤ value |
| `if_has_status` | `{ status: "fire" }` | 蛇有任意段携带指定状态 |
| `if_enemy_has_status` | `{ status: "ice" }` | 目标敌人携带指定状态 |
| `if_scale_level` | `{ min: int }` | 鳞片等级 ≥ min |
| `if_random` | `{ chance: float }` | 随机概率 |
| `if_hit_counter_at` | `{ value: int }` | 受击计数器 == value |

#### 3.6.4 内置动作原子（与 T25 + 蛇头/蛇尾共享注册表）

| 原子 | params | 说明 |
|------|--------|------|
| `modify_rule` | `{ rule, modifier }` | 修改规则参数（如 fire_aura_damage +1） |
| `apply_carried_status` | `{ target, status_type }` | 施加 carried_status 给蛇段或敌人 |
| `create_status_tile` | `{ offset, status_type }` | 生成状态格 |
| `direct_grow` | `{ amount }` | 恢复长度（与蛇头共享原子） |
| `damage_area` | `{ center, radius, amount }` | 范围伤害 |
| `push` | `{ target, direction, distance }` | 击退 |
| `modify_hit_counter` | `{ delta }` | 修改受击计数器 |
| `extra_food_drop` | `{ count }` | 额外掉落食物 |
| `modify_effect_value` | `{ chain_id, param, delta }` | 增幅其他链的原子参数 |

#### 3.6.5 鳞片触发流程

```
1. TriggerManager 收到事件（如 on_kill、on_hit_received）
2. 查找当前注册的所有鳞片链
3. 对每条链：
   a. 检查该鳞片所在段位的触发器是否匹配
   b. 按 conditions 数组依次执行条件原子（AND 组合）
   c. 检查冷却是否结束
4. 对通过检查的链，AtomExecutor 按 atoms 数组依次执行
5. 发射 EventBus.scale_triggered { scale_def, slot, atoms_executed }
```

> **与蛇头/蛇尾链的交互：** 蛇鳞链中的 `modify_effect_value` 原子可以增幅蛇头/蛇尾链的参数（如增加 Hydra 的 `direct_grow.amount`）。蛇头/蛇尾链的 `modify_rule` 原子可以改变鳞片触发条件（如改变前段槽的触发事件）。所有交互通过 Atom Chain 管线自然发生，无需特殊耦合代码。

#### 3.6.6 邻接共鸣

两片相邻槽位的鳞片，如果 `resonance_partners` 中包含对方的 id，则触发共鸣：

```
on 鳞片装备/移动:
  遍历所有相邻槽位对
  if scale_a.resonance_partners.has(scale_b.id):
    激活共鸣链（定义在 resonance_table.json 中的 Atom Chain）
    共鸣链通过 TriggerManager 注册，使用与普通链相同的执行流程
    发射 EventBus.scale_resonance_activated { scale_a, scale_b, resonance_effect }
```

#### 3.6.7 关键事件

| 事件（发射） | 触发时机 | 参数 |
|-------------|---------|------|
| `scale_triggered` | 鳞片效果激活 | `{ scale_def, slot_type, slot_index }` |
| `scale_equipped` | 鳞片装入槽位 | `{ scale_def, slot_type, slot_index }` |
| `scale_removed` | 鳞片移除 | `{ scale_def, slot_type, slot_index }` |
| `scale_upgraded` | 鳞片升级 | `{ scale_def, old_level, new_level }` |
| `scale_resonance_activated` | 共鸣激活 | `{ scale_a, scale_b, resonance_effect }` |

| 事件（监听） | 来源 |
|-------------|------|
| 所有游戏事件 | 各系统（用于触发匹配） |

---

### 3.7 🟢 P3 — 地图与房间系统 (MapSystem)

**对应设计文档：** 系统七（第8章）
**目录：** `systems/map/`
**职责：** PCG 生成层级结构、房间内容、连通关系

#### 3.7.1 层级结构

```
Floor（层）:
  theme: FloorThemeDef           # 环境标签 × 压力标签
  rooms: Array[Room]
  connections: Dictionary         # room_id → Array[room_id]
  corruption_level: int           # 腐化进度
  corruption_timer: float

Room:
  id: StringName
  room_type: RoomType            # COMBAT / HUNT / RELIC / SHOP / CURSE / ELITE / HIDDEN / HUB / BOSS
  terrain_template: TerrainTemplate
  modifiers: Array[RoomModifier]
  enemies: Array[EnemySpawnConfig]
  foods: Array[FoodSpawnConfig]
  visit_count: int               # 0=未访问, 1=首次, 2=再次, 3+=枯竭
  is_cleared: bool
```

#### 3.7.2 PCG 四步流程

| 步骤 | 输入 | 输出 | 方法 |
|------|------|------|------|
| Step 1: 层主题 | 当前层数、玩家 Build 信息 | 环境标签 + 压力标签 | 加权随机，考虑层间关联 |
| Step 2: 房间池 | 层主题、固定配额 | 房间类型列表 | 固定配额 + 主题权重修正 |
| Step 3: 房间内容 | 房间类型、层主题 | 地形 + 机制修饰 + 敌人 + 食物 | 三层叠加：底层地形 → 中层修饰 → 表层内容 |
| Step 4: 连通结构 | 所有房间 | 连通图 | 星形/链式/网状，保证双通路 |

#### 3.7.3 房间状态与重访

```
visit_count == 0 → 未访问
visit_count == 1 → 完整内容
visit_count == 2 → 残局：已杀敌不复活，食物减半刷新，机制保留
visit_count >= 3 → 枯竭：无敌人无食物，可能暴露隐藏格
```

#### 3.7.4 腐化进度

```
on EventBus.tick_post_process:
  corruption_timer -= tick_interval
  if corruption_timer <= 0:
    corruption_level += 1
    apply_corruption_effect(corruption_level)
    发射 EventBus.corruption_advanced { level }
```

| 腐化等级 | 效果 |
|----------|------|
| 1 | 地图边缘格子消失 |
| 2 | 中心广场食物停止刷新 |
| 3 | 已清空房间重新生成强化敌人 |
| 4 | Boss 房间强制开启 |

---

### 3.8 🟢 P3 — 事件遭遇系统 (EventEncounterSystem)

**对应设计文档：** 系统八（第9章）
**目录：** `systems/event_encounter/`
**职责：** 管理地图上的建筑物、掉落物、痕迹等事件交互

> **命名说明：** 为避免与 EventBus 混淆，设计文档中的「事件系统」在代码中统一称为 EventEncounter。

#### 3.8.1 三种来源

| 来源 | 代码类 | 触发方式 | GridEntity 子类 |
|------|--------|---------|----------------|
| 建筑物 | `Building` | 蛇头经过相邻格时 → 暂停 → 互动 UI | `Building extends GridEntity` |
| 掉落物 | `Pickup` | 蛇头经过时自动拾取 | `Pickup extends GridEntity` |
| 痕迹 | `Trace` | 蛇头经过时微提示，选择是否停留互动 | `Trace extends GridEntity` |

#### 3.8.2 数据定义

**EventEncounterDef (Resource)：**

```
EventEncounterDef:
  id: StringName
  encounter_type: EncounterType   # BUILDING / PICKUP / TRACE
  trigger_radius: int             # 触发距离（格数，建筑物为 1）
  interaction_config: Dictionary  # 互动选项配置
  rewards: Array[RewardConfig]    # 奖励配置
  spawn_weight_modifiers: Dictionary  # 出现权重修正条件
```

---

### 3.9 🔵 P4 — 成长与奖励系统 (GrowthSystem)

**对应设计文档：** 系统九（第10章）
**目录：** `systems/growth/`
**职责：** 管理一局 Run 内的四个成长维度和货币系统

#### 3.9.1 四个成长维度

| 维度 | 来源 | 频率 | 管理内容 |
|------|------|------|---------|
| 鳞片 | 战斗间/精英间/隐藏格 | 常见 | 鳞片获取、3选1界面 |
| 槽位 | Boss 击败/商人间 | 稀缺 | 槽位数量扩展 |
| 蛇头/尾 | 商人间(升级)/遗迹间(替换) | 罕见 | 等级提升、替换 |
| 蜕皮（货币） | 击杀/放弃鳞片/隐藏格 | 持续积累 | 消费于商人间 |

#### 3.9.2 关键事件

| 事件（发射） | 触发时机 |
|-------------|---------|
| `loot_dropped` | 战斗/精英间完成 |
| `scale_choice_presented` | 玩家需要从 N 选 1 |
| `scale_choice_made` | 玩家做出选择 |
| `slot_unlocked` | 新槽位解锁 |
| `currency_changed` | 蜕皮货币变化 |
| `floor_reward_presented` | 进层奖励 3 选 1 |

---

### 3.10 🔵 P4 — 数值框架与难度系统 (DifficultySystem)

**对应设计文档：** 系统十（第11章）
**目录：** `systems/difficulty/`
**职责：** 层级数值缩放、动态难度调整、无尽模式

#### 3.10.1 核心：数值全部外置

所有数值常量放在 `data/json/balance.json` 中，不硬编码：

```json
{
  "player": {
    "initial_length": 6,
    "length_zones": {
      "danger": [1, 4],
      "survival": [5, 10],
      "combat": [11, 20],
      "comfort": [21, 35],
      "overload": [36, 999]
    }
  },
  "floor_scaling": {
    "1": { "normal_enemy_cost": 1, "elite_cost": 6, "boss_cost": 14, "food_per_room": 10 },
    "2": { "normal_enemy_cost": 1, "elite_cost": 8, "boss_cost": 18, "food_per_room": 9 },
    ...
  },
  "dynamic_difficulty": {
    "strong_threshold_multiplier": 1.5,
    "weak_threshold_multiplier": 0.6,
    "strong_adjustments": { "armor_chance_bonus": 0.2, "food_reduction": 2 },
    "weak_adjustments": { "enemy_reduction": 1, "food_bonus": 3 }
  }
}
```

#### 3.10.2 动态难度调整

```
on EventBus.room_about_to_generate:
  player_strength = 评估玩家当前强度（长度、鳞片质量、蛇头/尾等级）
  expected_strength = 查表获取当前层数预期强度

  if player_strength > expected * strong_threshold:
    应用 strong_adjustments
  elif player_strength < expected * weak_threshold:
    应用 weak_adjustments
```

---

### 3.11 🔵 P5 — 元成长系统 (MetaGrowthSystem)

**对应设计文档：** 系统十一（第12章）
**目录：** `systems/meta_growth/`
**职责：** 跨局 Run 的解锁与传承（见识系统 + 遗愿系统）

#### 3.11.1 持久化数据

元成长数据需要**持久化存储**（保存到磁盘），使用 Godot 的 `ConfigFile` 或 `JSON` 存储到 `user://` 目录。

```
meta_save_data:
  unlocked_heads: Array[StringName]
  unlocked_tails: Array[StringName]
  discovered_scales: Array[StringName]   # "见过即解锁"
  legacy_stones: Array[LegacyStone]      # 遗愿石碑（最多5条）
  endless_stones: Array[LegacyStone]     # 无尽石碑

LegacyStone:
  description: String
  highlight_type: String                  # "combat", "reaction_chain", "survival", ...
  bias_config: Dictionary                 # 继承时的概率倾向修正
```

#### 3.11.2 解锁条件检测

```
on EventBus.run_ended { stats }:
  遍历所有未解锁内容的 unlock_conditions
  if 条件满足:
    解锁 → 保存 → 发射 EventBus.content_unlocked
  生成遗愿 → 保存到石碑
```

---

## 4. 事件目录 Event Catalog

> **使用说明：** 所有事件在 `autoloads/event_bus.gd` 中声明为 `signal`。命名规范：`{主语}_{对象}_{动词过去分词}`。

### 4.1 Tick 生命周期事件

| 事件名 | 参数 | 说明 |
|--------|------|------|
| `tick_pre_process` | `{ tick_index: int }` | Tick 开始前，用于准备阶段 |
| `tick_input_collected` | `{ tick_index: int }` | 输入收集完毕，触发移动 |
| `tick_post_process` | `{ tick_index: int }` | Tick 结算完毕，用于状态更新 |

### 4.2 蛇相关事件

| 事件名 | 参数 | 发射者 | 监听者 |
|--------|------|--------|--------|
| `snake_moved` | `{ body, direction, head_pos, old_tail_pos }` | MovementSystem | LengthSystem, StatusSystem, ScaleSystem |
| `snake_turned` | `{ old_dir, new_dir }` | MovementSystem | ScaleSystem |
| `snake_hit_boundary` | `{ position, direction }` | MovementSystem | GameManager, SnakePartsSystem |
| `snake_hit_self` | `{ position, segment_index }` | MovementSystem | GameManager, SnakePartsSystem |
| `snake_hit_enemy` | `{ enemy, position }` | MovementSystem | EnemySystem, ScaleSystem, LengthSystem |
| ~~`snake_body_crush_enemy`~~ | ~~已在 L1 中移除~~ | — | — |
| `snake_food_eaten` | `{ food, position, food_type }` | MovementSystem | LengthSystem, ScaleSystem, GrowthSystem |
| `snake_length_increased` | `{ amount, source, new_length }` | LengthSystem | ScaleSystem, DifficultySystem |
| `snake_length_decreased` | `{ amount, source, new_length }` | LengthSystem | ScaleSystem, SnakePartsSystem |
| `snake_died` | `{ cause }` | LengthSystem | GameManager, MetaGrowthSystem |
| `snake_body_attacked` | `{ position, segment, enemy, enemy_status, seg_status }` | Enemy | SegmentEffectSystem, VFXManager, HUD |
| `no_body_countdown_started` | `{ total_seconds }` | LengthSystem | HUD |
| `no_body_countdown_tick` | `{ remaining_seconds, total_seconds, ratio }` | LengthSystem | HUD |
| `no_body_countdown_cancelled` | — | LengthSystem | HUD |

### 4.3 长度相关事件

| 事件名 | 参数 | 说明 |
|--------|------|------|
| `length_decrease_requested` | `{ amount, source }` | 任何系统请求减少蛇长度 |
| `length_increase_requested` | `{ amount, source }` | 任何系统请求增加蛇长度 |
| `length_grow_requested` | `{ amount }` | 通知 MovementSystem 下一 tick 不缩尾 |

### 4.4 状态效果事件

| 事件名 | 参数 | 发射者 | 监听者 |
|--------|------|--------|--------|
| `status_applied` | `{ target, status_type, layers, source }` | StatusSystem | ScaleSystem, EnemySystem |
| `status_removed` | `{ target, status_type, reason }` | StatusSystem | ScaleSystem |
| `status_layer_changed` | `{ target, status_type, old_layers, new_layers }` | StatusSystem | ScaleSystem |
| `status_tile_created` | `{ position, status_type, duration }` | StatusSystem | EnemySystem (AI路径更新) |
| `status_tile_expired` | `{ position, status_type }` | StatusSystem | EnemySystem |
| `status_reaction_triggered` | `{ type_a, type_b, position, damage, reaction_name }` | StatusSystem | ScaleSystem, MetaGrowthSystem (统计) |
| `reaction_triggered` | `{ reaction_type, position, radius }` | ReactionSystem (L1) | ReactionSystem (AoE 执行) |

### 4.5 敌人相关事件

| 事件名 | 参数 | 发射者 | 监听者 |
|--------|------|--------|--------|
| `enemy_spawned` | `{ enemy_def, position }` | EnemySystem | — |
| `enemy_killed` | `{ enemy_def, position, method, killer }` | EnemySystem | GrowthSystem, StatusSystem, ScaleSystem |
| `enemy_part_destroyed` | `{ enemy, part_id, part_type }` | EnemySystem | ScaleSystem, GrowthSystem |
| `enemy_damaged` | `{ enemy, amount, source }` | EnemySystem | ScaleSystem |

### 4.6 鳞片相关事件

| 事件名 | 参数 | 发射者 | 监听者 |
|--------|------|--------|--------|
| `scale_triggered` | `{ scale_def, slot_type, slot_index }` | ScaleSystem | MetaGrowthSystem (统计) |
| `scale_equipped` | `{ scale_def, slot_type, slot_index }` | ScaleSystem | ScaleSystem (共鸣检测) |
| `scale_removed` | `{ scale_def, slot_type, slot_index }` | ScaleSystem | ScaleSystem (共鸣检测) |
| `scale_upgraded` | `{ scale_def, old_level, new_level }` | ScaleSystem | — |
| `scale_resonance_activated` | `{ scale_a, scale_b, resonance_effect }` | ScaleSystem | — |

### 4.7 地图/房间事件

| 事件名 | 参数 | 发射者 | 监听者 |
|--------|------|--------|--------|
| `room_entered` | `{ room, visit_count }` | MapSystem | EnemySystem, StatusSystem |
| `room_cleared` | `{ room, room_type }` | MapSystem | GrowthSystem |
| `room_about_to_generate` | `{ floor, room_type }` | MapSystem | DifficultySystem |
| `floor_entered` | `{ floor_number, theme }` | MapSystem | DifficultySystem, MetaGrowthSystem |
| `corruption_advanced` | `{ level }` | MapSystem | GameManager |
| `boss_defeated` | `{ boss_def, floor_number }` | EnemySystem | MapSystem, GrowthSystem |

### 4.8 事件遭遇事件

| 事件名 | 参数 | 说明 |
|--------|------|------|
| `encounter_triggered` | `{ encounter_def, position }` | 建筑物/掉落物/痕迹被触发 |
| `encounter_completed` | `{ encounter_def, outcome }` | 完成互动 |
| `encounter_ignored` | `{ encounter_def }` | 玩家选择忽略 |

### 4.9 成长/奖励事件

| 事件名 | 参数 | 说明 |
|--------|------|------|
| `loot_dropped` | `{ loot_table, position }` | 掉落物生成 |
| `scale_choice_presented` | `{ options, source }` | 鳞片 N 选 1 |
| `scale_choice_made` | `{ chosen, discarded }` | 玩家选定 |
| `slot_unlocked` | `{ slot_type, slot_index }` | 新槽位开放 |
| `currency_changed` | `{ old_amount, new_amount, source }` | 蜕皮变化 |
| `floor_reward_presented` | `{ options }` | 进层奖励 |
| `floor_reward_chosen` | `{ chosen }` | 玩家选定进层奖励 |

### 4.10 全局 GridWorld 事件

| 事件名 | 参数 | 说明 |
|--------|------|------|
| `entity_moved` | `{ entity, from, to }` | 任何 GridEntity 移动 |
| `entity_placed` | `{ entity, position }` | GridEntity 放置到 Grid |
| `entity_removed` | `{ entity, position }` | GridEntity 从 Grid 移除 |

### 4.11 元成长事件

| 事件名 | 参数 | 说明 |
|--------|------|------|
| `run_started` | `{ legacy_stone }` | 新一局开始（可能携带遗愿） |
| `run_ended` | `{ stats, cause }` | 一局结束 |
| `content_unlocked` | `{ content_type, content_id }` | 新内容解锁 |
| `legacy_stone_created` | `{ stone }` | 遗愿生成 |

---

## 5. 数据配置方案

### 5.1 配置分层原则

> **L1 修订：** L1 阶段大幅简化配置方案——所有核心数据统一放入 `game_config.json`，使用 T25 Atom System 的 JSON 驱动模型。Resource (.tres) 文件暂未使用，待 L2+ 内容量增大后按需引入。

| 层级 | 格式 | 用途 | L1 现状 |
|------|------|------|---------|
| **定义+数值+关系层** | JSON | 统一管理所有游戏配置 | `game_config.json`（已实现） |
| **定义层** | Resource (.tres) | 类型安全的实体定义 | L2+ 按需引入 |

### 5.2 game_config.json 结构（L1 已实现）

```json
{
  "grid": { "cell_size": 32, "width": 40, "height": 22 },
  "tick": { "base_interval": 0.25 },
  "snake": { "initial_length": 6, "hits_per_segment_loss": 3, "no_body_grace_seconds": 10 },
  "food": { "max_count": 3, "growth_amount": 1 },
  "enemy": { "max_count": 3, "spawn_weights": {...}, "max_status_tiles": 100 },
  "status_effects": {
    "fire": { "entity_effects": [...], "tile_effects": [...], "visual": {...} },
    "ice": { ... },
    "poison": { ... }
  },
  "reactions": {
    "steam": { "type_a": "fire", "type_b": "ice", ... },
    "toxic_explosion": { ... },
    "frozen_plague": { ... }
  },
  "enemy_types": {
    "wanderer": { "hp": 1, "attack_cooldown": 3, "drop_food_count": 2, ... },
    "chaser": { ... },
    "bog_crawler": { ... }
  },
  "length_thresholds": { "danger": [1,4], "survival": [5,10], ... }
}
```

### 5.3 L2+ 扩展配置（待实现）

| 配置节 | 位置 | 内容 | 状态 |
|--------|------|------|------|
| `snake_heads` | game_config.json | 蛇头 Atom Chain 定义 + level_configs | L2 待添加 |
| `snake_tails` | game_config.json | 蛇尾 Atom Chain 定义 + level_configs | L2 待添加 |
| `snake_scales` | game_config.json | 蛇鳞 Atom Chain 定义 + 共鸣表 | L2 待添加 |
| `resonance_table` | game_config.json | 鳞片邻接共鸣关系 | L2 待添加 |
| `loot_tables` | game_config.json | 各场景掉落概率表 | L2+ |
| `unlock_conditions` | game_config.json | 蛇头/蛇尾解锁条件 | L2+ |

### 5.4 配置热加载

开发阶段需要快速迭代，建议实现以下热加载机制：

1. **JSON 热加载：** `GameManager` 监听 `data/json/` 目录的文件变化，JSON 修改后自动重新加载到内存，无需重启游戏
2. **Resource 重载：** 提供调试命令 / 编辑器插件，支持运行时重载指定 Resource
3. **调试控制台：** 开发期间提供简单的命令行界面，支持：
   - 修改蛇长度
   - 施加/移除状态效果
   - 生成指定敌人
   - 跳转到指定房间
   - 触发指定鳞片效果

### 5.5 T25 Atom 注册表（统一注册）

> **L1 修订：** 原独立的 ConditionRegistry / ActionRegistry 已统一为 T25 的 `AtomRegistry`。所有条件原子和动作原子（包括蛇头/蛇尾/蛇鳞新增的原子）在同一注册表中注册。

```
AtomRegistry（systems/atoms/atom_registry.gd）:
  # T25 已有原子
  "damage" → DamageAtom
  "modify_speed" → ModifySpeedAtom
  "freeze" → FreezeAtom
  "place_tile" → PlaceTileAtom
  "apply_status" → ApplyStatusAtom
  "remove_status" → RemoveStatusAtom
  "modify_growth" → ModifyGrowthAtom
  # 条件原子（is_condition() -> true）
  "if_has_status" → IfHasStatusAtom
  "if_min_length" → IfMinLengthAtom
  "if_random" → IfRandomAtom
  # L2 新增原子（蛇头/蛇尾/蛇鳞系统）
  "modify_food_drop" → ModifyFoodDropAtom
  "direct_grow" → DirectGrowAtom
  "steal_status" → StealStatusAtom
  "modify_hit_threshold" → ModifyHitThresholdAtom
  "delay_loss" → DelayLossAtom
  "grant_invincibility" → GrantInvincibilityAtom
  "modify_rule" → ModifyRuleAtom
  "modify_effect_value" → ModifyEffectValueAtom
  ...（可通过新增 .gd 文件 + 注册一行代码扩展）
```

添加新原子：创建 `systems/atoms/atoms/<category>/<name>_atom.gd` → extends AtomBase → 注册到 `_register_all()`。

---

## 6. MVP 里程碑定义

### 6.1 L0 MVP（最小可运行原型）✅ 已完成

**目标：** 一条蛇在一个房间里能移动、吃食物、死亡。

| 系统 | 范围 | 状态 |
|------|------|------|
| 核心抽象层 | GridEntity, GridWorld, EventBus, TickManager | ✅ |
| 基础移动 | 蛇移动、转向、碰撞检测、输入队列 | ✅ |
| 长度系统 | 吃食物增长、碰撞死亡、No-Body Countdown | ✅ |
| 食物 | 食物 GridEntity，随机/击杀掉落生成 | ✅ |
| 单房间 | 固定大小矩形房间（40×22 格） | ✅ |
| 渲染 | 彩色方块：蛇白灰色、敌人红色系、状态格对应颜色 | ✅ |

### 6.2 L1 战斗循环 ✅ 已完成（1017 测试通过）

**目标：** 蛇吃敌人 → 掉食物 → per-segment status → 敌人攻击蛇身 → 状态反应

| 系统 | 范围 | 状态 |
|------|------|------|
| 敌人系统 | 3 种敌人 AI（wanderer/chaser/bog_crawler）+ 攻击蛇身 | ✅ |
| Per-Segment Status | SnakeSegment.carried_status + 状态继承 | ✅ |
| 敌人攻击 | 受击计数器（3 hit = -1 段）+ 双向状态转移 | ✅ |
| 状态格交互 | 逐段检测 + 永久状态格 + 同位异类互斥 | ✅ |
| 段效果系统 | 火光环/毒液蔓延/冰防御 | ✅ |
| 反应系统 | 蒸腾/毒爆/冻疫 3 种反应 | ✅ |
| T25 Atom System | JSON 驱动可组合效果框架（49 原子，17 触发器） | ✅ |
| 视觉反馈 | 状态覆盖层 + VFX + 攻击闪烁 + 受击计数器 HUD | ✅ |

### 6.3 后续里程碑

| 里程碑 | 包含 | 验收标准 |
|--------|------|---------|
| **L2 Build 系统** (P2) | 蛇头/尾/鳞 统一 Atom Chain + 装备/升级 UI | 可以装备蛇头/鳞片组建 Build，不同组合有明显差异 |
| **L3 完整一局** (P3) | 地图 PCG + 房间类型 + 腐化 | 可以完整打完一局 Run（多层多房间到 Boss） |
| **L4 成长循环** (P4) | 奖励 + 商人 + 数值框架 | 有完整的成长曲线和难度递进 |
| **L5 元成长** (P5) | 解锁 + 遗愿 + 事件遭遇 | 多局 Run 之间有连续性和解锁动力 |

---

## 附录 A：命名约定

| 类别 | 规则 | 示例 |
|------|------|------|
| GDScript 文件名 | `snake_case.gd` | `grid_entity.gd`, `movement_system.gd` |
| 类名 | `PascalCase` | `GridEntity`, `MovementSystem` |
| 信号名 | `snake_case_past_tense` | `snake_moved`, `enemy_killed` |
| Resource 文件名 | `snake_case.tres` | `fire_scale.tres`, `wanderer.tres` |
| JSON key | `snake_case` | `initial_length`, `base_tick_interval` |
| 常量 | `UPPER_SNAKE_CASE` | `CELL_SIZE`, `BASE_TICK_INTERVAL` |
| 枚举值 | `UPPER_SNAKE_CASE` | `EntityType.SNAKE_SEGMENT` |
| 目录名 | `snake_case` | `status_effect/`, `snake_parts/` |

## 附录 B：系统依赖关系图

```
                    GridEntity + GridWorld + EventBus + TickManager
                                    │
                    ┌───────────────┼───────────────┐
                    │               │               │
              MovementSystem  LengthSystem    (基础食物)
              [🔴 P0]         [🔴 P0]         [🔴 P0]
                    │               │
                    └───────┬───────┘
                            │
                ┌───────────┼───────────┐
                │                       │
          StatusSystem            EnemySystem
          [🟠 P1]                 [🟠 P1]
                │                       │
                └───────────┬───────────┘
                            │
                ┌───────────┼───────────┐
                │                       │
         SnakePartsSystem (统一 Atom Chain)
         蛇头/蛇尾/蛇鳞 [🟡 P2]
         复用 T25 AtomRegistry + TriggerManager
                            │
                       MapSystem
                       [🟢 P3]
                            │
                ┌───────────┼───────────┐
                │           │           │
         EventEncounter  GrowthSystem  DifficultySystem
         [🟢 P3]        [🔵 P4]       [🔵 P4]
                                        │
                                  MetaGrowthSystem
                                  [🔵 P5]
```

## 附录 C：开发注意事项

1. **不要跨系统直接引用：** 所有系统间通信必须通过 EventBus。如果发现需要直接调用另一个系统的方法，应该思考是否遗漏了某个事件。

2. **GridEntity 回调 vs EventBus 事件：** `_on_entity_enter` 等回调用于**同一格子内的局部交互**（如踩到状态格获得状态）。EventBus 事件用于**系统级广播**（如蛇吃了食物，多个系统需要响应）。两者互补，不是替代关系。

3. **状态效果是空间现象：** 这是本游戏最核心的设计理念之一。实现时必须始终保持「状态存在于空间中，不只是数值标签」的思维。每个状态效果都要实现实体版本和空间版本。

4. **蛇头/蛇尾是规则改写器：** 它们通过 Hook 改写其他系统的行为，而不是自己包含游戏逻辑。实现 Hook 系统时要保证足够灵活，能支持设计文档中所有示例的蛇头/蛇尾效果。

5. **Condition/Action 系统是扩展性的关键：** 鳞片效果全部通过 Condition+Action 数据描述。新增鳞片应该只需要创建新的 `.tres` 文件，而不需要写新的 GDScript（除非需要全新的 Condition/Action 类型）。

6. **所有数值都可配置：** 硬编码数值是设计迭代的大敌。即使是看起来「不会变」的值（如初始长度 6），也应该从 `balance.json` 读取。

7. **MVP 先行，逐步叠加：** 严格按照 P0→P1→P2→P3→P4→P5 顺序实现。每个里程碑完成后应有可运行的游戏版本。不要提前实现高优先级系统需要的底层机制以外的任何内容。
