extends SceneTree

func _initialize() -> void:
	var model: Node3D = load("res://assets/cars/cc0_f2002.glb").instantiate()
	root.add_child(model)
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var bounds := mesh.transform * mesh.get_aabb()
		print(mesh.name, " centre=", bounds.get_center(), " size=", bounds.size, " vertices=", mesh.mesh.surface_get_array_len(0))
	quit()
