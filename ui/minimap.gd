class_name TrackMinimap
extends Control

var circuit: CircuitTrack
var cars: Array[RaycastFormulaCar] = []
var bounds := Rect2(-170.0, -155.0, 340.0, 300.0)
var _outline := PackedVector2Array()
var _cached_size := Vector2.ZERO

func setup(track_value: CircuitTrack, field: Array[RaycastFormulaCar]) -> void:
	circuit = track_value
	cars = field
	_recalculate_bounds()
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _recalculate_bounds() -> void:
	if circuit == null:
		return
	var min_x := INF
	var min_z := INF
	var max_x := -INF
	var max_z := -INF
	for point in circuit.centerline:
		min_x = minf(min_x, point.x)
		min_z = minf(min_z, point.z)
		max_x = maxf(max_x, point.x)
		max_z = maxf(max_z, point.z)
	bounds = Rect2(min_x, min_z, max_x - min_x, max_z - min_z).grow(18.0)

func _draw() -> void:
	draw_style_box(_panel_style(), Rect2(Vector2.ZERO, size))
	if circuit == null:
		return
	if _cached_size != size or _outline.is_empty():
		_cached_size = size
		_outline.clear()
		for index in range(0, circuit.centerline.size(), 3):
			_outline.append(_map(circuit.centerline[index]))
		_outline.append(_outline[0])
	draw_polyline(_outline, Color("#24363e"), 8.0, true)
	draw_polyline(_outline, Color("#bfccd0"), 3.0, true)
	for zone in circuit.drs_zones:
		var points := PackedVector2Array()
		for index in 20:
			points.append(_map(circuit.sample_at_distance(lerpf(zone.x, zone.y, float(index) / 19)).position))
		draw_polyline(points, ApexStyle.ACCENT, 3.0, true)
	for index in 3:
		var distance := float(circuit.sector_distances[index]) if index < 2 else 0.0
		var dot := _map(circuit.sample_at_distance(distance).position)
		draw_circle(dot, 4.0, Color("#b69bff") if index < 2 else ApexStyle.WHITE)
		draw_string(get_theme_default_font(), dot + Vector2(5,-5), "S%d" % (index + 1) if index < 2 else "START", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ApexStyle.WHITE)
	for car in cars:
		if not is_instance_valid(car) or not car.visible:
			continue
		var dot := _map(car.global_position)
		var color := Color("#ffffff") if car.player_controlled else car.livery_color
		draw_circle(dot, 4.4 if car.player_controlled else 3.0, color)
		if car.player_controlled:
			var direction := Vector2(-car.global_basis.z.x, -car.global_basis.z.z).normalized()
			draw_line(dot, dot + direction * 10, color, 2, true)

func _map(world_position: Vector3) -> Vector2:
	var relative := Vector2(world_position.x - bounds.position.x, world_position.z - bounds.position.y)
	var scale := minf((size.x - 40.0) / maxf(bounds.size.x, 1.0), (size.y - 40.0) / maxf(bounds.size.y, 1.0))
	var drawing_size := bounds.size * scale
	var origin := (size - drawing_size) * 0.5
	return origin + relative * scale

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.055, 0.82)
	style.border_color = Color("#6387a7")
	style.set_border_width_all(1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style
