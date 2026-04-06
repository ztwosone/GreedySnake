Commit and push workflow. Follow these steps exactly:

1. Run the test suite:
```bash
"F:/GodotMCP/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64_console.exe" --headless --path "F:/GreedySnake/Project" Test/test_runner.tscn 2>&1 | tail -20
```
If tests fail (output contains "FAILED"), STOP and report. Do not commit.

2. Run `git status` and `git diff --stat` to see changes.

3. Stage all relevant changed files. Exclude `.claude/settings.local.json` and any `.tmp` files.

4. Commit with message. If `$ARGUMENTS` is provided, use it as the commit message. If not, generate a concise message from the staged changes following the project's commit style (see `git log --oneline -5`). Always append the co-author line:
```
Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```
Use HEREDOC format for the commit message.

5. Push to origin.

6. Report: commit hash, files changed count, test count. Be concise — one or two lines.
