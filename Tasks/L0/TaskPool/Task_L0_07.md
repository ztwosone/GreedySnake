## [L0-T07] LengthSystem 长度系统

### 元信息

| 字段 | 值 |
|------|-----|
| **阶段** | L0-MVP |
| **优先级** | P1(核心) |
| **前置任务** | L0-T02, L0-T06 |
| **预估粒度** | M(1~3h) |
| **分配职能** | Gameplay 程序 |

### 概述

实现长度管理系统——长度是本游戏唯一的数值单位，同时扮演生命值和战斗资源。LengthSystem 响应增减请求，执行实际的蛇身增长/缩短，并在长度归零时触发死亡。

### 上下文

| 文档 | 章节/位置 |
|------|----------|
| `TechDocs/ScriptingLeading.md` | §3.2 长度系统 (LengthSystem) |
| `Designs/General/snake_roguelite_design.md` | §3 系统二：长度系统 |

### 任务详细

1. 创建 `Project/systems/length/length_system.gd`
2. LengthSystem 作为 Node 附加到游戏场景中（非 Autoload）

**核心属性：**

| 属性 | 类型 | 说明 |
|------|------|------|
| `snake` | `Node` (Snake 引用) | 对 Snake 控制器的引用 |
| `current_length` | `int` (只读计算属性) | 直接返回 `snake.body.size()` |

**核心逻辑 — 事件监听与响应：**

```
func _ready():
    EventBus.snake_food_eaten.connect(_on_food_eaten)
    EventBus.length_decrease_requested.connect(_on_decrease_requested)
    EventBus.snake_hit_boundary.connect(_on_death_collision)
    EventBus.snake_hit_self.connect(_on_death_collision)

# 吃到食物 → 增长
func _on_food_eaten(data: Dictionary):
    var amount = 1  # MVP 中基础食物固定 +1
    snake.grow_pending += amount
    EventBus.snake_length_increased.emit({
        "amount": amount,
        "source": "food",
        "new_length": snake.body.size() + snake.grow_pending
    })

# 长度减少请求（来自战斗、状态效果等）
func _on_decrease_requested(data: Dictionary):
    var amount: int = data.get("amount", 1)
    var source: String = data.get("source", "unknown")

    # 执行缩短：从蛇尾移除
    for i in range(amount):
        if snake.body.size() <= 1:
            # 长度归零 → 死亡
            EventBus.snake_died.emit({"cause": source})
            snake.die(source)
            return
        snake.remove_tail_segment()

    EventBus.snake_length_decreased.emit({
        "amount": amount,
        "source": source,
        "new_length": snake.body.size()
    })

# 碰撞死亡（撞墙/撞自身）
func _on_death_collision(data: Dictionary):
    var cause = "hit_boundary" if data.has("direction") else "hit_self"
    EventBus.snake_died.emit({"cause": cause})
    snake.die(cause)
```

**Snake 控制器需要暴露的接口（T06 应已提供，此处确认）：**

| 方法/属性 | 说明 |
|----------|------|
| `body: Array[Vector2i]` | 蛇身坐标队列 |
| `grow_pending: int` | 待增长格数 |
| `remove_tail_segment()` | 移除最后一格 |
| `die(cause: String)` | 蛇死亡（停止移动，标记 is_alive=false） |

**需要创建的文件：**
- `Project/systems/length/length_system.gd`

### 技术约束

- 继承 `Node`，不是 Autoload
- LengthSystem **不直接操作 GridWorld**，而是通过 Snake 控制器的方法间接操作
- 长度减少时从**蛇尾**开始移除（FIFO 队列原则）
- 长度归零（`body.size() <= 1` 时再减少）触发死亡，最后一格（蛇头）不可移除
- 所有长度变化都必须发射对应事件（`snake_length_increased` / `snake_length_decreased`）

### 验收标准

- [ ] `length_system.gd` 存在且正确监听 EventBus 事件
- [ ] 蛇吃到食物后，`snake.grow_pending` 增加 1，下一 tick 蛇不缩尾（长度+1）
- [ ] 发射 `length_decrease_requested` 事件后，蛇从尾部缩短指定格数
- [ ] 缩短后蛇身的 GridWorld 注册正确更新（旧尾格已注销）
- [ ] 蛇长度缩短到只剩 1 格时再请求缩短 → 发射 `snake_died` 事件
- [ ] 蛇头撞墙 → 发射 `snake_died` 事件
- [ ] 蛇头撞自身 → 发射 `snake_died` 事件
- [ ] 每次长度变化后 `snake_length_increased` / `snake_length_decreased` 事件中 `new_length` 值正确

### 备注

- MVP 中食物固定 +1 格。后续版本中特殊食物可能 +2 或有附加效果，通过 `data` 字典中的额外字段传递
- `length_decrease_requested` 是一个**通用请求事件**，任何系统都可以发射它来造成伤害。MVP 中只有战斗（T09）会发射；后续版本中灼烧等状态效果也会发射
- LengthSystem 需要持有对 Snake 的引用。建议在游戏场景组装时（T10）通过 `@export` 或 `get_node()` 注入
