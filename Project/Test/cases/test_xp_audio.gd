extends RefCounted
## Phase P T105: 程序化音频契约（presentation_design.md §9 触发表 / §10 音频体系）
## SFXForge（boot 按 JSON 合成 AudioStreamWAV，16-bit mono 22050Hz）+
## AudioManager（8 voice 池、仅监听 EventBus、dedup_ms 防重、sfx_invoked 仪表 +
## last_played 环形缓冲）。触发表 = presentation.game_feel.triggers（表即契约，
## Layer A 直接读同一份 JSON 断言）；强度排序 segment_loss > hit；
## audio.enabled=false 完整可玩零播放。

## MUST 触发表（§9 #1-8；#5 反应为三变体、#8 拆 presented/chosen 两行）
const MUST_SFX_TABLE: Dictionary = {
	"snake_food_eaten": "eat",
	"enemy_killed": "kill",
	"snake_body_attacked": "hit",
	"snake_length_decreased": "segment_loss",
	"snake_died": "death",
	"room_completed": "room_clear",
	"choice_presented": "card_in",
	"choice_chosen": "confirm",
}

var _invoked: Array = []


func run(t) -> void:
	_test_trigger_table_contract(t)
	_test_sfx_forge(t)
	await _test_audio_manager(t)


# === §9：触发表完整性 + 强度排序（JSON 数值比较） ===
func _test_trigger_table_contract(t) -> void:
	var triggers: Dictionary = ConfigManager.get_game_feel().get("triggers", {})
	var bank: Dictionary = ConfigManager.get_presentation_config() \
		.get("audio", {}).get("sfx", {})

	for event_id in MUST_SFX_TABLE:
		var trig: Dictionary = triggers.get(event_id, {})
		t.assert_false(trig.is_empty(), "[P105] triggers has MUST row '%s'" % event_id)
		if trig.is_empty():
			continue
		t.assert_true(bool(trig.get("enabled", false)),
			"[P105] MUST trigger '%s' enabled" % event_id)
		var sfx_id: String = str(trig.get("sfx", ""))
		t.assert_eq(sfx_id, MUST_SFX_TABLE[event_id],
			"[P105] '%s' maps to sfx '%s'" % [event_id, MUST_SFX_TABLE[event_id]])
		t.assert_true(bank.has(sfx_id), "[P105] sfx bank defines '%s'" % sfx_id)

	# #5 反应三变体（reaction_*）
	var reaction_trig: Dictionary = triggers.get("reaction_triggered", {})
	var variants: Array = reaction_trig.get("sfx_variants", [])
	t.assert_eq(variants.size(), 3, "[P105] reaction trigger has 3 sfx variants")
	for v in variants:
		t.assert_true(bank.has(str(v)), "[P105] sfx bank defines variant '%s'" % v)

	# 强度排序硬约束（§9）：segment_loss 的 hitstop/shake 必须 > hit
	var loss: Dictionary = triggers.get("snake_length_decreased", {})
	var hit: Dictionary = triggers.get("snake_body_attacked", {})
	t.assert_true(float(loss.get("hitstop", 0)) > float(hit.get("hitstop", 0)),
		"[P105] intensity order: segment_loss hitstop > hit hitstop")
	t.assert_true(float(loss.get("shake", 0)) > float(hit.get("shake", 0)),
		"[P105] intensity order: segment_loss shake > hit shake")
	# 表内强度数值即运行时数值（表即代码）：#2/#6 关键 hitstop 与设计表一致
	t.assert_eq(float(triggers.get("enemy_killed", {}).get("hitstop", 0)), 0.03,
		"[P105] enemy_killed hitstop == 0.03 (design table #2)")
	t.assert_eq(float(triggers.get("snake_died", {}).get("hitstop", 0)), 0.1,
		"[P105] snake_died hitstop == 0.1 (design table #6)")


