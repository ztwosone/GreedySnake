# GreedySnake Roguelite

基于 Godot 4.6 + GDScript 的**贪吃蛇 Roguelite**。Grid-based、Tick-driven、Event-driven、Data-driven 架构。

## 游戏特色

- **Per-Segment Status** — 蛇身每一段独立携带状态（火/冰/毒），产生不同战场效果
- **状态反应系统** — 异类状态碰撞触发反应（蒸腾、毒爆、冻疫）
- **多种敌人 AI** — 游荡者、追踪者、毒沼匍匐者，各有独特行为模式
- **JSON 驱动配置** — 所有数值、效果、反应均由 JSON 配置，零硬编码
- **Effect Atom System** — 可组合的效果原子框架（68 原子，24 触发器）

## 开发进度

| 里程碑 | 内容 | 状态 |
|--------|------|------|
| L0 | 基础移动 + 长度 + 食物 | ✅ 完成 |
| L1 | 战斗循环 + 状态系统 + Atom System | ✅ 完成 |
| L2 | 蛇头/蛇尾/蛇鳞统一 Atom Chain | ✅ 完成（T27A~T33） |
| L2.5 | Virtual Player 自动化测试基础设施 | ✅ 完成 |
| L3 | 完整一局：地图/房间/奖励/终局 | ✅ v1 完成（SpecKit 001，26/26 任务） |
| L4 | 成长循环：蜕皮/鳞片奖励/槽位/商店/多层 | 🟡 草稿在库，待按 SpecKit 002 重验收 |
| L5 | 元成长：解锁/传承石/拾取/存档 | 🟡 草稿在库，待按 SpecKit 003 重验收 |
| L6 | 体验完成层：程序化美学 + 游戏手感 | 📋 已规划（SpecKit 004，设计文档先行） |

## 项目结构

```
Project/          # Godot 工程目录
  autoloads/      #   全局单例（EventBus, ConfigManager, GridWorld）
  entities/       #   实体（snake, enemies, food, status_tiles）
  systems/        #   系统（combat, enemy, status, atoms, vfx）
  scenes/         #   场景（game_world, l1_acceptance）
  data/json/      #   JSON 配置文件
  Test/           #   测试框架 + 用例
Designs/          # 设计文档（source of truth）
TechDocs/         # 技术文档 + 速查手册
Tasks/            # 里程碑任务分解
DailyLogs/        # 每日开发日志
AgentOps/         # Agent 会话无关统筹控制面
.specify/specs/   # L3+ SpecKit 规格与任务
```

## 如何运行

**环境要求：** [Godot 4.6+](https://godotengine.org/download)

```bash
# 打开项目
godot --path Project

# 运行测试（headless）
godot --headless --path Project Test/test_runner.tscn

# 严格测试（同时扫描 Godot 错误输出）
$env:GODOT_DISABLE_CRASH_HANDLER="1"; powershell -ExecutionPolicy Bypass -File Tools/run_tests_strict.ps1
```

## 核心玩法（L1）

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
