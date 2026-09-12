extends RefCounted
## Collapse static detail into one draw per material, preserving moving pivots.
static func merge_children(parent: Node3D, excluded: Array = []) -> void:
	var groups: Dictionary = {}
	for child in parent.get_children():
		if child in excluded:
			continue
		if child is MeshInstance3D and child not in excluded and child.mesh != null and child.get_child_count() == 0:
			var material: Material = child.material_override
			if material == null:
				continue
			if not groups.has(material):
				groups[material] = []
			groups[material].append(child)
		elif child is Node3D and not child is GeometryInstance3D:
			merge_children(child, excluded)
	for material: Material in groups:
		var items: Array = groups[material]
		if items.size() < 2:
			continue
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		for item: MeshInstance3D in items:
			for surface in item.mesh.get_surface_count():
				builder.append_from(item.mesh, surface, item.transform)
		var merged := MeshInstance3D.new()
		merged.name = "BatchedDetail"
		merged.mesh = builder.commit()
		merged.material_override = material
		merged.cast_shadow = items[0].cast_shadow
		parent.add_child(merged)
		for item: MeshInstance3D in items:
			parent.remove_child(item)
			item.queue_free()
