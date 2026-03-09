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
| **Grid-based** | 所有游戏逻辑在离散网格上运行 | 64×64 像素/格；所有位置用 `Vector2i` 表示；不存在亚格级运动 |
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
| `CELL_SIZE` | `64` | 格子像素大小 |
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
  equipped_scale: ScaleDef       # 此段装备的蛇鳞（可为 null）
  status_effects: Array          # 此段携带的状态效果
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

#### 3.2.3 关键事件

| 事件（发射） | 触发时机 | 参数 |
|-------------|---------|------|
| `snake_length_increased` | 长度增加后 | `{ amount, source, new_length }` |
| `snake_length_decreased` | 长度减少后 | `{ amount, source, new_length }` |
| `snake_died` | 长度归零 | `{ cause }` |
| `length_grow_requested` | 需要增长时 | `{ amount }` |

| 事件（监听） | 来源 |
|-------------|------|
| `snake_food_eaten` | MovementSystem |
| `length_decrease_requested` | StatusSystem / CombatSystem / 任何造成伤害的系统 |
| `snake_moved` | MovementSystem |

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

**StatusEffectDef (Resource)：**

```
StatusEffectDef:
  id: StringName                     # "fire", "ice", "poison", "acid", "electric", "void"
  display_name: String
  entity_effect: EntityEffectConfig  # 实体上的效果配置
  spatial_effect: SpatialEffectConfig # 空间上的效果配置
  transfer_rule: TransferRule        # 实体→空间 / 空间→实体转化规则
  visual: StatusVisualConfig         # 视觉配置（颜色、粒子）

EntityEffectConfig:
  tick_damage: int                   # 每 N tick 造成的长度伤害（0=不伤害）
  tick_interval: int                 # 伤害间隔（tick 数）
  duration_ticks: int                # 持续时间（tick 数）
  max_layers: int                    # 最大层数
  special_rules: Array[String]       # 特殊规则标识符（由系统代码解释）

SpatialEffectConfig:
  duration_seconds: float            # 空间状态格持续时间
  spread_chance: float               # 每秒蔓延概率（0.0~1.0）
  blocks_food_spawn: bool            # 是否阻止食物生成
```

**StatusInstance（运行时实例）：**

```
StatusInstance:
  def: StatusEffectDef               # 引用的定义
  layers: int                        # 当前层数
  remaining_ticks: int               # 剩余持续 tick
  carrier: GridEntity                # 附着的实体（实体载体时）
  grid_position: Vector2i            # 所在格子（空间载体时）
```

#### 3.3.3 状态反应系统

**反应表（reaction_table.json）：**

```json
{
  "fire+ice": { "reaction": "evaporation", "coefficient": 0.5, "result_effect": "steam_cloud" },
  "fire+poison": { "reaction": "toxic_explosion", "coefficient": 1.0, "result_effect": "burn_poison_aoe" },
  "ice+electric": { "reaction": "superconduct", "coefficient": 1.5, "result_effect": "chain_lightning" },
  ...
}
```

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

#### 3.4.4 战斗判定

**蛇头撞击敌人：**
```
on EventBus.snake_hit_enemy { enemy, position }:
  attack_cost = enemy.get_attack_cost()  # 默认 1，有护甲则更多
  发射 EventBus.length_decrease_requested { amount: attack_cost, source: "combat" }
  enemy.take_damage(1)
  if enemy.hp <= 0:
    enemy.die()
    发射 EventBus.enemy_killed { enemy, position, method: "head_strike" }
```

**蛇身碾压敌人（蛇身段移动到敌人格子）：**
```
SnakeSegment._on_entity_enter(other):
  if other is Enemy and segment_type == BODY:
    发射 EventBus.snake_body_crush_enemy { enemy, segment_index }
```

#### 3.4.5 部位系统（精英/Boss 专用）

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

### 3.5 🟡 P2 — 蛇头/蛇尾系统 (SnakePartsSystem)

**对应设计文档：** 系统四（第5章）
**目录：** `systems/snake_parts/`
**职责：** 管理蛇头/蛇尾的「规则层」改写效果

#### 3.5.1 设计关键：规则改写机制

蛇头/蛇尾的核心功能是**改写其他系统的行为规则**，而非简单地加减数值。

**实现方式 — Hook 模式：**

