## [L0-T08] Food 食物系统

### 元信息

| 字段 | 值 |
|------|-----|
| **阶段** | L0-MVP |
| **优先级** | P1(核心) |
| **前置任务** | L0-T04, L0-T05 |
| **预估粒度** | M(1~3h) |
| **分配职能** | Gameplay 程序 |

### 概述

实现基础食物实体和食物生成管理器。食物是蛇增长的唯一来源（MVP 中），吃掉后自动在随机空格上生成新食物。

### 上下文

| 文档 | 章节/位置 |
|------|----------|
| `TechDocs/ScriptingLeading.md` | §3.2 长度系统（食物相关） |
| `TechDocs/ScriptingLeading.md` | §6.1 MVP 范围 — 食物 |
| `Designs/General/snake_roguelite_design.md` | §3 长度增加规则 |

### 任务详细

#### 步骤 1：创建 Food 实体

```
Food (extends GridEntity):
  entity_type = Constants.EntityType.FOOD
  blocks_movement = false    # 食物不阻挡移动
  is_solid = false
  cell_layer = 0             # 地面层

  visual: ColorRect           # 红色方块表示食物
```

视觉表现：`ColorRect`，大小比 `CELL_SIZE` 略小（如 48×48 居中于 64×64 格子），颜色红色 `Color(1.0, 0.2, 0.2)`。

Food 实体无需 override `_on_entity_enter` 等方法——食物的消耗由 Snake 的移动检测触发（`snake_food_eaten` 事件）。

#### 步骤 2：创建 FoodManager

`FoodManager` 管理食物的生成和消耗循环。

```
FoodManager (extends Node):
  max_food_count: int = 3          # 地图上同时存在的最大食物数量
  current_foods: Array[Food] = []  # 当前所有食物实例
  food_container: Node2D           # 食物实例的父节点
```

**核心方法：**

| 方法 | 说明 |
|------|------|
| `init_foods(count: int)` | 初始化时生成指定数量的食物 |
| `spawn_food()` | 在随机空格上生成一个食物 |
| `_on_food_eaten(data)` | 响应食物被吃事件，移除被吃的食物并生成新食物 |

**食物生成逻辑：**

```
func spawn_food():
    var empty_cells = GridWorld.get_empty_cells()
    if empty_cells.is_empty():
        return  # 无空位
    var pos = empty_cells[randi() % empty_cells.size()]
    var food = _create_food_instance()
    food.place_on_grid(pos)
    food_container.add_child(food)
    current_foods.append(food)

func _on_food_eaten(data: Dictionary):
    var food = data.get("food")
    if food and food in current_foods:
        current_foods.erase(food)
        food.remove_from_grid()
        food.queue_free()
    # 补充新食物
    spawn_food()
```

**事件连接：**

```
func _ready():
    EventBus.snake_food_eaten.connect(_on_food_eaten)
```

**需要创建的文件：**
- `Project/entities/foods/food.gd` — Food GridEntity
- `Project/entities/foods/food.tscn` — Food 场景（GridEntity + ColorRect）
- `Project/systems/food_manager.gd` — FoodManager

### 技术约束

- Food 继承 `GridEntity`，使用 `class_name Food`
- 食物生成时使用 `GridWorld.get_empty_cells()` 获取空格，避免生成在蛇身/敌人/其他食物上
- 食物被吃后立即 `remove_from_grid()` + `queue_free()`，然后生成新食物
- MVP 中食物数量固定为 3 个（`max_food_count = 3`）。后续版本由 `balance.json` 配置
- 食物的 `ColorRect` 应比格子稍小（留 8px 边距），以便视觉上区分格子边界

### 验收标准

- [ ] Food 继承 GridEntity，entity_type 为 FOOD
- [ ] FoodManager 初始化后地图上出现 3 个红色方块食物
- [ ] 食物不生成在已有实体的格子上
- [ ] 蛇头移动到食物格子时，`snake_food_eaten` 事件触发
- [ ] 食物被吃后从 GridWorld 和场景树中移除
- [ ] 食物被吃后立即在新的随机空格上生成一个新食物
- [ ] 如果地图已满（无空格），不生成新食物且不崩溃

### 备注

- 食物被吃的检测在 Snake 的 `move()` 方法中完成（T06 步骤 5），FoodManager 只负责响应事件后移除旧食物、生成新食物
- MVP 中只有一种食物（基础食物，+1 格）。后续版本会添加特殊食物（敌人掉落、附加效果等）
- 食物生成的随机性对 gameplay 影响很大——后续可能需要控制食物不生成在蛇头正前方过近的位置，但 MVP 中纯随机即可
