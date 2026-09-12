class_name CockpitDisplay
extends Control
## Readable cockpit-only steering wheel and instrument panel.

var car: RaycastFormulaCar

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if car == null:
		return
	var centre := size * Vector2(0.5, 0.62)
	draw_set_transform(centre, car.steering_input * 0.5)
	var wheel := PackedVector2Array([Vector2(-180,-65), Vector2(-145,-96), Vector2(-113,-75), Vector2(113,-75), Vector2(145,-96), Vector2(180,-65), Vector2(185,38), Vector2(138,69), Vector2(104,53), Vector2(-104,53), Vector2(-138,69), Vector2(-185,38)])
	draw_colored_polygon(wheel, Color("#151d23"))
	draw_polyline(wheel, Color("#56656c"), 3, true)
	draw_line(Vector2(-148,-57), Vector2(-148,32), Color("#03090d"), 34, true)
	draw_line(Vector2(148,-57), Vector2(148,32), Color("#03090d"), 34, true)
	for side in [-1, 1]:
		draw_circle(Vector2(112 * side,-26), 10, ApexStyle.RED if side < 0 else ApexStyle.ACCENT)
		draw_circle(Vector2(109 * side,16), 8, Color("#399ecd"))
	draw_rect(Rect2(-91,-70,182,109), Color("#041316"))
	draw_rect(Rect2(-91,-70,182,109), Color("#59777b"), false, 2)
	var font := get_theme_default_font()
	draw_string(font, Vector2(-17,-6), "R" if car.reverse_engaged else str(car.gear), HORIZONTAL_ALIGNMENT_LEFT, -1, 53, ApexStyle.WHITE)
	draw_string(font, Vector2(-66,26), "%03d KM/H" % int(car.speed_mps * 3.6), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, ApexStyle.WHITE)
	draw_string(font, Vector2(-76,-51), "%05d RPM" % int(car.rpm), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ApexStyle.ACCENT)
	var fraction := clampf((car.rpm - car.tuning.idle_rpm) / (car.tuning.rev_limit_rpm - car.tuning.idle_rpm), 0, 1)
	for index in 15:
		var color := Color("#25363a")
		if fraction >= float(index) / 15:
			color = ApexStyle.ACCENT if index < 8 else (Color("#ffd46c") if index < 12 else Color("#ac91ff"))
		draw_circle(Vector2(-85 + index * 12, -84), 4, color)
	if car.drs_available:
		draw_string(font, Vector2(-34,61), "DRS OPEN" if car.drs_open else "DRS READY", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ApexStyle.ACCENT)
	draw_set_transform(Vector2.ZERO)
