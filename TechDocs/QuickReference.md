# 事实摘要 — 当前实现状态速查

> 本文件是设计文档的精简索引。修改设计文档或代码后必须同步更新。
> 完整设计见 `Designs/General/snake_roguelite_design.md` 和 `TechDocs/ScriptingLeading.md`。

## 项目概述

Godot 4.6 + GDScript 贪吃蛇 Roguelite。Grid-based、Tick-driven、Event-driven、Data-driven。

## 里程碑进度

| 里程碑 | 内容 | 状态 |
|--------|------|------|
| L0 | 基础移动 + 长度 + 食物 | ✅ 完成 |
| L1 | 战斗循环 + per-segment status + T25 Atom System | ✅ 完成（1030 测试） |
| L2-Phase0 | T27A StatusCarrier + ReactionResolver + CollisionHandler | ✅ 完成（1082 测试） |
| L2 | 蛇头/蛇尾/蛇鳞统一 Atom Chain | ✅ 完成 T27A~T33（1518 测试） |
| L2.5 | Virtual Player 自动化测试基础设施 | ✅ 完成 |
| L3 | 完整一局：地图 / 房间 / 奖励 / 终局 | ✅ v1 完成并已提交（RunState、FloorMap、房间流程、奖励选择、楼层推进、终局、占位 UI smoke） |
| L4 | 成长循环（蜕皮/鳞片奖励/槽位/商店/PCG/难度） | ✅ 完成（S2 重验收，spec 002 修订版 SC-001..SC-012 全量自动验收 + 多层冒烟 + VirtualPlayer 体验冒烟 + Layer C 截图证据） |
| L5 | 元成长（解锁/传承石/拾取/user:// 存档） | ✅ 完成（S3 重验收 M1-M4：`run_ended` 链路 + 存档硬化 / MetaGrowthRoot + 解锁门控 / 传承石 bias + StoneSelect / broken_eye 网格拾取 + 全环冒烟 `test_l5_full_loop` + SC-001..SC-008 验收）——roguelite 循环机制闭合（第二存活检查点） |
| 体验层 | 程序化美学 + 游戏手感（SpecKit 004） | 📋 已规划：设计文档 `Designs/Interactive/presentation_design.md` 先行 |

## 核心配置

```
Project/data/json/game_config.json    # 核心配置（grid/tick/snake/food/enemy/status/reactions）
Project/autoloads/event_bus.gd        # 全局事件定义
Project/systems/atoms/atom_registry.gd # T25 原子注册表（68 原子，24 触发器）
Project/ui/build_test_panel.gd        # T33 Build 测试面板（B 键切换）
Project/systems/status/reaction_resolver.gd  # T27A 反应查表引擎
Project/systems/status/collision_handler.gd  # T27A 碰撞统一处理器
AgentOps/                         # 会话无关 Agent 统筹控制面
Tools/run_tests_strict.ps1        # 严格测试包装器（扫描 Godot 错误输出）
.specify/specs/001-l3-run-loop/   # L3 完整一局 SpecKit 规格
Project/Test/cases/test_l3_run_loop.gd       # L3 配置/事件契约测试
Project/systems/run/run_progression_system.gd # L3 run 生命周期状态机
Project/systems/rooms/floor_map_generator.gd  # L3 v1 固定短路径房间地图生成器
Project/Test/cases/test_l3_room_flow.gd      # L3 US1 房间进入/完成测试
Project/systems/rooms/room_flow_system.gd    # L3 房间生命周期与目标进度
Project/ui/room_intent_panel.gd              # L3 房间意图/进度占位 UI
Project/Test/cases/test_l3_rewards.gd        # L3 US2 奖励展示/选择/Build 应用测试
Project/systems/rewards/reward_flow_system.gd # L3 奖励 offer、选择和 Build 接入
Project/ui/reward_choice_panel.gd            # L3 奖励选择占位 UI
Project/Test/cases/test_l3_floor_progression.gd # L3 US3 楼层推进/进度 UI 测试
Project/ui/floor_progress_panel.gd           # L3 楼层进度占位 UI
Project/Test/cases/test_l3_run_end.gd        # L3 US4 终局/死亡/cleanup 测试
Project/Test/cases/test_l3_smoke_run.gd      # L3 v1 固定路径占位 UI smoke run
```

- CELL_SIZE = 32，网格 40×22
- Tick = 0.25s
- 测试入口：`res://Test/test_runner.tscn`
- 严格测试入口：`$env:GODOT_DISABLE_CRASH_HANDLER="1"; powershell -ExecutionPolicy Bypass -File Tools/run_tests_strict.ps1`
- 当前验证事实（2026-06-12，S4 T107 机器层收口）：普通测试 `4430/4430` 断言通过，套件 `79/79`（runner 现核对"发现/运行"数）；严格门禁 `STRICT PASSED`；Layer C `2026-06-12` 批 9 镜头 9 PASS / 0 FAIL；**Gate-H 人工终审未清（阻塞 S4 封板）**。严格脚本先跑 `--headless --import` 重建 class cache/.uid（导入器输出不进扫描），再跑测试并扫描 stderr，豁免 AtomRegistry 负向测试、lambda capture 清理日志和 headless 退出期资源日志。
- Layer C 截图装置（spec 002 T035）：`Project/AcceptanceShots/acceptance_shots.tscn`（自承载主场景，与 Layer A/B 共用 state_stager）经 `Tools/run_acceptance_shots.ps1` **带窗**运行（headless 截图全黑），输出 `AgentOps/acceptance_shots/<date>/`（PNG + manifest.json + AI 读图 findings.md）；Stage Gate 时点使用。
- 测试约定：禁止裸引用全局 class_name，一律 `const XxxScript := preload(...)`（见 ScriptingLeading 附录 C.8）；坏套件计 FAIL 不再静默吞测（2026-06-05 的"ALL PASSED 758/758"假绿根因已修复）。

## 表现内核事实（SpecKit 004 Phase F，2026-06-11）

- 设计文档：`Designs/Interactive/presentation_design.md`（「网格信号」，表现层 source of truth）。
- `game_config.json` 新增 `presentation` 段：palette（20 token）/typography/motion（tick 量化）/layout/glyphs/acceptance/game_feel/audio/hints/death_causes/debug_ui；ConfigManager 全套 accessor。
- `Project/ui/kit/`：theme_builder（JSON→Theme + 对比度对 + WCAG contrast_ratio）、kit_panel（角括号框基类，出生带 ui_kit 分组/ui_layer 元数据/settle()/track_tween/register_hit_target）、glyph（_draw 零子节点数据驱动图标）、choice_card/banner/chip（零编排组件态）。
- 仪表缝：TickManager `manual_mode`+`step_once()`（pause 期间步进无效）；VFXManager `vfx_invoked` 信号 + 参数 JSON 化 + 新效果 shatter_at/ring_at/fly_to_hud。
- TickManager reason-token 暂停（Phase P T101，设计 §11.2）：`pause(reason)`/`resume(reason)`（缺省 `&"default"`，既有裸调用零破坏），原因集合空才真恢复；`start_ticking()` 清残留集合；`get_pause_reasons()` 观察点；hud 手动暂停持 `&"manual"`（test_t03 文本级契约钉住），仪式用 `&"ceremony"`——仪式 resume 不吞玩家暂停。
- 体验验收基建 `Project/Test/experience/`：experience_recorder（四通道时间线+pending modal 栈）、tick_driver（模态感知手动步进）、ui_actor（playbook 驱动面板公共 API）、ui_settle、ui_geometry_probe（几何五项+有效底色对比度，dry_run 自测）、state_stager（典型状态装配）。
- L3 三面板 + title/game_over/hud 已迁移 kit 设计语言；debug UI（kill_feed/debug_panel/build_test_panel/event_log_panel + T/Y 捷径）收进 `presentation.debug_ui` 开关（默认关）。
- banner 文字色按对比度自动选深/浅（金色底配深字）；banner 副标题用 HeadingLabel（body 字号在 room_combat 上对比 4.48 < 4.5，banner 按 large 阈值设计）。

## 体验完成层事实（SpecKit 004 Phase P，S4，2026-06-12）

- T102 AppFlow 四态收口：`GameManager.GameState` 尾部追加 `SUMMARY`（int 4，既有值不变）+
  `enter_summary()`；`game_over` 事件 → main 显示总结屏并进 SUMMARY（T103 死亡/胜利仪式
  落地后将在 GAME_OVER 与 SUMMARY 之间插入仪式时距，当前零仪式直达）。
- game_over_screen 即 §7 局后总结屏：新增运行时 `TitleButton`「回标题」+ `title_pressed`
  信号 → main 收屏、清世界、回 TITLE（§7 流程图右下分支）；常驻按钮恰 2（再来一局/回标题），
  测试模式按钮仍门控于 debug_ui。
- title_screen §7 菜单重建：运行时 `QuitButton`「退出」（quit_pressed → main quit）+
  `StoneEntryButton`「传承石」（有石碑才显示；`set_stone_source(obj)` duck-typed 注入
  `get_available_stones`，main 注入 LegacyStoneSystem；`stones_pressed` 路由 = 开始分流）。
- `CeremonyLayer`（`ui/ceremony_layer.gd`，main 运行时挂 UILayer index 0，屏幕面板之下）：
  仪式编排宿主骨架——kit 零编排红线的解除处（FR-003 对偶）；本卡含 dim 原语
  `dim_in()/dim_out()/is_dimmed()` + `settle()`；`ui_dim` 组 + `ui_layer="dim"` 元数据。
- JSON 增量：`presentation.ceremony`（`dim_alpha: 0.6`/`dim_sec: 0.3`，§8.3「dim 0.6」的
  JSON 落点，T103/T104 仪式参数逐卡补入；设计 §14 schema 同步）+
  `ConfigManager.get_ceremony_config()`。
- 新套件 `test_xp_appflow.gd`（SUMMARY 状态/壳层 e2e：ceremony 骨架、标题菜单、
  game_over→SUMMARY→回标题；main.tscn 入树即 boot 临时档红线照守）。
- 测试警示：MetaGrowthRoot 子节点 `_ready` 先于 main `_ready` 自动 boot 生产档（只读）；
  断言标题屏石碑项前必须先 `boot(临时档)` 并重注入 `set_stone_source`，否则环境依赖。
- T103 终局仪式：`CeremonyLayer.play_end_ceremony(data, on_finished)`——死亡 =
  hitstop（`VFXManager.hit_stop`）→ 蛇尾到头逐段消散（snake 组 `segments`，不在场跳过）→
  世界去饱和灰罩（§13 无 shader 近似）→ dim → 死因中文一行（display 级，
  `get_death_cause_text(cause)` 缺键回退原文）停留 → 残留全清 → on_finished；
  胜利 = 蛇头处金色扩散环（`ring_at` + `victory_ring_token`）→ dim → on_finished。
  `game_feel.enabled=false` 整体旁路直达。单链 Tween 可 `settle()` 快进（机器验收）。
