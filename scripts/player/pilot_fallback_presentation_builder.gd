class_name PilotFallbackPresentationBuilder
extends RefCounted

## Deterministic construction of the PlayerController's legacy recovery suit.
##
## This helper owns presentation composition only. PlayerController continues to
## own fallback selection, visibility, motion authority, audits, and the scene
## pivots that the generated meshes articulate around.

const PILOT_NAVY := Color("071922")
const PILOT_NAVY_LIGHT := Color("102d39")
const PILOT_CYAN_TEXTILE := Color("185665")
const PILOT_CYAN_ARMOR := Color("3f7882")
const PILOT_CERAMIC := Color("91a8a7")
const PILOT_RUBBER := Color("02090d")
const PILOT_VISOR := Color("011017")
const PILOT_KETH_CYAN := Color("42dce2")
const PILOT_AMBER := Color("e9aa3a")
const PILOT_PRESENTATION_VERSION := &"realistic_stylised_v2"

var _materials: Dictionary = {}


func create_materials() -> Dictionary:
	_create_pilot_materials()
	return _materials


func build(
		body_pivot: Node3D,
		left_arm: Node3D,
		right_arm: Node3D,
		left_leg: Node3D,
		right_leg: Node3D
	) -> void:
	_build_pilot_core(body_pivot)
	_build_pilot_arm(left_arm, -1.0)
	_build_pilot_arm(right_arm, 1.0)
	_build_pilot_leg(left_leg, -1.0)
	_build_pilot_leg(right_leg, 1.0)


func _create_pilot_materials() -> void:
	_materials = {
		# The pressure layers read as woven and light-absorbing; armour remains
		# subtly harder without turning the whole suit into polished metal.
		"undersuit": _pilot_material(PILOT_NAVY, 0.0, 0.9),
		"textile": _pilot_material(PILOT_CYAN_TEXTILE, 0.01, 0.82),
		"webbing": _pilot_material(Color("0b2028"), 0.01, 0.76),
		"soft_armor": _pilot_material(PILOT_NAVY_LIGHT, 0.05, 0.66),
		"hard_armor": _pilot_material(PILOT_CYAN_ARMOR, 0.17, 0.45),
		"ceramic": _pilot_material(PILOT_CERAMIC, 0.07, 0.58),
		"rubber": _pilot_material(PILOT_RUBBER, 0.0, 0.94),
		"visor": _pilot_material(PILOT_VISOR, 0.34, 0.15),
		"piping": _pilot_material(Color("23828a"), 0.06, 0.55),
		"cyan_light": _pilot_material(
			PILOT_KETH_CYAN,
			0.08,
			0.38,
			PILOT_KETH_CYAN,
			0.62
		),
		"amber": _pilot_material(PILOT_AMBER, 0.2, 0.4),
		"amber_light": _pilot_material(
			PILOT_AMBER,
			0.08,
			0.4,
			PILOT_AMBER,
			0.48
		),
	}


