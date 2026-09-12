class_name ApexMenu
extends CanvasLayer

signal qualifying_requested
signal race_requested
signal time_trial_requested
signal quit_requested

var _root: Control
var _floating: VBoxContainer
var _overlay: PanelContainer
var _elapsed := 0.0
var _live: Label

func _ready() -> void:
	layer = 5
	ApexStyle.load_settings()
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){ float shade = mix(0.88, 0.0, smoothstep(0.04, 0.68, UV.x)); COLOR = vec4(0.018, 0.031, 0.038, shade); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	shade.material = material
	_root.add_child(shade)
	_floating = VBoxContainer.new()
	_floating.position = Vector2(94, 118)
	_floating.size.x = 505
	_floating.add_theme_constant_override("separation", 15)
	_root.add_child(_floating)
	_floating.add_child(ApexStyle.brand_logo(Vector2(505,200)))
	var tagline := ApexStyle.label("CHASE THE NEXT TENTH.", 30, ApexStyle.MUTED)
	tagline.add_theme_font_override("font", ApexStyle.display_font())
	_floating.add_child(tagline)
	var gap := Control.new()
	gap.custom_minimum_size.y = 35
	_floating.add_child(gap)
	_add_button("01     TIME TRIAL", func() -> void: time_trial_requested.emit(), true)
	_add_button("02     RACE WEEKEND", func() -> void: qualifying_requested.emit())
	_add_button("03     QUICK RACE", func() -> void: race_requested.emit())
	_add_button("04     SETTINGS & CONTROLS", _show_settings)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 14)
	_floating.add_child(bottom)
	var credits := ApexStyle.button("CREDITS")
	credits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credits.pressed.connect(_show_credits)
	bottom.add_child(credits)
	var quit := ApexStyle.button("QUIT")
	quit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quit.pressed.connect(func() -> void: quit_requested.emit())
	bottom.add_child(quit)
	_live = ApexStyle.label("LIVE  /  FLYING LAPS", 19, ApexStyle.WHITE)
	_live.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_live.position = Vector2(-440, 48)
	_live.size.x = 350
	_live.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_live)
	_overlay = PanelContainer.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_overlay.position = Vector2(-350, -430)
	_overlay.size = Vector2(700, 860)
	_overlay.add_theme_stylebox_override("panel", ApexStyle.panel(0.98))
	_overlay.visible = false
	_root.add_child(_overlay)

func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	_floating.position.y = 118 + sin(_elapsed * 0.48) * 4.0
	_live.modulate.a = 0.75 + 0.25 * sin(_elapsed * 1.5)
	if Input.is_action_just_pressed("pause") and _overlay.visible:
		_overlay.visible = false

func _add_button(text: String, callback: Callable, primary := false) -> void:
	var button := ApexStyle.button(text, primary)
	button.pressed.connect(callback)
	_floating.add_child(button)

func _clear_overlay() -> void:
	for child in _overlay.get_children():
		_overlay.remove_child(child)
		child.queue_free()
	_overlay.visible = true

func _show_settings() -> void:
	_clear_overlay()
	var content := ApexStyle.settings_content()
	_overlay.add_child(content)
	var close := ApexStyle.button("BACK", true)
	close.pressed.connect(func() -> void: _overlay.visible = false)
	content.add_child(close)

func _show_credits() -> void:
	_clear_overlay()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 28)
	_overlay.add_child(box)
	box.add_child(ApexStyle.brand_logo(Vector2(560,100)))
	box.add_child(ApexStyle.label("THE APEX TEAM", 25, ApexStyle.ACCENT))
	var text := ApexStyle.label("Rahul Awasthi - Game Development Head\nPritam Avuthu - Marketing Head\n\nCC0 textures from Poly Haven:\nAsphalt Track / Dimitrios Savva\nGrass Ground / Charlotte Baglioni\nGravel Floor / Jenelle van Heerden & Matterfield\nSky / Greg Zaal & Jarod Guest\n\nTree models / Rico Cilliers & Rob Tuytel\nFonts / Google Fonts (SIL Open Font License)\nCar and circuit geometry created for APEX Circuit.\nNo affiliation with any official racing championship.\nFull source links: assets/ATTRIBUTIONS.md", 21, ApexStyle.MUTED)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(text)
	var close := ApexStyle.button("BACK", true)
	close.pressed.connect(func() -> void: _overlay.visible = false)
	box.add_child(close)
