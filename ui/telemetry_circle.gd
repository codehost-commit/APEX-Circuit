class_name TelemetryCircle
extends Control
## Acceleration in the car's reference frame, measured by the physics integrator.
const BLUE := Color("39aaff")
const GREEN := Color("77ed91")
const YELLOW := Color("ffda65")
const FULL_SCALE_G := 5.0
var car: RaycastFormulaCar
var _trail: Array[Vector2] = []
var _sample_time := 0.0
var _peak_g := 0.0

func _ready() -> void:
	EventBus.session_started.connect(func(_mode: int) -> void: _reset_trace())
	EventBus.player_reset.connect(func(_car: Node) -> void: _reset_trace())

func _reset_trace() -> void:
	_trail.clear()
	_peak_g = 0.0

func _process(delta: float) -> void:
	if car == null:
		return
	_sample_time += delta
	if not GameState.paused:
		_peak_g = maxf(_peak_g, Vector2(car.lateral_g, car.longitudinal_g).length())
	if _sample_time >= 0.04 and not GameState.paused:
		_sample_time = 0.0
		_trail.append(g_point())
		if _trail.size() > 18:
			_trail.pop_front()
	queue_redraw()

func g_point() -> Vector2:
	# Positive longitudinal acceleration moves upwards; braking moves downwards.
	return Vector2(car.lateral_g, -car.longitudinal_g).limit_length(FULL_SCALE_G) / FULL_SCALE_G

func _draw() -> void:
	if car == null:
		return
	var center := Vector2(size.x * 0.5, 138)
	var magnitude := Vector2(car.lateral_g, car.longitudinal_g).length()
	var rim := Color(0.72, 0.77, 0.80, 0.48)
	draw_circle(center, 127, Color(0.025, 0.035, 0.04, 0.65))
	draw_arc(center, 127, 0, TAU, 128, Color(0.03, 0.04, 0.04, 0.85), 4, true)
	draw_arc(center, 123, 0, TAU, 128, rim, 1.5, true)
	# One annulus split into three sectors, matching the supplied reference.
	_sector(center, -219, -42, car.throttle_input, BLUE)
	_sector(center, -39, 63, car.brake_input, GREEN)
	_sector(center, 66, 138, magnitude / FULL_SCALE_G, YELLOW, true)
	draw_arc(center, 101, 0, TAU, 128, rim, 1.5, true)
	_arc_text(center, "THROTTLE", -139, 112, false)
	_arc_text(center, "BRAKE", 12, 112, false)
	_arc_text(center, "G FORCE", 102, 112, true)
	for radius in [25.0, 49.0, 73.0, 94.0]:
		draw_arc(center, radius, 0, TAU, 96, Color(0.65, 0.70, 0.73, 0.30), 2, true)
	draw_line(center - Vector2(94, 0), center + Vector2(94, 0), Color(0.7, 0.75, 0.78, 0.25), 1, true)
	draw_line(center - Vector2(0, 94), center + Vector2(0, 94), Color(0.7, 0.75, 0.78, 0.25), 1, true)
	# Top-down open-wheel silhouette with four tyres, wings and monocoque.
	var body := PackedVector2Array([Vector2(-3,-45),Vector2(3,-45),Vector2(7,-12),Vector2(13,8),Vector2(9,31),Vector2(-9,31),Vector2(-13,8),Vector2(-7,-12)])
	for i in body.size():
		body[i] = body[i] * 1.5 + center
	draw_colored_polygon(body, Color(0.65,0.69,0.71,0.65))
	for side in [-1, 1]:
		for y in [-25, 26]:
			draw_style_box(ApexStyle.panel(1.0), Rect2(center + Vector2(side * 30 - 8, y * 1.5 - 14), Vector2(16, 28)))
			draw_line(center + Vector2(side * 8,y * 1.5), center + Vector2(side * 30,y * 1.5), ApexStyle.MUTED, 2, true)
	draw_rect(Rect2(center + Vector2(-37,-59),Vector2(74,6)), ApexStyle.MUTED)
	draw_rect(Rect2(center + Vector2(-32,54),Vector2(64,7)), ApexStyle.MUTED)
	draw_circle(center + Vector2(0,2),5, ApexStyle.INK)
	for i in _trail.size():
		draw_circle(center + _trail[i] * 85, 2.0, Color(1.0,0.48,0.13,float(i) / 45.0))
	var point := center + g_point() * 85
	draw_circle(point, 10, Color(1.0,0.45,0.08,0.22))
	draw_circle(point, 6, Color("ff9839"))
	draw_circle(point, 2, ApexStyle.WHITE)
	var readout := Rect2(center.x - 83, 267, 166, 42)
	draw_style_box(ApexStyle.panel(0.70), readout)
	var font := ApexStyle.mono_font()
	draw_string(font, Vector2(center.x - 72, 296), "%.1f" % magnitude, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
	draw_string(font, Vector2(center.x + 8, 296), "%.1f" % maxf(_peak_g,magnitude), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, ApexStyle.RED)
	draw_string(ApexStyle.body_font(), Vector2(center.x - 69, 307), "G", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ApexStyle.MUTED)
	draw_string(ApexStyle.body_font(), Vector2(center.x + 12, 307), "PEAK G", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ApexStyle.MUTED)

func _sector(center: Vector2, start: float, end: float, amount: float, color: Color, reverse := false) -> void:
	draw_arc(center, 112, deg_to_rad(start), deg_to_rad(end), 80, Color(0.60,0.65,0.66,0.18), 19, true)
	var first := end if reverse else start
	var last := lerpf(first, start if reverse else end, clampf(amount,0,1))
	if amount > 0.001:
		var points := PackedVector2Array()
		for step in 65:
			points.append(center + Vector2.from_angle(deg_to_rad(lerpf(first,last,float(step)/64))) * 112)
		draw_polyline(points, color, 19, true)
	for angle in [start,end]:
		var radial := Vector2.from_angle(deg_to_rad(angle))
		draw_line(center + radial * 102,center + radial * 122,Color(0.7,0.75,0.78,0.5),1,true)

func _arc_text(center: Vector2, text: String, middle_angle: float, radius: float, reverse: bool) -> void:
	var font := ApexStyle.body_font()
	var width := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x
	var cursor := -width * 0.5
	for letter in text:
		var advance := font.get_string_size(letter,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x
		var angle := deg_to_rad(middle_angle) + (cursor + advance * 0.5) / radius * (-1 if reverse else 1)
		draw_set_transform(center + Vector2.from_angle(angle) * radius, angle + (-PI * 0.5 if reverse else PI * 0.5))
		draw_string(font, Vector2(-advance * 0.5,5),letter,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color.WHITE)
		cursor += advance
	draw_set_transform(Vector2.ZERO)