在关键系统的关键流程中，预留 Hook 点。蛇头/蛇尾通过注册 Hook 来改写流程。

```
Hook 点示例：
  MovementSystem:
    hook_pre_collision(collision_data) -> collision_data    # 碰撞判定前（可修改碰撞结果）
    hook_post_move(move_data) -> move_data                 # 移动后（可追加效果）

  LengthSystem:
    hook_on_length_decrease(decrease_data) -> decrease_data  # 长度减少前（可修改减少量/追加触发）
    hook_on_length_increase(increase_data) -> increase_data  # 长度增加前

  ScaleSystem:
    hook_on_scale_trigger(trigger_data) -> trigger_data     # 鳞片触发前（可修改触发条件/效果）
```

**SnakeHeadDef (Resource)：**

```
SnakeHeadDef:
  id: StringName                   # "hydra", "bai_she", ...
  display_name: String
  level: int                       # I / II / III
  hooks: Dictionary                # { hook_name: hook_config }
  level_configs: Array[Dictionary] # 每个等级的 hook 参数
```

**示例 — 九头蛇 Hydra：**

```
hooks:
  "hook_on_length_decrease":
    action: "also_trigger_back_slot"     # 长度缩短 = 同时触发后段槽
    level_params:
      1: { trigger_count: 1, save_chance: 0.0 }
      2: { trigger_count: 1, save_chance: 0.3 }
      3: { trigger_count: 2, save_chance: 0.3 }
```

#### 3.5.2 蛇头/蛇尾的吞噬/锚定操作

```
吞噬（蛇头）：
  蛇头可吞噬紧接在后的第一片鳞片
  → 该鳞片效果融入蛇头（成为蛇头的附加 Hook）
  → 蛇头转向判定变为 2 格
  → 在 SnakeHeadDef 运行时数据中记录 absorbed_scale_id

锚定（蛇尾）：
  蛇尾可锚定紧接在前的最后一片鳞片
  → 该鳞片在长度缩短时最后才失去
  → 蛇尾被动效果触发概率降低 50%
  → 在 SnakeTailDef 运行时数据中记录 anchored_scale_id
```

---

### 3.6 🟡 P2 — 蛇鳞系统 (ScaleSystem)

**对应设计文档：** 系统五（第6章）
**目录：** `systems/scales/`
**职责：** 管理蛇鳞（遗物）的装备、触发、升级、邻接共鸣

#### 3.6.1 核心概念：槽位 + 触发

蛇身分为前段、中段、后段三个区域，每个区域有固定数量的槽位。鳞片装入槽位后，其触发方式由**段位**决定：

| 段位 | 默认触发条件 | 可被改写者 |
|------|-------------|-----------|
| 前段 | 蛇头发生接触行为时 | 蛇头 Hook |
| 中段 | 持续被动（只要装着就运作） | — |
| 后段 | 蛇身受到影响时（长度缩短、被攻击） | 蛇尾 Hook |

#### 3.6.2 核心数据结构

**ScaleDef (Resource)：**

```
ScaleDef:
  id: StringName                  # "fire_scale", "poison_scale", ...
  display_name: String
  tags: Array[StringName]         # ["fire"], ["poison", "terrain"], ...
  category: ScaleCategory         # PATTERN / FORM / CURSE

  effects: Array[ScaleEffect]     # 各等级效果
  level_3_mutation: ScaleEffect   # III 级质变效果（独立定义）

  resonance_partners: Array[StringName]  # 可共鸣的鳞片 ID 列表

ScaleEffect:
  trigger_event: StringName       # 监听的事件名（如 "snake_hit_enemy"）
  conditions: Array[Condition]    # 触发条件数组
  actions: Array[Action]          # 触发时执行的动作数组
  cooldown_ticks: int             # 冷却 tick 数

Condition:
  type: String                    # "min_length", "has_status", "target_type", ...
  params: Dictionary

Action:
  type: String                    # "apply_status", "create_tile", "heal", "damage_area", ...
  params: Dictionary
```

> **关键设计：** ScaleDef 的 `effects` 通过通用的 Condition + Action 系统描述，而非为每个鳞片硬编码。这使得新鳞片可以纯数据驱动地添加，无需写新的 GDScript。

#### 3.6.3 Condition / Action 系统

