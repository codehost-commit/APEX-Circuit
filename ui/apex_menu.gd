class_name ApexMenu
extends CanvasLayer

signal qualifying_requested
signal race_requested
signal quit_requested

func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.008, 0.015, 0.024, 0.60)
	shade.position = Vector2(0.0, 0.0)
	shade.size = Vector2(650.0, 1080.0)
	root.add_child(shade)
	var title := Label.new()
	title.text = "APEX\nCIRCUIT"
	title.position = Vector2(54.0, 58.0)
	title.add_theme_font_size_override("font_size", 62)
	title.add_theme_color_override("font_color", Color("#f3f7f5"))
	title.add_theme_constant_override("outline_size", 9)
	title.add_theme_color_override("font_outline_color", Color("#0a121a"))
	root.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "ORIGINAL OPEN-WHEEL SIMULATION"
	subtitle.position = Vector2(60.0, 210.0)
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color("#79c7e7"))
	root.add_child(subtitle)
	var qualify := _button("QUALIFYING", Vector2(60.0, 320.0))
	qualify.pressed.connect(func() -> void: qualifying_requested.emit())
	root.add_child(qualify)
	var race := _button("RACE  ·  SKIP QUALIFYING", Vector2(60.0, 395.0))
	race.pressed.connect(func() -> void: race_requested.emit())
	root.add_child(race)
	var quit := _button("QUIT", Vector2(60.0, 470.0))
	quit.pressed.connect(func() -> void: quit_requested.emit())
	root.add_child(quit)
	var help := Label.new()
	help.text = "WASD / ARROWS  DRIVE\nQ / E  SHIFT     F  DRS     C  CAMERA\nESC  PAUSE"
	help.position = Vector2(60.0, 835.0)
	help.add_theme_font_size_override("font_size", 15)
	help.add_theme_color_override("font_color", Color("#b4c2ca"))
	root.add_child(help)

func _button(text_value: String, position_value: Vector2) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = position_value
	button.size = Vector2(390.0, 58.0)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color("#edf4f3"))
	button.add_theme_color_override("font_hover_color", Color("#6fe3ff"))
	button.add_theme_stylebox_override("normal", _style(Color(0.025, 0.06, 0.085, 0.76), Color("#42657a")))
	button.add_theme_stylebox_override("hover", _style(Color(0.04, 0.12, 0.16, 0.92), Color("#75e2ff")))
	button.add_theme_stylebox_override("pressed", _style(Color(0.02, 0.03, 0.05, 0.95), Color("#d8f6ff")))
	return button

func _style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 18.0
	return style
