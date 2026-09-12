class_name BrakeBoard
extends Area3D
## Lightweight foam marker: overlap detects a strike without launching the car.
## Impact direction and distance determine each fragment's momentum and spin.
var metres := 100
var broken := false
var fragments: Array[RigidBody3D] = []
var _solid: MeshInstance3D
var _face: Texture2D
var _debris_generation := 0

func _ready() -> void:
	add_to_group("brake_boards")
	collision_layer = 0
	collision_mask = 2
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.65,0.88,0.26)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.44
	add_child(collision)
	_solid = MeshInstance3D.new()
	_solid.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.65,0.88,0.26)
	_solid.mesh = mesh
	_solid.position.y = 0.44
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("f4f4ee")
	mat.roughness = 0.96
	_solid.material_override = mat
	add_child(_solid)
	_face = load("res://assets/trackside/brake_%d.png" % metres)
	var face := MeshInstance3D.new()
	face.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	var quad := QuadMesh.new()
	quad.size = Vector2(1.65,0.88)
	face.mesh = quad
	face.position.z = 0.137
	var print_material := StandardMaterial3D.new()
	print_material.albedo_texture = _face
	print_material.roughness = 0.96
	face.material_override = print_material
	_solid.add_child(face)
	body_entered.connect(_on_strike)
	EventBus.session_started.connect(func(_mode: int) -> void: restore())

func _on_strike(body: Node3D) -> void:
	if broken or not body is RaycastFormulaCar or body.linear_velocity.length() < 1.0:
		return
	var impact := to_local(body.global_position).clamp(Vector3(-0.825,0,-0.13),Vector3(0.825,0.88,0.13))
	shatter.call_deferred(body.linear_velocity, to_global(impact), body)

func shatter(velocity: Vector3, impact: Vector3, striking_car: RigidBody3D = null) -> void:
	if broken:
		return
	broken = true
	_debris_generation += 1
	var generation := _debris_generation
	_solid.visible = false
	set_deferred("monitoring",false)
	var local_impact := to_local(impact)
	var speed := velocity.length()
	var rng := RandomNumberGenerator.new()
	rng.seed = metres * 191 + int(speed * 100)
	var reaction := Vector3.ZERO
	for row in 3:
		for column in 4:
			var piece := RigidBody3D.new()
			piece.name = "FoamFragment"
			piece.mass = 0.10
			piece.collision_layer = 4
			piece.collision_mask = 1
			piece.continuous_cd = true
			piece.linear_damp = 0.7
			piece.angular_damp = 0.5
			var size := Vector3(0.4025,0.2833,0.24)
			var collider := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = size
			collider.shape = box
			piece.add_child(collider)
			var visual := MeshInstance3D.new()
			visual.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
			var mesh := BoxMesh.new()
			mesh.size = size
			visual.mesh = mesh
			visual.material_override = _solid.material_override
			piece.add_child(visual)
			var printed_piece := MeshInstance3D.new()
			printed_piece.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
			var face_mesh := QuadMesh.new()
			face_mesh.size = Vector2(size.x,size.y)
			printed_piece.mesh = face_mesh
			printed_piece.position.z = size.z * 0.5 + 0.004
			var face_material := StandardMaterial3D.new()
			face_material.albedo_texture = _face
			face_material.roughness = 0.96
			face_material.uv1_scale = Vector3(0.25,1.0 / 3.0,1)
			face_material.uv1_offset = Vector3(column * 0.25,(2 - row) / 3.0,0)
			printed_piece.material_override = face_material
			piece.add_child(printed_piece)
			get_parent().add_child(piece)
			var center := Vector3(-0.61875 + column * 0.4125,0.1467 + row * 0.2933,0)
			piece.global_transform = global_transform * Transform3D(Basis.IDENTITY,center)
			var distance := center.distance_to(local_impact)
			var transfer := 0.12 + 0.28 * exp(-distance * 1.4)
			piece.linear_velocity = velocity * transfer + global_basis * Vector3(rng.randf_range(-1.5,1.5),rng.randf_range(1,3),rng.randf_range(-1,1)) * minf(speed * 0.08,3)
			# Off-centre contact imparts torque around the impacted edge.
			piece.apply_impulse(velocity * piece.mass * 0.03,global_basis * (local_impact - center).limit_length(0.35))
			piece.angular_velocity += Vector3(rng.randf_range(-4,4),rng.randf_range(-4,4),rng.randf_range(-4,4))
			reaction += piece.linear_velocity * piece.mass + velocity * piece.mass * 0.03
			fragments.append(piece)
	if is_instance_valid(striking_car):
		striking_car.apply_impulse(-reaction,impact - striking_car.global_position)
	get_tree().create_timer(12.0).timeout.connect(func() -> void:
		if generation == _debris_generation:
			_clear_fragments())

func _clear_fragments() -> void:
	for piece in fragments:
		if is_instance_valid(piece):
			piece.queue_free()
	fragments.clear()

func restore() -> void:
	_debris_generation += 1
	_clear_fragments()
	broken = false
	_solid.visible = true
	set_deferred("monitoring",true)