# === §10：SFXForge boot 合成全部音色（五条实现坑之 16-bit/22050/mono） ===
func _test_sfx_forge(t) -> void:
	var forge: Node = t.get_node_or_null("/root/SFXForge")
	t.assert_true(forge != null, "[P105] SFXForge autoload registered")
	if forge == null:
		return
	var bank: Dictionary = ConfigManager.get_presentation_config() \
		.get("audio", {}).get("sfx", {})
	t.assert_true(bank.size() >= 11, "[P105] sfx bank has full MUST set (got %d)" % bank.size())
	for sfx_id in bank:
		var stream = forge.get_stream(str(sfx_id))
		t.assert_true(stream is AudioStreamWAV, "[P105] '%s' synthesized" % sfx_id)
		if not (stream is AudioStreamWAV):
			continue
		t.assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS,
			"[P105] '%s' is FORMAT_16_BITS (pitfall #1)" % sfx_id)
		t.assert_eq(stream.mix_rate, 22050, "[P105] '%s' mix rate 22050" % sfx_id)
		t.assert_false(stream.stereo, "[P105] '%s' is mono" % sfx_id)
		var expected: int = int(float(bank[sfx_id].get("duration", 0.0)) * 22050.0) * 2
		t.assert_true(absi(stream.data.size() - expected) <= 4,
			"[P105] '%s' data length matches duration (got %d, want ~%d)" % [
				sfx_id, stream.data.size(), expected])
	# §7 #6：death 为 1.2s 下行扫频
	var death_def: Dictionary = bank.get("death", {})
	t.assert_eq(float(death_def.get("duration", 0)), 1.2, "[P105] death sweep is 1.2s")
	t.assert_true(float(death_def.get("freq_end", 0)) < float(death_def.get("freq_start", 0)),
		"[P105] death sweep descends")


