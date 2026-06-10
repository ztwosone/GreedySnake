# Feature Specification: 程序化美学与游戏手感（表现层）

**Feature Branch**: `004-presentation-experience`
**Created**: 2026-06-11
**Status**: Phase F in progress
**Design Source**: `Designs/Interactive/presentation_design.md`（「网格信号」，source of truth）

## 概述

把已验证的系统堆栈变成「打开就能感受到设计意图的作品」：统一几何设计语言（零外部美术）、
完整屏幕流程（标题→局→死亡/胜利仪式→总结→元成长→再来一局）、游戏手感（tween/震屏/
hitstop/色块碎片/程序化音效），以及配套的体验验收基建（契约层/几何层/视觉评审层）。

分两期交付：**Phase F（表现内核，Stage S1）** 在 L4/L5 重验收之前落地，保证后续所有新
UI 一次成型；**Phase P（体验完成层，Stage S4）** 在系统全部就位后做编排与打磨。

## User Stories

### US1 (P1, Phase F) — 统一设计语言与 UI 内核

玩家看到的每一块界面都来自同一套设计语言：角括号框、语义色板、字号阶梯、程序绘制 glyph。

**验收场景**：
1. F5 启动后，标题屏/HUD/房间面板/奖励面板/楼层面板/结算屏全部使用 kit 组件渲染，
   无灰色默认 PanelContainer、无设计语言外的样式。
2. `presentation.palette/typography/motion/layout` 全部来自 JSON；改 JSON 色值，
   重启后全 UI 变色，不改任何代码。
3. kit 组件出生即带分组/`ui_layer` 元数据/`settle()`；组件本身零编排
   （仅 hover/press/disabled 态）。
4. debug UI（debug_panel/event_log_panel/kill_feed/build_test_panel）收进
   `presentation.debug_ui` 开关，默认关闭，豁免迁移。

### US2 (P1, Phase F) — 体验验收基建（Layer A 契约 + Layer B 几何）

体验质量可被机器验收：事件→反馈契约、UI 几何可读性随严格门禁每次运行。

**验收场景**：
1. `Project/Test/experience/` 提供 ExperienceRecorder（四通道时间线）、TickDriver
   （manual_mode 步进 + 模态感知）、ScriptedUIActor（playbook 驱动面板公共 API）、
   StateStager（典型状态装配）、UIGeometryProbe（几何五项+对比度）。
2. TickManager 提供 `manual_mode` + `step_once()` 测试缝（pause 期间步进无效）；
   VFXManager 提供 `vfx_invoked` 仪表信号。
3. L3 既有流程的首批契约入库：模态唯一、reward 流 ui 变化、time-to-first-choice。
4. 几何探测覆盖迁移后全部 L3 面板典型状态，沉降态探测，零误报放行（白名单走
   `ui_layer` 矩阵与 `ui_allow_truncate` 显式声明）。

### US3 (P2, Phase P) — 屏幕流程与仪式

完整的局外流程与死亡/胜利仪式（见设计文档 §7）。

**验收场景**：
1. AppFlow 四态（TITLE/STONE_SELECT/RUN/SUMMARY）由 GameManager.GameState 驱动；
   石碑列表为空时 STONE_SELECT 整屏跳过。
2. 死亡仪式：hitstop→逐段消散→去饱和→dim→死因中文一行→总结屏；tick 脉搏线随消散渐灭。
3. 局后总结：统计 stagger 滚入→解锁卡→石碑卡→按钮；与本局 `run_ended.stats` 一致。
4. T/Y 验收捷径保留于 debug 开关后。

### US4 (P2, Phase P) — 局内体验与 Game Feel

设计文档 §8 局内体验 + §9 触发表 MUST #1-8 全部落地。

**验收场景**：
1. 房间意图横幅→chip 两段式；楼层小地图；选择仪式（pause/dim/三卡/飞行）；
   蜕皮 chip 飞行粒子；Build 状态条 + 共鸣连线。
2. MUST 触发表逐条经 Layer A 契约验证；强度排序（丢段>受击）数值断言通过。
3. TickManager reason-token 暂停；hud 手动暂停迁移；test_t03 扩展通过。

### US5 (P2, Phase P) — 程序化音频

SFXForge + AudioManager（设计文档 §10），SFX-only。

**验收场景**：
1. boot 时按 JSON 合成全部音色；MUST 事件均有音效；50ms 防重。
2. `audio.enabled=false` 时游戏完整可玩、全部契约仍绿。
3. headless 测试下零 stderr 噪声。

### US6 (P3, Phase P) — 认知轻度引导

hint_system 首次事件 caption（设计文档 §8.8），≤1 概念/房间，已见列表入 meta 存档。

## Functional Requirements

- FR-001: 所有表现层数值/颜色/时长来自 `presentation` JSON 段（宪法对齐）。
- FR-002: 表现层只监听 EventBus / 调用注入系统公共方法，不驱动游戏状态。
- FR-003: kit 组件零编排；编排归 Phase P CeremonyLayer。
- FR-004: 仪表信号挂各自单例（vfx_invoked/sfx_invoked），不挂 EventBus。
- FR-005: 重特效与音频均可 JSON 禁用。
- FR-006: 暂停采用 reason-token 集合语义（Phase P）。
- FR-007: Layer A/B 随严格门禁每次运行；Layer C 截图评审在 Stage Gate 运行。

## Success Criteria

- SC-001: F5 全流程无调试观感（Phase F 范围为 L3 流程，Phase P 范围为全循环）。
- SC-002: 几何探测在全部典型状态零违规；对比度全部达标。
- SC-003: MUST 触发表 8/8 契约绿；关音频契约仍绿。
- SC-004: Layer C findings 中 FAIL 项清零后方可过 Gate。
- SC-005: Gate-H 人工终审（S4/S5）通过：30 秒上手、丢段体感重于受击、5 秒说出死因。
