class_name CircuitTrack
extends Node3D
## Original closed circuit generated from text data. Replace visual blocks, not its gameplay API.

@export var centerline := PackedVector3Array([
	Vector3(8.0, 0.0, 122.0), Vector3(-76.0, 0.0, 116.0), Vector3(-142.0, 0.0, 66.0),
	Vector3(-158.0, 0.0, -31.0), Vector3(-106.0, 0.0, -112.0), Vector3(-18.0, 0.0, -143.0),
	Vector3(79.0, 0.0, -128.0), Vector3(147.0, 0.0, -70.0), Vector3(158.0, 0.0, 24.0),
	Vector3(113.0, 0.0, 98.0), Vector3(42.0, 0.0, 130.0)
])

var total_length := 0.0
var _segment_lengths := PackedFloat32Array()
var _cumulative_lengths := PackedFloat32Array()
var racing_line: Path3D
var checkpoints: Array[Area3D] = []
var sector_distances := PackedFloat32Array()

const SURFACES := {
	"asphalt": {"name": "asphalt", "grip": 1.0, "drag": 1.0, "legal": true},
	"kerb": {"name": "kerb", "grip": 0.85, "drag": 1.05, "legal": true},
	"grass": {"name": "grass", "grip": 0.40, "drag": 2.4, "legal": false},
	"gravel": {"name": "gravel", "grip": 0.35, "drag": 4.8, "legal": false}
}

func _ready() -> void:
	_build_distance_cache()
	_build_visual_and_collision()
	_build_racing_line()
	_build_checkpoints()

func _build_distance_cache() -> void:
	total_length = 0.0
	_segment_lengths.clear()
	_cumulative_lengths.clear()
	for index in centerline.size():
		_cumulative_lengths.append(total_length)
		var length := centerline[index].distance_to(centerline[(index + 1) % centerline.size()])
		_segment_lengths.append(length)
		total_length += length
	sector_distances = PackedFloat32Array([total_length / 3.0, total_length * 2.0 / 3.0, total_length])

func _build_visual_and_collision() -> void:
	var grass := MeshInstance3D.new()
	grass.name = "GrassInfield"
	var grass_mesh := BoxMesh.new()
	grass_mesh.size = Vector3(410.0, 0.16, 410.0)
	grass.mesh = grass_mesh
	grass.position.y = -0.16
	grass.material_override = _material(Color("#263d29"), 0.96, 0.0)
	add_child(grass)
	_add_static_box(Vector3(0.0, -0.28, 0.0), Vector3(410.0, 0.30, 410.0), "grass")
	for index in centerline.size():
		var first := centerline[index]
		var second := centerline[(index + 1) % centerline.size()]
		_add_road_piece(first, second, RaceConfig.track_width, Color("#25282d"), "asphalt", 0.02)
		_add_road_piece(first, second, RaceConfig.track_width + RaceConfig.kerb_width * 2.0, Color("#c6c7c3"), "kerb", -0.025)
		_add_kerb_stripes(first, second)
	_add_start_finish()

func _add_road_piece(first: Vector3, second: Vector3, width: float, color: Color, surface: String, y: float) -> void:
	var length := first.distance_to(second) + 0.45
	var midpoint := (first + second) * 0.5 + Vector3.UP * y
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = "%s_Surface" % surface.capitalize()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, 0.13, length)
	mesh_node.mesh = mesh
	mesh_node.position = midpoint
	mesh_node.rotation.y = atan2(second.x - first.x, second.z - first.z)
	mesh_node.material_override = _material(color, 0.86, 0.03)
	add_child(mesh_node)
	_add_static_box(midpoint - Vector3.UP * 0.10, Vector3(width, 0.13, length), surface, mesh_node.rotation.y)

func _add_static_box(position_value: Vector3, size: Vector3, surface: String, yaw := 0.0) -> void:
	var body := StaticBody3D.new()
	body.name = "%s_Collision" % surface.capitalize()
	body.set_meta("surface_type", surface)
	body.position = position_value
	body.rotation.y = yaw
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _add_kerb_stripes(first: Vector3, second: Vector3) -> void:
	var tangent := (second - first).normalized()
	var normal := Vector3(tangent.z, 0.0, -tangent.x)
	var steps := maxi(1, int(first.distance_to(second) / 4.0))
	for step in steps:
		var point := first.lerp(second, (float(step) + 0.5) / float(steps))
		for side in [-1.0, 1.0]:
			var stripe := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(1.05, 0.05, 2.1)
			stripe.mesh = mesh
			stripe.position = point + normal * side * (RaceConfig.track_width * 0.5 + RaceConfig.kerb_width * 0.5) + Vector3.UP * 0.055
			stripe.rotation.y = atan2(tangent.x, tangent.z)
			stripe.material_override = _material(Color("#c23436") if step % 2 == 0 else Color("#eeeeea"), 0.72, 0.0)
			add_child(stripe)

