## [L0-T01] 项目脚手架与核心常量

### 元信息

| 字段 | 值 |
|------|-----|
| **阶段** | L0-MVP |
| **优先级** | P0(阻塞) |
| **前置任务** | 无 |
| **预估粒度** | S(< 1h) |
| **分配职能** | 引擎程序 |

### 概述

创建项目的目录骨架和全局常量定义，为后续所有任务提供统一的基础结构。这是所有任务的前置条件。

### 上下文

| 文档 | 章节/位置 |
|------|----------|
| `TechDocs/ScriptingLeading.md` | §1.2 项目目录结构 |
| `TechDocs/ScriptingLeading.md` | §1.4 Autoload 单例清单 |
| `TechDocs/ScriptingLeading.md` | §2.6 全局常量 |
| `TechDocs/ScriptingLeading.md` | §2.7 坐标系统约定 |
| `TechDocs/ScriptingLeading.md` | 附录 A：命名约定 |

### 任务详细

1. 按照 `ScriptingLeading.md §1.2` 在 `Project/` 下创建完整的目录结构（只创建 L0-MVP 涉及的目录即可，不含 `status_effect/`、`scales/` 等后续系统目录）
2. 创建 `core/constants.gd`，定义全局常量
3. 在 `project.godot` 中将 `constants.gd` 注册为 Autoload（名称 `Constants`）
4. 确保 `project.godot` 中显示配置正确（1280×720，canvas_items 拉伸）

**需要创建的目录（MVP 范围）：**
```
Project/
├── autoloads/
├── core/
│   └── helpers/
├── systems/
│   ├── movement/
│   └── length/
├── entities/
│   ├── snake/
│   ├── enemies/
│   └── foods/
├── ui/
├── data/
│   └── json/
└── scenes/
```

**需要创建的文件：**
- `Project/core/constants.gd`

**需要修改的文件：**
- `Project/project.godot` — 注册 Autoload、确认 main_scene 清空（后续任务会设置）

### `constants.gd` 应包含的常量

| 常量名 | 类型 | 值 | 说明 |
|--------|------|-----|------|
| `CELL_SIZE` | `int` | `64` | 格子像素大小 |
| `BASE_TICK_INTERVAL` | `float` | `0.25` | 基础 tick 间隔（秒） |
| `GRID_WIDTH` | `int` | `20` | 默认地图宽度（格数），20×64=1280 |
| `GRID_HEIGHT` | `int` | `11` | 默认地图高度（格数），11×64=704 ≈ 720 |
| `INITIAL_SNAKE_LENGTH` | `int` | `6` | 蛇初始长度 |

同时定义以下枚举：

```
enum EntityType { SNAKE_SEGMENT, ENEMY, FOOD, TERRAIN, STATUS_TILE, PICKUP, BUILDING }
enum Direction { UP, DOWN, LEFT, RIGHT }
```

以及 Direction 到 `Vector2i` 的映射字典 `DIR_VECTORS`：
```
const DIR_VECTORS = {
    Direction.UP: Vector2i(0, -1),
    Direction.DOWN: Vector2i(0, 1),
    Direction.LEFT: Vector2i(-1, 0),
    Direction.RIGHT: Vector2i(1, 0),
}
```

### 技术约束

- 所有命名使用 `snake_case`（文件名）和 `UPPER_SNAKE_CASE`（常量），参考附录 A
- 不要创建任何空的 `.gd` 占位文件，只创建目录
- `constants.gd` 使用 `extends Node` 以支持 Autoload
- 目录需要包含 `.gdignore` 或至少一个文件才会被 Godot 识别。对于空目录可暂时忽略（Godot 会在首次保存场景/脚本时自动创建）

### 验收标准

- [ ] 目录结构与上述清单一致
- [ ] `constants.gd` 存在且包含所有列出的常量和枚举
- [ ] `DIR_VECTORS` 字典能正确映射四个方向到 `Vector2i`
- [ ] `project.godot` 中 `Constants` 已注册为 Autoload
- [ ] Godot 编辑器可正常打开项目，无报错

### 备注

- `GRID_WIDTH=20` 和 `GRID_HEIGHT=11` 是根据 1280×720 分辨率计算得出的默认值。20×64=1280 正好填满宽度，11×64=704 接近 720（底部 16px 留给可能的 HUD）
- 后续任务中 `run/main_scene` 会被覆盖设置，本任务可将其设为空字符串 `""`
