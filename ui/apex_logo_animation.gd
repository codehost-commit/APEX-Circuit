class_name ApexLogoAnimation
extends Control
## Responsive, code-drawn APEX identity. The same stroke sequence is used for
## the launch reveal and the compact menu mark at every aspect ratio.

signal finished

const DESIGN_SIZE := Vector2(1000.0, 300.0)
const SILVER := Color("f4f5f6")
const RED := Color("f5222d")
const DARK_RED := Color("9e2830")

var progress := 1.0
var _duration := 2.4
var _running := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func play(duration := 2.4) -> void:
	_duration = maxf(duration, 0.1)
	progress = 0.0
	_running = true
	set_process(true)
	queue_redraw()

func finish_immediately() -> void:
	progress = 1.0
	_running = false
	set_process(false)
	queue_redraw()

func _process(delta: float) -> void:
	if not _running:
		return
	progress = minf(1.0, progress + delta / _duration)
	queue_redraw()
	if progress >= 1.0:
		_running = false
		set_process(false)
		finished.emit()

func _draw() -> void:
	var scale_factor := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	if scale_factor <= 0.0:
		return
	var origin := (size - DESIGN_SIZE * scale_factor) * 0.5
	draw_set_transform(origin, 0.0, Vector2.ONE * scale_factor)

	# A: the lead stroke travels from the lower left to the crown and down.
	_stroke(PackedVector2Array([Vector2(42,208),Vector2(128,38),Vector2(182,38),Vector2(229,208)]), _window(0.00,0.23), SILVER, 39.0)
	_stroke(PackedVector2Array([Vector2(88,132),Vector2(208,132)]), _window(0.14,0.27), SILVER, 25.0)

	# P: the top and curved bowl arrive first, then its stem drops down.
	var p_bowl := PackedVector2Array([Vector2(276,41),Vector2(366,41),Vector2(401,45),Vector2(422,65),Vector2(428,88),Vector2(420,111),Vector2(397,127),Vector2(361,132),Vector2(261,132)])
	_stroke(p_bowl, _window(0.20,0.43), SILVER, 39.0)
	_stroke(PackedVector2Array([Vector2(276,41),Vector2(238,208)]), _window(0.35,0.49), SILVER, 39.0)

	# E: upper, vertical, middle and lower strokes draw in reading order.
	_stroke(PackedVector2Array([Vector2(493,41),Vector2(655,41)]), _window(0.43,0.53), SILVER, 39.0)
	_stroke(PackedVector2Array([Vector2(493,41),Vector2(458,208)]), _window(0.50,0.63), SILVER, 39.0)
	_stroke(PackedVector2Array([Vector2(475,126),Vector2(615,126)]), _window(0.57,0.67), SILVER, 32.0)
	_stroke(PackedVector2Array([Vector2(458,208),Vector2(624,208)]), _window(0.63,0.72), SILVER, 39.0)

	# X: the silver slash draws down; the signature red slash flies upward.
	_stroke(PackedVector2Array([Vector2(709,42),Vector2(886,208)]), _window(0.67,0.82), SILVER, 39.0)
	_stroke(PackedVector2Array([Vector2(690,208),Vector2(898,39)]), _window(0.73,0.92), RED, 39.0)
	_stroke(PackedVector2Array([Vector2(858,72),Vector2(899,39)]), _window(0.87,0.94), DARK_RED, 39.0)

	# APEX completes before the widely spaced subtitle appears.
	var subtitle_alpha := smoothstep(0.86,1.0,progress)
	var subtitle := "C  I  R  C  U  I  T"
	var font := ApexStyle.display_font()
	var text_size := font.get_string_size(subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,42)
	draw_string(font,Vector2((DESIGN_SIZE.x-text_size.x)*0.5,278),subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,42,Color(SILVER,subtitle_alpha))
	draw_set_transform(Vector2.ZERO)

func _window(start: float, finish: float) -> float:
	return clampf((progress - start) / maxf(finish - start, 0.001),0.0,1.0)

func _stroke(points: PackedVector2Array, reveal: float, color: Color, width: float) -> void:
	if reveal <= 0.0 or points.size() < 2:
		return
	var total := 0.0
	for index in range(points.size() - 1):
		total += points[index].distance_to(points[index + 1])
	var remaining := total * reveal
	var visible_points := PackedVector2Array([points[0]])
	for index in range(points.size() - 1):
		var segment := points[index].distance_to(points[index + 1])
		if remaining >= segment:
			visible_points.append(points[index + 1])
			remaining -= segment
		elif remaining > 0.0:
			visible_points.append(points[index].lerp(points[index + 1],remaining / segment))
			break
		else:
			break
	if visible_points.size() >= 2:
		draw_polyline(visible_points,color,width,true)
