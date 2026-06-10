# AgentOps 入口

`AgentOps/` 是 GreedySnake 的会话无关 agent 控制面。任何新 agent 会话都必须把这里和项目源文档当作长期记忆，不依赖聊天历史。

## 启动顺序

1. 读取 `AGENTS.md`、`EnvPath.json`、`TechDocs/QuickReference.md`。
2. 读取本目录的 `CurrentState.md`、`Backlog.md`、`Runbook.md`、`Verification.md`。
3. 读取当前 feature 的 `.specify/specs/<feature>/spec.md`、`plan.md`、`tasks.md`。
4. 运行只读状态检查：`git status --short --branch` 和 `git log --oneline -5`。
5. 只处理 Orchestrator 派发的一张任务卡。
6. 完成后按 `HandoffTemplate.md` 留下交接信息。

## 当前默认

- 默认分支：`codex/001-l3-run-loop`
- 当前 feature：`.specify/specs/001-l3-run-loop/`
- 派发粒度：单任务卡
- L3 v1 目标：完整一局闭环，使用占位美术/UI，不扩展到 L4/L5

## 角色边界

- Orchestrator：派发任务、维护状态、触发验证和 review，不写 gameplay 代码。
- Implementer：按任务卡 TDD 实现，不自行扩大范围。
- Verifier：运行测试和错误扫描，记录证据。
- Reviewer：基于 diff、任务卡、设计文档审查，不依赖聊天上下文。
- Documentarian：同步 QuickReference、DailyLogs、README、AgentOps 状态。

