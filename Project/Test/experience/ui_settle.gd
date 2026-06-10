extends RefCounted
## 沉降工具（SpecKit 004 T009，设计文档 §12.1 "沉降态探测"）：
## 几何探测前把全部 ui_kit 组件的追踪 Tween 快进到终态（kit_panel.settle() 契约）。
## 非套件 harness 文件：不得命名 test_*.gd、不得放进 Test/cases/。


static func settle_all(tree: SceneTree) -> int:
	## 返回实际 settle 的节点数（套件可断言覆盖面）
	var settled: int = 0
	for node in tree.get_nodes_in_group("ui_kit"):
		if is_instance_valid(node) and node.has_method("settle"):
			node.settle()
			settled += 1
	return settled
