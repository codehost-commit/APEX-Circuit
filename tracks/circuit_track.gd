class_name CircuitTrack
extends Node3D
## Original Python circuit, in metres. Road, contact, timing and AI share one route.

const METRES_PER_UNIT := 0.14
const SOURCE_ORIGIN := Vector2(1600, 1500)
const ROAD_Y := 0.035
const SAMPLE_STEP := 1.6
const SPATIAL_CELL := 40.0
const SOURCE_POINTS := [
	Vector2(1000,1500),Vector2(3604,1500),Vector2(4162,1562),Vector2(4441,1872),
	Vector2(4472,2275),Vector2(4286,2616),Vector2(3883,2740),Vector2(3480,2585),
	Vector2(3170,2275),Vector2(2829,2120),Vector2(2488,2275),Vector2(2271,2616),
	Vector2(2302,2988),Vector2(2519,3298),Vector2(2860,3422),Vector2(3170,3329),
	Vector2(3356,3050),Vector2(3511,3236),Vector2(3604,3577),Vector2(3480,3887),
	Vector2(3139,4073),Vector2(2200,4073),Vector2(2395,3887),Vector2(2085,3608),
	Vector2(1682,3484),Vector2(1310,3546),Vector2(1031,3856),Vector2(969,4228),
	Vector2(1124,4538),Vector2(1465,4693),Vector2(1930,4724),Vector2(2426,4910),
	Vector2(2984,5065),Vector2(3604,5065),Vector2(4224,5065),Vector2(4844,5065),
	Vector2(5464,5065),Vector2(6084,5065),Vector2(6642,5127),Vector2(7076,5406),
	Vector2(7262,5809),Vector2(7076,6150),Vector2(6580,6336),Vector2(5960,6398),
	Vector2(5340,6274),Vector2(4782,5964),Vector2(4348,5750),Vector2(4162,5500),
	Vector2(3604,5700),Vector2(3046,5654),Vector2(2426,5654),Vector2(1868,5468),
	Vector2(1372,5158),Vector2(1000,4786),Vector2(690,4414),Vector2(566,3918),
	Vector2(597,3360),Vector2(783,2802),Vector2(938,2337),Vector2(1000,1934)
]
const SOURCE_GRAVEL := [
	[Vector2(3980,1530),Vector2(4480,1700),Vector2(4620,2250),Vector2(4320,2700),Vector2(4010,2520),Vector2(4140,2050)],
	[Vector2(3000,3750),Vector2(3420,3800),Vector2(3510,4200),Vector2(3140,4470),Vector2(2700,4250),Vector2(2600,4000)],
	[Vector2(6280,4880),Vector2(6900,4960),Vector2(7380,5520),Vector2(7420,6100),Vector2(6900,6500),Vector2(6400,6200),Vector2(6500,5550)],
	[Vector2(4200,5300),Vector2(5000,5700),Vector2(5620,6200),Vector2(5200,6620),Vector2(4480,6200),Vector2(3980,5680)],
	[Vector2(600,2500),Vector2(950,2200),Vector2(1160,2800),Vector2(960,3500),Vector2(500,3920),Vector2(420,3300)]
]
const SURFACES := {
	"asphalt":{"name":"asphalt","grip":1.0,"drag":1.0,"rolling_resistance":0.012,"legal":true},
	"kerb":{"name":"kerb","grip":0.58,"drag":2.667,"rolling_resistance":0.032,"legal":true},
	"grass":{"name":"grass","grip":0.38,"drag":6.0,"rolling_resistance":0.072,"legal":false},
	"gravel":{"name":"sand","grip":0.52,"drag":15.833,"rolling_resistance":0.19,"legal":false}
}

var road_half_width := 10.5
var kerb_width := 7.84
var total_length := 0.0
var centerline := PackedVector3Array()
var racing_line: Path3D
var checkpoints: Array[Area3D] = []
var checkpoint_distances := PackedFloat32Array()
var sector_distances := PackedFloat32Array()
var drs_zones: Array[Vector2] = []
var drs_detection_distances := PackedFloat32Array()
var _segment_lengths := PackedFloat32Array()
var _cumulative_lengths := PackedFloat32Array()
var _tangents := PackedVector3Array()
var _normals := PackedVector3Array()
var _spatial: Dictionary = {}
var _gravel_polygons: Array[PackedVector2Array] = []
var _light_materials: Array[StandardMaterial3D] = []
var _last_light_count := -1
var _last_light_out := true
var _materials: Dictionary = {}
var _projection_frame := -1
var _projection_cache: Dictionary = {}

func _ready() -> void:
	_build_original_layout()
	_build_distance_cache()
	_build_spatial_index()
	_build_timing_data()
	_build_materials()
	_build_terrain()
	_build_gravel()
	_build_road()
	_build_racing_line()
	_build_checkpoints()
	_build_circuit_furniture()
	_build_paddock_and_grandstands()
	_build_vegetation()
	_build_start_finish()
	# Keep timing lamps separate because their material changes each light phase.
	preload("res://scripts/mesh_batcher.gd").merge_children(self)
	print("Original APEX circuit: %.1f m, %d continuous samples, 5 checkpoints, 3 sectors, 3 DRS zones." % [total_length,centerline.size()])

