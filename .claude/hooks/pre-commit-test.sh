#!/bin/bash
# Pre-commit hook: run Godot tests before allowing git commit
# Exit 0 = allow, Exit 2 = block

RESULT=$("F:/GodotMCP/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64_console.exe" \
  --headless --path "F:/GreedySnake/Project" Test/test_runner.tscn 2>&1 | \
  grep -E "(ALL PASSED|FAILED:)" | tail -1)

if echo "$RESULT" | grep -q "ALL PASSED"; then
  echo "$RESULT" >&2
  exit 0
else
  echo "BLOCKED: Tests failed. Fix before committing." >&2
  echo "$RESULT" >&2
  exit 2
fi
