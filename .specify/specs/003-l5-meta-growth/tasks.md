# Tasks: L5 Meta Growth & Events（重验收 Re-cut，2026-06-11）

**Input**: `.specify/specs/003-l5-meta-growth/`（spec.md 2026-06-11 修订版 + plan.md「重验收策略」+ backlog.md + Designs §12.3 附录「v1 内容映射」）
**Context**: 非绿地开发。6-5 草稿五系统（meta_save / run_stats / unlock / legacy_stone / pickup）+ 四套件已入库、零场景集成；判决见 plan.md「重验收策略」表。任务语义统一为**「对照修订后 spec 验证/修复/重写 X」**，而非「Create X」。
**Tests**: TDD 强制——每卡先写/改失败测试（Red）→ 最小实现（Green）→ 重构 → 全量回归；每卡列明归属套件（套件在 `Project/Test/cases/`，harness 在外）。
**存档卫生（不可妥协）**: 生产存档路径 `user://meta_save.json`。一切测试必须注入临时 save_path（M1 落地注入缝）并测后清理——绝不污染真实 user:// 存档、绝不依赖其先验状态。
**UI**: 全部 UI 卡**基于 `Project/ui/kit/` 构建**（出生即带分组 / `ui_layer` 元数据 / `settle()`）；数据通路 only，零编排——屏幕流（GameState 枚举扩展）与仪式编排归 S4（004 Phase P）。
**纪律**: preload / duck-typing（去 class_name，ScriptingLeading C.8）；新 .gd 配 .uid 同卡入库；EventBus / JSON schema 变更同提交落 QuickReference；全数值走 JSON（ConfigManager accessor）。
**合入节奏**: 每簇（M1–M4）严格门禁绿（`STRICT PASSED` + suites N/N + ALL PASSED）→ 勾卡 → 提交 → 合 main——防长分支搁浅。

---

## M1 簇 — run_ended 链路（地基，阻塞全部后续）

**Goal**: 生产代码恰一次发射 `run_ended`（RunProgressionSystem victory/death 双出口调用 `RunStatsTracker.finalize_run`，once-guard），payload = spec FR-016 冻结契约；meta 存档可注入路径 + `schema_version` + 容错重置（FR-009/013/014/016）。

**Independent Test**: 临时 save_path 下：胜利与死亡各恰一次 `run_ended` 且字段集 = 冻结契约十字段 + outcome/run_id/floor_index；坏档/缺档/未知版本 → 容错重置不崩溃；双 finalize 第二次被 once-guard 拒绝。

- [x] T001 [M1] Red 卡：重写 `Project/Test/cases/test_l5_meta_save.gd`——注入临时 save_path（user:// 临时文件，测后删除）；`schema_version` 写入/读回；坏 JSON / 非 Dictionary 形状 / 缺文件 / 未知版本 → 容错重置 + 默认值（含默认解锁集 hydra/salamander）；`run_ended` once-guard（双 finalize 第二次零发射）；payload 冻结字段集逐一断言（FR-016）；near_death / low_length / damage（snake_body_attacked 补源）/ max_length / duration_ticks 度量源用例。测试套件：`test_l5_meta_save.gd`
- [x] T002 [M1] 验证修复 `Project/systems/meta_growth/meta_save_system.gd`（判决：保留+微修）：save_path 注入缝（构造/初始化参数，缺省读 `meta_growth.save_path`——草稿 _init 即读盘的隐式 IO 改为显式可控）；`schema_version` 字段（写入恒带；读档校验，parse 失败/形状不符/版本未知 → 重置默认 + `push_warning`，绝不带病加载）；reset 默认值含默认解锁集；去 class_name。测试套件：`test_l5_meta_save.gd`
- [x] T003 [M1] 验证补全 `Project/systems/meta_growth/run_stats_tracker.gd`（判决：保留+补）：补度量源——`damage_taken` 增 `snake_body_attacked`（草稿仅 hit_boundary）、`near_death_count`（濒死事件源：无身体倒计时进入/长度跌至 JSON 阈值）、`survival_low_length_ticks`（tick 监听 + `meta_growth.stats.low_length_threshold`）、`max_length`（长度峰值）、`duration_ticks`（run 起算 tick 计数）；`finalize_run` once-guard + payload 增 run_id/floor_index（自 `run_started`/`floor_generated` 缓存或调用方传入，契约 FR-016 为准）+ 删 `stats.run_outcome` 冗余（顶层 outcome 为准）；`run_started` 重置（FR-013 风格）；阈值全 JSON。去 class_name。测试套件：`test_l5_meta_save.gd`
- [x] T004 [M1] 接线卡：`Project/systems/run/run_progression_system.gd` 注入 tracker（duck-typed `set_stats_tracker(obj)`，未注入零行为——L3 既有测试零破坏），victory 路径与 death 路径（`_on_snake_died` outcome 同步处）各调一次 `finalize_run`，once-guard 双保险（RunProgression 侧 + tracker 侧）。**EventBus 契约变更（run_ended 冻结 payload + 发射方落定）同提交落 `TechDocs/QuickReference.md` 事件对照表。**测试套件：`test_l5_meta_save.gd`（接线用例：victory/death 双出口恰一次）+ `test_l3_run_end.gd` 回归
- [x] T005 [M1] [P] JSON + accessor 卡：`Project/data/json/game_config.json` `meta_growth` 段增 `schema_version`、`stats`（low_length_threshold 等度量参数）；`Project/autoloads/config_manager.gd` 对应 accessor。**JSON schema 变更同提交落 QuickReference。**测试套件：`test_l5_meta_save.gd`（数据断言）

