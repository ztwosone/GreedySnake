# Implementation Plan: 程序化美学与游戏手感

**Spec**: `spec.md` | **Design**: `Designs/Interactive/presentation_design.md`

## 技术方案要点

### Phase F（S1，本期）

- **`ui/kit/`**（全部 `extends Control`/`RefCounted`，零编排）：
  - `theme_builder.gd`（RefCounted）：从 `presentation.palette/typography` 构建 `Theme`
    （StyleBoxFlat 面板底、字号、字色），暴露 `build() -> Theme` 与
    `get_contrast_pairs() -> Array`（fg/bg/role 三元组，供对比度断言）。纯函数式，可单测。
  - `kit_panel.gd`（基类）：角括号框绘制（_draw 四角 L 形）+ 出生分组/元数据/`settle()`。
  - `glyph.gd`：按 `presentation.glyphs[id]` 程序绘制 ≤4 矩形。
  - `choice_card.gd` / `banner.gd` / `chip.gd`：组件态（normal/hover/press/disabled/selected）。
- **ConfigManager**：`get_presentation_config()` + `get_palette_color(token) -> Color`
  + `get_motion()/get_typography()/get_acceptance()` accessor。
- **VFXManager**：默认参数全部改读 `presentation.motion/game_feel`；新增
  `vfx_invoked(fx_name, args)` 仪表信号（每个公共方法首行 emit）；新增
  `shatter_at(pos, color, n)`、`ring_at(pos, color)`、`fly_to_hud(from_world, to_control, color)`。
- **TickManager**：`manual_mode: bool` + `step_once() -> bool`（与 `_on_timer_timeout`
  同函数体；`is_ticking==false` 时返回 false 不发 tick）。
- **L3 面板迁移**：room_intent/reward_choice/floor_progress 三面板 + title_screen/
  game_over_screen/hud 换 kit 渲染，**保留全部公共 API 与 getter**（既有 L3 测试不改断言
  语义，只跟随视觉结构调整取值方式）。
- **`Project/Test/experience/`**：experience_recorder / tick_driver / ui_actor /
  state_stager / ui_settle / ui_geometry_probe + 两个套件
  `test_xp_ui_geometry.gd`、`test_xp_contracts_l3.gd`。

### Phase P（S4，后期）

CeremonyLayer 编排、AppFlow 四态、SFXForge/AudioManager、reason-token 暂停、
hint_system、触发表全量、Layer C AcceptanceShots 装置。详见设计文档 §7-§10。

## 架构决策记录

- **单场景 AppFlow**（不切场景）：autoload 状态存续、headless 可测、复用已验证 cleanup 管线。
- **Theme 运行时构建**而非 .tres：保持 JSON 单一事实源 + 可单测。
- **shatter 色块碎片优先于 GPUParticles2D**：契合色块美学、headless 安全、可命令层断言。
- **契约表与运行时绑定共用 `presentation.game_feel.triggers`**：表即代码，文档不漂移。
- **kit 出生带验收钩子**（分组/元数据/settle）：事后翻新成本远高于出生自带。

## 风险与对策

- L3 面板迁移破坏既有测试 → 迁移卡按"先跑旧测试红线确认范围→迁移→旧测试回归"执行；
  getter 语义不变。
- 几何探测误报 → 只测沉降态 + `ui_layer` 矩阵 + 显式 truncate 声明（设计文档 §12.1）。
- hud.gd 等动态创建 UI 与 kit 并存期 → Phase F 允许混合，Gate 标准是"无调试观感"，
  hud 元素逐个换 kit 样式。