- 仪式打断契约：`reset()` 杀链清残留——main 在 restart/回标题/test-mode 入口调用
  （防迟到回调污染下一局 + 防 tween 引用已释放世界节点）；`game_started` 自动 reset。
- main `_on_game_over` 委派仪式，收场回调 `_show_summary`（show_results + enter_summary）
  ——GAME_OVER 态即仪式时距，总结屏可见才进 SUMMARY。
- 总结屏（game_over_screen）：死因走 JSON 映射（victory 不带「死因」前缀）；
  `_refresh_and_stagger` 延迟权威刷 + §7 stagger 滚入（统计/死因 → 结算行 → 按钮，
  Tween 经 `_frame_panel.track_tween` 登记保 settle）。hud tick 脉搏线随 `game_over`
  渐灭（时长 = ceremony.desaturate_sec），`game_started` 复位。
- JSON 增量：`presentation.ceremony` 扩展（death_hitstop_sec 0.1 / dissolve_per_segment_sec
  0.05 / desaturate_alpha 0.55 / desaturate_sec 0.4 / cause_hold_sec 0.8 /
  victory_ring_token）+ `death_causes` 填充（hit_boundary/hit_self/no_body_timeout/
  victory/unknown，键 = `snake.die(cause)` 实际死因）+ `get_death_cause_text()`；
  设计 §14 同步。新套件 `test_xp_ceremony.gd`（映射/门控/打断/game_feel 旁路）。
- T104a 房间意图两段式（§8.1）：room_intent_panel 增 `show_banner_stage()/
  collapse_banner()/is_banner_expanded()`（组件零编排状态切换）+ 出生入
  `room_intent_panel` 组（编排寻址）；CeremonyLayer 监听 `room_entered` → 展开横幅 →
  `ceremony.room_banner_sec`（0.9）后收缩为 chip；game_feel 关闭直达 chip 态；
  未被驱动（world-only 测试/几何布景）横幅常驻 = Phase F 静态版兼容。
- T104a 楼层小地图（§8.2，`ui/floor_minimap.gd`，game_world 运行时挂 `UI/FloorMinimap`）：
  左上 kit 面板，数据驱动 _draw 零子节点——主路径横排（exits[0] 链）+ 支线挂父房下行；
  房色 = room_* token（回退 placeholder_color）；当前 = accent_resonance 外框
  （game_feel 开启正弦脉动，_process 驱动无 Tween——不进 settle 语义）；完成 = 暗化 +
  中心点；未达 = frame_line 深灰；`floor_generated` 重建（floor 前隐藏，跨层状态清空）。
  查询契约 `get_room_count/get_current_room_id/is_room_completed`（test_xp_minimap）。
- 测试警示：多壳层套件子测试间必须 `await process_frame` 冲 queue_free——旧壳
  CeremonyLayer 仍连 EventBus 时 `room_entered` 一发多收（test_xp_ceremony _teardown）。
- T104b 选择仪式（§8.3）：CeremonyLayer 监听三模态 `*_presented`（reward/scale_reward/
  floor_reward）→ `TickManager.pause(&"ceremony")` + dim_in；决议事件（chosen×3 +
  scale_option_discarded）→ resume + dim_out + 蛇头 acquire 环（accent_resonance，
  「选中卡飞向蛇头」v1 近似，整卡飞行收 spec 004 backlog.md）。`_choice_paused` 内部
  持锁——只解自己加的锁（FR-014 自动决议无 presented 绝不幻影 resume）；floor_reward
  两段重呈现单 token 原地保持；shop_entered 非模态不参与；game_feel 关闭不仪式
  （FR-015 推进门控仍由 RunProgression 把守，世界级行为不变）；reset() 兼释放停拍锁。
- T104b 蜕皮飞行（§8.5）：`currency_changed` payload 增可选 `position`（Vector2i
  入账事发格）——ShedskinSystem `earn(amount, source, grid_position=null)` 第三参
  （击杀路径透传 enemy_killed.position；discard/重置无坐标不带键）；shedskin_display
  带坐标入账 → `VFXManager.fly_to_hud`（格→世界像素 ×CELL_SIZE+半格）金色粒子飞向
  chip，无坐标只 bounce。spec 004 backlog.md 新建（整卡飞行/列扫 wipe/墙体偏色/
  商店全屏卡阵四项收容）。
- T104c Build 状态条（§8.6，`ui/build_status_bar.gd`，game_world 运行时挂
  `UI/BuildStatusBar` + `setup(parts_mgr, slot_mgr, resonance_mgr)` 只读查询面）：
  底中数据驱动 _draw——[头][front…][middle…][back…][尾] 格序、空槽四角虚框、装备
  实心 + 等级点（≤3 accent_shedskin）、共鸣 = 活跃对 part_id 定位格间
  accent_resonance 连线（`ResonanceManager.get_active_pairs()` 新只读访问器，
  key "res:partA+partB" 反解）；首次发现 caption「共鸣发现：X」内嵌条上方（hud 层
  避免与 toast 互踩），`ceremony.discovery_hold_sec`（2.0）后收起（track_tween 入
  settle）。查询契约 get_cell_count/get_occupied_count/get_link_count/
  is_caption_visible/get_caption_text（test_xp_build_bar）。
- T104c 拾取闪烁（§8.7 前半）：pickup_entity `_process` 正弦 alpha 脉动
  （`blink_alpha(phase)` 纯函数钳 [0.55,1.0]，`game_feel.pickup_blink_hz`（1.2）驱动；
  game_feel 关闭恒亮）。
- T105 程序化音频（§9/§10）：`SFXForge` autoload（boot 按 `audio.sfx` 合成
  AudioStreamWAV——16-bit mono 22050、s16 小端手写、id 哈希 LCG 确定性噪声、
  `steps>1` 扫频量化台阶 = room_clear 两音上行；11 音色全 JSON）+ `AudioManager`
  autoload（8 voice 池、仅监听 EventBus、`dedup_ms` 防重 ticks_msec 差值、
  `sfx_invoked` 仪表 + `last_played` 环形缓冲 ≤32、`audio.enabled=false` 零播放）。
  两 autoload 注册在 VFXManager 之后（坑 #3：晚于 ConfigManager）。
- T105 触发表落地（§9 表即代码）：`game_feel.triggers` 9 行（MUST #1-8，#5 三变体
  `sfx_variants` 按 reaction_id 哈希定声、#8 拆 choice_presented/chosen 两行，
  presented 族 card_in ×3 stagger 0.06s 超防重窗）；连吃音高 +1 半音/4s 衰减
  （`pitch_step_semitones`/`streak_window_sec`，`game_started` 清 streak）；
  `ConfigManager.get_trigger(event_id)`/`get_audio_config()` 新 accessor。
  **强度数值单一来源迁移**：enemy_killed hitstop 0.02→表 0.03（enemy_manager）、
  segment_loss shake 3.0→表 4.0 + 新增 hitstop 0.05（length_system）、
  body_attacked shake 1.5→表（enemy.gd）、死亡 hitstop = triggers.snake_died.hitstop
  （`ceremony.death_hitstop_sec` 已删，单一来源）。强度排序硬约束 segment_loss > hit
  由 test_xp_audio 从同一 JSON 断言。新套件 `test_xp_audio.gd`。
- T107 S4 Gate 机器层（2026-06-12）：3 局 soak `test_xp_soak`（连续三局 + 回标题分支，
  每局 run_ended 恰一、模态全收、dim 清）；AcceptanceShots 镜头清单扩到 9（新增
  08 总结屏 / 09 选石屏）；GameTransition 入 settle 语义（ui_kit 组 + settle()——
  修 S2 顺手项 GO! 定格，连带消除局内镜头黑罩残留）；stager game_over 布景死因
  改真实键 hit_self（总结屏镜头显示中文映射）。Layer C findings 9 PASS / 0 FAIL。
- T106 认知轻度引导（§8.8，`ui/hint_system.gd` 挂 main UILayer 跨 run）：8 条首次
  事件 caption（first_food/hit/status/reward/resonance/shedskin/shop/pickup，
  文案全 `presentation.hints`；first_shedskin 条件 = shedskin 且 amount>0）；
  底中 Build 条之上，`ceremony.hint_hold_sec`（3.0）后收起（track_tween 入 settle）；
  **≤1 概念/房间**（room_entered 重置预算；被压掉的不标已见——下房间再现）；
  已见列表入 meta 存档 `seen_hints` 可选字段（`get_seen_hints/mark_hint_seen`，
  旧档缺键走默认，schema_version 1 兼容新增）；存档源 duck-typed
  `set_save_source(root)`——`get_meta_save()` 每次取活档（boot 换档安全）。
  新套件 `test_xp_hints.gd`。

## AgentOps 统筹事实

- 仓库长期记忆放在 `AgentOps/`，新会话必须从 `AgentOps/README.md` 启动。
- L3+ 默认由 Orchestrator Agent 派发单任务卡；Implementer 不自行扩大范围。
- 当前阶段路线：S0 稳定化 ✅ → S1 体验设计文档+表现内核（SpecKit 004 Phase F）→ S2 L4 重验收（spec 002）→ S3 L5（spec 003）→ S4 体验完成层（004 Phase P）→ S5 封板。S2/S4 按 US 合 main，其余按 Stage 合 main。
- 安全快照：`snapshot/2026-06-10-raw-worktree` 保存 6-05 草稿原始状态，永不合并。
- 设计门禁：体验深度、认知轻度；美术/UI 占位将由 SpecKit 004 表现内核替换为统一设计语言。
- 治理规则：改 EventBus 契约或 JSON schema 的提交，必须同一提交内含 QuickReference 增量。

## L3 Foundation 事实