func _build_pilot_core(body_pivot: Node3D) -> void:
	var core := Node3D.new()
	core.name = "RefinedPilotCore"
	core.set_meta(&"presentation_style", &"realistic_stylised")
	core.set_meta(&"presentation_version", PILOT_PRESENTATION_VERSION)
	core.set_meta(&"target_heads_tall", Vector2(5.5, 6.0))
	body_pivot.add_child(core)

	# Flexible pressure layer and tapered armoured torso establish human rather
	# than toy-like proportions without making the suit implausibly skin-tight.
	_pilot_cylinder(
		core, "PressureTorso", Vector3(0.0, 1.205, 0.0),
		0.305, 0.235, 0.62, _materials.textile,
		Vector3(1.0, 1.0, 0.64)
	)
	_pilot_sphere(
		core, "ChestShell", Vector3(0.0, 1.315, -0.045),
		0.3, _materials.hard_armor,
		Vector3(1.04, 0.78, 0.52)
	)
	_pilot_sphere(
		core, "SternumPanel", Vector3(0.0, 1.3, -0.225),
		0.16, _materials.ceramic,
		Vector3(0.82, 1.14, 0.12)
	)
	_pilot_capsule(
		core, "ClavicleArmor", Vector3(0.0, 1.5, -0.092),
		0.045, 0.44, _materials.soft_armor,
		Vector3(1.0, 1.0, 0.58),
		Vector3(0.0, 0.0, PI * 0.5)
	)
	_pilot_cylinder(
		core, "Abdomen", Vector3(0.0, 0.92, 0.0),
		0.235, 0.215, 0.28, _materials.undersuit,
		Vector3(1.0, 1.0, 0.66)
	)
	for rib_index in range(3):
		_pilot_torus(
			core,
			"AbdomenSeal%02d" % rib_index,
			Vector3(0.0, 0.845 + float(rib_index) * 0.078, -0.006),
			0.192,
			0.207,
			_materials.soft_armor,
			Vector3(1.0, 1.0, 0.68)
		)

	_pilot_sphere(
		core, "PelvicArmor", Vector3(0.0, 0.735, -0.004),
		0.275, _materials.soft_armor,
		Vector3(1.0, 0.5, 0.68)
	)
	_pilot_cylinder(
		core, "UtilityBelt", Vector3(0.0, 0.825, -0.004),
		0.245, 0.245, 0.082, _materials.webbing,
		Vector3(1.0, 1.0, 0.68)
	)
	_pilot_torus(
		core, "BeltCyanPiping", Vector3(0.0, 0.842, -0.006),
		0.225, 0.239, _materials.piping,
		Vector3(1.0, 1.0, 0.68)
	)

	# A shallow life-support pack and service spine keep the back readable while
	# remaining compact enough for the Torrent seat and canopy.
	_pilot_capsule(
		core, "LifeSupportPack", Vector3(0.0, 1.205, 0.205),
		0.17, 0.5, _materials.soft_armor,
		Vector3(1.45, 1.0, 0.43)
	)
	_pilot_capsule(
		core, "ServiceSpine", Vector3(0.0, 1.205, 0.285),
		0.062, 0.4, _materials.ceramic,
		Vector3(0.78, 1.0, 0.5)
	)
	_pilot_sphere(
		core, "PackStatusLight", Vector3(0.0, 1.38, 0.323),
		0.026, _materials.cyan_light,
		Vector3(1.3, 0.55, 0.34)
	)

	# Harness webbing follows the chest instead of floating as a rectangular
	# plate. The amber quick-release remains a strong Keth colour cue.
	for side in [-1.0, 1.0]:
		_pilot_capsule(
			core,
			"HarnessStrap%s" % ("L" if side < 0.0 else "R"),
			Vector3(side * 0.132, 1.235, -0.252),
			0.022, 0.54, _materials.webbing,
			Vector3(1.0, 1.0, 0.44),
			Vector3(0.0, 0.0, side * deg_to_rad(-14.0))
		)
	_pilot_sphere(
		core, "HarnessRelease", Vector3(0.0, 1.075, -0.276),
		0.046, _materials.amber,
		Vector3(1.0, 0.62, 0.26)
	)
	_pilot_capsule(
		core, "ChestTelemetry", Vector3(-0.102, 1.355, -0.265),
		0.042, 0.125, _materials.soft_armor,
		Vector3(1.4, 1.0, 0.25),
		Vector3(0.0, 0.0, deg_to_rad(-8.0))
	)
	_pilot_sphere(
		core, "TelemetryLight", Vector3(-0.102, 1.382, -0.282),
		0.013, _materials.amber_light,
		Vector3(1.0, 0.55, 0.36)
	)

	# Low-profile service hoses terminate at visible couplings instead of
	# disappearing into the torso. Their dark rubber stays subordinate to the
	# harness and helmet while adding credible pressure-suit function.
	for side in [-1.0, 1.0]:
		var suffix := "L" if side < 0.0 else "R"
		_pilot_capsule(
			core, "ServiceHoseUpper%s" % suffix,
			Vector3(side * 0.245, 1.245, -0.195),
			0.015, 0.31, _materials.rubber,
			Vector3(1.0, 1.0, 0.88),
			Vector3(deg_to_rad(-4.0), 0.0, side * deg_to_rad(9.0))
		)
		_pilot_capsule(
			core, "ServiceHoseLower%s" % suffix,
			Vector3(side * 0.218, 1.015, -0.16),
			0.015, 0.2, _materials.rubber,
			Vector3(1.0, 1.0, 0.88),
			Vector3(deg_to_rad(-9.0), 0.0, side * deg_to_rad(-7.0))
		)
		_pilot_cylinder(
			core, "HoseCoupling%s" % suffix,
			Vector3(side * 0.25, 1.39, -0.215),
			0.025, 0.025, 0.026, _materials.amber,
			Vector3.ONE, Vector3(PI * 0.5, 0.0, 0.0)
		)
	for side in [-1.0, 1.0]:
		for height in [1.2, 1.4]:
			_pilot_cylinder(
				core,
				"ChestFastener%s%s" % ["L" if side < 0.0 else "R", "Low" if height < 1.3 else "High"],
				Vector3(side * 0.105, height, -0.251),
				0.011, 0.011, 0.016, _materials.rubber,
				Vector3.ONE, Vector3(PI * 0.5, 0.0, 0.0)
			)

	_build_pilot_helmet(core)


