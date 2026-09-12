class_name ApexStyle
extends RefCounted

const INK := Color("#0b131b")
const WHITE := Color("#f1f4ef")
const MUTED := Color("#99abb4")
const ACCENT := Color("#a8f06b")
const RED := Color("#ff6760")

static func label(text: String, font_size := 20, color := WHITE) -> Label:
	var value := Label.new()
	value.text = text
	value.add_theme_font_size_override("font_size", font_size)
	value.add_theme_color_override("font_color", color)
	value.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.05, 0.70))
	value.add_theme_constant_override("outline_size", 2)
	return value

static func panel(alpha := 0.91, border := Color("#34424b")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(INK, alpha)
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style

static func button(text: String, prominent := false) -> Button:
	var value := Button.new()
	value.text = text
	value.custom_minimum_size = Vector2(0, 64)
	value.alignment = HORIZONTAL_ALIGNMENT_LEFT
	value.add_theme_font_size_override("font_size", 23)
	value.add_theme_color_override("font_color", INK if prominent else WHITE)
	var normal := panel(0.78)
	if prominent:
		normal.bg_color = ACCENT
		normal.border_color = ACCENT
	value.add_theme_stylebox_override("normal", normal)
	var hover := panel(0.96, ACCENT)
	hover.bg_color = Color("#263d36")
	value.add_theme_stylebox_override("hover", hover)
	value.add_theme_stylebox_override("focus", panel(0.1, WHITE))
	value.add_theme_stylebox_override("pressed", panel(0.98, WHITE))
	value.add_theme_color_override("font_hover_color", WHITE)
	return value

static func settings_content() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.add_child(label("DRIVING & DISPLAY", 27))
	box.add_child(label("Changes apply immediately to your car.", 17, MUTED))
	var player := GameState.player_car as RaycastFormulaCar
	if player != null:
		for entry in [["Automatic gears", "auto_shift"], ["Traction control", "traction_control"], ["Anti-lock brakes", "abs_enabled"]]:
			var check := CheckButton.new()
			check.text = entry[0]
			check.add_theme_font_size_override("font_size", 21)
			check.button_pressed = bool(player.tuning.get(entry[1]))
			var property := String(entry[1])
			check.toggled.connect(func(value: bool) -> void:
				player.tuning.set(property, value)
				_save_settings())
			box.add_child(check)
	var ghost := CheckButton.new()
	ghost.text = "Personal-best ghost (G)"
	ghost.button_pressed = GameState.ghost_enabled
	ghost.add_theme_font_size_override("font_size", 21)
	ghost.toggled.connect(func(value: bool) -> void:
		GameState.ghost_enabled = value
		_save_settings())
	box.add_child(ghost)
	var telemetry := CheckButton.new()
	telemetry.text = "Tyre and input telemetry"
	telemetry.button_pressed = GameState.telemetry_enabled
	telemetry.add_theme_font_size_override("font_size", 21)
	telemetry.toggled.connect(func(value: bool) -> void:
		GameState.telemetry_enabled = value
		_save_settings())
	box.add_child(telemetry)
	box.add_child(label("KEYBOARD", 17, ACCENT))
	box.add_child(label("W / S  throttle / brake    A / D  steer\nQ / E  gear down / up    F  hold DRS\nSpace  handbrake    R  recover\nC  camera    G  ghost    Esc  pause", 19, MUTED))
	box.add_child(label("CONTROLLER", 17, ACCENT))
	box.add_child(label("Left stick  steer    RT / LT  throttle / brake\nX  DRS    LB / RB  shift    Y  camera\nA  handbrake    Start  pause    Back  recover", 19, MUTED))
	return box

static func _save_settings() -> void:
	var config := ConfigFile.new()
	var player := GameState.player_car as RaycastFormulaCar
	if player != null:
		for property in ["auto_shift", "traction_control", "abs_enabled"]:
			config.set_value("driving", property, player.tuning.get(property))
	config.set_value("display", "ghost", GameState.ghost_enabled)
	config.set_value("display", "telemetry", GameState.telemetry_enabled)
	config.save("user://apex_settings.cfg")

static func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://apex_settings.cfg") != OK:
		return
	var player := GameState.player_car as RaycastFormulaCar
	if player != null:
		for property in ["auto_shift", "traction_control", "abs_enabled"]:
			player.tuning.set(property, config.get_value("driving", property, player.tuning.get(property)))
	GameState.ghost_enabled = config.get_value("display", "ghost", true)
	GameState.telemetry_enabled = config.get_value("display", "telemetry", true)