**内置 Condition 类型：**

| type | params | 说明 |
|------|--------|------|
| `always` | — | 无条件触发 |
| `min_length` | `{ value: int }` | 当前长度 ≥ value |
| `max_length` | `{ value: int }` | 当前长度 ≤ value |
| `has_status` | `{ target: "self"/"enemy", status: "fire" }` | 目标有指定状态 |
| `scale_level` | `{ min: int }` | 鳞片等级 ≥ min |
| `random_chance` | `{ chance: float }` | 随机概率 |

**内置 Action 类型：**

| type | params | 说明 |
|------|--------|------|
| `apply_status` | `{ target, status_type, layers }` | 施加状态效果 |
| `create_status_tile` | `{ offset, status_type, duration }` | 生成状态格 |
| `heal` | `{ amount }` | 恢复长度 |
| `damage_area` | `{ center, radius, amount }` | 范围伤害 |
| `push` | `{ target, direction, distance }` | 击退 |
| `spawn_projectile` | `{ type, direction }` | 生成投射物 |
| `modify_tick_speed` | `{ multiplier, duration }` | 修改 tick 速度 |

#### 3.6.4 鳞片触发流程

```
1. EventBus 上某事件触发（如 snake_hit_enemy）
2. ScaleSystem 收到事件
3. 遍历所有已装备的鳞片：
   a. 检查该鳞片的 trigger_event 是否匹配
   b. 检查该鳞片所在段位的触发条件是否满足（前段 = 头接触、中段 = 持续、后段 = 受攻击）
   c. 检查蛇头/蛇尾 Hook 是否改写了触发条件
   d. 检查鳞片自身的 conditions 是否全部通过
   e. 检查冷却是否结束
4. 对通过检查的鳞片，按 actions 数组依次执行
5. 发射 EventBus.scale_triggered { scale_def, slot, actions_executed }
```

#### 3.6.5 邻接共鸣

两片相邻槽位的鳞片，如果 `resonance_partners` 中包含对方的 id，则触发共鸣：

```
on 鳞片装备/移动:
  遍历所有相邻槽位对
  if scale_a.resonance_partners.has(scale_b.id):
    激活共鸣效果（定义在 resonance_table.json 中）
    发射 EventBus.scale_resonance_activated { scale_a, scale_b, resonance_effect }
```

#### 3.6.6 关键事件

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
| `snake_body_crush_enemy` | `{ enemy, segment_index }` | SnakeSegment | EnemySystem, ScaleSystem |
| `snake_food_eaten` | `{ food, position, food_type }` | MovementSystem | LengthSystem, ScaleSystem, GrowthSystem |
| `snake_length_increased` | `{ amount, source, new_length }` | LengthSystem | ScaleSystem, DifficultySystem |
| `snake_length_decreased` | `{ amount, source, new_length }` | LengthSystem | ScaleSystem, SnakePartsSystem |
| `snake_died` | `{ cause }` | LengthSystem | GameManager, MetaGrowthSystem |

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

| 层级 | 格式 | 用途 | 示例 |
|------|------|------|------|
| **定义层** | Resource (.tres) | 定义实体**是什么**，包含结构化数据和类型安全 | ScaleDef、EnemyDef、SnakeHeadDef |
| **数值层** | JSON | 定义实体**有多强**，便于批量调参和外部工具编辑 | balance.json、loot_tables.json |
| **关系层** | JSON | 定义实体**之间的关系**，如反应表、共鸣表 | reaction_table.json、resonance_table.json |

### 5.2 Resource 定义清单

| Resource 类型 | 目录 | 关键字段 |
|--------------|------|---------|
| `ScaleDef` | `data/resources/scales/` | id, tags, effects (Condition+Action), level_3_mutation |
| `EnemyDef` | `data/resources/enemies/` | id, tier, hp, status_response, behavior_config, parts |
| `SnakeHeadDef` | `data/resources/snake_heads/` | id, hooks, level_configs |
| `SnakeTailDef` | `data/resources/snake_tails/` | id, hooks, level_configs |
| `StatusEffectDef` | `data/resources/status_effects/` | id, entity_effect, spatial_effect, transfer_rule |
| `RoomTemplateDef` | `data/resources/rooms/` | terrain_grid, spawn_points, modifier_slots |
| `FloorThemeDef` | `data/resources/floors/` | env_tag, pressure_tag, room_weights |
| `EventEncounterDef` | `data/resources/encounters/` | type, interaction_config, rewards |

