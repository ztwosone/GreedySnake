Run the Godot test suite in headless mode. Execute this exact command:

```bash
"F:/GodotMCP/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64_console.exe" --headless --path "F:/GreedySnake/Project" Test/test_runner.tscn 2>&1 | grep -E "^(  FAIL|ALL PASSED|FAILED:)" | head -30
```

Report the result concisely:
- If ALL PASSED: just say the count (e.g. "1167/1167 pass")
- If FAILED: show the summary line and each FAIL line, then suggest investigating
- Do NOT analyze passing tests or show warnings