- `game_config.json` 新增 `run` / `floor` / `room_types` / `rewards` / `endpoint` 配置。
- ConfigManager 新增 L3 访问器：`get_run_config()`、`get_floor_config()`、`get_room_type()`、`get_reward_pool()` 等。
- EventBus 新增 L3 信号：`run_started`、`floor_generated`、`room_entered`、`room_completed`、`reward_presented`、`reward_chosen`、`floor_completed`、`run_victory` 等。
- `RunProgressionSystem` 已支持 start/victory/death/cleanup 生命周期、当前房间查询、可进入房间列表、房间完成后解锁下一房间，以及 `advance_to_room(room_id)` 显式推进。
- `RunProgressionSystem` 只接受当前可进入房间的 completion，监听 `room_advance_requested` 进入下一房间，监听 `snake_died` 同步 death outcome，并在 endpoint 完成时发出 `floor_completed` / `run_victory`。
- `FloorMapGenerator` 已支持从 JSON `floor.fixed_v1_path` 生成确定性短路径房间图，房间类型、意图、目标和占位颜色来自 JSON。
- `RoomFlowSystem` 已支持进入当前房间、监听既有 `enemy_killed` 事件推进 `clear_enemies` 目标、发出 `room_objective_progressed` 和单次 `room_completed`。
- `RoomIntentPanel` 已作为功能占位 UI 接入 `game_world.tscn`，显示房间意图、目标进度和完成状态；正式美术可后续替换节点表现。
- L3 v1 战斗房当前配置为 `required_count=3` 且 `enemy_count=3`，这是 JSON 数值，不写死在系统代码中，避免“清空敌人”提前完成。
- `RewardFlowSystem` 已支持从 JSON `rewards.pools.starter_build` 生成最多 3 个可应用选项，监听配置的 `rewards.trigger_room_types`；v1 从 `reward` 房进入触发，选择后完成奖励房，并通过既有 `SnakePartsManager` / `ScaleSlotManager` 应用 head/tail/scale 奖励。
- `RewardChoicePanel` 已作为功能占位 UI 接入 `game_world.tscn`，使用按钮、文本标签和色块表达奖励选择与已选择反馈。
- L3 v1 奖励先复用既有 Build 系统，单次展示最多 3 个选项。
- `FloorProgressPanel` 已作为功能占位 UI 接入 `game_world.tscn`，使用色块和文本展示固定路径进度、当前房间意图和完成状态。
- `FloorProgressPanel` 已支持 Next 按钮/`request_next_room()`，通过 EventBus `room_advance_requested` 请求进入下一可用房间；UI 不直接修改 run state。
- `rest` 与 `endpoint` v1 通过 JSON `auto_complete_on_enter` 自动完成，避免 L3 v1 引入额外休整系统或 Boss 机制。
- `test_l3_smoke_run.gd` 已验证真实 `game_world.tscn` 能通过占位 UI 跑完固定一局：战斗 → 奖励 → 战斗 → 休整 → endpoint → victory/game over。
- `game_world.gd` 的 L3 子节点引用使用 `get_node_or_null()`，继承的 L1/L2 验收场景可以不带 L3 节点进树。
- `game_world.cleanup()` 已清理 L3 state、Build state、window state，以及 `TriggerManager` 对场景级 enemy/food/window manager 的引用；`VFXManager` 会在旧 VFX 层失效后重建。

## L4 配置与契约基线（S2 T1，spec 002 修订版 2026-06-11）

配置事实（`game_config.json`，测试套件 `Project/Test/cases/test_l4_config.gd`）：

- `run.max_floors: 3` **显式取代并删除** `max_floors_v1`（FR-016/SC-009；grep 验证旧键零 GDScript 调用方，无需迁移；`run_progression_system` 在 T022 才消费新键）。
- `floor.generator: "fixed_v1"`，枚举 `fixed_v1 | pcg`（FR-016）；fixed_v1 为回退/MDE 路径。
- 概念节奏纯数据（FR-017/SC-010）：`floor.modifier_weights`（首层全 0，2 层起正权重）、`floor.elite_weights`（首层 0，逐层严格递增）、`floor.shop_guarantee`（`min_combat_rooms_before: 2`，每层保底商店）。
- `shop.price_multiplier_per_floor: 1.25`（FR-003：蜕皮跨层保留，下层物价上涨是唯一经济压力阀）。
- `room_types.shop`（`auto_complete_on_enter: true`，退店无目标门槛）、`room_types.elite`（clear_enemies，不自动完成）。
- `enemy_types.elite_wanderer|elite_chaser|elite_bog_crawler`：`is_elite: true` + `base_type`，复用基础型 shape/color，`visual_scale: 1.25` + `outline_palette_token: "room_elite"`（描边表现留待 UI 卡）；三个基础型显式 `is_elite: false`。精英不入 `enemy.spawn_weights` 常驻池，由 RoomDirector（T021）按 `floor.elite_weights` 注入。
- `difficulty.floor_table`（FR-008 MUST 静态层表：enemy_count 3/4/5、enemy_hp_bonus 0/1/2 严格递增，food_count 不回落）+ `difficulty.reactive`（SHOULD：normalization 分母 room_clear_ticks/damage_taken_per_room/status_usage_per_room + delta clamp，隐性、仅生成参数级验证）。T030 增量：`overperform_threshold: 0.75`（0.7 恰为「秒清零受击零状态」驱动器分数 0.4+0.3 的浮点临界，全 world 测试会抖）、`min_food_count: 0`（食物可被压到零）、死键 `baseline_food_count` 删除（食物静态基数 = floor_table.food_count）。
- `room_modifiers` 恰为 v1 双件 = `shield_enemies` + `preset_status_tiles`（各带逐项 `enabled` 开关，FR-009）；schema = `params`（应用参数）+ `visual`（表现参数），草稿 `apply_chains/remove_chains/visual_config` 键废弃。`darkness`/`speed_strips`/`mine_tiles` 草稿残留键已随 T029/T031 删除（backlog.md 收容，`test_l4_config` 文本级断言零残留）。

ConfigManager 新 accessor：`get_max_floors()`、`get_floor_generator()`、`get_floor_modifier_weights(floor)`、`get_floor_elite_weight(floor)`、`get_shop_guarantee()`、`get_shop_price_multiplier_per_floor()`、`get_difficulty_floor_table()`、`get_difficulty_floor_params(floor)`、`get_difficulty_reactive_config()`；楼层键表查询统一走 `_get_floor_keyed_value`（精确命中 → 钳制到 ≤floor 的最高定义层 → 最低定义层）。

L4 事件契约「发射方 → 监听方」对照表（T1 落地信号定义；接线落在标注簇）：

| 信号 | payload | 发射方（计划） | 监听方（计划） |
|------|---------|----------------|----------------|
| `currency_changed` | {currency, amount, total, source} | ShedskinSystem（T2 ✅） | shedskin_display（T2 ✅） |
| `scale_reward_presented` | {room_id, options, offer_id, pool_id} | ScaleRewardSystem（T2 ✅） | scale_choice_panel、RunProgression/FloorProgressPanel 模态门控（T2/T007 ✅） |
| `scale_reward_chosen` | {offer_id, option_id, scale_id, position, level, skipped} | ScaleRewardSystem（T2 ✅） | scale_choice_panel、门控解除（T2 ✅） |
| `scale_option_discarded` | {offer_id, discarded_ids, shedskin_gained} | ScaleRewardSystem（T2 ✅） | ShedskinSystem（discard 收入）、scale_choice_panel、门控解除（T2 ✅） |
| `shop_entered` | {room_id, items} | ShopSystem（T3） | shop_panel（T3） |
| `shop_purchase` | {item_id, category, cost, currency_remaining} | ShopSystem（T3） | ShedskinSystem、shop_panel（T3） |
| `slot_unlocked` | {position, total_slots, source} | SlotExpansionSystem（T3） | Build 面板（T3） |
| `floor_reward_presented` | {reward_id, floor_index, source_room_id, step: "slot_unlock"\|"choice", slot_options, options} | FloorRewardSystem（T5b ✅，Boss 结算两段各发一次） | floor_reward_panel、RunProgression/FloorProgressPanel 模态门控（T5b ✅） |
| `floor_reward_chosen` | {floor_index, category, option_id, skipped} | FloorRewardSystem（T5b ✅，skipped=true 为空选项自动决议 FR-014） | RunProgression（决议先于 advance_floor/floor_generated，T027 ✅）、floor_reward_panel 收面板 |
| `difficulty_adjusted` | {reason, adjustment: {score, floor_index, enemy_delta, food_delta, reactive_enemy_delta, reactive_food_delta}} | DifficultyScaler（T030 ✅，每 rooms_between_adjustments 房重算时发射） | 监听方为空——RoomDirector 经 duck-typed 钩子拉取（唯一消费者），事件供表现层/调试观测（S4） |
| `room_modifier_applied` | {room_id, modifier_id} | RoomModifierSystem（T031 ✅，经 RoomDirector 注入点应用） | 表现层（S4）；测试观测 |
| `floor_theme_set` | {theme, pressure, floor_index} | RoomDirector（T5a ✅，生成器保持纯函数） | 表现层（S4） |

FR-018 显式保留契约：**RewardFlowSystem 为 L3 `reward` 房发射的合成 `room_completed` 是该类房间唯一完成通路（load-bearing），保留不动**；草稿 ScaleRewardSystem 的合成 `room_completed` 是缺陷（幻影二次 offer 根因之一），T005 拆除——拆除范围仅限 ScaleRewardSystem。空选项 offer 一律自动决议（chosen 带 `skipped: true` 或 discarded，FR-014）；任一 `*_presented` 未决时推进请求被忽略（FR-015，T007 落地）。

## L4 鳞片奖励链 + 蜕皮经济事实（S2 T2，T004-T010，2026-06-11）

- `ScaleRewardSystem` 重写落地：战斗房 `room_completed`（`growth.scale_reward.trigger_room_types`）→ 恰 3 选项 offer；
  选择经 `ScaleSlotManager.equip_scale` 装备，**满槽替换**（卸该位置首槽旧鳞再装新鳞）；
  选项按「位置可承载」过滤（有空开放槽或可替换）；**无合成 `room_completed`**（FR-018）；
  决议顺序先清状态再发事件（草稿 :85/:98 幻影二次 offer/软锁根因已修）；
  `set_sampling_bias(Callable)` 传承石偏置钩子留给 L5（收合格选项 Array → 返回重排 Array）。
- 决议事件语义：选择 → `scale_reward_chosen`（skipped=false）+ `scale_option_discarded`（未选 2 项，每项 +`scale_discard`）；
  放弃全部（`discard_offer()`）→ 仅 `scale_option_discarded`（全部选项 × `scale_discard`）；
  空池/零合格 → 仅 `scale_reward_chosen`（skipped=true，不发 `scale_reward_presented`，FR-014）。
- `ShedskinSystem` 修复落地：`enemy_killed` 的 `enemy_def` 按 **Enemy 节点**取 `enemy_type`（草稿当 Dictionary 判型的死代码已修），
  精英判定走 `ConfigManager.get_enemy_type(...).is_elite`；**跨层保留**（`floor_generated` 清零路径已删，FR-003）；
  `run_started` 清零（FR-013）；消费 `scale_option_discarded.shedskin_gained` 入账（source=`scale_discard`）。
