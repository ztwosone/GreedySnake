# GreedySnake Roguelite

基于 Godot 4.6 + GDScript 的**贪吃蛇 Roguelite**。Grid-based、Tick-driven、Event-driven、Data-driven 架构。

完整循环已闭环：局内战斗成长 → 死亡/胜利仪式 → 局后总结 → 解锁与传承石 → 石碑开局影响下一局。

## 游戏特色

- **Per-Segment Status** — 蛇身每一段独立携带状态（火/冰/毒），产生不同战场效果
- **状态反应系统** — 异类状态碰撞触发反应（蒸腾、毒爆、冻疫）
- **Effect Atom System** — 可组合的效果原子框架（68 原子，24 触发器）；蛇头/蛇尾/蛇鳞统一 Atom Chain，相邻鳞片 tag 共鸣
- **完整 Roguelite 循环** — 种子化 PCG 多层地图（商店保底/精英升格/房间修饰符）、鳞片三选一、蜕皮经济商店、Boss 两段结算、静态+反应式双层难度
- **元成长** — 条件解锁新蛇头/蛇尾、死亡铸传承石（下一局抽样偏置）、网格拾取物、`user://` 持久化存档
- **程序化美学「网格信号」** — 零外部美术：语义色板 + 角括号框 + 程序绘制 glyph 统一设计语言；死亡/胜利/选择仪式、楼层小地图、Build 状态条
- **程序化音频** — 全部音色由 JSON 参数运行时合成（SFXForge），Game-Feel 触发表「表即代码」（运行时绑定与验收断言共用同一份 JSON）
- **JSON 驱动配置** — 所有数值、效果、反应、表现参数均由 JSON 配置，零硬编码
- **三层体验验收** — Layer A 事件契约 + Layer B UI 几何探测随每次严格门禁运行；Layer C AI 截图评审在 Stage Gate 运行

## 开发进度

| 里程碑 | 内容 | 状态 |
|--------|------|------|
| L0 | 基础移动 + 长度 + 食物 | ✅ 完成 |
| L1 | 战斗循环 + 状态系统 + Atom System | ✅ 完成 |
| L2 | 蛇头/蛇尾/蛇鳞统一 Atom Chain | ✅ 完成 |
| L2.5 | Virtual Player 自动化测试基础设施 | ✅ 完成 |
| L3 | 完整一局：地图/房间/奖励/终局 | ✅ 完成（SpecKit 001） |
| L4 | 成长循环：蜕皮/鳞片/槽位/商店/PCG/难度 | ✅ 完成（SpecKit 002） |
| L5 | 元成长：解锁/传承石/拾取/存档 | ✅ 完成（SpecKit 003） |
| 体验层 | 程序化美学 + 游戏手感 + 程序化音频 | ✅ 机器层完成（SpecKit 004，人工终审 Gate-H 进行中） |

当前验证基线：**79 测试套件 / 4430 断言全绿 + 严格门禁通过**（严格门禁同时扫描引擎错误输出）。

## 项目结构

```
Project/          # Godot 工程目录
  autoloads/      #   全局单例（EventBus, ConfigManager, TickManager, VFXManager, SFXForge, AudioManager）
  entities/       #   实体（snake, enemies, food, status_tiles, pickups）
  systems/        #   系统（rooms, rewards, growth, difficulty, meta_growth, snake_parts, status, atoms, vfx）
  scenes/         #   场景（main, game_world, 验收场景）
  ui/             #   界面（ui/kit 设计语言内核 + 各面板/仪式编排层）
  data/json/      #   JSON 配置（game_config.json 单一事实源）
  Test/           #   测试框架 + 用例 + 体验验收基建（Test/experience）
  AcceptanceShots/#   Layer C 截图装置
Designs/          # 设计文档（source of truth）
TechDocs/         # 技术文档 + 速查手册（QuickReference）
DailyLogs/        # 每日开发日志
AgentOps/         # Agent 会话无关统筹控制面（当前状态/验证记录/截图证据）
.specify/specs/   # SpecKit 规格与任务（001-004）
```

## 如何运行

**环境要求：** [Godot 4.6+](https://godotengine.org/download)

```bash
# 直接游玩（窗口运行主场景）
godot --path Project

# 运行测试（headless）
godot --headless --path Project Test/test_runner.tscn

# 严格测试（同时扫描 Godot 错误输出）
$env:GODOT_DISABLE_CRASH_HANDLER="1"; powershell -ExecutionPolicy Bypass -File Tools/run_tests_strict.ps1

# Layer C 截图评审（带窗，输出到 AgentOps/acceptance_shots/<date>/）
powershell -ExecutionPolicy Bypass -File Tools/run_acceptance_shots.ps1
```

**操作**：WASD / 方向键移动，Esc 暂停，选择卡支持鼠标与 ←/→ + 数字键 + 回车。

## 一局流程

标题 →（有传承石则石碑选择）→ 逐房推进：战斗房清敌 → 鳞片三选一 → 奖励房 → 商店（蜕皮买鳞片/槽位/升级）→ Boss → 两段楼层结算 → 下一层（共 3 层）→ 胜利；任何时刻死亡进入死亡仪式与局后总结，解锁与铸石写入存档，影响下一局。

## 核心战斗（L1 起）

蛇头碰敌人直接吞噬，击杀掉落食物。蛇身每段可携带火/冰/毒状态：

| 状态 | 蛇段效果 | 状态格效果 |
|------|----------|-----------|
| 火 | 火光环：相邻格敌人受火属性伤害 | 踩入获火 |
| 毒 | 毒液蔓延：每 3 tick 向邻格扩散毒格 | 踩入获毒 |
| 冰 | 冰防御：被攻击时攻击者获冰 | 踩入获冰 |

异类状态碰撞触发反应：

| 反应 | 组合 | 效果 |
|------|------|------|
| 蒸腾 | 火+冰 | 范围伤害 2，蛇自伤 1 格 |
| 毒爆 | 火+毒 | 范围伤害 3，蛇自伤 2 格 |
| 冻疫 | 冰+毒 | 范围内敌人施加双状态 |

## 许可证

私有项目，保留所有权利。
