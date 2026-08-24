extends SceneTree

const SemanticPresenterType := preload("res://scripts/ui/semantic_audio_cue_presenter.gd")
const TEST_ORIGIN := Vector3(820.0, 240.0, -1320.0)
const FLEET_CRAFT_NAMES := [
	"TorrentInterceptor",
	"ArrowReconShip",
	"JovianLightFreighter",
	"ZenithInterceptor",
	"HalyardCrewTransport",
]
const CASES := [
	{
		"component": ShipComponentDamage.COMPONENT_ENGINE_BAY,
		"cue": &"engine_component_impact",
		"caption": "Engine bay impact",
		"collision": true,
		"deferred": false,
	},
	{
		"component": ShipComponentDamage.COMPONENT_PORT_WING,
		"cue": &"port_weapon_component_impact",
		"caption": "Port weapon impact",
		"collision": false,
		"deferred": false,
	},
	{
		"component": ShipComponentDamage.COMPONENT_STARBOARD_WING,
		"cue": &"starboard_weapon_component_impact",
		"caption": "Starboard weapon impact",
		"collision": false,
		"deferred": false,
	},
	{
		"component": ShipComponentDamage.COMPONENT_CORE_SYSTEMS,
		"cue": &"sensor_component_impact",
		"caption": "Sensor core impact",
		"collision": false,
		"deferred": true,
	},
]

var _failures: Array[String] = []
var _semantic_events: Array[Dictionary] = []
var _next_receipt_id := 8100
var _presenter: RefCounted = SemanticPresenterType.new()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("production main scene loads")
		_finish()
		return
	var game := packed.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame

	for craft_name: String in FLEET_CRAFT_NAMES:
		var craft := game.get_node_or_null(craft_name) as HeroShip
		if craft == null:
			_fail("%s exists as a retained HeroShip" % craft_name)
			continue
		await _test_craft(craft)

	game.queue_free()
	await process_frame
	_finish()


func _test_craft(craft: HeroShip) -> void:
	var rig := craft.get_ship_audio_rig()
	var callback := _record_semantic_event.bind(StringName(craft.name))
	if not rig.semantic_engine_cue_emitted.is_connected(callback):
		rig.semantic_engine_cue_emitted.connect(callback)
	for impact_case: Dictionary in CASES:
		var reset := craft.reset_for_reuse(Transform3D(Basis.IDENTITY, TEST_ORIGIN))
		_check(bool(reset.get("accepted", false)), "%s resets before %s" % [craft.name, impact_case.cue])
		await process_frame
		_semantic_events.clear()
		var report := craft.get_component_damage_report()
		var component_id: StringName = impact_case.component
		var local_hit := _component_position(report, component_id)
		var world_hit := craft.to_global(local_hit)
		var damage_amount := craft.maximum_hull * 0.12
		var voice_requests_before := int(rig.get_state_snapshot().get("cue_request_count", -1))
		var deferred := bool(impact_case.deferred)
		var receipt_id := _next_receipt_id if deferred else -1
		_next_receipt_id += 1

		if bool(impact_case.collision):
			craft.call("_apply_resolved_collision_damage", damage_amount, world_hit, Vector3.UP)
		else:
			craft.apply_damage(damage_amount, world_hit, Vector3.UP, receipt_id, deferred)
		if deferred:
			_check(
				_count_cue(impact_case.cue) == 0,
				"%s defers %s semantic feedback with its receipt" % [craft.name, impact_case.cue]
			)
			craft.commit_deferred_damage_presentation(receipt_id)

		var cue_count := _count_cue(impact_case.cue)
		var caption := _presenter.call(
			"present_cue",
			impact_case.cue,
			StringName(craft.name),
			1.0,
			world_hit
		) as Dictionary
		_check(
			cue_count == 1
			and bool(caption.get("accepted", false))
			and str(caption.get("caption", "")) == str(impact_case.caption),
			"%s identifies %s once as '%s'" % [craft.name, component_id, impact_case.caption]
		)
		_check(
			int(rig.get_state_snapshot().get("cue_request_count", -1)) == voice_requests_before,
			"%s %s consumes no additional playback voice" % [craft.name, impact_case.cue]
		)

	var fallback_reset := craft.reset_for_reuse(Transform3D(Basis.IDENTITY, TEST_ORIGIN))
	_check(bool(fallback_reset.get("accepted", false)), "%s resets before generic feedback" % craft.name)
	await process_frame
	_semantic_events.clear()
	var fallback_voice_requests := int(rig.get_state_snapshot().get("cue_request_count", -1))
	craft.apply_damage(1.0)
	var fallback_caption := _presenter.call(
		"present_cue",
		&"hull_impact_medium",
		StringName(craft.name),
		0.35,
		Vector3.ZERO
	) as Dictionary
	_check(
		_count_cue(&"hull_impact_medium") == 1
		and fallback_caption.get("caption", "") == "Hull impact detected"
		and int(rig.get_state_snapshot().get("cue_request_count", -1)) == fallback_voice_requests,
		"%s positionless damage emits one generic hull caption without a voice" % craft.name
	)

	var stale_reset := craft.reset_for_reuse(Transform3D(Basis.IDENTITY, TEST_ORIGIN))
	_check(bool(stale_reset.get("accepted", false)), "%s resets before stale receipt probe" % craft.name)
	await process_frame
	_semantic_events.clear()
	var core_position := craft.to_global(_component_position(
		craft.get_component_damage_report(),
		ShipComponentDamage.COMPONENT_CORE_SYSTEMS
	))
	var stale_receipt := _next_receipt_id
	_next_receipt_id += 1
	craft.apply_damage(1.0, core_position, Vector3.UP, stale_receipt, true)
	craft.reset_for_reuse(Transform3D(Basis.IDENTITY, TEST_ORIGIN))
	await process_frame
	_check(
		not craft.commit_deferred_damage_presentation(stale_receipt)
		and _count_cue(&"sensor_component_impact") == 0,
		"%s reset rejects stale deferred subsystem feedback" % craft.name
	)
	if rig.semantic_engine_cue_emitted.is_connected(callback):
		rig.semantic_engine_cue_emitted.disconnect(callback)


func _component_position(report: Dictionary, component_id: StringName) -> Vector3:
	for component: Dictionary in report.get("components", []) as Array:
		if StringName(component.get("id", &"")) == component_id:
			return component.get("local_position", Vector3.INF) as Vector3
	return Vector3.INF


func _record_semantic_event(cue_id: StringName, intensity: float, craft_id: StringName) -> void:
	_semantic_events.append({"cue_id": cue_id, "intensity": intensity, "craft_id": craft_id})


func _count_cue(cue_id: StringName) -> int:
	var count := 0
	for event: Dictionary in _semantic_events:
		if StringName(event.get("cue_id", &"")) == cue_id:
			count += 1
	return count


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("Hero component impact semantic audio test passed")
		quit(0)
	else:
		push_error("Hero component impact semantic audio test failed: %s" % [_failures])
		quit(1)
