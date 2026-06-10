# 当前状态

**更新时间**：2026-06-10
**当前分支**：`chore/stage0-stabilization`（S0 完成后合 `main`）
**当前 feature**：S1 起为 `.specify/specs/004-presentation-experience/`（待创建）
**当前阶段**：S0 稳定化完成；下一步 S1（体验设计文档 + 表现内核 + 验收基建）

## 阶段路线图（已批准计划，全文见会话计划文件）

```
S0 稳定化 ✅ → S1 体验设计文档+表现内核(004前半) → S2 L4 重验收(spec 002)
→ S3 L5 元成长(spec 003) → S4 体验完成层(004后半) → S5 整段验收封板
```

阶段目标：结束时项目是「打开就能感受到设计意图的作品」——全循环（L3+L4+L5）+
程序化美学与游戏手感（零外部美术）+ 编辑器 F5 可玩交付。

## 实现事实（S0 后基线）

- L0–L2.5：已提交完成（详见 QuickReference）。
- L3 v1：完成且已提交（commit `cace804`，SpecKit 001 26/26）。
- L4/L5：2026-06-05 草稿已提交在库（commit `02cdabf`），**零场景集成、任务 0 勾选**，
  已知缺陷已在提交信息和阶段计划中归档（鳞片幻影二次 offer、买槽 no-op、难度误测、
  拾取无实体、enemy_def 判型、PCG 无 seed）。S2/S3 逐卡 keep/adapt/rewrite。
- 测试基建：runner 假绿根因已修（can_instantiate 守卫 + 套件数核对 + await）；
  严格门禁前置 `--import`；preload 约定入 ScriptingLeading 附录 C.8。
- 历史教训（已记录）：HEAD `ea30586` 的套件本已损坏（test_t33 调用当时不存在的
  assert_false）；2026-06-05 的 "ALL PASSED 758/758" 是 runner 中断后的假绿。
- 安全快照：`snapshot/2026-06-10-raw-worktree`（草稿原始状态，永不合并）。

## 当前阻塞项

- 无阻塞。

## 最近验证基线

- 普通测试：`2346/2346` 断言通过，套件 `56/56`。
- 严格测试：`STRICT PASSED`（2026-06-10）。
- 入口与注意事项不变（GODOT_DISABLE_CRASH_HANDLER=1，勿加 --disable-crash-handler）。

## 下一张建议任务（S1 开卡）

1. **先写设计文档** `Designs/Interactive/presentation_design.md`（「网格信号」美学宣言、
   palette/形状/字体/动效/空间体系、屏幕流程、Game-Feel 触发表、SFXForge 音色规格、
   认知轻度引导规则、手动验收清单三分法）——设计先行红线。
2. 创建 `.specify/specs/004-presentation-experience/`（spec/plan/tasks，tasks 分
   Phase F=S1 / Phase P=S4）。
3. 实现 Phase F：`ui/kit/`（theme_builder/panel_frame/glyph/choice_card/banner/chip，
   组件出生带分组+ui_layer 元数据+settle()）、`presentation` JSON 段 + accessor、
   VFXManager JSON 化 + `vfx_invoked` 仪表信号、L3 面板迁移、debug UI 收进开关。
4. 体验验收基建 Layer A+B：`Project/Test/experience/`（ExperienceRecorder/TickDriver/
   ScriptedUIActor/StateStager/UIGeometryProbe）+ TickManager `manual_mode/step_once()`
   测试缝 + 首批契约 + L3 面板几何探测。

S1 Gate-A：F5 全流程统一设计语言；L3 各状态 geometry probe 绿；严格门禁绿。
S1 Gate-H：5 分钟设计语言裁定（人工）。
