class_name EffectChainResolver
extends RefCounted
## JSON 配置 → EffectChain 解析器
## 将 game_config.json 中的效果定义转换为运行时 EffectChain。

var _registry: AtomRegistry


func _init(registry: AtomRegistry = null) -> void:
	_registry = registry


## 解析单个效果定义 → EffectChain
func resolve(def: Dictionary) -> EffectChain:
	var chain := EffectChain.new()

	# 触发器
	chain.trigger = def.get("trigger", "on_applied")
	chain.trigger_params = {}
	if def.has("interval"):
		chain.trigger_params["interval"] = float(def["interval"])
	if def.has("layer"):
		chain.trigger_params["layer"] = int(def["layer"])
	if def.has("threshold"):
		chain.trigger_params["threshold"] = int(def["threshold"])
	if def.has("range"):
		chain.trigger_params["range"] = int(def["range"])
	if def.has("streak_timeout"):
		chain.trigger_params["streak_timeout"] = int(def["streak_timeout"])

	# 概率
	chain.chance = float(def.get("chance", 1.0))

	# 范围模式
	chain.pattern = def.get("pattern", "self")
	chain.pattern_params = {}
	if def.has("radius"):
		chain.pattern_params["radius"] = int(def["radius"])
	if def.has("count"):
		chain.pattern_params["count"] = int(def["count"])
	if def.has("length"):
		chain.pattern_params["length"] = int(def["length"])
	if def.has("segment"):
		chain.pattern_params["segment"] = def["segment"]
	if def.has("chebyshev"):
		chain.pattern_params["chebyshev"] = def["chebyshev"]

	# 解析原子列表
	var atoms_defs: Array = def.get("atoms", [])
	for atom_def in atoms_defs:
		if atom_def is not Dictionary:
			continue
		var atom_name: String = atom_def.get("atom", "")
		if atom_name.is_empty():
			continue

		if _registry == null or not _registry.has_atom(atom_name):
			push_warning("EffectChainResolver: unknown atom '%s'" % atom_name)
			continue

		# 复制参数（排除 "atom" key）
		var params: Dictionary = atom_def.duplicate()
		params.erase("atom")

		var atom: AtomBase = _registry.create(atom_name, params)
		if atom == null:
			continue

		if atom.is_condition():
			chain.conditions.append(atom)
		else:
			chain.actions.append(atom)

	# 来源标记
	chain.chain_source = def.get("_chain_source", "")

	return chain


## 解析一个状态效果的全部链（entity_effects + tile_effects + trail_effects）
func resolve_all(status_config: Dictionary) -> Array:
	var chains: Array = []

	# 实体效果链
	var entity_effects: Array = status_config.get("entity_effects", [])
	for def in entity_effects:
		if def is Dictionary:
			def["_chain_source"] = "entity_effect"
			chains.append(resolve(def))

	# 地砖效果链
	var tile_effects: Array = status_config.get("tile_effects", [])
	for def in tile_effects:
		if def is Dictionary:
			def["_chain_source"] = "tile_effect"
			chains.append(resolve(def))

	# 留痕效果链
	var trail_effects: Array = status_config.get("trail_effects", [])
	for def in trail_effects:
		if def is Dictionary:
			def["_chain_source"] = "trail_effect"
			chains.append(resolve(def))

	return chains


## 解析反应定义 → EffectChain
func resolve_reaction(reaction_config: Dictionary) -> EffectChain:
	var def: Dictionary = reaction_config.duplicate()
	def["_chain_source"] = "reaction"
	if not def.has("trigger"):
		def["trigger"] = "on_applied"  # 反应是即时触发
	return resolve(def)
