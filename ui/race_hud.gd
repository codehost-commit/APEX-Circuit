class_name RaceHUD
extends CanvasLayer

signal restart_requested
signal menu_requested
signal skip_qualifying_requested

var circuit: CircuitTrack
var field: Array[RaycastFormulaCar] = []
var cockpit: CockpitDisplay
var minimap: TrackMinimap
var _root: Control
var _session: Label
var _lap_clock: Label
var _timing: Label
var _delta_label: Label
var _sector_labels: Array[Label] = []
var _standings: VBoxContainer
var _standing_rows: Array[Label] = []
var _message: Label
var _announcement: PanelContainer
var _announcement_title: Label
var _dynamics: TelemetryCircle
var _light_label: Label
var _instruments: RaceInstruments
var _pause: PanelContainer
var _results: PanelContainer
var _results_text: Label
var _results_title: Label
var _skip: Button
var _message_timer := 0.0
var _standings_timer := 0.0
var _settings_showing := false
var _pause_content: VBoxContainer

func _ready() -> void:
	layer = 2
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_layout()
	EventBus.race_message.connect(_show_message)
	EventBus.start_lights_changed.connect(_on_lights)
	EventBus.session_started.connect(_on_session_started)

func setup(track_value: CircuitTrack, cars_value: Array[RaycastFormulaCar]) -> void:
	circuit = track_value
	field = cars_value
	minimap.setup(circuit, field)

func _unhandled_input(event: InputEvent) -> void:
	if GameState.mode == GameState.Mode.MENU or not event.is_action_pressed("pause"):
		return
	get_viewport().set_input_as_handled()
	if GameState.mode == GameState.Mode.RESULTS:
		return
	GameState.set_paused(not GameState.paused)
	_pause.visible = GameState.paused
	if GameState.paused:
		_show_pause_home()

func _process(delta: float) -> void:
	visible = GameState.mode != GameState.Mode.MENU
	if not visible:
		return
	var player := GameState.player_car as RaycastFormulaCar
	var director := GameState.race_director as RaceDirector
	if player == null or director == null:
		return
	if not GameState.paused:
		_message_timer = maxf(0, _message_timer - delta)
	_announcement.visible = _message_timer > 0
	_pause.visible = GameState.paused
	var status := director.get_player_status()
	if status.is_empty():
		return
	var rows := director.get_classification()
	var position := 1
	for row in rows:
		if row.car == player:
			position = int(row.position)
	var mode := GameState.mode
	var trial := mode == GameState.Mode.TIME_TRIAL
	var qualifying := mode == GameState.Mode.QUALIFYING
	if trial:
		_session.text = "TIME TRIAL    /    LAP %02d" % (player.lap + 1)
	elif qualifying:
		_session.text = "QUALIFYING    /    %s LEFT" % RaceDirector.format_time(maxf(0, RaceConfig.qualifying_duration - director.qualifying_time))
	else:
		_session.text = "P%02d / %02d    /    LAP %d OF %d" % [position, field.size(), mini(player.lap + 1, GameState.total_laps), GameState.total_laps]
	_lap_clock.text = RaceDirector.format_time(float(status.current_lap)) if bool(status.started) else "OUT LAP"
	_lap_clock.add_theme_color_override("font_color", ApexStyle.WHITE if bool(status.lap_valid) else ApexStyle.RED)
	_timing.text = "LAST   %s%s\nBEST   %s\nPB       %s" % [RaceDirector.format_time(float(status.last_lap)), "  INVALID" if not bool(status.last_lap_valid) else "", RaceDirector.format_time(float(status.best_lap)), RaceDirector.format_time(director.personal_best)]
	var lap_delta := float(status.delta)
	_delta_label.text = "DELTA  %+.3f" % lap_delta if is_finite(lap_delta) else "DELTA  --.---"
	_delta_label.add_theme_color_override("font_color", ApexStyle.MUTED if not is_finite(lap_delta) else (ApexStyle.ACCENT if lap_delta <= 0 else ApexStyle.RED))
	for index in 3:
		var current := float(status.sectors[index])
		var seconds := current if is_finite(current) else float(status.last_sectors[index])
		_sector_labels[index].text = "S%d\n%s" % [index + 1, "%.3f" % seconds if is_finite(seconds) else "--.---"]
		var color := ApexStyle.MUTED
		if is_finite(current):
			color = ApexStyle.RED if not bool(status.sector_valid[index]) else (Color("#bba2ff") if bool(status.sector_pb[index]) else ApexStyle.ACCENT)
		_sector_labels[index].add_theme_color_override("font_color", color)
	_dynamics.car = player
	_dynamics.visible = mode != GameState.Mode.RESULTS
	_instruments.car = player
	_instruments.visible = not player.is_cockpit_camera() and mode != GameState.Mode.RESULTS
	cockpit.car = player
	cockpit.visible = player.is_cockpit_camera() and mode != GameState.Mode.RESULTS
	_standings.visible = not trial
	_skip.visible = qualifying
	_skip.disabled = false
	_skip.text = "SKIP TO GRID"
	_results.visible = mode == GameState.Mode.RESULTS
	if _results.visible:
		_update_results(rows, director, status)
	_standings_timer -= delta
	if _standings_timer <= 0:
		_standings_timer = 0.15
		_update_standings(rows, player)