func _source_to_world(point: Vector2) -> Vector3:
	var metres := (point - SOURCE_ORIGIN) * METRES_PER_UNIT
	return Vector3(metres.x,0.0,metres.y)

func _build_original_layout() -> void:
	# Faithful _rounded_control_path port: authored straights stay straight.
	var rounded := PackedVector3Array()
	for index in SOURCE_POINTS.size():
		var point: Vector2 = SOURCE_POINTS[index]
		var incoming: Vector2 = SOURCE_POINTS[posmod(index - 1,SOURCE_POINTS.size())] - point
		var outgoing: Vector2 = SOURCE_POINTS[(index + 1) % SOURCE_POINTS.size()] - point
		var radius := minf(90.0,minf(incoming.length() * 0.22,outgoing.length() * 0.22))
		var entry := point + incoming.normalized() * radius
		var exit_point := point + outgoing.normalized() * radius
		rounded.append(_source_to_world(entry))
		for step in range(1,25):
			var amount := float(step) / 24.0
			var inverse := 1.0 - amount
			rounded.append(_source_to_world(entry * inverse * inverse + point * 2.0 * inverse * amount + exit_point * amount * amount))
	# Rotate the loop to the exact prototype start/finish, including its seam.
	var start_index := 0
	for index in rounded.size():
		var first := rounded[index]
		var second := rounded[(index + 1) % rounded.size()]
		if absf(first.z) < 0.0001 and absf(second.z) < 0.0001 and first.x <= 0 and second.x > 0:
			rounded.insert(index + 1,Vector3.ZERO)
			start_index = index + 1
			break
	for cursor in rounded.size():
		var index := (start_index + cursor) % rounded.size()
		var first := rounded[index]
		var second := rounded[(index + 1) % rounded.size()]
		var count := maxi(1,int(ceil(first.distance_to(second) / SAMPLE_STEP)))
		for step in count:
			var point := first.lerp(second,float(step) / float(count))
			if centerline.is_empty() or centerline[-1].distance_squared_to(point) > 0.000001:
				centerline.append(point)
	for source_zone in SOURCE_GRAVEL:
		var polygon := PackedVector2Array()
		for source_point in source_zone:
			var world_point := _source_to_world(source_point)
			polygon.append(Vector2(world_point.x,world_point.z))
		_gravel_polygons.append(polygon)

func _build_distance_cache() -> void:
	for index in centerline.size():
		_cumulative_lengths.append(total_length)
		var next := centerline[(index + 1) % centerline.size()]
		var length := centerline[index].distance_to(next)
		_segment_lengths.append(length)
		total_length += length
		var incoming := (centerline[index] - centerline[posmod(index - 1,centerline.size())]).normalized()
		var outgoing := (next - centerline[index]).normalized()
		var tangent := (incoming + outgoing).normalized()
		_tangents.append(tangent)
		_normals.append(tangent.cross(Vector3.UP))

func _build_spatial_index() -> void:
	var padding := road_half_width + kerb_width + 5.0
	for index in centerline.size():
		var first := centerline[index]
		var second := centerline[(index + 1) % centerline.size()]
		var minimum := Vector2i(floori((minf(first.x,second.x) - padding) / SPATIAL_CELL),floori((minf(first.z,second.z) - padding) / SPATIAL_CELL))
		var maximum := Vector2i(floori((maxf(first.x,second.x) + padding) / SPATIAL_CELL),floori((maxf(first.z,second.z) + padding) / SPATIAL_CELL))
		for x in range(minimum.x,maximum.x + 1):
			for z in range(minimum.y,maximum.y + 1):
				var key := Vector2i(x,z)
				if not _spatial.has(key):
					_spatial[key] = PackedInt32Array()
				_spatial[key].append(index)

func _build_timing_data() -> void:
	for fraction in [0.16,0.32,0.49,0.66,0.83]:
		checkpoint_distances.append(total_length * float(fraction))
	for anchor in [Vector2(2771,4073),Vector2(6960,6193)]:
		sector_distances.append(float(progress_at(_source_to_world(anchor)).progress))
	sector_distances.sort()
	sector_distances.append(total_length)
	for fractions in [Vector2(0.005,0.115),Vector2(0.52,0.66),Vector2(0.35,0.405)]:
		drs_zones.append(fractions * total_length)
		drs_detection_distances.append(fposmod(fractions.x * total_length - 65.0,total_length))

