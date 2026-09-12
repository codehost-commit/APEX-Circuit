extends RefCounted
## Scanned tree assets and articulated spectator geometry, regionally instanced.
static func scanned_trees() -> Array[Mesh]:
	var meshes: Array[Mesh] = []
	for path in ["res://assets/nature/island_tree.glb","res://assets/nature/pine_saplings.glb"]:
		var scene := (load(path) as PackedScene).instantiate()
		for node in scene.find_children("*","MeshInstance3D",true,false):
			meshes.append(node.mesh)
		scene.free()
	return meshes

static func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat

static func spectator(variant: int, standing := false) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var skin := _mat([Color("bd8964"),Color("754d37"),Color("e6bda0"),Color("a97550")][variant % 4],0.78)
	var shirt := _mat([Color("284766"),Color("c84437"),Color("dbdcd6"),Color("547463"),Color("e7ba48"),Color("323446")][variant % 6],0.91)
	var trouser := _mat(Color("293341"),0.94)
	var shoes := _mat(Color("252326"),0.83)
	var hair := _mat([Color("28221b"),Color("694932"),Color("ae8a52")][variant % 3],0.90)
	var hip_y := 0.90 if standing else 0.35
	var shoulder_y := hip_y + 0.46
	_part(mesh,Vector3(0,hip_y + 0.23,0),Vector3(0.20,0.30,0.115),shirt)
	_part(mesh,Vector3(0,shoulder_y + 0.15,-0.01),Vector3(0.054,0.09,0.06),skin)
	_part(mesh,Vector3(0,shoulder_y + 0.29,-0.025),Vector3(0.086,0.116,0.089),skin)
	_part(mesh,Vector3(0,shoulder_y + 0.35,-0.006),Vector3(0.091,0.074,0.087),hair)
	_part(mesh,Vector3(0,shoulder_y + 0.27,-0.11),Vector3(0.024,0.031,0.025),skin)
	for side in [-1.0,1.0]:
		_part(mesh,Vector3(side * 0.086,shoulder_y + 0.29,-0.02),Vector3(0.018,0.030,0.018),skin)
		_part(mesh,Vector3(side * 0.033,shoulder_y + 0.31,-0.104),Vector3(0.026,0.016,0.009),shoes)
		var shoulder := Vector3(side * 0.20,shoulder_y,0)
		var elbow := Vector3(side * 0.24,hip_y + 0.17,-0.045)
		var hand := Vector3(side * 0.15,hip_y + 0.13,-0.30)
		if variant % 4 == 0 and side > 0:
			elbow.y += 0.49
			hand = Vector3(side * 0.18,shoulder_y + 0.38,-0.20)
		_limb(mesh,shoulder,elbow,0.066,shirt)
		_limb(mesh,elbow,hand,0.038,skin)
		_part(mesh,hand,Vector3(0.035,0.055,0.020),skin)
		var hip := Vector3(side * 0.10,hip_y,0)
		var knee := Vector3(side * 0.13,0.52,-0.02) if standing else Vector3(side * 0.13,0.28,-0.38)
		var ankle := Vector3(side * 0.13,0.11,-0.02) if standing else Vector3(side * 0.13,-0.15,-0.45)
		_limb(mesh,hip,knee,0.083,trouser)
		_limb(mesh,knee,ankle,0.056,trouser)
		_part(mesh,ankle + Vector3(0,-0.035,-0.05),Vector3(0.06,0.05,0.13),shoes)
	# Consolidate the anatomical parts by fabric/skin material before instancing.
	var groups: Dictionary = {}
	for surface_index in mesh.get_surface_count():
		var material := mesh.surface_get_material(surface_index)
		if not groups.has(material):
			groups[material] = []
		groups[material].append(surface_index)
	var combined := ArrayMesh.new()
	for material: Material in groups:
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		for surface_index: int in groups[material]:
			builder.append_from(mesh,surface_index,Transform3D.IDENTITY)
		builder.set_material(material)
		builder.commit(combined)
	return combined

static func _part(mesh: ArrayMesh, position: Vector3, scale_value: Vector3, material: Material, basis := Basis.IDENTITY) -> void:
	var shape := SphereMesh.new()
	shape.radius = 1
	shape.height = 2
	shape.radial_segments = 10
	shape.rings = 5
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder.append_from(shape,0,Transform3D(basis.scaled(scale_value),position))
	builder.set_material(material)
	builder.commit(mesh)

static func _limb(mesh: ArrayMesh, a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var basis := Basis(Quaternion(Vector3.UP,(b-a).normalized()))
	_part(mesh,(a+b)*0.5,Vector3(radius,a.distance_to(b)*0.60,radius),material,basis)
