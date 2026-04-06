Generate today's daily development log. Follow these steps:

1. Get today's date in YYYY-MM-DD format.

2. Run `git log --since="today 00:00" --format="%H %s"` to get today's commits.

3. Run `git diff --stat HEAD~$(git rev-list --count --since="today 00:00" HEAD)..HEAD` for changed file stats (if commits exist).

4. Create `F:/GreedySnake/DailyLogs/YYYY-MM-DD.md` using this template (write in Chinese):

```markdown
# YYYY-MM-DD 开发日志

## 本日工作

### [根据 commit 内容分组的子标题]
- 具体完成的事项（从 commit message 和 diff 推断）

## 技术决策记录

| 决策 | 原因 |
|------|------|
| [如有] | [如有] |

## 提交记录

| Commit | 内容 |
|--------|------|
| [短hash] | [commit message] |

## 下一步
- [根据项目上下文推断]
```

5. If `$ARGUMENTS` is provided, incorporate it as additional context for the log.

6. Do NOT read old daily logs for format reference — use the template above directly.