func _build_layout() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var timing_panel := PanelContainer.new()
	timing_panel.position = Vector2(34, 32)
	timing_panel.size = Vector2(415, 356)
	timing_panel.add_theme_stylebox_override("panel", ApexStyle.panel(0.83))
	_root.add_child(timing_panel)
	var timing_box := VBoxContainer.new()
	timing_box.add_theme_constant_override("separation", 10)
	timing_panel.add_child(timing_box)
	_session = ApexStyle.label("TIME TRIAL", 20, ApexStyle.ACCENT)
	timing_box.add_child(_session)
	_lap_clock = ApexStyle.label("OUT LAP", 47)
	timing_box.add_child(_lap_clock)
	_timing = ApexStyle.label("LAST\nBEST\nPB", 20, ApexStyle.MUTED)
	timing_box.add_child(_timing)
	var sectors := HBoxContainer.new()
	timing_box.add_child(sectors)
	for index in 3:
		var label := ApexStyle.label("S%d\n--.---" % (index + 1), 20, ApexStyle.MUTED)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sectors.add_child(label)
		_sector_labels.append(label)
	_delta_label = ApexStyle.label("DELTA  --.---", 28)
	timing_box.add_child(_delta_label)
	_announcement = PanelContainer.new()
	_root.add_child(_announcement)
	_announcement.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_announcement.position = Vector2(-420, 32)
	_announcement.custom_minimum_size = Vector2(790, 105)
	_announcement.size.x = 790
	var announcement_style := ApexStyle.panel(0.96, ApexStyle.ACCENT)
	announcement_style.border_width_left = 5
	_announcement.add_theme_stylebox_override("panel", announcement_style)
	var announcement_box := VBoxContainer.new()
	announcement_box.add_theme_constant_override("separation", 6)
	_announcement.add_child(announcement_box)
	_announcement_title = ApexStyle.label("RACE CONTROL", 22, ApexStyle.ACCENT)
	announcement_box.add_child(_announcement_title)
	_message = ApexStyle.label("", 21, ApexStyle.WHITE)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	announcement_box.add_child(_message)
	_light_label = ApexStyle.label("", 54, ApexStyle.RED)
	_light_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_light_label.position = Vector2(-250, 188)
	_light_label.size.x = 500
	_light_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_light_label)
	_standings = VBoxContainer.new()
	_standings.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_standings.position = Vector2(-412, 34)
	_standings.size.x = 380
	_standings.add_theme_constant_override("separation", 5)
	_root.add_child(_standings)
	_standings.add_child(ApexStyle.label("CLASSIFICATION / INTERVAL", 17, ApexStyle.MUTED))
	for index in 12:
		var label := ApexStyle.label("", 20)
		_standings.add_child(label)
		_standing_rows.append(label)
	_skip = ApexStyle.button("SKIP TO GRID")
	_skip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_skip.position = Vector2(-412, 465)
	_skip.size = Vector2(380, 62)
	_skip.pressed.connect(func() -> void: skip_qualifying_requested.emit())
	_root.add_child(_skip)
	minimap = TrackMinimap.new()
	minimap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	minimap.position = Vector2(34, -312)
	minimap.size = Vector2(306, 274)
	_root.add_child(minimap)
	_instruments = RaceInstruments.new()
	_instruments.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_instruments.position = Vector2(-425, -343)
	_instruments.size = Vector2(390, 309)
	_root.add_child(_instruments)
	_dynamics = TelemetryCircle.new()
	_root.add_child(_dynamics)
	_dynamics.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_dynamics.position = Vector2(-425, -663)
	_dynamics.size = Vector2(390, 310)
	cockpit = CockpitDisplay.new()
	cockpit.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	cockpit.position = Vector2(-260, -255)
	cockpit.size = Vector2(520, 270)
	_root.add_child(cockpit)
	var help := ApexStyle.label("C  CAMERA     F  DRS     R  RECOVER     ESC  PAUSE", 15, ApexStyle.MUTED)
	help.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	help.position = Vector2(-350, -34)
	help.size.x = 700
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(help)
	_pause = _center_panel(Vector2(690, 870))
	_pause.visible = false
	_results = _center_panel(Vector2(960, 890))
	_results.visible = false
	var result_box := VBoxContainer.new()
	result_box.add_theme_constant_override("separation", 20)
	_results.add_child(result_box)
	_results_title = ApexStyle.label("CLASSIFICATION", 39, ApexStyle.ACCENT)
	result_box.add_child(_results_title)
	_results_text = ApexStyle.label("", 23)
	_results_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	result_box.add_child(_results_text)
	var restart := ApexStyle.button("RACE AGAIN", true)
	restart.pressed.connect(func() -> void:
		GameState.set_paused(false)
		restart_requested.emit())
	result_box.add_child(restart)
	var menu := ApexStyle.button("MAIN MENU")
	menu.pressed.connect(func() -> void:
		GameState.set_paused(false)
		menu_requested.emit())
	result_box.add_child(menu)

