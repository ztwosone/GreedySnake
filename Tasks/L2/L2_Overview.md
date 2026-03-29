# L2 里程碑总览：蛇头/蛇尾/蛇鳞统一 Atom Chain

> **核心目标：** 在 T25 Atom System 基础上实现 Build 系统——蛇头（攻击风格）、蛇尾（防御风格）、蛇鳞（规则修改器），全部通过 JSON + Atom Chain 配置驱动。

## 架构决策

- 三套系统统一使用 T25 EffectChainResolver → TriggerManager → AtomExecutor 管线
- 新增 EffectWindow 时间窗口框架（T27）支撑持续型效果
- 新增 4 个即时原子 + 2 个窗口原子
- 蛇鳞效果走 Atom Chain，不再有独立的 Condition/Action 系统

## 任务总览

| 任务 | 名称 | 优先级 | 粒度 | 前置 | 状态 |
|------|------|--------|------|------|------|
| T27 | EffectWindow 时间窗口框架 | P0 前置 | M | T25 | 🟡 设计完成 |
| T28 | L2 新原子实现（4 即时型） | P1 核心 | M | T27 | 🔮 待设计 |
| T29 | SnakePartsManager + 蛇头链 | P1 核心 | L | T27, T28 | 🔮 待设计 |
| T30 | 蛇尾链 | P1 核心 | M | T27, T28 | 🔮 待设计 |
| T31 | ScaleSystem 槽位管理 + 9 鳞片 | P1 核心 | L | T28 | 🔮 待设计 |
| T32 | 邻接共鸣系统 | P2 增强 | M | T31 | 🔮 待设计 |
| T33 | 全系统联调 + 数值平衡 | P2 增强 | L | T29-T32 | 🔮 待设计 |

## 阶段划分

| 阶段 | 任务 | 说明 |
|------|------|------|
| Phase 0 | T27 | 基础设施：时间窗口框架 |
| Phase 1 | T28 | 新原子：modify_food_drop, direct_grow, steal_status, modify_hit_threshold |
| Phase 2 | T29, T30 | 蛇头/蛇尾系统（Hydra, 白蛇, 再生尾, 时滞尾） |
| Phase 3 | T31, T32 | 蛇鳞系统 + 共鸣 |
| Phase 4 | T33 | 联调与平衡 |

## 依赖关系

```
T25 (Atom System, L1 已完成)
  └── T27 (EffectWindow 框架)
       ├── T28 (4 个即时原子)
       │    ├── T29 (蛇头: Hydra, 白蛇)
       │    ├── T30 (蛇尾: 再生尾, 时滞尾)
       │    └── T31 (蛇鳞: 9 基础鳞片)
       │         └── T32 (邻接共鸣)
       └── T29, T30 (窗口型效果依赖 T27)
            └── T33 (全系统联调)
```