# === §10：AudioManager——事件绑定/防重/连吃音高/关音频旁路/环形缓冲 ===
func _test_audio_manager(t) -> void:
	var mgr: Node = t.get_node_or_null("/root/AudioManager")
	t.assert_true(mgr != null, "[P105] AudioManager autoload registered")
	if mgr == null:
		return
	var voices: int = 0
	for child in mgr.get_children():
		if child is AudioStreamPlayer:
			voices += 1
	t.assert_eq(voices, 8, "[P105] 8-voice player pool")

	var saved_gm: Dictionary = {
		"state": GameManager.current_state, "score": GameManager.current_score,
		"best": GameManager.best_score,
	}
	var audio_cfg: Dictionary = ConfigManager.presentation.get("audio", {})
	var saved_dedup: int = int(audio_cfg.get("dedup_ms", 50))
	audio_cfg["dedup_ms"] = 0  # 顺序契约测试不受 50ms 防重干扰
	_invoked.clear()
	mgr.sfx_invoked.connect(_on_sfx_invoked)

	# MUST 表逐行：事件 → 对应 sfx 同步可观测
	var payloads: Dictionary = {
		"snake_food_eaten": [EventBus.snake_food_eaten,
			{"food": null, "position": Vector2i.ZERO, "food_type": "normal"}],
		"enemy_killed": [EventBus.enemy_killed,
			{"enemy_def": null, "position": Vector2i.ZERO, "method": "t105"}],
		"snake_body_attacked": [EventBus.snake_body_attacked,
			{"position": Vector2i.ZERO, "segment": null, "enemy": null,
				"status_transferred": false}],
		"snake_length_decreased": [EventBus.snake_length_decreased,
			{"amount": 1, "source": "t105", "new_length": 3}],
		"snake_died": [EventBus.snake_died, {"cause": "t105_probe"}],
		"room_completed": [EventBus.room_completed,
			{"room_id": "t105", "room_type": "combat"}],
		"choice_presented": [EventBus.reward_presented,
			{"offer_id": "t105", "options": []}],
		"choice_chosen": [EventBus.reward_chosen,
			{"offer_id": "t105", "option_id": "x", "skipped": false}],
	}
	for event_id in payloads:
		var before: int = _invoked.size()
		payloads[event_id][0].emit(payloads[event_id][1])
		var expected_sfx: String = MUST_SFX_TABLE[event_id]
		var got: Array = _invoked.slice(before).map(func(e): return e[0])
		t.assert_true(got.has(expected_sfx),
			"[P105] %s -> sfx '%s' invoked (got %s)" % [event_id, expected_sfx, got])

	# #5 反应三变体：同 reaction_id 决定性、变体属配置集合
	var variants: Array = ConfigManager.get_game_feel().get("triggers", {}) \
		.get("reaction_triggered", {}).get("sfx_variants", [])
	var before_r: int = _invoked.size()
	EventBus.reaction_triggered.emit({"reaction_id": "boil", "position": Vector2i.ZERO,
		"type_a": "wet", "type_b": "burn", "layer_a": 1, "layer_b": 1, "damage": 1})
	EventBus.reaction_triggered.emit({"reaction_id": "boil", "position": Vector2i.ZERO,
		"type_a": "wet", "type_b": "burn", "layer_a": 1, "layer_b": 1, "damage": 1})
	var reaction_plays: Array = _invoked.slice(before_r).map(func(e): return e[0])
	t.assert_eq(reaction_plays.size(), 2, "[P105] both reactions played (dedup off)")
	if reaction_plays.size() == 2:
		t.assert_eq(reaction_plays[0], reaction_plays[1],
			"[P105] same reaction_id picks the same variant (deterministic)")
		t.assert_true(variants.has(reaction_plays[0]),
			"[P105] variant comes from the configured set")

	# #1 连吃音高 +1 半音：同窗第二口 pitch 更高
	var before_e: int = _invoked.size()
	EventBus.snake_food_eaten.emit({"food": null, "position": Vector2i.ZERO,
		"food_type": "normal"})
	EventBus.snake_food_eaten.emit({"food": null, "position": Vector2i.ZERO,
		"food_type": "normal"})
	var eats: Array = _invoked.slice(before_e).filter(func(e): return e[0] == "eat")
	t.assert_eq(eats.size(), 2, "[P105] both eats played")
	if eats.size() == 2:
		t.assert_true(float(eats[1][1].get("pitch", 1.0)) > float(eats[0][1].get("pitch", 1.0)),
			"[P105] consecutive eat raises pitch (+1 semitone streak)")

	# §10 防重：恢复 dedup 后同音效连发只过第一发
	# （先真实等 60ms 让 sweep 阶段的 kill 时间戳滑出防重窗）
	audio_cfg["dedup_ms"] = 50
	await t.get_tree().create_timer(0.06).timeout
	var before_d: int = _invoked.size()
	EventBus.enemy_killed.emit({"enemy_def": null, "position": Vector2i.ZERO,
		"method": "t105"})
	EventBus.enemy_killed.emit({"enemy_def": null, "position": Vector2i.ZERO,
		"method": "t105"})
	t.assert_eq(_invoked.slice(before_d).size(), 1,
		"[P105] 50ms dedup suppresses the immediate repeat")

	# audio.enabled=false：完整事件流零播放零报错（宪法：可禁用）
	var saved_enabled: bool = bool(audio_cfg.get("enabled", true))
	audio_cfg["enabled"] = false
	audio_cfg["dedup_ms"] = 0
	var before_off: int = _invoked.size()
	for event_id in payloads:
		payloads[event_id][0].emit(payloads[event_id][1])
	t.assert_eq(_invoked.slice(before_off).size(), 0,
		"[P105] audio off: zero plays across the full MUST sweep")
	audio_cfg["enabled"] = saved_enabled
	audio_cfg["dedup_ms"] = saved_dedup

	# last_played 环形缓冲有界（Layer A 观察点）
	t.assert_true(mgr.last_played.size() <= 32, "[P105] last_played ring bounded")
	t.assert_true(mgr.last_played.size() > 0, "[P105] last_played recorded plays")

	mgr.sfx_invoked.disconnect(_on_sfx_invoked)
	GameManager.current_state = int(saved_gm.get("state", GameManager.GameState.TITLE))
	GameManager.current_score = int(saved_gm.get("score", 0))
	GameManager.best_score = int(saved_gm.get("best", 0))
	TickManager.stop_ticking()
	await t.get_tree().process_frame


func _on_sfx_invoked(sfx_id: String, args: Dictionary) -> void:
	_invoked.append([sfx_id, args])