### 5.3 JSON 调参文件清单

| 文件 | 路径 | 内容 |
|------|------|------|
| `balance.json` | `data/json/balance.json` | 所有数值常量：初始长度、层级缩放、安全阈值等 |
| `reaction_table.json` | `data/json/reaction_table.json` | 6×6 状态反应矩阵及效果定义 |
| `resonance_table.json` | `data/json/resonance_table.json` | 鳞片邻接共鸣对照表 |
| `loot_tables.json` | `data/json/loot_tables.json` | 各场景掉落概率表 |
| `unlock_conditions.json` | `data/json/unlock_conditions.json` | 蛇头/蛇尾解锁条件 |

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

### 5.5 Condition / Action 注册表

ScaleSystem 的 Condition 和 Action 通过**注册表模式**实现可扩展性：

```
ConditionRegistry:
  "always" → AlwaysCondition
  "min_length" → MinLengthCondition
  "has_status" → HasStatusCondition
  ...（可在运行时注册新类型）

ActionRegistry:
  "apply_status" → ApplyStatusAction
  "create_status_tile" → CreateStatusTileAction
  "heal" → HealAction
  ...（可在运行时注册新类型）
```

这允许在不修改核心系统代码的情况下，通过注册新的 Condition/Action 类型来扩展鳞片能力。

---

## 6. MVP 里程碑定义

### 6.1 MVP（最小可运行原型）范围

**目标：** 一条蛇在一个房间里能移动、吃食物、撞敌人、死亡。

**包含的系统（🔴 P0）：**

| 系统 | MVP 范围 | 不包含 |
|------|---------|--------|
| 核心抽象层 | GridEntity, GridWorld, EventBus, TickManager | StateMachine（P1 才需要） |
| 基础移动 | 蛇移动、转向、碰撞检测 | 输入队列优化 |
| 长度系统 | 吃食物增长、碰撞死亡 | 长度缩短（P1 的战斗消耗） |
| 食物 | 基础食物 GridEntity，随机生成 | 特殊食物、移动食物 |
| 简单敌人 | 1 种静止敌人（占格子，碰到就死+消耗 1 格） | AI 移动、状态响应 |
| 渲染 | 最简视觉：彩色方块表示蛇/食物/敌人/墙壁 | 精灵、动画、粒子 |
| 单房间 | 固定大小的矩形房间 | PCG、多房间、通道 |

### 6.2 MVP 验收标准

- [ ] 蛇在 Grid 上按 0.25s tick 移动
- [ ] 方向键/WASD 控制转向，不允许 180° 反向
- [ ] 蛇头碰墙壁或自身 → 游戏结束
- [ ] 食物随机出现在空格上
- [ ] 蛇头碰食物 → 长度 +1，新食物生成
- [ ] 静止敌人存在于地图上
- [ ] 蛇头碰敌人 → 敌人消失，蛇长度 -1
- [ ] 蛇长度降为 0 → 游戏结束
- [ ] EventBus 事件正常发射和监听（可通过日志验证）
- [ ] GridWorld 正确追踪所有实体位置

### 6.3 后续里程碑

| 里程碑 | 包含 | 验收标准 |
|--------|------|---------|
| **M1 战斗可玩** (P1) | 状态效果系统 + 敌人 AI + 碾压机制 | 蛇可以利用状态格和移动路线击败多种敌人 |
| **M2 Build 系统** (P2) | 蛇头/尾 + 蛇鳞 + Condition/Action | 可以装备鳞片组建 Build，感受到不同组合的差异 |
| **M3 完整一局** (P3) | 地图 PCG + 房间类型 + 腐化 | 可以完整打完一局 Run（多层多房间到 Boss） |
| **M4 成长循环** (P4) | 奖励 + 商人 + 数值框架 | 有完整的成长曲线和难度递进 |
| **M5 元成长** (P5) | 解锁 + 遗愿 + 事件遭遇 | 多局 Run 之间有连续性和解锁动力 |

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
         SnakePartsSystem         ScaleSystem
         [🟡 P2]                  [🟡 P2]
                │                       │
                └───────────┬───────────┘
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
