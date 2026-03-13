## [L0-T04] GridWorld 网格世界管理器

### 元信息

| 字段 | 值 |
|------|-----|
| **阶段** | L0-MVP |
| **优先级** | P0(阻塞) |
| **前置任务** | L0-T01, L0-T02 |
| **预估粒度** | L(3~6h) |
| **分配职能** | 引擎程序 |

### 概述

创建 Grid 数据管理器，负责所有实体在网格上的注册、查询、移动和碰撞回调链。这是整个游戏逻辑的空间基础层。

### 上下文

| 文档 | 章节/位置 |
|------|----------|
| `TechDocs/ScriptingLeading.md` | §2.2 GridWorld |
| `TechDocs/ScriptingLeading.md` | §2.7 坐标系统约定 |

### 任务详细

1. 创建 `Project/autoloads/grid_world.gd`
2. 在 `project.godot` 中注册为 Autoload，名称 `GridWorld`
3. 实现以下功能：

**核心数据结构：**

```
var cell_map: Dictionary = {}
# key: Vector2i（格子坐标）
# value: Array[GridEntity]（该格上的所有实体）

var grid_width: int    # 从 Constants.GRID_WIDTH 读取
var grid_height: int   # 从 Constants.GRID_HEIGHT 读取
```

**核心方法：**

| 方法 | 签名 | 说明 |
|------|------|------|
| `init_grid` | `(width: int, height: int) -> void` | 初始化/重置网格 |
| `register_entity` | `(entity: Node, pos: Vector2i) -> void` | 注册实体到指定格子 |
| `unregister_entity` | `(entity: Node) -> void` | 移除实体注册 |
| `move_entity` | `(entity: Node, from: Vector2i, to: Vector2i) -> void` | 移动实体并触发回调链 |
| `get_entities_at` | `(pos: Vector2i) -> Array` | 获取指定格子上所有实体 |
| `get_first_entity_of_type` | `(pos: Vector2i, type: int) -> Node` | 获取指定格子上第一个指定类型的实体，无则返回 null |
| `is_cell_blocked` | `(pos: Vector2i) -> bool` | 格子是否被阻挡实体占据 |
| `is_within_bounds` | `(pos: Vector2i) -> bool` | 坐标是否在地图边界内 |
| `get_neighbors` | `(pos: Vector2i) -> Array[Vector2i]` | 获取四方向相邻格（过滤越界） |
| `get_empty_cells` | `() -> Array[Vector2i]` | 获取所有无实体的格子（用于食物生成） |
| `grid_to_world` | `(grid_pos: Vector2i) -> Vector2` | Grid 坐标 → 世界坐标（格子中心） |
| `world_to_grid` | `(world_pos: Vector2) -> Vector2i` | 世界坐标 → Grid 坐标 |
| `clear_all` | `() -> void` | 清空所有实体注册（用于重开游戏） |

**`move_entity()` 回调链（关键核心！）：**

当调用 `move_entity(entity, from, to)` 时，严格按以下顺序执行：

```
1. 从 cell_map[from] 中移除 entity
2. 对 cell_map[from] 中剩余实体逐一调用 entity._on_entity_exit(moving_entity)（如果方法存在）
3. 将 entity 加入 cell_map[to]
4. 对 cell_map[to] 中已有的其他实体逐一调用 other._on_entity_enter(entity)（如果方法存在）
5. 对 cell_map[to] 中已有的 cell_layer == 0 的实体调用 ground._on_stepped_on(entity)（如果方法存在）
6. 发射 EventBus.entity_moved.emit({ "entity": entity, "from": from, "to": to })
7. 更新 entity.global_position = grid_to_world(to)（如果 entity 有此属性）
```

> **为什么回调链如此重要？** 蛇踩到食物、蛇头碰敌人、蛇经过状态格等所有交互，全部通过这个回调链统一触发，而不是在各个系统中单独检测。

**坐标转换公式：**

```
grid_to_world(grid_pos) = Vector2(grid_pos.x * CELL_SIZE + CELL_SIZE / 2, grid_pos.y * CELL_SIZE + CELL_SIZE / 2)
world_to_grid(world_pos) = Vector2i(int(world_pos.x / CELL_SIZE), int(world_pos.y / CELL_SIZE))
```

**需要创建的文件：**
- `Project/autoloads/grid_world.gd`

**需要修改的文件：**
- `Project/project.godot` — 添加 GridWorld Autoload

### 技术约束

- 继承 `Node`
- GridWorld 是**纯数据层**，不负责任何渲染
- `cell_map` 中不存在的 key 应返回空数组，不应崩溃
- `move_entity()` 的回调链中，调用实体方法前须用 `has_method()` 检查（因为 MVP 中并非所有实体都继承 GridEntity）
- `register_entity()` 内部同时发射 `EventBus.entity_placed` 事件
- `unregister_entity()` 内部同时发射 `EventBus.entity_removed` 事件
- 所有 `get_*` 查询方法必须对越界坐标返回安全值（空数组 / false / null），不抛出异常

### 验收标准

- [ ] `grid_world.gd` 存在且已注册为 Autoload
- [ ] `init_grid(20, 11)` 后，`is_within_bounds(Vector2i(0, 0))` 返回 `true`
- [ ] `is_within_bounds(Vector2i(-1, 0))` 和 `is_within_bounds(Vector2i(20, 11))` 返回 `false`
- [ ] `register_entity()` 后 `get_entities_at()` 能查到该实体
- [ ] `unregister_entity()` 后 `get_entities_at()` 查不到该实体
- [ ] `move_entity()` 后实体从旧格移至新格，旧格查不到、新格能查到
- [ ] `move_entity()` 过程中，目标格已有实体的 `_on_entity_enter()` 被调用
- [ ] `get_empty_cells()` 返回所有无实体占据的格子坐标
- [ ] `grid_to_world()` 和 `world_to_grid()` 互为逆运算（允许整数截断误差）
- [ ] 对越界坐标的查询不崩溃，返回安全值

### 备注

- MVP 中 `find_path()` 寻路方法**不需要实现**（敌人是静止的），留待 L1 实现
- `get_neighbors_8()`（八方向）也不需要在 MVP 中实现
- 注意 `cell_map` 使用 `Dictionary` 而非二维数组，这样更灵活（支持将来的非矩形地图）
- `move_entity()` 的回调中，调用的是实体上的方法。后续的 GridEntity 基类（T05）会提供这些虚方法的默认实现