func _build_materials() -> void:
	for surface_name in ["asphalt","kerb","grass","gravel"]:
		var material := ShaderMaterial.new()
		material.shader = load("res://materials/circuit_surface.gdshader")
		material.set_shader_parameter("surface_kind",["asphalt","kerb","grass","gravel"].find(surface_name))
		if surface_name != "kerb":
			var texture_id: String = {"asphalt":"asphalt_track", "grass":"grass_ground", "gravel":"gravel_floor"}[surface_name]
			material.set_shader_parameter("surface_albedo", load("res://assets/textures/%s_diffuse.jpg" % texture_id))
			material.set_shader_parameter("surface_normal", load("res://assets/textures/%s_nor_gl.jpg" % texture_id))
			material.set_shader_parameter("surface_roughness", load("res://assets/textures/%s_rough.jpg" % texture_id))
			material.set_shader_parameter("texture_metres", 2.3 if surface_name == "gravel" else 2.0)
		_materials[surface_name] = material
	_materials["white"] = _material(Color("#e5e1d3"),0.82)
	_materials["dark"] = _material(Color("#161d21"),0.65)
	_materials["steel"] = _material(Color("#a4acaf"),0.48,0.7)
	_materials["teal"] = _material(Color("#087f86"),0.65,0.15)
	_materials["red"] = _material(Color("#cb2837"),0.76)

func _build_terrain() -> void:
	# Ground extends beyond the camera far plane; hills have real depth.
	var ground := MeshInstance3D.new()
	ground.name = "ContinuousLandscape"
	var plane := PlaneMesh.new()
	plane.size = Vector2(16000,16000)
	ground.mesh = plane
	ground.position = Vector3(300,-0.07,330)
	ground.material_override = _materials.grass
	add_child(ground)
	_add_collision_box(Vector3(300,-1.07,330),Vector3(16000,2,16000),"grass")
	var hill_mesh := SphereMesh.new()
	hill_mesh.radius = 1.0
	hill_mesh.height = 2.0
	hill_mesh.radial_segments = 24
	hill_mesh.rings = 12
	hill_mesh.material = _material(Color("#344936"),1.0)
	var hills: Array[Transform3D] = []
	for index in 28:
		var angle := TAU * float(index) / 28.0
		var radius := 1950.0 + 310.0 * sin(float(index) * 1.7)
		var point := Vector3(300 + cos(angle) * radius,-70,330 + sin(angle) * radius)
		var scale_value := Vector3(330 + (index % 4) * 80,125 + (index % 5) * 28,330)
		hills.append(Transform3D(Basis.IDENTITY.scaled(scale_value),point))
	_add_multimesh("DistantRollingHills",hill_mesh,hills)

func _build_road() -> void:
	_add_ribbon("AsphaltContinuous",-road_half_width,road_half_width,ROAD_Y,_materials.asphalt,"asphalt")
	for side in [-1.0,1.0]:
		var first: float = (road_half_width + 0.03) * side
		var second: float = (road_half_width + kerb_width) * side
		_add_ribbon("WideKerb",minf(first,second),maxf(first,second),ROAD_Y - 0.003,_materials.kerb,"kerb")
		var inner: float = (road_half_width - 0.17) * side
		var outer: float = (road_half_width + 0.03) * side
		_add_ribbon("TrackLimitWhiteLine",minf(inner,outer),maxf(inner,outer),ROAD_Y + 0.006,_materials.white)
		var edge: float = (road_half_width + kerb_width) * side
		_add_ribbon("KerbOuterEdge",minf(edge,edge + side * 0.12),maxf(edge,edge + side * 0.12),ROAD_Y + 0.004,_materials.white)

func _add_ribbon(node_name: String,left_offset: float,right_offset: float,y: float,material: Material,surface := "") -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for index in range(centerline.size() + 1):
		var wrapped := index % centerline.size()
		var progress := total_length if index == centerline.size() else _cumulative_lengths[index]
		var center := centerline[wrapped] + Vector3.UP * y
		vertices.append(center + _normals[wrapped] * left_offset)
		vertices.append(center + _normals[wrapped] * right_offset)
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		uvs.append(Vector2(left_offset,progress))
		uvs.append(Vector2(right_offset,progress))
		if index < centerline.size():
			var base := index * 2
			# Clockwise viewed from above, with an exact duplicate closing seam.
			indices.append_array(PackedInt32Array([base,base + 2,base + 1,base + 1,base + 2,base + 3]))
	var mesh := _array_mesh(vertices,normals,uvs,indices)
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	if not surface.is_empty():
		var shape := mesh.create_trimesh_shape()
		shape.backface_collision = true
		_add_collision_shape(node_name + "Collision",shape,surface)