- 模态门控（FR-015）落地两处：`RunProgressionSystem._pending_offers` 家族登记
  （reward/scale_reward/floor_reward 三家族，`has_pending_offer()` 公共查询，未决时忽略 `room_advance_requested`）；
  `FloorProgressPanel` 同步登记（Next 按钮禁用 + `request_next_room()` 返回 false，`is_advance_blocked()` 公共查询）。
- `RewardFlowSystem` 回补（FR-014）：零可应用选项时自动决议——发 `reward_chosen`（payload 带 `skipped: true`）+
  合成 `room_completed`（完成通路保留），不发 `reward_presented`；choose 路径同步改为先清状态再发事件。
- UI：`ui/scale_choice_panel.gd` 基于 ui/kit 重建（modal 层 + ui_modal 组；choice_card×3 + 放弃入口
  「放弃全部 +N 蜕皮」，N = 选项数 × `growth.shedskin.scale_discard`）；`ui/shedskin_display.gd` 基于 ui/kit chip 重建
  （hud 层右上角，shedskin glyph + accent_shedskin；**渐进披露**：首次入账 amount>0 才出现）。
  两面板均已去 class_name（按路径加载，ScriptingLeading C.8）。
- `game_world.tscn/gd` 接线：`ShedskinSystem`/`ScaleRewardSystem` 场景节点 + `UI/ScaleChoicePanel`/`UI/ShedskinDisplay`；
  `cleanup()` 扩展。L3 全量回归套件（smoke/acceptance/xp_contracts/stager）已适配鳞片模态：
  战斗房完成 → 决议鳞片 offer → 才能推进。
- JSON 增量：`growth.scale_reward.default_pool: "l1_basic"`（present_offer 缺省池走配置，不写死池 id）。
- 几何探测新增状态 `l4_scale_pending`（state_stager + test_xp_ui_geometry：鳞片模态 + 蜕皮 chip 同屏探测）。
- 测试事实：`enemy_killed` 全局总线 payload 的 `enemy_def` 必须是 Node 派生或 null
  （EnemyManager 按 Node 收参；测试 mock 用 Node2D + enemy_type 属性）。

## L4 槽位扩展 + 商店经济事实（S2 T3，T011-T016，2026-06-11）

- `ScaleSlotManager` 槽位上限 JSON 化（T012）：`MAX_SLOTS` 常量删除，`init_manager` 读
  `growth.slot_expansion.max/initial`；新 accessor `get_max_slots(position)` /
  `get_open_slots(position)`（消费方不得直读 `_open_slots`；`build_test_panel` 已迁移）。
- `SlotExpansionSystem` 重写为**薄适配器**（T012）：不再自持槽位计数，唯一事实源 =
  ScaleSlotManager；`unlock_slot(position, source)` 真调 `open_slot()` 成功才发
  `slot_unlocked {position, total_slots, source}` + 记解锁史；监听 `shop_purchase`
  （category=`slot`，按 item_id 解析位置）走同一通路；草稿监听 `floor_reward_chosen`
  （expansion）属旧奖励模型已拆除——Boss 固定槽位解锁步骤（FR-007）由 T025 经
  `unlock_slot(position, "boss")` 接入。
- `ShopSystem` 修复落地（T014）：**种子 RNG 抽货**（`hash(run_seed:room_id)`，同局同店
  确定性，草稿 :198 pool[0] 伪随机已修）；容量按 `get_open_slots < get_max_slots`
  判定（草稿 :130 误用已装数已修）；**退店通路 = `room_entered`**（进商店房开店、进任何
  其他房关店；商店房 `auto_complete_on_enter: true`，**不注册模态门控**——否则门控 +
  进房退店组合必死锁，spec「allow exit without purchase」）；物价 = `ceil(基准价 ×
  price_multiplier_per_floor^(楼层-1))`（FR-003，监听 `run_started`/`floor_generated`
  取 seed 与楼层）；空货架自动决议（FR-014：零可上架项不发 `shop_entered`、不进 active）。
- 购买语义：scale → 满槽替换装备（与 ScaleRewardSystem 同语义）按 tier 等级；slot →
  只验容量后发 `shop_purchase`，真开槽由 SlotExpansionSystem 事件链完成（FR-011）；
  head/tail upgrade → `equip_head/equip_tail(part_id, level+1)`（已装备且下一等级
  配置存在才上架）。`setup(shedskin, scale_mgr, parts_mgr)`（草稿第 4 个 panel 参数删除，
  表现层只听不驱动）。
- JSON schema 增量（`shop` 段）：`scale_pool: "l1_basic"`（货架鳞片抽样池，草稿 :199
  硬编码池 id 已入配置）、`shelf_plan: {scale: 2, slot: 1, head_upgrade: 1,
  tail_upgrade: 1}`（货架构成纯数据，合计 ≤ `max_items_per_shop: 5`，SC-003 ≥3 项）、
  `item_categories.scale_l1|l2|l3` 增 `level`（tier 等级）、`item_categories.slot_*`
  增 `position`。
- 固定路径增商店房（T016/MDE）：`floor.fixed_v1_path = [combat_01, reward_01, combat_02,
  shop_01, rest_01, endpoint_01]`（6 房，`rooms_per_floor: 6`）；shop_01 排在 2 个战斗房后
  （FR-017 商店保底在 fixed_v1 档的体现），F5 即可走到买槽。L3 回归套件
  （acceptance/smoke/floor_progression/run_end/xp_contracts/T010）已适配 6 房路径。
- `game_world.tscn/gd` 接线（T016）：`ShopSystem`/`SlotExpansionSystem` 场景节点 +
  `UI/ShopPanel`；`shop_system.setup(shedskin, scale_slot_mgr, snake_parts_mgr)`、
  `slot_expansion_system.setup(scale_slot_mgr)`、`shop_panel.setup(shop_system)`；
  `cleanup()` 扩展。买槽端到端：面板 purchase → `shop_purchase` → 适配器 `open_slot` →
  新槽可装备可共鸣（e2e 用例 `test_l4_shop._test_game_world_shop_chain`）。
- 几何探针实证缺陷顺手修（T016）：`RewardChoicePanel` 决议后的「已选择」反馈面板
  原本悬挂不收，离开奖励房进商店时构成双模态重叠；现监听 `room_entered`——
  进入非奖励触发房且无待决选项时收起（奖励房本身由 `reward_presented` 接管，
  RewardFlow 在同一派发中先行，顺序安全）。
- 几何探测新增状态 `l4_shop_open`（state_stager + test_xp_ui_geometry：两战斗一奖励
  走到 shop_01，ShopPanel 货架 + 蜕皮 chip 同屏探测）。

## L4 Seeded PCG 楼层生成事实（S2 T4，T018-T019，2026-06-11）

- `FloorMapGenerator` 重写为双档（FR-016）：`floor.generator == "pcg"` 走 seeded PCG，
  否则 fixed_v1 固定路径（回退/MDE 档，输出与 L3 验收完全一致；草稿「楼层 1 无条件短路
  固定路径、2 层起无视开关走 PCG」已修——开关全权决定档位）。`generate_floor(floor_index,
  run_seed)` 返回 map 新增 `generator` 字段标记实际档位。
- **种子推导（SC-011）**：每层 RNG 种子 = `hash("run_seed:floor_index")`，同 run 不同楼层
  独立可复现；与 ShopSystem `hash(run_seed:room_id)` 派生约定一致。RNG 调用顺序固定
  （① 主题 → ② 主路径房数 → ③ 自由槽房型 → ④ 中段洗牌 → ⑤ 商店插位 → ⑥ 支线房 →
  ⑦ 精英升格 → ⑧ 修饰符），重排即改变同种子输出。
- **结构保证（构造即性质）**：起点 = combat、终点 = boss 恰一间且为图终点（死端）；
  每层恰一间商店且所有 start→shop 路径途经 ≥ `shop_guarantee.min_combat_rooms_before`
  个战斗类房（combat/elite，SC-010——经预留中段战斗槽 + 插位下界构造保证）；奖励房
  ≥ `floor.pcg.min_reward_rooms`；主路径 `exits[0]` = 下一主路径房，支线房挂主路径房
  exits 末尾且为死端（全房可达）。精英升格 = combat 房按 `floor.elite_weights` 概率
  转 elite（起点/boss 豁免）；修饰符按 `floor.modifier_weights` 逐项概率附加到战斗类房，
  尊重 `room_modifiers.<id>.enabled` 逐项开关（FR-009）；首层两权重全 0（FR-017）。
- JSON schema 增量：`floor.pcg`（`main_rooms` 楼层键表 {min,max} 主路径房数、
  `min_reward_rooms`、`middle_type_weights`、`side_room_chance`、`max_side_rooms`、
  `side_type_weights`——草稿 :54-84 魔数全部清除，FR-010）；`room_types.boss`
  （clear_enemies、required/enemy_count 1、`is_boss: true`、不自动完成；US4 boss endpoint，
  Boss 结算消费在 T024-T027）。房 dict 新增 `modifiers: Array`（fixed_v1 档恒空）。
- ConfigManager 新 accessor：`get_pcg_config()`、`get_pcg_main_room_bounds(floor)`
  （楼层键表，钳制语义同 `_get_floor_keyed_value`）。
- 测试事实：`test_l4_pcg_rooms.gd` 重写为性质测试（定种子全等 var_to_str 比对、变种子
  10 取 ≥9 异图、BFS 全房可达、DFS 枚举 start→shop 全路径验战斗保底、房数边界 =
  main_rooms ± max_side_rooms、首层零精英零修饰 + 权重拉满反证数据通路 + 逐项 disable）；
  测试通过改写 `ConfigManager.floor`/`room_modifiers` 段并还原来驱动数据反证。

## L4 多层推进 + RoomDirector 事实（S2 T5a，T020-T023，2026-06-11）

- `EnemyManager` 增量改造（T020，默认行为与 L1/L2 完全一致）：
  `respawn_policy = "maintain"`（默认，击杀即补怪维持 `max_enemy_count`）|
  `"room_budget"`（生成既定一批不补怪，RoomDirector 用）；`spawn_budget`（room_budget
  档剩余可生成数，-1 不限，`spawn_enemy` 成功消耗 1、归零拒绝；`spawn_enemy_at`
  为脚本定点放置**不消耗**——l1/l2 验收场景用法）；`set_spawn_weights(Dictionary)`
  注入权重表（空表回退 `enemy.spawn_weights`，权重按 float 累计）。
