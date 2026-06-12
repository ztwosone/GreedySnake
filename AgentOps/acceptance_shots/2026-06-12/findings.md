# Layer C 截图评审 — 2026-06-12（S4 Gate / 004 Phase P T107）

装置：`Project/AcceptanceShots/` 经 `Tools/run_acceptance_shots.ps1` 带窗 1280×720；
9/9 镜头捕获（S4 新增 08 总结屏 / 09 传承石选择屏）。评审口径 = presentation_design.md §12.2。

## 逐张评审

| # | 镜头 | 结论 | 说明 |
|---|------|------|------|
| 01 | title | PASS | display 级标题 + 角括号框菜单（开始/退出）；构图居中、留白干净；生产档无石碑故无「传承石」项（条件项行为正确） |
| 02 | l3_run_start | PASS | S4 全要素入镜：左上楼层小地图（当前房高亮）+ 楼层进度面板、顶中房间横幅两段（横幅+chip 行，世界级布景横幅常驻属 Phase F 静态兼容）、左下 HUD chip、底中 Build 状态条（空槽虚框）；蛇/敌/食物色块可辨 |
| 03 | l4_scale_pending | PASS | 鳞片三选一模态（glyph + 名称 + 位置/等级 + 底缘色条）+「放弃全部 +6 蜕皮」次选项 + 右上蜕皮 chip（◆3）；模态唯一 |
| 04 | l4_shop_open | PASS | 商店侧栏（4 项货架 + 价格 chip + 余额 12）+ 退店提示行；小地图显示已完成房（暗化+中心点）；Build 条已装格可见 |
| 05 | l4_floor_reward_slot | PASS | Boss 结算第一段：前/中/后三槽位卡（slot_empty glyph）+ 标题「Boss 结算」 |
| 06 | l4_floor_reward_choice | PASS | 第二段 3 选 1（类别 + 具体效果 + 底缘色条）；三卡全「扩展」为零装备布景下的替补行为（spec Edge Case，S2 已裁定不阻塞） |
| 07 | l4_multifloor_midrun | PASS | 楼层 2 主题敌池色变可辨；**S2 登记顺手项「GO! 过渡字定格」已修**（GameTransition 入 settle 语义）——同时消除了此前全部局内镜头的黑罩残留偏暗，本批画面通透 |
| 08 | summary_screen（S4 新增） | PASS | 总结屏：得分/最佳 + 死因中文映射（**「死因：吞到了自己」**，布景死因键已换真实 hit_self）+ 再来一局/回标题双出口；角括号框居中 |
| 09 | l5_stone_select（S4 新增） | PASS | 两石碑卡（glyph + 名称 + 描述 + 金色底缘）+「轻装上阵」；SUSPECT（轻微）：第二张卡描述两行换行略压底缘色条，几何探测在容差内放行，观感可接受 |

## 总评

- **FAIL：0**（SC-004 达标，Gate 可过机器层）。
- SUSPECT 不阻塞 ×2：06 三卡同类别（既有 Edge Case 行为）、09 双行描述换行紧凑（容差内）。
- 遮字测试（§12.2）：02/04/07 仅凭色彩与 glyph 可 1 秒辨认房型（战斗红/商店蓝/意图色小地图）。
- 全图无灰框占位、无英文 debug 文案、palette 合规目视抽查通过。
- 顺手修复（本批落地）：GameTransition settle 语义（GO! 定格 + 黑罩残留）、
  布景死因真实键（self_collision → hit_self）。