func _build_pilot_helmet(parent: Node3D) -> void:
	_pilot_torus(
		parent, "NeckPressureSeal", Vector3(0.0, 1.575, 0.0),
		0.145, 0.18, _materials.rubber,
		Vector3(1.0, 1.0, 0.9)
	)
	_pilot_sphere(
		parent, "HelmetShell", Vector3(0.0, 1.765, 0.0),
		0.18, _materials.ceramic,
		Vector3(1.0, 0.95, 0.92)
	)
	_pilot_sphere(
		parent, "HelmetRearArmor", Vector3(0.0, 1.765, 0.105),
		0.166, _materials.hard_armor,
		Vector3(1.02, 0.9, 0.56)
	)
	_pilot_sphere(
		parent, "Visor", Vector3(0.0, 1.765, -0.173),
		0.148, _materials.visor,
		Vector3(0.91, 0.7, 0.15)
	)
	_pilot_torus(
		parent, "VisorSeal", Vector3(0.0, 1.765, -0.191),
		0.108, 0.126, _materials.soft_armor,
		Vector3(1.05, 0.78, 1.0),
		Vector3(PI * 0.5, 0.0, 0.0)
	)
	_pilot_capsule(
		parent, "HelmetBrow", Vector3(0.0, 1.88, -0.142),
		0.027, 0.225, _materials.hard_armor,
		Vector3(1.0, 1.0, 0.68),
		Vector3(0.0, 0.0, PI * 0.5)
	)
	_pilot_capsule(
		parent, "HelmetChin", Vector3(0.0, 1.64, -0.138),
		0.03, 0.205, _materials.soft_armor,
		Vector3(1.0, 1.0, 0.68),
		Vector3(0.0, 0.0, PI * 0.5)
	)
	for side in [-1.0, 1.0]:
		_pilot_cylinder(
			parent,
			"HelmetComms%s" % ("L" if side < 0.0 else "R"),
			Vector3(side * 0.183, 1.765, 0.0),
			0.038, 0.038, 0.028, _materials.amber,
			Vector3.ONE,
			Vector3(0.0, 0.0, PI * 0.5)
		)
	_pilot_capsule(
		parent, "HelmetCyanRail", Vector3(0.0, 1.925, 0.005),
		0.01, 0.17, _materials.piping,
		Vector3(1.0, 1.0, 0.64),
		Vector3(0.0, 0.0, PI * 0.5)
	)