- `RoomDirector`（T021，`systems/rooms/room_director.gd`，game_world.tscn 常驻节点）：
  `floor_generated` → 缓存楼层/主题并发 `floor_theme_set`（主题空不发——fixed_v1 档）；
  `room_entered` → 清场（clear_enemies/clear_foods）→ 重新布怪布食：仅 `clear_enemies`
  目标房有敌（预算 = 房 dict `enemy_count` + 难度 delta，钳入
  `difficulty.[min|max]_enemy_count` 后 **required_count 始终压过 cap** 保目标可达成，
  T030 起）；主题敌池经 `set_spawn_weights` 注入；elite/`is_boss` 房映射
  `enemy_types.elite_*` 变体（无变体回退基础型——spec「boss 未配置 → 精英回退」边界）；
  食物数 = `difficulty.floor_table[层].food_count` + delta（钳入
  `difficulty.[min|max]_food_count`，min 默认 0，T030 起）。
  难度钩子 `set_difficulty_scaler(obj)` duck-typed 读 `get_enemy_count_delta`/
  `get_food_count_delta`/`get_enemy_hp_bonus`（T030 实装，hp bonus 落点
  `EnemyManager.spawn_hp_bonus`）；修饰符注入点 `set_modifier_system(obj)` →
  布场后调 `apply_modifiers(room)`（T031 实装，先布怪后修饰）。
- `RunProgressionSystem` 多层推进（T022）：run state 增 `seed` 键；`advance_floor()`
  以同一 run seed 生成下一层（种子推导含 floor_index，SC-011 跨层确定性）、
  completed/available 按层重置（房 id 是楼层作用域）、`floor_generated` →
  `room_entered` 进起点房。**pcg 档**非终层 endpoint/boss 完成 → `floor_completed` →
  （`floor_reward` 家族未决则挂起，`floor_reward_chosen` 后再推进——FR-007 决议先于
  `floor_generated` 的 T027 groundwork）→ `call_deferred("advance_floor")`（boss 击杀
  级联发生在 tick 派发内，不可同步重建世界）；终层（`run.max_floors`）→ 胜利路径。
  **fixed_v1 档保持单层 MDE 闭环**（终点完成即胜利，FR-016「回退/MDE 路径」语义，
  L3 验收与 MDE 手动脚本不变——多层推进是 pcg 档行为）。
- `game_world`（T022）：`reset_for_floor()` 组合既有原语（按 target 注销蛇/段状态——
  **不可用 `StatusEffectManager.clear_all`，会连 TriggerManager 原子链清掉杀死 Build
  触发器**；clear_enemies/clear_foods/status_tile clear_all/effect window clear_all；
  蛇重建保长度），监听 `floor_generated`（楼层号大于跟踪值且属本世界 run 才重置，
  mock 发射免疫）；`start_game` 在有 RoomDirector 时不再 `init_enemies`（布怪让位
  director；l1/l2 场景无该节点保持原行为）。
- Build 跨层存续（T023，`test_l4_slots` 用例组）：蛇重建后已装鳞片/头/共鸣/开槽数/
  蜕皮余额/长度全部存续，卸装重装可驱动共鸣重算（触发器链路完好，FR-003/FR-013 边界）。
- 测试事实：`test_l4_room_director.gd`（T020 契约 + T021 布场 + T022 多层/门控/
  fixed_v1 回归 + game_world reset e2e）；全 game_world 多层测试需测试内切
  `ConfigManager.floor["generator"] = "pcg"` 并还原；boss 完成后需 `await process_frame`
  冲延迟切层。

## L4 Boss 结算 + 楼层奖励 + 多层冒烟事实（S2 T5b，T024-T028，2026-06-11）

- `FloorRewardSystem` 重写落地（`systems/growth/floor_reward_system.gd`，game_world.tscn 常驻节点）：
  Boss 结算两段式（FR-007/Designs §10.3-10.5）——① 固定槽位解锁步骤
  `choose_slot_position(position)` 经 `SlotExpansionSystem.unlock_slot(position, "boss")`
  真开槽（新槽先于 3 选 1 开放，US3 场景 1；全位置满级自动跳过）；② 独立 3 选 1
  `choose_floor_reward(index)`：扩展=随机高级鳞（`growth.floor_reward.expansion.advanced_level/
  scale_pool`，满槽替换语义同 ScaleRewardSystem）/ 强化=最低等级已装鳞免费升一级
  （`ScaleSlotManager.upgrade_scale`，满级件跳过，同级并列取 front→middle→back 序首件）/
  修正=同 tag 换鳞（保级保槽位）。无合格目标类别以高级鳞替补（去重），尽量保持 3 选项；
  全空自动决议（`floor_reward_chosen` 带 skipped=true，不发 presented，FR-014）。
- 呈现自守门（`_on_floor_completed`）：`floor_index < run.max_floors`（终层直达胜利路径，
  US5 场景 4）**且 `floor.generator == "pcg"`**（T5a 裁定：fixed_v1 = 单层 MDE 回退档）；
  `present_settlement(floor_index, room_id, salt)` 公共方法本身不设门槛（测试/布景直驱）。
  抽样种子 = `hash(run_id:floor_reward:floor_index:source_room_id)`（同 run 同层确定性）。
  `run_started` 清残留 offer（FR-013）。
- 门控时序（T027）：`floor_completed` 同步派发内 presented → RunProgression 登记
  `floor_reward` 家族 → 挂起切层；`floor_reward_chosen` → `call_deferred("advance_floor")`
  ——决议严格先于下一次 `floor_generated`（US5 场景 5，`test_l4_floor_rewards` 顺序断言）。
- `ScaleSlotManager.get_slot_layout(position)` 新 accessor：槽位原始视图（含 null 空槽，
  索引 = 真实槽位号）——升级/换鳞按槽位号定位（`get_scales` 压缩空槽索引会漂移）。
- UI：`ui/floor_reward_panel.gd` 基于 ui/kit 重建为两段式模态（modal 层 + ui_modal 组，
  右上选择栏同槽位；① slot_empty glyph 槽位卡（前段/中段/后段）→ ② choice_card×3
  （类别名 + detail 具体效果 + 底缘标签色条），已去 class_name。公共契约：setup/get_step/
  get_visible_option_count/get_slot_labels/get_option_labels/choose_slot_by_index/
  choose_slot_position/choose_option_by_index/get_status_text。
- 多层冒烟（T028，`test_l4_multifloor_run.gd`）：种子 9090 三层 PCG 至胜利全程面板公共 API
  驱动——floor_generated×3、主题（ruins/marsh/cave）与房型序列各异（SC-005）、结算未决时
  Next 被拒、槽位 3→5 真开、终层无楼层奖励、game_over cause=victory。
- 几何探测新增状态 `l4_floor_reward_slot`/`l4_floor_reward_choice`（state_stager 经
  `present_settlement` 系统公共 API 布景两段模态）。
- JSON 增量：`growth.floor_reward.slot_unlock_source: "boss"`、`expansion.scale_pool/
  advanced_level`；三类 description 对齐 Designs §10.4 措辞（诅咒鳞/头尾升级/槽位重排
  变体在 backlog.md，不入 v1）。

## L4 难度缩放 + 房间修饰符事实（S2 T6，T029-T032，2026-06-11）

- `DifficultyScaler` 重写落地（`systems/difficulty/difficulty_scaler.gd`，game_world.tscn
  常驻节点）。FR-008 两层结构：
  - **静态层（MUST，玩家可感）**：`get_static_enemy_delta()` = floor_table[层].enemy_count
    − `baseline_enemy_count`；`get_enemy_hp_bonus()` = floor_table[层].enemy_hp_bonus；
    楼层号经 `floor_generated` 跟踪。食物静态基数由 RoomDirector 直接读
    floor_table.food_count，**scaler 的 `get_food_count_delta()` 只含反应式分量**（防双计）。
  - **反应式层（SHOULD，设计不可见——Designs §11.5，验收仅生成参数级断言）**：
    单房口径度量（草稿 :114 全局累计 tick 已修）——`room_entered` 记起算 tick、
    `room_completed` 计差；命中源 = `snake_body_attacked` + `snake_hit_boundary`；
    状态源 = `reaction_triggered` + `status_added_to_carrier(carrier_type=="enemy")`；
    每 `rooms_between_adjustments` 房按 `metrics` 权重重算分数（归一化分母出自
    `reactive.normalization`，草稿 :93 硬编码已修）→ 过 `overperform_threshold` 敌 +/食 −、
    低于 `underperform_threshold` 反向，幅度 `adjustment_*_delta` 钳入 `reactive.clamp`；
    `reactive.enabled=false` 整层归零（砍单阶梯首位）、`difficulty.enabled=false` 全部归零；
    `run_started` 重置（FR-013）。`get_last_room_metrics()` 介观接口供测试。
  - **唯一消费者 = RoomDirector**（duck-typed 钩子拉取）；`difficulty_adjusted` 事件
    仅供观测，无系统监听方。
- `EnemyManager.spawn_hp_bonus`（T030 增量）：随机生成敌人在 config hp 之上加成
  （RoomDirector 每房写入 scaler 的 hp bonus；默认 0 保 L1/L2；`spawn_enemy_at`
  定点放置不吃加成——l1/l2 验收场景/触发原子语义不变）。
- `RoomModifierSystem` 重写-扩展落地（`systems/difficulty/room_modifier_system.gd`，
  game_world.tscn 常驻节点，`setup(enemy_mgr, status_tile_mgr, snake)`）。v1 双件：
  - `shield_enemies`：布场后随机 `params.max_shielded` 个敌人 hp += `params.hp_bonus`，
    挂 `ShieldOutline` 描边（`visual.outline_palette_token` palette 色、外扩
    `outline_pad`、z 序低于本体；与状态描边 3px 错开，叠加独立可读）+
    meta `room_modifier_shield`；
  - `preset_status_tiles`：经 StatusTileManager 预置 `params.tile_count` 个状态格
    （类型抽 `params.tile_types`，距蛇头曼哈顿 ≥ `params.min_distance_from_snake`，
    Designs §11.5「状态格已预置」，复用状态格视觉）。
  - 生命周期：生成期选定（FloorMapGenerator ⑧ 按 `floor.modifier_weights`）→
    RoomDirector 布场后 `apply_modifiers(room)`（注入点，重入先回收旧账）→
    `room_completed` 移除（**按 [pos,type] 账本只回收自己放置的格/盾**，不误伤外部
    状态格；存活敌人 hp 回退）→ `run_started` 清账（FR-013）。应用层复核逐项
    `enabled`（生成层之外纵深防御）；v1 集合外 id（含草稿残留）一律拒绝。
- `game_world.tscn/gd` 接线：`DifficultyScaler`/`RoomModifierSystem` 场景节点；
  `room_director.set_difficulty_scaler/set_modifier_system` + `room_modifier_system.setup`；
  `cleanup()` 扩展。接线后全 world 多层测试的楼层 2+ 敌数 = 房 enemy_count + 静态
  delta（`test_l4_room_director` e2e 断言已按 scaler 读数计算预期）。
