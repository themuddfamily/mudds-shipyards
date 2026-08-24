extends SceneTree

## Focused renderer contract for the base defender's two immutable charge-lens
## barrels. Animated telegraphs and every gameplay/presentation authority stay
## on their existing independent nodes.

const OPPONENT_SCENE := preload("res://scenes/ships/range_opponent.tscn")
const DERIVED_ARCHETYPES := [
	[preload("res://scenes/ships/standoff_picket_opponent.tscn"), &"StandoffPicketVisual", &"SensorBlister"],
	[preload("res://scenes/ships/flanking_skirmisher_opponent.tscn"), &"WingSkirmisherVisual", &"RoleLamp"],
	[preload("res://scenes/ships/courier_runner_opponent.tscn"), &"ContractCourierVisual", &"DistressBeacon"],
]

var _assertions := 0
var _failures: Array[String] = []
var _destroyed_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var opponent := OPPONENT_SCENE.instantiate() as RangeOpponent
	root.add_child(opponent)
	await process_frame

	var visual := opponent.get_node_or_null(^"RangeInterceptorVisual") as Node3D
	var batch := visual.get_node_or_null(^"ChargeLensBatch") as MultiMeshInstance3D \
		if visual != null else null
	var multi := batch.multimesh if batch != null else null
	var expected_basis := Basis.from_euler(Vector3(deg_to_rad(90.0), 0.0, 0.0))
	var expected_transforms: Array[Transform3D] = [
		Transform3D(expected_basis, RangeOpponent.CHARGE_LENS_POSITIONS[0]),
		Transform3D(expected_basis, RangeOpponent.CHARGE_LENS_POSITIONS[1]),
	]
	var expected_bounds := AABB()
	if multi != null and multi.mesh != null:
		for index in expected_transforms.size():
			var instance_bounds := (expected_transforms[index] * multi.mesh.get_aabb()).abs()
			expected_bounds = instance_bounds if index == 0 else expected_bounds.merge(instance_bounds)
	var material := multi.mesh.surface_get_material(0) as StandardMaterial3D \
		if multi != null and multi.mesh != null else null
	_check(
		multi != null
			and multi.transform_format == MultiMesh.TRANSFORM_3D
			and multi.instance_count == RangeOpponent.CHARGE_LENS_COPY_COUNT
			and multi.visible_instance_count == -1
			and multi.mesh.get_surface_count() == 1,
		"the two fixed charge lenses use one bounded 3D MultiMesh submission"
	)
	_check(
		batch.get_meta(&"authored_instance_transforms", []) == expected_transforms
			and batch.get_meta(&"authored_visual_names", PackedStringArray()) \
				== PackedStringArray(RangeOpponent.CHARGE_LENS_NAMES)
			and multi.custom_aabb.is_equal_approx(expected_bounds),
		"both exact lens transforms, semantic identities and culling bounds remain authored"
	)
	_check(
		batch.layers == 1
			and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and material != null
			and material.albedo_color.is_equal_approx(RangeOpponent.SIGNAL_AMBER)
			and material.emission_enabled
			and is_equal_approx(material.emission_energy_multiplier, 2.3)
			and bool(batch.get_meta(&"presentation_only", false))
			and batch.get_child_count() == 0
			and batch.get_script() == null,
		"the batched stock preserves its renderer recipe and remains authority-free"
	)

	var retired_lenses := 0
	var telegraphs := 0
	for raw_child in visual.get_children():
		var mesh_instance := raw_child as MeshInstance3D
		if mesh_instance == null:
			continue
		if mesh_instance.position in RangeOpponent.CHARGE_LENS_POSITIONS:
			retired_lenses += 1
		var sphere := mesh_instance.mesh as SphereMesh
		if sphere != null and is_equal_approx(sphere.radius, RangeOpponent.WEAPON_TELEGRAPH_RADIUS):
			telegraphs += 1
	_check(
		retired_lenses == 0 and telegraphs == RangeOpponent.WEAPON_TELEGRAPH_COPY_COUNT,
		"the retired renderers are gone while both animated telegraph nodes remain independent"
	)

	var audio_binding := opponent.get_damage_audio_binding()
	var audio_snapshot: Dictionary = audio_binding.call("get_snapshot") \
		if audio_binding != null else {}
	_check(
		opponent.find_children("*", "CollisionShape3D", false, false).size() == 7
			and opponent.get_node_or_null(^"PortMuzzle") is Marker3D
			and opponent.get_node_or_null(^"StarboardMuzzle") is Marker3D
			and opponent.get_node_or_null(^"DamageSparks") is CPUParticles3D
			and opponent.get_node_or_null(^"EngineSmoke") is CPUParticles3D
			and opponent.get_node_or_null(^"WeaponDamageSparks") is CPUParticles3D
			and opponent.get_node_or_null(^"SensorDamageLight") is OmniLight3D
			and bool(audio_snapshot.get("attached", false)),
		"collision, combat mounts, particle anchors and semantic audio binding remain independent"
	)

	opponent.destroyed.connect(_on_destroyed)
	var activation := opponent.activate_with_result(Transform3D(Basis.IDENTITY, Vector3(4.0, 2.0, -8.0)))
	var maximum_health := opponent.get_maximum_health()
	opponent.apply_damage(maximum_health * 0.7, opponent.global_position)
	var smoke := opponent.get_node_or_null(^"EngineSmoke") as CPUParticles3D
	var damaged := opponent.is_active() and smoke != null and smoke.emitting
	opponent.deactivate()
	activation = opponent.activate_with_result(Transform3D(Basis.IDENTITY, Vector3(-3.0, 1.0, 6.0)))
	var reused := bool(activation.get("accepted", false)) \
		and opponent.is_active() \
		and is_equal_approx(opponent.get_health(), maximum_health) \
		and smoke != null \
		and not smoke.emitting \
		and batch.visible
	opponent.apply_damage(maximum_health, opponent.global_position)
	_check(
		damaged and reused and _destroyed_count == 1 and not opponent.is_active(),
		"component damage, reuse reset and the external destruction/scoring hook remain intact"
	)

	for archetype_spec in DERIVED_ARCHETYPES:
		var archetype := (archetype_spec[0] as PackedScene).instantiate() as RangeOpponent
		root.add_child(archetype)
		await process_frame
		var visual_name := archetype_spec[1] as StringName
		var sensor_name := archetype_spec[2] as StringName
		var derived_visual := archetype.get_node_or_null(NodePath(String(visual_name))) as Node3D
		_check(
			derived_visual != null
				and derived_visual.get_node_or_null(NodePath(String(sensor_name))) is Node3D
				and derived_visual.get_node_or_null(^"ChargeLensBatch") == null,
			"%s keeps its override-owned silhouette and component anchor" % visual_name
		)
		archetype.queue_free()
		await process_frame

	opponent.queue_free()
	await process_frame
	if _failures.is_empty():
		print("RANGE_OPPONENT_CHARGE_LENS_MULTIMESH_TEST_OK: %d checks" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _on_destroyed(_position: Vector3) -> void:
	_destroyed_count += 1


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
