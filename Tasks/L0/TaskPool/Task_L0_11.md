## [L0-T11] GameManager 与游戏循环

### 元信息

| 字段 | 值 |
|------|-----|
| **阶段** | L0-MVP |
| **优先级** | P1(核心) |
| **前置任务** | L0-T02, L0-T10 |
| **预估粒度** | L(3~6h) |
| **分配职能** | Gameplay 程序 |

### 概述

实现 GameManager 单例和完整的游戏状态循环（标题 → 游玩 → 死亡 → 重开），加上简单的标题画面和 Game Over 画面，使 MVP 成为一个可以反复游玩的完整游戏循环。

### 上下文

| 文档 | 章节/位置 |
|------|----------|
| `TechDocs/ScriptingLeading.md` | §1.4 Autoload — GameManager |
| `TechDocs/ScriptingLeading.md` | §6.1 MVP 范围 |

### 任务详细

#### 步骤 1：创建 GameManager

`Project/autoloads/game_manager.gd`，注册为 Autoload。

**游戏状态枚举：**

```
enum GameState { TITLE, PLAYING, GAME_OVER }
var current_state: GameState = GameState.TITLE
```

**核心属性：**

| 属性 | 类型 | 说明 |
|------|------|------|
| `current_state` | `GameState` | 当前游戏状态 |
| `current_score` | `int` | 当前分数（= 击杀敌人数，MVP 简单计分） |
| `best_score` | `int` | 历史最高分 |

**核心方法：**

| 方法 | 说明 |
|------|------|
| `start_game()` | 切换到 PLAYING 状态，加载 GameWorld 场景 |
| `end_game(cause: String)` | 切换到 GAME_OVER 状态，停止 Tick |
| `restart_game()` | 清理当前游戏，重新开始 |
| `go_to_title()` | 回到标题画面 |

**事件监听：**

```
func _ready():
    EventBus.snake_died.connect(_on_snake_died)
    EventBus.enemy_killed.connect(_on_enemy_killed)
    EventBus.game_restart_requested.connect(restart_game)

func _on_snake_died(data: Dictionary):
    end_game(data.get("cause", "unknown"))

func _on_enemy_killed(_data: Dictionary):
    if current_state == GameState.PLAYING:
        current_score += 1
```

**`start_game()` 流程：**

```
func start_game():
    current_state = GameState.PLAYING
    current_score = 0
    # 切换到 GameWorld 场景（或通知 Main 场景切换显示）
    EventBus.game_started.emit()
```

**`end_game()` 流程：**

```
func end_game(cause: String):
    current_state = GameState.GAME_OVER
    TickManager.stop_ticking()
    if current_score > best_score:
        best_score = current_score
    EventBus.game_over.emit({
        "cause": cause,
        "final_length": _get_final_length(),
        "score": current_score,
        "best_score": best_score
    })
```

**`restart_game()` 流程：**

```
func restart_game():
    GridWorld.clear_all()
    # 重新加载 GameWorld 场景或调用 GameWorld.start_game()
    start_game()
```

#### 步骤 2：创建 Main 场景

`Project/scenes/main.tscn` — 作为项目入口场景（设为 `project.godot` 的 `run/main_scene`）。

```
Main (Node)
├── TitleScreen (Control)       # 标题画面
│   ├── TitleLabel (Label)      # "GreedySnake Roguelite"
│   └── StartButton (Button)    # "Start Game"
├── GameWorldContainer (Node)   # GameWorld 的挂载点
└── GameOverScreen (Control)    # 死亡画面
    ├── GameOverLabel (Label)   # "Game Over"
    ├── ScoreLabel (Label)      # "Score: X | Best: Y"
    ├── CauseLabel (Label)      # "Cause: hit_boundary"
    └── RestartButton (Button)  # "Restart"
```

**Main 场景脚本逻辑：**

```
初始状态：显示 TitleScreen，隐藏 GameWorld 和 GameOverScreen

StartButton 点击：
  隐藏 TitleScreen
  实例化 GameWorld 场景到 GameWorldContainer
  调用 GameWorld.start_game()

EventBus.game_over：
  显示 GameOverScreen
  更新分数和死因文字

RestartButton 点击：
  隐藏 GameOverScreen
  清理旧 GameWorld
  实例化新 GameWorld
  调用 GameWorld.start_game()
```

#### 步骤 3：更新 project.godot

- 将 `run/main_scene` 设置为 `"res://scenes/main.tscn"`
- 确保所有 Autoload 注册顺序正确：Constants → EventBus → TickManager → GridWorld → GameManager

**需要创建的文件：**
- `Project/autoloads/game_manager.gd`
- `Project/scenes/main.tscn` — 入口场景
- `Project/scenes/main.gd` — 入口场景脚本
- `Project/ui/title_screen.tscn` — 标题画面
- `Project/ui/title_screen.gd`
- `Project/ui/game_over_screen.tscn` — Game Over 画面
- `Project/ui/game_over_screen.gd`

**需要修改的文件：**
- `Project/project.godot` — 注册 GameManager Autoload，更新 main_scene

### 技术约束

- GameManager 继承 `Node`，注册为 Autoload
- GameManager **不持有对具体实体的引用**，全部通过 EventBus 通信
- 场景切换使用实例化/释放模式（`instantiate()` + `queue_free()`），不使用 `change_scene()`（因为 Autoload 需要保持）
- 标题画面和 Game Over 画面使用简单的 Label + Button，不需要复杂 UI 设计
- Autoload 注册顺序必须是：Constants → EventBus → TickManager → GridWorld → GameManager（后者可能依赖前者）
- `restart_game()` 必须完全清理旧状态（GridWorld.clear_all()、释放旧场景），避免残留数据

### 验收标准

- [ ] 启动游戏显示标题画面，有 "GreedySnake Roguelite" 标题和 "Start Game" 按钮
- [ ] 点击 Start 按钮进入游戏，蛇开始移动
- [ ] 蛇死亡后显示 Game Over 画面，显示死因和分数
- [ ] Game Over 画面显示击杀敌人数作为分数
- [ ] 点击 Restart 按钮重新开始新一局
- [ ] 重新开始后地图、蛇、食物、敌人全部重置为初始状态
- [ ] 反复重启不会导致内存泄漏或实体残留（可通过 Godot 监视器检查节点数）
- [ ] 最高分（best_score）在同一次运行的多局之间保持
- [ ] Autoload 在场景切换间保持存在
- [ ] `project.godot` 的 `run/main_scene` 指向 `res://scenes/main.tscn`

### 备注

- MVP 阶段的 UI 极简即可：白色文字 + 深色背景 + 按钮。不需要任何美化
- `current_score` 以击杀敌人数计分是 MVP 简化方案。后续版本分数计算会更复杂（层数、Build 评分等）
- `best_score` 在 MVP 中只存在于内存中（关闭游戏即丢失）。后续由 MetaGrowthSystem 持久化
- 这是 L0-MVP 的**最终集成任务**，完成后整个 MVP 应可作为一个完整的游戏循环运行