- 测试事实：`test_l4_difficulty.gd` 重写（静态层/钳制/单房度量/事件源/clamp/分母
  JSON 反证/开关/FR-013 + 修饰符应用-移除-禁用-叠加-拒绝 + RoomDirector e2e +
  场景节点存在）；反应式用例全部为生成参数级断言（无玩家感知措辞）；
  `test_l4_config`/`test_l4_pcg_rooms` 补 T032 节奏互证（v1 集合恰为双件、params 形状、
  权重引用真实修饰符、2 层起精英/修饰从数据出现且 id 全落 v1 集合——固定种子确定性）。

## L4 验收与封口事实（S2 T7，T033-T037，2026-06-11）

- `test_l4_acceptance.gd` 重写为修订版 spec SC-001..SC-012 逐条映射：
  SC-001 世界级一屏决议（战斗完成 → 3 选项 → 面板选择 → 真实装备 + 未选 2 项
  放弃入账）；SC-002 经济三常数（1/3/2）JSON==spec、跨层保留、楼层物价
  `ceil(基准×mult^(层-1))`；SC-003 经 state_stager 布景商店购买扣款；SC-004 两段
  结算 + 终层事件路径门控（pcg 档 + 终层 floor_completed 不呈现）；SC-005 定种子
  9090 三层主题/布局各异；SC-006 静态层逐层严格更难 + 反应式纯生成参数级；
  SC-007 修饰符双件；SC-008 严格门禁装置存在性；SC-009 配置文本零 `max_floors_v1`
  残留；SC-010 多种子（9090/4242/20260611）商店保底 DFS 全路径性质；SC-011 双档
  开关 + 定种子 pcg 两次 var_to_str 全等；SC-012 四 offer 系统（RewardFlow/Scale/
  FloorReward/Shop）空选项自动决议 + 未决时推进忽略/Next 禁用/决议后恢复。
- `test_xp_contracts_l4.gd`（VirtualPlayer 冒烟，L4 新模态体验契约）：
  CompositeBrain（确定性种子 4242）经 `tick_pre_process` 注入方向真实步进穿过
  首个战斗房（目标余量 record_objective_progress 补足）→ 面板公共 API 驱动 3 层
  pcg run（种子 9090）至胜利；**防死锁断言**——任一 pending 模态无人决议即 FAIL；
  契约表：scale/floor_reward presented → 面板 ui 变化在 `feedback_window_ticks` 内、
  presented/决议恰好配对、两段结算 step 序 `[slot_unlock, choice]×2`（楼层 [1,1,2,2]）、
  shop_entered 非模态不门控、并发 pending 家族 ≤ `max_pending_modals`。
- **experience_recorder pending 语义修订（T034）**：同前缀重呈现（floor_reward 两段
  结算各发一次 presented）= 同一 offer 家族的步骤推进，pending **原地更新不叠层**
  （镜像 RunProgression 家族登记；修订前两段结算叠出悬挂模态 → 驱动死锁）。
- **game_perception 修复（L2.5 草稿缺陷，T034 Red 实证）**：`Object.get` 双参误用
  （Dictionary API 形态）——任何敌人/状态格进入 `GridWorld.cell_map` 即整个快照
  运行时中断，VirtualPlayer 盲飞；改 `_get_node_prop`（`prop in entity` + 单参 get）。
- Layer C 截图装置 `Project/AcceptanceShots/`（T035，自承载主场景模式）+
  `Tools/run_acceptance_shots.ps1`（带窗，路径读 EnvPath.json，已登记
  `EnvPath.json.commands.run_acceptance_shots`）；S2 Gate 首用证据
  `AgentOps/acceptance_shots/2026-06-11/`（7 镜头 + findings.md：7 PASS /
  2 SUSPECT 不阻塞——choice 镜头零装备致三卡全扩展替补（spec Edge Case 行为）、
  GO! 过渡字定格（ui_settle 不含 GameTransition），均登记 S4 顺手项）。
- S2 验证基线：套件 `71/71`，断言 `3635/3635`，`STRICT PASSED`；几何探测覆盖
  8 典型状态（title/game_over/l3 run/reward + l4 scale/shop/floor_reward 两段）。

## L5 元成长 M1 事实（S3 M1，T001-T005，2026-06-11）

- **`run_ended` 冻结契约（spec 003 FR-016）**：
  `{outcome: "victory"|"death", run_id: String, floor_index: int, stats: {total_turns,
  total_kills, reaction_kills, near_death_count, survival_low_length_ticks,
  floors_completed, max_reaction_chain, damage_taken, max_length, duration_ticks}}`
  ——恰四顶层键 + 十 stats 字段；草稿 `stats.run_outcome` 冗余已删（顶层 outcome 为准）。
- **唯一发射点（FR-013）**：`RunStatsTracker.finalize_run(outcome)`，once-guard 同 run 第二次
  调用零发射（`run_started` 解除）；调用方 = `RunProgressionSystem` victory（`mark_victory`）/
  death（`_on_snake_died` → `mark_death`）双出口，经 `set_stats_tracker(obj)` duck-typed 注入
  （未注入零行为——L3 既有测试零破坏；注入引用跨 start_run 存续），RunProgression 侧
  `_run_stats_finalized` 与 tracker 侧 once-guard 构成双保险。场景接线（MetaGrowthRoot
  挂 main.tscn）归 M2 T009。
- 事件对照表增量：

| 信号 | payload | 发射方 | 监听方 |
|------|---------|--------|--------|
| `run_ended` | FR-016 冻结契约（上） | RunStatsTracker.finalize_run（唯一，M1 ✅） | UnlockSystem、LegacyStoneSystem（M2/M3 重验收） |

- **RunStatsTracker 度量源（T003 补全）**：total_turns=`snake_turned`；total_kills/
  reaction_kills=`enemy_killed`（method 含 reaction）；floors_completed=`floor_completed`；
  max_reaction_chain=`reaction_triggered`（layer_a+layer_b 峰值）；damage_taken=
  `snake_hit_boundary` + `snake_body_attacked`（双源，草稿仅 boundary）；near_death_count=
  `no_body_countdown_started`；survival_low_length_ticks=`tick_post_process` × 当前长度 <
  `meta_growth.stats.low_length_threshold`（长度自 `snake_length_increased/decreased`
  new_length 跟踪）；max_length=长度事件峰值；duration_ticks=`tick_post_process` 计数。
  `run_started` 重置全部并缓存 run_id/floor_index（floor_index 随 `floor_generated` 跟进）；
  finalize 后统计冻结至下个 run_started。
- **MetaSaveSystem 硬化（T002）**：save_path 构造参数注入缝（缺省读 `meta_growth.save_path`
  = 生产路径 `user://meta_save.json`）；`_init` 不再隐式读盘（注入先于首次 IO），
  `load_from_disk()` 显式调用；`save_to_disk` 写入恒带 `schema_version`；读档 parse 失败 /
  非 Dictionary 形状 / 版本未知 → `push_warning` + 容错重置默认值（绝不带病加载）；
  缺档静默走默认。reset/容错默认值含默认解锁集（hydra/salamander）。
- **JSON schema 增量（`meta_growth` 段，T005）**：`schema_version: 1`、
  `default_unlocked_heads: ["hydra"]`、`default_unlocked_tails: ["salamander"]`、
  `stats: {low_length_threshold: 5}`。ConfigManager 新 accessor：`get_meta_schema_version()`、
  `get_meta_stats_config()`、`get_default_unlocked_heads()`、`get_default_unlocked_tails()`。
  （default_unlocked_* 为 M2 T007 schema 的先行落地；T007 余下职责 = unlock_conditions
  重写为 v1 双条件。）
- **测试存档卫生（不可妥协）**：全部 L5 套件注入临时 save_path（`user://test_l5_*_tmp.json`）
  并测后删除——`test_l5_meta_save` 已按 M1 重写；`test_l5_unlocks/legacy/acceptance` 草稿已
  卫生化补丁（M2/M3/M4 各自重写卡接手）。生产存档绝不被测试触碰、绝不被依赖。
- `meta_save_system.gd` / `run_stats_tracker.gd` 已去 class_name（preload/duck-typing，
  ScriptingLeading C.8）；unlock/legacy/pickup 的 class_name 随各自重验收卡移除。

## L5 元成长 M2 事实（S3 M2，T006-T011，2026-06-11）

- **unlock_conditions v1 重写（T007，Designs §12.3 附录「v1 内容映射」）**：恰双条件——
  `reaction_kills_10`（reaction_kills ≥ 10 → head `bai_she` 白蛇）+ `floors_2`
  （floors_completed ≥ 2 → tail `lag_tail` 时滞尾）；`condition_type` 即 FR-016 冻结 stats
  字段名（UnlockSystem 直接以其为键查 stats，草稿手写映射表与 `survival_low_length` 别名
  已删）。草稿五条件（turns_200/reaction_kills_15/survive_60s_low_length/floors_3/
  enemies_50，指向 ungud/medusa/taotie/styx_tail/salamander）已移除——backlog.md 收容
  （salamander 改默认解锁）。display_name 与 snake_heads/snake_tails 内容池对齐，
  target_id 必须存在于内容池（test_l5_unlocks 数据互证断言钉住红线）。
- **JSON schema 增量（rewards 段）**：`rewards.pools.starter_build` 增 `head_bai_she` /
  `tail_lag` 两选项（追加在池尾，新档首 3 项不变——L3 既有 offer 行为零破坏）。
  这是解锁的生产数据通路：锁定时被过滤，解锁后可进 offer（无 offer 渠道的解锁 = 死内容）。
- **MetaGrowthRoot（T009，`systems/meta_growth/meta_growth_root.gd`）**：main.tscn 常驻节点
  （**GameWorldContainer 外**，跨 run 存续、世界重建不清）。`boot(save_path)` 显式装载
  MetaSaveSystem + `load_from_disk()`（生产缺省 `meta_growth.save_path`；可重复 boot 换档
  ——测试缝）；子节点 RunStatsTracker（run_ended 唯一发射点）+ UnlockSystem /
  LegacyStoneSystem `setup(meta_save)`。`attach_world(world)`（main._start_new_game 在
  `start_game()` 前调用）：duck-typed 接线 RunProgression.set_stats_tracker（M1 注入缝）+
  RewardFlow.set_unlock_query；L1/L2 验收场景无对应节点全部 no-op。
  **测试警示**：凡把 main.tscn 入树并驱动 `run_ended` 的套件必须先 `boot(临时路径)`，
  否则解锁/铸石落盘污染生产存档（state_stager 的 title/game_over 布景只读不写——
  这些状态不发 run_ended）。
