extends Node
## AudioManager——事件驱动音效播放器（SpecKit 004 Phase P T105，presentation §9/§10）
## 8 voice AudioStreamPlayer 池；**仅监听 EventBus**（§11.1 只听不驱动）；
## 触发绑定 = `presentation.game_feel.triggers`（表即代码，Layer A 读同一份 JSON）；
## 同音效 `audio.dedup_ms` 防重（Time.get_ticks_msec 差值，坑 #4）；
## 仪表信号 `sfx_invoked(sfx_id, args)` + `last_played` 环形缓冲（挂单例不挂 EventBus，
## §11.4）。`audio.enabled=false` 零播放完整可玩（宪法：可禁用）。
## 音乐不做（SFX-only）。

signal sfx_invoked(sfx_id: String, args: Dictionary)

const VOICE_COUNT: int = 8
const RING_LIMIT: int = 32

var last_played: Array = []

var _players: Array = []
var _last_played_ms: Dictionary = {}
var _eat_streak: int = 0
var _last_eat_ms: int = -1000000


func _ready() -> void:
	var volume_db: float = float(
		ConfigManager.get_presentation_config().get("audio", {}).get("master_volume_db", 0))
	for i in VOICE_COUNT:
		var player := AudioStreamPlayer.new()
		player.name = "Voice%d" % i
		player.volume_db = volume_db
		add_child(player)

	# §9 触发表绑定（MUST #1-8；#8 的 presented/chosen 族与 CeremonyLayer 同口径）
	EventBus.snake_food_eaten.connect(_on_food_eaten)
	EventBus.enemy_killed.connect(_play_for_event.bind("enemy_killed"))
	EventBus.snake_body_attacked.connect(_play_for_event.bind("snake_body_attacked"))
	EventBus.snake_length_decreased.connect(_play_for_event.bind("snake_length_decreased"))
	EventBus.snake_died.connect(_play_for_event.bind("snake_died"))
	EventBus.room_completed.connect(_play_for_event.bind("room_completed"))
	EventBus.reaction_triggered.connect(_on_reaction)
	for presented in [EventBus.reward_presented, EventBus.scale_reward_presented,
			EventBus.floor_reward_presented]:
		presented.connect(_on_choice_presented)
	for chosen in [EventBus.reward_chosen, EventBus.scale_reward_chosen,
			EventBus.scale_option_discarded, EventBus.floor_reward_chosen]:
		chosen.connect(_play_for_event.bind("choice_chosen"))
	EventBus.game_started.connect(_on_game_started)


## 通用播放（仪表 + 防重 + voice 池）。返回是否真实出声。
func play_sfx(sfx_id: String, pitch: float = 1.0) -> bool:
	var audio_cfg: Dictionary = ConfigManager.get_presentation_config().get("audio", {})
	if not bool(audio_cfg.get("enabled", true)):
		return false
	if not SFXForge.has_stream(sfx_id):
		return false
	var now: int = Time.get_ticks_msec()
	var dedup_ms: int = int(audio_cfg.get("dedup_ms", 50))
	if dedup_ms > 0 and now - int(_last_played_ms.get(sfx_id, -1000000)) < dedup_ms:
		return false
	_last_played_ms[sfx_id] = now

	var player: AudioStreamPlayer = _grab_voice()
	player.stream = SFXForge.get_stream(sfx_id)
	player.pitch_scale = pitch
	player.play()

	sfx_invoked.emit(sfx_id, {"pitch": pitch})
	last_played.append(sfx_id)
	if last_played.size() > RING_LIMIT:
		last_played.pop_front()
	return true


func _grab_voice() -> AudioStreamPlayer:
	for player in get_children():
		if player is AudioStreamPlayer and not player.playing:
			return player
	return get_child(0)


func _trigger(event_id: String) -> Dictionary:
	return ConfigManager.get_game_feel().get("triggers", {}).get(event_id, {})


func _play_for_event(_data: Dictionary, event_id: String) -> void:
	var trig: Dictionary = _trigger(event_id)
	if not bool(trig.get("enabled", false)):
		return
	play_sfx(str(trig.get("sfx", "")))


## §9 #1：连吃音高 +1 半音，streak_window_sec 无续口即衰减归零
func _on_food_eaten(_data: Dictionary) -> void:
	var trig: Dictionary = _trigger("snake_food_eaten")
	if not bool(trig.get("enabled", false)):
		return
	var now: int = Time.get_ticks_msec()
	var window_ms: int = int(float(trig.get("streak_window_sec", 4.0)) * 1000.0)
	if now - _last_eat_ms > window_ms:
		_eat_streak = 0
	var semitones: float = float(_eat_streak * int(trig.get("pitch_step_semitones", 1)))
	if play_sfx(str(trig.get("sfx", "")), pow(2.0, semitones / 12.0)):
		_eat_streak += 1
		_last_eat_ms = now


## §9 #5：反应三变体——reaction_id 哈希定变体（同反应同声，命名教学一致性）
func _on_reaction(data: Dictionary) -> void:
	var trig: Dictionary = _trigger("reaction_triggered")
	if not bool(trig.get("enabled", false)):
		return
	var variants: Array = trig.get("sfx_variants", [])
	if variants.is_empty():
		return
	var idx: int = hash(str(data.get("reaction_id", ""))) % variants.size()
	play_sfx(str(variants[idx]))


## §9 #8：card_in ×N stagger（首发即时入契约，余发计时器超 dedup 窗）
func _on_choice_presented(_data: Dictionary) -> void:
	var trig: Dictionary = _trigger("choice_presented")
	if not bool(trig.get("enabled", false)):
		return
	var sfx_id: String = str(trig.get("sfx", ""))
	play_sfx(sfx_id)
	var stagger_sec: float = float(trig.get("stagger_sec", 0.06))
	for i in range(1, int(trig.get("stagger_count", 1))):
		get_tree().create_timer(stagger_sec * i).timeout.connect(
			play_sfx.bind(sfx_id), CONNECT_ONE_SHOT)


func _on_game_started() -> void:
	_eat_streak = 0
	_last_eat_ms = -1000000
