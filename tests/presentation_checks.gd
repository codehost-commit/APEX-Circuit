extends Node
## Physical regressions for the visual overhaul, including actual board impacts.
var game: Node3D
var failures: Array[String] = []

func _ready() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	print("PASS " if condition else "FAIL ",message)
	if not condition:
		failures.append(message)

func frames(count: int) -> void:
	for tick in count:
		await get_tree().physics_frame

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	game.race_director._record_path = "res://tests/artifacts/qa_presentation_pb.json"
	Engine.max_fps = 0
	await frames(3)
	var car := game.player_car as RaycastFormulaCar
	var landscape: MeshInstance3D = game.track.get_node("SculptedLandscape360")
	var normals: PackedVector3Array = landscape.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var minimum_up := 1.0
	for normal in normals:
		minimum_up = minf(minimum_up, normal.y)
	check(minimum_up > 0.0,"Landscape faces upward with smooth terrain normals")
	var saved_unit := GameState.speed_unit
	GameState.speed_unit = "kmh"
	check(ApexStyle.speed_value(100.0 / 3.6) == 100,"Metric speed readout uses metres/second conversion")
	GameState.speed_unit = "mph"
	check(ApexStyle.speed_value(100.0 / 3.6) == 62 and ApexStyle.speed_suffix() == "MPH","Imperial speed readout and suffix agree")
	GameState.speed_unit = saved_unit
	game._start_time_trial()
	car.set_camera_mode(2)
	var mouse := InputEventMouseMotion.new()
	mouse.position = get_viewport().get_visible_rect().size * Vector2(0.75,0.5)
	mouse.relative = Vector2(3,0)
	car._input(mouse)
	car._update_camera(0.4)
	check(car._mouse_active and car._cockpit_camera.rotation.y < -0.1,"Cockpit camera follows the mouse to the right")
	var stick := InputEventJoypadMotion.new()
	stick.axis_value = 0.7
	car._input(stick)
	car._update_camera(0.7)
	check(not car._mouse_active and absf(car._cockpit_camera.rotation.y) < 0.02,"Controller activity recentres mouse look automatically")
	var combinations: Dictionary = {}
	for competitor in game.all_cars:
		var visual: Node3D = competitor._generated_visual
		combinations[Vector2i(visual._sponsor_id,visual._personal_sponsor)] = true
	check(combinations.size() == 12,"All twelve cars have different sponsor combinations")
	var ghost: Node3D = game.race_director._ghost.get_node("CompleteGhostCar")
	var complete: bool = ghost._wheels.size() == 4
	for wheel: Dictionary in ghost._wheels:
		complete = complete and is_instance_valid(wheel.visual) and is_instance_valid(wheel.roll_node)
	check(complete,"Ghost has all four tyres, steering pivots and rolling axles")
	var player_hidden_in_mirrors := true
	for mesh in car._generated_visual.find_children("*","MeshInstance3D",true,false):
		player_hidden_in_mirrors = player_hidden_in_mirrors and mesh.layers == 2
	check(player_hidden_in_mirrors,"Batched player geometry stays excluded from rearview cameras")
	check(game.track.find_children("PaintedDRSLine*","MeshInstance3D",true,false).size() == 6,"Every DRS entry and exit is a painted line")
	check(game.track.find_children("Board_SECTOR*","",true,false).is_empty(),"Sector boundaries have no trackside boxes")
	# Sweep a chassis-sized volume around three lanes to catch walls/buildings
	# that a downward ray beginning inside an obstruction would miss.
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8,0.4,4.4)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	var blocked: Dictionary = {}
	for i in 1500:
		var sample: Dictionary = game.track.sample_at_distance(i * game.track.total_length / 1500.0)
		for lane in [-4.0,0.0,4.0]:
			query.transform = Transform3D(Basis.looking_at(sample.tangent),sample.position + sample.normal * lane + Vector3.UP * 0.43)
			for hit in game.get_world_3d().direct_space_state.intersect_shape(query):
				blocked[str(hit.collider.get_path())] = true
	check(blocked.is_empty(),"4,500 chassis sweeps find no structure intruding into the driving lanes: " + str(blocked.keys()))
	for session in ["time_trial","qualifying","race"]:
		game.call("_start_" + session)
		car.automated_input = true
		game.drivers[0].enabled = false
		car.ai_command = {"throttle":0.0,"brake":1.0,"steer":0.0,"drs":false}
		await frames(90)
		check(car.grounded_wheels == 4 and absf(car.global_position.y) < 0.18 and car.global_basis.y.y > 0.98,"Stable grounded player spawn in " + session)
	game._start_time_trial()
	game.race_director.set_physics_process(false)
	game.drivers[0].enabled = false
	car.automated_input = true
	car.reset_to_pose(game.track.safe_pose_at_distance(50),true)
	car.set_flying_speed(45)
	car.ai_command = {"throttle":0.0,"brake":1.0,"steer":0.0,"drs":false}
	await frames(24)
	check(car.longitudinal_g < -0.8 and absf(car.lateral_g) < 0.15,"Measured acceleration shows straight-line braking with the correct sign")
	var circle := game.hud._dynamics as TelemetryCircle
	circle.car = car
	check(circle.g_point().y > 0,"G-force dot moves down under braking")
	var board := BrakeBoard.new()
	board.metres = 100
	board.transform = game.track.safe_pose_at_distance(130)
	game.track.add_child(board)
	car.reset_to_pose(game.track.safe_pose_at_distance(110),true)
	car.set_flying_speed(35)
	car.ai_command = {"throttle":0.4,"brake":0.0,"steer":0.0,"drs":false}
	await frames(100)
	check(board.broken and board.fragments.size() == 12,"Driving into a brake marker breaks it into twelve rigid fragments")
	var momentum := Vector3.ZERO
	for fragment in board.fragments:
		momentum += fragment.linear_velocity * fragment.mass
	check(momentum.dot(-board.global_basis.z) > 1.0,"Debris carries momentum in the direction of impact")
	check(car.global_position.y < 0.2 and car.speed_mps > 15,"Lightweight foam debris does not launch or stop the car")
	game._start_time_trial()
	await frames(3)
	check(not board.broken and board.fragments.is_empty(),"Restart restores brake boards and removes old fragments")
	await frames(840)
	board.shatter(Vector3(0,0,-30),board.global_position)
	await frames(720)
	check(board.fragments.size() == 12,"A previous session's debris timer cannot remove newly broken fragments")
	await frames(840)
	check(board.fragments.is_empty(),"Fragments expire after their own lifetime")
	game.hud._process(0)
	await get_tree().process_frame
	var bounds := Rect2(Vector2.ZERO,get_viewport().get_visible_rect().size)
	check(bounds.encloses(circle.get_global_rect()),"Telemetry module remains inside the viewport")
	print("PRESENTATION_CHECKS_RESULT ",JSON.stringify({"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
