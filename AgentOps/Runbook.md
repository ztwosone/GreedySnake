# AgentOps Runbook

## Orchestrator 派发循环

1. 读取 `AGENTS.md`、`EnvPath.json`、`TechDocs/QuickReference.md`、`AgentOps/CurrentState.md`。
2. 读取当前 feature 的 `spec.md`、`plan.md`、`tasks.md`。
3. 从 `tasks.md` 中选择最高优先级、前置已完成、未勾选的单任务卡。
4. 生成任务包，必须包含：
   - feature id 和 task id
   - 目标和成功标准
   - 必读文档
   - 允许修改范围
   - 必须先写的失败测试
   - 必须运行的验证命令
   - 需要同步的文档
5. 派给 Implementer。
6. 完成后触发 Verifier 与 Reviewer。
7. 通过则更新 `CurrentState.md` 并派下一张；失败则派 fix 任务。

## Implementer 执行循环

1. 只读取任务包和列出的文档。
2. 先写失败测试，确认 Red。
3. 做最小实现，确认 Green。
4. 只做必要重构，避免额外玩法。
5. 运行普通测试和严格测试。
6. 同步文档和 handoff。
7. commit 格式：`[L3-001-Txxx] {任务名}`。

## Verifier 验证循环

1. 运行 `Tools/run_tests_strict.ps1`。
2. 记录普通断言汇总和严格错误扫描结果。
3. 检查 `TechDocs/QuickReference.md`、SpecKit `tasks.md`、AgentOps 状态是否同步。
4. 将证据写入 handoff。

## Reviewer 审查循环

1. 查看任务 commit 的 diff。
2. 对照任务卡、spec、plan、AGENTS、constitution。
3. 检查 TDD、EventBus、JSON 配置、生命周期清理。
4. 检查玩法设计是否通过深度/轻认知门禁。
5. 输出 `PASS` 或 `BLOCKED`，blocking 项必须可执行。

## Gameplay 设计门禁

- 深度：新机制必须能和蛇身状态、敌人、Build、共鸣或房间流程产生组合关系。
- 轻认知：单任务不得一次引入多个玩家必须理解的新概念。
- 渐进暴露：新规则先在低压场景出现，再进入混合战斗。
- 可读反馈：颜色、位置、状态图标或简单 UI 必须能解释当前发生了什么。
- 可回退：复杂机制必须能用配置禁用或降级。

## 美术/UI 占位政策

- 美术/UI 不阻塞玩法验证。
- L3 v1 可使用色块、文本标签、简单图标、调试面板。
- 新系统必须保留表现接口，后续可替换成正式资产。
- 验收只检查信息清楚、状态可辨、交互可完成。

