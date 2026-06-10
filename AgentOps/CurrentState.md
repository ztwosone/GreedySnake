# 当前状态

**更新时间**：2026-06-11
**当前分支**：`004-presentation-experience`（S1 完成已合 main；S2 将开 `002-l4-growth-cycle` 分支）
**当前 feature**：S2 起为 `.specify/specs/002-l4-growth-cycle/`（重验收）
**当前阶段**：S1 完成（SpecKit 004 Phase F 15/15 卡）；下一步 S2（L4 成长循环重验收）

## 阶段路线图

```
S0 稳定化 ✅ → S1 体验设计文档+表现内核 ✅ → S2 L4 重验收(spec 002) ← 当前
→ S3 L5 元成长(spec 003) → S4 体验完成层(004 Phase P) → S5 整段验收封板
```

## 实现事实（S1 后基线）

- 表现层 source of truth：`Designs/Interactive/presentation_design.md`（「网格信号」）。
- 表现内核与验收基建已落地（详见 QuickReference「表现内核事实」节）：
  `presentation` JSON 段、`ui/kit/` 六件、TickManager/VFXManager 仪表缝、
  `Test/experience/` 六件（recorder/driver/actor/settle/probe/stager）。
- L3 三面板 + title/game_over/hud 已迁移统一设计语言；debug UI 收进
  `presentation.debug_ui` 开关（默认关，含 T/Y 验收捷径与 B/V/C 热键）。
- 几何探测随严格门禁每次运行（4 个典型状态）；L3 首批体验契约入库
  （模态唯一/reward 流 ui 变化/time-to-first-choice）。
- 顺手修复：空身躯残留蛇 tick 越界（Snake.move 防御早退 + 回归测试，
  ScriptingLeading §3.1.3 步骤 0）。
- L4/L5 草稿仍为零集成状态，等待 S2/S3 逐卡重验收（缺陷清单见 02cdabf 提交信息）。

## 当前阻塞项

- 无阻塞。**Gate-H 欠账**：S1 的人工 5 分钟设计语言裁定未做（编辑器 F5 看一眼
  title→局内→game over 的观感），不阻塞 S2 开工，须在 S2 收口前补录于本文件。

## 最近验证基线

- 普通测试：`2897/2897` 断言，套件 `67/67`。
- 严格测试：`STRICT PASSED`（2026-06-11，Phase F 全六簇每簇过门禁）。

## 下一张建议任务（S2 开卡）

**治理先行（改 spec 再写码）**，对照阶段计划（会话计划文件 + QuickReference 路线）：
1. spec 002 修订：FR-003 蜕皮改跨层保留（依 Designs §10.2）；US3/US5 改 Boss 固定槽位
   解锁 + 三类楼层奖励（依 Designs §10.4/10.5）；tasks.md 重切（Create→验证/重写语义，
   加重集成卡，UI 卡基于 ui/kit）。
2. T1 配置卡：room_types.shop|elite、enemy_types.elite_*、run.max_floors（显式取代
   max_floors_v1）、floor.generator 开关、difficulty 归一化参数、概念节奏权重
   （首层 modifier/elite 权重 0，商店保底 ≥2 战斗房后）+ accessor + 配置测试。
3. T2 鳞片奖励链重写（拆合成 room_completed 仅限 ScaleRewardSystem、
   scale_option_discarded 新信号、模态门控、四 offer 系统空选项自动决议）。
4. 顺序：T1→T2→T3 槽位+商店→【MDE tag】→T4 PCG→T5 多层+RoomDirector→T6 难度+修饰符→T7 验收。
   每 US 合 main。13 文件判决表见阶段计划。
