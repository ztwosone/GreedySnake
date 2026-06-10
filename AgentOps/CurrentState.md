# 当前状态

**更新时间**：2026-06-11（S2 T1 簇收口）
**当前分支**：`002-l4-growth-cycle`（spec 002 重验收进行中，每簇过严格门禁后合 main）
**当前 feature**：`.specify/specs/002-l4-growth-cycle/`（重验收）
**当前阶段**：S2 T1 簇完成（T001-T003 配置与契约基线）；下一簇 T2（鳞片奖励链 + 蜕皮经济，T004-T010）

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

- 普通测试：`3016/3016` 断言，套件 `68/68`（新增 `test_l4_config.gd`）。
- 严格测试：`STRICT PASSED`（2026-06-11，S2 T1 簇门禁）。

## S2 进度

- T1 簇 ✅（T001-T003）：`run.max_floors: 3` 取代并删除 `max_floors_v1`（旧键零调用方）、`floor.generator` 开关、
  节奏权重（首层 modifier/elite 全 0）、商店保底、`shop.price_multiplier_per_floor`、`room_types.shop|elite`、
  elite 敌人类型（is_elite + 1.25x + room_elite 描边 token）、difficulty 静态层表 + reactive 归一化、
  修饰符 v1 配置（shield_enemies/preset_status_tiles 逐项开关）；EventBus 补 `scale_option_discarded`/`floor_theme_set`、
  `scale_reward_chosen` 带 skipped 契约；QuickReference 含 L4 事件发射方→监听方表 + FR-018 注记。
  注意：`room_modifiers` 中 darkness/speed_strips/mine_tiles 为草稿残留（仍被草稿测试引用），
  随 T029/T031/T033 测试重写时删除。

## 下一张建议任务（S2 T2 簇开卡）

治理项（spec 002 修订）与 T1 簇均已完成。下一簇 T2（T004-T010）：
1. T004 Red：重写 `test_l4_scale_rewards.gd`——幻影二次 offer 回归、无合成 `room_completed`
   断言（FR-018）、满槽替换、按开放槽过滤、空池自动决议（FR-014）、放弃蜕皮收入。
2. T005 重写 `scale_reward_system.gd`（修 :85/:98 状态互踩软锁；拆合成 room_completed 仅限
   此系统；改发 `scale_reward_chosen`/`scale_option_discarded`；传承石偏置钩子）。
3. T006 修 `shedskin_system.gd`（节点判型 bug、跨层保留、discard 收入）；T007 模态门控
   （RunProgression pending-offer 登记，FR-015）；T008/T009 UI 卡基于 ui/kit；T010 集成。
4. 顺序：T2→T3 槽位+商店→【MDE tag T017】→T4 PCG→T5 多层+RoomDirector→T6 难度+修饰符→T7 验收。
   每簇合 main。13 文件判决表见 plan.md「重验收策略」。
