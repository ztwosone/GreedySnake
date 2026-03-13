## [L0-T06] Snake 实体与移动系统

### 元信息

| 字段 | 值 |
|------|-----|
| **阶段** | L0-MVP |
| **优先级** | P1(核心) |
| **前置任务** | L0-T02, L0-T03, L0-T04, L0-T05 |
| **预估粒度** | XL(> 6h) |
| **分配职能** | Gameplay 程序 |

### 概述

实现蛇的完整数据结构和移动系统——这是整个游戏的操作核心。蛇由一个控制器管理多个 SnakeSegment（继承 GridEntity）组成，每 tick 按当前方向移动一格。

### 上下文

| 文档 | 章节/位置 |
|------|----------|
| `TechDocs/ScriptingLeading.md` | §3.1 基础移动系统 (MovementSystem) |
| `Designs/General/snake_roguelite_design.md` | §2 系统一：基础移动系统 |

### 任务详细

#### 步骤 1：创建 SnakeSegment

`SnakeSegment` 是蛇身每一格的 GridEntity。

```
SnakeSegment (extends GridEntity):
  segment_index: int         # 在蛇身中的位置（0=头）
  segment_type: int          # 0=HEAD, 1=BODY, 2=TAIL（用常量定义）
  entity_type = Constants.EntityType.SNAKE_SEGMENT
  blocks_movement = true
  is_solid = true
```

每个 SnakeSegment 需要一个简单的视觉表现：一个 `ColorRect` 子节点，大小 `CELL_SIZE × CELL_SIZE`（MVP 中蛇头用亮绿色，蛇身用绿色，蛇尾用深绿色）。

#### 步骤 2：创建 Snake 控制器

`Snake` 是管理所有 SnakeSegment 的控制器节点。

```
Snake (extends Node2D):
  body: Array[Vector2i]              # 有序坐标队列，body[0]=蛇头
  segments: Array[SnakeSegment]      # 对应的段实例
  direction: Vector2i                # 当前方向
  input_buffer: Vector2i             # 下一次转向输入缓存
  is_alive: bool
  grow_pending: int                  # 待增长格数（由 LengthSystem 设置）
```

**核心方法：**

| 方法 | 说明 |
|------|------|
| `init_snake(start_pos: Vector2i, length: int, dir: Vector2i)` | 初始化蛇，在指定位置生成指定长度 |
| `process_input()` | 从 `input_buffer` 读取并验证转向 |
| `move()` | 执行一步移动（核心逻辑，见下方详细流程） |
| `add_segment_at_tail()` | 在尾部增加一格 |
| `remove_tail_segment()` | 移除最后一格 |
| `die(cause: String)` | 蛇死亡处理 |

#### 步骤 3：实现移动逻辑

**`move()` 方法 — 每 tick 调用一次：**

```
func move():
    # 1. 读取输入
    process_input()

    # 2. 计算新蛇头位置
    var new_head_pos = body[0] + direction

    # 3. 边界检测
    if not GridWorld.is_within_bounds(new_head_pos):
        EventBus.snake_hit_boundary.emit({"position": new_head_pos, "direction": direction})
        return

    # 4. 自身碰撞检测（跳过尾巴，因为尾巴即将移走，除非在增长）
    var body_to_check = body.slice(0, body.size() - 1) if grow_pending <= 0 else body
    if new_head_pos in body_to_check:
        EventBus.snake_hit_self.emit({"position": new_head_pos, "segment_index": body.find(new_head_pos)})
        return

    # 5. 检测目标格上的实体（战斗/食物判定）
    var entities_at_target = GridWorld.get_entities_at(new_head_pos)
    for entity in entities_at_target:
        if entity.entity_type == Constants.EntityType.ENEMY:
            EventBus.snake_hit_enemy.emit({"enemy": entity, "position": new_head_pos})
            # 注意：不 return，碰撞后蛇是否继续移动取决于后续设计
            # MVP 中蛇头撞敌人后敌人消失，蛇继续前进到那个格子
        elif entity.entity_type == Constants.EntityType.FOOD:
            EventBus.snake_food_eaten.emit({"food": entity, "position": new_head_pos, "food_type": "basic"})

    # 6. 执行移动：插入新蛇头
    body.push_front(new_head_pos)
    var new_head_segment = _create_segment(new_head_pos, 0, HEAD)
    segments.push_front(new_head_segment)
    # 旧蛇头变为 body
    if segments.size() > 1:
        segments[1].segment_type = BODY
        _update_segment_visual(segments[1])

    # 7. 处理尾巴
    if grow_pending > 0:
        grow_pending -= 1
    else:
        var old_tail_pos = body.pop_back()
        var old_tail_seg = segments.pop_back()
        old_tail_seg.remove_from_grid()
        old_tail_seg.queue_free()

    # 8. 更新尾巴类型
    if segments.size() > 1:
        segments[-1].segment_type = TAIL
        _update_segment_visual(segments[-1])

    # 9. 更新所有段的 segment_index
    for i in range(segments.size()):
        segments[i].segment_index = i

    # 10. 发射移动事件
    EventBus.snake_moved.emit({
        "body": body.duplicate(),
        "direction": direction,
        "head_pos": body[0],
        "old_tail_pos": body[-1]
    })
```

