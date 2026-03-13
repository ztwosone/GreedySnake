## [L0-T10] 游戏场景组装与视觉层

### 元信息

| 字段 | 值 |
|------|-----|
| **阶段** | L0-MVP |
| **优先级** | P1(核心) |
| **前置任务** | L0-T01 ~ L0-T09（所有前置任务） |
| **预估粒度** | L(3~6h) |
| **分配职能** | Gameplay 程序 |

### 概述

将所有已实现的系统和实体组装到一个可运行的游戏场景中，添加 Grid 背景可视化、Camera 配置和基础 HUD（显示当前长度），使 MVP 成为一个有完整视觉反馈的可玩版本。

### 上下文

| 文档 | 章节/位置 |
|------|----------|
| `TechDocs/ScriptingLeading.md` | §1.3 场景树结构 |
| `TechDocs/ScriptingLeading.md` | §6.1 MVP 范围 — 渲染 |

### 任务详细

#### 步骤 1：创建 GameWorld 场景

创建 `Project/scenes/game_world.tscn`，场景树结构：

```
GameWorld (Node2D)                        # game_world.gd
├── Camera2D                              # 固定摄像头，居中于 Grid
├── GridBackground (Node2D)               # grid_background.gd — 绘制格子线
├── EntityContainer (Node2D)              # 所有 GridEntity 的父节点
│   ├── Snake (Node2D)                    # Snake 控制器（来自 T06）
│   ├── EnemyContainer (Node2D)           # 敌人父节点
│   └── FoodContainer (Node2D)            # 食物父节点
├── WallVisual (Node2D)                   # 边界墙视觉
└── UI (CanvasLayer)
    └── HUD (Control)
        └── LengthLabel (Label)           # 显示 "Length: X"
```

#### 步骤 2：Grid 背景可视化

`GridBackground` 使用 `_draw()` 方法绘制：
- 整个 Grid 区域填充深色背景（如 `Color(0.1, 0.1, 0.12)`）
- 格子线用更浅的颜色（如 `Color(0.15, 0.15, 0.18)`）
- 网格大小：`GRID_WIDTH × GRID_HEIGHT` 格，每格 `CELL_SIZE` 像素

#### 步骤 3：边界墙视觉

在 Grid 四周绘制墙壁视觉（灰色方块或线条），让玩家清楚看到边界。

#### 步骤 4：Camera2D 配置

- 位置：Grid 区域中心
- 缩放：确保整个 Grid 区域在 1280×720 视窗中完整可见
- 固定不动（MVP 中无滚动需求）

#### 步骤 5：HUD — 长度显示

```
HUD (extends Control):
  @onready var length_label: Label

  func _ready():
      EventBus.snake_length_increased.connect(_update_length)
      EventBus.snake_length_decreased.connect(_update_length)
      EventBus.game_started.connect(_on_game_started)

  func _update_length(data: Dictionary):
      length_label.text = "Length: %d" % data.get("new_length", 0)

  func _on_game_started():
      length_label.text = "Length: %d" % Constants.INITIAL_SNAKE_LENGTH
```

Label 配置：
- 位置：屏幕左上角，留 16px 边距
- 字体大小：24px
- 颜色：白色

#### 步骤 6：GameWorld 初始化脚本

`game_world.gd` 负责协调所有组件的初始化：

```
func start_game():
    # 1. 初始化 Grid
    GridWorld.init_grid(Constants.GRID_WIDTH, Constants.GRID_HEIGHT)

    # 2. 初始化蛇
    var start_pos = Vector2i(Constants.GRID_WIDTH / 2, Constants.GRID_HEIGHT / 2)
    snake.init_snake(start_pos, Constants.INITIAL_SNAKE_LENGTH, Constants.DIR_VECTORS[Constants.Direction.RIGHT])

    # 3. 初始化食物
    food_manager.init_foods(3)

    # 4. 初始化敌人
    enemy_manager.init_enemies(3)

    # 5. 启动 Tick
    TickManager.start_ticking()

    # 6. 通知游戏开始
    EventBus.game_started.emit()
```

**需要创建的文件：**
- `Project/scenes/game_world.tscn` — 游戏世界场景
- `Project/scenes/game_world.gd` — 场景初始化脚本
- `Project/scenes/grid_background.gd` — Grid 背景绘制
- `Project/ui/hud.gd` — HUD 脚本
- `Project/ui/hud.tscn` — HUD 场景

### 技术约束

- GameWorld 是**场景级别的组装**，不是 Autoload
- 各子系统（LengthSystem、FoodManager、EnemyManager）应作为 GameWorld 的子节点或通过 `@export` 注入引用
- Camera2D 的 `position` 应计算为 Grid 区域的中心点：`Vector2(GRID_WIDTH * CELL_SIZE / 2, GRID_HEIGHT * CELL_SIZE / 2)`
- GridBackground 的 `_draw()` 方法需要在 Grid 尺寸变化时调用 `queue_redraw()`
- HUD 使用 `CanvasLayer` 确保 UI 不受 Camera 变换影响
- 所有实体（Snake segments、Food、Enemy）必须作为 `EntityContainer` 的子节点添加到场景树中

### 验收标准

- [ ] 打开 `game_world.tscn` 场景，Godot 编辑器不报错
- [ ] 运行后可以看到深色背景上的 Grid 线
- [ ] Grid 四周有可见的边界墙
- [ ] 蛇出现在 Grid 中央偏左，初始长度 6 格，向右移动
- [ ] 地图上有 3 个红色食物和 3 个紫红色敌人
- [ ] 屏幕左上角显示 "Length: 6"
- [ ] 吃到食物后长度数字增加
- [ ] 撞击敌人后长度数字减少
- [ ] 整个 Grid 区域在屏幕中完整可见，不被裁切
- [ ] WASD / 方向键控制蛇移动正常

### 备注

- 本任务是**集成任务**，依赖 T01~T09 所有前置任务的完成。如果某些前置任务尚未完成，可以先用硬编码 placeholder 替代
- GridBackground 的格子线绘制是纯视觉的，不影响游戏逻辑
- MVP 阶段不需要平滑移动动画（蛇是逐格跳跃的）。如果视觉上不舒服，可以加一个简单的 tween 插值（可选优化，不是验收要求）
- 将来 L1 阶段会把 GameWorld 拆分为多个房间，但 MVP 中只有一个固定大小的矩形区域