func _center_panel(dimensions: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = -dimensions * 0.5
	panel.size = dimensions
	panel.add_theme_stylebox_override("panel", ApexStyle.panel(0.98))
	_root.add_child(panel)
	return panel

func _clear_pause() -> void:
	for child in _pause.get_children():
		_pause.remove_child(child)
		child.queue_free()

func _show_pause_home() -> void:
	_clear_pause()
	_settings_showing = false
	_pause_content = VBoxContainer.new()
	_pause_content.add_theme_constant_override("separation", 17)
	_pause.add_child(_pause_content)
	_pause_content.add_child(ApexStyle.label("SESSION PAUSED", 40, ApexStyle.ACCENT))
	_pause_content.add_child(ApexStyle.label("Simulation and all session clocks are paused.", 20, ApexStyle.MUTED))
	_pause_button("RESUME", func() -> void: GameState.set_paused(false), true)
	_pause_button("SETTINGS & CONTROLS", _show_pause_settings)
	_pause_button("RECOVER TO CHECKPOINT", func() -> void:
		GameState.set_paused(false)
		GameState.race_director.reset_player())
	_pause_button("RESTART SESSION", func() -> void:
		GameState.set_paused(false)
		restart_requested.emit())
	if GameState.mode == GameState.Mode.QUALIFYING:
		_pause_button("FINISH QUALIFYING / GRID", func() -> void:
			GameState.set_paused(false)
			skip_qualifying_requested.emit())
	else:
		_pause_button("END TIME TRIAL" if GameState.mode == GameState.Mode.TIME_TRIAL else "RETIRE FROM RACE", func() -> void:
			GameState.set_paused(false)
			GameState.race_director.retire_player())
	_pause_button("MAIN MENU", func() -> void:
		GameState.set_paused(false)
		menu_requested.emit())

func _pause_button(text: String, callback: Callable, primary := false) -> void:
	var button := ApexStyle.button(text, primary)
	button.pressed.connect(callback)
	_pause_content.add_child(button)

func _show_pause_settings() -> void:
	_clear_pause()
	_settings_showing = true
	_pause_content = ApexStyle.settings_content()
	_pause.add_child(_pause_content)
	_pause_button("BACK", _show_pause_home, true)

func _update_standings(rows: Array, player: RaycastFormulaCar) -> void:
	for index in _standing_rows.size():
		var label := _standing_rows[index]
		label.visible = index < rows.size()
		if index >= rows.size():
			continue
		var row: Dictionary = rows[index]
		var gap := "LEADER" if index == 0 else ("+%.3f" % float(row.interval) if is_finite(float(row.interval)) else "NO TIME")
		if bool(row.retired):
			gap = "DNF"
		elif float(row.penalty) > 0:
			gap += " +%.0fs" % float(row.penalty)
		label.text = "%02d   %-13s  %s" % [row.position, row.driver, gap]
		label.add_theme_color_override("font_color", ApexStyle.ACCENT if row.car == player else ApexStyle.WHITE)

func _update_results(rows: Array, director: RaceDirector, status: Dictionary) -> void:
	var lines: Array[String] = []
	if GameState.session_mode == GameState.Mode.TIME_TRIAL:
		_results_title.text = "TIME TRIAL / SESSION COMPLETE"
		lines.append("SESSION BEST     " + RaceDirector.format_time(float(status.best_lap)))
		lines.append("PERSONAL BEST    " + RaceDirector.format_time(director.personal_best))
		lines.append("\nBEST SECTORS")
		for index in 3:
			lines.append("S%d     %s" % [index + 1, RaceDirector.format_time(float(status.best_sectors[index]))])
		lines.append("\nClean personal bests and the ghost are saved automatically.")
	else:
		_results_title.text = "%s WINS" % String(rows[0].driver).to_upper() if not rows.is_empty() and bool(rows[0].finished) else "RACE CLASSIFICATION"
		lines.append("POS    DRIVER                   TOTAL / STATUS       PENALTY")
		for row in rows:
			var time := RaceDirector.format_time(float(row.time)) if bool(row.finished) else ("DNF" if bool(row.retired) else "%d LAPS" % int(row.lap))
			lines.append("%02d      %-16s   %-16s  %s" % [row.position, row.driver, time, "+%.0fs" % float(row.penalty) if float(row.penalty) > 0 else "-"])
		lines.append("\nFinal order includes every resolved time penalty.")
		if not status.penalty_log.is_empty():
			lines.append("Your decisions: " + ", ".join(status.penalty_log))
	_results_text.text = "\n".join(lines)

func _show_message(title: String, detail: String, duration: float) -> void:
	_announcement_title.text = "RACE CONTROL  /  " + title
	_message.text = detail
	_message_timer = duration

func _on_lights(count: int, extinguished: bool) -> void:
	_light_label.text = "" if extinguished or count == 0 else "● ".repeat(count) + "○ ".repeat(5 - count)

func _on_session_started(_mode: int) -> void:
	_message_timer = 0
	_results.visible = false
	_pause.visible = false
