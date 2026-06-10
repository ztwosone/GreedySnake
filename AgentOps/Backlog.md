# AgentOps Backlog

## P0 治理前置

- [x] 同步 README 与 QuickReference 的阶段状态。
- [x] 建立严格测试包装脚本，扫描 Godot `SCRIPT ERROR` / 未豁免 `ERROR` / `FAILED`。
- [x] 补齐测试框架 `assert_false`。
- [x] 修复 `ScriptedBrain.setup()` typed array 参数不匹配。
- [x] 将旧 `Tasks/AgentWorkflow.md` 标注为 L0 历史流程，并指向 AgentOps。
- [x] 创建 L3 完整一局 SpecKit 初始文档。

## P1 L3 启动

- [ ] Orchestrator 派发 `001-l3-run-loop` 的 `T001`。
- [x] Verifier 建立严格测试脚本并清理运行期历史错误输出。
- [ ] Reviewer 检查 L3 spec/plan/tasks 是否满足深度/轻认知门禁。

## P2 后续治理

- [ ] 把严格测试脚本接入 `/test` 或 ship 流程。
- [ ] 为每次 handoff 建立 `AgentOps/Handoffs/` 记录目录。
- [ ] 将旧 L0 AgentWorkflow 中仍有价值的 prompt 迁移为 L3 通用模板。
