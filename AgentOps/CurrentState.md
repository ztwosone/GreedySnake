# 当前状态

**更新时间**：2026-06-11（S2 T3 簇收口 + MDE 检查点）
**当前分支**：`002-l4-growth-cycle`（spec 002 重验收进行中，每簇过严格门禁后合 main）
**当前 feature**：`.specify/specs/002-l4-growth-cycle/`（重验收）
**当前阶段**：S2 T3 簇完成（T011-T017 槽位扩展 + 商店 + MDE 检查点 tag `mde-checkpoint`）；下一簇 T4（Seeded PCG，T018-T019）

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

- 无阻塞。**Gate-H 欠账**：① S1 的人工 5 分钟设计语言裁定未做（编辑器 F5 看一眼
  title→局内→game over 的观感）；② T017 MDE 的 10 分钟人工通跑未做（脚本见下节，
  全自动链路已由 e2e + 几何探测覆盖）。两项均不阻塞后续簇，须在 S2 收口前补录于本文件。

## MDE 存活检查点（T017，tag `mde-checkpoint`，2026-06-11）

**定义**：fixed_v1 单层闭环 = 战斗 → 鳞片三选一 → 蜕皮入账 → 商店买槽 → 终点/死亡结算，
S1 统一设计语言。此后任何中断，项目仍是「打开就能感受到设计意图」的最小可交付体验。
砍单阶梯（反应式 DDA → 主题敌池 → 修饰符扩展）绝不低于此线。

**10 分钟手动演示脚本**（人工通跑待补录，Gate-H 式欠账）：

1. 编辑器 F5 → 标题屏：确认 S1 设计语言（角括号框、palette、glyph、网格信号布局）→ 开始。
2. `combat_01`：清 3 敌（蛇头吞噬/状态反应），观察击杀掉食、HUD 长度、房间意图面板进度 0/3→3/3。
3. 房间完成 → 右上鳞片三选一模态：确认 Next 按钮禁用（FR-015 门控）；点「放弃全部 +6 蜕皮」→
   右上蜕皮 chip 首次入账出现（渐进披露）并弹跳。
4. Next → `reward_01`：L3 奖励三选一（头/尾/鳞 choice_card），选一张 → 「已选择」反馈。
5. Next → `combat_02`：再清 3 敌 → 第二次鳞片模态 → 再放弃（余额 12）。
6. Next → `shop_01`：商店面板开（货架 ≤5：鳞片 L1-L3×2 / 扩展槽位 / 蛇头升级 / 蛇尾升级；
   价格 chip 蜕皮图标；买不起的行灰显）。买「扩展槽位」（5 蜕皮）→ 余额扣减；
   （debug_ui 开启时按 B 看 Build 面板开槽数 +1）。确认不买也能直接走（无门控）。
7. Next → `rest_01`（自动完成）→ Next → `endpoint_01` → 胜利结算屏（cause=victory）。
8. 重开一局，故意撞墙/被敌人耗死 → 死亡结算屏 → 重开正常。
9. 全程检查：模态唯一（同屏最多一个选择面板）、离开奖励房后「已选择」面板收起、
   商店离店后面板收起、蜕皮 chip 跨房间存续。

## 最近验证基线

- 普通测试：`3207/3207` 断言，套件 `68/68`（T3 簇重写 `test_l4_slots`/`test_l4_shop` +
  L3 套件适配 6 房路径后的断言基数）。
- 严格测试：`STRICT PASSED`（2026-06-11，S2 T3 簇门禁）。

## S2 进度

- T1 簇 ✅（T001-T003）：`run.max_floors: 3` 取代并删除 `max_floors_v1`（旧键零调用方）、`floor.generator` 开关、
  节奏权重（首层 modifier/elite 全 0）、商店保底、`shop.price_multiplier_per_floor`、`room_types.shop|elite`、
  elite 敌人类型（is_elite + 1.25x + room_elite 描边 token）、difficulty 静态层表 + reactive 归一化、
  修饰符 v1 配置（shield_enemies/preset_status_tiles 逐项开关）；EventBus 补 `scale_option_discarded`/`floor_theme_set`、
  `scale_reward_chosen` 带 skipped 契约；QuickReference 含 L4 事件发射方→监听方表 + FR-018 注记。
  注意：`room_modifiers` 中 darkness/speed_strips/mine_tiles 为草稿残留（仍被草稿测试引用），
  随 T029/T031/T033 测试重写时删除。

