extends Control
## One live display texture on the physical steering wheel, in every camera.
var car: RaycastFormulaCar

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if car == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("061013"))
	var mono := ApexStyle.mono_font()
	var label_font := ApexStyle.body_font()
	draw_texture_rect(preload("res://assets/branding/apex-circuit-dark.png"),Rect2(18,7,108,36),false)
	draw_string(mono, Vector2(190, 149), "R" if car.reverse_engaged else str(car.gear), HORIZONTAL_ALIGNMENT_LEFT, -1, 106, ApexStyle.WHITE)
	draw_string(mono, Vector2(22, 85), "%03d" % ApexStyle.speed_value(car.speed_mps), HORIZONTAL_ALIGNMENT_LEFT, -1, 36, ApexStyle.WHITE)
	draw_string(label_font, Vector2(22, 111), ApexStyle.speed_suffix(), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ApexStyle.MUTED)
	draw_string(label_font, Vector2(320, 62), "LAP %02d" % (car.lap + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, ApexStyle.WHITE)
	draw_string(mono, Vector2(319, 103), "%05d" % car.rpm, HORIZONTAL_ALIGNMENT_LEFT, -1, 27, ApexStyle.ACCENT)
	draw_string(label_font, Vector2(324, 130), "RPM", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ApexStyle.MUTED)
	draw_line(Vector2(20, 173),Vector2(492,173),Color("30454c"),2)
	draw_string(label_font, Vector2(20, 216), "DRS OPEN" if car.drs_open else ("DRS READY" if car.drs_available else "DRS CLOSED"), HORIZONTAL_ALIGNMENT_LEFT, -1, 25, ApexStyle.ACCENT if car.drs_available else ApexStyle.MUTED)
	draw_string(label_font, Vector2(315, 216), "BB %.1f" % (car.tuning.brake_front_bias * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 25, ApexStyle.WHITE)
