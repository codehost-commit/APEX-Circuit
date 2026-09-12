extends Node3D
## Deterministic synthesized engine sample, pitched by actual crankshaft RPM.
## Sample generation happens once; no per-frame audio buffer loops per entrant.

static var _engine_sample: AudioStreamWAV
static var _tyre_sample: AudioStreamWAV
var car: Node
var _engine: AudioStreamPlayer3D
var _tyres: AudioStreamPlayer3D

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	if _engine_sample == null:
		_engine_sample = _make_sample(false)
		_tyre_sample = _make_sample(true)
	_engine = AudioStreamPlayer3D.new()
	_engine.name = "EngineRPM"
	_engine.stream = _engine_sample
	_engine.max_distance = 160.0
	_engine.unit_size = 8.0
	_engine.attenuation_filter_cutoff_hz = 6500.0
	_engine.volume_db = -14.0
	add_child(_engine)
	_engine.play()
	_tyres = AudioStreamPlayer3D.new()
	_tyres.name = "TyreScrub"
	_tyres.stream = _tyre_sample
	_tyres.max_distance = 65.0
	_tyres.unit_size = 7.0
	_tyres.volume_db = -65.0
	add_child(_tyres)
	_tyres.play()

func _process(delta: float) -> void:
	if _engine == null or car == null:
		return
	var engine_volume := -13.0 if car.player_controlled else -23.0
	engine_volume += lerpf(-8.0, 0.0, car.throttle_input)
	if not car.race_enabled:
		engine_volume -= 8.0
	if float(car.get("_shift_cut")) > 0.0:
		engine_volume -= 8.0
	_engine.volume_db = lerpf(_engine.volume_db, engine_volume, 1.0 - exp(-15.0 * delta))
	_engine.pitch_scale = lerpf(_engine.pitch_scale, clampf(car.rpm / 6000.0, 0.7, 3.5), 1.0 - exp(-18.0 * delta))
	var tyre_volume := -65.0
	if car.speed_mps > 6.0:
		tyre_volume = lerpf(-65.0, -23.0 if car.player_controlled else -33.0, clampf(car.tyre_smoke_strength - 0.25, 0.0, 1.0))
	_tyres.volume_db = lerpf(_tyres.volume_db, tyre_volume, 1.0 - exp(-10.0 * delta))
	_tyres.pitch_scale = 0.80 + clampf(car.speed_mps / 140.0, 0.0, 0.7)

func _make_sample(tyre: bool) -> AudioStreamWAV:
	const SAMPLE_RATE := 22050
	const FRAMES := 11025
	var bytes := PackedByteArray()
	bytes.resize(FRAMES * 2)
	var noise_state := 928371
	var filtered := 0.0
	for index in range(FRAMES):
		var time := float(index) / SAMPLE_RATE
		var value := 0.0
		if tyre:
			noise_state = (noise_state * 48271) % 2147483647
			var noise := float(noise_state) / 1073741824.0 - 1.0
			filtered = lerpf(filtered, noise, 0.38)
			value = filtered * 0.7 + sin(time * TAU * 920.0) * 0.12 + sin(time * TAU * 1370.0) * 0.06
		else:
			var firing := time * TAU * 300.0
			value = sin(firing) * 0.38 + sin(firing * 2.0 + 0.4) * 0.23 + sin(firing * 3.0 + 0.8) * 0.12
			value += sin(firing * 4.0 + 0.2) * 0.06 + sin(time * TAU * 100.0) * 0.12
			value *= 0.91 + sin(time * TAU * 50.0) * 0.09
		bytes.encode_s16(index * 2, int(clampf(value, -0.97, 0.97) * 32767.0))
	var sample := AudioStreamWAV.new()
	sample.format = AudioStreamWAV.FORMAT_16_BITS
	sample.mix_rate = SAMPLE_RATE
	sample.stereo = false
	sample.data = bytes
	sample.loop_mode = AudioStreamWAV.LOOP_FORWARD
	sample.loop_begin = 0
	sample.loop_end = FRAMES
	return sample
