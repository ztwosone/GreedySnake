# Code Review 模板

> 用于 Opus 级 agent 对低 tier agent 提交到 main 分支的 commit 进行 review。

---

## 工作流

```
main ── [L0-T01] ── review ── [L0-T02] ── review ── ... ── [L0-T11] ── review
```

1. Sonnet/Haiku 在 main 上完成任务，提交 commit（格式：`[L0-T{xx}] {任务名}`）
2. Opus 运行 `git diff HEAD~1` 查看最新 commit 改动，执行 review
3. 通过 → 继续下一个任务；打回 → 原 agent 修复后再 commit，Opus 再 review

---

## Review 指令（直接作为 prompt 使用）

将 `{xx}` 替换为任务编号后发送给 Opus：

```
你是一个 Godot 4.6 + GDScript 项目的 Code Reviewer。

请 review main 分支最新 commit 的改动。

### 你需要做的事

1. 运行 `git diff HEAD~1` 查看改动
2. 阅读对应的任务描述：`Tasks/L0/TaskPool/Task_L0_{xx}.md`
3. 阅读技术文档：`TechDocs/ScriptingLeading.md` 中相关章节
4. 按以下维度逐项检查

### Review 检查维度

#### A. 任务完整性
- [ ] 任务描述中「需要创建的文件」是否全部创建
- [ ] 任务描述中「需要修改的文件」是否正确修改
- [ ] 验收标准是否全部满足

#### B. 架构合规性
- [ ] 是否遵循 ScriptingLeading.md 的目录结构
- [ ] 是否遵循命名约定（snake_case 文件名、PascalCase 类名等）
- [ ] 系统间是否通过 EventBus 通信（无直接引用其他系统）
- [ ] GridEntity 子类是否正确使用 place_on_grid / remove_from_grid

#### C. GDScript 4.x 正确性
- [ ] 使用 4.x 语法（@onready, @export, typed arrays, -> 返回值）
- [ ] signal 声明语法正确：signal name(param: Type)
- [ ] 枚举引用正确：Constants.EntityType.FOOD
- [ ] 无已废弃的 3.x API 调用

#### D. 事件契约
- [ ] 发射的事件名与 EventBus 声明一致
- [ ] 事件参数 Dictionary 的 key 与文档约定一致
- [ ] 该监听的事件都已 connect
- [ ] 无遗漏的事件发射点

#### E. 边界安全
- [ ] 越界坐标是否有安全检查
- [ ] 空数组 / null 返回值是否有防护
- [ ] queue_free() 前是否先 remove_from_grid()
- [ ] 无潜在的内存泄漏（孤立节点、未释放引用）

### 输出格式

## Review 结果：✅ 通过 / ❌ 打回

### 各维度评分
| 维度 | 结果 | 备注 |
|------|------|------|
| A 任务完整性 | ✅/❌ | ... |
| B 架构合规性 | ✅/❌ | ... |
| C GDScript 正确性 | ✅/❌ | ... |
| D 事件契约 | ✅/❌ | ... |
| E 边界安全 | ✅/❌ | ... |

### 必须修改（Blocking）
1. ...

### 建议修改（Non-blocking）
1. ...

### 可选优化
1. ...
```
