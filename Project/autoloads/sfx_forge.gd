extends Node
## SFXForge——程序化音色合成器（SpecKit 004 Phase P T105，presentation_design.md §10）
## boot 时按 `presentation.audio.sfx` 合成全部 AudioStreamWAV。
## 参数 schema：{wave: sine|square|triangle|noise, freq_start, freq_end, duration,
## attack, decay, noise_mix, volume, steps?}（steps>1 = 频率扫频量化为 N 级——
## room_clear「两音上行」之类的台阶音）。
## 五条实现坑（设计 §10 强制）：① 只用 FORMAT_16_BITS + s16 小端手写；
## ② 测试不 await finished；③ autoload 排 ConfigManager 之后；④ 防重在 AudioManager；
## ⑤ 不动总线（master_volume_db 落在 voice 池 volume_db）。
## 噪声用 id 哈希种子 LCG（确定性，boot 不消耗全局 RNG）。

const MIX_RATE: int = 22050

var _streams: Dictionary = {}


func _ready() -> void:
	_synthesize_all()


func _synthesize_all() -> void:
	_streams.clear()
	var bank: Dictionary = ConfigManager.get_presentation_config() \
		.get("audio", {}).get("sfx", {})
	for sfx_id in bank:
		_streams[str(sfx_id)] = _forge(str(sfx_id), bank[sfx_id])


func get_stream(sfx_id: String) -> AudioStreamWAV:
	return _streams.get(sfx_id)


func has_stream(sfx_id: String) -> bool:
	return _streams.has(sfx_id)


static func _forge(sfx_id: String, def: Dictionary) -> AudioStreamWAV:
	var duration: float = maxf(float(def.get("duration", 0.05)), 0.01)
	var freq_start: float = float(def.get("freq_start", 440.0))
	var freq_end: float = float(def.get("freq_end", freq_start))
	var attack: float = maxf(float(def.get("attack", 0.005)), 0.0)
	var decay: float = maxf(float(def.get("decay", 0.0)), 0.0)
	var noise_mix: float = clampf(float(def.get("noise_mix", 0.0)), 0.0, 1.0)
	var volume: float = clampf(float(def.get("volume", 0.5)), 0.0, 1.0)
	var steps: int = maxi(int(def.get("steps", 1)), 1)
	var wave: String = str(def.get("wave", "sine"))

	var n: int = int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)

	var phase: float = 0.0
	var noise_state: int = hash(sfx_id) & 0x7FFFFFFF
	for i in n:
		var t: float = float(i) / MIX_RATE
		var progress: float = t / duration
		# steps>1：扫频量化为离散台阶（两音上行等）
		if steps > 1:
			progress = floorf(progress * steps) / float(steps)
		var freq: float = lerpf(freq_start, freq_end, progress)
		phase += freq / MIX_RATE

		var frac: float = phase - floorf(phase)
		var tone: float
		match wave:
			"square":
				tone = 1.0 if frac < 0.5 else -1.0
			"triangle":
				tone = 2.0 * absf(2.0 * frac - 1.0) - 1.0
			"noise":
				tone = 0.0
			_:
				tone = sin(TAU * frac)

		# 确定性 LCG 噪声（glibc 系数）
		noise_state = int((noise_state * 1103515245 + 12345) & 0x7FFFFFFF)
		var noise: float = float(noise_state) / float(0x7FFFFFFF) * 2.0 - 1.0
		var sample: float = lerpf(tone, noise, noise_mix if wave != "noise" else 1.0)

		# 包络：attack 线性升 + 尾部 decay 线性收
		var env: float = 1.0
		if attack > 0.0 and t < attack:
			env = t / attack
		if decay > 0.0 and t > duration - decay:
			env = minf(env, (duration - t) / decay)
		var v: int = int(clampf(sample * env * volume, -1.0, 1.0) * 32767.0)
		# s16 小端手写（坑 #1：encode_s16 语义）
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
