# 验证门禁

## 普通测试

```powershell
& "F:/GodotMCP/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64_console.exe" --headless --path "F:/GreedySnake/Project" Test/test_runner.tscn
```

## 严格测试

```powershell
$env:GODOT_DISABLE_CRASH_HANDLER="1"; powershell -ExecutionPolicy Bypass -File "F:/GreedySnake/Tools/run_tests_strict.ps1"
```

严格测试会扫描 Godot 输出：

- `SCRIPT ERROR` 一律失败。
- `FAILED` 一律失败。
- `ERROR:` 默认失败，除非在脚本 allowlist 中明确豁免。

当前 allowlist 仅用于两类已知测试噪声：

- 负向测试故意触发的未知 AtomRegistry 原子。
- Godot headless 退出期偶发的 lambda capture 清理日志。
- Godot headless 退出期的 TextServer/RID/resource teardown 泄漏日志。

本机必须在启动 Godot 前设置 `GODOT_DISABLE_CRASH_HANDLER=1`；不要给 Godot 追加 `--disable-crash-handler` 参数。若未设置环境变量，strict runner 会失败退出，避免弹出 Windows 原生崩溃对话框。

## 任务级门禁

- 测试必须先 Red，再 Green。
- 新增数值必须进入 JSON。
- 系统间通信必须通过 EventBus。
- 改设计或代码后必须同步 `TechDocs/QuickReference.md`。
- 涉及 lifecycle 的任务必须覆盖重开游戏、cleanup、全局单例残留。

## L3 user story 门禁

- 每个 user story 必须能独立验证。
- 每个房间只承载一个主要意图。
- 占位 UI 必须能完成选择和反馈。
- VirtualPlayer smoke run 必须能覆盖核心路径。