func _build_gravel() -> void:
	var pebble_mesh := SphereMesh.new()
	pebble_mesh.radius = 0.06
	pebble_mesh.height = 0.055
	pebble_mesh.radial_segments = 4
	pebble_mesh.rings = 2
	pebble_mesh.material = _material(Color("#a98c5d"),1.0)
	var pebbles: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 9367
	for zone_index in _gravel_polygons.size():
		var polygon := _gravel_polygons[zone_index]
		var triangles := Geometry2D.triangulate_polygon(polygon)
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var uvs := PackedVector2Array()
		var indices := PackedInt32Array()
		for point in polygon:
			vertices.append(Vector3(point.x,-0.018,point.y))
			normals.append(Vector3.UP)
			uvs.append(point)
		for index in range(0,triangles.size(),3):
			var a := triangles[index]
			var b := triangles[index + 1]
			var c := triangles[index + 2]
			if (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).y > 0:
				indices.append_array(PackedInt32Array([a,c,b]))
			else:
				indices.append_array(PackedInt32Array([a,b,c]))
		var mesh := _array_mesh(vertices,normals,uvs,indices)
		var node := MeshInstance3D.new()
		node.name = "OriginalSandTrap_%d" % zone_index
		node.mesh = mesh
		node.material_override = _materials.gravel
		add_child(node)
		var shape := mesh.create_trimesh_shape()
		shape.backface_collision = true
		_add_collision_shape("SandTrapCollision",shape,"gravel")
		var minimum := polygon[0]
		var maximum := polygon[0]
		for point in polygon:
			minimum = minimum.min(point)
			maximum = maximum.max(point)
		for attempt in 1500:
			var point := Vector2(rng.randf_range(minimum.x,maximum.x),rng.randf_range(minimum.y,maximum.y))
			var world_point := Vector3(point.x,0.02,point.y)
			if not Geometry2D.is_point_in_polygon(point,polygon) or float(progress_at(world_point).distance) < road_half_width + kerb_width:
				continue
			pebbles.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * rng.randf_range(0.5,1.8)),world_point))
	_add_multimesh("SandGranules",pebble_mesh,pebbles,100.0)

func _build_racing_line() -> void:
	racing_line = Path3D.new()
	racing_line.name = "OriginalCircuitRacingLine"
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	for point in centerline:
		curve.add_point(point + Vector3.UP * ROAD_Y)
	curve.add_point(centerline[0] + Vector3.UP * ROAD_Y)
	racing_line.curve = curve
	add_child(racing_line)

func _build_checkpoints() -> void:
	for index in checkpoint_distances.size():
		var sample := sample_at_distance(checkpoint_distances[index])
		var area := Area3D.new()
		area.name = "OrderedCheckpoint_%d" % (index + 1)
		area.collision_layer = 0
		area.collision_mask = 2
		area.position = sample.position + Vector3.UP * 2.0
		area.basis = Basis.looking_at(sample.tangent,Vector3.UP)
		area.set_meta("checkpoint_index",index)
		area.set_meta("lap_distance",checkpoint_distances[index])
		var box := BoxShape3D.new()
		box.size = Vector3((road_half_width + kerb_width) * 2.0,5,2.5)
		var collision := CollisionShape3D.new()
		collision.shape = box
		area.add_child(collision)
		add_child(area)
		checkpoints.append(area)

func _build_circuit_furniture() -> void:
	var rail_mesh := BoxMesh.new()
	rail_mesh.size = Vector3(0.22,0.3,8.15)
	rail_mesh.material = _materials.steel
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.17,3.0,0.17)
	post_mesh.material = _materials.steel
	var wire_mesh := BoxMesh.new()
	wire_mesh.size = Vector3(0.035,0.035,8.15)
	wire_mesh.material = _materials.steel
	var rails: Array[Transform3D] = []
	var posts: Array[Transform3D] = []
	var wires: Array[Transform3D] = []
	var barrier_body := StaticBody3D.new()
	barrier_body.name = "PhysicalArmcoPerimeter"
	barrier_body.collision_layer = 1
	barrier_body.collision_mask = 2
	barrier_body.set_meta("surface_type","barrier")
	barrier_body.set_meta("barrier",true)
	add_child(barrier_body)
	for index in int(total_length / 8.0):
		var sample := sample_at_distance(float(index) * 8.0)
		var facing := Basis.looking_at(sample.tangent,Vector3.UP)
		for side in [-1.0,1.0]:
			var point: Vector3 = sample.position + sample.normal * float(side) * (road_half_width + kerb_width + 17.0)
			if not _clears_track(point,sample.tangent,4,2):
				continue
			if point.z > 18 and point.z < 70 and point.x > -100 and point.x < 280:
				continue
			for height in [0.47,0.83]:
				rails.append(Transform3D(facing,point + Vector3.UP * float(height)))
			posts.append(Transform3D(facing,point + Vector3.UP * 1.5))
			for height in [1.3,1.8,2.3,2.8]:
				wires.append(Transform3D(facing,point + Vector3.UP * float(height)))
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(0.35,1,8.1)
			collision.shape = shape
			collision.transform = Transform3D(facing,point + Vector3.UP * 0.5)
			barrier_body.add_child(collision)
	_add_multimesh("ContinuousArmcoRails",rail_mesh,rails,650)
	_add_multimesh("CatchFencePosts",post_mesh,posts,500)
	_add_multimesh("CatchFenceWires",wire_mesh,wires,350)
	for zone in drs_zones:
		_add_distance_board(zone.x,"DRS",Color("#39cbb3"))
		_add_distance_board(zone.y,"DRS END",Color("#e3e0cd"))
	for index in 2:
		_add_distance_board(sector_distances[index],"SECTOR %d" % (index + 2),Color("#efce65"))
	var last_corner := -200.0
	for index in int(total_length / 12.0):
		var distance_value := float(index) * 12.0
		if curvature_at(distance_value) > 0.015 and distance_value - last_corner > 110:
			for metres in [150,100,50]:
				_add_distance_board(distance_value - float(metres),str(metres),Color("#e7e5d9"))
			last_corner = distance_value
	for index in 20:
		var sample := sample_at_distance(float(index) * total_length / 20 + 35)
		var point: Vector3 = sample.position + sample.normal * (road_half_width + kerb_width + 20)
		if not _clears_track(point,sample.tangent,6,3):
			continue
		var board := Node3D.new()
		board.name = "CircuitSponsorBoard"
		board.transform = Transform3D(Basis.looking_at(-sample.normal,Vector3.UP),point)
		add_child(board)
		_add_box(board,Vector3(0,1.15,0),Vector3(11,2.2,0.25),_materials.teal)
		_add_label(board,"APEX  /  CIRCUIT",Vector3(0,1.2,0.15),0.027,Color("#f5f2dc"))
		if index % 4 == 0:
			_add_box(board,Vector3(7,1.45,-2),Vector3(3.4,2.9,3),_materials.white)
			_add_box(board,Vector3(7,3.03,-2),Vector3(4,0.22,3.6),_materials.teal)
			_add_box(board,Vector3(7,2,-0.47),Vector3(2.6,0.7,0.03),_materials.dark)