- **解锁过滤（T010）**：`RewardFlowSystem.set_unlock_query(Callable)` 注入缝（口径同
  `ScaleRewardSystem.set_sampling_bias`）——`Callable(content_type, content_id) -> bool`；
  未注入全量回退（L3 既有测试零破坏）；v1 仅过滤 head/tail（鳞片不门控，Designs §12.3）；
  过滤后零选项走既有 FR-014 自动决议（合成 room_completed 保留，不死锁）。
  **Shop 核查结论（T010 check）**：ShopSystem 只上架**已装备**头/尾的下一等级升级
  （`_make_part_upgrade_items` 取 `get_active_head/tail`），从不 offer 新部件——
  能装备即已解锁，商店无需解锁过滤。
- **解锁 toast（T011，`ui/unlock_toast.gd`）**：kit chip 基座，`ui_layer = "toast"`
  （层矩阵 toast 可压 hud、同层 ≤1）；监听 `content_unlocked` 顶中显示「解锁 X」+ 组件级
  bounce，重复解锁原地更新（恒 ≤1 件），`run_started` 收起；main.gd `_ready` 创建挂壳层
  UILayer。停留/飞行编排归 S4。
- **game_over 结算数据通路（M2 卡，M3 T016 扩展）**：MetaGrowthRoot 缓存本局
  `content_unlocked` / `legacy_stone_created`，`run_ended` 时与冻结 stats 合并为
  `get_last_run_summary()`（`run_started` 清缓存）；game_over_screen
  `set_summary_source(root)`（main 接线）→ `show_results` 渲染统计/解锁/铸石 kit 文本行
  （`get_summary_lines()` 测试契约）。**时序事实**：GameManager（autoload）比
  RunProgression 先连 `snake_died`，`game_over` 先于 `run_ended` 抵达——show_results
  同步刷一次 + `call_deferred` 再刷一次拿到本局数据。
- 事件对照表增量：

| 信号 | payload | 发射方 | 监听方 |
|------|---------|--------|--------|
| `content_unlocked` | {content_type, content_id, display_name} | UnlockSystem（M2 ✅） | unlock_toast、MetaGrowthRoot（结算缓存） |
| `legacy_stone_created` | {description, highlight_type, display_name, bias_config, created_at} | LegacyStoneSystem（草稿保留，M3 重验收） | MetaGrowthRoot（结算缓存） |
| `run_ended` | FR-016 冻结契约 | RunStatsTracker.finalize_run（唯一） | UnlockSystem、LegacyStoneSystem、MetaGrowthRoot（M2 接线 ✅，root 汇总 handler 末位执行） |

- `unlock_system.gd` 已去 class_name；`legacy_stone_system.gd` / `pickup_system.gd` 的
  class_name 随 M3/M4 卡移除。`test_l5_acceptance` 草稿已补 v1 映射最小适配
  （turns_200→ungud 断言改 reaction_kills_10→bai_she，全量重写归 M4 T020）。

## L5 元成长 M3 事实（S3 M3，T012-T016，2026-06-11）

- **高光阈值 JSON 化（T013，FR-004）**：`meta_growth.legacy_stone_thresholds`
  （highlight_type 键 → 达标下限：high_kills 30 / complex_reaction 5 / near_death 2 /
  long_survival 3；缺键 = 该高光禁用，落 default「旅者」石）；ConfigManager 新 accessor
  `get_legacy_stone_thresholds()`。评估优先级固定 high_kills > complex_reaction >
  near_death > long_survival > default。`legacy_stone_system.gd` 已去 class_name。
- **`legacy_stone_selected` payload 修订（T013）**：`{stone_index, stone}`——stone 为完整
  dict（description/highlight_type/display_name/bias_config/created_at），消费方无需回查
  存档；选中即消耗（存档移除 + 落盘），越界选择零副作用零事件。
- **bias 消费链（T014，FR-015/SC-004）**：选中石 →
  `main._start_new_game(stone)` → `game_world.start_game(run_options)`（新缺省参数
  `{legacy_stone: stone}`，全部既有调用方零改动；l1/l2 验收场景 override 已同签名）→
  `_apply_legacy_stone_bias`：`stone.bias_config.scale_tag_weights` 经
  `systems/meta_growth/stone_bias.gd` 构造加权重排 Callable（scale 选项按
  ConfigManager.get_scale_tags 连乘 tag 乘数、head/tail 恒 1.0；按权重不放回抽样重排 =
  输入的置换；RNG 种子 = hash("run_seed:stone_bias") 定种子可复现）→ 注入
  `ScaleRewardSystem.set_sampling_bias`（S2 T005 既有钩子零改造）+
  `RewardFlowSystem.set_sampling_bias`（M3 新钩子，同口径；未注入保持 L3 first-N 池序）。
  **bias 生命周期恰一局**：每局 start_game 显式 set-or-clear（空石注入空 Callable 清除）；
  两系统新增 `has_sampling_bias()` 可观测。
- **StoneSelectScreen（T015，`ui/stone_select_screen.gd`，FR-012）**：kit modal
  （ui_modal 组 + ui_layer=modal，choice_card 横排石碑卡 ≤5 + 「轻装上阵」跳过；
  ←/→ 高亮环绕、1-5 直选、回车/空格确认、Esc 跳过、鼠标点卡；居中停靠 =
  reset_size + set_anchors_and_offsets_preset(CENTER, MINSIZE)，unlock_toast 同款）。
  **空石碑列表整屏跳过**：open() 返回 false 绝不闪现（裁定 #12，概念第二局登场）。
  公共契约：setup(legacy_system)/open/get_visible_stone_count/get_stone_labels/
  get_selected_index/get_skip_label_text/choose_stone_by_index/skip +
  `stone_select_finished(stone)` 信号（空 dict = 跳过）。
- **屏幕流提前落地（T015 范围修订，spec/presentation §7 已同步注记）**：
  `GameManager.GameState` 尾部追加 `STONE_SELECT`（既有 int 值不变）+
  `enter_stone_select()`；main.gd 开局分流 `_begin_run_flow()`——「开始」与
  「再来一局」（非验收模式）均先经选石（有石 → STONE_SELECT；空石直进 RUN）；
  T/Y 验收捷径与全部既有信号/流程保持。SUMMARY 枚举与仪式编排仍归 S4。
  新增 glyph `stone`（presentation.glyphs，石碑卡图标）。
- **结算数据通路（T016）**：`get_last_run_summary().stone` 为完整铸石 dict（与
  `legacy_stone_created` payload 同构），`run_started` 清缓存——M2 既有通路的
  M3 数据可达性断言收口（呈现编排归 S4 RunSummaryScreen）。
- **几何探测新增状态 `l5_stone_select`**（state_stager + test_xp_ui_geometry，共 9 状态）：
  临时档写 2 块假石 → main.tscn 壳层 + root.boot(临时路径) → 隐标题 + open()；
  teardown 按 ctx["temp_save_path"] 删临时档（存档卫生）。
- 事件对照表增量：

| 信号 | payload | 发射方 | 监听方 |
|------|---------|--------|--------|
| `legacy_stone_selected` | {stone_index, stone}（完整 stone dict，M3 修订） | LegacyStoneSystem.select_legacy_stone（StoneSelectScreen/AppFlow 驱动，M3 ✅） | 表现层（S4 仪式）/测试观测 |

## L5 元成长 M4 事实（S3 M4，T017-T021，2026-06-11，spec 003 封口）

- **PickupSystem 重写落地（`systems/events/pickup_system.gd`，game_world.tscn 常驻节点；
  US3 SHOULD，v1 = broken_eye ONLY——serpent_scale 配置 `enabled: false` 入 backlog.md）**。
  草稿三缺陷修复（plan.md 判决表）：
  - `_on_enemy_killed` 节点判型：enemy_def 是 **Enemy 节点**（duck-typed `enemy_type`，
    同 ShedskinSystem 口径，兼容 String/Dictionary 测试形态）——草稿当 Dictionary 判型 =
    生产零掉落死代码；
  - elite 判定走 `ConfigManager.get_enemy_type(...).is_elite`（草稿 `enemy_type != "elite"`
    字符串比对，该字面量不存在于配置——RoomDirector 精英房实际生成 `elite_*` 变体）；
  - **randf 顺序契约**：enabled → elite 判定 → 掷骰——非精英零 RNG 消耗（定种子可证）。
- **网格实体化（仿 food）**：`entities/pickups/pickup_entity.gd`（EntityType.PICKUP、
  cell_layer 0、不阻挡移动、颜色出自 `placeholder_color`）；掉落占用格 → **BFS 偏移
  最近空格**（spec Edge Case）；`enemy_killed` 派发时刚死的敌人仍占格——`try_drop_pickup`
  的 `exclude` 参数排除尸格，碎片落在击杀位；蛇头进入拾取（监听 `snake_moved.head_pos` +
  `collect_pickup_at(pos)` 直驱缝）。
- **携带/激活模型（Designs §9.4，激活路线 A/B 入 backlog）**：拾取 = 携带（active=false），
  携带效果即时生效——broken_eye `carry_effect: "enemy_intent"` → **DangerIndicator**
  监听 `pickup_collected/expired` 开关敌人意图显示（`enemy_action_decided` 最近一次移动
  决策方向 → 目标格标记；`is_intent_display_enabled()`/`get_intent_cells()` 测试契约）；
  携带倒数 `duration_rooms`（`room_completed` 递减，归零 `pickup_expired`
  reason=rooms_exhausted）；`activate_pickup` 幂等（active 字段 + `pickup_activated` =
  模型缝），**激活者免倒数、免层末清除**；FR-008：`floor_completed` 清未激活携带
  （reason=floor_transition）+ 地面残留；`room_entered` 清地面残留（房间重布景同口径）；
  `run_started` 全量重置。
- **PickupDisplay（`ui/pickup_display.gd`，kit chip 行）**：右上蜕皮 chip 下方 hud 层，
  每枚携带碎片一枚 chip（新 glyph `pickup` + 名称 + 剩余房数，激活者只显名称）；
  渐进披露（无携带整行隐藏）；`setup(pickup_system)` + EventBus 驱动刷新。
- 事件对照表增量（M4 全部 ✅）：

| 信号 | payload | 发射方 | 监听方 |
|------|---------|--------|--------|
| `pickup_dropped` | {pickup_id, instance_id, position（偏移后实际落点）, display_name} | PickupSystem | 表现层（S4）/测试观测 |
| `pickup_collected` | {pickup_id, instance_id, display_name, carry_effect, rooms_remaining} | PickupSystem | DangerIndicator（enemy_intent）、PickupDisplay |
| `pickup_activated` | {pickup_id, instance_id} | PickupSystem.activate_pickup | PickupDisplay；激活路线内容在 backlog |
| `pickup_expired` | {pickup_id, instance_id, reason: "rooms_exhausted"\|"floor_transition"} | PickupSystem | DangerIndicator、PickupDisplay |

