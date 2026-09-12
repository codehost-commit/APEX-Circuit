class_name CockpitDisplay
extends Control
## A readable wheel display used only with the cockpit camera.

var car: RaycastFormulaCar

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if car == null:
		return
	var centre := Vector2(size.x * 0.5, size.y * 0.62)
	var radius := minf(size.x * 0.27, size.y * 0.28)
	var wheel_color := Color("#10141a")
	draw_circle(centre, radius, wheel_color)
	draw_arc(centre, radius, PI * 0.12, PI * 0.88, 24, Color("#c9d2d7"), 5.0, true)
	draw_arc(centre, radius, PI * 1.12, PI * 1.88, 24, Color("#c9d2d7"), 5.0, true)
	var rotation := car.steering_input * 0.48
	var spoke := Vector2(sin(rotation), -cos(rotation)) * radius * 0.74
	draw_line(centre, centre + spoke, Color("#dce4e7"), 7.0, true)
	draw_line(centre, centre + spoke.rotated(2.35), Color("#dce4e7"), 7.0, true)
	draw_line(centre, centre + spoke.rotated(-2.35), Color("#dce4e7"), 7.0, true)
	var display := Rect2(centre - Vector2(radius * 0.43, radius * 0.29), Vector2(radius * 0.86, radius * 0.58))
	draw_rect(display, Color("#071017"), true)
	draw_rect(display, Color("#778f9e"), false, 2.0)
	var font := get_theme_default_font()
	var gear_text := "N" if car.gear <= 0 else str(car.gear)
	draw_string(font, display.position + Vector2(display.size.x * 0.34, display.size.y * 0.48), gear_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(radius * 0.48), Color("#f5f7e9"))
	draw_string(font, display.position + Vector2(11.0, display.size.y - 9.0), "%03d KM/H" % int(car.speed_mps * 3.6), HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(radius * 0.15), Color("#b9d9ed"))
	var led_y := centre.y - radius * 1.18
	for index in 10:
		var amount := float(index + 1) / 10.0
		var lit := car.rpm / car.tuning.rev_limit_rpm >= amount * 0.72
		var color := Color("#1f3529")
		if lit:
			color = Color("#4cde72") if index < 5 else (Color("#f2d343") if index < 8 else Color("#e8454d"))
		draw_rect(Rect2(centre.x - radius + float(index) * radius * 0.2, led_y, radius * 0.14, radius * 0.11), color, true)
	if car.drs_open:
		draw_string(font, Vector2(centre.x - 18.0, led_y - 10.0), "DRS", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color("#66ef9d"))
