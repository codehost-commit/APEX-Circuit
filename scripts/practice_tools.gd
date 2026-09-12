class_name PracticeTools
extends CanvasLayer
## Native equivalents of the prototype's K section coach and T policy trainer.
## Policies are measured through the same physical car, never by invented lap times.

var game: Node3D
var coach_active := false
var training_active := false
var sections: Dictionary = {}
var training_best := INF
var generation := 0
var attempt := 0
var _label: Label
var _panel: PanelContainer
var _section := -1
var _section_time := 0.0
var _section_valid := true
var _samples: Array = []
var _last_progress := -1.0
var _save_path := "user://apex_coach_3d_v1.json"
var _training_path := "user://apex_training_3d_v1.json"
var _best_pace := 0.96
var _attempt_elapsed := 0.0
var _trainer_random := RandomNumberGenerator.new()

func setup(main: Node3D) -> void:
	game = main
	layer = 7
	_trainer_random.randomize()
	_panel = PanelContainer.new()
	_panel.position = Vector2(1375.0, 660.0)
	_panel.size = Vector2(500.0, 220.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.025, 0.04, 0.92)
	style.content_margin_left = 18.0
	style.content_margin_top = 16.0
	style.content_margin_right = 18.0
	style.content_margin_bottom = 16.0
	_panel.add_theme_stylebox_override("panel", style)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 19)
	_label.add_theme_color_override("font_color", Color("#d3f2ff"))
	_panel.add_child(_label)
	add_child(_panel)
	_panel.visible = false
	EventBus.lap_completed.connect(_lap_completed)
	EventBus.player_reset.connect(func(_car: Node) -> void: _section_valid = false)
	_load_coach()
	if FileAccess.file_exists(_training_path):
		var training: Variant = JSON.parse_string(FileAccess.get_file_as_string(_training_path))
		if training is Dictionary and int(training.get("format", 0)) == 1 and absf(float(training.get("track_metres",0.0)) - game.track.total_length) < 0.1:
			_best_pace = clampf(float(training.get("pace", 0.96)), 0.90, 1.06)
			training_best = float(training.get("best_valid_lap", INF))

func _physics_process(delta: float) -> void:
	if game == null:
		return
	if Input.is_action_just_pressed("coach_toggle"):
		coach_active = not coach_active
		training_active = false
		game._start_time_trial()
		_section = -1
		_last_progress = -1.0
	if Input.is_action_just_pressed("training_toggle"):
		training_active = not training_active
		coach_active = false
		if training_active:
			_begin_attempt()
		else:
			game._start_time_trial()
	if GameState.mode != GameState.Mode.TIME_TRIAL:
		coach_active = false
		training_active = false
	_panel.visible = coach_active or training_active
	if coach_active:
		_capture_section(delta)
		_label.text = "DRIVER COACH  ·  K TO CLOSE\n%d / 24 clean sections recorded\nSection %02d  ·  %.2f s\n%s\nBank saves the fastest clean section." % [sections.size(), maxi(0, _section) + 1, _section_time, "CLEAN" if _section_valid else "INVALID — recover on next section"]
	if training_active:
		_attempt_elapsed += delta
		_label.text = "AI TRAINING  ·  T TO TAKE CONTROL\nGeneration %d  ·  Candidate %d / 6\nPace %.3f  ·  Lap %.1f s\nBest valid lap: %s\nSame car, same tyres, measured laps." % [generation, attempt % 6 + 1, game.drivers[0].pace_multiplier, _attempt_elapsed, "—" if not is_finite(training_best) else "%.3f s" % training_best]
		if _attempt_elapsed > 180.0:
			_next_attempt()

func _capture_section(delta: float) -> void:
	var car := game.player_car as RaycastFormulaCar
	var status: Dictionary = game.race_director.get_player_status()
	if not bool(status.get("started", false)):
		return
	var progress := car.race_progress
	var current := mini(23, int(progress / game.track.total_length * 24.0))
	if current != _section:
		if _section >= 0 and current == (_section + 1) % 24 and _section_valid and _section_time > 0.0 and not _samples.is_empty():
			var key := str(_section)
			if not sections.has(key) or _section_time < float(sections[key].seconds):
				sections[key] = {"seconds": _section_time, "trace": _samples.duplicate(true)}
				_save_coach()
		_section = current
		_section_time = 0.0
		_section_valid = true
		_samples.clear()
	_section_time += delta
	if not car.all_wheels_legal() or absf(car.slip_angle) > 0.72:
		_section_valid = false
	if _last_progress >= 0.0:
		var ds := wrapf(progress - _last_progress, -game.track.total_length * 0.5, game.track.total_length * 0.5)
		if ds < -0.2 or ds > maxf(15.0, car.speed_mps * delta * 3.0):
			_section_valid = false
	_last_progress = progress
	if _samples.is_empty() or _section_time - float(_samples[-1][0]) >= 0.05:
		_samples.append([_section_time, progress, car.speed_mps, car.steering_input, car.throttle_input, car.brake_input])

func _begin_attempt() -> void:
	game._start_time_trial()
	game.player_car.automated_input = true
	game.drivers[0].enabled = true
	game.drivers[0].tactics_enabled = false
	game.drivers[0].pace_multiplier = _best_pace if attempt == 0 else clampf(_best_pace + _trainer_random.randf_range(-0.025, 0.025), 0.90, 1.06)
	game.drivers[0].reset_session()
	_attempt_elapsed = 0.0

func _next_attempt() -> void:
	attempt += 1
	generation = attempt / 6
	_begin_attempt()

func _lap_completed(car: Node, _lap: int, seconds: float, valid: bool) -> void:
	if not training_active or car != game.player_car:
		return
	if valid and seconds < training_best:
		training_best = seconds
		_best_pace = game.drivers[0].pace_multiplier
		var file := FileAccess.open(_training_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify({"format": 1, "track_metres": game.track.total_length, "best_valid_lap": seconds, "pace": _best_pace, "attempt": attempt}))
	_next_attempt.call_deferred()

func _save_coach() -> void:
	var file := FileAccess.open(_save_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"format": 1, "track_metres": game.track.total_length, "sections": sections}))

func _load_coach() -> void:
	if not FileAccess.file_exists(_save_path):
		return
	var record: Variant = JSON.parse_string(FileAccess.get_file_as_string(_save_path))
	if record is Dictionary and int(record.get("format", 0)) == 1 and absf(float(record.get("track_metres", 0.0)) - game.track.total_length) < 0.1:
		sections = record.get("sections", {})