- **JSON schema 增量**：`event_pickups.pickups.broken_eye.carry_effect: "enemy_intent"`、
  `serpent_scale.enabled: false`（v1 砍单，backlog.md）；`presentation.glyphs.pickup`
  （眼形 3 矩形）。数值零新增段（duration_rooms/drop_chance 沿用既有键）。
- **全环冒烟 `test_l5_full_loop.gd`（T019，SC-008）**：真实 main.tscn AppFlow + 临时
  save_path——run 1 新档（StoneSelect 整屏跳过）→ 真实事件喂入 30 反应击杀 →
  `snake.die()` 真实死亡出口 → `run_ended` 恰一次 + bai_she 解锁 + high_kills 石入档 +
  存档落盘 + 同路径新 MetaSaveSystem 实例重载（SC-002 跨进程代理）→ game_over 屏结算行
  → 「再来一局」→ StoneSelect 首登场 → 选石 → run 2 bias 双系统生效 + 选中即消耗 +
  解锁内容进 offer 并真实装备。
- `test_l5_acceptance.gd` 重写为修订版 spec SC-001..SC-008 逐条映射（全程临时 save_path）；
  `test_l5_pickups.gd` 重写为 T017 全量契约（含 game_world 接线 e2e：spawn_enemy_at
  精英 → take_damage 击杀 → 掉落 → 拾取 → 指示器/chip 行）。
- S3 验证基线：套件 `72/72`，断言 `4110/4110`，`STRICT PASSED`；user:// 零残留
  （生产存档未被任何套件触碰）。

## L1 战斗循环关键事实

- **吃敌人无消耗** — 蛇头碰敌人 = 直接吞噬，不扣长度；若蛇头与敌人携带异类状态则触发反应、双方状态清除
- **所有击杀方式均掉食物** — 蛇头吞噬、火光环、反应伤害
- **Per-Segment Status** — 每个 SnakeSegment 实现 StatusCarrier 接口，持有 `_statuses: Array[String]`（兼容 `carried_status` getter）
- **段对象持久化** — 蛇移动时所有段对象向前移动一格（不创建/销毁），状态自然跟随段走
- **空身躯防御早退** — `Snake.move()` 在 `body` 为空时直接 return（生命周期残留防御：销毁中的蛇在 queue_free 落地前仍连着 tick 信号）；仅剩蛇头的无身体倒计时态（`body.size() == 1`）照常移动（ScriptingLeading §3.1.3 步骤 0，回归测试在 test_t06_snake）
- **敌人攻击蛇身** — 敌人 P0 优先级，累计 3 次命中丢 1 段（hits_per_segment_loss=3）
- **双向状态转移** — 敌人攻击蛇段时双方状态互换/触发反应
- **敌人携带状态颜色** — 敌人携带 fire/ice/poison 时显示对应叠层颜色（fire=橙边框闪烁+overlay, ice=蓝overlay, poison=绿脉动overlay）
- **状态格永久存在** — L1 中无持续时间递减
- **同位异类互斥** — 放置状态格时已有不同类型 → 反应 + 双方消除
- **蛇基础颜色白/灰** — HEAD=0.95, BODY=0.78, TAIL=0.6 灰度
- **碾压（crush）已移除** — 蛇身段不再主动攻击敌人

## L2 架构决策

- **StatusCarrier 统一载体 + ReactionResolver 反应引擎（T27A）** ✅ 已实现
  - 蛇段/敌人/状态格统一实现 StatusCarrier 接口（`_statuses: Array[String]` + 兼容 getter）
  - CollisionHandler 统一处理 5 种碰撞类型，JSON `collision_rules` 驱动
  - ReactionResolver JSON 驱动反应规则（替代 3 处 `_get_reaction_id`）
  - `game_config.json` 新增 `collision_rules` 节
  - EventBus 新增 `status_added_to_carrier` / `status_removed_from_carrier` 信号
- **统一 Atom Chain** — 蛇头/蛇尾/蛇鳞三套系统统一使用 T25 Effect Atom System
- 复用 EffectChainResolver → TriggerManager → AtomExecutor 管线
- **EffectWindow 时间窗口框架（T27）** ✅ 已实现 — 为 Atom System 新增"持续 N tick"能力
  - 新增 EffectWindowManager（有状态管理器）+ open_window / if_in_window 原子
  - 窗口期内规则覆写（ignore_hit_counter / block_segment_loss 等）由各系统主动查询
  - 到期执行 on_expire 原子链，cancel_on 条件取消不触发到期链
  - 完全 JSON 配置，零代码扩展；新增 3 个 EventBus 信号
- **新增触发器 7 个（T28A）** ✅ 已实现 — 补全操作维度和资源维度
  - 高：on_length_change（长度增减）、on_turn（转弯）、on_near_death（濒死）
  - 中：on_streak（连杀）、on_enemy_approach（敌人靠近）、on_status_gained（获得状态）、on_tile_placed（状态格放置）
- **新增即时原子 4 个（T28B）** ✅ 已实现：modify_food_drop, direct_grow, steal_status, modify_hit_threshold；Snake.request_grow() 新增
- **SnakePartsManager + 蛇头链（T29）** ✅ 已实现
  - SnakePartsManager 管理蛇头装备/卸载，SnakePartData 兼容 TriggerManager duck typing
  - Hydra（九头蛇）：受击阈值-1、不掉食物、直接增长、窃取状态、L3回声咬
  - Bái Shé（白蛇）：击杀开无敌窗口、L2+反击冰冻、L3到期爆发状态
  - 新增 area_damage + burst_carried_status 原子（总数 57）
  - StatusEffectManager 持久修改器：hit_threshold / food_drop
  - Snake.take_hit() 集成无敌窗口查询
  - ConfigManager 新增 snake_heads 段 + get_snake_head()
- **蛇尾链（T30）** ✅ 已实现
  - Salamander（火蜥蜴尾）：段丢失后恢复窗口，L2+恢复时尾段获火，L3回复量+1
  - Lag Tail（滞后尾）：block_segment_loss 窗口 → 延迟段丢失，L2取消时减 hits_taken，L3蛇尾获冰
  - 新增 request_segment_loss + modify_hits_taken + cancel_window 原子（总数 60）
  - EffectWindow 新增 on_cancel 链：窗口被信号取消时执行
  - LengthSystem 集成 block_segment_loss 窗口规则查询
  - ConfigManager 新增 snake_tails 段 + get_snake_tail()
- **ScaleSystem 蛇鳞槽位（T31）** ✅ 已实现
  - ScaleSlotManager 管理 front/middle/back 三位置（最大 2/3/2 槽，初始 1/1/1）
  - 9 鳞片 × 3 级，全 JSON + Atom Chain 驱动
  - 前段：greedy_scale（食物掉落）、predator_scale（窃取+扩散状态）
  - 中段：flame_scale（火光环增强）、toxin_scale（毒蔓延加速）、frost_scale（攻击冷却）、phantom_scale（幻影尾段）
  - 后段：thorn_scale（击退）、regen_scale（概率增长）、retaliation_scale（反伤）
  - 新增 6 原子（总数 66）：modify_system_param, damage_attacker, knockback_attacker, knockback_with_damage, spread_status_to_segments, ice_wave
  - StatusEffectManager 新增 6 修改器：fire_aura_damage/range, poison_spread_bonus/tile_damage, attack_cooldown_bonus, phantom_tail_count
  - SegmentEffectSystem：曼哈顿距离火光环 + 毒格伤害
  - EnemyBrain：幻影尾段过滤
- 蛇鳞效果也走 Atom Chain，不再有独立的 Condition/Action 系统
- **邻接共鸣系统（T32）** ✅ 已实现
  - Tag-pair 驱动 + scale-pair override 混合架构
  - ResonanceManager 监听鳞片装备/卸载，自动计算邻接共鸣
  - 位置级邻接：front↔middle、middle↔back、同位置互邻；front↔back 不邻接
  - 11 个 tag-pair 共鸣：沸毒(fire+poison)、蒸腾(fire+ice)、冻疫(ice+poison)、炎棘(fire+physical)、冰刺(ice+physical)、毒棘(poison+physical)、幽焰(fire+void)、毒影(poison+void)、焚食(fire+recovery)、寒餐(ice+recovery)、铁壁(physical+physical)
  - 同 tag 不共鸣（physical 除外，铁壁）；多 tag 鳞片可触发多个共鸣
  - 新增 2 原子（总数 68）：apply_status_in_radius, place_tile_at_attacker
  - ConfigManager 新增 tag_resonances + scale_resonance_overrides 双向查找
  - EventBus 新增 resonance_activated / resonance_deactivated 信号
  - 发现机制：首次激活 is_new_discovery=true（预留 UI 提示）
- **全系统联调 + Build 测试面板（T33）** ✅ 已实现
  - Build 测试面板（B 键）：实时显示头/尾/鳞/共鸣/修改器/窗口状态
  - 热键装备：H=蛇头, J=蛇尾, F/G/K=前/中/后鳞, L=升级, 0=清空
  - game_world.cleanup()：修复重开游戏时 TriggerManager/修改器/窗口泄漏
  - main.gd：queue_free 前调用 cleanup 确保跨系统状态清理
  - 集成测试：修改器叠加、共鸣联动、清理正确性、配置一致性

## 敌人类型（L1）

| 类型 | 行为 | 攻击冷却 | 掉落食物 |
|------|------|----------|----------|
| wanderer | 随机移动，无视状态格 | 3 ticks | 2 |
| chaser | 追踪蛇身段，回避状态格 | 2 ticks | 3 |
| bog_crawler | 趋向毒液格，死亡留毒 | 4 ticks | 4 |

## 状态效果（L1，仅 fire/ice/poison）

| 状态 | 蛇段效果 | 状态格效果 |
|------|----------|-----------|
| fire | 火光环：相邻格敌人受火属性伤害（异类状态触发反应） | 踩入获火，蔓延 |
| poison | 毒蔓延：每个毒段每 3 tick 向随机邻格蔓延一格毒 | 踩入获毒 |
| ice | 冰防御：被攻击时攻击者获冰 | 踩入获冰 |

## 反应（L1，仅 3 种）

| 反应 | 组合 | 敌伤 | 蛇自伤 |
|------|------|------|--------|
| steam | fire+ice | 2 | 1 格 |
| toxic_explosion | fire+poison | 3 | 2 格 |
| frozen_plague | ice+poison | 0 | 0 |