func _build_paddock_and_grandstands() -> void:
	var paddock := Node3D.new()
	paddock.name = "PaddockAndPitLane"
	add_child(paddock)
	_add_box(paddock,Vector3(100,-0.025,30),Vector3(360,0.04,17),_materials.asphalt)
	_add_collision_box(Vector3(100,-0.065,30),Vector3(360,0.08,17),"asphalt")
	var glass := _material(Color("#263e48"),0.2,0.4)
	for index in 13:
		var x := -30.0 + float(index) * 17
		_add_box(paddock,Vector3(x,2.9,53),Vector3(16.5,5.8,18),_materials.white)
		_add_box(paddock,Vector3(x,1.9,43.94),Vector3(13.8,3.8,0.1),_materials.dark)
		_add_box(paddock,Vector3(x,4.8,43.82),Vector3(15.5,1,0.1),_materials.teal if index % 2 == 0 else _materials.red)
		_add_box(paddock,Vector3(x,5.95,51),Vector3(17,0.28,22),_materials.dark)
		_add_box(paddock,Vector3(x,7.2,55),Vector3(15.5,2.3,13),glass)
		var label := _add_label(paddock,"%02d / APEX MOTORSPORT" % (index + 1),Vector3(x,4.82,43.73),0.017,Color("#f8f0d6"))
		label.rotation.y = PI
		_add_box(paddock,Vector3(x,0.03,32),Vector3(0.14,0.015,10),_materials.white)
	_add_box(paddock,Vector3(84,0.65,21.3),Vector3(252,1.3,0.4),_materials.white)
	_add_collision_box(Vector3(84,0.65,21.3),Vector3(252,1.3,0.4),"barrier")
	for index in 36:
		_add_box(paddock,Vector3(-40 + index * 7,1.65,21.3),Vector3(0.07,2,0.07),_materials.steel)
	_add_box(paddock,Vector3(84,2.5,21.3),Vector3(252,0.07,0.07),_materials.steel)
	var stand_data := [Vector2(0.015,-1),Vector2(0.245,1),Vector2(0.515,-1),Vector2(0.745,-1),Vector2(0.925,1)]
	var seat_mesh := BoxMesh.new()
	seat_mesh.size = Vector3(0.62,0.18,0.75)
	seat_mesh.material = _materials.red
	var seats: Array[Transform3D] = []
	for index in stand_data.size():
		var data: Vector2 = stand_data[index]
		var sample := sample_at_distance(total_length * data.x)
		var point: Vector3 = sample.position + sample.normal * data.y * 55
		if not _clears_track(point,sample.tangent,27,15):
			point += sample.normal * data.y * 25
		if not _clears_track(point,sample.tangent,27,15):
			continue
		var stand := Node3D.new()
		stand.name = "Grandstand_%d" % index
		stand.transform = Transform3D(Basis.looking_at(sample.normal * data.y,Vector3.UP),point)
		add_child(stand)
		for row in 8:
			_add_box(stand,Vector3(0,0.5 + row * 0.65,-6 + row * 1.6),Vector3(48,0.8,1.7),_materials.white)
			for seat in 30:
				var seat_point := Vector3(-22.3 + seat * 1.52,1.1 + row * 0.65,-5.8 + row * 1.6)
				seats.append(stand.transform * Transform3D(Basis.IDENTITY,seat_point))
		for x in [-25.0,0.0,25.0]:
			_add_box(stand,Vector3(x,5,6),Vector3(0.38,10,0.38),_materials.steel)
		_add_box(stand,Vector3(0,10,1.5),Vector3(53,0.35,19),_materials.dark)
		_add_box(stand,Vector3(0,9.35,-8),Vector3(52,1,0.15),_materials.teal)
		var label := _add_label(stand,"APEX CIRCUIT / ORIGINAL GRAND PRIX",Vector3(0,9.38,-8.12),0.042,Color("#f2ebcd"))
		label.rotation.y = PI
	_add_multimesh("GrandstandSeats",seat_mesh,seats,450)

