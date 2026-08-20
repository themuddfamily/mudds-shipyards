extends SceneTree

const SCENE := preload("res://scenes/world/planets/aurora_temperate_world.tscn")
const WORLD := preload("res://assets/world/planets/aurora_temperate_world.tres")
const TERRAIN := preload("res://assets/world/planets/aurora_temperate_terrain.tres")
const LANDING := preload("res://assets/world/planets/aurora_foundation_landing.tres")
var failures := PackedStringArray()
var assertions := 0
func _init() -> void: call_deferred("run")
func run() -> void:
	var scene := SCENE.instantiate() as AuroraTemperateAuthoredScene
	root.add_child(scene)
	await process_frame
	check(WORLD.is_definition_valid() and TERRAIN.is_profile_valid() and LANDING.is_definition_valid() and WORLD.scene_path == scene.scene_file_path, "Aurora world, terrain, landing, and scene path are exact")
	check(scene.get_node("LandingRegion").position == Vector3.UP * 120000.0 and scene.get_node("LandingRegion/WalkablePatch").collision_layer == 1 and scene.get_node("LandingRegion/WalkablePatch").collision_mask == 0, "bounded +Y landing patch has World-only collision")
	check(scene.get_node("AuroraAtmosphereComposition/WorldEnvironment") is WorldEnvironment and not scene.is_processing() and bool(scene.audit().valid), "composition remains sole WorldEnvironment owner and scene has no cadence")
	check(scene.get_node("LandingRegion/Markers/ApproachEntry").position == Vector3(0,60,300) and scene.get_node("LandingRegion/Markers/AuroraEgress").position == Vector3(18,0,0), "scene markers match the bounded landing declaration")
	print("AURORA_TEMPERATE_AUTHORED_SCENE_ASSERTIONS: %d" % assertions)
	if failures.is_empty(): print("AURORA_TEMPERATE_AUTHORED_SCENE_TEST_OK"); quit(0); return
	print("AURORA_TEMPERATE_AUTHORED_SCENE_TEST_FAILED: %s" % ", ".join(failures)); quit(1)
func check(value: bool, label: String) -> void:
	assertions += 1
	if value: print("PASS: %s" % label)
	else: failures.append(label); push_error("FAIL: %s" % label)