**M1 收口**: 严格门禁绿 → 勾卡 → 提交 → 合 main。

---

## M2 簇 — Meta 根节点 + 解锁门控（US1，P1）

**Goal**: MetaGrowthRoot 常驻 main.tscn（GameWorldContainer 外，跨 run 存续、世界重建不清）；解锁条件 = Designs §12.3 附录 v1 映射（目标全部存在于内容池——设计先行红线）；奖励/Build 池按解锁集过滤；解锁 toast 数据通路。

**Independent Test**: 新档默认池恰 = hydra + salamander（bai_she / lag_tail 不出现在 offer）；一局 reaction_kills ≥ 10 → run_ended → bai_she 入解锁集 + `content_unlocked` + 落盘；重复达成零二次解锁；解锁后下局奖励池含 bai_she。

- [ ] T006 [M2] Red 卡：重写 `Project/Test/cases/test_l5_unlocks.gd` 对照 v1 映射——默认解锁集（hydra/salamander）；reaction_kills ≥ 10 → bai_she、floors_completed ≥ 2 → lag_tail；幂等（无重复解锁/事件）；临时 save_path 持久化；池过滤断言（锁定内容不进 offer、解锁后进入）；unlock_conditions 的 target_id 必须存在于 snake_heads/snake_tails（数据互证断言）。测试套件：`test_l5_unlocks.gd`
- [ ] T007 [M2] JSON 卡：`game_config.json` `meta_growth.unlock_conditions` 重写为 v1 双条件（`reaction_kills_10` → bai_she / `floors_2` → lag_tail，display_name 对齐内容池 白蛇/时滞尾）+ `default_unlocked_heads: ["hydra"]` / `default_unlocked_tails: ["salamander"]`；草稿五条件中指向 ungud/medusa/taotie/styx_tail 的目标移除（backlog.md 收容，含 salamander 旧条件——已改默认解锁）。**JSON schema 变更同提交落 QuickReference。**测试套件：`test_l5_unlocks.gd`（数据断言）
- [ ] T008 [M2] 验证修复 `Project/systems/meta_growth/unlock_system.gd`（判决：保留+修）：条件评估对照 v1 schema（condition_type 枚举与 FR-016 stats 字段对齐）；幂等保持；`content_unlocked` 发射 + 解锁即落盘保持；去 class_name。测试套件：`test_l5_unlocks.gd`
- [ ] T009 [M2] MetaGrowthRoot 卡：新建 `Project/systems/meta_growth/meta_growth_root.gd`（+.uid）挂 `Project/scenes/main.tscn` 常驻节点（GameWorldContainer 外）：boot 加载 MetaSaveSystem（生产路径，测试可注入）；子节点 UnlockSystem / LegacyStoneSystem / RunStatsTracker `setup(meta_save)`；`run_started` 重置 tracker；跨 run 存续断言（世界重建后解锁集/石碑仍在）。测试套件：`test_l5_unlocks.gd`（root 装配/存续用例）
- [ ] T010 [M2] 池过滤卡：`Project/systems/rewards/reward_flow_system.gd`（L3 头/尾奖励 offer）及头尾池消费方按解锁集过滤（duck-typed 解锁查询注入，未注入全量回退——L3 既有测试零破坏；v1 鳞片不过滤，Designs §12.3 附录）。测试套件：`test_l5_unlocks.gd`（过滤用例）+ `test_l3_rewards.gd` 回归
- [ ] T011 [M2] [P] UI 卡：新建 `Project/ui/unlock_toast.gd`（+.uid）**基于 ui/kit chip/banner**（监听 `content_unlocked`；数据通路 only，编排/仪式归 S4；toast ≤ 1 几何规则）；main/game_world 接线。测试套件：`test_l5_unlocks.gd`（toast 数据断言）+ 几何探测（进组自动覆盖）