func _build_pilot_arm(parent: Node3D, side: float) -> void:
	var suffix := "L" if side < 0.0 else "R"
	_pilot_sphere(
		parent, "PressureShoulder%s" % suffix, Vector3(-side * 0.04, -0.02, 0.0),
		0.09, _materials.textile,
		Vector3(1.04, 1.0, 0.96)
	)
	_pilot_sphere(
		parent, "Shoulder%s" % suffix, Vector3(-side * 0.04, 0.005, -0.018),
		0.095, _materials.hard_armor,
		Vector3(1.18, 0.56, 0.94)
	)
	_pilot_cylinder(
		parent, "UpperArm%s" % suffix, Vector3(-side * 0.032, -0.21, 0.0),
		0.082, 0.068, 0.36, _materials.textile,
		Vector3(1.0, 1.0, 0.92),
		Vector3(0.0, 0.0, side * deg_to_rad(3.0))
	)
	_pilot_torus(
		parent, "UpperArmBand%s" % suffix, Vector3(-side * 0.039, -0.292, 0.0),
		0.073, 0.087, _materials.piping,
		Vector3(1.0, 1.0, 0.92)
	)
	_pilot_sphere(
		parent, "Elbow%s" % suffix, Vector3(-side * 0.045, -0.425, 0.0),
		0.077, _materials.soft_armor,
		Vector3(1.0, 0.9, 0.96)
	)
	_pilot_cylinder(
		parent, "Forearm%s" % suffix, Vector3(-side * 0.055, -0.56, -0.012),
		0.072, 0.058, 0.275, _materials.hard_armor,
		Vector3(1.0, 1.0, 0.9),
		Vector3(0.0, 0.0, side * deg_to_rad(4.0))
	)
	_pilot_torus(
		parent, "WristSeal%s" % suffix, Vector3(-side * 0.065, -0.7, -0.015),
		0.058, 0.072, _materials.rubber,
		Vector3(1.0, 1.0, 0.93)
	)
	_pilot_capsule(
		parent, "Glove%s" % suffix, Vector3(-side * 0.068, -0.765, -0.045),
		0.071, 0.18, _materials.rubber,
		Vector3(0.9, 1.0, 0.88),
		Vector3(deg_to_rad(8.0), 0.0, side * deg_to_rad(4.0))
	)
	_pilot_sphere(
		parent, "GloveKnuckle%s" % suffix, Vector3(-side * 0.068, -0.82, -0.092),
		0.054, _materials.ceramic,
		Vector3(1.04, 0.52, 0.4)
	)


func _build_pilot_leg(parent: Node3D, side: float) -> void:
	var suffix := "L" if side < 0.0 else "R"
	_pilot_sphere(
		parent, "HipSeal%s" % suffix, Vector3.ZERO,
		0.116, _materials.undersuit,
		Vector3(0.88, 0.94, 0.96)
	)
	_pilot_cylinder(
		parent, "Thigh%s" % suffix, Vector3(side * 0.008, -0.205, 0.0),
		0.115, 0.088, 0.38, _materials.textile,
		Vector3(0.94, 1.0, 0.92),
		Vector3(0.0, 0.0, side * deg_to_rad(-2.0))
	)
	_pilot_capsule(
		parent, "ThighArmor%s" % suffix, Vector3(side * 0.008, -0.215, -0.088),
		0.072, 0.33, _materials.hard_armor,
		Vector3(1.0, 1.0, 0.32),
		Vector3(0.0, 0.0, side * deg_to_rad(-2.0))
	)
	_pilot_sphere(
		parent, "Knee%s" % suffix, Vector3(side * 0.018, -0.39, -0.035),
		0.106, _materials.soft_armor,
		Vector3(0.91, 0.84, 0.96)
	)
	_pilot_sphere(
		parent, "KneePlate%s" % suffix, Vector3(side * 0.018, -0.4, -0.108),
		0.077, _materials.ceramic,
		Vector3(0.91, 0.82, 0.29)
	)
	_pilot_cylinder(
		parent, "Shin%s" % suffix, Vector3(side * 0.025, -0.53, 0.0),
		0.09, 0.068, 0.28, _materials.textile,
		Vector3(0.93, 1.0, 0.91),
		Vector3(0.0, 0.0, side * deg_to_rad(-2.5))
	)
	_pilot_capsule(
		parent, "ShinGuard%s" % suffix, Vector3(side * 0.025, -0.535, -0.078),
		0.061, 0.285, _materials.hard_armor,
		Vector3(0.94, 1.0, 0.3)
	)
	_pilot_torus(
		parent, "AnkleSeal%s" % suffix, Vector3(side * 0.03, -0.615, 0.0),
		0.071, 0.087, _materials.rubber,
		Vector3(0.95, 1.0, 0.92)
	)
	_pilot_capsule(
		parent, "Boot%s" % suffix, Vector3(side * 0.03, -0.625, -0.1),
		0.09, 0.39, _materials.rubber,
		Vector3(0.92, 1.0, 0.94),
		Vector3(PI * 0.5, 0.0, 0.0)
	)
	_pilot_capsule(
		parent, "BootArmor%s" % suffix, Vector3(side * 0.03, -0.595, -0.17),
		0.06, 0.27, _materials.ceramic,
		Vector3(0.92, 1.0, 0.42),
		Vector3(PI * 0.5, 0.0, 0.0)
	)
	_pilot_box(
		parent, "BootSole%s" % suffix, Vector3(side * 0.03, -0.7125, -0.1),
		Vector3(0.17, 0.035, 0.35), _materials.rubber
	)