#### 步骤 4：输入处理

```
func _unhandled_input(event):
    if not is_alive:
        return
    if event.is_action_pressed("move_up"):
        _buffer_direction(Constants.DIR_VECTORS[Constants.Direction.UP])
    elif event.is_action_pressed("move_down"):
        _buffer_direction(Constants.DIR_VECTORS[Constants.Direction.DOWN])
    elif event.is_action_pressed("move_left"):
        _buffer_direction(Constants.DIR_VECTORS[Constants.Direction.LEFT])
    elif event.is_action_pressed("move_right"):
        _buffer_direction(Constants.DIR_VECTORS[Constants.Direction.RIGHT])

func _buffer_direction(new_dir: Vector2i):
    # 禁止 180° 反向
    if new_dir + direction != Vector2i.ZERO:
        input_buffer = new_dir

func process_input():
    if input_buffer != Vector2i.ZERO:
        var old_dir = direction
        direction = input_buffer
        input_buffer = Vector2i.ZERO
        if old_dir != direction:
            EventBus.snake_turned.emit({"old_dir": old_dir, "new_dir": direction})
```

#### 步骤 5：连接 Tick 事件

```
func _ready():
    EventBus.tick_input_collected.connect(_on_tick)

func _on_tick(_data: Dictionary):
    if is_alive:
        move()
```

#### 步骤 6：配置 Input Map

在 `project.godot` 中添加输入动作映射：
- `move_up` → W 键 + 上方向键
- `move_down` → S 键 + 下方向键
- `move_left` → A 键 + 左方向键
- `move_right` → D 键 + 右方向键

**需要创建的文件：**
- `Project/entities/snake/snake.gd` — Snake 控制器
- `Project/entities/snake/snake_segment.gd` — SnakeSegment GridEntity
- `Project/entities/snake/snake.tscn` — Snake 场景（可选，也可在代码中动态创建 segment）

**需要修改的文件：**
- `Project/project.godot` — 添加 Input Map 配置

### 技术约束

- Snake 控制器继承 `Node2D`，SnakeSegment 继承 `GridEntity`
- 蛇身坐标用 `Array[Vector2i]`，SnakeSegment 实例用 `Array[SnakeSegment]`，两者保持同步
- 转向验证：`new_dir + current_dir != Vector2i.ZERO`（排除 180° 反向）
- 蛇移动到敌人格子时，应先发射事件再实际移入（让战斗系统有机会先处理敌人消灭）
- 蛇的视觉表现使用 `ColorRect`（MVP 阶段）：蛇头亮绿 `Color(0.2, 1.0, 0.2)`、蛇身绿色 `Color(0.1, 0.7, 0.1)`、蛇尾深绿 `Color(0.0, 0.5, 0.0)`

### 验收标准

- [ ] 蛇在 Grid 上按每 tick（0.25s）一步的节奏移动
- [ ] WASD 和方向键都能控制转向
- [ ] 不允许 180° 直接反向转弯
- [ ] 蛇头撞墙时发射 `snake_hit_boundary` 事件
- [ ] 蛇头撞自身时发射 `snake_hit_self` 事件
- [ ] 蛇头进入有敌人的格子时发射 `snake_hit_enemy` 事件
- [ ] 蛇头进入有食物的格子时发射 `snake_food_eaten` 事件
- [ ] `grow_pending > 0` 时蛇尾不缩进（长度增长）
- [ ] 所有 SnakeSegment 在 GridWorld 中正确注册，可通过 `get_entities_at()` 查到
- [ ] 蛇头视觉颜色区别于蛇身和蛇尾
- [ ] 移动后 `snake_moved` 事件包含正确的 body 数据

### 备注

- 上方移动流程中的步骤 5（碰撞检测），在 MVP 中蛇撞击敌人后**继续前进到该格子**（敌人由 EnemySystem 响应事件后移除）。这是最简化的处理方式。后续版本中蛇头撞击可能有不同行为（如反弹等）
- `grow_pending` 属性由 LengthSystem（T07）通过监听事件来设置。在 T06 单独测试时，可手动设置 `grow_pending = 1` 来验证增长逻辑
- 蛇身自碰撞检测时跳过最后一格（尾巴），因为如果不在增长，尾巴在同一 tick 会被移走。这是经典贪吃蛇的标准处理
