class_name SponsorIdentity
extends RefCounted
## Original image-generated identities shared by cars, pit garages and barriers.
const NAMES := ["APEX CIRCUIT", "VOLTARA", "NORDLINE", "HELIX", "KORSA", "AERION", "STRATUM", "PULSE", "VECTOR", "IONIX", "FORGE", "ZENITH"]
static var _materials: Dictionary = {}

static func material(index: int) -> StandardMaterial3D:
	index = posmod(index, 12)
	if _materials.has(index):
		return _materials[index]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = preload("res://assets/sponsors/atlas.png") if index < 8 else preload("res://assets/sponsors/car-atlas.png")
	# Inset the UV region to avoid neighbouring tiles bleeding into mip levels.
	mat.uv1_scale = Vector3(0.496, 0.246 if index < 8 else 0.496, 1)
	var tile := index if index < 8 else index - 8
	mat.uv1_offset = Vector3((tile % 2) * 0.5 + 0.002, (tile / 2) * (0.25 if index < 8 else 0.5) + 0.002, 0)
	if index == 0:
		mat.albedo_texture = preload("res://assets/branding/apex-circuit-dark.png")
		mat.uv1_scale = Vector3.ONE
		mat.uv1_offset = Vector3.ZERO
	mat.roughness = 0.53
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_materials[index] = mat
	return mat

static func panel(parent: Node3D, index: int, dimensions: Vector2, pose: Transform3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = "Sponsor_" + NAMES[posmod(index, 12)].replace(" ", "_")
	var quad := QuadMesh.new()
	if posmod(index, 12) == 0:
		dimensions.y = minf(dimensions.y, dimensions.x / 3.0)
	quad.size = dimensions
	node.mesh = quad
	node.material_override = material(index)
	node.transform = pose
	parent.add_child(node)
	return node