**M2 收口**: 严格门禁绿 → 勾卡 → 提交 → 合 main。

---

## M3 簇 — 传承石（US2，P1）

**Goal**: 高光阈值 JSON 化；run_ended → 铸石入档；run 2 选石 → bias 以 `scale_tag_weights` 加权鳞片/奖励抽样（`ScaleRewardSystem.set_sampling_bias` 既有钩子零改造接入）；StoneSelectScreen（kit，**空列表整屏跳过**——概念第二局登场，裁定 #12）；game_over/summary 结算数据通路。

**Independent Test**: 定造 stats → 正确 highlight_type 石入档（阈值改 JSON 可反证）；选石事件 payload = 完整 stone dict；bias 注入后定种子抽样分布偏移可断言；空石列表 → StoneSelect 不闪现、整屏跳过。

- [ ] T012 [M3] Red 卡：重写 `Project/Test/cases/test_l5_legacy.gd`——高光阈值出自 JSON（改写 ConfigManager 段反证）；铸石/容量 5/最旧轮换（临时 save_path）；`legacy_stone_selected` payload 带完整 stone（{stone_index, stone}）；bias 消费：注入 scale_tag_weights → ScaleRewardSystem 定种子抽样分布偏移断言；bias 一局有效（run_started 生命周期）；StoneSelect 空列表跳过。测试套件：`test_l5_legacy.gd`
- [ ] T013 [M3] 验证修复 `Project/systems/meta_growth/legacy_stone_system.gd`（判决：保留+修）：`_evaluate_highlight` 魔数（30/5/2/3）→ `meta_growth.legacy_stone_thresholds` JSON + ConfigManager accessor；`select_legacy_stone` 发完整 stone dict；无高光默认石保持；去 class_name。**EventBus 契约变更（legacy_stone_selected payload）+ JSON schema 变更同提交落 QuickReference。**测试套件：`test_l5_legacy.gd`
- [ ] T014 [M3] bias 消费卡：选中石的 `bias_config.scale_tag_weights` 经 `ScaleRewardSystem.set_sampling_bias`（S2 T005 预留钩子：收合格选项 Array → 返回加权重排 Array）接入鳞片抽样；RewardFlow 奖励抽样同口径加权（tag 匹配项权重乘数）；bias 生命周期 = 恰一局（下个 `run_started` 未带石则清除，FR-015）。测试套件：`test_l5_legacy.gd`（分布断言）+ `test_l4_scale_rewards.gd` 回归
- [ ] T015 [M3] UI 卡：新建 `Project/ui/stone_select_screen.gd`（+.uid）**基于 ui/kit**（choice_card 列石 + 「不继承」入口；**空列表整屏跳过**，FR-012）；挂 main.tscn UILayer；数据通路 only——`GameManager.GameState` 枚举扩展（STONE_SELECT）与屏幕流编排归 S4，S3 以系统级公共 API + 测试驱动。测试套件：`test_l5_legacy.gd`（公共 API 驱动 + 跳过用例）+ 几何探测
- [ ] T016 [M3] [P] 结算数据通路卡：`MetaGrowthRoot` 暴露 `get_last_run_summary()`（本局统计 + 新铸石 + 新解锁缓存，run_ended 时写入）；game_over 屏数据可达性（显示编排归 S4 RunSummaryScreen，S3 仅数据断言）。测试套件：`test_l5_legacy.gd`