func _build_vegetation() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41731
	var trunks: Array[Transform3D] = []
	var canopies: Array[Transform3D] = []
	var bushes: Array[Transform3D] = []
	for index in 1100:
		var point := Vector3(rng.randf_range(-700,1650),0,rng.randf_range(-520,1420))
		if float(progress_at(point).distance) < road_half_width + kerb_width + 25:
			continue
		if point.x > -100 and point.x < 300 and point.z > -85 and point.z < 95:
			continue
		if _in_gravel(point):
			continue
		var height := rng.randf_range(5,13)
		var size := rng.randf_range(2.2,4.8)
		trunks.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.28,height * 0.55,0.28)),point + Vector3.UP * height * 0.275))
		for crown in 3:
			var offset := Vector3(rng.randf_range(-1.4,1.4),height * 0.6 + crown * 0.7,rng.randf_range(-1.4,1.4))
			canopies.append(Transform3D(Basis.IDENTITY.scaled(Vector3(size,size * 1.1,size)),point + offset))
		if index % 4 == 0:
			bushes.append(Transform3D(Basis.IDENTITY.scaled(Vector3(2.8,1.5,2.2)),point + Vector3(3,1,1)))
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.7
	trunk_mesh.bottom_radius = 1
	trunk_mesh.height = 1
	trunk_mesh.radial_segments = 6
	trunk_mesh.material = _material(Color("#504534"),0.98)
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 1
	crown_mesh.height = 2
	crown_mesh.radial_segments = 9
	crown_mesh.rings = 5
	crown_mesh.material = _material(Color("#42623b"),0.95)
	var bush_mesh := SphereMesh.new()
	bush_mesh.radius = 1
	bush_mesh.height = 2
	bush_mesh.radial_segments = 8
	bush_mesh.rings = 4
	bush_mesh.material = _material(Color("#537042"),0.98)
	_add_multimesh("WoodlandTrunks",trunk_mesh,trunks,1400)
	_add_multimesh("WoodlandCanopies",crown_mesh,canopies,1400)
	_add_multimesh("InfieldBushes",bush_mesh,bushes,650)

func _build_start_finish() -> void:
	var sample := sample_at_distance(0)
	var gantry := Node3D.new()
	gantry.name = "StartFinishGantry"
	gantry.transform = Transform3D(Basis.looking_at(sample.tangent,Vector3.UP),sample.position)
	add_child(gantry)
	for side in [-1.0,1.0]:
		_add_box(gantry,Vector3(side * 24,3.8,0),Vector3(0.55,7.6,0.55),_materials.steel)
		_add_box(gantry,Vector3(side * 24,0.3,0),Vector3(2,0.6,2),_materials.white)
	_add_box(gantry,Vector3(0,7.5,0),Vector3(48.5,1.25,0.65),_materials.teal)
	_add_label(gantry,"APEX  CIRCUIT",Vector3(0,7.5,0.34),0.071,Color("#f5ead4"))
	_add_box(gantry,Vector3(0,6.1,0.08),Vector3(7.3,1.8,0.6),_materials.dark)
	for index in 5:
		var material := _material(Color("#300b0c"),0.24)
		material.emission_enabled = true
		material.emission = Color("#ff1721")
		material.emission_energy_multiplier = 0
		_light_materials.append(material)
		for row in 2:
			var lamp := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.29
			sphere.height = 0.58
			sphere.radial_segments = 16
			sphere.rings = 8
			lamp.mesh = sphere
			lamp.scale.z = 0.28
			lamp.position = Vector3(-2.6 + index * 1.3,6.52 - row * 0.78,0.43)
			lamp.material_override = material
			gantry.add_child(lamp)
	for row in 2:
		for column in 28:
			var material: Material = _materials.white if (row + column) % 2 == 0 else _materials.dark
			_add_box(gantry,Vector3(-road_half_width + (column + 0.5) * road_half_width / 14,ROAD_Y + 0.012,(row - 0.5) * 0.42),Vector3(road_half_width / 14,0.016,0.42),material)
	for index in 12:
		var pose := pose_at_grid(index)
		var marker := Node3D.new()
		marker.name = "GridSlot_%02d" % (index + 1)
		marker.transform = Transform3D(pose.basis,Vector3(pose.origin.x,ROAD_Y + 0.015,pose.origin.z))
		add_child(marker)
		_add_box(marker,Vector3(0,0,-2.7),Vector3(2.9,0.02,0.12),_materials.white)
		for side in [-1.0,1.0]:
			_add_box(marker,Vector3(side * 1.4,0,-1.7),Vector3(0.12,0.02,2),_materials.white)

func set_start_lights(count: int,extinguished := false) -> void:
	if count == _last_light_count and extinguished == _last_light_out:
		return
	_last_light_count = count
	_last_light_out = extinguished
	for index in _light_materials.size():
		var active := index < count and not extinguished
		_light_materials[index].albedo_color = Color("#ff2933") if active else Color("#300b0c")
		_light_materials[index].emission_energy_multiplier = 3.0 if active else 0.0