func _pilot_material(
		albedo: Color,
		metallic: float,
		roughness: float,
		emission: Color = Color(0.0, 0.0, 0.0, 1.0),
		emission_energy: float = 0.0
	) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.metallic = metallic
	material.roughness = roughness
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = emission_energy
	return material


func _pilot_mesh_instance(
		parent: Node3D,
		part_name: String,
		position: Vector3,
		mesh: PrimitiveMesh,
		material: Material,
		scale_value: Vector3 = Vector3.ONE,
		rotation_value: Vector3 = Vector3.ZERO
	) -> MeshInstance3D:
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.position = position
	instance.rotation = rotation_value
	instance.scale = scale_value
	instance.mesh = mesh
	var material_role := _get_pilot_material_role(material)
	instance.set_meta(&"pilot_generated", true)
	instance.set_meta(&"material_role", material_role)
	instance.set_meta(&"construction_role", _get_pilot_construction_role(material_role))
	parent.add_child(instance)
	return instance


func _get_pilot_material_role(material: Material) -> StringName:
	for key in _materials:
		if _materials[key] == material:
			return StringName(key)
	return &"unknown"


func _get_pilot_construction_role(material_role: StringName) -> StringName:
	match material_role:
		&"undersuit", &"textile", &"webbing":
			return &"fabric"
		&"soft_armor", &"rubber":
			return &"flexible"
		&"hard_armor", &"ceramic", &"amber":
			return &"hard"
		&"visor":
			return &"glazing"
		&"cyan_light", &"amber_light":
			return &"light"
		&"piping":
			return &"trim"
	return &"unknown"


func _pilot_capsule(
		parent: Node3D,
		part_name: String,
		position: Vector3,
		radius: float,
		height: float,
		material: Material,
		scale_value: Vector3 = Vector3.ONE,
		rotation_value: Vector3 = Vector3.ZERO
	) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0)
	mesh.radial_segments = 24
	mesh.rings = 8
	return _pilot_mesh_instance(
		parent, part_name, position, mesh, material, scale_value, rotation_value
	)


func _pilot_sphere(
		parent: Node3D,
		part_name: String,
		position: Vector3,
		radius: float,
		material: Material,
		scale_value: Vector3 = Vector3.ONE,
		rotation_value: Vector3 = Vector3.ZERO
	) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	return _pilot_mesh_instance(
		parent, part_name, position, mesh, material, scale_value, rotation_value
	)


func _pilot_cylinder(
		parent: Node3D,
		part_name: String,
		position: Vector3,
		top_radius: float,
		bottom_radius: float,
		height: float,
		material: Material,
		scale_value: Vector3 = Vector3.ONE,
		rotation_value: Vector3 = Vector3.ZERO
	) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.rings = 4
	return _pilot_mesh_instance(
		parent, part_name, position, mesh, material, scale_value, rotation_value
	)


func _pilot_torus(
		parent: Node3D,
		part_name: String,
		position: Vector3,
		inner_radius: float,
		outer_radius: float,
		material: Material,
		scale_value: Vector3 = Vector3.ONE,
		rotation_value: Vector3 = Vector3.ZERO
	) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 24
	mesh.ring_segments = 10
	return _pilot_mesh_instance(
		parent, part_name, position, mesh, material, scale_value, rotation_value
	)


func _pilot_box(
		parent: Node3D,
		part_name: String,
		position: Vector3,
		size: Vector3,
		material: Material,
		scale_value: Vector3 = Vector3.ONE,
		rotation_value: Vector3 = Vector3.ZERO
	) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _pilot_mesh_instance(
		parent, part_name, position, mesh, material, scale_value, rotation_value
	)