**M3 收口**: 严格门禁绿 → 勾卡 → 提交 → 合 main。

---

## M4 簇 — 事件拾取 + 全环冒烟 + 封口（US3 SHOULD + 验收）

**Goal**: 精英掉落 `broken_eye` 网格实体（v1 唯一拾取；携带/激活模型保留 per Designs §9.4，激活路线 A/B 入 backlog）；层末未激活清除；L5 全环冒烟（死 → 元 → 二局 bias）；文档清偿 + S3 Gate-A 记录。

**Independent Test**: 击杀 `is_elite` 敌人 → 网格实体掉落（占用格偏移）→ 蛇头拾取 → 携带效果（敌人下一步方向显示，DangerIndicator 复用）→ floor 离场未激活清除；`test_l5_full_loop` 绿。

- [ ] T017 [M4] Red 卡：重写 `Project/Test/cases/test_l5_pickups.gd`——elite 判定走 Enemy 节点 + `ConfigManager.get_enemy_type(...).is_elite`（草稿 Dictionary 判型 / `enemy_type != "elite"` 字符串比对的回归用例）；randf 顺序（先判 elite 再掷骰，非精英零 RNG 消耗——定种子可证）；v1 池恰 = broken_eye（serpent_scale 不可掉落）；网格实体掉落/蛇头拾取；占用格偏移最近空格；floor 离场未激活清除；激活 API 幂等保持。测试套件：`test_l5_pickups.gd`
- [ ] T018 [M4] 验证修复 `Project/systems/events/pickup_system.gd`（判决：修+补实体层；**SHOULD——砍单阶梯首位**，超预算整簇入 backlog 并在 spec 标注 deferred）：修 `_on_enemy_killed` 节点判型（`enemy_def` 为 Node 派生，同 ShedskinSystem 口径）；elite 经 is_elite 配置；randf 顺序修正；v1 池 = broken_eye only；网格实体化（仿 food：GridWorld 占格 + 蛇头碰撞拾取 + 占用格偏移）；携带效果接 DangerIndicator 数据通路（敌人下一步方向显示）；激活模型保留（active 字段 / `activate_pickup` API / `pickup_activated`；路线 A/B 入 backlog）；floor 离场未激活清除（FR-008）；game_world 接线 + cleanup。去 class_name。测试套件：`test_l5_pickups.gd`
- [ ] T019 [M4] 全环冒烟卡：新建 `Project/Test/cases/test_l5_full_loop.gd`（+.uid）——临时 save_path 全程：run 1 死亡 → `run_ended` 恰一次 + 铸石入档 + 解锁评估 + 存档文件落盘可读回；run 2 → StoneSelect 选石（公共 API）→ bias 影响定种子抽样分布；测后清理临时档（SC-008）。测试套件：`test_l5_full_loop.gd`
- [ ] T020 [M4] 验收重写卡：重写 `Project/Test/cases/test_l5_acceptance.gd` 对照修订版 spec SC-001..SC-008 逐条映射（SC-002 以同路径新实例重载为跨进程代理；全程临时 save_path）。测试套件：`test_l5_acceptance.gd`
- [ ] T021 [M4] 文档清偿 + S3 Gate-A 卡：`TechDocs/QuickReference.md` 增「L5 元成长事实」节（run_ended / legacy_stone_selected 冻结契约、unlock v1 映射、存档 schema、发射方→监听方表增量）；`AgentOps/CurrentState.md` S3 收口卡（Gate-A 记录：STRICT PASSED + 套件数核对 + 全环冒烟；Gate-H 待办：重启游戏跨进程持久化 + 删 user:// 重验，连同 S2 三项人工欠账一并列出）；DailyLogs。测试套件：严格门禁全量

**M4 收口**: 严格门禁绿 → 勾卡 → 提交 → 合 main。**此 Gate 过 = 循环机制闭合（第二存活检查点）。**