func sample_at_distance(distance_value: float) -> Dictionary:
	var wrapped := fposmod(distance_value,maxf(total_length,0.001))
	var index := _segment_at_distance(wrapped)
	var blend := (wrapped - _cumulative_lengths[index]) / maxf(_segment_lengths[index],0.0001)
	var next := (index + 1) % centerline.size()
	var tangent := _tangents[index].lerp(_tangents[next],blend).normalized()
	return {"position":centerline[index].lerp(centerline[next],blend),"tangent":tangent,"normal":tangent.cross(Vector3.UP),"segment":index,"progress":wrapped}

func _segment_at_distance(wrapped: float) -> int:
	var low := 0
	var high := _cumulative_lengths.size() - 1
	while low < high:
		var middle := (low + high + 1) / 2
		if _cumulative_lengths[middle] <= wrapped:
			low = middle
		else:
			high = middle - 1
	return low

func _candidate_segments(point: Vector3) -> PackedInt32Array:
	var cell := Vector2i(floori(point.x / SPATIAL_CELL),floori(point.z / SPATIAL_CELL))
	if _spatial.has(cell):
		return _spatial[cell]
	for radius in range(1,50):
		var candidates := PackedInt32Array()
		for x in range(cell.x - radius,cell.x + radius + 1):
			for z in [cell.y - radius,cell.y + radius]:
				var key := Vector2i(x,z)
				if _spatial.has(key):
					candidates.append_array(_spatial[key])
		for z in range(cell.y - radius + 1,cell.y + radius):
			for x in [cell.x - radius,cell.x + radius]:
				var key := Vector2i(x,z)
				if _spatial.has(key):
					candidates.append_array(_spatial[key])
		if not candidates.is_empty():
			return candidates
	return PackedInt32Array(range(centerline.size()))

func progress_at(world_point: Vector3,hint_progress := -1.0,window := 40.0) -> Dictionary:
	# Neighbour avoidance, timing and the HUD query identical poses many times.
	# Share only exact, unhinted projections within this physics tick.
	var frame := Engine.get_physics_frames()
	if frame != _projection_frame:
		_projection_frame = frame
		_projection_cache.clear()
	var cache_key := Vector2(world_point.x, world_point.z)
	if hint_progress < 0 and _projection_cache.has(cache_key):
		return _projection_cache[cache_key]
	var candidates := _candidate_segments(world_point)
	if hint_progress >= 0:
		var nearby := PackedInt32Array()
		for index in candidates:
			var difference := absf(fposmod(_cumulative_lengths[index] - hint_progress + total_length * 0.5,total_length) - total_length * 0.5)
			if difference <= window:
				nearby.append(index)
		if not nearby.is_empty():
			candidates = nearby
		else:
			candidates.clear()
			var center := _segment_at_distance(fposmod(hint_progress,total_length))
			for offset in range(-100,101):
				var index := posmod(center + offset,centerline.size())
				var difference := absf(fposmod(_cumulative_lengths[index] - hint_progress + total_length * 0.5,total_length) - total_length * 0.5)
				if difference <= window:
					candidates.append(index)
	var best_distance_squared := INF
	var best_progress := 0.0
	var best_offset := 0.0
	var best_position := Vector3.ZERO
	var best_segment := 0
	var planar := Vector3(world_point.x,0,world_point.z)
	for index in candidates:
		var first := centerline[index]
		var segment := centerline[(index + 1) % centerline.size()] - first
		var alpha := clampf((planar - first).dot(segment) / maxf(segment.length_squared(),0.000001),0,1)
		var projected := first + segment * alpha
		var distance_squared := planar.distance_squared_to(projected)
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best_progress = fposmod(_cumulative_lengths[index] + _segment_lengths[index] * alpha,total_length)
			best_offset = (planar - projected).dot(segment.normalized().cross(Vector3.UP))
			best_position = projected
			best_segment = index
	var result := {"progress":best_progress,"distance":sqrt(best_distance_squared),"offset":best_offset,"position":best_position,"segment":best_segment}
	if hint_progress < 0:
		_projection_cache[cache_key] = result
	return result

func get_surface_at(world_point: Vector3) -> Dictionary:
	var lateral := float(progress_at(world_point).distance)
	if lateral <= road_half_width:
		return SURFACES.asphalt
	if lateral <= road_half_width + kerb_width:
		return SURFACES.kerb
	if world_point.x > -80 and world_point.x < 280 and world_point.z > 21.5 and world_point.z < 38.5:
		return {"name":"asphalt","grip":1.0,"drag":1.0,"rolling_resistance":0.012,"legal":false}
	if _in_gravel(world_point):
		return SURFACES.gravel
	return SURFACES.grass

func _in_gravel(world_point: Vector3) -> bool:
	var point := Vector2(world_point.x,world_point.z)
	for polygon in _gravel_polygons:
		if Geometry2D.is_point_in_polygon(point,polygon):
			return true
	return false

func is_legal(world_point: Vector3) -> bool:
	return float(progress_at(world_point).distance) <= road_half_width + kerb_width + 0.42

