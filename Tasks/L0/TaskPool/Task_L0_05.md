## [L0-T05] GridEntity 万物基类

### 元信息

| 字段 | 值 |
|------|-----|
| **阶段** | L0-MVP |
| **优先级** | P0(阻塞) |
| **前置任务** | L0-T01, L0-T04 |
| **预估粒度** | M(1~3h) |
| **分配职能** | 引擎程序 |

### 概述

创建所有 Grid 上实体的基类 `GridEntity`，统一位置管理、碰撞标记、GridWorld 注册/注销接口和虚方法回调。蛇身段、敌人、食物在后续任务中都将继承此类。

### 上下文

| 文档 | 章节/位置 |
|------|----------|
| `TechDocs/ScriptingLeading.md` | §2.1 GridEntity — 万物基类 |

### 任务详细

1. 创建 `Project/core/grid_entity.gd`
2. 实现 GridEntity 的完整基类接口

**核心属性：**

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `grid_position` | `Vector2i` | `Vector2i.ZERO` | 当前格子坐标 |
| `entity_type` | `int` (Constants.EntityType) | `-1` | 实体类型枚举 |
| `blocks_movement` | `bool` | `false` | 是否阻挡移动 |
| `is_solid` | `bool` | `true` | 是否参与碰撞 |
| `cell_layer` | `int` | `1` | 格子内层级（0=地面, 1=实体） |

**核心方法（虚方法 — 子类 override）：**

| 方法 | 签名 | 默认实现 | 说明 |
|------|------|---------|------|
| `_on_entity_enter` | `(other: Node) -> void` | 空 | 另一个实体进入本格时调用 |
| `_on_entity_exit` | `(other: Node) -> void` | 空 | 另一个实体离开本格时调用 |
| `_on_tick` | `() -> void` | 空 | 每 tick 调用（需自行连接 EventBus） |
| `_on_stepped_on` | `(stepper: Node) -> void` | 空 | 被另一个实体踩过时调用（cell_layer=0 的实体） |

**实体方法（子类直接使用，不需 override）：**

| 方法 | 签名 | 说明 |
|------|------|------|
| `place_on_grid` | `(pos: Vector2i) -> void` | 放置到 Grid 上，调用 GridWorld.register_entity()，更新 grid_position 和 global_position |
| `remove_from_grid` | `() -> void` | 从 Grid 上移除，调用 GridWorld.unregister_entity() |
| `move_to` | `(new_pos: Vector2i) -> void` | 移动到新位置，调用 GridWorld.move_entity()，更新 grid_position |

**`place_on_grid()` 实现要点：**

```
func place_on_grid(pos: Vector2i) -> void:
    grid_position = pos
    global_position = GridWorld.grid_to_world(pos)
    GridWorld.register_entity(self, pos)
```

**`remove_from_grid()` 实现要点：**

```
func remove_from_grid() -> void:
    GridWorld.unregister_entity(self)
```

**`move_to()` 实现要点：**

```
func move_to(new_pos: Vector2i) -> void:
    var old_pos = grid_position
    grid_position = new_pos
    GridWorld.move_entity(self, old_pos, new_pos)
    # global_position 由 GridWorld.move_entity() 内部更新
```

**需要创建的文件：**
- `Project/core/grid_entity.gd`

### 技术约束

- 继承 `Node2D`（需要 `global_position` 用于渲染）
- 使用 `class_name GridEntity` 声明全局类名，使其可被子类继承
- 虚方法使用空函数体作为默认实现（GDScript 没有 abstract，子类直接 override）
- `place_on_grid()` / `remove_from_grid()` / `move_to()` 是**最终方法**，子类不应 override 这些，而是 override 回调方法
- GridEntity 自身不负责视觉表现（子类在场景中添加 Sprite2D / ColorRect 等节点）

### 验收标准

- [ ] `grid_entity.gd` 存在且声明了 `class_name GridEntity`
- [ ] 继承自 `Node2D`
- [ ] 所有列出的属性和方法存在且签名正确
- [ ] `place_on_grid()` 正确调用 `GridWorld.register_entity()` 并更新 `global_position`
- [ ] `remove_from_grid()` 正确调用 `GridWorld.unregister_entity()`
- [ ] `move_to()` 正确调用 `GridWorld.move_entity()` 并更新 `grid_position`
- [ ] 子类可通过 `extends GridEntity` 继承并 override 虚方法
- [ ] 创建一个 GridEntity 实例并调用 `place_on_grid(Vector2i(5, 5))`，可在 GridWorld 中查到

### 备注

- `entity_type` 使用 `int` 而非直接引用 `Constants.EntityType` 枚举，是因为 GDScript 中枚举本质上是 int。子类在赋值时使用 `Constants.EntityType.FOOD` 等常量
- MVP 中 `_on_tick()` 回调不由 GridEntity 自动连接到 EventBus，而是由需要 tick 行为的子类自行在 `_ready()` 中连接。这避免所有实体都收到不需要的 tick 事件