- T3 簇 ✅（T011-T017）：`ScaleSlotManager` 上限 JSON 化（`growth.slot_expansion.max/initial` +
  `get_max_slots`/`get_open_slots` accessor，`build_test_panel` 直读迁移）；`slot_expansion_system`
  重写为薄适配器（unlock 真调 `open_slot`，草稿买槽零效果已修；`shop_purchase` 事件链开槽）；
  `shop_system` 修复（种子 RNG `hash(run_seed:room_id)`、容量按开放槽、`room_entered` 退店、
  物价乘数 `ceil(基准×mult^(层-1))`、空货架自动决议 FR-014、商店**不注册模态门控**）；
  `shop_panel` 基于 ui/kit 重建（货架行 + 价格 chip + 禁用去饱和，≤5 项）；
  `fixed_v1_path` 插入 `shop_01`（6 房，FR-017 商店保底 + MDE 买槽可达）；game_world 接线
  买槽端到端（买 → 开槽 → 装备 → 共鸣）；几何探针实证缺陷顺手修：`RewardChoicePanel`
  「已选择」反馈离开奖励房不收（双模态重叠），现随 `room_entered` 收起；
  几何探测新增 `l4_shop_open` 状态；JSON 增量 `shop.scale_pool`/`shop.shelf_plan`/
  tier `level`/slot `position`。MDE tag `mde-checkpoint` 已打（见上节）。

- T2 簇 ✅（T004-T010）：`scale_reward_system` 重写（无合成 `room_completed`/FR-018、满槽替换、
  按开放槽过滤、空池自动决议 FR-014、先清状态再发事件修软锁、`set_sampling_bias` L5 钩子）；
  `shedskin_system` 修复（Enemy 节点判型、跨层保留 FR-003、`run_started` 清零 FR-013、discard 收入）；
  模态门控 FR-015 双侧落地（RunProgression `has_pending_offer` + FloorProgressPanel Next 禁用/
  `is_advance_blocked`）；L3 `RewardFlowSystem` 空选项自动决议回补；`scale_choice_panel`（kit 模态，
  choice_card×3 + 放弃入口 +N 蜕皮）与 `shedskin_display`（kit chip，渐进披露）重建；game_world 接线 +
  cleanup 扩展；L3 回归套件（smoke/acceptance/xp_contracts/stager）适配鳞片模态；几何探测新增
  `l4_scale_pending` 状态；JSON 增量 `growth.scale_reward.default_pool`。
  测试事实：全局 `enemy_killed` 的 `enemy_def` 必须是 Node 派生或 null（EnemyManager 按 Node 收参）。

## 下一张建议任务（S2 T4 簇开卡）

T3 簇已收口合 main，MDE 存活线已立（tag `mde-checkpoint`）。下一簇 T4（T018-T019 Seeded PCG）：
1. T018 Red：重写 `test_l4_pcg_rooms.gd` 为**性质测试**——连通性、全房可达、房数边界、
   定种子确定性（SC-011）、商店保底排 ≥2 战斗房后（SC-010）、endpoint=boss、
   首层 modifier/elite 权重为 0 从数据生效。
2. T019 重写 `floor_map_generator.gd` PCG 路径：seeded RNG + config 权重/分支 + 每层保底 shop +
   endpoint=boss；魔数（:54-84）全部入 JSON；fixed_v1 留作 `floor.generator` 开关回退
   （注意 fixed_v1 路径现为 6 房含 shop_01）。
3. 回归重点：`test_l3_floor_progression.gd`（fixed_v1 档）+ 楼层键表查询走
   `ConfigManager._get_floor_keyed_value` 系 accessor，不读裸 dict。
4. 后续：T5 多层+RoomDirector（T020 EnemyManager respawn_policy 前置）→T6 难度+修饰符→T7 验收。
   每簇合 main。13 文件判决表见 plan.md「重验收策略」。
   T016 后注意：任何走完整 fixed 路径的新测试要途经 shop_01（房间自动完成、无门控、
   `room_entered` 退店收面板）。