func pose_at_grid(grid_index: int) -> Transform3D:
	var row := grid_index / 2
	var column := grid_index % 2
	var back := (82.0 + float(row) * 58 + float(column) * 13) * METRES_PER_UNIT
	var sample := sample_at_distance(-back)
	var side := -1.0 if column == 0 else 1.0
	var point: Vector3 = sample.position + sample.normal * side * 27.0 * METRES_PER_UNIT + Vector3.UP * (ROAD_Y + 0.04)
	return Transform3D(Basis.looking_at(sample.tangent,Vector3.UP),point)

func nearest_safe_pose(world_point: Vector3) -> Transform3D:
	return safe_pose_at_distance(float(progress_at(world_point).progress))

func safe_pose_at_distance(distance_value: float,lateral_offset := 0.0) -> Transform3D:
	var sample := sample_at_distance(distance_value)
	return Transform3D(Basis.looking_at(sample.tangent,Vector3.UP),sample.position + sample.normal * clampf(lateral_offset,-road_half_width + 2,road_half_width - 2) + Vector3.UP * (ROAD_Y + 0.04))

func curvature_at(distance_value: float) -> float:
	return absf(signed_curvature_at(distance_value))

func signed_curvature_at(distance_value: float,half_window := 5.0) -> float:
	var before: Vector3 = sample_at_distance(distance_value - half_window).tangent
	var after: Vector3 = sample_at_distance(distance_value + half_window).tangent
	return before.signed_angle_to(after,Vector3.UP) / (half_window * 2)

func _clears_track(point: Vector3,tangent: Vector3,half_length: float,half_width: float) -> bool:
	var normal := tangent.cross(Vector3.UP)
	for along in [-half_length,0.0,half_length]:
		for outward in [-half_width,0.0,half_width]:
			if float(progress_at(point + tangent * float(along) + normal * float(outward)).distance) < road_half_width + kerb_width + 2.5:
				return false
	return true

func _add_distance_board(distance_value: float,text_value: String,text_color: Color) -> void:
	var sample := sample_at_distance(distance_value)
	var point: Vector3 = sample.position + sample.normal * (road_half_width + kerb_width + 4.5)
	if not _clears_track(point,sample.tangent,0.4,1.2):
		return
	var board := Node3D.new()
	board.name = "Board_" + text_value.replace(" ","_")
	board.transform = Transform3D(Basis.looking_at(sample.tangent,Vector3.UP),point)
	add_child(board)
	_add_box(board,Vector3(0,0.8,0),Vector3(0.09,1.6,0.09),_materials.steel)
	_add_box(board,Vector3(0,1.9,0),Vector3(2.5,1.4,0.12),_materials.dark)
	_add_label(board,text_value,Vector3(0,1.9,0.075),0.028,text_color)

func _array_mesh(vertices: PackedVector3Array,normals: PackedVector3Array,uvs: PackedVector2Array,indices: PackedInt32Array) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

func _add_collision_shape(node_name: String,shape: Shape3D,surface: String) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 2
	body.set_meta("surface_type",surface)
	if surface == "barrier":
		body.set_meta("barrier",true)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _add_collision_box(point: Vector3,size: Vector3,surface: String) -> void:
	var body := StaticBody3D.new()
	body.name = surface.capitalize() + "Collision"
	body.position = point
	body.collision_layer = 1
	body.collision_mask = 2
	body.set_meta("surface_type",surface)
	if surface == "barrier":
		body.set_meta("barrier",true)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _add_box(parent: Node3D,point: Vector3,size: Vector3,material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = point
	node.material_override = material
	parent.add_child(node)
	return node

func _add_label(parent: Node3D,text_value: String,point: Vector3,pixel_size_value: float,color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text_value
	label.position = point
	label.font_size = 64
	label.pixel_size = pixel_size_value
	label.modulate = color
	label.outline_size = 0
	label.no_depth_test = false
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(label)
	return label

func _add_multimesh(node_name: String,mesh: Mesh,transforms: Array[Transform3D],visibility_distance := 0.0) -> void:
	if transforms.is_empty():
		return
	# Regional batches retain culling; one circuit-wide AABB would never cull.
	var chunks: Dictionary = {}
	for transform_value in transforms:
		var key := Vector2i(floori(transform_value.origin.x / 160),floori(transform_value.origin.z / 160))
		if not chunks.has(key):
			chunks[key] = []
		chunks[key].append(transform_value)
	for key in chunks:
		var instances: Array = chunks[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = instances.size()
		var origin := Vector3(key.x * 160 + 80,0,key.y * 160 + 80)
		for index in instances.size():
			var transform_value: Transform3D = instances[index]
			transform_value.origin -= origin
			multimesh.set_instance_transform(index,transform_value)
		var node := MultiMeshInstance3D.new()
		node.name = node_name
		node.position = origin
		node.multimesh = multimesh
		if visibility_distance > 0:
			node.visibility_range_end = visibility_distance
			node.visibility_range_end_margin = 70
		add_child(node)

func _material(color: Color,roughness := 0.85,metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material
