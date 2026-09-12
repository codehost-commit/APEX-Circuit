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

func _process(delta: float) -> void:
	if car == null:
		return
	_sample_time += delta
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
	draw_style_box(ApexStyle.panel(0.88), Rect2(Vector2.ZERO, size))
	var center := Vector2(size.x * 0.5, 128)
	var font := ApexStyle.mono_font()
	draw_string(ApexStyle.body_font(), Vector2(20, 25), "VEHICLE DYNAMICS", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, ApexStyle.MUTED)
	for radius in [29.0, 58.0, 87.0]:
		draw_arc(center, radius, 0, TAU, 96, Color(0.7, 0.8, 0.85, 0.15), 1, true)
	draw_line(center - Vector2(82, 0), center + Vector2(82, 0), Color(0.7, 0.8, 0.85, 0.13), 1, true)
	draw_line(center - Vector2(0, 82), center + Vector2(0, 82), Color(0.7, 0.8, 0.85, 0.13), 1, true)
	_ring(center, 96, -PI * 0.5, car.throttle_input, BLUE)
	_ring(center, 104, -PI * 0.5, car.brake_input, GREEN)
	_ring(center, 112, -PI * 0.5, Vector2(car.lateral_g, car.longitudinal_g).length() / FULL_SCALE_G, YELLOW)
	# Top-down open-wheel silhouette with four tyres, wings and monocoque.
	var body := PackedVector2Array([Vector2(-3,-45),Vector2(3,-45),Vector2(7,-12),Vector2(13,8),Vector2(9,31),Vector2(-9,31),Vector2(-13,8),Vector2(-7,-12)])
	for i in body.size():
		body[i] += center
	draw_colored_polygon(body, Color("91a8b8"))
	for side in [-1, 1]:
		for y in [-25, 26]:
			draw_style_box(ApexStyle.panel(1.0), Rect2(center + Vector2(side * 22 - 6, y - 10), Vector2(12, 20)))
			draw_line(center + Vector2(side * 6,y), center + Vector2(side * 22,y), ApexStyle.MUTED, 2, true)
	draw_rect(Rect2(center + Vector2(-27,-39),Vector2(54,5)), ApexStyle.MUTED)
	draw_rect(Rect2(center + Vector2(-23,36),Vector2(46,6)), ApexStyle.MUTED)
	draw_circle(center + Vector2(0,2),5, ApexStyle.INK)
	for i in _trail.size():
		draw_circle(center + _trail[i] * 85, 2.0, Color(YELLOW, float(i) / 28.0))
	var point := center + g_point() * 85
	draw_circle(point, 10, Color(YELLOW, 0.16))
	draw_circle(point, 5, YELLOW)
	draw_circle(point, 2, ApexStyle.WHITE)
	draw_string(font, Vector2(20, 269), "THROTTLE %3d%%" % int(car.throttle_input * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, BLUE)
	draw_string(font, Vector2(190, 269), "BRAKE %3d%%" % int(car.brake_input * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, GREEN)
	draw_string(font, Vector2(20, 294), "%.2f G" % Vector2(car.lateral_g, car.longitudinal_g).length(), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, YELLOW)
	draw_string(font, Vector2(160, 294), "5 G FULL SCALE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ApexStyle.MUTED)

func _ring(center: Vector2, radius: float, start: float, amount: float, color: Color) -> void:
	draw_arc(center, radius, 0, TAU, 120, Color(color, 0.12), 4, true)
	if amount > 0.001:
		draw_arc(center, radius, start, start + TAU * clampf(amount, 0, 1), 120, color, 4, true)
