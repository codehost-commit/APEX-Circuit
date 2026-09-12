class_name RaceInstruments
extends Control
## Inputs, wheel loads and rev lights read the actual simulated powertrain.

var car: RaycastFormulaCar
var compact := false

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if car == null:
		return
	draw_style_box(ApexStyle.panel(0.84), Rect2(Vector2.ZERO, size))
	var font := get_theme_default_font()
	var width := size.x - 40.0
	var rev_fraction := clampf((car.rpm - car.tuning.idle_rpm) / maxf(car.tuning.rev_limit_rpm - car.tuning.idle_rpm, 1.0), 0.0, 1.0)
	for index in 20:
		var lit := rev_fraction >= float(index) / 20.0
		var color := Color("#25333b")
		if lit:
			color = ApexStyle.ACCENT if index < 11 else (Color("#ffd26d") if index < 16 else Color("#aa8dff"))
		if car.rpm >= car.tuning.upshift_rpm and int(Time.get_ticks_msec() / 90) % 2 == 0:
			color = ApexStyle.WHITE
		draw_rect(Rect2(20 + index * width / 20, 18, width / 20 - 3, 10), color)
	var gear := "R" if car.reverse_engaged else ("N" if car.gear <= 0 else str(car.gear))
	draw_string(font, Vector2(25, 112), gear, HORIZONTAL_ALIGNMENT_LEFT, -1, 82, ApexStyle.WHITE)
	draw_line(Vector2(100, 46), Vector2(100, 114), Color("#4d5e66"), 1)
	draw_string(font, Vector2(120, 101), "%03d" % int(car.speed_mps * 3.6), HORIZONTAL_ALIGNMENT_LEFT, -1, 63, ApexStyle.WHITE)
	draw_string(font, Vector2(265, 101), "KM/H", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, ApexStyle.MUTED)
	draw_string(font, Vector2(23, 143), "%05d RPM" % int(car.rpm), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ApexStyle.MUTED)
	var drs_color := ApexStyle.ACCENT if car.drs_available else ApexStyle.MUTED
	var drs := "DRS OPEN" if car.drs_open else ("DRS READY / F" if car.drs_available else "DRS CLOSED")
	draw_string(font, Vector2(200, 143), drs, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, drs_color)
	if compact:
		return
	_bar(font, 174, "THR", car.throttle_input, ApexStyle.ACCENT)
	_bar(font, 201, "BRK", car.brake_input, ApexStyle.RED)
	var steer_x := 74.0 + (width - 55.0) * 0.5
	draw_string(font, Vector2(22, 245), "STR", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ApexStyle.MUTED)
	draw_line(Vector2(74, 239), Vector2(size.x - 22, 239), Color("#344650"), 5)
	draw_line(Vector2(steer_x, 235), Vector2(steer_x, 244), ApexStyle.MUTED, 1)
	draw_circle(Vector2(steer_x + car.steering_input * (width - 55) * 0.5, 239), 4, ApexStyle.WHITE)
	if GameState.telemetry_enabled:
		var telemetry: Dictionary = car.get_telemetry() if car.has_method("get_telemetry") else {}
		var wheels: Array = telemetry.get("wheels", car.get("_wheels"))
		for index in mini(4, wheels.size()):
			var wheel: Dictionary = wheels[index]
			var x := 22.0 + float(index % 2) * 183.0
			var y := 266.0 + floorf(float(index) / 2.0) * 41.0
			var surface := String(wheel.get("surface", car.current_surface))
			var slip := absf(float(wheel.get("slip_ratio", 0.0))) + absf(float(wheel.get("slip_angle", 0.0)))
			var color := ApexStyle.RED if slip > 0.25 else (Color("#ffd26d") if surface != "asphalt" else ApexStyle.ACCENT)
			draw_rect(Rect2(x, y, 10, 26), color)
			draw_string(font, Vector2(x + 17, y + 10), "%s  %s" % [wheel.get("name", ""), surface.to_upper()], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)
			draw_string(font, Vector2(x + 17, y + 27), "%.1fkN   SLIP %.0f%%" % [float(wheel.get("normal_force", 0.0)) / 1000.0, slip * 100.0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ApexStyle.MUTED)
		draw_string(font, Vector2(22, 368), "DAMAGE %02d%%   LAT %+.1fG   LONG %+.1fG" % [int(car.damage * 100), car.lateral_g, car.longitudinal_g], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ApexStyle.RED if car.damage > 0.5 else ApexStyle.MUTED)

func _bar(font: Font, y: float, text: String, amount: float, color: Color) -> void:
	draw_string(font, Vector2(22, y + 9), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ApexStyle.MUTED)
	draw_rect(Rect2(74, y, size.x - 96, 8), Color("#263943"))
	draw_rect(Rect2(74, y, (size.x - 96) * clampf(amount, 0, 1), 8), color)