func _add_start_finish() -> void:
	var sample := sample_at_distance(0.0)
	var line := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(RaceConfig.track_width, 0.025, 0.55)
	line.mesh = mesh
	line.position = sample.position + Vector3.UP * 0.11
	line.rotation.y = atan2(sample.tangent.x, sample.tangent.z)
	line.material_override = _material(Color("#f3f4ec"), 0.55, 0.0)
	add_child(line)

func _build_racing_line() -> void:
	racing_line = Path3D.new()
	racing_line.name = "RacingLine"
	var curve := Curve3D.new()
	curve.closed = true
	for point in centerline:
		curve.add_point(point + Vector3.UP * 0.15)
	racing_line.curve = curve
	add_child(racing_line)

func _build_checkpoints() -> void:
	for index in 3:
		var distance := total_length * float(index) / 3.0
		var sample := sample_at_distance(distance)
		var area := Area3D.new()
		area.name = "Checkpoint_%d" % (index + 1)
		area.position = sample.position + Vector3.UP * 2.0
		area.rotation.y = atan2(sample.tangent.x, sample.tangent.z)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(RaceConfig.track_width + RaceConfig.kerb_width * 2.0, 4.0, 2.0)
		shape.shape = box
		area.add_child(shape)
		add_child(area)
		checkpoints.append(area)

func sample_at_distance(distance_value: float) -> Dictionary:
	var wrapped := fposmod(distance_value, total_length)
	for index in _segment_lengths.size():
		var start := _cumulative_lengths[index]
		var length := _segment_lengths[index]
		if wrapped <= start + length or index == _segment_lengths.size() - 1:
			var blend := (wrapped - start) / maxf(length, 0.001)
			var first := centerline[index]
			var second := centerline[(index + 1) % centerline.size()]
			var tangent := (second - first).normalized()
			return {"position": first.lerp(second, blend), "tangent": tangent, "normal": Vector3(tangent.z, 0.0, -tangent.x), "segment": index}
	return {"position": centerline[0], "tangent": Vector3.FORWARD, "normal": Vector3.RIGHT, "segment": 0}

func progress_at(world_point: Vector3) -> Dictionary:
	var best_distance := INF
	var best_progress := 0.0
	var best_offset := 0.0
	for index in centerline.size():
		var first := centerline[index]
		var second := centerline[(index + 1) % centerline.size()]
		var segment := second - first
		var length := _segment_lengths[index]
		var alpha := clampf((world_point - first).dot(segment) / maxf(segment.length_squared(), 0.001), 0.0, 1.0)
		var projected := first.lerp(second, alpha)
		var distance := Vector2(world_point.x - projected.x, world_point.z - projected.z).length()
		if distance < best_distance:
			best_distance = distance
			best_progress = _cumulative_lengths[index] + length * alpha
			var tangent := segment.normalized()
			best_offset = (world_point - projected).dot(Vector3(tangent.z, 0.0, -tangent.x))
	return {"progress": best_progress, "distance": best_distance, "offset": best_offset}

func get_surface_at(world_point: Vector3) -> Dictionary:
	var result := progress_at(world_point)
	var lateral_distance := absf(float(result.distance))
	var asphalt_limit := RaceConfig.track_width * 0.5
	var kerb_limit := asphalt_limit + RaceConfig.kerb_width
	if lateral_distance <= asphalt_limit:
		return SURFACES.asphalt.duplicate()
	if lateral_distance <= kerb_limit:
		return SURFACES.kerb.duplicate()
	if lateral_distance <= kerb_limit + 9.0:
		return SURFACES.grass.duplicate()
	return SURFACES.gravel.duplicate()

func is_legal(world_point: Vector3) -> bool:
	return bool(get_surface_at(world_point).legal)

func pose_at_grid(grid_index: int) -> Transform3D:
	var distance := 18.0 + float(grid_index / 2) * 8.0
	var sample := sample_at_distance(distance)
	var side := -1.0 if grid_index % 2 == 0 else 1.0
	var position_value: Vector3 = sample.position + sample.normal * side * 3.4 + Vector3.UP * 0.82
	var basis := Basis.looking_at(-sample.tangent, Vector3.UP)
	return Transform3D(basis, position_value)

func nearest_safe_pose(world_point: Vector3) -> Transform3D:
	var progress := progress_at(world_point)
	var sample := sample_at_distance(float(progress.progress))
	return Transform3D(Basis.looking_at(-sample.tangent, Vector3.UP), sample.position + Vector3.UP * 0.82)

func curvature_at(distance_value: float) -> float:
	var before := sample_at_distance(distance_value - 6.0).tangent as Vector3
	var after := sample_at_distance(distance_value + 6.0).tangent as Vector3
	return acos(clampf(before.dot(after), -1.0, 1.0)) / 12.0

func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material
