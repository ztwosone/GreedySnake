# 当前状态

**更新时间**：2026-05-19  
**当前分支**：`codex/001-l3-run-loop`  
**当前 feature**：`.specify/specs/001-l3-run-loop/`  
**当前阶段**：L3 v1 T001-T026 完成，已具备占位 UI 可视化验收路径

## 实现事实

- L0 已完成：基础移动、长度、食物、基础循环。
- L1 已完成：战斗循环、per-segment status、敌人 AI、T25 Atom System。
- L2 已完成：蛇头/蛇尾/蛇鳞统一 Atom Chain、共鸣、Build 测试面板。
- L2.5 已完成：Virtual Player 测试基础设施。
- L3 Foundation 已完成配置骨架、事件契约、RunState 生命周期和确定性 FloorMap v1 短路径。
- L3 US1 已完成：进入战斗房、展示单一房间意图、监听既有 `enemy_killed` 推进目标、达成 JSON 配置的 `required_count=3` 后单次完成房间；`required_count` 与 `enemy_count` 保持一致。
- L3 US2 已完成：进入配置指定的 `reward` 房后展示最多 3 个 Build 奖励，玩家选择后通过既有 `SnakePartsManager` / `ScaleSlotManager` 应用 head/tail/scale，并完成奖励房。
- L3 US3 已完成：固定 v1 路径支持房间完成后记录 completed、解锁下一房间、由 `advance_to_room()` 进入已解锁房间，并在 cleanup/restart 时清空楼层推进状态。
- L3 US3 reviewer fix 已完成：未解锁/非当前房间的完成事件会被忽略，RoomFlow 会跟随 `room_entered` 同步目标，`rest` / `endpoint` 通过 JSON `auto_complete_on_enter` 支持 v1 固定路径闭环。
- L3 US4 已完成：endpoint 完成后发出 `floor_completed` 与 `run_victory`，GameManager 在 PLAYING 状态收到胜利后进入 existing game over flow，蛇死亡会同步 L3 run outcome 为 `death`。
- L3 smoke 已完成：真实 `game_world.tscn` 可通过 `FloorProgressPanel` 的 Next 请求和 `RewardChoicePanel` 的奖励选择，从 `combat_01` 跑到 `endpoint_01` 并得到 victory。
- `RoomIntentPanel`、`RewardChoicePanel` 和 `FloorProgressPanel` 都是功能占位 UI，当前只验收信息清晰、状态可辨、交互可完成。
- L3 子节点接入对继承的 L1/L2 验收场景安全：`game_world.gd` 使用 `get_node_or_null()`，缺失 L3 子节点不会阻断旧场景进树。
- cleanup 已覆盖 L3 state、reward state、TriggerManager 场景引用和 VFX 层失效重建。

## 当前阻塞项

- 无阻塞。
- 无 L3 阻塞。下一步建议进入人工可视化验收与 L3 reviewer pass；如验收通过，再开 L4/L5 设计，不在 L3 v1 继续加复杂度。

## 最近验证基线

- 普通测试入口：`Project/Test/test_runner.tscn`
- 当前普通汇总：`1831/1831` 断言通过。
- 严格验证入口：`$env:GODOT_DISABLE_CRASH_HANDLER="1"; powershell -ExecutionPolicy Bypass -File Tools/run_tests_strict.ps1`
- 最近严格结果：`STRICT PASSED: no unallowed Godot error output detected.`
- 注意：本机 strict 测试必须设置 `GODOT_DISABLE_CRASH_HANDLER=1`，不要给 Godot 追加 `--disable-crash-handler` 参数。

## 下一张建议任务

Orchestrator 派发 L3 visual acceptance / reviewer 任务。任务包必须要求：

- 从主场景启动一局，确认占位 UI 能看懂当前房间、奖励选择、楼层进度和胜利结果。
- 验收只看信息清楚、状态可辨、交互可完成，不要求正式美术。
- 若发现体验阻塞，优先作为 L3 fix；若只是内容/表现打磨，进入 L4+ 或 presentation backlog。
