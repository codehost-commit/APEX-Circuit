class_name RaceHUD
extends CanvasLayer
## Screen-space race presentation; all data comes from RaceDirector/EventBus.

var circuit: CircuitTrack
var field: Array[RaycastFormulaCar] = []
var top_left: Label
var timing: Label
var leaderboard: Label
var message: Label
var start_lights: Label
var center_readout: Label
var cockpit: CockpitDisplay
var minimap: TrackMinimap
var results_panel: PanelContainer
var results_text: Label
var _message_timer := 0.0
var _current_message := ""
var _last_lap := "--:--.---"
var _best_lap := "--:--.---"
var _sector_text := ["S1 ---.---", "S2 ---.---", "S3 ---.---"]

func _ready() -> void:
	layer = 2
	_build_layout()
	EventBus.race_message.connect(_show_message)
	EventBus.lap_completed.connect(_on_lap)
	EventBus.sector_completed.connect(_on_sector)
	EventBus.start_lights_changed.connect(_on_lights)

func setup(track_value: CircuitTrack, cars_value: Array[RaycastFormulaCar]) -> void:
	circuit = track_value
	field = cars_value
	if minimap != null:
		minimap.setup(circuit, field)

func _process(delta: float) -> void:
	visible = GameState.mode != GameState.Mode.MENU
	if Input.is_action_just_pressed("pause") and GameState.mode != GameState.Mode.MENU:
		GameState.paused = not GameState.paused
		_show_message("PAUSED" if GameState.paused else "RESUMED", "ESC to continue", 2.0)
	_message_timer = maxf(0.0, _message_timer - delta)
	message.text = _current_message if _message_timer > 0.0 else ""
	if GameState.player_car == null or GameState.race_director == null:
		return
	var player := GameState.player_car as RaycastFormulaCar
	var director := GameState.race_director as RaceDirector
	var rows := director.get_classification()
	var player_position := 1
	for row in rows:
		if row.car == player:
			player_position = int(row.position)
			break
	top_left.text = "P%d / %d\nLAP %d / %d\n%s" % [player_position, field.size(), min(player.lap + 1, GameState.total_laps), GameState.total_laps, "QUALIFYING" if GameState.mode == GameState.Mode.QUALIFYING else "RACE"]
	var status := director.get_player_status()
	var best := float(status.best_lap)
	if is_finite(best):
		_best_lap = _format_time(best)
	timing.text = "TIME  %s\nLAST  %s\nBEST  %s\n%s" % [_format_time(GameState.elapsed_seconds), _last_lap, _best_lap, "  ".join(_sector_text)]
	leaderboard.text = _leaderboard_text(rows, player_position)
	center_readout.text = "%d\n%03d\n%s" % [player.gear, int(player.speed_mps * 3.6), "DRS OPEN" if player.drs_open else ("DRS READY" if player.drs_available else "")]
	var cockpit_on := player.is_cockpit_camera()
	center_readout.visible = not cockpit_on
	cockpit.visible = cockpit_on
	cockpit.car = player
	results_panel.visible = GameState.mode == GameState.Mode.RESULTS
	if results_panel.visible:
		results_text.text = "RACE CLASSIFICATION\n\n" + _results_text(rows)

func _build_layout() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	top_left = _label(24, Color("#ecf2f4"))
	top_left.position = Vector2(28.0, 25.0)
	root.add_child(top_left)
	timing = _label(16, Color("#b7c8d3"))
	timing.position = Vector2(28.0, 123.0)
	root.add_child(timing)
	leaderboard = _label(17, Color("#edf3f5"))
	leaderboard.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	leaderboard.position = Vector2(1450.0, 28.0)
	leaderboard.size = Vector2(430.0, 390.0)
	root.add_child(leaderboard)
	message = _label(24, Color("#fff3c0"))
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.position = Vector2(520.0, 85.0)
	message.size = Vector2(880.0, 70.0)
	root.add_child(message)
	start_lights = _label(30, Color("#e63843"))
	start_lights.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_lights.position = Vector2(620.0, 170.0)
	start_lights.size = Vector2(680.0, 52.0)
	root.add_child(start_lights)
	center_readout = _label(34, Color("#f1f6f8"))
	center_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_readout.position = Vector2(790.0, 820.0)
	center_readout.size = Vector2(340.0, 170.0)
	root.add_child(center_readout)
	cockpit = CockpitDisplay.new()
	cockpit.position = Vector2(690.0, 690.0)
	cockpit.size = Vector2(540.0, 360.0)
	cockpit.visible = false
	root.add_child(cockpit)
	minimap = TrackMinimap.new()
	minimap.position = Vector2(28.0, 760.0)
	minimap.size = Vector2(250.0, 250.0)
	root.add_child(minimap)
	results_panel = PanelContainer.new()
	results_panel.position = Vector2(610.0, 190.0)
	results_panel.size = Vector2(700.0, 700.0)
	results_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.025, 0.04, 0.93)
	style.border_color = Color("#7194ae")
	style.set_border_width_all(2)
	results_panel.add_theme_stylebox_override("panel", style)
	results_text = _label(23, Color("#f2f5ed"))
	results_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	results_panel.add_child(results_text)
	root.add_child(results_panel)

func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.03, 0.88))
	return label

func _leaderboard_text(rows: Array, player_position: int) -> String:
	var lines := ["LIVE CLASSIFICATION"]
	for row in rows.slice(0, min(8, rows.size())):
		var marker := "›" if int(row.position) == player_position else " "
		lines.append("%s P%02d  %-10s  %s" % [marker, row.position, row.driver, "+%.1f" % float(row.penalty) if float(row.penalty) > 0.0 else ""])
	return "\n".join(lines)

func _results_text(rows: Array) -> String:
	var lines: Array[String] = []
	for row in rows:
		lines.append("P%02d  %-12s  %s  %s" % [row.position, row.driver, _format_time(float(row.time)), "+%.0fs" % float(row.penalty) if float(row.penalty) > 0.0 else ""])
	return "\n".join(lines)

func _format_time(seconds: float) -> String:
	if not is_finite(seconds) or seconds <= 0.0:
		return "--:--.---"
	var minutes := int(seconds / 60.0)
	var remainder := seconds - float(minutes) * 60.0
	return "%02d:%06.3f" % [minutes, remainder]

func _show_message(title: String, detail: String, duration: float) -> void:
	_current_message = "%s\n%s" % [title, detail]
	_message_timer = duration

func _on_lap(car: Node, _lap: int, lap_time: float, _valid: bool) -> void:
	if car == GameState.player_car:
		_last_lap = _format_time(lap_time)

func _on_sector(car: Node, sector: int, sector_time: float) -> void:
	if car == GameState.player_car and sector >= 0 and sector < _sector_text.size():
		_sector_text[sector] = "S%d %s" % [sector + 1, _format_time(sector_time)]

func _on_lights(lit: int, is_green: bool) -> void:
	if is_green:
		start_lights.text = "GO!"
	elif lit > 0:
		start_lights.text = "● ".repeat(lit) + "○ ".repeat(5 - lit)
	else:
		start_lights.text = ""
